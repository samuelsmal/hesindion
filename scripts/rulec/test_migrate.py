"""migrate.py: the fixed old→new key table (plan Task 7, spec §10.3 step 1). One test per row of the
mechanical map, plus comments, untouched lines, idempotence, `reviewed` and MIGRATION.md."""
import re
import shutil
import tempfile
import unittest
from pathlib import Path

from rulec import migrate

EXAMPLES = Path(__file__).resolve().parents[2] / "docs" / "rules-rework" / "examples"


def clause(effects: str) -> str:
    """A rule snippet with one clause whose effects are `effects` (lines at 6 spaces)."""
    return "clauses:\n  - id: X1\n    text: t\n    effects:\n" + effects


def rule(src):
    return migrate.migrate_text(src, kind="rule")


def sits(src):
    return migrate.migrate_text(src, kind="situations")


def keys(residue):
    return [(r.key, r.reason) for r in residue]


class RuleRowTests(unittest.TestCase):
    def test_rule_keys_catalog_id_agent_pass_tiers(self):
        out, residue = rule("id: SA_1\ncatalog_id: SA_1\ntiers: 3\nagent_pass: null\n")
        self.assertEqual(out, "id: SA_1\ncatalogId: SA_1\nlevels: 3\nagentPass: null\n")
        self.assertEqual(residue, [])

    def test_ruling_keys_why_recommended_applies_to(self):
        src = ("rulings:\n  - id: r1\n    recommended: a\n    why_recommended: >\n      because\n"
               "    applies_to: [SA_1.X1]\n")
        out, residue = rule(src)
        self.assertEqual(out, "rulings:\n  - id: r1\n    recommended: a\n    whyRecommended: >\n"
                              "      because\n    appliesTo: [SA_1.X1]\n")
        self.assertEqual(residue, [])

    def test_shared_rulings_file_is_a_list(self):
        out, residue = rule("- id: round-up\n  status: decided\n  applies_to: [SA_62.ST2]\n")
        self.assertEqual(out, "- id: round-up\n  status: decided\n  appliesTo: [SA_62.ST2]\n")
        self.assertEqual(residue, [])

    def test_effects_none_with_why_becomes_none(self):
        src = "clauses:\n  - id: X1\n    text: t\n    effects: none\n    why: purchase cost\n"
        out, residue = migrate.migrate_text(src, kind="rule")
        self.assertIn("    none: purchase cost\n", out)
        self.assertNotIn("effects", out)
        self.assertEqual(residue, [])

    def test_effects_none_keeps_the_blank_line_before_the_next_clause(self):
        src = ("clauses:\n  - id: X1\n    text: t\n    effects: none\n    why: cost\n\n"
               "  - id: X2\n    text: u\n    effects: none\n    why: prerequisite\n")
        out, _ = rule(src)
        self.assertEqual(out, "clauses:\n  - id: X1\n    text: t\n    none: cost\n\n"
                              "  - id: X2\n    text: u\n    none: prerequisite\n")

    def test_effects_list_with_why_becomes_a_comment_above_effects(self):
        src = clause("      - add: { to: at, value: 1 }\n") + "    why: only in melee\n"
        out, residue = rule(src)
        self.assertEqual(out, "clauses:\n  - id: X1\n    text: t\n    # why: only in melee\n"
                              "    effects:\n      - add: { to: at, value: 1 }\n")
        self.assertEqual(residue, [])

    def test_the_lines_after_a_removed_why_stay(self):
        src = ("clauses:\n  - id: X1\n    text: t\n    effects:\n      - add: { to: at, value: 1 }\n"
               "        # note\n    why: >\n      only in\n      melee\n\n"
               "  - id: X2\n    text: u\n    none: cost\n")
        out, _ = rule(src)
        self.assertEqual(out, "clauses:\n  - id: X1\n    text: t\n    # why: only in melee\n    effects:\n"
                              "      - add: { to: at, value: 1 }\n        # note\n\n"
                              "  - id: X2\n    text: u\n    none: cost\n")

    def test_apply_level_becomes_use_level(self):
        out, residue = rule(clause("      - apply_level: { rule: COND_6.SZ5, level: \"level - 1\" }\n"))
        self.assertIn("      - useLevel: { rule: COND_6.SZ5, as: \"level - 1\" }\n", out)
        self.assertEqual(residue, [])

    def test_halve_becomes_multiply_by_one_half(self):
        out, residue = rule(clause("      - halve: { value: item.ladezeit, round: up }\n"))
        self.assertIn("      - multiply: { to: item.ladezeit, by: 0.5, round: up }\n", out)
        self.assertEqual(residue, [])

    def test_shift_becomes_add_on_a_spell_parameter(self):
        out, residue = rule(clause("      - shift: { param: castingTime, steps: 1, table: zauberdauer }\n"))
        self.assertIn("      - add: { to: spell.castingTime, value: 1, scale: zauberdauer }\n", out)
        self.assertEqual(residue, [])

    def test_shift_of_a_parameter_already_named_spell_is_not_prefixed_twice(self):
        out, _ = rule(clause("      - shift: { param: spell.range, steps: 1, table: ZM8.reichweite }\n"))
        self.assertIn("      - add: { to: spell.range, value: 1, scale: ZM8.reichweite }\n", out)

    def test_a_verb_the_effect_already_has_is_never_overwritten(self):
        src = clause("      - when: { level: 1 }\n"
                     "        shift: { param: range, steps: 1, table: ZM8.reichweite }\n"
                     "        add: { to: check, value: -1 }\n")
        out, residue = rule(src)
        self.assertEqual(out, src)
        self.assertEqual([r.key for r in residue], ["shift"])
        self.assertIn("already has", residue[0].reason)

    def test_opponent_add_becomes_add_on_opponent_targets(self):
        out, residue = rule(clause("      - opponent_add: { to: [pa, aw], value: -2 }\n"))
        self.assertIn("      - add: { to: [opponent.pa, opponent.aw], value: -2 }\n", out)
        self.assertEqual(residue, [])
        out, residue = rule(clause("      - opponent_add: { to: at, value: -2 }\n"))
        self.assertIn("      - add: { to: opponent.at, value: -2 }\n", out)

    def test_opponent_add_with_another_key_is_residue(self):
        src = clause("      - opponent_add: { to: [pa, aw], value: -2, per: chosenTier }\n")
        out, residue = rule(src)
        self.assertEqual(out, src)
        self.assertEqual([r.key for r in residue], ["opponent_add"])
        self.assertIn("per", residue[0].reason)

    def test_remove_becomes_suppress_of_a_line(self):
        out, residue = rule(clause("      - remove: { line: schilde.SCH3 }\n"))
        self.assertIn("      - suppress: { line: { line: schilde.SCH3 } }\n", out)
        self.assertEqual(residue, [])

    def test_requires_any_of_becomes_require_that_any(self):
        out, residue = rule(clause("      - requires: { any_of: [{ hero.has: SA_862 }, { ally.has: SA_862 }] }\n"))
        self.assertIn("      - require: { that: { any: [{ hero.has: SA_862 }, { ally.has: SA_862 }] } }\n", out)
        self.assertEqual(residue, [])

    def test_requires_of_facts_becomes_require_that(self):
        out, residue = rule(clause("      - requires: { loadout.weapon.technique: [CT_5, CT_6] }\n"
                                   "        ruling: sf-technique-lists\n"))
        self.assertIn("      - require: { that: { loadout.weapon.technique: [CT_5, CT_6] } }\n"
                      "        ruling: sf-technique-lists\n", out)
        self.assertEqual(residue, [])

    def test_requires_with_a_key_that_is_not_a_fact_is_residue(self):
        src = clause("      - requires: { loadout.any.technique: [CT_3] }\n")
        out, residue = rule(src)
        self.assertEqual(out, src)
        self.assertEqual([r.key for r in residue], ["requires"])
        self.assertIn("loadout.any.technique", residue[0].reason)

    def test_excludes_becomes_forbid_together(self):
        out, residue = rule(clause("      - excludes: { manoeuvre: finte }\n"))
        self.assertIn("      - forbid: { what: { manoeuvre: finte }, together: true }\n", out)
        self.assertEqual(residue, [])

    def test_tell_names_its_audience(self):
        out, _ = rule(clause("      - tell: { opponent: passierschlag }\n"))
        self.assertIn("      - tell: { to: opponent, text: passierschlag }\n", out)
        out, _ = rule(clause("      - tell: { hero: \"nur mit der längeren Waffe\" }\n"))
        self.assertIn("      - tell: { to: player, text: \"nur mit der längeren Waffe\" }\n", out)
        out, residue = rule(clause("      - tell: { player: x }\n"))
        self.assertIn("      - tell: { to: player, text: x }\n", out)
        self.assertEqual(residue, [])

    def test_tell_with_a_structure_instead_of_a_text_is_residue(self):
        src = clause("      - tell: { opponent: { check: { talent: Kraftakt } } }\n")
        out, residue = rule(src)
        self.assertEqual(out, src)
        self.assertEqual([r.key for r in residue], ["tell"])

    def test_provides_becomes_one_provide_per_key_each_with_the_meta_keys(self):
        src = clause("      - provides: { mount.gs: 12, mount.kk: 25 }\n"
                     "        when: { hero.mounted: true }\n"
                     "        ruling: mount-profile-data\n"
                     "        because: data\n")
        out, residue = rule(src)
        self.assertIn("      - provide: { name: mount.gs, value: 12 }\n"
                      "        when: { hero.mounted: true }\n"
                      "        ruling: mount-profile-data\n"
                      "        because: data\n"
                      "      - provide: { name: mount.kk, value: 25 }\n"
                      "        when: { hero.mounted: true }\n"
                      "        ruling: mount-profile-data\n"
                      "        because: data\n", out)
        self.assertEqual(residue, [])

    def test_provides_in_block_style_keeps_each_keys_comment(self):
        src = clause("      - provides:\n"
                     "          tables.a: [1, 2, 4]      # Aktionen\n"
                     "          tables.b: [x, 2, 4]      # Schritt\n"
                     "          tables.c: [1, 2, 4]      # AsP\n"
                     "        ruling: r\n")
        out, residue = rule(src)
        self.assertRegex(out, r"      - provide:\n          name: tables.a\n          value: \[1, 2, 4\] +# Aktionen\n"
                              r"        ruling: r\n")
        self.assertRegex(out, r"name: tables.b\n          value: \[x, 2, 4\] +# Schritt\n        ruling: r\n")
        self.assertRegex(out, r"name: tables.c\n          value: \[1, 2, 4\] +# AsP\n        ruling: r\n$")
        self.assertEqual(residue, [])

    def test_provides_with_one_key_becomes_one_provide(self):
        out, residue = rule(clause("      - provides: { loadout.weapon: stats }\n        # the row\n"))
        self.assertIn("      - provide: { name: loadout.weapon, value: stats }\n        # the row\n", out)
        self.assertEqual(residue, [])

    def test_provides_with_from_is_residue(self):
        src = clause("      - provides: { item.value: ladezeit, from: weapon.reloadTime }\n")
        out, residue = rule(src)
        self.assertEqual(out, src)
        self.assertEqual([r.key for r in residue], ["provides"])

    def test_charge_becomes_cost(self):
        out, residue = rule(clause("      - charge: { amount: spell.cost.effective, pool: asp }\n"))
        self.assertIn("      - cost: { pool: asp, amount: spell.cost.effective }\n", out)
        self.assertEqual(residue, [])

    def test_charge_with_other_keys_is_residue(self):
        src = clause("      - charge: { pool: asp, amount: 1, every: spell.interval }\n")
        out, residue = rule(src)
        self.assertEqual(out, src)
        self.assertEqual([r.key for r in residue], ["charge"])

    def test_gain_state_becomes_gain_rule(self):
        out, residue = rule(clause("      - gain: { state: STATE_10 }\n"))
        self.assertIn("      - gain: { rule: STATE_10 }\n", out)
        self.assertEqual(residue, [])

    def test_gain_state_with_until_is_residue(self):
        src = clause("      - gain: { state: STATE_10, until: levelBelow4 }\n")
        out, residue = rule(src)
        self.assertEqual(out, src)
        self.assertEqual([r.key for r in residue], ["gain"])

    def test_unless_without_when_becomes_when_not(self):
        out, residue = rule(clause("      - unless: { hero.has: SA_173 }\n"
                                   "        excludes: { manoeuvre: finte }\n"))
        self.assertIn("      - when: { not: { hero.has: SA_173 } }\n"
                      "        forbid: { what: { manoeuvre: finte }, together: true }\n", out)
        self.assertEqual(residue, [])

    def test_unless_beside_a_when_is_residue(self):
        src = clause("      - when: { level: 4 }\n        unless: { hero.has: SA_173 }\n"
                     "        add: { to: at, value: -1 }\n")
        out, residue = rule(src)
        self.assertEqual(out, src)
        self.assertEqual([r.key for r in residue], ["unless"])

    def test_a_payload_key_that_is_not_a_field_of_its_verb_is_residue(self):
        src = clause("      - offer: { choice: targetZone, requires: { choice: x } }\n")
        out, residue = rule(src)
        self.assertEqual(out, src)
        self.assertEqual(keys(residue), [("requires", "not a field of `offer`")])

    def test_set_on_a_target_is_unchanged(self):
        src = clause("      - set: { to: gs, value: 1 }\n")
        out, residue = rule(src)
        self.assertEqual(out, src)
        self.assertEqual(residue, [])

    def test_unknown_verb_is_residue_not_guessed(self):
        src = "clauses:\n  - id: X1\n    text: t\n    effects:\n      - raise: { line: A.B, by: 1 }\n"
        out, residue = migrate.migrate_text(src, kind="rule")
        self.assertIn("raise:", out)
        self.assertEqual([(r.key, r.reason) for r in residue], [("raise", "no one-to-one verb")])


