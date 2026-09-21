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
