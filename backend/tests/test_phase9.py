"""
Phase 9: Generic Workflow Engine
Configurable procedures, departments, status flow, and checklist generation.
"""
import pytest
import json
from fastapi.testclient import TestClient
from backend.main import app


@pytest.fixture
def client():
    return TestClient(app)


class TestPhase9WorkflowEngine:
    """Validate workflow management and procedure execution."""

    def test_create_workflow_instance(self, client):
        """Create a new workflow instance for a procedure."""
        response = client.post(
            "/api/workflows",
            json={
                "procedure_type": "withdrawal",
                "student_id": "STU001",
                "metadata": {"reason": "Personal reasons"}
            }
        )
        assert response.status_code == 200
        body = response.json()
        assert "workflow_id" in body
        assert body["procedure_type"] == "withdrawal"
        assert body["status"] == "initiated"
        assert "created_at" in body

    def test_workflow_has_department_assignment(self, client):
        """Workflow instance includes department routing."""
        response = client.post(
            "/api/workflows",
            json={
                "procedure_type": "withdrawal",
                "student_id": "STU002",
                "metadata": {"reason": "Academic"}
            }
        )
        body = response.json()
        assert "assigned_department" in body
        assert body["assigned_department"] in ["Academic Affairs", "Student Services", "Finance", "Registry"]

    def test_workflow_status_progression(self, client):
        """Workflow can advance through defined status states."""
        # Create workflow
        create_resp = client.post(
            "/api/workflows",
            json={
                "procedure_type": "withdrawal",
                "student_id": "STU003",
                "metadata": {"reason": "Health"}
            }
        )
        workflow_id = create_resp.json()["workflow_id"]

        # Advance to next status
        advance_resp = client.post(
            f"/api/workflows/{workflow_id}/advance",
            json={"action": "submit", "notes": "Submitted for review"}
        )
        assert advance_resp.status_code == 200
        body = advance_resp.json()
        assert body["status"] in ["submitted", "under_review", "pending_approval"]

    def test_workflow_checklist_generation(self, client):
        """Workflow generates required checklist items based on procedure."""
        response = client.post(
            "/api/workflows",
            json={
                "procedure_type": "withdrawal",
                "student_id": "STU004",
                "metadata": {"reason": "Career"}
            }
        )
        body = response.json()
        assert "checklist" in body
        assert isinstance(body["checklist"], list)
        assert len(body["checklist"]) > 0
        
        # Each checklist item has required structure
        for item in body["checklist"]:
            assert "item_id" in item
            assert "description" in item
            assert "status" in item
            assert item["status"] in ["pending", "completed", "approved"]

    def test_workflow_retrieve_by_id(self, client):
        """Retrieve workflow status and details by ID."""
        # Create
        create_resp = client.post(
            "/api/workflows",
            json={
                "procedure_type": "withdrawal",
                "student_id": "STU005",
                "metadata": {"reason": "Family"}
            }
        )
        workflow_id = create_resp.json()["workflow_id"]

        # Retrieve
        get_resp = client.get(f"/api/workflows/{workflow_id}")
        assert get_resp.status_code == 200
        body = get_resp.json()
        assert body["workflow_id"] == workflow_id
        assert "status" in body
        assert "checklist" in body
        assert "assigned_department" in body

    def test_workflow_list_by_student(self, client):
        """List all workflows for a student."""
        student_id = "STU006"
        
        # Create two workflows
        client.post(
            "/api/workflows",
            json={
                "procedure_type": "withdrawal",
                "student_id": student_id,
                "metadata": {"reason": "Test1"}
            }
        )
        client.post(
            "/api/workflows",
            json={
                "procedure_type": "grievance",
                "student_id": student_id,
                "metadata": {"subject": "Test2"}
            }
        )

        # List
        list_resp = client.get(f"/api/workflows?student_id={student_id}")
        assert list_resp.status_code == 200
        body = list_resp.json()
        assert isinstance(body, list)
        assert len(body) >= 2

    def test_checklist_item_completion(self, client):
        """Mark checklist items as completed."""
        # Create workflow
        create_resp = client.post(
            "/api/workflows",
            json={
                "procedure_type": "withdrawal",
                "student_id": "STU007",
                "metadata": {"reason": "Test"}
            }
        )
        workflow_id = create_resp.json()["workflow_id"]
        checklist_items = create_resp.json()["checklist"]
        
        if checklist_items:
            first_item_id = checklist_items[0]["item_id"]
            
            # Complete item
            complete_resp = client.post(
                f"/api/workflows/{workflow_id}/checklist/{first_item_id}/complete",
                json={"notes": "Document submitted"}
            )
            assert complete_resp.status_code == 200
            body = complete_resp.json()
            
            # Verify status changed
            updated_item = next(
                (item for item in body["checklist"] if item["item_id"] == first_item_id),
                None
            )
            assert updated_item is not None
            assert updated_item["status"] in ["completed", "pending_review"]

    def test_multiple_procedure_types(self, client):
        """Workflow engine handles different procedure types."""
        procedures = [
            {"type": "withdrawal", "metadata": {"reason": "Career"}},
            {"type": "grievance", "metadata": {"subject": "Issue"}},
            {"type": "scholarship", "metadata": {"scheme_id": "SCH001"}},
        ]
        
        for proc in procedures:
            response = client.post(
                "/api/workflows",
                json={
                    "procedure_type": proc["type"],
                    "student_id": "STU008",
                    "metadata": proc["metadata"]
                }
            )
            assert response.status_code == 200
            body = response.json()
            assert body["procedure_type"] == proc["type"]
            assert "checklist" in body
            assert len(body["checklist"]) > 0
