"""Phase 11 staff analytics and report export endpoints."""

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import Response

from ..security.rbac import require_any_role
from ..services.reporting_service import ReportingService

router = APIRouter(prefix="/api/reports", tags=["Reports"])
_STAFF_ROLES = {"Registrar", "Administrator", "Department Coordinator", "Finance Department", "Scholarship Department", "Examination Cell"}


def _authorise(request: Request) -> None:
    require_any_role(request, _STAFF_ROLES)


@router.get("/analytics")
def analytics_snapshot(request: Request):
    _authorise(request)
    return ReportingService.analytics_snapshot()


@router.get("/funnel")
def journey_funnel(request: Request):
    _authorise(request)
    return ReportingService.journey_funnel()


@router.get("/bottlenecks")
def workflow_bottlenecks(request: Request):
    _authorise(request)
    return ReportingService.bottlenecks()


@router.get("/export")
def export_report(request: Request, report: str = "analytics", format: str = "csv"):
    _authorise(request)
    reports = {
        "analytics": ("Analytics snapshot", ReportingService.analytics_snapshot),
        "funnel": ("Journey funnel", ReportingService.journey_funnel),
        "bottlenecks": ("Workflow bottlenecks", ReportingService.bottlenecks),
    }
    if report not in reports or format not in {"csv", "pdf"}:
        raise HTTPException(status_code=400, detail="report must be analytics, funnel, or bottlenecks; format must be csv or pdf.")
    title, builder = reports[report]
    data = builder()
    if format == "csv":
        return Response(
            ReportingService.csv_export(data), media_type="text/csv",
            headers={"Content-Disposition": f'attachment; filename="{report}.csv"'},
        )
    return Response(
        ReportingService.pdf_export(title, data), media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{report}.pdf"'},
    )
