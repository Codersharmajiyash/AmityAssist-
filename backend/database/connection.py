"""
SQLite connection management using thread-local storage.

Security note: Thread-local connections prevent shared state across threads.
All queries elsewhere use parameterised placeholders (?) — never string
interpolation — which is the primary defence against SQL injection.
"""

import sqlite3
import threading
from pathlib import Path

# Resolve DB path relative to this file: backend/database/ -> root/database/
DB_PATH = Path(__file__).resolve().parents[2] / "database" / "chatbot.db"

_local = threading.local()


def get_connection() -> sqlite3.Connection:
    """Return a thread-local SQLite connection with Row factory enabled."""
    if not hasattr(_local, "conn") or _local.conn is None:
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        _local.conn = sqlite3.connect(str(DB_PATH), check_same_thread=False)
        _local.conn.row_factory = sqlite3.Row
        # Enforce referential integrity
        _local.conn.execute("PRAGMA foreign_keys = ON")
        # Write-ahead logging: better concurrent read performance
        _local.conn.execute("PRAGMA journal_mode = WAL")
    return _local.conn


def close_connection() -> None:
    """Close and discard the thread-local connection."""
    conn = getattr(_local, "conn", None)
    if conn:
        conn.close()
        _local.conn = None
