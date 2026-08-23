"""
Compliance and Data Privacy Service (Phase 19).

Provides GDPR / statutory privacy controls:
- Personal Data Export (Right to Access & Portability)
- Data Erasure / Anonymization (Right to be Forgotten)
- Audit Trail Queries
- Data Retention Policy Lifecycle Enforcement
"""

from datetime import datetime, timezone, timedelta
import json
import uuid
from typing import Dict, Any, List, Optional
from backend.database.connection import get_connection
from backend.services.audit_service import record_audit_event


def export_student_data(student_id: str) -> Dict[str, Any]:
    """Compile and export all data associated with a student in portable JSON format."""
    conn = get_connection()
    cursor = conn.cursor()

    student_row = cursor.execute("SELECT * FROM students WHERE id = ?", (student_id,)).fetchone()
    if not student_row:
        raise ValueError(f"Student '{student_id}' not found.")

    student_data = dict(student_row)

    conversations = [
        dict(row) for row in cursor.execute(
            "SELECT id, message, sender, detected_intent, sentiment, timestamp FROM conversations WHERE student_id = ? ORDER BY timestamp ASC",
            (student_id,)
        ).fetchall()
    ]

    grievances = [
        dict(row) for row in cursor.execute(
            "SELECT id, category, description, status, resolution, timestamp FROM grievances WHERE student_id = ?",
            (student_id,)
        ).fetchall()
    ]

    scholarships = [
        dict(row) for row in cursor.execute(
            "SELECT sa.id, sa.scholarship_id, s.name as scholarship_name, sa.status, sa.timestamp "
            "FROM scholarship_applications sa "
            "JOIN scholarships s ON sa.scholarship_id = s.id "
            "WHERE sa.student_id = ?",
            (student_id,)
        ).fetchall()
    ]

    exams = [
        dict(row) for row in cursor.execute(
            "SELECT subject_code, subject_name, exam_date, grade, type, backpaper_status FROM examinations WHERE student_id = ?",
            (student_id,)
        ).fetchall()
    ]

    documents = [
        dict(row) for row in cursor.execute(
            "SELECT id, file_name, classification, verification_status, verification_notes, timestamp FROM documents WHERE student_id = ?",
            (student_id,)
        ).fetchall()
    ]

    workflows = [
        dict(row) for row in cursor.execute(
            "SELECT id, procedure_type, status, assigned_department, campus_code, created_at, updated_at FROM workflows WHERE student_id = ?",
            (student_id,)
        ).fetchall()
    ]

    notifications = [
        dict(row) for row in cursor.execute(
            "SELECT id, notification_type, title, message, priority, read_status, created_at FROM notifications WHERE student_id = ?",
            (student_id,)
        ).fetchall()
    ]

    record_audit_event(
        action="DATA_EXPORT",
        entity_type="student",
        entity_id=student_id,
        actor_id=student_id,
        actor_role="Student",
        metadata={"exported_at": datetime.now(timezone.utc).isoformat()}
    )

    return {
        "export_metadata": {
            "format_version": "1.0",
            "exported_at": datetime.now(timezone.utc).isoformat(),
            "compliance_standard": "GDPR / University Privacy Regulation",
            "student_id": student_id,
        },
        "student_profile": student_data,
        "conversations": conversations,
        "grievances": grievances,
        "scholarship_applications": scholarships,
        "examinations": exams,
        "documents": documents,
        "workflows": workflows,
        "notifications": notifications,
    }


