"""Phase 12 multi-campus configuration endpoints."""

from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel, Field

from ..security.rbac import require_any_role
from ..services.campus_service import CampusService

router = APIRouter(prefix="/api/campuses", tags=["Campuses"])
_STAFF_ROLES = {"Registrar", "Administrator", "Department Coordinator", "Finance Department", "Scholarship Department", "Examination Cell"}


class CampusProcedureRuleUpdate(BaseModel):
    default_department: str = Field(min_length=2, max_length=100)
    target_days: int = Field(ge=1, le=365)
    policy_note: str | None = Field(default=None, max_length=1000)


def _authorise(request: Request) -> None:
    require_any_role(request, _STAFF_ROLES)


@router.get("")
def list_campuses(request: Request):
    _authorise(request)
    return CampusService.list_campuses()


@router.get("/students")
def cross_campus_students(request: Request, campus_code: str | None = None, q: str | None = Query(default=None, max_length=100)):
    _authorise(request)
    return CampusService.find_students(campus_code, q)


@router.get("/{campus_code}/procedure-rules")
def get_procedure_rules(campus_code: str, request: Request):
    _authorise(request)
    try:
        return CampusService.procedure_rules(campus_code)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.put("/{campus_code}/procedure-rules/{procedure_type}")
def update_procedure_rule(campus_code: str, procedure_type: str, body: CampusProcedureRuleUpdate, request: Request):
    _authorise(request)
    try:
        return CampusService.update_procedure_rule(campus_code, procedure_type, body.default_department, body.target_days, body.policy_note)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
