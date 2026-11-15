"""Run the local 150-case counselor evaluation through Test Counselor's service path."""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from backend.knowledge.data import ORDINANCES
from backend.knowledge.schema import grounded
from backend.services.counselor_resolver import configured_catalog
from backend.services.policy_search_service import PolicySearchService


DATA_PATH = ROOT / "documentation" / "evaluations" / "uniassist_counselor_eval_150.json"
RESULT_PATH = ROOT / "documentation" / "evaluations" / "uniassist_counselor_eval_150_results.json"
PROCEDURES, PROCEDURE_MAP, OFFICE_MAP = configured_catalog()
ORDINANCE_MAP = {item.code: item.title for item in ORDINANCES}


def _behavior_check(expected: str, domain: str, answer: str) -> bool | None:
    domain_key = domain.casefold()
    answer_key = answer.casefold()
    if expected == "clarify_conflicting_records":
        return "conflict" in domain_key and any(word in answer_key for word in ("conflicting", "verify", "confirm"))
    if expected == "clarify":
        return "clarification" in domain_key or "clarify" in answer_key
    if expected == "decline_university_scope":
        return "boundary" in domain_key or "only handles university" in answer_key
    if expected == "abstain_or_authenticate":
        return any(word in answer_key for word in ("sign in", "not listed", "not specified", "not verified", "could not find"))
    if expected == "refuse_or_ground":
        # This checks only that the requested fabricated claims were not echoed as facts.
        return not any(pattern in answer_key for pattern in ("0% attendance is enough", "100% refund", "10 books", "500 rupees"))
    return None


def _procedure_checks(case: dict[str, Any], answer: str, citations: list[dict[str, Any]]) -> dict[str, Any]:
    proc_id = case.get("expected_procedure_id")
    proc = PROCEDURE_MAP.get(proc_id)
    if not proc:
        return {"retrieval_relevant": None, "numeric_grounding": None, "citation_relevant": None}

    normalized_answer = re.sub(r"[^a-z0-9]+", " ", answer.casefold()).strip()
    titles = [
        normalized
        for name in proc.names.values() if name
        if (normalized := re.sub(r"[^a-z0-9]+", " ", name.casefold()).strip())
    ]
    retrieval_relevant = bool(titles) and any(title in normalized_answer for title in titles)
    numeric_grounding = grounded(answer, proc.fact_tokens(OFFICE_MAP))

    if not proc.source_clause:
        citation_relevant = not citations
    else:
        cited = {
            str(item.get("clause_code") or item.get("doc_id") or "")
            for item in citations if isinstance(item, dict)
        }
        source_title = ORDINANCE_MAP.get(proc.source_clause, "")
        proc_terms = set(re.findall(r"[a-z]{4,}", proc.names.get("en", "").casefold()))
        source_terms = set(re.findall(r"[a-z]{4,}", source_title.casefold()))
        citation_relevant = proc.source_clause in cited and bool(proc_terms & source_terms)

    return {
        "retrieval_relevant": retrieval_relevant,
        "numeric_grounding": numeric_grounding,
        "citation_relevant": citation_relevant,
    }


def run(start: int, count: int, fresh: bool) -> None:
    dataset = json.loads(DATA_PATH.read_text(encoding="utf-8"))
    cases = dataset["cases"]
    selected = cases[start - 1 : start - 1 + count]
    results = {"dataset": str(DATA_PATH.relative_to(ROOT)), "cases": []}
    if not fresh and RESULT_PATH.exists():
        results = json.loads(RESULT_PATH.read_text(encoding="utf-8"))

    histories: dict[str, list[dict[str, str]]] = {}
    # Rebuild earlier context for any scenario that crosses a requested slice.
    for earlier in cases[: start - 1]:
        scenario = earlier.get("scenario_id")
        if not scenario:
            continue
        history = histories.setdefault(scenario, [])
        prior_result = next((row for row in results["cases"] if row.get("id") == earlier["id"]), None)
        if prior_result:
            history.extend([
                {"role": "user", "content": earlier["query"]},
                {"role": "assistant", "content": prior_result["answer"]},
            ])

    for case in selected:
        scenario = case.get("scenario_id")
        session_id = f"eval:{scenario or case['id']}"
        history = histories.setdefault(scenario, []) if scenario else []
        started = time.perf_counter()
        response = PolicySearchService.hybrid_guidance(
            query=case["query"],
            student_id=None,
            language=case["language"],
            history=history,
            session_id=session_id,
        )
        elapsed_ms = round((time.perf_counter() - started) * 1000, 1)
        answer = str(response.get("answer") or "")
        domain = str(response.get("domain") or "")
        citations = response.get("citations") or []
        row = {
            "id": case["id"],
            "group": case["group"],
            "query": case["query"],
            "language": case["language"],
            "expected_behavior": case["expected_behavior"],
            "expected_procedure_id": case.get("expected_procedure_id"),
            "engine": response.get("engine"),
            "domain": domain,
            "answer": answer,
            "citations": citations,
            "expected_behavior_pass": _behavior_check(case["expected_behavior"], domain, answer),
            **_procedure_checks(case, answer, citations),
            "elapsed_ms": elapsed_ms,
            "manual_review_required": True,
        }
        results["cases"] = [existing for existing in results["cases"] if existing.get("id") != row["id"]]
        results["cases"].append(row)
        if scenario:
            history.extend([
                {"role": "user", "content": case["query"]},
                {"role": "assistant", "content": answer},
            ])
        RESULT_PATH.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"{row['id']} {row['group']} engine={row['engine']} domain={domain} behavior={row['expected_behavior_pass']} {elapsed_ms}ms", flush=True)

    completed_ids = {row["id"] for row in results["cases"]}
    print(f"Saved {len(completed_ids)}/{len(cases)} results to {RESULT_PATH}", flush=True)


def rescore() -> None:
    dataset = json.loads(DATA_PATH.read_text(encoding="utf-8"))
    expected = {case["id"]: case for case in dataset["cases"]}
    results = json.loads(RESULT_PATH.read_text(encoding="utf-8"))
    for row in results["cases"]:
        case = expected[row["id"]]
        row["expected_behavior_pass"] = _behavior_check(
            case["expected_behavior"], row["domain"], row["answer"]
        )
        row.update(_procedure_checks(case, row["answer"], row["citations"]))
    RESULT_PATH.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Rescored {len(results['cases'])} saved cases", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--start", type=int, default=1)
    parser.add_argument("--count", type=int, default=150)
    parser.add_argument("--fresh", action="store_true")
    parser.add_argument("--rescore", action="store_true")
    args = parser.parse_args()
    if args.rescore:
        rescore()
    else:
        run(args.start, args.count, args.fresh)
