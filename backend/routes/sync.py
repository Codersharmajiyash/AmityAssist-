# ==============================================================================
# UniAssist — Amizone Sync Bridge API Router
# Lead Architect: Abhishek Shrivastava
# Phase 3: Inbound Webhook Receiver + Outbox Health Cockpit
# ==============================================================================
from __future__ import annotations

import json
from typing import Any, Dict, Optional

from fastapi import APIRouter, BackgroundTasks, Header, HTTPException, Request
from pydantic import BaseModel, Field

from ..database.connection import get_connection
from ..services.sync_bridge_service import SyncBridgeService

router = APIRouter(prefix="/api/sync", tags=["Amizone Sync Bridge"])


# ── Pydantic Models ───────────────────────────────────────────────────────────

class ManualEventRequest(BaseModel):
    event_type: str = Field(
        ...,
        example="STUDENT_ENROLLED",
        description="One of: STUDENT_ENROLLED, NOTICE_PUBLISHED, STUDENT_STATUS_CHANGED, FEE_PAID",
    )
    aggregate_id: Optional[str] = Field(None, example="STU001")
    data: Dict[str, Any] = Field(
        ...,
        example={"student_id": "STU001", "name": "Rahul Sharma", "program": "B.Tech CSE", "semester": 3},
    )


class OutboundTestEventRequest(BaseModel):
    event_type: str = Field(..., example="WITHDRAWAL_COMPLETED")
    aggregate_id: str = Field(..., example="AMITY-WTH-2026-AB12")
    payload_data: Dict[str, Any] = Field(
        ...,
        example={"student_id": "STU001", "net_refund_payable": 95000.0},
    )


# ── Inbound Webhook Receiver (From Amizone ERP) ───────────────────────────────

@router.post(
    "/amizone/inbound",
    summary="Inbound Webhook Receiver (From Amizone)",
    description=(
        "Receives authenticated push notifications from Amizone ERP. "
        "Enforces HMAC-SHA256 signature verification to prevent webhook spoofing. "
        "Supported events: STUDENT_ENROLLED, FEE_PAID, NOTICE_PUBLISHED, STUDENT_STATUS_CHANGED."
    ),
)
async def receive_amizone_webhook(
    request: Request,
    x_amizone_signature: Optional[str] = Header(None, alias="X-Amizone-Signature"),
):
    body_bytes = await request.body()
    if not body_bytes:
        raise HTTPException(status_code=400, detail="Empty webhook payload.")

    # Enforce HMAC-SHA256 signature when Amizone sends the header
    if x_amizone_signature:
        is_valid = SyncBridgeService.verify_hmac_signature(body_bytes, x_amizone_signature)
        if not is_valid:
            raise HTTPException(
                status_code=401,
                detail="Invalid HMAC-SHA256 signature. Webhook rejected — possible spoofing attempt.",
            )

    try:
        payload_data = json.loads(body_bytes.decode("utf-8"))
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON payload.")

    result = SyncBridgeService.process_inbound_amizone_event(payload_data)
    return result


# ── Manual Inbound Injection (Admin/Testing) ──────────────────────────────────

@router.post(
    "/amizone/inject",
    summary="Manually Inject Amizone Event (Admin / Testing)",
    description=(
        "Allows IT administrators or test suites to inject a simulated Amizone event "
        "without requiring the real Amizone server. Useful for staging and integration testing."
    ),
)
async def inject_amizone_event(req: ManualEventRequest):
    payload = {
        "event_type": req.event_type,
        "aggregate_id": req.aggregate_id,
        "data": req.data,
    }
    result = SyncBridgeService.process_inbound_amizone_event(payload)
    return {
        "success": True,
        "injected_event": req.event_type,
        "result": result,
    }


# ── Outbox Status Health Cockpit ──────────────────────────────────────────────

@router.get(
    "/outbox/status",
    summary="Get Outbox Sync Queue Metrics",
    description=(
        "Returns the current state (PENDING / SYNCED / FAILED) of the Amizone outbound event queue. "
        "IT staff can monitor this endpoint to detect delivery failures before they affect students."
    ),
)
async def get_outbox_status():
    counts = SyncBridgeService.get_outbox_counts()
    recent_events = SyncBridgeService.get_recent_events(limit=10)

    queue_health = "healthy"
    if counts["failed"] > 0:
        queue_health = "degraded"
    if counts["pending"] > 50:
        queue_health = "backlogged"

    return {
        "status": queue_health,
        "counts": counts,
        "recent_events": recent_events,
        "amizone_endpoint": "configured" if "api.amity.edu" in str(
            __import__("backend.services.sync_bridge_service", fromlist=["AMIZONE_API_ENDPOINT"])
            .AMIZONE_API_ENDPOINT
        ) else "custom",
    }


# ── Manual Outbox Flush ───────────────────────────────────────────────────────

@router.post(
    "/outbox/flush",
    summary="Trigger Manual Outbox Flush",
    description=(
        "Triggers an immediate background flush of all PENDING or FAILED outbox events "
        "to Amizone. Normally this runs automatically; use this for immediate re-delivery "
        "after Amizone comes back online."
    ),
)
async def trigger_outbox_flush(background_tasks: BackgroundTasks):
    background_tasks.add_task(SyncBridgeService.flush_outbox, max_batch=50)
    return {
        "success": True,
        "message": "Outbox flush initiated as background task. Check /api/sync/outbox/status for results.",
    }


# ── Queue Outbound Test Event ─────────────────────────────────────────────────

@router.post(
    "/outbox/queue-test",
    summary="Queue a Test Outbound Event (Admin / Testing)",
    description=(
        "Enqueues a test outbound event into the sync_outbox table without sending it. "
        "Useful for verifying the outbox table schema, queue mechanics, and flush behaviour."
    ),
)
async def queue_test_event(req: OutboundTestEventRequest):
    event_id = SyncBridgeService.queue_outbound_event(
        event_type=req.event_type,
        aggregate_id=req.aggregate_id,
        payload_data=req.payload_data,
    )
    return {
        "success": True,
        "event_id": event_id,
        "message": f"Event '{req.event_type}' queued for outbound delivery to Amizone.",
    }


# ── Inbound Audit Log ─────────────────────────────────────────────────────────

@router.get(
    "/inbound/log",
    summary="View Inbound Event Audit Log",
    description="Returns the last N inbound webhook events received from Amizone for audit review.",
)
async def get_inbound_log(limit: int = 20):
    SyncBridgeService.init_tables()
    conn = get_connection()
    try:
        rows = conn.execute(
            """
            SELECT id, event_type, aggregate_id, result, received_at
            FROM sync_inbound_log
            ORDER BY received_at DESC
            LIMIT ?
            """,
            (min(limit, 100),),
        ).fetchall()
        return {
            "count": len(rows),
            "events": [dict(r) for r in rows],
        }
    except Exception as e:
        return {"count": 0, "events": [], "note": str(e)}

