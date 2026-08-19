"""Withdrawal workflow guidance and checklist helpers.

Phase 1 keeps the implementation self-contained while moving withdrawal
support away from a chatbot-only shape. Procedure content is seeded in SQLite
and exposed through structured APIs for the UI, kiosk, or future Flutter app.
"""

from __future__ import annotations

import uuid
from typing import Any

from ..database.connection import get_connection
from .audit_service import record_audit_event


PROCEDURE_CODE = "withdrawal"


def generate_reference() -> str:
    return "WD-" + str(uuid.uuid4())[:8].upper()


def get_withdrawal_guide() -> dict[str, Any]:
    conn = get_connection()
    steps = conn.execute(
        """SELECT step_number, title, description, department, timeline_text, status_after
           FROM procedure_steps
           WHERE procedure_code = ?
           ORDER BY step_number ASC""",
        (PROCEDURE_CODE,),
    ).fetchall()
    documents = conn.execute(
        """SELECT document_key, name, description, mandatory, applicable_reason, form_url
           FROM procedure_documents
           WHERE procedure_code = ?
           ORDER BY mandatory DESC, id ASC""",
        (PROCEDURE_CODE,),
    ).fetchall()
    forms = conn.execute(
        """SELECT form_key, name, description, download_url, issuing_department
           FROM procedure_forms
           WHERE procedure_code = ?
           ORDER BY id ASC""",
        (PROCEDURE_CODE,),
    ).fetchall()

    return {
        "procedure_code": PROCEDURE_CODE,
        "title": "Withdrawal Intelligence System",
        "summary": (
            "Structured guidance for students who want to understand, prepare, "
            "submit, and track an official university withdrawal request."
        ),
        "principle": (
            "UNIASSIST provides official procedure guidance and timeline bands. "
            "It does not predict approval, rejection, or exact refund dates."
        ),
        "steps": [dict(row) for row in steps],
        "documents": [_normalise_document(dict(row)) for row in documents],
        "forms": [dict(row) for row in forms],
        "departments": [
            "Student",
            "Academic Department",
            "Registrar Office",
            "Library",
            "Hostel Office",
            "Finance Office",
            "Accounts/Refund Desk",
        ],
        "official_timeline": [
            {
                "stage": "Initial verification",
                "timeline": "Generally 1-2 working days after submission.",
            },
            {
                "stage": "Department clearances",
                "timeline": "Generally 3-5 working days, depending on pending dues or records.",
            },
            {
                "stage": "Finance and refund processing",
                "timeline": "Generally 7-10 working days after all required clearances.",
            },
        ],
        "statuses": [
            "draft",
            "pending",
            "submitted",
            "under_review",
            "documents_pending",
            "department_clearance",
            "finance_processing",
            "completed",
            "rejected",
        ],
    }


def get_required_documents(reason: str | None = None) -> list[dict[str, Any]]:
    guide = get_withdrawal_guide()
    reason_text = (reason or "").lower()
    selected: list[dict[str, Any]] = []
    for document in guide["documents"]:
        applicability = str(document.get("applicable_reason") or "all").lower()
        if applicability == "all" or applicability in reason_text:
            selected.append(document)

    keys = {item["document_key"] for item in selected}
    for document in guide["documents"]:
        if document["mandatory"] and document["document_key"] not in keys:
            selected.append(document)
    return selected


def create_withdrawal_request(student_id: str, reason: str, intent: str) -> str:
    conn = get_connection()
    reference = generate_reference()
    conn.execute(
        """INSERT INTO withdrawal_requests
           (student_id, reason, detected_intent, status, reference_no, current_step)
           VALUES (?, ?, ?, 'pending', ?, 1)""",
        (student_id, reason, intent, reference),
    )
    request_id = conn.execute("SELECT last_insert_rowid() AS id").fetchone()["id"]

    for document in get_required_documents(reason):
        conn.execute(
            """INSERT INTO withdrawal_checklist_items
               (request_id, document_key, label, description, status)
               VALUES (?, ?, ?, ?, 'pending')""",
            (
                request_id,
                document["document_key"],
                document["name"],
                document["description"],
            ),
        )

    conn.execute(
        """INSERT INTO workflow_events
           (request_id, status, title, description, actor)
           VALUES (?, 'submitted', 'Withdrawal request submitted',
                   'Student confirmed intent and the official checklist was generated.',
                   'student')""",
        (request_id,),
    )
    conn.commit()
    record_audit_event(
        action="withdrawal.submitted",
        entity_type="withdrawal_request",
        entity_id=str(request_id),
        actor_id=student_id,
        actor_role="Student",
        metadata={"reference_no": reference},
    )
    return reference


def get_latest_withdrawal_status(student_id: str) -> dict[str, Any]:
    conn = get_connection()
    row = conn.execute(
        """SELECT *
           FROM withdrawal_requests
           WHERE student_id = ?
           ORDER BY timestamp DESC
           LIMIT 1""",
        (student_id.upper().strip(),),
    ).fetchone()
    if not row:
        return {"has_request": False, "guide": get_withdrawal_guide()}

    request = dict(row)
    request_id = request["id"]
    checklist_rows = conn.execute(
        """SELECT id, document_key, label, description, status, updated_at
           FROM withdrawal_checklist_items
           WHERE request_id = ?
           ORDER BY id ASC""",
        (request_id,),
    ).fetchall()
    event_rows = conn.execute(
        """SELECT status, title, description, actor, timestamp
           FROM workflow_events
           WHERE request_id = ?
           ORDER BY timestamp ASC, id ASC""",
        (request_id,),
    ).fetchall()

    return {
        "has_request": True,
        "request": request,
        "checklist": [dict(row) for row in checklist_rows],
        "events": [dict(row) for row in event_rows],
        "guide": get_withdrawal_guide(),
    }


def _normalise_document(document: dict[str, Any]) -> dict[str, Any]:
    document["mandatory"] = bool(document.get("mandatory"))
    return document
