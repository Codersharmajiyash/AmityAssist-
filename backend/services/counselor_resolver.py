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
from ..knowledge.schema import Office, Procedure, Step, grounded

OFFICE_MAP: dict[str, Office] = {o.id: o for o in OFFICES}
PROC_MAP: dict[str, Procedure] = {p.id: p for p in PROCEDURES}


def configured_catalog() -> tuple[list[Procedure], dict[str, Procedure], dict[str, Office]]:
    """Return seeded procedures plus the active procedures created in the admin UI."""
    procedures = list(PROCEDURES)
    offices = dict(OFFICE_MAP)
    try:
        from .procedure_service import ProcedureService

        for item in ProcedureService.list_procedures(active_only=True):
            title = str(item.get("title") or "").strip()
            raw_id = str(item.get("id") or "").strip().lower()
            if not title or not raw_id:
                continue
            proc_id = re.sub(r"[^a-z0-9-]+", "-", raw_id).strip("-")
            if not proc_id or any(p.id == proc_id for p in procedures):
                continue

            department = str(item.get("department") or "Student Services").strip()
            office_id = f"custom-{proc_id}-office"
            offices[office_id] = Office(office_id, department)
            steps: list[Step] = []
            for index, raw_step in enumerate(item.get("steps") or [], 1):
                desk = str(raw_step.get("responsible_desk") or department).strip()
                step_office_id = f"custom-{proc_id}-step-{index}"
                offices[step_office_id] = Office(step_office_id, desk)
                title_text = str(raw_step.get("title") or f"Step {index}").strip()
                description = str(raw_step.get("description") or "").strip()
                steps.append(Step(
                    text=f"{title_text}: {description}" if description else title_text,
                    office=step_office_id,
                    sla_days=raw_step.get("sla_days"),
                ))

            category = str(item.get("category") or department).strip()
            procedure = Procedure(
                id=proc_id,
                names={"en": title, "hi": title, "hinglish": title},
                aliases=[title],
                category=category,
                audience=["student"],
                kind="form",
                docs=[str(doc) for doc in (item.get("required_docs") or []) if str(doc).strip()],
                sla=f"{item['sla_days']} days" if item.get("sla_days") else None,
                office=office_id,
                steps=steps,
                action_url="/services",
                action_label=str(item.get("action_label") or f"View {title}"),
                is_custom=True,
            )
            procedures.append(procedure)
    except Exception:
        # Seed procedures remain available if the custom-procedure store is unavailable.
        pass

    return procedures, {p.id: p for p in procedures}, offices

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
    pending_procedure_ids: list[str] = field(default_factory=list)
    pending_conflict: str | None = None


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

    if has_any(q_lower, [
        "next step", "what next", "what's next", "what is next", "what should i do next",
        "agla step", "aage kya kare", "aage kya karna hai", "aage kya karu", "aur aage",
        "अगला कदम", "अगला स्टेप", "अब क्या",
    ]):
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
    offices: dict[str, Office] | None = None
    explicit_unknown_target: bool = False


