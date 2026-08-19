"""Repository functions for withdrawal workflow persistence."""

from __future__ import annotations

from typing import Any

from ..database.connection import get_connection


class WithdrawalRepository:
    def latest_for_student(self, student_id: str) -> dict[str, Any] | None:
        row = get_connection().execute(
            """SELECT *
               FROM withdrawal_requests
               WHERE student_id = ?
               ORDER BY timestamp DESC
               LIMIT 1""",
            (student_id.upper().strip(),),
        ).fetchone()
        return dict(row) if row else None

    def list_checklist(self, request_id: int) -> list[dict[str, Any]]:
        rows = get_connection().execute(
            """SELECT *
               FROM withdrawal_checklist_items
               WHERE request_id = ?
               ORDER BY id ASC""",
            (request_id,),
        ).fetchall()
        return [dict(row) for row in rows]


withdrawal_repository = WithdrawalRepository()