class WhenRowTests(unittest.TestCase):
    def when(self, cond):
        out, residue = rule(clause(f"      - when: {cond}\n        add: {{ to: at, value: 1 }}\n"))
        return out.splitlines()[4], residue

    def test_gm_fact(self):
        self.assertEqual(self.when("{ gm.fact: fromBehind }"),
                         ("      - when: { gmFact.fromBehind: true }", []))

    def test_choice_with_bonus(self):
        self.assertEqual(self.when("{ choice: formation, bonus: at }"),
                         ("      - when: { choice.formation: true, choice.formation.bonus: at }", []))

    def test_choice(self):
        self.assertEqual(self.when("{ choice: dornenspitze }"),
                         ("      - when: { choice.dornenspitze: true }", []))

    def test_manoeuvre_attack_defence(self):
        self.assertEqual(self.when("{ manoeuvre: finte, attack: melee, defence: pa }"),
                         ("      - when: { action.manoeuvre: finte, action.attack: melee, action.defence: pa }", []))

    def test_roll_with(self):
        self.assertEqual(self.when("{ roll.with: shield, roll.with.shieldSize: gross, roll.with.reach: lang }"),
                         ("      - when: { action.with: shield, loadout.shield.size: gross, loadout.reach: lang }", []))

    def test_weapon_technique(self):
        self.assertEqual(self.when("{ weapon.technique: CT_2 }"),
                         ("      - when: { loadout.weapon.technique: CT_2 }", []))
        self.assertEqual(self.when("{ loadout.technique: CT_2 }"),
                         ("      - when: { loadout.weapon.technique: CT_2 }", []))

    def test_ruleset(self):
        self.assertEqual(self.when("{ ruleset: fokus.trefferzonen }"),
                         ("      - when: { rulesets: fokus.trefferzonen }", []))

    def test_check(self):
        self.assertEqual(self.when("{ check: Sinnesschärfe }"),
                         ("      - when: { check.talent: Sinnesschärfe }", []))

    def test_check_naming_the_kind_of_check_is_residue(self):
        for kind in ("at", "aw", "talent"):
            line, residue = self.when(f"{{ check: {kind} }}")
            self.assertEqual(line, f"      - when: {{ check: {kind} }}")
            self.assertEqual([r.key for r in residue], ["check"])

    def test_any_of_all_of(self):
        self.assertEqual(self.when("{ any_of: [{ manoeuvre: finte }, { all_of: [{ level: 1 }, { gm.fact: x }] }] }"),
                         ("      - when: { any: [{ action.manoeuvre: finte }, { all: [{ level: 1 }, { gmFact.x: true }] }] }", []))

    def test_a_when_inside_a_payload_is_mapped_too(self):
        out, _ = rule(clause("      - forbid: { choice: formation, when: { manoeuvre: finte } }\n"))
        self.assertIn("forbid: { choice: formation, when: { action.manoeuvre: finte } }", out)

    def test_a_fact_the_vocabulary_does_not_know_is_residue(self):
        line, residue = self.when("{ side: opponent, attack.kind: melee }")
        self.assertEqual(line, "      - when: { side: opponent, attack.kind: melee }")
        self.assertEqual([r.key for r in residue], ["side", "attack.kind"])


