"""
Tests for the NLP service — intent classification and sentiment scoring.

Double-validation:
  Round 1 — verify each intent/sentiment category produces correct output
  Round 2 — verify edge cases: mixed signals, empty text, capitalization
"""

import pytest
from backend.services.nlp_service import classify_intent, score_sentiment


class TestIntentClassification:
    """Round 1 — One representative phrase per intent category."""

    def test_financial_intent(self):
        assert classify_intent("I cannot afford my tuition fees anymore") == "financial"

    def test_academic_intent(self):
        assert classify_intent("I am consistently failing my exams and my GPA is terrible") == "academic"

    def test_personal_intent(self):
        assert classify_intent("I need to move back home to support my family") == "personal"

    def test_health_intent(self):
        assert classify_intent("I was diagnosed with a chronic illness and need surgery") == "health"

    def test_career_intent(self):
        assert classify_intent("I received a full-time job offer from a company") == "career"

    def test_unclear_intent_returns_unclear(self):
        assert classify_intent("I just want to stop") == "unclear"


class TestIntentClassificationEdgeCases:
    """Round 2 — Edge cases and boundary conditions."""

    def test_mixed_financial_academic(self):
        """When both signals present, the dominant one should win."""
        result = classify_intent("I can't afford my fees and I am also failing every exam")
        assert result in ("financial", "academic")  # both valid, one dominates

    def test_uppercase_input(self):
        """Classifier must be case-insensitive."""
        assert classify_intent("MY TUITION FEES ARE TOO HIGH") == "financial"

    def test_single_keyword(self):
        """Even a single strong keyword should produce the correct intent."""
        assert classify_intent("loan") == "financial"
        assert classify_intent("fail") == "academic"

    def test_empty_string_returns_unclear(self):
        assert classify_intent("") == "unclear"

    def test_gibberish_returns_unclear(self):
        assert classify_intent("asdfghjkl qwerty zxcvbnm") == "unclear"


class TestSentimentScoring:
    """Round 1 — Basic polarity detection."""

    def test_positive_sentiment(self):
        assert score_sentiment("Yes, I agree and I appreciate the help") == "positive"

    def test_negative_sentiment(self):
        assert score_sentiment("No, I cannot do this, it is impossible and hopeless") == "negative"

    def test_neutral_sentiment(self):
        assert score_sentiment("I am withdrawing from the course") == "neutral"


class TestSentimentEdgeCases:
    """Round 2 — Edge and boundary conditions."""

    def test_empty_input_is_neutral(self):
        assert score_sentiment("") == "neutral"

    def test_mixed_signals_balanced(self):
        """Balanced positive and negative should return neutral."""
        result = score_sentiment("yes no")
        assert result == "neutral"

    def test_confirm_message_is_positive(self):
        assert score_sentiment("yes I confirm") == "positive"

    def test_cancel_message_is_negative(self):
        assert score_sentiment("no I cannot proceed") == "negative"
