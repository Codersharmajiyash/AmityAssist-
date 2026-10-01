"""
Phase 30: Interactive Procedure Setup Wizard API Router.
Enables administrators and staff to configure custom student procedures,
approval chains, SLA targets, and document verification checklists.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional
from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel, Field

from ..services.procedure_service import ProcedureService

router = APIRouter(prefix="/api/procedures", tags=["Procedure Setup Wizard"])


class ProcedureStepInput(BaseModel):
    title: str = Field(..., min_length=2, max_length=150)
    description: str = Field("", max_length=500)
    responsible_desk: str = Field(..., min_length=2, max_length=100)
    sla_days: int = Field(2, ge=1, le=90)


class ProcedureCreateRequest(BaseModel):
    title: str = Field(..., min_length=3, max_length=200)
    department: str = Field(..., min_length=2, max_length=100)
    category: str = Field(..., min_length=2, max_length=50)
    description: str = Field("", max_length=1000)
    sla_days: int = Field(7, ge=1, le=180)
    required_docs: List[str] = Field(default_factory=list)
    steps: List[ProcedureStepInput] = Field(default_factory=list)
    created_by: str = Field("STAFF", max_length=50)


@router.get("", summary="List Custom Procedures")
async def list_procedures(
    department: Optional[str] = Query(None, description="Filter by department name"),
    category: Optional[str] = Query(None, description="Filter by category code"),
    active_only: bool = Query(False, description="Filter active procedures only"),
):
    """Retrieve all custom procedures with steps and required document checklists."""
    try:
        procedures = ProcedureService.list_procedures(
            department=department,
            category=category,
            active_only=active_only,
        )
        return {
            "status": "success",
            "count": len(procedures),
            "procedures": procedures,
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list procedures: {str(e)}",
        )


@router.get("/{procedure_id}", summary="Get Procedure Details")
async def get_procedure(procedure_id: str):
    """Fetch full configuration, steps, and document checklist for a procedure."""
    proc = ProcedureService.get_procedure(procedure_id)
    if not proc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Procedure '{procedure_id}' not found",
        )
    return {"status": "success", "procedure": proc}


@router.post("", status_code=status.HTTP_201_CREATED, summary="Create Custom Procedure")
async def create_procedure(req: ProcedureCreateRequest):
    """Create a new custom procedure with sequential desk steps and required documents."""
    try:
        steps_data = [s.model_dump() for s in req.steps]
        created = ProcedureService.create_procedure(
            title=req.title,
            department=req.department,
            category=req.category,
            description=req.description,
            sla_days=req.sla_days,
            required_docs=req.required_docs,
            steps=steps_data,
            created_by=req.created_by,
        )
        return {
            "status": "success",
            "message": "Custom procedure created successfully",
            "procedure": created,
        }
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create procedure: {str(e)}",
        )


@router.delete("/{procedure_id}", summary="Delete Custom Procedure")
async def delete_procedure(procedure_id: str):
    """Delete a custom procedure and its steps."""
    success = ProcedureService.delete_procedure(procedure_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Procedure '{procedure_id}' not found",
        )
    return {"status": "success", "message": f"Procedure '{procedure_id}' deleted successfully"}


# ── Procedure Step Customizer (e.g. Program Withdrawal Steps) ────────────────

class StepCreateRequest(BaseModel):
    title: str = Field(..., min_length=2, max_length=150)
    department: str = Field(..., min_length=2, max_length=100)
    timeline_text: str = Field("1-2 days", max_length=100)
    description: str = Field("", max_length=500)
    status_after: str = Field("in_progress", max_length=50)
    insert_at_step: Optional[int] = Field(None, ge=1)


class StepUpdateRequest(BaseModel):
    title: Optional[str] = Field(None, min_length=2, max_length=150)
    department: Optional[str] = Field(None, min_length=2, max_length=100)
    timeline_text: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    status_after: Optional[str] = Field(None, max_length=50)


class StepReorderRequest(BaseModel):
    ordered_step_ids: List[int] = Field(..., min_length=1)


@router.get("/{code}/steps", summary="List Steps for Procedure")
async def get_procedure_steps(code: str):
    """Retrieve all ordered steps for the given procedure code (e.g., 'withdrawal')."""
    steps = ProcedureService.get_steps(code)
    return {
        "status": "success",
        "procedure_code": code,
        "total_steps": len(steps),
        "steps": steps,
    }


@router.post("/{code}/steps", status_code=status.HTTP_201_CREATED, summary="Add Step to Procedure")
async def add_procedure_step(code: str, req: StepCreateRequest):
    """Add a new step to a procedure, optionally inserted at a target position."""
    try:
        result = ProcedureService.add_step(
            procedure_code=code,
            title=req.title,
            department=req.department,
            timeline_text=req.timeline_text,
            description=req.description,
            status_after=req.status_after,
            insert_at_step=req.insert_at_step,
        )
        return {"status": "success", "message": "Step added successfully", **result}
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))


@router.put("/{code}/steps/{step_number}", summary="Update Procedure Step")
async def update_procedure_step(code: str, step_number: int, req: StepUpdateRequest):
    """Update title, department, timeline, or description of a procedure step."""
    try:
        result = ProcedureService.update_step(
            procedure_code=code,
            step_number=step_number,
            title=req.title,
            description=req.description,
            department=req.department,
            timeline_text=req.timeline_text,
            status_after=req.status_after,
        )
        return {"status": "success", "message": "Step updated successfully", **result}
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ve))


@router.delete("/{code}/steps/{step_number}", summary="Delete Procedure Step")
async def delete_procedure_step(code: str, step_number: int):
    """Delete a step and recompact subsequent step numbers to maintain contiguous ordering."""
    try:
        result = ProcedureService.delete_step(procedure_code=code, step_number=step_number)
        return {"status": "success", "message": f"Step {step_number} deleted successfully", **result}
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ve))


@router.post("/{code}/steps/reorder", summary="Reorder Procedure Steps")
async def reorder_procedure_steps(code: str, req: StepReorderRequest):
    """Reorder procedure steps based on the provided ordered list of step IDs."""
    try:
        result = ProcedureService.reorder_steps(procedure_code=code, ordered_step_ids=req.ordered_step_ids)
        return {"status": "success", "message": "Steps reordered successfully", **result}
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