class SituationRowTests(unittest.TestCase):
    def test_file_keys_hero_file_base_hero(self):
        out, residue = sits("hero_file: \"x.json\"\nbase_hero:\n  abilities: { SA_1: 1 }\nsituations: []\n")
        self.assertEqual(out, "heroFile: \"x.json\"\nhero:\n  abilities: { SA_1: 1 }\nsituations: []\n")
        self.assertEqual(residue, [])

    def test_app_today(self):
        out, residue = sits("situations:\n  - id: \"1\"\n    app_today: >\n      wrong\n")
        self.assertEqual(out, "situations:\n  - id: \"1\"\n    appToday: >\n      wrong\n")
        self.assertEqual(residue, [])

    def test_choose_with_bonus(self):
        out, residue = sits("situations:\n  - id: \"1\"\n    choose: { formation: true, bonus: at }\n")
        self.assertIn("    choose: { choice.formation: true, choice.formation.bonus: at }\n", out)
        self.assertEqual(residue, [])

    def test_a_choose_key_that_is_not_a_fact_is_residue(self):
        out, residue = sits("situations:\n  - id: \"1\"\n    choose: { manoeuvre: finte, choice.x: true }\n")
        self.assertEqual(keys(residue), [("manoeuvre", "not a fact in the vocabulary")])

    def test_choose_with_two_choices_and_a_bonus_is_left(self):
        src = "situations:\n  - id: \"1\"\n    choose: { formation: true, vorstoss: true, bonus: at }\n"
        out, _ = sits(src)
        self.assertEqual(out, src)

    def test_expect_keys(self):
        src = ("situations:\n  - id: \"1\"\n    expect:\n      not_offered: [x]\n"
               "      at: { not_applied: [{ rule: SA_1 }] }\n      ini_base: 12\n      le_max: 30\n")
        out, residue = sits(src)
        self.assertEqual(out, "situations:\n  - id: \"1\"\n    expect:\n      notOffered: [x]\n"
                              "      at: { notApplied: [{ rule: SA_1 }] }\n      iniBase: 12\n      leMax: 30\n")
        self.assertEqual(residue, [])

    def test_expect_shield_parry_queries(self):
        for old in ("pa_shield", "shield_parry", "parry_shield"):
            out, residue = sits(f"situations:\n  - id: \"1\"\n    expect:\n      {old}: {{ total: 1 }}\n")
            self.assertIn("      \"pa(with: shield)\": { total: 1 }\n", out, old)
            self.assertEqual(residue, [], old)

    def test_expect_weapon_parry_query(self):
        out, residue = sits("situations:\n  - id: \"1\"\n    expect:\n      pa_weapon: 8\n")
        self.assertIn("      \"pa(with: weapon)\": 8\n", out)
        self.assertEqual(residue, [])

    def test_expect_hand_queries(self):
        src = ("situations:\n  - id: \"1\"\n    expect:\n      parry_main: 1\n      parry_off: 2\n"
               "      attack_main: 3\n      attack_off: 4\n")
        out, residue = sits(src)
        self.assertIn("      \"pa(with: mainHand)\": 1\n      \"pa(with: offHand)\": 2\n"
                      "      \"at(with: mainHand)\": 3\n      \"at(with: offHand)\": 4\n", out)
        self.assertEqual(residue, [])

    def test_an_unmapped_snake_case_key_is_residue(self):
        out, residue = sits("situations:\n  - id: \"1\"\n    expect:\n      at: { on_hit: 1 }\n")
        self.assertIn("on_hit", out)
        self.assertEqual(keys(residue), [("on_hit", "snake_case key, no mapping")])
        self.assertEqual((residue[0].line, residue[0].path), (4, 'situations["1"].expect.at.on_hit'))


