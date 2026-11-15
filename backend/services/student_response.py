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
