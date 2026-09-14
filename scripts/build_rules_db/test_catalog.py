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
        no_file = entry(id="SA_2", name="Zweite", status="byHand", note="x", pointer={"file": "Nope.swift", "symbol": "x"})
        self.assertEqual(catalog.validate([ok, no_file], RULES, self.root),
                         ["SA_2: pointer file Nope.swift does not exist"])
        no_symbol = entry(id="SA_2", name="Zweite", status="byHand", note="x", pointer={"file": "Hero.swift", "symbol": "golgariten"})
        self.assertEqual(catalog.validate([ok, no_symbol], RULES, self.root),
                         ["SA_2: symbol 'golgariten' not found in Hero.swift"])

    def test_by_hand_needs_a_note(self):
        entries = [entry(status="byHand", pointer={"file": "Hero.swift", "symbol": "golgaritenActive"}),
                   entry(id="SA_2", name="Zweite")]
        self.assertIn("SA_1: byHand without note", catalog.validate(entries, RULES, self.root))

    def test_todo_needs_a_why(self):
        entries = [entry(why=None), entry(id="SA_2", name="Zweite")]
        self.assertIn("SA_1: todo without why", catalog.validate(entries, RULES, self.root))

    def test_no_roll_effect_needs_a_note(self):
        entries = [entry(status="noRollEffect", why=None), entry(id="SA_2", name="Zweite")]
        self.assertIn("SA_1: noRollEffect without note", catalog.validate(entries, RULES, self.root))

    def test_a_non_mapping_entry_is_a_problem_not_a_crash(self):
        problems = catalog.validate([None, "SA_1"], RULES, self.root)
        self.assertIn("entry 0: not a mapping", problems)
        self.assertIn("entry 1: not a mapping", problems)

    def test_a_pointer_file_outside_the_repo_is_a_problem(self):
        absolute = entry(status="byHand", note="x", pointer={"file": "/etc/passwd", "symbol": "x"})
        self.assertIn("SA_1: pointer file /etc/passwd must be a relative path inside the repository",
                      catalog.validate([absolute], RULES, self.root))
        escaping = entry(status="byHand", note="x", pointer={"file": "../Hero.swift", "symbol": "x"})
        self.assertIn("SA_1: pointer file ../Hero.swift must be a relative path inside the repository",
                      catalog.validate([escaping], RULES, self.root))

    def test_a_pointer_symbol_must_be_a_non_empty_string(self):
        empty = entry(status="byHand", note="x", pointer={"file": "Hero.swift", "symbol": ""})
        self.assertIn("SA_1: pointer symbol must be a non-empty string",
                      catalog.validate([empty], RULES, self.root))
        not_a_string = entry(status="byHand", note="x", pointer={"file": "Hero.swift", "symbol": 1})
        self.assertIn("SA_1: pointer symbol must be a non-empty string",
                      catalog.validate([not_a_string], RULES, self.root))

    def test_a_group_mismatch_is_a_problem_when_groups_is_given(self):
        groups = {"SA_1": "Kampf", "SA_2": "Kampf"}
        entries = [entry(group="Nicht Kampf"), entry(id="SA_2", name="Zweite")]
        problems = catalog.validate(entries, RULES, self.root, groups)
        self.assertIn("SA_1: group is 'Nicht Kampf', rules.db says 'Kampf'", problems)

    def test_group_check_is_skipped_when_groups_is_none(self):
        entries = [entry(group="Falsch"), entry(id="SA_2", name="Zweite")]
        self.assertEqual(catalog.validate(entries, RULES, self.root), [])

    def test_an_unknown_key_is_a_problem(self):
        entries = [entry(spurious="x"), entry(id="SA_2", name="Zweite")]
        self.assertIn("SA_1: unknown key 'spurious'", catalog.validate(entries, RULES, self.root))

    def test_implemented_needs_clauses(self):
        ok = entry(status="implemented", clauses=[{}])
        no_clauses = entry(id="SA_2", name="Zweite", status="implemented")
        self.assertEqual(catalog.validate([ok, no_clauses], RULES, self.root),
                         ["SA_2: implemented without clauses"])


