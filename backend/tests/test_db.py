"""
Database-layer tests — schema integrity, CRUD operations, parameterised queries.

Double-validation:
  Round 1 — Verify data inserted by seed.py is correct
  Round 2 — Direct DB writes: conversations and withdrawal_requests
"""

import pytest
from backend.database.connection import get_connection


class TestSeedData:
    """Round 1 — Seed correctness."""

    def test_ten_students_seeded(self):
        """Exactly 10 sample students must exist after init_db()."""
        conn = get_connection()
        count = conn.execute("SELECT COUNT(*) FROM students").fetchone()[0]
        assert count == 10

    def test_student_stu001_exists(self):
        conn = get_connection()
        row = conn.execute(
            "SELECT * FROM students WHERE id = ?", ("STU001",)
        ).fetchone()
        assert row is not None
        assert row["name"] == "Aisha Malik"
        assert row["course"] == "Computer Science"
        assert "branch" in row.keys()  # expanded schema includes branch
        assert "@" in row["email"]

    def test_all_students_have_unique_emails(self):
        conn = get_connection()
        emails = [r[0] for r in conn.execute("SELECT email FROM students").fetchall()]
        assert len(emails) == len(set(emails))  # no duplicates

    def test_init_db_is_idempotent(self):
        """Running init_db() twice must not duplicate records."""
        from backend.database.seed import init_db
        init_db()
        conn = get_connection()
        count = conn.execute("SELECT COUNT(*) FROM students").fetchone()[0]
        assert count == 10  # still exactly 10


class TestDirectDbOperations:
    """Round 2 — Direct write / read verification."""

    def test_conversation_record_written(self):
        """Directly inserting a conversation record and reading it back."""
        conn = get_connection()
        conn.execute(
            "INSERT INTO conversations (student_id, message, sender, detected_intent, sentiment) "
            "VALUES (?, ?, ?, ?, ?)",
            ("STU001", "This is a test message", "student", "academic", "neutral"),
        )
        conn.commit()
        row = conn.execute(
            "SELECT * FROM conversations WHERE student_id = ? AND message = ?",
            ("STU001", "This is a test message"),
        ).fetchone()
        assert row is not None
        assert row["detected_intent"] == "academic"
        assert row["sentiment"] == "neutral"

    def test_withdrawal_request_record_written(self):
        """Directly inserting a withdrawal request and verifying status default."""
        conn = get_connection()
        conn.execute(
            "INSERT INTO withdrawal_requests (student_id, reason, detected_intent) "
            "VALUES (?, ?, ?)",
            ("STU002", "Financial difficulties", "financial"),
        )
        conn.commit()
        row = conn.execute(
            "SELECT * FROM withdrawal_requests WHERE student_id = ? ORDER BY id DESC LIMIT 1",
            ("STU002",),
        ).fetchone()
        assert row is not None
        assert row["status"] == "pending"
        assert row["detected_intent"] == "financial"

    def test_invalid_sender_rejected_by_check_constraint(self):
        """The 'sender' column CHECK constraint must reject invalid values."""
        conn = get_connection()
        with pytest.raises(Exception):
            conn.execute(
                "INSERT INTO conversations (student_id, message, sender) VALUES (?, ?, ?)",
                ("STU001", "bad sender test", "admin"),
            )
            conn.commit()
        conn.rollback()

    def test_foreign_key_constraint_blocks_orphan(self):
        """Inserting a conversation for a non-existent student must fail."""
        conn = get_connection()
        with pytest.raises(Exception):
            conn.execute(
                "INSERT INTO conversations (student_id, message, sender) VALUES (?, ?, ?)",
                ("STU999", "orphan message", "student"),
            )
            conn.commit()
        conn.rollback()
