import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

import catalog


RULES = {"SA_1": "Erste", "SA_2": "Zweite"}


def entry(**kw):
    base = {"id": "SA_1", "name": "Erste", "group": "Kampf", "status": "todo", "why": "not yet read"}
    base.update(kw)
    return base


class ValidateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "Hero.swift").write_text("struct Hero {\n    var golgaritenActive: Bool\n}\n")

    def tearDown(self):
        self.tmp.cleanup()

    def test_a_complete_catalog_has_no_problems(self):
        entries = [entry(), entry(id="SA_2", name="Zweite")]
        self.assertEqual(catalog.validate(entries, RULES, self.root), [])

    def test_a_rule_without_an_entry_is_a_problem(self):
        problems = catalog.validate([entry()], RULES, self.root)
        self.assertIn("SA_2: no catalog entry", problems)

    def test_an_entry_the_rules_do_not_know_is_a_problem(self):
        entries = [entry(), entry(id="SA_2", name="Zweite"), entry(id="SA_9", name="Neunte")]
        self.assertIn("SA_9: not in rules.db", catalog.validate(entries, RULES, self.root))

    def test_a_duplicate_and_a_wrong_name_and_an_unknown_status_are_problems(self):
        entries = [entry(), entry(), entry(id="SA_2", name="Falsch", status="maybe")]
        problems = catalog.validate(entries, RULES, self.root)
        self.assertIn("SA_1: listed twice", problems)
        self.assertIn("SA_2: name is 'Falsch', rules.db says 'Zweite'", problems)
        self.assertTrue(any(p.startswith("SA_2: status 'maybe'") for p in problems))

    def test_by_hand_needs_a_pointer_that_resolves(self):
        ok = entry(status="byHand", note="x", pointer={"file": "Hero.swift", "symbol": "golgaritenActive"})
        no_pointer = entry(id="SA_2", name="Zweite", status="byHand", note="x")
        self.assertEqual(catalog.validate([ok, no_pointer], RULES, self.root),
                         ["SA_2: byHand needs pointer {file, symbol}"])
        no_file = entry(id="SA_2", name="Zweite", status="byHand", pointer={"file": "Nope.swift", "symbol": "x"})
        self.assertEqual(catalog.validate([ok, no_file], RULES, self.root),
                         ["SA_2: pointer file Nope.swift does not exist"])
        no_symbol = entry(id="SA_2", name="Zweite", status="byHand", pointer={"file": "Hero.swift", "symbol": "golgariten"})
        self.assertEqual(catalog.validate([ok, no_symbol], RULES, self.root),
                         ["SA_2: symbol 'golgariten' not found in Hero.swift"])

    def test_todo_needs_a_why(self):
        entries = [entry(why=None), entry(id="SA_2", name="Zweite")]
        self.assertIn("SA_1: todo without why", catalog.validate(entries, RULES, self.root))


class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "snap.json"

    def tearDown(self):
        self.tmp.cleanup()

    def test_counts_and_an_equal_snapshot(self):
        entries = [entry(), entry(id="SA_2", name="Zweite", status="byHand", note="x",
                                  pointer={"file": "a", "symbol": "b"})]
        counts = catalog.status_counts(entries)
        self.assertEqual(counts, {"implemented": 0, "byHand": 1, "noRollEffect": 0, "todo": 1})
        catalog.write_snapshot(counts, self.path)
        self.assertEqual(catalog.check_snapshot(counts, self.path), [])

    def test_shrinking_coverage_and_growing_todo_are_named(self):
        self.path.write_text(json.dumps({"implemented": 1, "byHand": 1, "noRollEffect": 0, "todo": 0}))
        problems = catalog.check_snapshot({"implemented": 0, "byHand": 1, "noRollEffect": 0, "todo": 1}, self.path)
        self.assertTrue(any("backwards" in p for p in problems))
        self.assertTrue(any("grew" in p for p in problems))
        self.assertTrue(any("--update-snapshot" in p for p in problems))


class TableTests(unittest.TestCase):
    def test_the_table_holds_one_row_per_entry(self):
        conn = sqlite3.connect(":memory:")
        entries = [entry(), entry(id="SA_2", name="Zweite", status="byHand", note="by hand",
                                  pointer={"file": "Hero.swift", "symbol": "x"},
                                  reviewed={"by": "sam", "on": "2026-09-14"})]
        catalog.write_catalog_table(conn, entries)
        rows = conn.execute("SELECT rule_id, status, note, pointer_file, pointer_symbol, reviewed_by, reviewed_on "
                            "FROM catalog ORDER BY rule_id").fetchall()
        self.assertEqual(rows, [
            ("SA_1", "todo", "not yet read", None, None, None, None),
            ("SA_2", "byHand", "by hand", "Hero.swift", "x", "sam", "2026-09-14"),
        ])


if __name__ == "__main__":
    unittest.main()