class LoadCatalogTests(unittest.TestCase):
    def test_a_mapping_is_not_a_valid_catalog(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "catalog.yaml"
            path.write_text("id: SA_1\n")
            with self.assertRaises(catalog.CatalogError):
                catalog.load_catalog(path)


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

    def test_a_missing_snapshot_says_so(self):
        problems = catalog.check_snapshot({"implemented": 0, "byHand": 0, "noRollEffect": 0, "todo": 0}, self.path)
        self.assertEqual(len(problems), 1)
        self.assertIn("--update-snapshot", problems[0])


class TableTests(unittest.TestCase):
    def test_the_table_holds_one_row_per_entry(self):
        conn = sqlite3.connect(":memory:")
        entries = [entry(), entry(id="SA_2", name="Zweite", status="byHand", note="by hand",
                                  pointer={"file": "Hero.swift", "symbol": "x"},
                                  reviewed={"by": "sam", "date": "2026-09-14"})]
        catalog.write_catalog_table(conn, entries)
        rows = conn.execute("SELECT rule_id, status, note, pointer_file, pointer_symbol, reviewed_by, reviewed_on "
                            "FROM catalog ORDER BY rule_id").fetchall()
        self.assertEqual(rows, [
            ("SA_1", "todo", "not yet read", None, None, None, None),
            ("SA_2", "byHand", "by hand", "Hero.swift", "x", "sam", "2026-09-14"),
        ])

    def test_yaml_on_key_still_yields_a_date_string(self):
        yaml_text = (
            "- { id: SA_1, name: Erste, group: Kampf, status: byHand, note: x, "
            "pointer: { file: a, symbol: b }, reviewed: { by: sam, date: 2026-09-14 } }\n"
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "catalog.yaml"
            path.write_text(yaml_text)
            entries = catalog.load_catalog(path)
        conn = sqlite3.connect(":memory:")
        catalog.write_catalog_table(conn, entries)
        reviewed_on = conn.execute("SELECT reviewed_on FROM catalog WHERE rule_id = 'SA_1'").fetchone()[0]
        self.assertEqual(reviewed_on, "2026-09-14")


class ImportCatalogTests(unittest.TestCase):
    """Uses an in-memory sqlite db with a minimal rules/rules_i18n/categories/groups schema."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.catalog_path = self.root / "catalog.yaml"
        self.snapshot_path = self.root / "snapshot.json"

    def tearDown(self):
        self.tmp.cleanup()

    def _conn(self):
        conn = sqlite3.connect(":memory:")
        conn.executescript("""
            CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL);
            CREATE TABLE groups (id INTEGER PRIMARY KEY, category TEXT NOT NULL, name TEXT NOT NULL);
            CREATE TABLE rules (id TEXT PRIMARY KEY, category TEXT NOT NULL, group_id INTEGER);
            CREATE TABLE rules_i18n (rule_id TEXT NOT NULL, locale TEXT NOT NULL, name TEXT NOT NULL);
        """)
        conn.execute("INSERT INTO categories VALUES ('special_ability', 'Sonderfertigkeit')")
        conn.execute("INSERT INTO groups VALUES (1, 'special_ability', 'Kampf')")
        conn.execute("INSERT INTO rules VALUES ('SA_1', 'special_ability', 1)")
        conn.execute("INSERT INTO rules VALUES ('SA_2', 'special_ability', NULL)")
        conn.execute("INSERT INTO rules_i18n VALUES ('SA_1', 'de-DE', 'Erste')")
        conn.execute("INSERT INTO rules_i18n VALUES ('SA_2', 'de-DE', 'Zweite')")
        conn.commit()
        return conn

    def _write_catalog(self, text):
        self.catalog_path.write_text(text)

    def test_a_valid_catalog_writes_the_table(self):
        self._write_catalog(
            "- { id: SA_1, name: Erste, group: Kampf, status: todo, why: x }\n"
            "- { id: SA_2, name: Zweite, group: Sonderfertigkeit, status: todo, why: x }\n"
        )
        conn = self._conn()
        catalog.import_catalog(conn, self.catalog_path, self.snapshot_path, self.root,
                                update_snapshot=True)
        rows = conn.execute("SELECT rule_id FROM catalog ORDER BY rule_id").fetchall()
        self.assertEqual(rows, [("SA_1",), ("SA_2",)])

    def test_a_catalog_with_a_problem_raises(self):
        self._write_catalog("- { id: SA_1, name: Erste, group: Kampf, status: todo, why: x }\n")
        conn = self._conn()
        with self.assertRaises(SystemExit):
            catalog.import_catalog(conn, self.catalog_path, self.snapshot_path, self.root,
                                    update_snapshot=True)

    def test_snapshot_drift_raises_and_update_snapshot_writes(self):
        self._write_catalog(
            "- { id: SA_1, name: Erste, group: Kampf, status: todo, why: x }\n"
            "- { id: SA_2, name: Zweite, group: Sonderfertigkeit, status: todo, why: x }\n"
        )
        self.snapshot_path.write_text(
            json.dumps({"implemented": 1, "byHand": 0, "noRollEffect": 0, "todo": 1}))

        with self.assertRaises(SystemExit):
            catalog.import_catalog(self._conn(), self.catalog_path, self.snapshot_path, self.root,
                                    update_snapshot=False)

        catalog.import_catalog(self._conn(), self.catalog_path, self.snapshot_path, self.root,
                                update_snapshot=True)
        snap = json.loads(self.snapshot_path.read_text())
        self.assertEqual(snap, {"implemented": 0, "byHand": 0, "noRollEffect": 0, "todo": 2})

    def test_the_source_hash_is_stored(self):
        self._write_catalog(
            "- { id: SA_1, name: Erste, group: Kampf, status: todo, why: x }\n"
            "- { id: SA_2, name: Zweite, group: Sonderfertigkeit, status: todo, why: x }\n"
        )
        conn = self._conn()
        catalog.import_catalog(conn, self.catalog_path, self.snapshot_path, self.root,
                                update_snapshot=True)
        stored = conn.execute(
            "SELECT value FROM catalog_meta WHERE key = 'source_sha256'").fetchone()[0]
        self.assertEqual(stored, catalog.source_hash(self.catalog_path))


if __name__ == "__main__":
    unittest.main()
