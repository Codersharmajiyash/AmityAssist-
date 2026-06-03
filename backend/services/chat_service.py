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
from .nlp_service import classify_intent, detect_language, is_voice_command, route_intent, score_sentiment

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
        "grievance_category": None,
        "grievance_description": None,
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
_GRIEVANCE_CATEGORIES = {"academic", "fee", "hostel", "exam", "scholarship"}


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


def _fetch_student(student_id: str) -> Optional[dict]:
    conn = get_connection()
    row = conn.execute("SELECT * FROM students WHERE id = ?", (student_id,)).fetchone()
    return dict(row) if row else None


def _fetch_exam_summary(student_id: str) -> list[dict]:
    conn = get_connection()
    rows = conn.execute(
        "SELECT * FROM examinations WHERE student_id = ? ORDER BY exam_date ASC",
        (student_id,),
    ).fetchall()
    return [dict(row) for row in rows]


def _fetch_scholarship_summary(student_id: str, cgpa: float) -> list[dict]:
    conn = get_connection()
    rows = conn.execute("SELECT * FROM scholarships ORDER BY eligibility_cgpa DESC").fetchall()
    applied = conn.execute(
        "SELECT scholarship_id, status FROM scholarship_applications WHERE student_id = ?",
        (student_id,),
    ).fetchall()
    statuses = {row["scholarship_id"]: row["status"] for row in applied}

    result = []
    for row in rows:
        item = dict(row)
        item["eligible"] = cgpa >= row["eligibility_cgpa"]
        item["application_status"] = statuses.get(row["id"])
        result.append(item)
    return result


def _calculate_refund(student: dict) -> dict:
    enrolled = datetime.fromisoformat(student["enrolled_date"])
    days_enrolled = max((datetime.utcnow() - enrolled).days, 0)
    annual_tuition = 240000.0

    if days_enrolled <= 15:
        percent = 1.0
    elif days_enrolled <= 30:
        percent = 0.8
    elif days_enrolled <= 60:
        percent = 0.5
    elif days_enrolled <= 90:
        percent = 0.25
    else:
        percent = 0.0

    gross_refund = annual_tuition * percent
    fee_due = float(student.get("fee_due") or 0)
    return {
        "days_enrolled": days_enrolled,
        "percent": percent,
        "gross_refund": gross_refund,
        "fee_due": fee_due,
        "net_refund": max(gross_refund - fee_due, 0.0),
    }


def _language_prefix(language: str, voice: bool) -> str:
    if voice and language == "hindi":
        return "Voice command received. Hindi mode active.\n\n"
    if voice and language == "hinglish":
        return "Voice command received. Hinglish mode active.\n\n"
    if language == "hindi":
        return "Hindi mode: "
    if language == "hinglish":
        return "Hinglish mode: "
    if voice:
        return "Voice command received.\n\n"
    return ""


def _is_lifecycle_query(raw_message: str, voice: bool) -> bool:
    lower = raw_message.lower()
    command_markers = (
        "show", "which", "eligible", "status", "file", "register", "apply",
        "admit card", "datesheet", "backpaper", "back paper", "cgpa",
        "attendance", "bata", "batao", "help", "complaint", "grievance",
        "result",
    )
    return voice or any(marker in lower for marker in command_markers)


