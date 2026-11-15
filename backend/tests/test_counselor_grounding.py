"""Regression checks for grounded counselor routing and abstention behavior."""

from dataclasses import replace

from backend.knowledge.data import OFFICES, PROCEDURES
from backend.knowledge.schema import Office
from backend.services.counselor_resolver import (
    SessionState,
    render_counselor_response,
    resolve_query,
)
from backend.services.local_llm_service import sanitize_and_verify_response
from backend.services.student_response import enforce_student_evidence

OFFICE_MAP = {office.id: office for office in OFFICES}


def _catalog(*ids):
    procedures = [p for p in PROCEDURES if p.id in ids]
    return procedures, {p.id: p for p in procedures}


def _resolve(query, session, procedures, procedure_map):
    return resolve_query(query, session, procedures, procedure_map, OFFICE_MAP)


def test_course_change_and_generic_change_clarification():
    procedures, procedure_map = _catalog("hostel-room-change", "semester-course-change")
    session = SessionState("test-change")

    ambiguous = _resolve("change", session, procedures, procedure_map)
    assert ambiguous.status == "clarify"
    assert {p.id for p in ambiguous.candidates or []} == {"hostel-room-change", "semester-course-change"}

    selected = _resolve("2", session, procedures, procedure_map)
    assert selected.status == "hit"
    assert selected.procedure.id == "semester-course-change"

    direct = _resolve("To change my semester", session, procedures, procedure_map)
    assert direct.procedure.id == "semester-course-change"


def test_unknown_step_cannot_reuse_active_procedure():
    procedures, procedure_map = _catalog("withdrawal-application")
    session = SessionState("test-unknown-step")
    assert _resolve("withdrawal", session, procedures, procedure_map).status == "hit"

    unknown = _resolve("3rd step of petrol", session, procedures, procedure_map)
    assert unknown.status == "not_found"
    assert unknown.explicit_unknown_target
    assert session.active_procedure_id is None


def test_next_step_progresses_instead_of_repeating():
    procedures, procedure_map = _catalog("withdrawal-application")
    session = SessionState("test-next")
    _resolve("withdrawal", session, procedures, procedure_map)
    first_next = _resolve("next step", session, procedures, procedure_map)
    second_next = _resolve("aage kya karna hai", session, procedures, procedure_map)
    assert first_next.target_step == 2
    assert second_next.target_step == 3


def test_missing_fee_and_documents_are_not_claimed_free_or_digital():
    procedures, _ = _catalog("library-regulations")
    source = procedures[0]
    sparse = replace(
        source,
        id="test-library-procedure",
        names={"en": "Test Library Procedure", "hi": "परीक्षण प्रक्रिया", "hinglish": "Test Library Procedure"},
        aliases=["test library procedure"],
        docs=[],
        fee=None,
    )
    session = SessionState("test-missing-fields")
    query_result = _resolve("test library procedure", session, [sparse], {sparse.id: sparse})
    assert query_result.procedure is sparse

    fee_result = _resolve("fee", session, [sparse], {sparse.id: sparse})
    fee_answer = render_counselor_response(fee_result, None, session)["answer"].lower()
    assert "not listed" in fee_answer
    assert "no fee" not in fee_answer

    docs_result = _resolve("documents", session, [sparse], {sparse.id: sparse})
    docs_answer = render_counselor_response(docs_result, None, session)["answer"].lower()
    assert "not listed" in docs_answer
    assert "100% digital" not in docs_answer


def test_three_languages_keep_same_route_and_unverified_numbers_are_rejected():
    procedures, procedure_map = _catalog("hostel-room-change", "semester-course-change")
    ids = []
    for index, language in enumerate(("en-IN", "hi-IN", "hi-Latn")):
        session = SessionState(f"test-language-{index}", language=language)
        result = _resolve("change", session, procedures, procedure_map)
        ids.append([p.id for p in result.candidates or []])
        render_counselor_response(result, None, session, language)
    assert ids[0] == ids[1] == ids[2]

    assert sanitize_and_verify_response("The attendance cutoff is 80%.", evidence_text="The cutoff is 75%.") == ""
    assert sanitize_and_verify_response("Go to Room 201.", evidence_text="Go to Room 201.") == "Go to Room 201."


def test_duplicate_procedure_records_abstain_instead_of_picking_one():
    canonical, _ = _catalog("library-regulations")
    source = canonical[0]
    duplicate_a = replace(
        source,
        id="duplicate-library-a",
        names={"en": "Library Card", "hi": "Library Card", "hinglish": "Library Card"},
        aliases=["library card"],
        is_custom=True,
    )
    duplicate_b = replace(duplicate_a, id="duplicate-library-b")
    procedures = [duplicate_a, duplicate_b, source]
    procedure_map = {p.id: p for p in procedures}
    session = SessionState("test-library-collision")

    result = _resolve("what about library card", session, procedures, procedure_map)
    answer = render_counselor_response(result, None, session, "en-IN")
    assert result.status == "clarify"
    assert "conflicting records" in answer["answer"]
    assert answer["citations"] == []


def test_unreferenced_general_answer_abstains():
    response = enforce_student_evidence(
        {"domain": "General", "engine": "UniAssist Policy Engine", "answer": "Invented answer", "citations": []},
        "en-IN",
    )
    assert "not listed" in response["answer"]
    assert response["citations"] == []
