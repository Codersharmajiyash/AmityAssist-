"""Unified knowledge-base schema for UniAssist (Step 2).

Every form, guideline and wizard-created procedure is ONE `Procedure` record.
Nothing else in the codebase may hold fees, rooms, deadlines or step lists.

Key idea: a record may carry a best-guess value AND a `verify` entry explaining
why it is unconfirmed. `public_facts()` hides every field listed in `verify`,
so unconfirmed facts can never reach a student until the owner clears the flag.
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import asdict, dataclass, field
from typing import Any, Literal

Audience = Literal["student", "faculty", "staff"]
Kind = Literal["form", "info"]

LANGS = ("en", "hi", "hinglish")

# Fields the owner can flag as unverified. A flagged field is hidden from answers.
FACT_FIELDS = (
    "form_code", "eligibility", "docs", "fee", "deadline", "sla",
    "office", "steps", "notes",
)

VALID_ROUTES = {
    "/forms", "/withdrawal", "/exams", "/services", "/chat", "/scholarship",
    "/profile", "/login", "/dashboard", "/tracking", "/request-status", "/staff",
}


@dataclass
class Office:
    id: str
    name: str
    room: str | None = None
    building: str | None = None
    verify: str | None = None          # why the location is uncertain (hides room/building)

    def label(self) -> str:
        """Human label; room/building omitted while location is unverified."""
        if self.verify:
            return self.name
        extra = ", ".join(x for x in (f"Room {self.room}" if self.room else None, self.building) if x)
        return f"{self.name} ({extra})" if extra else self.name


@dataclass
class Ordinance:
    code: str
    title: str


@dataclass
class Step:
    text: str
    office: str | None = None          # Office.id
    sla_days: int | None = None


@dataclass
class Fee:
    amount_inr: int
    unit: str | None = None            # e.g. "per subject"

    def text(self) -> str:
        return f"INR {self.amount_inr:,}" + (f" {self.unit}" if self.unit else "")


@dataclass
class Procedure:
    id: str                                    # stable slug, e.g. "condonation-ac04"
    names: dict[str, str]                      # en / hi / hinglish
    aliases: list[str]                         # what people actually type (any language)
    category: str
    audience: list[Audience]
    kind: Kind = "form"
    form_code: str | None = None
    eligibility: str | None = None
    docs: list[str] = field(default_factory=list)
    fee: Fee | None = None
    deadline: str | None = None
    sla: str | None = None
    office: str | None = None                  # Office.id where it is submitted
    steps: list[Step] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)
    source_clause: str | None = None           # Ordinance.code
    related_clauses: list[str] = field(default_factory=list)
    action_url: str = "/forms"
    action_label: str = "Open Forms Catalog"
    verify: dict[str, str] = field(default_factory=dict)   # field -> reason (hidden until cleared)
    reviewer_notes: str = ""                   # never shown to students
    is_custom: bool = False                    # True for wizard / ingestion-created records
    version: int = 1

    # ---- serialisation -------------------------------------------------
    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @staticmethod
    def from_dict(d: dict[str, Any]) -> "Procedure":
        d = dict(d)
        d["steps"] = [Step(**s) for s in d.get("steps", [])]
        d["fee"] = Fee(**d["fee"]) if d.get("fee") else None
        return Procedure(**d)

    def content_hash(self) -> str:
        payload = self.to_dict()
        payload.pop("version", None)
        return hashlib.sha1(json.dumps(payload, sort_keys=True, ensure_ascii=False).encode()).hexdigest()

    # ---- what the answer renderer may use ------------------------------
    def public_facts(self, offices: dict[str, Office]) -> dict[str, Any]:
        """Only verified facts. Flagged fields come back as None and are listed in `unverified`."""
        hide = set(self.verify)

        def pick(name: str, value: Any) -> Any:
            return None if name in hide else value

        office = offices.get(self.office) if self.office else None
        return {
            "id": self.id,
            "names": self.names,
            "form_code": pick("form_code", self.form_code),
            "eligibility": pick("eligibility", self.eligibility),
            "docs": pick("docs", self.docs),
            "fee": pick("fee", self.fee.text() if self.fee else None),
            "deadline": pick("deadline", self.deadline),
            "sla": pick("sla", self.sla),
            "office": pick("office", office.label() if office else None),
            "steps": pick("steps", [
                {"n": i, "text": s.text,
                 "office": (offices[s.office].label() if s.office in offices else None)}
                for i, s in enumerate(self.steps, 1)
            ]),
            "notes": pick("notes", self.notes),
            "unverified": sorted(hide),
            "action_url": self.action_url,
            "action_label": self.action_label,
        }

    def fact_tokens(self, offices: dict[str, Office]) -> set[str]:
        """Numbers, codes and rooms in public facts. Used by the grounding check on LLM output."""
        blob = json.dumps(self.public_facts(offices), ensure_ascii=False)
        return extract_tokens(blob)


_TOKEN_RE = re.compile(r"\d[\d,\.]*|[A-Z]{2,}(?:-[A-Z0-9.]+)+|\b[A-Z]{2,}-?\d+\b")


def extract_tokens(text: str) -> set[str]:
    """Pull out every number / code that an answer must not invent."""
    return {t.rstrip(".,") for t in _TOKEN_RE.findall(text)}


def grounded(answer: str, allowed: set[str]) -> bool:
    """True if every number/code in `answer` appears in `allowed`."""
    return extract_tokens(answer) <= allowed


# ---- validation ---------------------------------------------------------

def validate_procedure(p: Procedure, office_ids: set[str], clause_codes: set[str]) -> list[str]:
    errs: list[str] = []
    pid = p.id or "<no id>"
    if not re.fullmatch(r"[a-z0-9][a-z0-9\-]*", p.id or ""):
        errs.append(f"{pid}: id must be a lowercase slug")
    for lang in LANGS:
        if not (p.names.get(lang) or "").strip():
            errs.append(f"{pid}: names['{lang}'] missing")
    if len([a for a in p.aliases if a.strip()]) < 3:
        errs.append(f"{pid}: needs at least 3 aliases")
    if not p.audience:
        errs.append(f"{pid}: audience empty")
    if p.kind == "form" and not p.steps:
        errs.append(f"{pid}: a form needs at least one step")
    if p.office and p.office not in office_ids:
        errs.append(f"{pid}: unknown office '{p.office}'")
    for i, s in enumerate(p.steps, 1):
        if not s.text.strip():
            errs.append(f"{pid}: step {i} empty")
        if s.office and s.office not in office_ids:
            errs.append(f"{pid}: step {i} unknown office '{s.office}'")
    for code in ([p.source_clause] if p.source_clause else []) + p.related_clauses:
        if code not in clause_codes:
            errs.append(f"{pid}: clause '{code}' does not exist in the ordinance registry")
    if p.action_url not in VALID_ROUTES:
        errs.append(f"{pid}: action_url '{p.action_url}' is not a known route")
    for k, reason in p.verify.items():
        if k not in FACT_FIELDS:
            errs.append(f"{pid}: verify key '{k}' is not one of {FACT_FIELDS}")
        if not reason.strip():
            errs.append(f"{pid}: verify['{k}'] needs a reason")
    return errs


def validate_kb(procs: list[Procedure], offices: list[Office], ordinances: list[Ordinance]) -> list[str]:
    errs: list[str] = []
    office_ids = {o.id for o in offices}
    codes = {o.code for o in ordinances}
    if len(office_ids) != len(offices):
        errs.append("duplicate office ids")
    if len(codes) != len(ordinances):
        errs.append("duplicate ordinance codes")
    ids = [p.id for p in procs]
    for dup in {i for i in ids if ids.count(i) > 1}:
        errs.append(f"duplicate procedure id '{dup}'")
    form_codes = [p.form_code for p in procs if p.form_code]
    for dup in {c for c in form_codes if form_codes.count(c) > 1}:
        errs.append(f"duplicate form_code '{dup}'")
    for p in procs:
        errs.extend(validate_procedure(p, office_ids, codes))
    return errs