class LayoutTests(unittest.TestCase):
    def test_a_comment_on_an_effect_survives(self):
        src = clause("      - remove: { line: schilde.SCH3 }\n"
                     "        # FORMAT: takes away another rule's line.\n"
                     "      - add: { to: at, value: 1 }   # trailing\n")
        out, _ = rule(src)
        self.assertIn("        # FORMAT: takes away another rule's line.\n", out)
        self.assertIn("      - add: { to: at, value: 1 }   # trailing\n", out)

    def test_untouched_lines_keep_their_layout(self):
        src = ("# head\nid: SA_1\nreviewed: { by: \"@x\", date: 2026-09-24 }\nclauses:\n  - id: X1\n    text: >\n"
               "      Ein langer Text, der gefaltet ist und nicht neu umbrochen werden darf, auch wenn er\n"
               "      über die Breite geht.\n    effects:\n"
               "      - when: { level: 1 }\n        add: { to: at,  value: 1 }     # aligned\n"
               "      - tell: { opponent: x }\n")
        out, _ = rule(src)
        self.assertEqual(out, src.replace("tell: { opponent: x }", "tell: { to: opponent, text: x }"))

    def test_a_flow_mapping_over_two_lines_keeps_its_comment(self):
        src = ("base_hero: { name: B, ko: 15,     # AT: no armour\n"
               "             advantages: { ADV_25: 2 } }\nsituations: []\n")
        out, _ = sits(src)
        self.assertEqual(out, src.replace("base_hero:", "hero:"))

    def test_a_query_key_is_judged_by_its_target_name(self):
        self.assertFalse(migrate.is_snake("check.modifier(talent: TAL_8)"))
        self.assertFalse(migrate.is_snake("level(rule: COND_1)"))
        self.assertTrue(migrate.is_snake("pa_shield(with: x)"))

    def test_rule_id_keys_are_never_residue(self):
        out, residue = sits("hero:\n  abilities: { SA_40: 1, ITEMTPL_19: 1 }\nsituations: []\n")
        self.assertEqual(residue, [])

    def test_idempotent(self):
        src = clause("      - requires: { any_of: [{ hero.has: SA_862 }] }\n"
                     "      - provides: { mount.gs: 12, mount.kk: 25 }\n"
                     "      - unless: { hero.has: SA_173 }\n        tell: { hero: x }\n") \
            + "    why: shown\n"
        once, r1 = rule(src)
        twice, r2 = rule(once)
        self.assertEqual(once, twice)
        self.assertEqual(r1, r2)


