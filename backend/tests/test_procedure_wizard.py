"""
Tests for Phase 30: Interactive Procedure Setup Wizard.
Verifies custom procedure creation, multi-desk step sequencing,
document requirements checklist, and filtering.
"""

import pytest


class TestProcedureWizard:
    def test_default_custom_procedures_seeded(self, client):
        """Default sample custom procedures are seeded on DB init."""
        res = client.get("/api/procedures")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["count"] >= 2
        titles = [p["title"] for p in data["procedures"]]
        assert "Hostel Room Change Application" in titles
        assert "Bonafide & Character Certificate Request" in titles

    def test_get_procedure_detail(self, client):
        """Fetch details of a seeded procedure with all step metadata."""
        res = client.get("/api/procedures/proc-hostel-swap")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        proc = data["procedure"]
        assert proc["id"] == "proc-hostel-swap"
        assert proc["department"] == "Hostel Administration"
        assert proc["category"] == "ACCOMMODATION"
        assert len(proc["steps"]) == 3
        assert len(proc["required_docs"]) == 3
        assert proc["steps"][0]["responsible_desk"] == "Hostel Warden"

    def test_create_custom_procedure(self, client):
        """Staff can create a brand new custom procedure with sequential approval steps."""
        payload = {
            "title": "Semester Grade Re-Evaluation",
            "department": "Examination Controller Office",
            "category": "EXAMINATION",
            "description": "Formal application workflow for students requesting answer script re-totaling and re-evaluation.",
            "sla_days": 10,
            "required_docs": ["Grade Card Copy", "Fee Payment Receipt (₹500 per subject)"],
            "steps": [
                {
                    "title": "Fee & Eligibility Verification",
                    "description": "Accounts validates re-eval payment receipt.",
                    "responsible_desk": "Accounts Desk",
                    "sla_days": 2,
                },
                {
                    "title": "Script Retrieval & Examiner Assignment",
                    "description": "Controller retrieves physical script and assigns independent reviewer.",
                    "responsible_desk": "Examination Cell",
                    "sla_days": 5,
                },
                {
                    "title": "Final Grade Amendment & Notification",
                    "description": "Registrar issues amended grade sheet if marks variance > 5%.",
                    "responsible_desk": "Registrar Office",
                    "sla_days": 3,
                },
            ],
            "created_by": "STAFF_EXAM_01",
        }
        res = client.post("/api/procedures", json=payload)
        assert res.status_code == 201
        data = res.json()
        assert data["status"] == "success"
        created = data["procedure"]
        assert created["title"] == "Semester Grade Re-Evaluation"
        assert len(created["steps"]) == 3
        assert created["total_steps"] == 3
        assert len(created["required_docs"]) == 2

        # Verify it appears in list
        list_res = client.get("/api/procedures?category=EXAMINATION")
        assert list_res.status_code == 200
        exam_procs = list_res.json()["procedures"]
        assert any(p["id"] == created["id"] for p in exam_procs)

    def test_filter_procedures_by_department(self, client):
        """Procedures can be filtered by department."""
        res = client.get("/api/procedures?department=Registrar Office")
        assert res.status_code == 200
        data = res.json()
        for p in data["procedures"]:
            assert p["department"].lower() == "registrar office"

    def test_delete_procedure(self, client):
        """Staff can delete a custom procedure."""
        # Create a temporary procedure
        payload = {
            "title": "Temporary Parking Permit",
            "department": "Security",
            "category": "CAMPUS_SERVICES",
            "description": "Temp pass for visitors",
            "sla_days": 2,
            "required_docs": ["Vehicle RC"],
            "steps": [
                {"title": "Gate verification", "responsible_desk": "Main Gate", "sla_days": 1}
            ],
        }
        create_res = client.post("/api/procedures", json=payload)
        assert create_res.status_code == 201
        proc_id = create_res.json()["procedure"]["id"]

        # Delete it
        del_res = client.delete(f"/api/procedures/{proc_id}")
        assert del_res.status_code == 200
        assert del_res.json()["status"] == "success"

        # Verify 404
        get_res = client.get(f"/api/procedures/{proc_id}")
        assert get_res.status_code == 404

    def test_procedure_validation_error(self, client):
        """Validation errors returned for invalid inputs."""
        res = client.post("/api/procedures", json={"title": "", "department": "", "category": ""})
        assert res.status_code == 422  # Pydantic validation error
