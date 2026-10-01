"""
Comprehensive Test Suite for Generalized Institutional Setup & Customizer:
1. Module Switchboard (Dynamic Enablement / Disablement)
2. Procedure Step Customizer (Add, Update, Delete with renumbering, Reorder)
3. Dynamic Clearance Chain Integration in Withdrawal Requests
4. Dynamic Reference Prefix Generation
"""

import pytest
from fastapi.testclient import TestClient
from backend.services.institution_service import InstitutionService
from backend.services.procedure_service import ProcedureService
from backend.services.withdrawal_workflow import create_withdrawal_request, process_department_clearance, generate_reference
from backend.database.connection import get_connection


@pytest.fixture(autouse=True)
def isolate_generalized_setup_db():
    """Snapshot and restore tables before and after each test in this module."""
    conn = get_connection()
    # Save snapshots
    config_snap = conn.execute("SELECT key, value FROM institution_config").fetchall()
    chain_snap = conn.execute("SELECT * FROM institution_clearance_chain").fetchall()
    steps_snap = conn.execute("SELECT * FROM procedure_steps").fetchall()

    yield

    # Restore snapshots
    conn.execute("DELETE FROM institution_config")
    conn.executemany("INSERT INTO institution_config (key, value) VALUES (?, ?)", [(r["key"], r["value"]) for r in config_snap])

    conn.execute("DELETE FROM institution_clearance_chain")
    conn.executemany(
        "INSERT INTO institution_clearance_chain (desk_code, desk_name, sequence_order, is_active, description) VALUES (?, ?, ?, ?, ?)",
        [(r["desk_code"], r["desk_name"], r["sequence_order"], r["is_active"], r["description"]) for r in chain_snap],
    )

    conn.execute("DELETE FROM procedure_steps")
    conn.executemany(
        "INSERT INTO procedure_steps (id, procedure_code, step_number, title, description, department, timeline_text, status_after) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [(r["id"], r["procedure_code"], r["step_number"], r["title"], r["description"], r["department"], r["timeline_text"], r["status_after"]) for r in steps_snap],
    )
    conn.commit()


