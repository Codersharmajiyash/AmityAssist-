"""
Compliance and Data Privacy API routes (Phase 19).
"""

from typing import Optional
from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel, Field

from ..security.rbac import require_student_access, require_any_role
from ..services.compliance_service import (
    export_student_data,
    request_erasure,
    get_audit_trail,
    get_retention_policies,
    execute_retention_cleanup,
)

router = APIRouter(prefix="/api/compliance", tags=["Compliance & Privacy"])
_STAFF_ROLES = {"Registrar", "Administrator", "Department Coordinator"}


class ErasureRequest(BaseModel):
    student_id: str = Field(..., min_length=3, max_length=30)
    reason: Optional[str] = Field("Right to be forgotten request", max_length=500)


@router.get("/export/{student_id}")
async def export_data(student_id: str, request: Request):
    """Export all institutional data stored for a student in GDPR-compliant JSON format."""
    require_student_access(request, student_id)
    try:
        return export_student_data(student_id.upper().strip())
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate export: {str(e)}")


@router.post("/erasure")
async def process_erasure(body: ErasureRequest, request: Request):
    """Execute personal data anonymization and GDPR right-to-be-forgotten request."""
    require_student_access(request, body.student_id)
    try:
        return request_erasure(body.student_id.upper().strip(), body.reason or "Student privacy request")
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process erasure: {str(e)}")


@router.get("/audit-logs")
async def list_audit_logs(
    request: Request,
    actor_id: Optional[str] = Query(None),
    action: Optional[str] = Query(None),
    entity_type: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
):
    """Staff/Admin query of system audit logs and compliance actions."""
    require_any_role(request, _STAFF_ROLES)
    return {
        "audit_logs": get_audit_trail(
            actor_id=actor_id,
            action=action,
            entity_type=entity_type,
            limit=limit,
        )
    }


@router.get("/retention-policies")
async def list_retention_policies(request: Request):
    """Retrieve institutional data retention schedules."""
    require_any_role(request, _STAFF_ROLES)
    return {"policies": get_retention_policies()}


@router.post("/retention-cleanup")
async def run_retention_cleanup(request: Request):
    """Staff/Admin execution of automated data retention policy cleanup."""
    require_any_role(request, {"Administrator", "Registrar"})
    return execute_retention_cleanup()
