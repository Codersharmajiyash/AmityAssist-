import json
import pytest
from backend.services.sync_bridge_service import SyncBridgeService
from backend.services.withdrawal_workflow import (
    offset_dues_from_caution_deposit,
    create_withdrawal_request,
)
from backend.database.connection import get_connection

def test_hmac_signature_generation_and_verification():
    payload = b'{"event_type": "TEST", "data": {"key": "value"}}'
    sig = SyncBridgeService.generate_hmac_signature(payload)
    assert isinstance(sig, str)
    assert len(sig) == 64
    assert SyncBridgeService.verify_hmac_signature(payload, sig) is True
    assert SyncBridgeService.verify_hmac_signature(payload, "invalid_signature") is False

def test_inbound_student_enrolled():
    body = {
        "event_type": "STUDENT_ENROLLED",
        "data": {
            "student_id": "AMZ999",
            "name": "Arjun Malhotra",
            "course": "B.Tech AI",
            "semester": 1,
        }
    }
    result = SyncBridgeService.process_inbound_amizone_event(body)
    assert result["status"] == "success"

    conn = get_connection()
    student = conn.execute("SELECT * FROM students WHERE id = 'AMZ999'").fetchone()
    assert student is not None
    assert student["name"] == "Arjun Malhotra"
    assert student["course"] == "B.Tech AI"

def test_inbound_notice_published():
    result = SyncBridgeService.process_inbound_amizone_event({
        "event_type": "NOTICE_PUBLISHED",
        "data": {
            "title": "Registration Deadline Extended",
            "content": "All students must submit forms by Friday.",
            "category": "academics"
        }
    })
    assert result["status"] == "success"

def test_inbound_fee_paid():
    result = SyncBridgeService.process_inbound_amizone_event({
        "event_type": "FEE_PAID",
        "data": {
            "student_id": "STU001",
            "amount": 55000.0,
            "receipt_no": "RCP-2026-001"
        }
    })
    assert result["status"] == "success"

def test_inbound_student_status_changed():
    result = SyncBridgeService.process_inbound_amizone_event({
        "event_type": "STUDENT_STATUS_CHANGED",
        "data": {
            "student_id": "STU001",
            "status": "SUSPENDED"
        }
    })
    assert result["status"] == "success"

def test_outbox_queue_and_counts():
    event_id = SyncBridgeService.queue_outbound_event(
        event_type="CLEARANCE_COMPLETED",
        aggregate_id="REF-TEST-001",
        payload_data={"student_id": "STU001", "cleared": True}
    )
    assert event_id.startswith("EVT-")

    counts = SyncBridgeService.get_outbox_counts()
    assert counts["pending"] >= 1

    recent = SyncBridgeService.get_recent_events(limit=5)
    assert len(recent) >= 1
    assert any(e["id"] == event_id for e in recent)

def test_outbox_status_transitions():
    SyncBridgeService.init_tables()
    conn = get_connection()
    
    event_id = SyncBridgeService.queue_outbound_event(
        event_type="STATUS_CHECK_TEST",
        aggregate_id="REF-STATUS-1",
        payload_data={"val": 123}
    )
    
    # Mark as SYNCED
    now = SyncBridgeService._now_iso()
    conn.execute(
        "UPDATE sync_outbox SET status = 'SYNCED', synced_at = ? WHERE id = ?",
        (now, event_id)
    )
    conn.commit()
    
    row = conn.execute("SELECT * FROM sync_outbox WHERE id = ?", (event_id,)).fetchone()
    assert row["status"] == "SYNCED"
    assert row["synced_at"] == now

def test_withdrawal_workflow_sync_hook():
    ref = create_withdrawal_request("STU001", "Transferring to other university", "general")
    assert ref is not None

    # Apply caution deposit offset (Phase 3 hook)
    offset_res = offset_dues_from_caution_deposit(
        reference_no=ref,
        department="LIBRARY",
        amount=200.0,
        reason="Lost book fine",
        authorized_by="Chief Librarian"
    )
    assert offset_res["status"] == "CLEARED"

    # Verify FINANCIAL_OFFSET_APPLIED event was queued in sync_outbox
    conn = get_connection()
    event_row = conn.execute(
        "SELECT * FROM sync_outbox WHERE event_type = 'FINANCIAL_OFFSET_APPLIED' AND aggregate_id = ? ORDER BY created_at DESC LIMIT 1",
        (ref,)
    ).fetchone()
    assert event_row is not None
    payload = json.loads(event_row["payload"])
    assert payload["data"]["offset_amount"] == 200.0
    assert payload["data"]["department"] == "LIBRARY"
