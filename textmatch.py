"""Word-boundary text matching helpers for UniAssist.

Drop into backend/app/services/text_match.py and use instead of `"x" in q_lower`.
Handles Latin and Devanagari (Python's \\w does NOT match Devanagari vowel signs,
so the range \\u0900-\\u097F is included explicitly).
"""

from __future__ import annotations

import re
from functools import lru_cache
from typing import Iterable

_WORD = r"A-Za-z0-9_\u0900-\u097F"


def tokens(text: str) -> list[str]:
    return re.findall(rf"[{_WORD}]+", (text or "").lower())


@lru_cache(maxsize=4096)
def _phrase_re(phrase: str, stem: bool) -> re.Pattern[str]:
    parts = [re.escape(p) for p in phrase.lower().split()]
    body = r"\s+".join(parts)
    end = "" if stem else rf"(?![{_WORD}])"
    return re.compile(rf"(?<![{_WORD}]){body}{end}")


def has_phrase(text: str, phrase: str) -> bool:
    """True if `phrase` occurs as whole word(s). 'ipl' no longer matches 'diploma'."""
    return bool(_phrase_re(phrase, False).search((text or "").lower()))


def has_stem(text: str, stem: str) -> bool:
    """True if a word STARTS with `stem` ('relocat' matches 'relocation')."""
    return bool(_phrase_re(stem, True).search((text or "").lower()))


def has_any(text: str, phrases: Iterable[str]) -> bool:
    return any(has_phrase(text, p) for p in phrases)


def count_hits(text: str, phrases: Iterable[str]) -> int:
    return sum(1 for p in phrases if has_phrase(text, p))


if __name__ == "__main__":
    assert not has_phrase("i want a diploma certificate", "ipl")
    assert has_phrase("who won the ipl match", "ipl")
    assert not has_phrase("do you know the rules", "no")
    assert not has_phrase("what is the procedure", "due")
    assert has_phrase("pending dues", "dues")
    assert not has_phrase("i will fill the form", "ill")
    assert has_phrase("library timing please", "library timing")
    assert has_phrase("मेरी अटेंडेंस कितनी है", "अटेंडेंस")
    assert not has_phrase("अटेंडेंसी", "अटेंडेंस")
    assert has_stem("relocation visa", "relocat")
    assert has_phrase("calculate my attendance", "attendance")
    print("text_match: all checks passed")
