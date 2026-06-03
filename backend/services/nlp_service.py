"""
Keyword-based NLP intent classifier + polarity sentiment scorer.

Design rationale: Deterministic keyword matching instead of a heavy ML model because:
  - Full auditability — every decision is traceable to explicit keywords
  - Zero external runtime dependencies
  - Sub-millisecond latency on any hardware
  - Easy to extend: add keywords, adjust weights, or swap the engine behind the same interface

Intent categories:
  financial | academic | personal | health | career | unclear
"""

from __future__ import annotations

import re
from typing import Literal

Intent = Literal["financial", "academic", "personal", "health", "career", "unclear"]
Sentiment = Literal["positive", "neutral", "negative"]

# ---------------------------------------------------------------------------
# Keyword tables (all lower-case; substring matching used for partial words)
# ---------------------------------------------------------------------------

_INTENT_KEYWORDS: dict[str, list[str]] = {
    "financial": [
        "fee", "fees", "money", "cost", "afford", "financial", "payment",
        "scholarship", "debt", "loan", "broke", "expense", "tuition", "fund",
        "poverty", "income", "salary", "economics", "budget", "bursary",
        "credit card", "installment", "due", "overdue", "refund",
    ],
    "academic": [
        "fail", "failing", "grade", "marks", "exam", "course", "study",
        "professor", "teacher", "curriculum", "assignment", "thesis",
        "academic", "performance", "cgpa", "gpa", "semester", "credit",
        "difficult", "hard", "understand", "class", "lecture", "dropout",
        "repeat", "retake", "plagiarism", "suspension",
    ],
    "personal": [
        "family", "personal", "home", "parent", "relative", "marriage",
        "relationship", "mental", "anxiety", "stress", "depression",
        "move", "relocat", "immigrat", "visa", "abroad", "country",
        "divorce", "separation", "grief", "loss",
    ],
    "health": [
        "health", "sick", "ill", "disease", "hospital", "surgery",
        "chronic", "mental health", "therapy", "treatment", "disability",
        "injury", "cancer", "diagnos", "medical", "medication", "recover",
    ],
    "career": [
        "job", "career", "work", "employ", "company", "internship",
        "opportunity", "offer", "business", "startup", "entrepreneur",
        "promotion", "full-time", "hired", "appointment",
    ],
}

_POSITIVE_WORDS = frozenset({
    "thank", "thanks", "appreciate", "good", "great", "okay", "yes",
    "sure", "confirm", "agree", "resolve", "help", "support", "better",
    "wonderful", "excellent", "perfect", "love", "happy", "pleased",
})

_NEGATIVE_WORDS = frozenset({
    "no", "not", "never", "cant", "cannot", "difficult", "hard",
    "fail", "bad", "worst", "hate", "terrible", "awful", "hopeless",
    "struggle", "impossible", "refuse", "won't", "wont", "disagree",
    "frustrated", "desperate", "overwhelmed",
})


def _tokenize(text: str) -> list[str]:
    """Lower-case, strip punctuation, split into tokens."""
    return re.sub(r"[^a-z\s]", " ", text.lower()).split()


def classify_intent(text: str) -> Intent:
    """
    Classify the dominant withdrawal intent from free-text input.

    Algorithm:
      1. Tokenise input
      2. Count keyword hits per intent category
      3. Return highest-scoring category; 'unclear' if all scores are 0
    """
    lower_text = text.lower()
    tokens = set(_tokenize(text))

    scores: dict[str, int] = {}
    for intent, keywords in _INTENT_KEYWORDS.items():
        count = 0
        for kw in keywords:
            # Match whole-word tokens OR substring inside longer words
            if kw in tokens or kw in lower_text:
                count += 1
        scores[intent] = count

    best = max(scores, key=lambda k: scores[k])
    return best if scores[best] > 0 else "unclear"  # type: ignore[return-value]


def score_sentiment(text: str) -> Sentiment:
    """
    Simple polarity scorer.

    Returns 'positive' if positive signals outweigh negative,
    'negative' if vice versa, or 'neutral' when balanced/absent.
    """
    tokens = set(_tokenize(text))
    pos = len(tokens & _POSITIVE_WORDS)
    neg = len(tokens & _NEGATIVE_WORDS)

    if pos > neg:
        return "positive"
    if neg > pos:
        return "negative"
    return "neutral"