def _route_lifecycle_message(session: dict, raw_message: str, language: str, voice: bool) -> Optional[ChatResponse]:
    student_id = session["student_id"]
    routed_intent = route_intent(raw_message)
    sentiment = score_sentiment(raw_message)
    student = _fetch_student(student_id)
    prefix = _language_prefix(language, voice)

    if routed_intent in {"unknown", "withdrawals"}:
        return None
    if not _is_lifecycle_query(raw_message, voice):
        return None

    if routed_intent == "help":
        reply = (
            f"{prefix}I can help with academics, exams, scholarships, grievances, "
            "withdrawals, refund estimates, notices, and document support. "
            "Tell me what you need in English, Hindi, Hinglish, or by voice."
        )
        _log_message(student_id, reply, "bot", routed_intent, sentiment)
        return ChatResponse(reply=reply, state="ROUTED", intent=routed_intent, sentiment=sentiment)

    if routed_intent == "academics" and student:
        reply = (
            f"{prefix}{student['name']}, your academic snapshot is: CGPA {student['cgpa']}, "
            f"attendance {student['attendance']}%, semester {student['semester']}, "
            f"performance: {student['academic_performance']}. "
            "For back papers or admit cards, ask about exams."
        )
        _log_message(student_id, reply, "bot", routed_intent, sentiment)
        return ChatResponse(reply=reply, state="ROUTED", intent=routed_intent, sentiment=sentiment)

    if routed_intent == "exams":
        exams = _fetch_exam_summary(student_id)
        if not exams:
            reply = f"{prefix}I could not find exam records for your profile yet."
        else:
            upcoming = [exam for exam in exams if exam["grade"] is None]
            backpapers = [exam for exam in exams if exam["grade"] in ("F", "D")]
            lines = []
            if upcoming:
                next_exam = upcoming[0]
                lines.append(f"Next exam: {next_exam['subject_name']} on {next_exam['exam_date']}.")
            if backpapers:
                names = ", ".join(exam["subject_name"] for exam in backpapers[:3])
                lines.append(f"Back-paper eligible subjects: {names}.")
            if not lines:
                lines.append("All listed exam records are completed with no pending back-paper action.")
            reply = prefix + " ".join(lines)
        _log_message(student_id, reply, "bot", routed_intent, sentiment)
        return ChatResponse(reply=reply, state="ROUTED", intent=routed_intent, sentiment=sentiment)

    if routed_intent == "scholarships" and student:
        schemes = _fetch_scholarship_summary(student_id, float(student["cgpa"]))
        eligible = [scheme for scheme in schemes if scheme["eligible"]]
        if eligible:
            names = ", ".join(scheme["name"] for scheme in eligible)
            reply = (
                f"{prefix}Based on CGPA {student['cgpa']}, you are eligible for: {names}. "
                "Use the Scholarship Hub to apply or say the scheme name."
            )
        else:
            minimum = min(scheme["eligibility_cgpa"] for scheme in schemes) if schemes else 0
            reply = (
                f"{prefix}Your current CGPA is {student['cgpa']}. "
                f"The lowest listed scholarship threshold is {minimum}."
            )
        _log_message(student_id, reply, "bot", routed_intent, sentiment)
        return ChatResponse(reply=reply, state="ROUTED", intent=routed_intent, sentiment=sentiment)

    if routed_intent == "grievances":
        session["state"] = "GRIEVANCE_CATEGORY"
        reply = (
            f"{prefix}I can file a grievance for you. "
            "Choose one category: academic, fee, hostel, exam, or scholarship."
        )
        _log_message(student_id, reply, "bot", routed_intent, sentiment)
        return ChatResponse(reply=reply, state="GRIEVANCE_CATEGORY", intent=routed_intent, sentiment=sentiment)

    return None