class TestGeneralizedSetup:

    def test_module_switchboard_get_and_put(self, client: TestClient):
        """Verify GET and PUT for /api/institution/modules."""
        # 1. Fetch current modules
        res = client.get("/api/institution/modules")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        modules = data["modules"]
        assert modules["dashboard"] is True
        assert modules["withdrawal"] is True
        assert modules["scholarships"] is True

        # 2. Toggle off scholarships and hostel
        put_res = client.put(
            "/api/institution/modules",
            json={"modules": {"scholarships": False, "hostel": False}},
        )
        assert put_res.status_code == 200
        put_data = put_res.json()
        assert put_data["status"] == "success"
        assert put_data["modules"]["scholarships"] is False
        assert put_data["modules"]["hostel"] is False
        assert put_data["modules"]["withdrawal"] is True

        # 3. Verify persistence
        res2 = client.get("/api/institution/modules")
        assert res2.json()["modules"]["scholarships"] is False
        assert res2.json()["modules"]["hostel"] is False

        # Reset back for clean state
        client.put("/api/institution/modules", json={"modules": {"scholarships": True, "hostel": True}})

    def test_procedure_steps_list_and_add(self, client: TestClient):
        """Verify listing and adding steps to a standard procedure (e.g. withdrawal)."""
        # 1. Get initial steps
        res = client.get("/api/procedures/withdrawal/steps")
        assert res.status_code == 200
        init_steps = res.json()["steps"]
        init_count = len(init_steps)
        assert init_count > 0

        # 2. Add step inserted at position 2
        add_res = client.post(
            "/api/procedures/withdrawal/steps",
            json={
                "title": "Laboratory Component Handover",
                "department": "Department Lab Cell",
                "timeline_text": "24 hours",
                "description": "Return all equipment and toolkits.",
                "insert_at_step": 2,
            },
        )
        assert add_res.status_code == 201
        add_data = add_res.json()
        assert add_data["total_steps"] == init_count + 1
        assert add_data["step_number"] == 2

        # Verify step at position 2 is the new step
        steps = add_data["steps"]
        step2 = next(s for s in steps if s["step_number"] == 2)
        assert step2["title"] == "Laboratory Component Handover"
        assert step2["department"] == "Department Lab Cell"

        # Verify previous step 2 is now step 3
        step3 = next(s for s in steps if s["step_number"] == 3)
        assert step3["id"] == init_steps[1]["id"]

    def test_procedure_steps_update(self, client: TestClient):
        """Verify updating title, department, or SLA of a procedure step."""
        res = client.put(
            "/api/procedures/withdrawal/steps/2",
            json={
                "title": "Advanced Laboratory Handover",
                "timeline_text": "Same day SLA",
            },
        )
        assert res.status_code == 200
        data = res.json()
        step2 = next(s for s in data["steps"] if s["step_number"] == 2)
        assert step2["title"] == "Advanced Laboratory Handover"
        assert step2["timeline_text"] == "Same day SLA"

    def test_procedure_steps_delete_and_recompact(self, client: TestClient):
        """Verify deleting a step renumbers all subsequent steps contiguously."""
        steps_before = client.get("/api/procedures/withdrawal/steps").json()["steps"]
        count_before = len(steps_before)

        # Delete step 2
        del_res = client.delete("/api/procedures/withdrawal/steps/2")
        assert del_res.status_code == 200
        del_data = del_res.json()
        assert del_data["deleted_step"] == 2
        assert del_data["remaining_steps"] == count_before - 1

        # Check contiguous indexing 1, 2, 3...
        step_numbers = [s["step_number"] for s in del_data["steps"]]
        assert step_numbers == list(range(1, count_before))

    def test_procedure_steps_reorder(self, client: TestClient):
        """Verify reordering steps using ordered IDs."""
        current_steps = client.get("/api/procedures/withdrawal/steps").json()["steps"]
        if len(current_steps) >= 3:
            # Swap first and second
            step_ids = [s["id"] for s in current_steps]
            swapped_ids = [step_ids[1], step_ids[0]] + step_ids[2:]

            res = client.post(
                "/api/procedures/withdrawal/steps/reorder",
                json={"ordered_step_ids": swapped_ids},
            )
            assert res.status_code == 200
            reordered = res.json()["steps"]
            assert reordered[0]["id"] == swapped_ids[0]
            assert reordered[1]["id"] == swapped_ids[1]

            # Revert back to original order
            client.post("/api/procedures/withdrawal/steps/reorder", json={"ordered_step_ids": step_ids})

    def test_dynamic_reference_prefix(self):
        """Verify generated reference numbers adapt to institution short_name."""
        # 1. Default should be AMITY
        ref_default = generate_reference()
        assert ref_default.startswith("AMITY-WTH-")

        # 2. Update short_name to DTU
        InstitutionService.update_config({"short_name": "DTU"})
        ref_dtu = generate_reference()
        assert ref_dtu.startswith("DTU-WTH-")

        # 3. Update short_name to IITD
        InstitutionService.update_config({"short_name": "IITD"})
        ref_iitd = generate_reference()
        assert ref_iitd.startswith("IITD-WTH-")

        # Revert back to AMITY
        InstitutionService.update_config({"short_name": "AMITY"})

    def test_dynamic_clearance_chain_withdrawal_creation(self):
        """Verify withdrawal request creates clearance gates matching active clearance chain."""
        conn = get_connection()

        # Set a custom 3-gate clearance chain: LIBRARY, LABORATORY, ACCOUNTS
        custom_chain = [
            {"desk_code": "LIBRARY", "desk_name": "Central Library", "is_active": True},
            {"desk_code": "LABORATORY", "desk_name": "Department Labs", "is_active": True},
            {"desk_code": "ACCOUNTS", "desk_name": "Finance & Accounts", "is_active": True},
        ]
        InstitutionService.update_clearance_chain(custom_chain)

        # Create withdrawal
        ref = create_withdrawal_request(
            student_id="STU001",
            reason="Personal relocation",
            intent="personal",
        )
        assert "-WTH-" in ref

        # Check clearance_gates in SQLite
        gates = conn.execute(
            "SELECT department, sequence_order, status FROM clearance_gates WHERE reference_no = ? ORDER BY sequence_order ASC",
            (ref,),
        ).fetchall()
        gate_depts = [g["department"] for g in gates]
        assert gate_depts == ["LIBRARY", "LABORATORY", "ACCOUNTS"]
        assert len(gates) == 3

        # Verify clearance action works for custom LABORATORY gate
        clear_res = process_department_clearance(
            reference_no=ref,
            department="LABORATORY",
            action="CLEAR",
            officer_name="Dr. Lab Officer",
            officer_id="STAFF_LAB_1",
            notes="Equipment returned intact.",
        )
        assert clear_res["status"] == "CLEARED"
        assert clear_res["is_all_cleared"] is False

        # Reset clearance chain back to default 4 desks
        default_chain = [
            {"desk_code": "LIBRARY", "desk_name": "Library Clearance Desk", "is_active": True},
            {"desk_code": "HOSTEL", "desk_name": "Hostel Clearance Desk", "is_active": True},
            {"desk_code": "ACCOUNTS", "desk_name": "Accounts & Finance Desk", "is_active": True},
            {"desk_code": "REGISTRAR", "desk_name": "Registrar Office", "is_active": True},
        ]
        InstitutionService.update_clearance_chain(default_chain)
