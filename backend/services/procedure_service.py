"""
Phase 30: Interactive Procedure Setup Wizard Service.
Enables university staff/administrators to dynamically create, configure,
and manage bespoke university procedures, approval steps, SLA windows,
and document checklists.
"""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from ..database.connection import get_connection


class ProcedureService:
    """CRUD service for custom university procedures and multi-desk steps."""

    @staticmethod
    def _now_iso() -> str:
        return datetime.now(timezone.utc).isoformat()

    @classmethod
    def list_procedures(
        cls,
        department: Optional[str] = None,
        category: Optional[str] = None,
        active_only: bool = False,
    ) -> List[Dict[str, Any]]:
        """List custom procedures with step counts and document checklists."""
        conn = get_connection()
        query = "SELECT * FROM custom_procedures WHERE 1=1"
        params: List[Any] = []

        if active_only:
            query += " AND is_active = 1"
        if department:
            query += " AND LOWER(department) = LOWER(?)"
            params.append(department)
        if category:
            query += " AND LOWER(category) = LOWER(?)"
            params.append(category)

        query += " ORDER BY created_at DESC"
        rows = conn.execute(query, params).fetchall()

        results = []
        for r in rows:
            proc_id = r["id"]
            # Fetch steps
            step_rows = conn.execute(
                "SELECT * FROM custom_procedure_steps WHERE procedure_id = ? ORDER BY step_number ASC",
                (proc_id,),
            ).fetchall()

            steps = [
                {
                    "id": s["id"],
                    "step_number": s["step_number"],
                    "title": s["title"],
                    "description": s["description"] or "",
                    "responsible_desk": s["responsible_desk"],
                    "sla_days": s["sla_days"],
                    "created_at": s["created_at"],
                }
                for s in step_rows
            ]

            try:
                docs = json.loads(r["required_docs"]) if r["required_docs"] else []
            except Exception:
                docs = []

            results.append({
                "id": r["id"],
                "title": r["title"],
                "department": r["department"],
                "category": r["category"],
                "description": r["description"] or "",
                "sla_days": r["sla_days"],
                "required_docs": docs,
                "is_active": bool(r["is_active"]),
                "created_by": r["created_by"],
                "created_at": r["created_at"],
                "updated_at": r["updated_at"],
                "steps": steps,
                "total_steps": len(steps),
            })
        return results

    @classmethod
    def get_procedure(cls, procedure_id: str) -> Optional[Dict[str, Any]]:
        """Fetch a single custom procedure by its identifier with all step details."""
        conn = get_connection()
        row = conn.execute(
            "SELECT * FROM custom_procedures WHERE id = ?", (procedure_id,)
        ).fetchone()
        if not row:
            return None

        step_rows = conn.execute(
            "SELECT * FROM custom_procedure_steps WHERE procedure_id = ? ORDER BY step_number ASC",
            (procedure_id,),
        ).fetchall()

        steps = [
            {
                "id": s["id"],
                "step_number": s["step_number"],
                "title": s["title"],
                "description": s["description"] or "",
                "responsible_desk": s["responsible_desk"],
                "sla_days": s["sla_days"],
                "created_at": s["created_at"],
            }
            for s in step_rows
        ]

        try:
            docs = json.loads(row["required_docs"]) if row["required_docs"] else []
        except Exception:
            docs = []

        return {
            "id": row["id"],
            "title": row["title"],
            "department": row["department"],
            "category": row["category"],
            "description": row["description"] or "",
            "sla_days": row["sla_days"],
            "required_docs": docs,
            "is_active": bool(row["is_active"]),
            "created_by": row["created_by"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
            "steps": steps,
            "total_steps": len(steps),
        }

    @classmethod
    def create_procedure(
        cls,
        title: str,
        department: str,
        category: str,
        description: str = "",
        sla_days: int = 7,
        required_docs: Optional[List[str]] = None,
        steps: Optional[List[Dict[str, Any]]] = None,
        created_by: str = "STAFF",
    ) -> Dict[str, Any]:
        """Create a new procedure with its sequential steps and checklist documents."""
        title = title.strip()
        department = department.strip()
        category = category.strip().upper()
        if not title:
            raise ValueError("Procedure title cannot be empty")
        if not department:
            raise ValueError("Department cannot be empty")
        if not category:
            raise ValueError("Category cannot be empty")
        if sla_days < 1:
            raise ValueError("SLA days must be at least 1 day")

        proc_id = f"proc-{uuid.uuid4().hex[:8]}"
        docs_json = json.dumps(required_docs or [])
        now = cls._now_iso()

        conn = get_connection()
        conn.execute(
            """
            INSERT INTO custom_procedures (
                id, title, department, category, description, sla_days,
                required_docs, is_active, created_by, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
            """,
            (proc_id, title, department, category, description.strip(), sla_days, docs_json, created_by, now, now),
        )

        created_steps = []
        if steps:
            for idx, s in enumerate(steps, start=1):
                step_id = f"step-{uuid.uuid4().hex[:8]}"
                step_title = s.get("title", f"Step {idx}").strip()
                step_desc = s.get("description", "").strip()
                step_desk = s.get("responsible_desk", "Department Desk").strip()
                step_sla = int(s.get("sla_days", 2))

                conn.execute(
                    """
                    INSERT INTO custom_procedure_steps (
                        id, procedure_id, step_number, title, description, responsible_desk, sla_days, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (step_id, proc_id, idx, step_title, step_desc, step_desk, step_sla, now),
                )
                created_steps.append({
                    "id": step_id,
                    "step_number": idx,
                    "title": step_title,
                    "description": step_desc,
                    "responsible_desk": step_desk,
                    "sla_days": step_sla,
                    "created_at": now,
                })

        conn.commit()

        return {
            "id": proc_id,
            "title": title,
            "department": department,
            "category": category,
            "description": description.strip(),
            "sla_days": sla_days,
            "required_docs": required_docs or [],
            "is_active": True,
            "created_by": created_by,
            "created_at": now,
            "updated_at": now,
            "steps": created_steps,
            "total_steps": len(created_steps),
        }

    @classmethod
    def delete_procedure(cls, procedure_id: str) -> bool:
        """Permanently delete a procedure and its associated steps."""
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM custom_procedure_steps WHERE procedure_id = ?", (procedure_id,))
        cursor.execute("DELETE FROM custom_procedures WHERE id = ?", (procedure_id,))
        conn.commit()
        return cursor.rowcount > 0
