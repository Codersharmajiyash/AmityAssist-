"""Phase 12 campus-scoped configuration and lookup helpers."""

from __future__ import annotations

from typing import Any

from ..database.connection import get_connection


class CampusService:
    @staticmethod
    def list_campuses() -> list[dict[str, Any]]:
        rows = get_connection().execute(
            "SELECT code, name, city, active FROM campuses ORDER BY name"
        ).fetchall()
        return [dict(row) for row in rows]

    @staticmethod
    def procedure_rules(campus_code: str) -> list[dict[str, Any]]:
        conn = get_connection()
        campus = conn.execute("SELECT code FROM campuses WHERE code = ?", (campus_code.upper(),)).fetchone()
        if not campus:
            raise ValueError("Campus not found")
        rows = conn.execute(
            """SELECT campus_code, procedure_type, default_department, target_days, policy_note
               FROM campus_procedure_rules WHERE campus_code = ? ORDER BY procedure_type""",
            (campus_code.upper(),),
        ).fetchall()
        return [dict(row) for row in rows]

    @staticmethod
    def update_procedure_rule(campus_code: str, procedure_type: str, default_department: str, target_days: int, policy_note: str | None) -> dict[str, Any]:
        conn = get_connection()
        campus_code = campus_code.upper()
        if not conn.execute("SELECT 1 FROM campuses WHERE code = ?", (campus_code,)).fetchone():
            raise ValueError("Campus not found")
        if procedure_type not in {"withdrawal", "grievance", "scholarship"}:
            raise ValueError("Unsupported procedure type")
        if not conn.execute("SELECT 1 FROM departments WHERE name = ?", (default_department,)).fetchone():
            raise ValueError("Default department is not configured")
        conn.execute(
            """INSERT INTO campus_procedure_rules (campus_code, procedure_type, default_department, target_days, policy_note)
               VALUES (?, ?, ?, ?, ?)
               ON CONFLICT(campus_code, procedure_type) DO UPDATE SET
                 default_department = excluded.default_department,
                 target_days = excluded.target_days,
                 policy_note = excluded.policy_note""",
            (campus_code, procedure_type, default_department, target_days, policy_note),
        )
        conn.commit()
        return next(rule for rule in CampusService.procedure_rules(campus_code) if rule["procedure_type"] == procedure_type)

    @staticmethod
    def find_students(campus_code: str | None = None, query: str | None = None) -> list[dict[str, Any]]:
        conn = get_connection()
        clauses, params = [], []
        if campus_code:
            clauses.append("s.campus_code = ?")
            params.append(campus_code.upper())
        if query:
            clauses.append("(s.id LIKE ? OR s.name LIKE ? OR s.email LIKE ?)")
            value = f"%{query.strip()}%"
            params.extend([value, value, value])
        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        rows = conn.execute(
            f"""SELECT s.id, s.name, s.email, s.course, s.branch, s.semester, s.campus_code,
                       c.name AS campus_name
                FROM students s JOIN campuses c ON c.code = s.campus_code
                {where} ORDER BY s.name LIMIT 100""",
            params,
        ).fetchall()
        return [dict(row) for row in rows]
