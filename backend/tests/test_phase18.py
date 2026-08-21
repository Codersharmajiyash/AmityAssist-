"""Phase 18: advanced conversational AI."""

from backend.services.advanced_ai_service import (
    advanced_reply,
    escalation_recommended,
    remember_turn,
    summarize_memory,
)


def _verify_student(client, student_id="STU001"):
    response = client.post("/api/auth/verify", json={"student_id": student_id})
    assert response.status_code == 200
    return response.json()["session_id"]


def test_context_memory_summarises_recent_topics():
    session = {}
    remember_turn(session, "student", "show my CGPA and attendance")
    remember_turn(session, "bot", "Your attendance is available in academics")
    remember_turn(session, "student", "now help with scholarship eligibility")

    summary = summarize_memory(session)

    assert "academics" in summary
    assert "scholarships" in summary
    assert "Latest sentiment" in summary


def test_local_advanced_reply_is_domain_guarded_without_llm_key():
    session = {}
    remember_turn(session, "student", "I checked my hostel status earlier")

    result = advanced_reply(
        "Can you book movie tickets for me?",
        {"name": "Aisha Malik"},
        session,
        language="english",
        voice=False,
    )

    assert result["source"] == "local-context"
    assert "UniAssist service workflows" in result["reply"]
    assert "hostel" in result["memory_summary"]
    assert result["escalation_recommended"] is False


def test_negative_urgent_messages_recommend_staff_escalation():
    assert escalation_recommended(
        "This is urgent and I feel unsafe",
        "negative",
        "Recent topics: grievances.",
    )


def test_chat_endpoint_returns_advanced_ai_metadata_for_unknown_query(client):
    session_id = _verify_student(client)

    first = client.post(
        "/api/chat/message",
        json={"session_id": session_id, "message": "show my CGPA and attendance"},
    )
    assert first.status_code == 200

    second = client.post(
        "/api/chat/message",
        json={"session_id": session_id, "message": "book movie tickets"},
    )

    assert second.status_code == 200
    body = second.json()
    assert body["ai_source"] == "local-context"
    assert "Recent topics" in body["memory_summary"]
    assert "UniAssist service workflows" in body["reply"]
