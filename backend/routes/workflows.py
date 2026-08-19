"""
Phase 9: Workflow Management Routes
Generic workflow API endpoints for procedure management.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from ..services.workflow_service import WorkflowService

router = APIRouter(prefix="/api/workflows", tags=["workflows"])


class WorkflowCreateRequest(BaseModel):
    procedure_type: str
    student_id: str
    metadata: Optional[Dict[str, Any]] = None
    campus_code: Optional[str] = None


class WorkflowAdvanceRequest(BaseModel):
    action: str
    notes: Optional[str] = None


class ChecklistItemCompleteRequest(BaseModel):
    notes: Optional[str] = None


@router.post("")
def create_workflow(request: WorkflowCreateRequest):
    """Create a new workflow instance."""
    try:
        result = WorkflowService.create_workflow(
            request.procedure_type, request.student_id, request.metadata, request.campus_code
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to create workflow")


@router.get("/{workflow_id}")
def get_workflow(workflow_id: str):
    """Retrieve workflow by ID."""
    result = WorkflowService.get_workflow(workflow_id)
    if not result:
        raise HTTPException(status_code=404, detail="Workflow not found")
    return result


@router.get("")
def list_workflows(student_id: str):
    """List all workflows for a student."""
    results = WorkflowService.list_workflows_for_student(student_id)
    return results


@router.post("/{workflow_id}/advance")
def advance_workflow(workflow_id: str, request: WorkflowAdvanceRequest):
    """Advance workflow to next status."""
    result = WorkflowService.advance_workflow(workflow_id, request.action, request.notes)
    if not result:
        raise HTTPException(status_code=404, detail="Workflow not found")
    return result


@router.post("/{workflow_id}/checklist/{item_id}/complete")
def complete_checklist_item(
    workflow_id: str, item_id: str, request: ChecklistItemCompleteRequest
):
    """Mark a checklist item as completed."""
    result = WorkflowService.complete_checklist_item(
        workflow_id, item_id, request.notes
    )
    if not result:
        raise HTTPException(status_code=404, detail="Workflow not found")
    return result
