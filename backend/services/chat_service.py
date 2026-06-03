"""
Conversation state-machine (FSM) service.

States:
  ASK_REASON  → Prompt student for withdrawal reason
  SUGGEST     → Classify intent, offer alternatives
  CONFIRM     → Request explicit CONFIRM / CANCEL
  DONE        → Withdrawal submitted; session closed
  RESOLVED    → Student chose an alternative; session closed gracefully

Session state is stored in-process (dict). The persistent record of every
message and every submitted request is written to SQLite via parameterised
queries — never raw string interpolation.
"""

from __future__ import annotations

import secrets
import uuid
from datetime import datetime
from typing import Optional

from ..database.connection import get_connection
from ..models.schemas import ChatResponse
from .nlp_service import classify_intent, score_sentiment

# ---------------------------------------------------------------------------
# In-memory session registry  {session_id: SessionData}
# ---------------------------------------------------------------------------

_sessions: dict[str, dict] = {}


def create_session(student_id: str) -> str:
    """Register a new verified student session and return a secure session token."""
    session_id = secrets.token_urlsafe(32)
    _sessions[session_id] = {
        "student_id": student_id,
        "state": "ASK_REASON",
        "intent": None,
        "reason": None,
        "created_at": datetime.utcnow(),
    }
    return session_id


def get_session(session_id: str) -> Optional[dict]:
    """Retrieve session data or None if expired/invalid."""
    return _sessions.get(session_id)


def invalidate_session(session_id: str) -> None:
    """Remove session — called after withdrawal submitted or resolved."""
    _sessions.pop(session_id, None)


# ---------------------------------------------------------------------------
# Per-intent suggestion templates
# ---------------------------------------------------------------------------

_SUGGESTIONS: dict[str, str] = {
    "financial": (
        "💡 **We understand financial pressure can be overwhelming.**\n\n"
        "Before proceeding, please consider these options available to you:\n"
        "- **Emergency Bursary Fund** — up to $500 for eligible students\n"
        "- **Deferred Payment Plan** — spread tuition across 12 monthly instalments\n"
        "- **Part-Time Scholarship** — apply through the Financial Aid portal\n\n"
        "Would any of these help you continue your studies? *(yes / no / tell me more)*"
    ),
    "academic": (
        "📚 **Academic challenges affect many students — you are not alone.**\n\n"
        "Before you decide, please explore these alternatives:\n"
        "- **Academic Counselling** — one-on-one sessions with a dedicated advisor\n"
        "- **Programme Transfer** — switch to a course that suits you better\n"
        "- **Leave of Absence** — pause your studies for one semester without penalty\n\n"
        "Would you like to explore any of these? *(yes / no)*"
    ),
    "personal": (
        "❤️ **Personal circumstances can be incredibly difficult.**\n\n"
        "Please know these support options exist for you:\n"
        "- **Compassionate Leave** — up to 6 months pause with full reinstatement rights\n"
        "- **Remote Study Mode** — complete your coursework fully online\n"
        "- **Student Counselling Service** — free, confidential, and always available\n\n"
        "Can any of these help you continue? *(yes / no)*"
    ),
    "health": (
        "🏥 **Your health and wellbeing come first.**\n\n"
        "Before withdrawing, consider these health-sensitive options:\n"
        "- **Medical Leave of Absence** — pause studies without academic penalty\n"
        "- **Reduced Course Load** — carry fewer credits this semester\n"
        "- **Campus Health Services** — specialist support at no cost\n\n"
        "Would a medical leave of absence work for your situation? *(yes / no)*"
    ),
    "career": (
        "🚀 **An exciting opportunity shouldn't mean leaving your degree behind.**\n\n"
        "Consider these flexible pathways:\n"
        "- **Co-operative Education Programme** — earn academic credits while working\n"
        "- **Part-Time Enrolment** — balance your career and studies simultaneously\n"
        "- **Industry Project Elective** — real work experience built into your degree\n\n"
        "Would any of these allow you to stay enrolled? *(yes / no)*"
    ),
    "unclear": (
        "Thank you for sharing that with me. To make sure I give you the best support, "
        "could you tell me a little more about why you're considering withdrawal?\n\n"
        "For example, is it related to:\n"
        "- 💰 **Finances** (fees, costs)\n"
        "- 📚 **Academics** (grades, workload)\n"
        "- ❤️ **Personal** (family, circumstances)\n"
        "- 🏥 **Health** (medical reasons)\n"
        "- 💼 **Career** (job opportunity)\n\n"
        "Please describe your situation in your own words."
    ),
}

_POSITIVE_SIGNALS = {"yes", "yeah", "yep", "sure", "ok", "okay", "agree", "please", "try", "interested", "help"}
_NEGATIVE_SIGNALS = {"no", "nope", "nah", "none", "still", "withdraw", "proceed", "want to leave", "decided"}


# ---------------------------------------------------------------------------
# Persistence helpers
# ---------------------------------------------------------------------------

def _log_message(
    student_id: str,
    message: str,
    sender: str,
    intent: Optional[str] = None,
    sentiment: Optional[str] = None,
) -> None:
    """Persist a single conversation turn to SQLite."""
    conn = get_connection()
    conn.execute(
        "INSERT INTO conversations (student_id, message, sender, detected_intent, sentiment) "
        "VALUES (?, ?, ?, ?, ?)",
        (student_id, message, sender, intent, sentiment),
    )
    conn.commit()


