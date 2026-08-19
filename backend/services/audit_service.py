"""Audit logging service for security-sensitive workflow actions."""

from __future__ import annotations

import json
from typing import Any

from ..database.connection import get_connection


def record_audit_event(
    action: str,
    entity_type: str,
    entity_id: str | None = None,
    actor_id: str | None = None,
    actor_role: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> None:
    conn = get_connection()
    conn.execute(
        """INSERT INTO audit_logs
           (actor_id, actor_role, action, entity_type, entity_id, metadata)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (
            actor_id,
            actor_role,
            action,
            entity_type,
            entity_id,
            json.dumps(metadata or {}),
        ),
    )
    conn.commit()
