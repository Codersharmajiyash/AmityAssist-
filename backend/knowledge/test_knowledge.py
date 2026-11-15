"""Run: python -m unittest backend.knowledge.test_knowledge -v"""

import copy
import sqlite3
import unittest

from .data import OFFICES, ORDINANCES, PROCEDURES
from .schema import Procedure, Step, extract_tokens, grounded, validate_kb
from .store import KnowledgeError, get_procedure, list_procedures, load_offices, sync_seed, upsert_procedure

OFFICE_MAP = {o.id: o for o in OFFICES}


def by_id(pid: str) -> Procedure:
    return next(p for p in PROCEDURES if p.id == pid)


class SeedData(unittest.TestCase):
    def test_seed_is_valid(self):
        self.assertEqual(validate_kb(PROCEDURES, OFFICES, ORDINANCES), [])

    def test_31_catalog_forms_plus_extras(self):
        self.assertEqual(len(PROCEDURES), 44)

    def test_every_procedure_has_all_three_languages(self):
        for p in PROCEDURES:
            for lang in ("en", "hi", "hinglish"):
                self.assertTrue(p.names[lang], f"{p.id} missing {lang}")


class UnverifiedFactsAreHidden(unittest.TestCase):
    def test_flagged_fee_never_reaches_answers(self):
        f = by_id("student-id-reissue").public_facts(OFFICE_MAP)
        self.assertIsNone(f["fee"])                       # INR 200 vs 500 unresolved
        self.assertIn("fee", f["unverified"])

    def test_flagged_office_room_not_leaked_via_step_labels(self):
        # accounts office location is unverified, so its label must not include a room
        self.assertEqual(OFFICE_MAP["accounts"].label(), "Finance & Accounts Counter")
        f = by_id("tada-claim").public_facts(OFFICE_MAP)
        self.assertNotIn("Room 14", str(f))

    def test_verified_facts_are_present(self):
        f = by_id("backpaper-ex02").public_facts(OFFICE_MAP)
        self.assertEqual(f["fee"], "INR 1,500 per registered subject")
        self.assertEqual(f["deadline"], "Within 14 calendar days of semester grade sheet publication.")

    def test_verified_office_keeps_room(self):
        self.assertIn("Room 201", OFFICE_MAP["dean-academic"].label())


class GroundingCheck(unittest.TestCase):
    def setUp(self):
        self.allowed = by_id("backpaper-ex02").fact_tokens(OFFICE_MAP)

    def test_accepts_answer_using_only_record_facts(self):
        self.assertTrue(grounded("Pay INR 1,500 per subject within 14 days using Form EX-02.", self.allowed))

    def test_rejects_invented_fee(self):
        self.assertFalse(grounded("Pay INR 2,000 per subject within 14 days.", self.allowed))

    def test_rejects_invented_code(self):
        self.assertFalse(grounded("Use Form EX-03 within 14 days.", self.allowed))

    def test_tokenizer(self):
        self.assertEqual(extract_tokens("Room 14, INR 1,500 and ORD-ACAD-7.2"), {"14", "1,500", "ORD-ACAD-7.2"})


class StoreBehaviour(unittest.TestCase):
    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        sync_seed(self.conn, copy.deepcopy(PROCEDURES), OFFICES, ORDINANCES)

    def test_roundtrip(self):
        p = get_procedure(self.conn, "condonation-ac04")
        self.assertEqual(p.form_code, "AC-04")
        self.assertEqual(len(list_procedures(self.conn)), len(PROCEDURES))

    def test_sync_is_idempotent(self):
        stats = sync_seed(self.conn, copy.deepcopy(PROCEDURES), OFFICES, ORDINANCES)
        self.assertEqual(stats["unchanged"], len(PROCEDURES))

    def test_sync_updates_changed_seed_row_and_bumps_version(self):
        edited = copy.deepcopy(PROCEDURES)
        next(p for p in edited if p.id == "tada-claim").sla = "5 working days."
        stats = sync_seed(self.conn, edited, OFFICES, ORDINANCES)
        self.assertEqual(stats["updated"], 1)
        self.assertEqual(get_procedure(self.conn, "tada-claim").version, 2)

    def test_sync_never_overwrites_staff_edit(self):
        p = get_procedure(self.conn, "tada-claim")
        p.sla = "STAFF EDITED"
        upsert_procedure(self.conn, p, is_custom=True)
        stats = sync_seed(self.conn, copy.deepcopy(PROCEDURES), OFFICES, ORDINANCES)
        self.assertEqual(stats["skipped_custom"], 1)
        self.assertEqual(get_procedure(self.conn, "tada-claim").sla, "STAFF EDITED")

    def _new(self, **kw) -> Procedure:
        base = dict(id="wifi-access", category="IT", audience=["student"],
                    names={"en": "Wi-Fi Access", "hi": "वाई-फाई एक्सेस", "hinglish": "Wi-Fi Access"},
                    aliases=["wifi", "internet", "वाईफाई"], office="it-hardware",
                    steps=[Step("Visit the IT desk.", "it-hardware")])
        base.update(kw)
        return Procedure(**base)

    def test_wizard_write_accepts_valid_record(self):
        saved = upsert_procedure(self.conn, self._new())
        self.assertTrue(saved.is_custom)

    def test_wizard_write_rejects_unknown_room_office(self):
        with self.assertRaises(KnowledgeError):
            upsert_procedure(self.conn, self._new(office="made-up-office"))

    def test_wizard_write_rejects_nonexistent_clause(self):
        with self.assertRaises(KnowledgeError):
            upsert_procedure(self.conn, self._new(source_clause="ORD-HST-5.1"))   # the phantom clause

    def test_wizard_write_rejects_bad_route_and_missing_language(self):
        with self.assertRaises(KnowledgeError):
            upsert_procedure(self.conn, self._new(action_url="/nowhere"))
        with self.assertRaises(KnowledgeError):
            upsert_procedure(self.conn, self._new(names={"en": "x", "hi": "", "hinglish": "x"}))


if __name__ == "__main__":
    unittest.main()
