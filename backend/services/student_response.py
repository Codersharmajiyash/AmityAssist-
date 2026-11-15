"""Small presentation-layer cleanup for student-facing counselor text."""

from __future__ import annotations

import re


def student_facing_text(value: object) -> str:
    text = str(value or "")
    # Keep institutional identifiers in structured citation metadata, not prose
    # shown or spoken to students.
    text = re.sub(r"\b(?:University\s+)?Ordinance\s+ORD-[A-Z0-9.-]+", "university rules", text, flags=re.I)
    text = re.sub(r"\bORD-[A-Z0-9.-]+\b", "", text, flags=re.I)
    text = re.sub(r"\b(?:ordinance|ordinances)\b", "university rules", text, flags=re.I)
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r" *\n *", "\n", text).strip()
    return text


def enforce_student_evidence(guidance: dict, language: str = "en-IN") -> dict:
    """Abstain on general answers with no attached evidence records."""
    domain = str(guidance.get("domain") or "").strip().casefold()
    citations = guidance.get("citations")
    has_evidence = isinstance(citations, list) and bool(citations)
    no_evidence_domains = {"general", "general guidance", "general ordinance guidance"}
    engine = str(guidance.get("engine") or "")
    if not has_evidence and (
        domain in no_evidence_domains or engine in {"UniAssist Policy Engine", "SQLite FTS5 (Local Offline)"}
    ):
        if language == "hi-IN":
            message = "यह जानकारी विश्वविद्यालय के सत्यापित रिकॉर्ड में नहीं मिली। कृपया संबंधित विभाग या छात्र सेवा डेस्क से पुष्टि करें।"
        elif language == "hi-Latn":
            message = "Yeh jaankari university ke verified records mein nahi mili. Kripya concerned department ya Student Services se confirm karein."
        else:
            message = "This information is not listed in the verified university records available to me. Please confirm with the responsible department or Student Services."
        guidance["answer"] = message
        guidance["voice_speech_text"] = message
        guidance["citations"] = []
        guidance["recommended_action"] = None
        guidance["action_url"] = None
    return guidance
