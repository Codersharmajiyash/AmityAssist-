"""Structured withdrawal workflow endpoints for Phase 1 UNIASSIST MVP."""

from fastapi import APIRouter

from ..services.withdrawal_workflow import (
    get_latest_withdrawal_status,
    get_required_documents,
    get_withdrawal_guide,
)

router = APIRouter(prefix="/api/withdrawal", tags=["Withdrawal Workflow"])


@router.get("/guide")
async def withdrawal_guide():
    """Return official steps, documents, forms, departments, and timelines."""
    return get_withdrawal_guide()


@router.get("/documents")
async def withdrawal_documents(reason: str | None = None):
    """Return required documents for a withdrawal reason."""
    return {"documents": get_required_documents(reason)}


@router.get("/status/{student_id}")
async def withdrawal_status(student_id: str):
    """Return latest withdrawal request, generated checklist, and timeline."""
    return get_latest_withdrawal_status(student_id)
