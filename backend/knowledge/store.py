"""SQLite persistence for the unified knowledge base.

Tables
  kb_offices(id, json)
  kb_ordinances(code, title)
  kb_procedures(id, json, is_custom, version, content_hash, updated_at)

Rules
  * sync_seed() refreshes seed rows when data.py changes, and NEVER touches is_custom=1 rows.
  * upsert_procedure() is the ONLY write path for the wizard and handbook ingestion.
    It validates against the office and ordinance registries first, so bad data is rejected
    at write time instead of surfacing later as a wrong answer.
"""

from __future__ import annotations

import json
import sqlite3
from dataclasses import asdict
from datetime import datetime, timezone

from .schema import Office, Ordinance, Procedure, validate_kb, validate_procedure


class KnowledgeError(ValueError):
    pass


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def init_kb(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS kb_offices (id TEXT PRIMARY KEY, json TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS kb_ordinances (code TEXT PRIMARY KEY, title TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS kb_procedures (
            id TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            is_custom INTEGER NOT NULL DEFAULT 0,
            version INTEGER NOT NULL DEFAULT 1,
            content_hash TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """
    )
    conn.commit()


def sync_seed(conn: sqlite3.Connection, procs: list[Procedure], offices: list[Office],
              ordinances: list[Ordinance]) -> dict[str, int]:
    """Make the DB match data.py for seed rows. Returns counts of added/updated/unchanged."""
    errs = validate_kb(procs, offices, ordinances)
    if errs:
        raise KnowledgeError("Seed data invalid:\n  " + "\n  ".join(errs))
    init_kb(conn)

    for o in offices:
        conn.execute("INSERT OR REPLACE INTO kb_offices (id, json) VALUES (?, ?)",
                     (o.id, json.dumps(asdict(o), ensure_ascii=False)))
    for c in ordinances:
        conn.execute("INSERT OR REPLACE INTO kb_ordinances (code, title) VALUES (?, ?)", (c.code, c.title))

    stats = {"added": 0, "updated": 0, "unchanged": 0, "skipped_custom": 0}
    for p in procs:
        row = conn.execute("SELECT is_custom, content_hash, version FROM kb_procedures WHERE id = ?", (p.id,)).fetchone()
        h = p.content_hash()
        if row is None:
            p.version = 1
            conn.execute(
                "INSERT INTO kb_procedures (id, json, is_custom, version, content_hash, updated_at) VALUES (?,?,0,?,?,?)",
                (p.id, json.dumps(p.to_dict(), ensure_ascii=False), p.version, h, _now()))
            stats["added"] += 1
        elif row[0]:
            stats["skipped_custom"] += 1          # a staff-edited record wins over the seed
        elif row[1] != h:
            p.version = row[2] + 1
            conn.execute("UPDATE kb_procedures SET json=?, version=?, content_hash=?, updated_at=? WHERE id=?",
                         (json.dumps(p.to_dict(), ensure_ascii=False), p.version, h, _now(), p.id))
            stats["updated"] += 1
        else:
            stats["unchanged"] += 1
    conn.commit()
    return stats


def load_offices(conn: sqlite3.Connection) -> dict[str, Office]:
    return {r[0]: Office(**json.loads(r[1])) for r in conn.execute("SELECT id, json FROM kb_offices")}


def load_clause_codes(conn: sqlite3.Connection) -> set[str]:
    return {r[0] for r in conn.execute("SELECT code FROM kb_ordinances")}


def get_procedure(conn: sqlite3.Connection, proc_id: str) -> Procedure | None:
    row = conn.execute("SELECT json FROM kb_procedures WHERE id = ?", (proc_id,)).fetchone()
    return Procedure.from_dict(json.loads(row[0])) if row else None


def list_procedures(conn: sqlite3.Connection) -> list[Procedure]:
    return [Procedure.from_dict(json.loads(r[0]))
            for r in conn.execute("SELECT json FROM kb_procedures ORDER BY id")]


def upsert_procedure(conn: sqlite3.Connection, proc: Procedure, *, is_custom: bool = True) -> Procedure:
    """Validated write used by the Procedure Wizard and handbook ingestion."""
    offices = load_offices(conn)
    errs = validate_procedure(proc, set(offices), load_clause_codes(conn))
    if errs:
        raise KnowledgeError("; ".join(errs))
    row = conn.execute("SELECT version FROM kb_procedures WHERE id = ?", (proc.id,)).fetchone()
    proc.version = (row[0] + 1) if row else 1
    proc.is_custom = is_custom
    conn.execute(
        """INSERT INTO kb_procedures (id, json, is_custom, version, content_hash, updated_at)
           VALUES (?,?,?,?,?,?)
           ON CONFLICT(id) DO UPDATE SET json=excluded.json, is_custom=excluded.is_custom,
             version=excluded.version, content_hash=excluded.content_hash, updated_at=excluded.updated_at""",
        (proc.id, json.dumps(proc.to_dict(), ensure_ascii=False), int(is_custom), proc.version,
         proc.content_hash(), _now()))
    conn.commit()
    return proc
