"""Institution isolation for admin-created procedures."""

import sqlite3
from unittest.mock import patch

from backend.services.procedure_service import ProcedureService


def _legacy_connection():
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.executescript(
        """
        CREATE TABLE institution_config (key TEXT PRIMARY KEY, value TEXT);
        INSERT INTO institution_config VALUES ('institution_name', 'Campus A');
        CREATE TABLE custom_procedures (
            id TEXT PRIMARY KEY, title TEXT NOT NULL, department TEXT NOT NULL,
            category TEXT NOT NULL, description TEXT, sla_days INTEGER NOT NULL DEFAULT 7,
            required_docs TEXT NOT NULL DEFAULT '[]', is_active INTEGER NOT NULL DEFAULT 1,
            created_by TEXT NOT NULL DEFAULT 'STAFF', created_at TEXT, updated_at TEXT
        );
        CREATE TABLE custom_procedure_steps (
            id TEXT PRIMARY KEY, procedure_id TEXT, step_number INTEGER, title TEXT,
            description TEXT, responsible_desk TEXT, sla_days INTEGER, created_at TEXT
        );
        INSERT INTO custom_procedures
            (id, title, department, category, description, required_docs, created_at, updated_at)
            VALUES ('legacy-a', 'Campus A process', 'Office A', 'STUDENT', '', '[]', 't', 't');
        """
    )
    return conn


def test_legacy_procedures_are_scoped_and_new_procedures_follow_active_institution():
    conn = _legacy_connection()
    with patch("backend.services.procedure_service.get_connection", return_value=conn):
        # The additive migration attaches legacy rows to the institution active
        # at migration time without changing their procedure text or steps.
        assert [p["id"] for p in ProcedureService.list_procedures()] == ["legacy-a"]
        assert conn.execute(
            "SELECT institution_name FROM custom_procedures WHERE id = 'legacy-a'"
        ).fetchone()[0] == "Campus A"

        conn.execute("UPDATE institution_config SET value = 'Campus B' WHERE key = 'institution_name'")
        conn.commit()
        created = ProcedureService.create_procedure(
            title="Campus B process",
            department="Office B",
            category="STUDENT",
        )
        visible = ProcedureService.list_procedures()
        assert [p["id"] for p in visible] == [created["id"]]
        assert created["institution_name"] == "Campus B"

        conn.execute("UPDATE institution_config SET value = 'Campus A' WHERE key = 'institution_name'")
        conn.commit()
        assert [p["id"] for p in ProcedureService.list_procedures()] == ["legacy-a"]
    conn.close()
