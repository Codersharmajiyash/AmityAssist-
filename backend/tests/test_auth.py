"""
Tests for /api/auth/verify — student verification endpoint.

Double-validation strategy:
  Round 1: standard happy-path and error cases
  Round 2: security-focused edge cases (injection, boundary values)
"""

import pytest


class TestStudentVerification:
    """Round 1 — Functional correctness."""

    def test_valid_student_id_returns_session(self, client):
        """A known student ID must return verified=True with a session token."""
        response = client.post(
            "/api/auth/verify",
            json={"student_id": "STU001"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["verified"] is True
        assert data["session_id"] is not None
        assert len(data["session_id"]) >= 16
        assert "Aisha" in data["student_name"]
        assert data["course"] == "Computer Science"  # STU001 course in expanded seed

    def test_valid_email_returns_session(self, client):
        """A known email address must also verify successfully."""
        response = client.post(
            "/api/auth/verify",
            json={"email": "rahul.sharma@uni.edu"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["verified"] is True
        assert data["student_name"] == "Rahul Sharma"

    def test_invalid_student_id_returns_unverified(self, client):
        """An unknown student ID must return verified=False."""
        response = client.post(
            "/api/auth/verify",
            json={"student_id": "STU999"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["verified"] is False
        assert data["session_id"] is None
        # Error message must NOT reveal whether the user exists or not
        assert "check your Student ID" in data["message"]

    def test_invalid_email_returns_unverified(self, client):
        """An unknown email must return verified=False."""
        response = client.post(
            "/api/auth/verify",
            json={"email": "nobody@uni.edu"},
        )
        assert response.status_code == 200
        assert response.json()["verified"] is False

    def test_no_credentials_returns_422(self, client):
        """Sending neither student_id nor email must be rejected."""
        response = client.post("/api/auth/verify", json={})
        assert response.status_code == 422


class TestStudentVerificationSecurity:
    """Round 2 — Security / edge-case validation."""

    def test_sql_injection_in_student_id_rejected(self, client):
        """
        SQL injection payload in student_id must be blocked by the
        field validator before reaching the database layer.
        """
        response = client.post(
            "/api/auth/verify",
            json={"student_id": "' OR '1'='1"},
        )
        # Validator rejects non-alphanumeric chars → 422
        assert response.status_code == 422

    def test_sql_injection_via_email_field_safe(self, client):
        """
        Even if an attacker sends a crafted email, parameterised
        queries ensure no injection occurs — result is simply unverified.
        """
        response = client.post(
            "/api/auth/verify",
            json={"email": "' OR 1=1--@example.com"},
        )
        # Pydantic EmailStr rejects this as an invalid email format
        assert response.status_code in (200, 422)
        if response.status_code == 200:
            assert response.json()["verified"] is False

    def test_oversized_student_id_rejected(self, client):
        """Fields longer than max_length must be rejected."""
        response = client.post(
            "/api/auth/verify",
            json={"student_id": "A" * 50},
        )
        assert response.status_code == 422

    def test_case_insensitive_student_id(self, client):
        """Student IDs should match regardless of case (normalised to upper)."""
        response = client.post(
            "/api/auth/verify",
            json={"student_id": "stu001"},
        )
        assert response.status_code == 200
        assert response.json()["verified"] is True

    def test_response_never_exposes_email(self, client):
        """Verify response must NOT include the student's full email."""
        response = client.post(
            "/api/auth/verify",
            json={"student_id": "STU001"},
        )
        body = response.text
        assert "aisha.malik@uni.edu" not in body


class TestJWTAndRBAC:
    """Phase 6: JWT-based auth and role-protected access."""

    def test_student_login_returns_jwt(self, client):
        response = client.post("/api/auth/login", json={"student_id": "STU001"})
        assert response.status_code == 200
        data = response.json()
        assert data["role"] == "Student"
        assert data["token"]
        assert data["student_id"] == "STU001"

    def test_student_profile_rejects_mismatched_student_id(self, client):
        response = client.post("/api/auth/login", json={"student_id": "STU001"})
        token = response.json()["token"]

        protected = client.get(
            "/api/student/profile",
            params={"student_id": "STU002"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert protected.status_code == 403

    def test_staff_login_and_admin_access(self, client):
        response = client.post("/api/auth/staff/login", json={"username": "registrar_staff"})
        assert response.status_code == 200
        token = response.json()["token"]

        admin = client.get(
            "/api/admin/grievances",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert admin.status_code == 200

        denied = client.get(
            "/api/student/profile",
            params={"student_id": "STU001"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert denied.status_code == 403
