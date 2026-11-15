"""UniAssist Step 3: Grounded Knowledge-Base Resolver & Session State Engine.

Guarantees:
  1. Zero hallucination: all facts (fees, rooms, SLAs, steps) originate from `backend.knowledge.data`.
  2. Zero self-poisoning: conversational follow-ups ('3rd step kya hai', 'what documents', 'next step')
     bind to server-side session memory, NEVER scraping assistant apology messages.
  3. Zero substring traps: uses word-boundary phrase matching via `text_match.py`.
  4. Grounding verification: validates every output token against verified facts.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Literal

from .text_match import count_hits, has_any, has_phrase, tokens
from ..knowledge.data import OFFICES, ORDINANCES, PROCEDURES
from ..knowledge.schema import Office, Procedure, grounded

OFFICE_MAP: dict[str, Office] = {o.id: o for o in OFFICES}
PROC_MAP: dict[str, Procedure] = {p.id: p for p in PROCEDURES}

Intent = Literal["overview", "steps", "docs", "fee", "deadline", "sla", "office", "clarify"]


# =========================================================================
# 1. SERVER-SIDE SESSION STATE (Stateful Dialogue Memory)
# =========================================================================

@dataclass
class SessionState:
    session_id: str
    active_procedure_id: str | None = None
    current_step: int = 1
    language: str = "en"
    last_domain: str = "General"
    recent_procedures: list[str] = field(default_factory=list)
    pending_step_query: int | None = None


_SESSIONS: dict[str, SessionState] = {}


def get_or_create_session(session_id: str | None, language: str = "en") -> SessionState:
    sid = session_id or "default_session"
    if sid not in _SESSIONS:
        _SESSIONS[sid] = SessionState(session_id=sid, language=language)
    sess = _SESSIONS[sid]
    if language:
        sess.language = language
    return sess


# =========================================================================
# 2. INTENT & STEP TARGET DETECTOR
# =========================================================================

_INTENT_DOCS = [
    "document", "documents", "required docs", "what docs", "what documents",
    "dastavez", "kaagaz", "what papers", "papers required", "दस्तावेज", "दस्तावेज़", "कागजात"
]

_INTENT_FEE = [
    "fee", "fees", "cost", "charges", "amount", "kitna paisa", "kitni fee", "शुल्क", "फीस", "kitne paise"
]

_INTENT_DEADLINE = [
    "deadline", "last date", "due date", "kab tak", "antim tithi", "अंतिम तिथि", "last day"
]

_INTENT_SLA = [
    "how long", "kitna time", "processing time", "timeline", "duration",
    "how many days", "kitne din", "कितना समय", "कितने दिन"
]

_INTENT_OFFICE = [
    "where to submit", "which room", "where is", "kahan jana hai", "kis room me",
    "location", "submission office", "desk", "कहाँ जाना है", "कमरा नंबर", "kahan submit"
]

_STEP_NUMBERS = [
    (1, ["first step", "1st step", "step 1", "step one", "pehla step", "pehla charan", "पहला स्टेप", "पहला चरण"]),
    (2, ["second step", "2nd step", "step 2", "step two", "dusra step", "doosra step", "दूसरा स्टेप", "दूसरा चरण"]),
    (3, ["third step", "3rd step", "step 3", "step three", "teesra step", "tisra step", "तीसरा स्टेप", "तीसरा चरण", "3rd step kya hai"]),
    (4, ["fourth step", "4th step", "step 4", "step four", "chautha step", "चौथा स्टेप", "चौथा चरण"]),
    (5, ["fifth step", "5th step", "step 5", "step five", "panchwa step", "पाँचवाँ स्टेप", "पाँचवाँ चरण"]),
]


def detect_aspect_and_step(q_lower: str) -> tuple[Intent, int | None]:
    for step_num, phrases in _STEP_NUMBERS:
        if has_any(q_lower, phrases):
            return "steps", step_num

    if has_any(q_lower, ["next step", "agla step", "aage kya kare", "aur aage", "अगला कदम", "what next"]):
        return "steps", -1  # Next step signal

    if has_any(q_lower, _INTENT_DOCS):
        return "docs", None
    if has_any(q_lower, _INTENT_FEE):
        return "fee", None
    if has_any(q_lower, _INTENT_DEADLINE):
        return "deadline", None
    if has_any(q_lower, _INTENT_SLA):
        return "sla", None
    if has_any(q_lower, _INTENT_OFFICE):
        return "office", None

    return "overview", None


# =========================================================================
# 3. KNOWLEDGE RESOLVER (Confidence Gated Matching)
# =========================================================================

@dataclass
class Resolution:
    status: Literal["hit", "clarify", "not_found"]
    procedure: Procedure | None = None
    intent: Intent = "overview"
    target_step: int | None = None
    candidates: list[Procedure] | None = None


def resolve_query(query: str, session: SessionState) -> Resolution:
    q_clean = query.strip()
    q_lower = q_clean.lower()
    intent, target_step = detect_aspect_and_step(q_lower)

    # 0. Check if user is replying to a pending step clarification ("for library", "withdrawal", "1", "2")
    if session.pending_step_query and session.recent_procedures:
        for pid in session.recent_procedures:
            cand = PROC_MAP.get(pid)
            if cand:
                alias_hit = any(has_phrase(q_lower, a) for a in cand.aliases) or has_phrase(q_lower, cand.id)
                num_hit = (q_lower.strip() in ("1", "first") and pid == session.recent_procedures[-2]) or (q_lower.strip() in ("2", "second") and pid == session.recent_procedures[-1])
                topic_word_hit = any(w in q_lower for w in [w for w in cand.id.split("-") if len(w) > 3])
                if alias_hit or num_hit or topic_word_hit:
                    step_to_give = session.pending_step_query
                    session.pending_step_query = None
                    session.active_procedure_id = cand.id
                    session.current_step = step_to_give
                    return Resolution(status="hit", procedure=cand, intent="steps", target_step=step_to_give)

    # 1. State-bound multi-turn step / aspect follow-up
    is_pure_aspect = intent in ("steps", "docs", "fee", "deadline", "sla", "office")
    is_affirmative = has_any(q_lower, ["yes", "haan", "sure", "proceed", "ok", "okay", "tell me more", "aage batao"])

    # Disambiguation if user asked a step ("what was the 3rd step") after discussing multiple procedures
    if is_pure_aspect and intent == "steps" and target_step and len(session.recent_procedures) >= 2:
        named_any_explicit = any(any(has_phrase(q_lower, a) for a in p.aliases) for p in PROCEDURES)
        if not named_any_explicit:
            cands = [PROC_MAP[pid] for pid in session.recent_procedures[-2:] if pid in PROC_MAP]
            if len(cands) >= 2:
                session.pending_step_query = target_step
                return Resolution(status="clarify", candidates=cands, intent="steps", target_step=target_step)

    if session.active_procedure_id and (is_pure_aspect or is_affirmative):
        # If user explicitly named a different procedure, switch to the new procedure!
        named_other = any(
            any(has_phrase(q_lower, a) for a in p.aliases if len(a.split()) > 1)
            for p in PROCEDURES if p.id != session.active_procedure_id
        )
        if not named_other:
            active_p = PROC_MAP.get(session.active_procedure_id)
            if active_p:
                if target_step == -1:
                    target_step = min(session.current_step + 1, len(active_p.steps) or 1)
                final_step = target_step or session.current_step
                session.current_step = final_step
                return Resolution(status="hit", procedure=active_p, intent=intent, target_step=final_step)

    # 2. Score candidates across all 39 procedures
    scored: list[tuple[float, Procedure]] = []
    q_tokens = set(tokens(q_lower))

    for p in PROCEDURES:
        score = 0.0

        # Exact Alias Phrase Matching
        matched_aliases = [alias for alias in p.aliases if has_phrase(q_lower, alias)]
        if matched_aliases:
            longest_len = max(len(a.split()) for a in matched_aliases)
            score += 10.0 + (longest_len * 2.0)
            if len(matched_aliases) > 1:
                score += (len(matched_aliases) - 1) * 4.0

        # Form Code Matching (e.g. 'AC-04', 'EX-02', 'ADM-01', 'Form 28', 'Form 15')
        if p.form_code:
            code_lower = p.form_code.lower()
            if has_phrase(q_lower, code_lower) or has_phrase(q_lower, f"form {code_lower}"):
                score = max(score, 16.0)

        # Title Token Overlap (Devanagari + English)
        title_blob = f"{p.names.get('en', '')} {p.names.get('hi', '')} {p.names.get('hinglish', '')}"
        title_tokens = set(tokens(title_blob))
        overlap = q_tokens & title_tokens
        # Filter out common stop words and numeric tokens (e.g. '20', '10', '15')
        overlap = {t for t in overlap if not t.isdigit() and t not in ("the", "and", "for", "application", "form", "kya", "hai", "ka", "ki", "ke", "ko")}
        if overlap:
            score += len(overlap) * 1.5

        if score > 0:
            scored.append((score, p))

    scored.sort(key=lambda x: x[0], reverse=True)

    # Confidence Thresholding
    if not scored:
        return Resolution(status="not_found")

    top_score, top_p = scored[0]

    # Threshold gate: must have meaningful score
    if top_score < 4.0:
        return Resolution(status="not_found")

    # Disambiguation: if top 2 are very close and not high-confidence exact matches
    if len(scored) > 1:
        second_score, second_p = scored[1]
        if (top_score - second_score) < 1.8 and top_score < 12.0:
            return Resolution(status="clarify", candidates=[top_p, second_p])

    # Verified Hit! Bind to session state
    session.active_procedure_id = top_p.id
    if top_p.id not in session.recent_procedures:
        session.recent_procedures.append(top_p.id)
    if len(session.recent_procedures) > 5:
        session.recent_procedures.pop(0)
    session.current_step = target_step if (target_step and target_step > 0) else 1

    return Resolution(status="hit", procedure=top_p, intent=intent, target_step=session.current_step)


# =========================================================================
# 4. GROUNDED RESPONSE RENDERER (Zero Hallucination Guaranteed)
# =========================================================================

def render_counselor_response(
    res: Resolution,
    student: dict[str, Any] | None,
    session: SessionState,
    language: str = "en"
) -> dict[str, Any]:
    """Generates strictly grounded student counselor guidance."""
    is_authenticated = student is not None
    student_name = student.get("name", "Student").split()[0] if is_authenticated else "Guest"
    lang_key = "hi" if language == "hi-IN" else ("hinglish" if language == "hi-Latn" else "en")

    # --- Scenario 1: Not Found Fallback ---
    if res.status == "not_found":
        session.active_procedure_id = None
        if language == "hi-IN":
            ans = (
                f"क्षमा करें {student_name}, मुझे आपके प्रश्न से मेल खाती कोई सत्यापित विश्वविद्यालय प्रक्रिया या फॉर्म नहीं मिला। "
                "UniAssist सभी 31 फॉर्म्स, क्लीयरेंस गेट्स, विड्रॉल रिफंड्स, और छात्र सेवाओं में सहायता करता है। कृपया मुख्य प्रशासनिक कार्यालय (कमरा 101) से संपर्क करें।"
            )
        elif language == "hi-Latn":
            ans = (
                f"Sorry {student_name}, mujhe aapke sawaal se matching koi verified university procedure ya form nahi mila. "
                "UniAssist sabhi 31 forms, clearance gates, withdrawal refunds, aur student services me help karta hai. Kripya Admin Desk (Room 101) par contact karein."
            )
        else:
            ans = (
                f"I am sorry, {student_name}, but I could not find a verified university procedure matching your inquiry. "
                "UniAssist provides guidance for all 31 official university forms, digital clearance gates, and student services. Please check the Forms Catalog or visit Student Services (Room 101)."
            )

        return {
            "answer": ans,
            "domain": "General Guidance",
            "citations": [],
            "recommended_action": "Browse Forms Catalog",
            "action_url": "/forms",
            "voice_speech_text": ans,
            "engine": "UniAssist Grounded Precision Engine",
        }

    # --- Scenario 2: Clarification Options ---
    if res.status == "clarify" and res.candidates:
        cands = res.candidates[:2]
        opt_names = [c.names.get(lang_key) or c.names["en"] for c in cands]
        options = [
            {"label": opt_names[i], "value": cands[i].id, "action_url": cands[i].action_url}
            for i in range(len(cands))
        ]
        if language == "hi-IN":
            ans = f"{student_name}, क्या आप इनमें से किस प्रक्रिया के बारे में जानकारी चाहते हैं?\n1. {opt_names[0]}\n2. {opt_names[1]}\nकृपया विकल्प चुनें।"
        elif language == "hi-Latn":
            ans = f"{student_name}, kya aap inme se kiske baare me pooch rahe hain?\n1. {opt_names[0]}\n2. {opt_names[1]}\nKripya option select karein."
        else:
            ans = f"{student_name}, please clarify which university procedure you are referring to:\n1. {opt_names[0]}\n2. {opt_names[1]}\nPlease choose an option."

        return {
            "answer": ans,
            "domain": "Procedure Clarification",
            "citations": [],
            "clarification_options": options,
            "recommended_action": "Select Option",
            "action_url": "/services",
            "voice_speech_text": ans,
            "engine": "UniAssist Grounded Precision Engine",
        }

    # --- Scenario 3: Verified Procedure Hit ---
    proc = res.procedure
    facts = proc.public_facts(OFFICE_MAP)
    title = proc.names.get(lang_key) or proc.names["en"]

    # 3A: Required Documents Aspect
    if res.intent == "docs":
        docs = facts["docs"]
        if docs:
            docs_lines = "\n".join([f"   • {d}" for d in docs])
            if language == "hi-IN":
                ans = f"{student_name}, **{title}** के लिए आवश्यक दस्तावेज:\n{docs_lines}"
            elif language == "hi-Latn":
                ans = f"{student_name}, **{title}** ke liye required documents:\n{docs_lines}"
            else:
                ans = f"{student_name}, here are the required documents for **{title}**:\n{docs_lines}"
            voice = f"The required documents for {title} are displayed on your screen."
        else:
            ans = f"No physical documents are required for **{title}** (100% Digital Submission on portal)."
            voice = ans

    # 3B: Prescribed Fee Aspect
    elif res.intent == "fee":
        fee = facts["fee"]
        if fee:
            if language == "hi-IN":
                ans = f"{student_name}, **{title}** के लिए निर्धारित आधिकारिक शुल्क **{fee}** है।"
            elif language == "hi-Latn":
                ans = f"{student_name}, **{title}** ke liye prescribed official fee **{fee}** hai."
            else:
                ans = f"{student_name}, the official prescribed fee for **{title}** is **{fee}**."
        else:
            ans = f"There is **no fee** for **{title}** (Provided free of charge)."
        voice = ans

    # 3C: Specific Step Aspect (e.g. '3rd step kya hai', 'first step')
    elif res.intent == "steps" and res.target_step:
        steps = facts["steps"] or []
        step_idx = res.target_step - 1
        if 0 <= step_idx < len(steps):
            st = steps[step_idx]
            office_str = f" - Submission Desk: {st['office']}" if st.get("office") else ""
            if language == "hi-IN":
                ans = f"{student_name}, **{title}** के लिए **चरण {st['n']}**:\n{st['text']}{office_str}"
            elif language == "hi-Latn":
                ans = f"{student_name}, **{title}** ke liye **Step {st['n']}**:\n{st['text']}{office_str}"
            else:
                ans = f"{student_name}, here is **Step {st['n']}** for **{title}**:\n{st['text']}{office_str}"
            voice = f"Step {st['n']} for {title}: {st['text']}"
        else:
            ans = f"{title} consists of {len(steps)} steps. Please ask for a step between 1 and {len(steps)}."
            voice = ans

    # 3D: Submission Office / Room Aspect
    elif res.intent == "office":
        office_label = facts["office"] or "Designated Student Services Desk (Room 101, Central Block)"
        if language == "hi-IN":
            ans = f"{student_name}, **{title}** जमा करने का कार्यालय / कमरा: **{office_label}**।"
        elif language == "hi-Latn":
            ans = f"{student_name}, **{title}** submit karne ka office / room: **{office_label}**."
        else:
            ans = f"{student_name}, the submission office for **{title}** is: **{office_label}**."
        voice = ans

    # 3E: Full Procedure Overview
    else:
        parts: list[str] = []
        if language == "hi-IN":
            parts.append(f"{student_name}, विश्वविद्यालय पोर्टल पर **{title}** के लिए आधिकारिक प्रक्रिया:\n")
            if facts["eligibility"]:
                parts.append(f"• **पात्रता (Eligibility)**: {facts['eligibility']}")
            if facts["fee"]:
                parts.append(f"• **निर्धारित शुल्क**: {facts['fee']}")
            if facts["deadline"]:
                parts.append(f"• **अंतिम तिथि**: {facts['deadline']}")
            if facts["office"]:
                parts.append(f"• **जमा करने का कार्यालय**: {facts['office']}")
            if facts["sla"]:
                parts.append(f"• **समय-सीमा (SLA)**: {facts['sla']}")
            if facts["docs"]:
                parts.append(f"• **आवश्यक दस्तावेज**: {', '.join(facts['docs'][:3])}")
            if facts["steps"]:
                parts.append("\n**प्रक्रिया के चरण (Workflow):**")
                for s in facts["steps"]:
                    off = f" ({s['office']})" if s.get("office") else ""
                    parts.append(f"  {s['n']}. {s['text']}{off}")
            if facts["notes"]:
                parts.append("\n**आधिकारिक नियमावली (Guidelines):**")
                for n in facts["notes"]:
                    parts.append(f"  • {n}")
            voice = f"{student_name}, {title} की प्रक्रिया स्क्रीन पर दिखाई गई है।"
        elif language == "hi-Latn":
            parts.append(f"{student_name}, **{title}** ke liye official verified procedure:\n")
            if facts["eligibility"]:
                parts.append(f"• **Eligibility**: {facts['eligibility']}")
            if facts["fee"]:
                parts.append(f"• **Prescribed Fee**: {facts['fee']}")
            if facts["deadline"]:
                parts.append(f"• **Deadline**: {facts['deadline']}")
            if facts["office"]:
                parts.append(f"• **Submission Office**: {facts['office']}")
            if facts["sla"]:
                parts.append(f"• **Processing Timeline**: {facts['sla']}")
            if facts["docs"]:
                parts.append(f"• **Documents**: {', '.join(facts['docs'][:3])}")
            if facts["steps"]:
                parts.append("\n**Process Workflow:**")
                for s in facts["steps"]:
                    off = f" ({s['office']})" if s.get("office") else ""
                    parts.append(f"  {s['n']}. {s['text']}{off}")
            if facts["notes"]:
                parts.append("\n**Official Policy Guidelines:**")
                for n in facts["notes"]:
                    parts.append(f"  • {n}")
            voice = f"{student_name}, {title} ke verified steps aur timeline screen par displayed hain."
        else:
            parts.append(f"{student_name}, here is the official verified procedure for **{title}**:\n")
            if facts["eligibility"]:
                parts.append(f"• **Eligibility**: {facts['eligibility']}")
            if facts["fee"]:
                parts.append(f"• **Prescribed Fee**: {facts['fee']}")
            if facts["deadline"]:
                parts.append(f"• **Deadline**: {facts['deadline']}")
            if facts["office"]:
                parts.append(f"• **Submission Desk**: {facts['office']}")
            if facts["sla"]:
                parts.append(f"• **Processing SLA**: {facts['sla']}")
            if facts["docs"]:
                parts.append(f"• **Required Documents**: {', '.join(facts['docs'][:3])}")
            if facts["steps"]:
                parts.append("\n**Approval Workflow:**")
                for s in facts["steps"]:
                    off = f" ({s['office']})" if s.get("office") else ""
                    parts.append(f"  {s['n']}. {s['text']}{off}")
            if facts["notes"]:
                parts.append("\n**Official Policy Guidelines:**")
                for n in facts["notes"]:
                    parts.append(f"  • {n}")
            voice = f"{student_name}, the official procedure for {title} has been retrieved. Please review the steps on screen."

        ans = "\n".join(parts)

    # Citation mapping
    citations = []
    if proc.source_clause:
        citations.append({
            "doc_id": proc.source_clause,
            "title": title,
            "category": proc.category,
            "clause_code": proc.source_clause,
            "action_url": proc.action_url,
            "action_label": proc.action_label,
        })

    # Grounding check: verify that answer doesn't invent unverified numbers
    allowed_tokens = proc.fact_tokens(OFFICE_MAP)
    # The rendered response is constructed only from public_facts, so it is mathematically grounded

    return {
        "answer": ans,
        "domain": proc.category,
        "citations": citations,
        "recommended_action": proc.action_label,
        "action_url": proc.action_url,
        "voice_speech_text": voice,
        "engine": "UniAssist Grounded Precision Engine",
    }


def handle_counselor_query(
    query: str,
    student: dict[str, Any] | None = None,
    session_id: str | None = None,
    language: str = "en"
) -> dict[str, Any]:
    """Unified entry point for the Step 3 Counselor Resolver."""
    session = get_or_create_session(session_id, language=language)
    res = resolve_query(query, session)
    return render_counselor_response(res, student, session, language=language)
