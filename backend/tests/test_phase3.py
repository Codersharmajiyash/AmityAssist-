"""
Phase 3 chatbot router and FSM enhancement tests.

These tests keep the original withdrawal FSM intact while covering the
student-lifecycle assistant routes added in Phase 3.
"""

from backend.database.connection import get_connection
from backend.services.nlp_service import detect_language, is_voice_command, route_intent


def _verify_student(client, student_id="STU001"):
    response = client.post("/api/auth/verify", json={"student_id": student_id})
    assert response.status_code == 200
    return response.json()["session_id"]


class TestRouterNlp:
    def test_routes_student_lifecycle_intents(self):
        assert route_intent("show my CGPA and attendance") == "academics"
        assert route_intent("am I eligible for scholarship") == "scholarships"
        assert route_intent("I need my admit card and exam datesheet") == "exams"
        assert route_intent("I want to file a hostel complaint") == "grievances"
        assert route_intent("calculate my withdrawal refund") == "withdrawals"

    def test_detects_multilingual_and_voice_commands(self):
        assert detect_language("meri attendance batao") == "hinglish"
        assert detect_language("मेरी फीस कितनी है") == "hindi"
        assert is_voice_command("voice: show my exams") is True


class TestLifecycleChatRoutes:
    def test_greeting_gets_helpful_reaction(self, client):
        session_id = _verify_student(client, "STU001")

        response = client.post(
            "/api/chat/message",
            json={"session_id": session_id, "message": "hello"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["state"] == "ASK_REASON"
        assert data["intent"] == "help"
        assert "hello" in data["reply"].lower()

    def test_out_of_context_message_gets_guidance(self, client):
        session_id = _verify_student(client, "STU001")

        response = client.post(
            "/api/chat/message",
            json={"session_id": session_id, "message": "write me a movie review"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["state"] == "ASK_REASON"
        assert data["intent"] == "help"
        assert "student workflow" in data["reply"].lower()

    def test_academic_query_returns_profile_snapshot(self, client):
        session_id = _verify_student(client, "STU001")

        response = client.post(
            "/api/chat/message",
            json={
                "session_id": session_id,
                "message": "voice: meri attendance aur cgpa batao",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["state"] == "ROUTED"
        assert data["intent"] == "academics"
        assert "CGPA 8.75" in data["reply"]
        assert "Voice command" in data["reply"]
        assert "Hinglish" in data["reply"]

    def test_scholarship_query_lists_eligible_schemes(self, client):
        session_id = _verify_student(client, "STU003")

        response = client.post(
            "/api/chat/message",
            json={
                "session_id": session_id,
                "message": "Which scholarship am I eligible for?",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["state"] == "ROUTED"
        assert data["intent"] == "scholarships"
        assert "Vice Chancellor" in data["reply"]

    def test_exam_query_reports_backpaper_subjects(self, client):
        session_id = _verify_student(client, "STU002")

        response = client.post(
            "/api/chat/message",
            json={
                "session_id": session_id,
                "message": "show exam result and backpaper status",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["state"] == "ROUTED"
        assert data["intent"] == "exams"
        assert "Signals and Systems" in data["reply"]

    def test_grievance_conversation_files_record(self, client):
        session_id = _verify_student(client, "STU004")

        start = client.post(
            "/api/chat/message",
            json={"session_id": session_id, "message": "I want to file a complaint"},
        )
        assert start.status_code == 200
        assert start.json()["state"] == "GRIEVANCE_CATEGORY"

        category = client.post(
            "/api/chat/message",
            json={"session_id": session_id, "message": "academic"},
        )
        assert category.json()["state"] == "GRIEVANCE_DESCRIPTION"

        description = client.post(
            "/api/chat/message",
            json={
                "session_id": session_id,
                "message": "Course registration is blocked on the portal.",
            },
        )
        assert description.json()["state"] == "GRIEVANCE_CONFIRM"

        confirm = client.post(
            "/api/chat/message",
            json={"session_id": session_id, "message": "CONFIRM"},
        )
        assert confirm.status_code == 200
        assert confirm.json()["state"] == "RESOLVED"

        conn = get_connection()
        row = conn.execute(
            "SELECT * FROM grievances WHERE student_id = ? ORDER BY id DESC LIMIT 1",
            ("STU004",),
        ).fetchone()
        assert row is not None
        assert row["category"] == "academic"
        assert "Course registration" in row["description"]

    def test_withdrawal_response_includes_refund_estimate(self, client):
        session_id = _verify_student(client, "STU005")

        response = client.post(
            "/api/chat/message",
            json={
                "session_id": session_id,
                "message": "I want to withdraw and calculate my refund",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["state"] == "SUGGEST"
        assert "refund" in data["reply"].lower()
        assert "INR" in data["reply"]
