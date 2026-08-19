"""
Shared test fixtures.

A fresh in-memory SQLite database is created per test session so that
tests never touch the real chatbot.db file.
"""

import os
import pytest
from fastapi.testclient import TestClient

# Point DB at a temp location before importing anything that opens a connection
os.environ.setdefault("CHATBOT_ENV", "test")

from backend.main import app  # noqa: E402 — import after env var set
from backend.database.seed import init_db  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def initialise_test_db(tmp_path_factory):
    """Create an isolated DB for the entire test session."""
    tmp_dir = tmp_path_factory.mktemp("db")
    db_path = tmp_dir / "test_chatbot.db"

    # Monkey-patch the DB path used by connection.py
    import backend.database.connection as conn_module
    conn_module.DB_PATH = db_path
    # Reset any existing connection so a fresh one is created at the new path
    conn_module._local.__dict__.clear()

    init_db()
    yield
    conn_module._local.__dict__.clear()


@pytest.fixture(scope="session")
def client(initialise_test_db):
    """Reusable synchronous TestClient for the full app."""
    # Disable rate limiting across all limiters for tests
    app.state.limiter.enabled = False
    from backend.routes.auth import limiter as auth_limiter
    from backend.routes.chat import limiter as chat_limiter
    auth_limiter.enabled = False
    chat_limiter.enabled = False
    
    with TestClient(app) as c:
        yield c
