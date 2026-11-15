"""Validate the knowledge base and print the owner's review checklist.

    python -m backend.knowledge.check            # validate + summary (use in CI; exits 1 on errors)
    python -m backend.knowledge.check --review   # also print every unverified fact
    python -m backend.knowledge.check --md > REVIEW.md   # same, as a markdown table for the reviewer
"""

from __future__ import annotations

import sys
from collections import Counter

from .data import OFFICES, ORDINANCES, PROCEDURES
from .schema import validate_kb


def review_rows() -> list[tuple[str, str, str, str]]:
    """(procedure id, field, value currently stored, reason it is unconfirmed)."""
    rows = []
    for p in PROCEDURES:
        for fld, reason in p.verify.items():
            if fld == "fee":
                cur = p.fee.text() if p.fee else "-"
            elif fld == "steps":
                cur = f"{len(p.steps)} steps"
            elif fld in ("docs", "notes"):
                cur = "; ".join(getattr(p, fld))[:80] or "-"
            else:
                cur = str(getattr(p, fld) or "-")
            rows.append((p.id, fld, cur, reason))
    for o in OFFICES:
        if o.verify:
            rows.append((f"office:{o.id}", "location", f"Room {o.room or '-'}, {o.building or '-'}", o.verify))
    return rows


def main(argv: list[str]) -> int:
    errs = validate_kb(PROCEDURES, OFFICES, ORDINANCES)
    if errs:
        print("VALIDATION ERRORS")
        for e in errs:
            print("  -", e)
        return 1

    flagged = [p for p in PROCEDURES if p.verify]
    by_aud = Counter(a for p in PROCEDURES for a in p.audience)
    print(f"OK: {len(PROCEDURES)} procedures, {len(OFFICES)} offices, {len(ORDINANCES)} ordinances")
    print(f"    audiences: {dict(by_aud)}")
    print(f"    fully verified: {len(PROCEDURES) - len(flagged)}   needing review: {len(flagged)}")

    rows = review_rows()
    if "--md" in argv:
        print("\n| Item | Field | Stored value | Why it is unconfirmed |\n|---|---|---|---|")
        for pid, f, cur, why in rows:
            print(f"| {pid} | {f} | {cur} | {why} |")
    elif "--review" in argv:
        print(f"\n{len(rows)} unconfirmed facts (hidden from answers until cleared):\n")
        for pid, f, cur, why in rows:
            print(f"* {pid} / {f}\n    stored : {cur}\n    issue  : {why}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
