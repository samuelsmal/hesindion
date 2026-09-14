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
        no_clauses = entry(id="SA_2", name="Zweite", status="implemented")
        self.assertEqual(catalog.validate([entry(), no_clauses], RULES, self.root),
                         ["SA_2: implemented needs a non-empty clauses list"])


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
        rows = conn.execute("SELECT rule_id, name, status, note, pointer_file, pointer_symbol, reviewed_by, reviewed_on "
                            "FROM catalog ORDER BY rule_id").fetchall()
        self.assertEqual(rows, [
            ("SA_1", "Erste", "todo", "not yet read", None, None, None, None),
            ("SA_2", "Zweite", "byHand", "by hand", "Hero.swift", "x", "sam", "2026-09-14"),
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
                                update_snapshot=True,
                                vocabulary_path=REPO_ROOT / "specs/data/rule-vocabulary.json")
        rows = conn.execute("SELECT rule_id FROM catalog ORDER BY rule_id").fetchall()
        self.assertEqual(rows, [("SA_1",), ("SA_2",)])

    def test_a_catalog_with_a_problem_raises(self):
        self._write_catalog("- { id: SA_1, name: Erste, group: Kampf, status: todo, why: x }\n")
        conn = self._conn()
        with self.assertRaises(SystemExit):
            catalog.import_catalog(conn, self.catalog_path, self.snapshot_path, self.root,
                                    update_snapshot=True,
                                    vocabulary_path=REPO_ROOT / "specs/data/rule-vocabulary.json")

    def test_snapshot_drift_raises_and_update_snapshot_writes(self):
        self._write_catalog(
            "- { id: SA_1, name: Erste, group: Kampf, status: todo, why: x }\n"
            "- { id: SA_2, name: Zweite, group: Sonderfertigkeit, status: todo, why: x }\n"
        )
        self.snapshot_path.write_text(
            json.dumps({"implemented": 1, "byHand": 0, "noRollEffect": 0, "todo": 1}))

        with self.assertRaises(SystemExit):
            catalog.import_catalog(self._conn(), self.catalog_path, self.snapshot_path, self.root,
                                    update_snapshot=False,
                                    vocabulary_path=REPO_ROOT / "specs/data/rule-vocabulary.json")

        catalog.import_catalog(self._conn(), self.catalog_path, self.snapshot_path, self.root,
                                update_snapshot=True,
                                vocabulary_path=REPO_ROOT / "specs/data/rule-vocabulary.json")
        snap = json.loads(self.snapshot_path.read_text())
        self.assertEqual(snap, {"implemented": 0, "byHand": 0, "noRollEffect": 0, "todo": 2})

    def test_the_source_hash_is_stored(self):
        self._write_catalog(
            "- { id: SA_1, name: Erste, group: Kampf, status: todo, why: x }\n"
            "- { id: SA_2, name: Zweite, group: Sonderfertigkeit, status: todo, why: x }\n"
        )
        conn = self._conn()
        catalog.import_catalog(conn, self.catalog_path, self.snapshot_path, self.root,
                                update_snapshot=True,
                                vocabulary_path=REPO_ROOT / "specs/data/rule-vocabulary.json")
        stored = conn.execute(
            "SELECT value FROM catalog_meta WHERE key = 'source_sha256'").fetchone()[0]
        self.assertEqual(stored, catalog.source_hash(self.catalog_path))

    def test_the_vocabulary_hash_is_stored(self):
        self._write_catalog(
            "- { id: SA_1, name: Erste, group: Kampf, status: todo, why: x }\n"
            "- { id: SA_2, name: Zweite, group: Sonderfertigkeit, status: todo, why: x }\n"
        )
        conn = self._conn()
        vocab = REPO_ROOT / "specs/data/rule-vocabulary.json"
        catalog.import_catalog(conn, self.catalog_path, self.snapshot_path, self.root,
                                update_snapshot=True, vocabulary_path=vocab)
        stored = conn.execute(
            "SELECT value FROM catalog_meta WHERE key = 'vocabulary_sha256'").fetchone()[0]
        self.assertEqual(stored, catalog.source_hash(vocab))


REPO_ROOT = Path(__file__).resolve().parents[2]

# A cut-down vocabulary with the same shape as specs/data/rule-vocabulary.json.
VOCAB = {
    "version": 1,
    "combinators": ["all", "any", "not"],
    "predicates": {
        "situation.mounted": {"args": {}, "required": []},
        "opponent.onFoot": {"args": {}, "required": []},
        "hero.fokusRule": {"args": {}, "required": [], "value": "string"},
        "loadout.reach": {"args": {}, "required": [], "value": "enum:reach"},
        "situation.targetZone": {"args": {}, "required": [], "value": "list:zone"},
        "loadout.weapon": {"args": {"technique": "strings", "item": "string", "consecrated": "bool"}, "required": []},
        "loadout.shield": {"args": {"item": "string"}, "required": []},
        "gm.fact": {"args": {"id": "string", "span": "enum:span"}, "required": ["id", "span"]},
    },
    "effects": {
        "add": {"args": {"target": "enum:target", "talentId": "string", "value": "int", "per": "enum:per"},
                "required": ["target", "value"]},
        "modifyRule": {"args": {"id": "string", "target": "enum:target", "talentId": "string",
                                "add": "int", "set": "int", "multiply": "number"},
                       "required": ["id", "target"]},
        "choice": {"args": {}, "required": [], "value": "list:effect"},
    },
    "enums": {
        "target": ["at", "pa", "vw", "talent"],
        "domain": ["meleeAttack", "meleeParry", "talentCheck"],
        "span": ["hero", "opponent", "attack", "round"],
        "per": ["tier", "defencesThisRound"],
        "reach": ["Kurz", "Mittel", "Lang"],
        "zone": ["kopf", "torso"],
        "kind": ["passive", "offer"],
        "tiers": ["owned"],
    },
}

GOLGARITEN = {
    "id": "SA_1", "name": "Erste", "group": "Kampf", "status": "implemented",
    "applies_with": {"all": [
        "situation.mounted",
        {"any": [
            {"loadout.weapon": {"technique": "CT_5", "item": "Rabenschnabel"}},
            {"loadout.shield": {"item": "Großschild"}},
        ]},
    ]},
    "clauses": [
        {"kind": "passive", "domains": ["meleeAttack"], "when": ["opponent.onFoot"],
         "effects": [{"modifyRule": {"id": "GRW_vorteilhaftePosition", "target": "at", "add": 2}}]},
        {"kind": "passive", "domains": ["meleeParry"],
         "effects": [{"add": {"target": "pa", "value": 1}}]},
    ],
}

GRW = {"id": "GRW_vorteilhaftePosition", "name": "Vorteilhafte Position", "group": "Grundregel",
       "status": "implemented",
       "clauses": [{"kind": "passive", "domains": ["meleeAttack"], "when": ["situation.mounted", "opponent.onFoot"],
                    "effects": [{"add": {"target": "at", "value": 2}}]}]}


class ClauseValidationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def validate(self, *entries):
        # Pad with a plain entry for every rules.db id the caller did not supply, so
        # the coverage check ("no catalog entry") never masks the clause problems.
        given = {e["id"] for e in entries}
        pad = [entry(id=rid, name=name) for rid, name in RULES.items() if rid not in given]
        return catalog.validate(list(entries) + pad, RULES, self.root, vocabulary=VOCAB)

    def test_the_design_example_is_valid(self):
        self.assertEqual(self.validate(GOLGARITEN, GRW), [])

    def test_a_grw_id_needs_no_rules_row_but_others_still_do(self):
        problems = self.validate(GRW, dict(GRW, id="GRX_nope"))
        self.assertIn("GRX_nope: not in rules.db", problems)
        self.assertFalse(any(p.startswith("GRW_vorteilhaftePosition:") for p in problems))

    def test_a_grw_name_and_group_are_not_checked_against_the_database(self):
        groups = {"SA_1": "Kampf", "SA_2": "Kampf"}
        self.assertEqual(catalog.validate([entry(), entry(id="SA_2", name="Zweite"), GRW], RULES, self.root, groups, VOCAB), [])

    def test_an_unknown_predicate_effect_target_domain_and_kind_are_named(self):
        bad = dict(GRW, id="GRW_bad", clauses=[{
            "kind": "sometimes", "domains": ["meleeAttack", "swimming"],
            "when": ["situation.raining", {"gm.fact": {"id": "x", "span": "century"}}],
            "effects": [{"add": {"target": "luck", "value": 1}}, {"sing": {}}],
        }])
        problems = self.validate(GRW, bad)
        self.assertIn("GRW_bad: clause 0: kind 'sometimes' is not one of passive, offer", problems)
        self.assertIn("GRW_bad: clause 0: unknown domain 'swimming'", problems)
        self.assertIn("GRW_bad: clause 0: unknown predicate 'situation.raining'", problems)
        self.assertIn("GRW_bad: clause 0: gm.fact.span is 'century', expected enum:span", problems)
        self.assertIn("GRW_bad: clause 0 effect 0: add.target is 'luck', expected enum:target", problems)
        self.assertIn("GRW_bad: clause 0 effect 1: unknown effect 'sing'", problems)

    def test_an_unknown_clause_key_and_a_missing_argument_are_named(self):
        bad = dict(GRW, id="GRW_bad", clauses=[{
            "kind": "passive", "domains": ["meleeAttack"], "cost": 1,
            "when": [{"gm.fact": {"id": "x"}}, {"loadout.weapon": {"colour": "red"}}],
            "effects": [{"add": {"target": "at"}}],
        }])
        problems = self.validate(GRW, bad)
        self.assertIn("GRW_bad: clause 0: unknown clause key 'cost'", problems)
        self.assertIn("GRW_bad: clause 0: gm.fact needs span", problems)
        self.assertIn("GRW_bad: clause 0: loadout.weapon has no argument 'colour'", problems)
        self.assertIn("GRW_bad: clause 0 effect 0: add needs value", problems)

    def test_a_scalar_predicate_takes_its_value_form(self):
        ok = dict(GRW, id="GRW_ok", clauses=[{"kind": "passive", "domains": ["meleeAttack"],
                  "when": [{"hero.fokusRule": "trefferzonen"}, {"loadout.reach": "Kurz"},
                           {"situation.targetZone": ["kopf", "torso"]}],
                  "effects": [{"add": {"target": "at", "value": -2}}]}])
        self.assertEqual(self.validate(GRW, ok), [])
        bad = dict(ok, id="GRW_bad", clauses=[{"kind": "passive", "domains": ["meleeAttack"],
                   "when": [{"loadout.reach": "Weit"}, {"situation.targetZone": ["nase"]}, "hero.fokusRule"],
                   "effects": [{"add": {"target": "at", "value": -2}}]}])
        problems = self.validate(GRW, bad)
        self.assertIn("GRW_bad: clause 0: loadout.reach is 'Weit', expected enum:reach", problems)
        self.assertIn("GRW_bad: clause 0: situation.targetZone is ['nase'], expected list:zone", problems)
        self.assertIn("GRW_bad: clause 0: hero.fokusRule needs an argument", problems)

    def test_modify_rule_must_name_an_implemented_entry_and_do_something(self):
        lonely = dict(GOLGARITEN)   # GRW not in the catalog
        problems = self.validate(lonely)
        self.assertIn("SA_1: clause 0 effect 0: modifyRule names 'GRW_vorteilhaftePosition', which is not an implemented entry", problems)
        idle = dict(GOLGARITEN, clauses=[{"kind": "passive", "domains": ["meleeAttack"],
                    "effects": [{"modifyRule": {"id": "GRW_vorteilhaftePosition", "target": "at"}}]}])
        self.assertIn("SA_1: clause 0 effect 0: modifyRule needs add, set or multiply", self.validate(idle, GRW))

    def test_a_talent_target_carries_its_id(self):
        ok = dict(GRW, id="GRW_ok", clauses=[{"kind": "passive", "domains": ["talentCheck"],
                  "effects": [{"add": {"target": {"talent": "TAL_8"}, "value": -2}}]}])
        self.assertEqual(self.validate(GRW, ok), [])
        bad = dict(ok, id="GRW_bad", clauses=[{"kind": "passive", "domains": ["talentCheck"],
                   "effects": [{"add": {"target": "talent", "value": -2}}]}])
        self.assertIn("GRW_bad: clause 0 effect 0: target talent needs an id", self.validate(GRW, bad))

    def test_an_offer_with_a_choice_and_tiers(self):
        ok = dict(GRW, id="GRW_ok", clauses=[{"kind": "offer", "domains": ["meleeAttack", "meleeParry"], "tiers": "owned",
                  "effects": [{"choice": [{"add": {"target": "at", "value": 1}}, {"add": {"target": "vw", "value": 1}}]}]}])
        self.assertEqual(self.validate(GRW, ok), [])
        bad = dict(ok, id="GRW_bad", clauses=[{"kind": "passive", "domains": ["meleeAttack"], "tiers": 0,
                   "effects": [{"choice": [{"add": {"target": "at", "value": 1}}]}]}])
        problems = self.validate(GRW, bad)
        self.assertIn("GRW_bad: clause 0: tiers is only for an offer", problems)
        self.assertIn("GRW_bad: clause 0: tiers is 0, expected 'owned' or a positive integer", problems)
        self.assertIn("GRW_bad: clause 0 effect 0: choice needs at least two options", problems)

    def test_implemented_needs_a_non_empty_clause_list(self):
        self.assertIn("GRW_bad: implemented needs a non-empty clauses list",
                      self.validate(GRW, dict(GRW, id="GRW_bad", clauses=[])))
        self.assertIn("GRW_bad: implemented needs a non-empty clauses list",
                      self.validate(GRW, dict(GRW, id="GRW_bad", clauses="yes")))

    def test_the_committed_vocabulary_accepts_the_design_example(self):
        vocab = catalog.load_vocabulary(REPO_ROOT / "specs/data/rule-vocabulary.json")
        problems = catalog.validate([GOLGARITEN, GRW, entry(id="SA_2", name="Zweite")], RULES, self.root, vocabulary=vocab)
        self.assertEqual(problems, [])


class NormalizeTests(unittest.TestCase):
    def test_the_design_example_normalises(self):
        applies, clauses = catalog.entry_json(GOLGARITEN)
        self.assertEqual(json.loads(applies), {"all": [
            {"is": "situation.mounted"},
            {"any": [
                {"is": "loadout.weapon", "technique": "CT_5", "item": "Rabenschnabel"},
                {"is": "loadout.shield", "item": "Großschild"},
            ]},
        ]})
        self.assertEqual(json.loads(clauses), [
            {"kind": "passive", "domains": ["meleeAttack"], "when": {"all": [{"is": "opponent.onFoot"}]},
             "effects": [{"effect": "modifyRule", "id": "GRW_vorteilhaftePosition", "target": "at", "add": 2}]},
            {"kind": "passive", "domains": ["meleeParry"],
             "effects": [{"effect": "add", "target": "pa", "value": 1}]},
        ])

    def test_scalars_choices_talents_and_not(self):
        e = dict(GRW, clauses=[{"kind": "offer", "domains": ["meleeAttack"], "tiers": "owned",
                 "when": {"not": {"hero.fokusRule": "trefferzonen"}},
                 "effects": [{"choice": [{"add": {"target": "at", "value": 1}},
                                         {"add": {"target": {"talent": "TAL_8"}, "value": -2}}]}]}])
        _, clauses = catalog.entry_json(e)
        self.assertEqual(json.loads(clauses), [
            {"kind": "offer", "domains": ["meleeAttack"], "tiers": "owned",
             "when": {"not": {"is": "hero.fokusRule", "value": "trefferzonen"}},
             "effects": [{"effect": "choice", "options": [
                 {"effect": "add", "target": "at", "value": 1},
                 {"effect": "add", "target": "talent", "talentId": "TAL_8", "value": -2},
             ]}]},
        ])

    def test_a_non_implemented_entry_has_no_json(self):
        self.assertEqual(catalog.entry_json(entry()), (None, None))


class ClauseTableTests(unittest.TestCase):
    def test_the_table_carries_name_applies_with_and_clauses(self):
        conn = sqlite3.connect(":memory:")
        catalog.write_catalog_table(conn, [GOLGARITEN, entry(id="SA_2", name="Zweite")])
        rows = conn.execute("SELECT rule_id, name, applies_with IS NOT NULL, clauses IS NOT NULL "
                            "FROM catalog ORDER BY rule_id").fetchall()
        self.assertEqual(rows, [("SA_1", "Erste", 1, 1), ("SA_2", "Zweite", 0, 0)])
        clauses = json.loads(conn.execute("SELECT clauses FROM catalog WHERE rule_id = 'SA_1'").fetchone()[0])
        self.assertEqual(clauses[1]["effects"], [{"effect": "add", "target": "pa", "value": 1}])


if __name__ == "__main__":
    unittest.main()
