"""5-Stage Deterministic Pipeline Verification Suite.

Validates the foolproof unified architecture:
1. Stage 1: Typo Normalizer & Domain Boundary Guardrail
2. Stage 2: Multi-Turn & Step Intent Resolver (strictly bound to active procedure in conversation memory)
3. Stage 3: Unified Entity & Procedure Matcher (clean rejection for non-existent procedures)
4. Stage 4: Conflicting Keyword & Disambiguation Engine (numbered cross-questioning)
5. Stage 5: Aspect Filter & Multilingual Response Synthesizer (explicit Voice TTS for required documents)
"""

from backend.services.policy_search_service import PolicySearchService


def test_scenario_1_domain_boundary_guard():
    """Irrelevant / Non-campus Query (e.g., 'I want to eat food', 'cricket score') caught at Stage 1."""
    for q in ["I want to eat food", "cricket score", "what is the weather today", "crypto bitcoin price"]:
        res = PolicySearchService.hybrid_guidance(q)
        assert res["domain"] == "Domain Boundary Guard"
        assert "UniAssist only handles" in res["answer"] or "personal requests" in res["answer"]
        assert res["citations"] == []


def test_scenario_2_non_existent_procedure_clean_rejection():
    """Non-existent procedure queries cleanly reject without hallucinating Admission Form ADM-01."""
    for q, topic in [("procedure for scuba diving", "Scuba Diving"), ("how to apply for buy car", "Buy Car")]:
        res = PolicySearchService.hybrid_guidance(q)
        assert f"No verified university procedure or ordinance exists for {topic}" in res["answer"]
        assert "Room 101" in res["answer"]
        assert "ADM-01" not in res["answer"]
        assert "Admissions" not in res["domain"]


def test_scenario_3_conflicting_keyword_disambiguation():
    """Bare or ambiguous keywords trigger cross-questioning with numbered options."""
    # Library
    res_lib = PolicySearchService.hybrid_guidance("library")
    assert res_lib.get("status") == "trigger_cross_question"
    assert "[1] Library Card" in res_lib["answer"]
    assert "[2] Central Library Timings" in res_lib["answer"]
    assert "[3] Library Clearance" in res_lib["answer"]

    # Hostel
    res_hostel = PolicySearchService.hybrid_guidance("hostel")
    assert res_hostel.get("status") == "trigger_cross_question"
    assert "[1] Hostel Room Change" in res_hostel["answer"]
    assert "[2] Hostel Allotment" in res_hostel["answer"]
    assert "[3] Hostel Clearance" in res_hostel["answer"]

    # Answering option 1
    hist = [
        {"role": "user", "content": "library"},
        {"role": "assistant", "content": res_lib["answer"]},
    ]
    res_opt1 = PolicySearchService.hybrid_guidance("1", history=hist)
    assert "Library Card" in res_opt1["answer"]
    assert "Student ID Card Copy" in res_opt1["answer"]


def test_scenario_4_typo_normalizer_and_documents_voice_speech():
    """Fuzzy typos are canonicalized and Voice TTS explicitly speaks the required documents array."""
    res = PolicySearchService.hybrid_guidance("douments rewuired for library card")
    assert "Student ID Card Copy" in res["answer"]
    assert "Latest Fee Receipt" in res["answer"]
    assert "librarin" in res["answer"]
    # Voice TTS must explicitly speak the documents array
    assert "The required documents for Library Card are: Student ID Card Copy and Latest Fee Receipt" in res["voice_speech_text"]


def test_scenario_5_step_traversal_on_custom_db_procedure():
    """Multi-turn step traversal binds strictly to the active procedure and clamps out-of-range steps."""
    hist = [
        {"role": "user", "content": "library card"},
        {
            "role": "assistant",
            "content": "Official procedure for Library Card (Central Library) with 2 steps. Step 1: go to desk (librarin). Step 2: Fill the form (Librarian).",
        },
    ]

    # Step 1
    s1 = PolicySearchService.hybrid_guidance("What was the first step?", history=hist)
    assert "go to desk" in s1["answer"].lower()
    assert "librarin" in s1["answer"].lower()
    assert "go to desk at librarin" in s1["voice_speech_text"].lower()

    # Step 2
    s2 = PolicySearchService.hybrid_guidance("What is step 2?", history=hist)
    assert "fill the form" in s2["answer"].lower()
    assert "librarian" in s2["answer"].lower()
    assert "fill the form at librarian" in s2["voice_speech_text"].lower()

    # Step 5 (out of range clamp)
    s5 = PolicySearchService.hybrid_guidance("What is step 5?", history=hist)
    assert "There are only 2 steps in this procedure. Step 2 was final." in s5["answer"]

    # Isolated step query without context
    s_iso = PolicySearchService.hybrid_guidance("What was the first step?")
    assert "please specify which university procedure" in s_iso["answer"].lower()
    assert "ADM-01" not in s_iso["answer"]


def test_multilingual_pipeline():
    """Verify that the 5-stage pipeline behaves deterministically in Hindi (hi-IN) and Hinglish (hi-Latn)."""
    # Hindi Domain Guard
    res_hi = PolicySearchService.hybrid_guidance("मुझे खाना खाना है", language="hi-IN")
    assert "UniAssist केवल" in res_hi["answer"]

    # Hinglish Domain Guard
    res_latn = PolicySearchService.hybrid_guidance("food khana hai bhook lagi", language="hi-Latn")
    assert "UniAssist keval" in res_latn["answer"]

    # Hindi Disambiguation
    res_lib_hi = PolicySearchService.hybrid_guidance("लाइब्रेरी", language="hi-IN")
    assert "[1] लाइब्रेरी कार्ड" in res_lib_hi["answer"]

    # Hindi Step Traversal
    hist_hi = [
        {"role": "user", "content": "लाइब्रेरी कार्ड"},
        {"role": "assistant", "content": "लाइब्रेरी कार्ड प्रक्रिया"},
    ]
    s1_hi = PolicySearchService.hybrid_guidance("पहला स्टेप क्या है?", language="hi-IN", history=hist_hi)
    assert "चरण 1" in s1_hi["answer"] or "librarin" in s1_hi["answer"]

    s5_hi = PolicySearchService.hybrid_guidance("चरण 5 क्या है?", language="hi-IN", history=hist_hi)
    assert "केवल 2 चरण हैं" in s5_hi["answer"]

