"""Local, auditable AI fallback for UniAssist.

This module intentionally does not invent policy outcomes. It only synthesizes
responses from the verified citation set returned by the FTS5 + workflow engine.
The goal is to keep local inference useful without creating hallucinated
university rules, refund slabs, or submission instructions.
"""

from __future__ import annotations

from typing import Any


def _safe_title(citation: dict[str, Any]) -> str:
    return str((citation or {}).get("title") or "verified university guidance").strip()


def _safe_clause(citation: dict[str, Any]) -> str:
    return str((citation or {}).get("clause_code") or "Policy clause").strip()


def _safe_content(citation: dict[str, Any]) -> str:
    content = str((citation or {}).get("content") or "").strip()
    return content[:500]


def generate_local_policy_answer(
    query: str,
    citations: list[dict[str, Any]],
    student: dict[str, Any] | None = None,
    page_context: dict[str, Any] | None = None,
) -> str | None:
    """Return a concise answer using only verified university clauses.

    If there is no verified citation set, the local LLM refuses rather than
    fabricating a policy answer.
    """
    if not query or not query.strip():
        return None
    if not citations:
        return (
            "I can only provide answers grounded in verified university policy and workflow records. "
            "No matching ordinance or guidance was found for this request."
        )

    student_name = (student or {}).get("name", "Student").split()[0]
    page_name = (page_context or {}).get("screen_name") or "the current panel"

    first = citations[0]
    clause = _safe_clause(first)
    title = _safe_title(first)
    summary = _safe_content(first)

    answer = (
        f"{student_name}, I can answer this using only verified university guidance. "
        f"The closest policy reference is {clause} ({title}). "
        f"Verified guidance: {summary}. "
        f"For anything urgent or final, please confirm with the relevant desk on the current {page_name}."
    )

    return answer[:1200]