def request_erasure(student_id: str, reason: str = "Student privacy request") -> Dict[str, Any]:
    """Execute right-to-erasure / anonymization for a student while preserving workflow audit integrity."""
    conn = get_connection()
    cursor = conn.cursor()

    student_row = cursor.execute("SELECT * FROM students WHERE id = ?", (student_id,)).fetchone()
    if not student_row:
        raise ValueError(f"Student '{student_id}' not found.")

    req_id = str(uuid.uuid4())
    cursor.execute(
        "INSERT INTO compliance_requests (id, student_id, request_type, status, reason, metadata, requested_at, completed_at) "
        "VALUES (?, ?, 'erasure', 'completed', ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
        (req_id, student_id, reason, json.dumps({"initiated_by": student_id}))
    )

    # Anonymize student profile PII
    anonymized_name = f"Anonymized Student ({student_id})"
    anonymized_email = f"erased_{student_id.lower()}@privacy.uniassist.local"
    cursor.execute(
        "UPDATE students SET name = ?, email = ?, interests = NULL, academic_performance = 'Standard' WHERE id = ?",
        (anonymized_name, anonymized_email, student_id)
    )

    # Scrub OCR text while keeping verification audit flags
    cursor.execute(
        "UPDATE documents SET ocr_data = json_object('scrubbed', 1, 'reason', 'GDPR erasure') WHERE student_id = ?",
        (student_id,)
    )

    conn.commit()

    record_audit_event(
        action="DATA_ERASURE_ANONYMIZATION",
        entity_type="student",
        entity_id=student_id,
        actor_id=student_id,
        actor_role="Student",
        metadata={"request_id": req_id, "reason": reason}
    )

    return {
        "request_id": req_id,
        "student_id": student_id,
        "status": "completed",
        "message": f"Personal identifying information for student {student_id} has been securely anonymized.",
        "completed_at": datetime.now(timezone.utc).isoformat(),
    }


def get_audit_trail(
    actor_id: Optional[str] = None,
    action: Optional[str] = None,
    entity_type: Optional[str] = None,
    limit: int = 50
) -> List[Dict[str, Any]]:
    """Query audit logs with optional filters."""
    conn = get_connection()
    cursor = conn.cursor()

    query = "SELECT id, actor_id, actor_role, action, entity_type, entity_id, metadata, timestamp FROM audit_logs WHERE 1=1"
    params: List[Any] = []

    if actor_id:
        query += " AND actor_id = ?"
        params.append(actor_id)
    if action:
        query += " AND action = ?"
        params.append(action)
    if entity_type:
        query += " AND entity_type = ?"
        params.append(entity_type)

    query += " ORDER BY id DESC LIMIT ?"
    params.append(limit)

    rows = cursor.execute(query, params).fetchall()
    return [dict(row) for row in rows]


def get_retention_policies() -> List[Dict[str, Any]]:
    """Retrieve all data retention policies."""
    conn = get_connection()
    cursor = conn.cursor()
    rows = cursor.execute("SELECT entity_name, retention_days, description, last_cleanup_at FROM data_retention_policies").fetchall()
    return [dict(row) for row in rows]


def execute_retention_cleanup() -> Dict[str, Any]:
    """Enforce data retention limits according to configured policies."""
    conn = get_connection()
    cursor = conn.cursor()

    policies = get_retention_policies()
    cleanup_summary = {}

    for policy in policies:
        entity = policy["entity_name"]
        days = policy["retention_days"]
        cutoff_date = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d %H:%M:%S")

        deleted_count = 0
        if entity == "conversations":
            cursor.execute("DELETE FROM conversations WHERE timestamp < ?", (cutoff_date,))
            deleted_count = cursor.rowcount
        elif entity == "notifications":
            cursor.execute("DELETE FROM notifications WHERE created_at < ?", (cutoff_date,))
            deleted_count = cursor.rowcount
        elif entity == "notification_logs":
            cursor.execute("DELETE FROM notification_logs WHERE timestamp < ?", (cutoff_date,))
            deleted_count = cursor.rowcount

        cursor.execute(
            "UPDATE data_retention_policies SET last_cleanup_at = CURRENT_TIMESTAMP WHERE entity_name = ?",
            (entity,)
        )
        cleanup_summary[entity] = {
            "retention_days": days,
            "cutoff_date": cutoff_date,
            "records_purged": max(deleted_count, 0)
        }

    conn.commit()

    record_audit_event(
        action="RETENTION_CLEANUP",
        entity_type="system",
        entity_id="retention_policy",
        actor_id="system_cron",
        actor_role="Administrator",
        metadata=cleanup_summary
    )

    return {
        "status": "success",
        "executed_at": datetime.now(timezone.utc).isoformat(),
        "summary": cleanup_summary,
    }