class TreeTests(unittest.TestCase):
    """Over a temp copy of the real draft files."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        for sub in ("rules", "situations"):
            shutil.copytree(EXAMPLES / sub, cls.root / sub, ignore=shutil.ignore_patterns("__pycache__"))
        cls.before = {p: p.read_text(encoding="utf-8") for p in cls.files(cls.root)}
        migrate.migrate_tree(cls.root)
        cls.after = {p: p.read_text(encoding="utf-8") for p in cls.files(cls.root)}

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    @staticmethod
    def files(root):
        return sorted((root / "rules").rglob("*.yaml")) + sorted((root / "situations").glob("*.yaml"))

    @staticmethod
    def reviewed(text):
        """The `reviewed:` entry's text, with its continuation lines."""
        m = re.search(r"^reviewed:.*\n(?:[ \t]+.*\n)*", text, re.M)
        return m.group(0) if m else None

    def test_reviewed_is_byte_identical(self):
        for p, text in self.before.items():
            self.assertEqual(self.reviewed(self.after[p]), self.reviewed(text), p)

    def test_running_twice_changes_nothing(self):
        md = (self.root / "MIGRATION.md").read_text(encoding="utf-8")
        migrate.migrate_tree(self.root)
        for p, text in self.after.items():
            self.assertEqual(p.read_text(encoding="utf-8"), text, p)
        self.assertEqual((self.root / "MIGRATION.md").read_text(encoding="utf-8"), md)

    def test_migration_md_has_a_section_per_file_and_the_reviews_section(self):
        md = (self.root / "MIGRATION.md").read_text(encoding="utf-8")
        for p in self.before:
            self.assertIn(f"\n## {p.relative_to(self.root).as_posix()}\n", md)
        self.assertRegex(md, r"\n## Reviews reset by hand edits\n\s*$")
        for item in re.findall(r"^- \[ \] .*$", md, re.M):
            self.assertRegex(item, r"^- \[ \] L\d+ \S.*: \S+ — \S")

    def test_the_only_snake_case_keys_left_are_listed(self):
        md = (self.root / "MIGRATION.md").read_text(encoding="utf-8")
        listed = set(re.findall(r"^- \[ \] L(\d+) \S+: (\S+) — ", md, re.M))
        sections = re.split(r"^## ", md, flags=re.M)
        by_file = {s.split("\n", 1)[0]: set(re.findall(r"^- \[ \] L(\d+) \S+: (\S+) — ", s, re.M))
                   for s in sections[1:]}
        self.assertTrue(listed)
        for p, text in self.after.items():
            rel = p.relative_to(self.root).as_posix()
            for n, key in migrate.snake_keys_in_text(text):
                self.assertIn((str(n), key), by_file[rel], f"{rel}:{n} {key}")


if __name__ == "__main__":
    unittest.main()