def _submit_withdrawal(student_id: str, reason: str, intent: str) -> None:
    """Create a withdrawal_request record with 'pending' status."""
    conn = get_connection()
    conn.execute(
        "INSERT INTO withdrawal_requests (student_id, reason, detected_intent, status) "
        "VALUES (?, ?, ?, 'pending')",
        (student_id, reason, intent),
    )
    conn.commit()


# ---------------------------------------------------------------------------
# Core FSM
# ---------------------------------------------------------------------------

def process_message(session_id: str, raw_message: str) -> ChatResponse:
    """
    Process one student message through the conversation FSM.

    Each call advances the session state machine one step and returns
    the bot's reply along with metadata for the frontend to consume.
    """
    session = get_session(session_id)
    if session is None:
        return ChatResponse(
            reply=(
                "Your session has expired. For your security, sessions end after "
                "a period of inactivity. Please refresh the page and verify your identity again."
            ),
            state="INVALID",
        )

    student_id: str = session["student_id"]
    state: str = session["state"]

    # Persist student's raw message
    _log_message(student_id, raw_message, "student")

    # ── State: ASK_REASON ────────────────────────────────────────────────────
    if state == "ASK_REASON":
        intent = classify_intent(raw_message)
        sentiment = score_sentiment(raw_message)

        session["intent"] = intent
        session["reason"] = raw_message
        session["state"] = "SUGGEST"

        bot_reply = _SUGGESTIONS[intent]
        _log_message(student_id, bot_reply, "bot", intent, sentiment)

        return ChatResponse(
            reply=bot_reply,
            state="SUGGEST",
            intent=intent,
            sentiment=sentiment,
        )

    # ── State: SUGGEST ───────────────────────────────────────────────────────
    elif state == "SUGGEST":
        intent = session.get("intent") or "unclear"
        sentiment = score_sentiment(raw_message)
        tokens = set(raw_message.lower().split())

        wants_alternative = bool(tokens & _POSITIVE_SIGNALS) and not bool(
            tokens & {"withdraw", "still", "proceed", "leave", "quit"}
        )

        if wants_alternative:
            invalidate_session(session_id)
            bot_reply = (
                "That's great to hear! 🎉\n\n"
                "Please visit the **Student Services Portal** or speak directly with your "
                "academic advisor to arrange your chosen option. They will guide you through "
                "the next steps.\n\n"
                "Is there anything else I can help you with today?"
            )
            _log_message(student_id, bot_reply, "bot", intent, sentiment)
            return ChatResponse(reply=bot_reply, state="RESOLVED", intent=intent, sentiment=sentiment)

        else:
            session["state"] = "CONFIRM"
            bot_reply = (
                "I understand, and I respect your decision.\n\n"
                "⚠️ **Please note:** Submitting this request will initiate a formal withdrawal "
                "from your programme. Depending on the withdrawal date, you may be eligible for "
                "a partial tuition refund — our Registrar's office will advise you on this.\n\n"
                "To proceed, type **CONFIRM**.\n"
                "To cancel and go back, type **CANCEL**."
            )
            _log_message(student_id, bot_reply, "bot", intent, sentiment)
            return ChatResponse(reply=bot_reply, state="CONFIRM", intent=intent, sentiment=sentiment)

    # ── State: CONFIRM ───────────────────────────────────────────────────────
    elif state == "CONFIRM":
        intent = session.get("intent") or "unclear"
        sentiment = score_sentiment(raw_message)
        normalised = raw_message.strip().upper()

        if normalised == "CONFIRM":
            _submit_withdrawal(student_id, session.get("reason", ""), intent)
            invalidate_session(session_id)
            ref = "WD-" + str(uuid.uuid4())[:8].upper()
            bot_reply = (
                f"✅ **Your withdrawal request has been submitted successfully.**\n\n"
                f"📋 **Reference:** `{ref}`\n\n"
                "You will receive a confirmation email within **2 business days** with full details. "
                "If you reconsider, please contact the Registrar's office within **48 hours** — "
                "requests can be withdrawn within that window.\n\n"
                "We wish you every success in your future endeavours. 🎓"
            )
            _log_message(student_id, bot_reply, "bot", intent, sentiment)
            return ChatResponse(
                reply=bot_reply,
                state="DONE",
                intent=intent,
                sentiment=sentiment,
                withdrawal_submitted=True,
            )

        elif normalised == "CANCEL":
            session["state"] = "ASK_REASON"
            session["reason"] = None
            session["intent"] = None
            bot_reply = (
                "Your withdrawal request has been cancelled. "
                "No changes have been made to your enrolment.\n\n"
                "Is there anything else I can help you with today?"
            )
            _log_message(student_id, bot_reply, "bot", intent, sentiment)
            return ChatResponse(reply=bot_reply, state="ASK_REASON", intent=intent, sentiment=sentiment)

        else:
            bot_reply = (
                "I need a clear response to proceed.\n\n"
                "Please type **CONFIRM** to submit your withdrawal request, "
                "or **CANCEL** to abort."
            )
            _log_message(student_id, bot_reply, "bot")
            return ChatResponse(reply=bot_reply, state="CONFIRM", intent=intent, sentiment=sentiment)

    # ── Guard: session already closed ────────────────────────────────────────
    else:
        return ChatResponse(
            reply=(
                "Your request has already been processed. "
                "Please contact the Registrar's office directly for further assistance."
            ),
            state="DONE",
        )
