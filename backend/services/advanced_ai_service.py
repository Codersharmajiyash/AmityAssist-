"""Phase 18 advanced conversational AI helpers.

The service keeps UniAssist useful without a paid LLM key by using local,
auditable context memory and domain guardrails. If a Gemini API key is
configured, the same interface can call Gemini for a concise answer.
"""

from __future__ import annotations

import textwrap
from typing import Any

import httpx

from ..config import settings
from .nlp_service import route_intent, score_sentiment


_DOMAIN_SCOPE = (
    "academics, attendance, exams, backpapers, scholarships, grievances, "
    "documents, hostel, fee dues, notices, internships, withdrawal procedure, "
    "refund guidance, and request status"
)

_ESCALATION_MARKERS = {
    "urgent",
    "emergency",
    "harassment",
    "unsafe",
    "suicide",
    "self harm",
    "legal",
    "medical emergency",
    "threat",
    "discrimination",
}


def remember_turn(session: dict[str, Any], role: str, message: str) -> None:
    """Store a bounded conversational memory in the in-process session."""
    turns = session.setdefault("recent_turns", [])
    turns.append(
        {
            "role": role,
            "message": message.strip()[:500],
            "intent": route_intent(message),
            "sentiment": score_sentiment(message),
        }
    )
    del turns[:-8]
    session["memory_summary"] = summarize_memory(session)


def summarize_memory(session: dict[str, Any]) -> str:
    """Return a compact summary suitable for display or LLM prompting."""
    turns = session.get("recent_turns", [])
    if not turns:
        return "No prior context in this session."

    intents = [
        turn["intent"]
        for turn in turns
        if turn.get("intent") and turn["intent"] != "unknown"
    ]
    sentiments = [turn.get("sentiment") for turn in turns if turn.get("sentiment")]
    last_student_turn = next(
        (turn["message"] for turn in reversed(turns) if turn.get("role") == "student"),
        "",
    )
    intent_summary = ", ".join(dict.fromkeys(intents)) or "general support"
    sentiment_summary = sentiments[-1] if sentiments else "neutral"
    return (
        f"Recent topics: {intent_summary}. "
        f"Latest sentiment: {sentiment_summary}. "
        f"Latest student message: {last_student_turn[:120]}"
    )


def escalation_recommended(message: str, sentiment: str, memory_summary: str) -> bool:
    """Flag conversations that should move to a human staff member."""
    lower = f"{message} {memory_summary}".lower()
    return sentiment == "negative" and any(marker in lower for marker in _ESCALATION_MARKERS)


def build_local_contextual_reply(
    message: str,
    student: dict[str, Any] | None,
    memory_summary: str,
    language: str,
    voice: bool,
) -> str:
    """Domain-specific fallback when no external LLM is configured."""
    first_name = (student or {}).get("name", "student").split()[0]
    prefix = ""
    if voice:
        prefix = "Voice command received. "
    if language == "hindi":
        prefix += "Hindi mode: "
    elif language == "hinglish":
        prefix += "Hinglish mode: "

    return (
        f"{prefix}{first_name}, I can only answer inside UniAssist service workflows and student workflow support right now. "
        f"Supported areas are {_DOMAIN_SCOPE}. "
        "Tell me which service you want, for example: withdrawal checklist, fee status, "
        "document verification, grievance filing, scholarship eligibility, notices, or exam results.\n\n"
        f"Context I will keep for this session: {memory_summary}"
    )


def try_gemini_reply(
    message: str,
    student: dict[str, Any] | None,
    memory_summary: str,
) -> str | None:
    """Call Gemini only when explicitly configured; otherwise return None."""
    if not settings.llm_enabled:
        return None

    prompt = textwrap.dedent(
        f"""
        You are UniAssist, a university student-service assistant.
        Stay inside this domain: {_DOMAIN_SCOPE}.
        Do not invent approval decisions, refund outcomes, legal advice, or medical advice.
        Give a concise next-step answer and suggest staff escalation for urgent cases.

        Student context: {student or {}}
        Conversation memory: {memory_summary}
        Student message: {message}
        """
    ).strip()

    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{settings.gemini_model}:generateContent?key={settings.gemini_api_key}"
    )
    payload = {"contents": [{"parts": [{"text": prompt}]}]}

    try:
        response = httpx.post(
            url,
            json=payload,
            timeout=settings.llm_timeout_seconds,
        )
        response.raise_for_status()
        data = response.json()
        return (
            data.get("candidates", [{}])[0]
            .get("content", {})
            .get("parts", [{}])[0]
            .get("text")
        )
    except Exception:
        return None


def advanced_reply(
    message: str,
    student: dict[str, Any] | None,
    session: dict[str, Any],
    language: str,
    voice: bool,
) -> dict[str, Any]:
    """Return an advanced AI reply with safe local fallback metadata."""
    memory_summary = summarize_memory(session)
    sentiment = score_sentiment(message)
    llm_reply = try_gemini_reply(message, student, memory_summary)

    if llm_reply:
        source = "gemini"
        reply = llm_reply
    else:
        source = "local-context"
        reply = build_local_contextual_reply(
            message, student, memory_summary, language, voice
        )

    return {
        "reply": reply,
        "source": source,
        "memory_summary": memory_summary,
        "sentiment": sentiment,
        "escalation_recommended": escalation_recommended(
            message, sentiment, memory_summary
        ),
    }