def _handle_grievance_state(session: dict, raw_message: str) -> ChatResponse:
    student_id = session["student_id"]
    state = session["state"]
    sentiment = score_sentiment(raw_message)
    normalised = raw_message.lower().strip()

    if state == "GRIEVANCE_CATEGORY":
        category = next((item for item in _GRIEVANCE_CATEGORIES if item in normalised), None)
        if category is None:
            reply = "Please choose one category: academic, fee, hostel, exam, or scholarship."
            _log_message(student_id, reply, "bot", "grievances", sentiment)
            return ChatResponse(reply=reply, state="GRIEVANCE_CATEGORY", intent="grievances", sentiment=sentiment)
        session["grievance_category"] = category
        session["state"] = "GRIEVANCE_DESCRIPTION"
        reply = f"Got it: {category}. Please describe the issue in one or two sentences."
        _log_message(student_id, reply, "bot", "grievances", sentiment)
        return ChatResponse(reply=reply, state="GRIEVANCE_DESCRIPTION", intent="grievances", sentiment=sentiment)

    if state == "GRIEVANCE_DESCRIPTION":
        if len(raw_message.strip()) < 5:
            reply = "Please add a little more detail so the right office can act on it."
            _log_message(student_id, reply, "bot", "grievances", sentiment)
            return ChatResponse(reply=reply, state="GRIEVANCE_DESCRIPTION", intent="grievances", sentiment=sentiment)
        session["grievance_description"] = raw_message.strip()
        session["state"] = "GRIEVANCE_CONFIRM"
        reply = "I have the grievance details. Type CONFIRM to file it, or CANCEL to discard it."
        _log_message(student_id, reply, "bot", "grievances", sentiment)
        return ChatResponse(reply=reply, state="GRIEVANCE_CONFIRM", intent="grievances", sentiment=sentiment)

    if state == "GRIEVANCE_CONFIRM":
        if raw_message.strip().upper() == "CONFIRM":
            conn = get_connection()
            conn.execute(
                "INSERT INTO grievances (student_id, category, description) VALUES (?, ?, ?)",
                (student_id, session["grievance_category"], session["grievance_description"]),
            )
            conn.commit()
            session["state"] = "ASK_REASON"
            session["grievance_category"] = None
            session["grievance_description"] = None
            reply = "Your grievance has been filed successfully. You will receive a response within 3 working days."
            _log_message(student_id, reply, "bot", "grievances", sentiment)
            return ChatResponse(reply=reply, state="RESOLVED", intent="grievances", sentiment=sentiment)
        if raw_message.strip().upper() == "CANCEL":
            session["state"] = "ASK_REASON"
            session["grievance_category"] = None
            session["grievance_description"] = None
            reply = "Grievance filing cancelled. No record was created."
            _log_message(student_id, reply, "bot", "grievances", sentiment)
            return ChatResponse(reply=reply, state="ASK_REASON", intent="grievances", sentiment=sentiment)
        reply = "Please type CONFIRM to file the grievance, or CANCEL to discard it."
        _log_message(student_id, reply, "bot", "grievances", sentiment)
        return ChatResponse(reply=reply, state="GRIEVANCE_CONFIRM", intent="grievances", sentiment=sentiment)

    return ChatResponse(reply="Invalid grievance state.", state="INVALID", intent="grievances", sentiment=sentiment)


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
    language = detect_language(raw_message)
    voice = is_voice_command(raw_message)

    # Persist student's raw message
    _log_message(student_id, raw_message, "student")

    if state in {"GRIEVANCE_CATEGORY", "GRIEVANCE_DESCRIPTION", "GRIEVANCE_CONFIRM"}:
        return _handle_grievance_state(session, raw_message)

    # ── State: ASK_REASON ────────────────────────────────────────────────────
    if state == "ASK_REASON":
        routed_response = _route_lifecycle_message(session, raw_message, language, voice)
        if routed_response is not None:
            return routed_response

        intent = classify_intent(raw_message)
        sentiment = score_sentiment(raw_message)

        session["intent"] = intent
        session["reason"] = raw_message
        session["state"] = "SUGGEST"

        bot_reply = _SUGGESTIONS[intent]
        if route_intent(raw_message) == "withdrawals":
            student = _fetch_student(student_id)
            if student:
                refund = _calculate_refund(student)
                bot_reply += (
                    "\n\n"
                    f"Estimated refund check: enrolled for {refund['days_enrolled']} days, "
                    f"policy refund {int(refund['percent'] * 100)}%, "
                    f"net estimate INR {refund['net_refund']:,.0f} after outstanding dues."
                )
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
            student = _fetch_student(student_id)
            if student:
                refund = _calculate_refund(student)
                bot_reply += (
                    "\n\n"
                    f"Current refund estimate: INR {refund['net_refund']:,.0f} "
                    f"({int(refund['percent'] * 100)}% policy band, "
                    f"INR {refund['fee_due']:,.0f} dues adjusted)."
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
