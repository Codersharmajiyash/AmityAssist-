"""Local, auditable AI service for UniAssist with Ollama (Llama 3.2) integration.

This module combines on-premise local LLM inference via Ollama (Llama 3.2)
with deterministic citation templates as a fallback. It never invents policy outcomes
and always grounds responses in the verified citation set returned by SQLite FTS5.
"""

from __future__ import annotations

import re
from typing import Any
import httpx

from ..config import settings


def _safe_title(citation: dict[str, Any]) -> str:
    return str((citation or {}).get("title") or "verified university guidance").strip()


def _safe_clause(citation: dict[str, Any]) -> str:
    return str((citation or {}).get("clause_code") or "Policy clause").strip()


def _safe_content(citation: dict[str, Any]) -> str:
    content = str((citation or {}).get("content") or "").strip()
    return content[:500]


def strip_markdown_stars(text: str) -> str:
    """Remove markdown bold asterisks and stray asterisks while preserving line breaks and structure."""
    if not text:
        return ""
    cleaned = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    cleaned = re.sub(r"\*([^*]+)\*", r"\1", cleaned)
    cleaned = re.sub(r"\*", "", cleaned)
    return cleaned


def clean_text_for_speech(text: str) -> str:
    """Strip markdown headers, bold asterisks, and code formatting for speech friendliness."""
    if not text:
        return ""
    cleaned = strip_markdown_stars(text)
    cleaned = re.sub(r"#{1,6}\s*", "", cleaned)
    cleaned = re.sub(r"`([^`]+)`", r"\1", cleaned)
    cleaned = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", cleaned)
    cleaned = re.sub(r"[-*]\s+", "", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned


VERIFIED_ROOMS = {"201", "103", "105", "110", "101", "102"}


def sanitize_and_verify_response(text: str, evidence_text: str | None = None) -> str:
    """Post-processing guardrails to ensure responses are concise, grounded, and free of fake rooms."""
    if not text:
        return ""
    cleaned = clean_text_for_speech(text)
    if evidence_text is not None:
        answer_numbers = set(re.findall(r"\b\d+(?:[.,]\d+)?\s*%?", cleaned))
        evidence_numbers = set(re.findall(r"\b\d+(?:[.,]\d+)?\s*%?", evidence_text))
        if answer_numbers - evidence_numbers:
            return ""

    # 0. Intercept LLM meta-roleplay preambles & conversational scenario setups
    meta_patterns = [
        r"^based on the (provided|verified) (text|documents|records|information)[^\n:.]*[:.]?\s*",
        r"^here are the (detailed )?(budget breakdowns|steps|procedures)[^\n:.]*[:.]?\s*",
        r"^detailed budget breakdown:\s*",
        r"^here is the updated conversation:.*?(counselor response:|counselor:)\s*",
        r"^here is an updated conversation:.*?(counselor response:|counselor:)\s*",
        r"^user query:.*?(counselor response:|counselor:)\s*",
        r"^here is the updated conversation:[^\n:]*:\s*",
        r"^it seems like you're trying to create a scenario[^\n.!?]*[.!?]?\s*",
        r"^i'll provide a possible response[^\n.!?]*[.!?]?\s*",
        r"^here is a possible response[^\n.!?]*[.!?]?\s*",
        r"^response:\s*(counselor:)?\s*",
        r"^counselor response:\s*",
        r"^counselor:\s*",
        r"^as an ai[^\n.!?]*[.!?]?\s*",
    ]
    for mp in meta_patterns:
        cleaned = re.sub(mp, "", cleaned, flags=re.IGNORECASE).strip()

    # Intercept hallucinated harassment or misconduct encouragement
    if any(p in cleaned.lower() for p in ["teacher ko pareshaan", "pareshan karna chahiye", "pareshaan karna chaahiye", "trouble the teacher", "harass"]):
        return "Sorry, main is baare me help nahi kar sakta. University Code of Conduct ke mutabiq teachers ya staff ko pareshaan karna strictly prohibited hai."

    # 1. Strip internal legalistic codes from spoken response
    cleaned = re.sub(r"\[?(ORD-[A-Z0-9.-]+|OCRM-[A-Z0-9.-]+)\]?", "university regulations", cleaned, flags=re.IGNORECASE)

    # 2. Intercept hallucinated room numbers: Room <number> or कमरा <number> or कक्ष <number>
    allowed_rooms = (
        set(re.findall(r"(?:Room|कमरा|कक्ष)\s*#?\s*(\d{2,4})", evidence_text, flags=re.IGNORECASE))
        if evidence_text is not None else VERIFIED_ROOMS
    )

    def _room_replacer(match: re.Match) -> str:
        prefix = match.group(1)
        num = match.group(2)
        if num in allowed_rooms:
            return match.group(0)
        if any(term in prefix.lower() for term in ["कमरा", "कक्ष"]):
            return "विश्वविद्यालय प्रशासनिक डेस्क"
        return "the designated university desk"

    cleaned = re.sub(r"(Room|room|कमरा|कक्ष)\s*#?\s*(\d{2,4})", _room_replacer, cleaned)
    # Intercept fake service centers: सेवा केंद्र 3, Service Center 3, etc.
    cleaned = re.sub(r"(सेवा\s*केंद्र|Service\s*Center)\s*\d+", "विश्वविद्यालय कार्यालय", cleaned, flags=re.IGNORECASE)

    # 3. Hard sentence ceiling: Max 3 to 4 complete sentences without breaking abbreviations (e.g. B.Tech, Dr., 7.5)
    sentence_delimiters = re.split(r'(?<!\b[A-Za-z])(?<!\b[A-Z][a-z])(?<!\d)([.!?।])(?:\s+|$)', cleaned)
    if len(sentence_delimiters) > 1:
        reconstructed = []
        sentence_count = 0
        for i in range(0, len(sentence_delimiters) - 1, 2):
            sent = sentence_delimiters[i].strip()
            punct = sentence_delimiters[i + 1]
            if sent:
                reconstructed.append(f"{sent}{punct}")
                sentence_count += 1
                if sentence_count >= 3:
                    break
        if reconstructed:
            cleaned = " ".join(reconstructed)

    return cleaned.strip()


def check_ollama_status() -> dict[str, Any]:
    """Check connectivity to the local Ollama daemon and list available models."""
    url = f"{settings.ollama_base_url.rstrip('/')}/api/tags"
    try:
        with httpx.Client(timeout=2.0) as client:
            resp = client.get(url)
            if resp.status_code == 200:
                data = resp.json()
                models = [m.get("name") for m in data.get("models", [])]
                model_ready = any(settings.ollama_model in m for m in models)
                return {
                    "online": True,
                    "target_model": settings.ollama_model,
                    "model_installed": model_ready,
                    "available_models": models,
                    "base_url": settings.ollama_base_url,
                }
    except Exception as exc:
        return {
            "online": False,
            "target_model": settings.ollama_model,
            "model_installed": False,
            "available_models": [],
            "base_url": settings.ollama_base_url,
            "error": str(exc),
        }
    return {
        "online": False,
        "target_model": settings.ollama_model,
        "model_installed": False,
        "available_models": [],
        "base_url": settings.ollama_base_url,
    }


def ensure_ollama_daemon_running() -> bool:
    """Check if Ollama daemon is active; if not, automatically launch 'ollama serve' in background."""
    import os
    import sys
    import shutil
    import subprocess

    status = check_ollama_status()
    if status.get("online"):
        return True

    # Only attempt to auto-launch if explicitly enabled to prevent llama-server.exe crash dialogs on Windows
    if os.getenv("OLLAMA_AUTOSPAWN", "false").lower() not in ("true", "1", "yes"):
        return False

    ollama_path = shutil.which("ollama")
    if not ollama_path:
        local_app_data = os.getenv("LOCALAPPDATA", "")
        candidate = os.path.join(local_app_data, "Programs", "Ollama", "ollama.exe")
        if os.path.exists(candidate):
            ollama_path = candidate

    if ollama_path:
        try:
            creationflags = 0
            if sys.platform == "win32":
                creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000) | getattr(subprocess, "DETACHED_PROCESS", 0x00000008)
            subprocess.Popen(
                [ollama_path, "serve"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL,
                creationflags=creationflags,
                shell=False,
            )
            return True
        except Exception:
            return False
    return False


def call_ollama_llama3(
    prompt: str,
    system_instruction: str,
    model: str | None = None,
    timeout: float | None = None,
    history: list[dict[str, Any]] | None = None,
) -> str | None:
    """Send an inference request to the local Ollama daemon with optional multi-turn conversation history."""
    target_model = model or settings.ollama_model
    request_timeout = timeout or settings.ollama_timeout_seconds
    url = f"{settings.ollama_base_url.rstrip('/')}/api/chat"

    messages: list[dict[str, str]] = [
        {"role": "system", "content": system_instruction}
    ]
    if history:
        # Bounded history window: last 4 turns, max 400 chars/turn to prevent context explosion and prompt injection
        for turn in history[-4:]:
            raw_role = str(turn.get("role", "user")).lower()
            role = "assistant" if raw_role in ("assistant", "model", "bot", "counselor") else "user"
            content = str(turn.get("content") or turn.get("message") or turn.get("text") or "")[:400].strip()
            if content:
                messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": prompt})

    payload = {
        "model": target_model,
        "messages": messages,
        "stream": False,
        "keep_alive": "60m",  # Keeps model hot in RAM/VRAM; zero delay between queries
        "options": {
            "temperature": 0.1,        # Deterministic, prevents creative hallucinations
            "top_p": 0.9,
            "repeat_penalty": 1.1,
            "num_predict": 85,         # Caps answer to 1-2 snappy sentences (~600ms generation)
            "num_ctx": 1024,
        },
    }

    try:
        with httpx.Client(timeout=request_timeout) as client:
            resp = client.post(url, json=payload)
            if resp.status_code == 200:
                data = resp.json()
                content = data.get("message", {}).get("content", "")
                if content and content.strip():
                    return sanitize_and_verify_response(content.strip(), evidence_text=facts_text)
    except Exception:
        return None
    return None


def generate_local_policy_answer(
    query: str,
    citations: list[dict[str, Any]],
    student: dict[str, Any] | None = None,
    page_context: dict[str, Any] | None = None,
    language: str = "en-IN",
    use_ollama: bool = True,
    history: list[dict[str, Any]] | None = None,
) -> str | None:
    """Return a concise answer using verified university clauses via Ollama or template fallback.

    If there is no verified citation set, refuses rather than fabricating.
    """
    if not query or not query.strip():
        return None
    if not citations:
        if language == "hi-IN":
            return "यह जानकारी विश्वविद्यालय के सत्यापित रिकॉर्ड में नहीं मिली। कृपया संबंधित विभाग से पुष्टि करें।"
        elif language == "hi-Latn":
            return "Yeh jaankari university ke verified records mein nahi mili. Kripya concerned department se confirm karein."
        return "This information is not listed in the verified university records available to me. Please confirm with the responsible department."

    # Reject a retrieval set that does not share a meaningful subject with the
    # query before either model synthesis or deterministic citation formatting.
    q_words = set(re.findall(r"[^\W_]+", query.lower(), flags=re.UNICODE))
    stop_words = {
        "what", "which", "where", "when", "who", "how", "is", "are", "was", "were", "the", "a", "an",
        "of", "for", "to", "in", "on", "my", "me", "i", "you", "do", "does", "can", "could", "please",
        "tell", "give", "show", "about", "step", "steps", "next", "previous", "this", "that", "it",
        "kya", "hai", "ka", "ki", "ke", "ko", "mujhe", "mera", "meri", "batao", "please",
        "क्या", "है", "का", "की", "के", "मुझे", "बताइए", "बताओ", "कौन", "कब", "कहाँ", "कैसे",
    }
    q_words = {word for word in q_words if len(word) > 2 and word not in stop_words and not word.isdigit()}
    evidence_words = set(re.findall(
        r"[^\W_]+",
        " ".join(f"{_safe_title(c)} {_safe_content(c)}" for c in citations).lower(),
        flags=re.UNICODE,
    ))
    if not q_words or not (q_words & evidence_words):
        if language == "hi-IN":
            return "यह जानकारी विश्वविद्यालय के सत्यापित रिकॉर्ड में नहीं मिली। कृपया संबंधित विभाग से पुष्टि करें।"
        if language == "hi-Latn":
            return "Yeh jaankari university ke verified records mein nahi mili. Kripya concerned department se confirm karein."
        return "This information is not listed in the verified university records available to me. Please confirm with the responsible department."

    student_name = (student or {}).get("name", "Student").split()[0]
    student_attendance = (student or {}).get("attendance", "N/A")
    student_fee_status = (student or {}).get("fee_status", "N/A")
    page_name = (page_context or {}).get("screen_name") or "the current panel"

    # Step 1: Attempt local Ollama inference if enabled / requested
    if use_ollama:
        from ..data.kiosk_master_procedures import get_procedure_by_keyword

        facts_text = "\n".join(
            [
                f"- {_safe_title(c)}: {_safe_content(c)}"
                for c in citations[:3]
            ]
        )

        matched_procedure = get_procedure_by_keyword(query)

        # Anti-Hallucination Relevance Guard: Never send unrelated citations to LLM
        q_words = [w for w in re.sub(r"[^\w\s]", " ", query.lower()).split() if len(w) >= 3 and w not in ("what", "which", "where", "how", "tell", "give", "from", "with", "this", "that", "there", "then", "have", "need", "want", "please", "karo", "batao", "step", "steps", "final", "last", "next", "pehla", "aakhri")]
        citation_text = " ".join([f"{_safe_title(c)} {_safe_content(c)}" for c in citations]).lower()
        has_subject_overlap = any(w in citation_text for w in q_words) or matched_procedure is not None

        if not has_subject_overlap and q_words:
            if language == "hi-IN":
                return f"मुझे क्षमा करें, {student_name}, लेकिन मुझे आपके इस प्रश्न से संबंधित कोई विशिष्ट विश्वविद्यालय अध्यादेश नहीं मिला। कृपया अपने विषय (जैसे विड्रॉल, उपस्थिति, परीक्षा, या फॉर्म का नाम) के साथ पूछें।"
            elif language == "hi-Latn":
                return f"Sorry {student_name}, mujhe aapke question se matching koi specific university rule nahi mila. Please topic mention karein (jaise withdrawal, attendance, exam, ya fee)."
            return f"I am sorry, {student_name}, but I could not find a specific university ordinance matching your inquiry. Please specify the topic (such as withdrawal, attendance, fees, or form name) so I can assist you."

        if matched_procedure:
            req_docs = ", ".join(matched_procedure.get("required_documents") or ["Not specified in verified records"])
            facts_text += (
                f"\nOFFICIAL MASTER PROCEDURE GROUNDING:\n"
                f"- Official Form: {matched_procedure.get('official_name', 'University Form')}\n"
                f"- Kiosk Access: {matched_procedure.get('action_label') or 'Not specified in verified records'}\n"
                f"- Eligibility: {matched_procedure.get('eligibility') or 'Not specified in verified records'}\n"
                f"- Required Attachments: {req_docs}\n"
                f"- Verified Submission Office: {matched_procedure.get('submission_office') or 'Not specified in verified records'}\n"
                f"- Turnaround SLA: {matched_procedure.get('deadline_sla') or 'Not specified in verified records'}\n"
            )

        # Dynamically inject live configured workflow steps and custom procedures into grounding
        try:
            from .procedure_service import ProcedureService
            q_lower_check = query.lower()
            if any(w in q_lower_check for w in ["withdrawal", "refund", "विड्रॉल", "रिफंड"]):
                live_wth_steps = ProcedureService.get_steps("withdrawal")
                if live_wth_steps:
                    steps_summary = "; ".join([f"Step {s['step_number']}: {s['title']} ({s['department']})" for s in live_wth_steps])
                    facts_text += f"\n- Live Clearance Workflow Steps ({len(live_wth_steps)} stages): {steps_summary}"

            active_procs = ProcedureService.list_procedures(active_only=True)
            matched = [
                ap for ap in active_procs
                if (ap.get("title") or "").strip().lower()
                and (ap.get("title") or "").strip().lower() in q_lower_check
            ]
            matched_custom = matched[0] if len(matched) == 1 else None
            if matched_custom:
                step_list = matched_custom.get("steps") or []
                s_desc = "; ".join([f"Step {s.get('step_number', idx+1)}: {s.get('title')} ({s.get('responsible_desk') or 'Desk'})" for idx, s in enumerate(step_list)]) if step_list else "Not specified in verified records"
                docs_desc = ", ".join(matched_custom.get("required_docs") or ["Not specified in verified records"])
                facts_text = (
                    f"OFFICIAL CONFIGURED PROCEDURE ({matched_custom.get('title')}):\n"
                    f"- Department: {matched_custom.get('department') or 'Not specified in verified records'}\n"
                    f"- Total Steps ({len(step_list)}): {s_desc}\n"
                    f"- SLA: {str(matched_custom.get('sla_days')) + ' days' if matched_custom.get('sla_days') else 'Not specified in verified records'}\n"
                    f"- Required Documents: {docs_desc}\n\n"
                    f"VERIFIED ORDINANCES:\n{facts_text}"
                )
        except Exception:
            pass

        lang_instruction = "Respond in warm, professional, and concise Indian English for text-to-speech."
        if language == "hi-IN":
            lang_instruction = (
                "Respond strictly in pure, natural, fluent Devanagari Hindi (हिन्दी). "
                "Use a warm campus counselor voice suitable for audio playback."
            )
        elif language == "hi-Latn":
            lang_instruction = (
                "Respond in conversational Hinglish (Hindi written in Roman script) "
                "suitable for friendly voice assistance."
            )

        system_instruction = (
            "You are UniAssist, an empathetic digital campus counselor at an official university kiosk.\n"
            f"{lang_instruction}\n"
            "STRICT RULES:\n"
            "1. Use only verified records below for university-specific facts. If a requested detail is absent, say it is not listed. Never guess or extrapolate.\n"
            "2. If records conflict or match multiple procedures, do not choose one; ask which procedure applies or say the record needs confirmation.\n"
            "3. Do not introduce facts, amounts, dates, thresholds, forms, desks, or rooms from general model knowledge.\n"
            "4. Keep factual content the same in English, Hindi, and Hinglish; translate wording without changing facts.\n"
            "5. Only give a next step if the records provide it.\n"
            "6. Do not recite internal source codes to students.\n"
            "7. Mention a kiosk action, office, or room only if the verified records below explicitly provide it."
        )

        user_prompt = (
            f"VERIFIED UNIVERSITY ORDINANCES:\n{facts_text}\n\n"
            f"STUDENT CONTEXT:\nName: {student_name}, Attendance: {student_attendance}%, Fee Status: {student_fee_status}\n"
            f"CURRENT SCREEN: {page_name}\n\n"
            f"STUDENT QUESTION:\n{query}"
        )

        ollama_result = call_ollama_llama3(user_prompt, system_instruction, history=None)
        if ollama_result:
            grounded_reply = sanitize_and_verify_response(ollama_result[:1200], evidence_text=facts_text)
            if grounded_reply:
                return grounded_reply

    # Step 2: Deterministic Citation Fallback (Guaranteed Safe, Direct & Professional)
    first = citations[0]
    clause = _safe_clause(first)
    title = _safe_title(first)
    summary = _safe_content(first)

    if language == "hi-IN":
        answer = (
            f"{student_name}, {title} (अध्यादेश {clause}) के संबंध में आधिकारिक विश्वविद्यालय नियम निम्नलिखित हैं:\n\n"
            f"{summary}\n\n"
        )
    elif language == "hi-Latn":
        answer = (
            f"{student_name}, {title} (Ordinance {clause}) ke verified university rules yeh hain:\n\n"
            f"{summary}\n\n"
        )
    else:
        answer = (
            f"{student_name}, official university guidance regarding {title} (Ordinance {clause}):\n\n"
            f"{summary}\n\n"
        )

    return answer[:1200]