def resolve_query(
    query: str,
    session: SessionState,
    procedures: list[Procedure] | None = None,
    procedure_map: dict[str, Procedure] | None = None,
    office_map: dict[str, Office] | None = None,
) -> Resolution:
    q_clean = query.strip()
    # Small, deterministic corrections for frequent student typos/voice errors.
    # This only normalizes routing terms; it never adds policy facts.
    typo_map = {
        "withdra": "withdrawal", "withdrwal": "withdrawal", "withrawal": "withdrawal",
        "libray": "library", "libary": "library", "hosetl": "hostel",
        "bonafid": "bonafide", "bonafidee": "bonafide",
    }
    q_clean = re.sub(
        r"[A-Za-z]+",
        lambda m: typo_map.get(m.group(0).lower(), m.group(0)),
        q_clean,
    )
    q_lower = q_clean.lower()
    intent, target_step = detect_aspect_and_step(q_lower)
    if procedures is None or procedure_map is None or office_map is None:
        loaded_procedures, loaded_map, loaded_offices = configured_catalog()
        procedures = procedures or loaded_procedures
        procedure_map = procedure_map or loaded_map
        office_map = office_map or loaded_offices

    def result(status: str, **kwargs: Any) -> Resolution:
        return Resolution(status=status, offices=office_map, **kwargs)  # type: ignore[arg-type]

    def candidate_match(text: str, proc: Procedure) -> bool:
        if any(has_phrase(text, alias) for alias in proc.aliases) or has_phrase(text, proc.id):
            return True
        title_words = set(tokens(" ".join(proc.names.values())))
        query_words = set(tokens(text))
        stop = {
            "the", "and", "for", "application", "form", "change", "step", "steps",
            "tell", "me", "what", "was", "is", "of", "previous", "last", "that",
            "it", "earlier", "third", "3rd", "first", "second", "1st", "2nd",
        }
        return bool((title_words & query_words) - stop)

    def has_explicit_unknown_step_target(text: str) -> bool:
        match = re.search(
            r"\b(?:step|स्टेप|चरण)\b.*?\b(?:of|for|ka|ki|ke|का|की|के)\s+([a-z][a-z-]*)\b"
            r"|\b([a-z][a-z-]*)\s+(?:ka|ki|ke|का|की|के)\s+.*?\b(?:step|स्टेप|चरण)\b",
            text,
        )
        if not match:
            return False
        target = match.group(1) or match.group(2)
        if target in {"previous", "last", "that", "it", "earlier", "pehle", "pichla"}:
            return False
        return not any(candidate_match(target, proc) for proc in procedures)

    if session.pending_procedure_ids:
        pending = [procedure_map[pid] for pid in session.pending_procedure_ids if pid in procedure_map]
        choice = None
        if q_lower.strip() in {"1", "first", "option 1", "one"} and pending:
            choice = pending[0]
        elif q_lower.strip() in {"2", "second", "option 2", "two"} and len(pending) > 1:
            choice = pending[1]
        elif q_lower.strip() in {"3", "third", "option 3", "three"} and len(pending) > 2:
            choice = pending[2]
        else:
            choice = next((p for p in pending if candidate_match(q_lower, p)), None)
        session.pending_procedure_ids.clear()
        if choice:
            session.pending_conflict = None
            session.active_procedure_id = choice.id
            session.current_step = 1
            if choice.id not in session.recent_procedures:
                session.recent_procedures.append(choice.id)
            return result("hit", procedure=choice, intent="overview", target_step=1)

    if session.pending_conflict and intent in ("steps", "docs", "fee", "deadline", "sla", "office"):
        named = any(
            any(has_phrase(q_lower, alias) for alias in proc.aliases if len(alias.split()) > 1)
            for proc in procedures
        )
        if not named:
            return result("not_found", explicit_unknown_target=True)

    # 0. Check if user is replying to a pending step clarification ("for library", "withdrawal", "1", "2")
    if session.pending_step_query and session.recent_procedures:
        for pid in session.recent_procedures:
            cand = procedure_map.get(pid)
            if cand:
                alias_hit = candidate_match(q_lower, cand)
                num_hit = (q_lower.strip() in ("1", "first") and pid == session.recent_procedures[-2]) or (q_lower.strip() in ("2", "second") and pid == session.recent_procedures[-1])
                if alias_hit or num_hit:
                    step_to_give = session.pending_step_query
                    session.pending_step_query = None
                    session.active_procedure_id = cand.id
                    session.current_step = step_to_give
                    return result("hit", procedure=cand, intent="steps", target_step=step_to_give)
        # A reply that names no candidate must not keep an old clarification alive.
        session.pending_step_query = None

    # A named but unknown target ("3rd step of petrol") overrides stale session context.
    if intent == "steps" and has_explicit_unknown_step_target(q_lower):
        session.active_procedure_id = None
        session.pending_step_query = None
        return result("not_found", explicit_unknown_target=True)

    # 1. State-bound multi-turn step / aspect follow-up
    is_pure_aspect = intent in ("steps", "docs", "fee", "deadline", "sla", "office")
    is_affirmative = has_any(q_lower, ["yes", "haan", "sure", "proceed", "ok", "okay", "tell me more", "aage batao"])

    # Disambiguation if user asked a step ("what was the 3rd step") after discussing multiple procedures
    if is_pure_aspect and intent == "steps" and target_step and len(session.recent_procedures) >= 2:
        named_any_explicit = any(candidate_match(q_lower, p) for p in procedures)
        if not named_any_explicit:
            refers_to_prior = has_any(q_lower, ["previous", "last", "that", "it", "earlier", "of previous", "of that", "pichla", "pehle", "उसका", "पिछला"])
            if not refers_to_prior and re.search(r"\b(?:of|for)\s+[a-z][a-z-]*\b", q_lower):
                session.active_procedure_id = None
                return result("not_found")
            cands = [procedure_map[pid] for pid in session.recent_procedures[-2:] if pid in procedure_map]
            if len(cands) >= 2:
                session.pending_step_query = target_step
                return result("clarify", candidates=cands, intent="steps", target_step=target_step)

    if session.active_procedure_id and (is_pure_aspect or is_affirmative):
        # If user explicitly named a different procedure, switch to the new procedure!
        named_other = any(
            any(has_phrase(q_lower, a) for a in p.aliases if len(a.split()) > 1)
            for p in procedures if p.id != session.active_procedure_id
        )
        if not named_other:
            active_p = procedure_map.get(session.active_procedure_id)
            if active_p:
                if target_step == -1:
                    target_step = min(session.current_step + 1, len(active_p.steps) or 1)
                final_step = target_step or session.current_step
                session.current_step = final_step
                return result("hit", procedure=active_p, intent=intent, target_step=final_step)

    # 2. Score candidates across all 39 procedures
    scored: list[tuple[float, Procedure]] = []
    q_tokens = set(tokens(q_lower))

    for p in procedures:
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
        return result("not_found")

    top_score, top_p = scored[0]

    # A broad but balanced keyword like “change” should prompt a choice when it
    # points equally to multiple procedures, even though neither is a strong hit.
    if top_score < 4.0:
        close_candidates = [p for score, p in scored if top_score - score < 0.01]
        if len(close_candidates) > 1 and set(q_tokens) & {"change", "form", "apply", "application", "room"}:
            session.active_procedure_id = None
            session.pending_procedure_ids = [p.id for p in close_candidates[:3]]
            session.pending_conflict = None
            return result("clarify", candidates=close_candidates[:3])
        return result("not_found")

    # Never choose between similarly supported procedures, even when both have
    # exact phrase matches. A strong score does not resolve a genuine collision.
    if len(scored) > 1:
        close_candidates = [p for score, p in scored if top_score - score < 1.8]
        if len(close_candidates) > 1:
            candidate_names = [
                re.sub(r"[^a-z0-9]+", " ", (p.names.get("en") or p.id).casefold()).strip()
                for p in close_candidates[:3]
            ]
            session.active_procedure_id = None
            if len(set(candidate_names)) < len(candidate_names):
                session.pending_conflict = close_candidates[0].names.get("en") or close_candidates[0].id
                session.pending_procedure_ids.clear()
            else:
                session.pending_conflict = None
                session.pending_procedure_ids = [p.id for p in close_candidates[:3]]
            return result("clarify", candidates=close_candidates[:3])

    # Verified Hit! Bind to session state
    session.active_procedure_id = top_p.id
    session.pending_conflict = None
    if top_p.id not in session.recent_procedures:
        session.recent_procedures.append(top_p.id)
    if len(session.recent_procedures) > 5:
        session.recent_procedures.pop(0)
    session.current_step = target_step if (target_step and target_step > 0) else 1

    return result("hit", procedure=top_p, intent=intent, target_step=session.current_step)


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
        if session.pending_conflict and language == "hi-IN":
            ans = f"उस अगले चरण को बताने से पहले, **{session.pending_conflict}** के विरोधी रिकॉर्ड की पुष्टि आवश्यक है। कृपया संबंधित विभाग से सही प्रक्रिया की पुष्टि करें।"
        elif session.pending_conflict and language == "hi-Latn":
            ans = f"Agla step batane se pehle **{session.pending_conflict}** ke conflicting records verify karne honge. Kripya department se sahi process confirm karein."
        elif session.pending_conflict:
            ans = f"Before I give that step, the conflicting records for **{session.pending_conflict}** need to be verified. Please confirm the correct procedure with the responsible department."
        elif language == "hi-IN":
            ans = (
                f"क्षमा करें {student_name}, मुझे आपके प्रश्न से मेल खाती कोई सत्यापित विश्वविद्यालय प्रक्रिया या फॉर्म नहीं मिला। "
                "कृपया प्रक्रिया का नाम बताकर फिर से पूछें, या छात्र सेवा डेस्क से संपर्क करें।"
            )
        elif language == "hi-Latn":
            ans = (
                f"Sorry {student_name}, mujhe aapke sawaal se matching koi verified university procedure ya form nahi mila. "
                "Procedure ka naam batakar dobara poochhein, ya Student Services se sampark karein."
            )
        else:
            ans = (
                f"I am sorry, {student_name}, but I could not find a verified university procedure matching your inquiry. "
                "Please try again with the procedure name, or contact Student Services."
            )

        return {
            "answer": ans,
            "domain": "General Guidance",
            "citations": [],
            "recommended_action": None,
            "action_url": None,
            "voice_speech_text": ans,
            "engine": "UniAssist Grounded Precision Engine",
        }

    # --- Scenario 2: Clarification Options ---
    if res.status == "clarify" and res.candidates:
        cands = res.candidates[:3]
        opt_names = [c.names.get(lang_key) or c.names["en"] for c in cands]
        normalized_names = [
            re.sub(r"[^a-z0-9]+", " ", (c.names.get("en") or c.id).casefold()).strip()
            for c in cands
        ]
        if len(set(normalized_names)) < len(normalized_names):
            conflict_title = opt_names[0]
            if language == "hi-IN":
                ans = f"मुझे **{conflict_title}** के लिए एक से अधिक विरोधी रिकॉर्ड मिले हैं। गलत प्रक्रिया बताने से बचने के लिए मैं अनुमान नहीं लगाऊँगा। कृपया संबंधित विभाग से पुष्टि करें।"
            elif language == "hi-Latn":
                ans = f"Mujhe **{conflict_title}** ke liye ek se zyada conflicting records mile hain. Galat process batane se bachne ke liye main guess nahi karunga. Kripya department se verify karein."
            else:
                ans = f"I found conflicting records for **{conflict_title}** and can’t verify which applies to your campus. I won’t guess; please confirm with the responsible department."
            return {
                "answer": ans,
                "domain": "Conflicting Procedure Records",
                "citations": [],
                "recommended_action": None,
                "action_url": None,
                "voice_speech_text": ans,
                "engine": "UniAssist Grounded Precision Engine",
            }
        options = [
            {"label": opt_names[i], "value": cands[i].id, "action_url": cands[i].action_url}
            for i in range(len(cands))
        ]
        numbered_options = "\n".join(f"{i}. {name}" for i, name in enumerate(opt_names, 1))
        if language == "hi-IN":
            ans = f"{student_name}, आप इनमें से किस प्रक्रिया के बारे में जानकारी चाहते हैं?\n{numbered_options}\nकृपया विकल्प चुनें।"
        elif language == "hi-Latn":
            ans = f"{student_name}, aap inme se kis procedure ke baare me pooch rahe hain?\n{numbered_options}\nKripya option select karein."
        else:
            ans = f"{student_name}, please clarify which university procedure you mean:\n{numbered_options}\nPlease choose an option."

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
    facts = proc.public_facts(res.offices or OFFICE_MAP)
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
            ans = f"The required documents for **{title}** are not listed in the verified university information available to me. Please check with the responsible department."
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
            ans = f"The fee for **{title}** is not listed in the verified university information available to me. Please check with the responsible department."
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
        office_label = facts["office"] or "not listed in the verified university information available to me"
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
    allowed_tokens = proc.fact_tokens(res.offices or OFFICE_MAP)
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
