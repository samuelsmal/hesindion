import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from rulec import compile, rules, situations, vocab
from rulec.__main__ import main

HEAD = """\
id: {id}
name: {id}
kind: {kind}
source: {{ url: x, book: y, page: 1, checked: 2026-09-24, hash: null }}
reviewed: null
"""

SA_1 = HEAD.format(id="SA_1", kind="specialAbility") + """\
clauses:
  - id: T1
    text: "eins"
    effects:
      - add: { to: at, value: 1 }
        ruling: r1
  - id: T2
    text: "zwei"
    effects:
      - add: { to: aw, value: 1 }
rulings:
  - id: r1
    question: q
    answer: null
"""

# Not owned by the fixture hero: an open ruling on `at` it does not reach.
SA_2 = HEAD.format(id="SA_2", kind="specialAbility") + """\
clauses:
  - id: X1
    text: "x"
    effects:
      - add: { to: at, value: 2 }
        ruling: r2
rulings:
  - id: r2
    question: q
    answer: null
"""

# Applies to everyone: its open ruling lies on the path of every `pa` query.
CORE = HEAD.format(id="CORE", kind="core") + """\
clauses:
  - id: K1
    text: "k"
    effects:
      - add: { to: pa, value: -1 }
        ruling: k1
rulings:
  - id: k1
    question: q
    answer: null
"""

# Reaches `*`, which every query evaluates.
SA_3 = HEAD.format(id="SA_3", kind="specialAbility") + """\
clauses:
  - id: S1
    text: "s"
    effects:
      - tell: { to: player, text: hallo }
        ruling: s3
rulings:
  - id: s3
    question: q
    answer: null
"""

# A decided ruling is not pending.
SA_4 = HEAD.format(id="SA_4", kind="specialAbility") + """\
clauses:
  - id: D1
    text: "d"
    effects:
      - add: { to: at, value: 1 }
        ruling: d1
rulings:
  - id: d1
    question: q
    answer: yes
"""

HERO = {
    "id": "H_1",
    "attr": {"values": [{"id": "ATTR_1", "value": 12}, {"id": "ATTR_7", "value": 13}]},
    "activatable": {"ADV_1": [{"tier": 2}], "ADV_0": [], "DISADV_2": [{"sid": 3}], "SA_9": [{}]},
    "ct": {"CT_5": 10},
    "talents": {"TAL_1": 5},
}

MAIN = """\
heroFile: ../hero.json
hero:
  abilities: { SA_1: 1 }
situations:
  - id: "1.10"
    name: expects only aw
    expect:
      aw: { total: 1 }
  - id: "1.2"
    name: expects at, from the clause with the open ruling
    expect:
      at: { total: 1, lines: [{ value: 1, from: SA_1.T1 }] }
"""


def tree(situation_files, rule_files=None, hero=HERO):
    d = Path(tempfile.mkdtemp())
    rules_dir = d / "rules"
    (rules_dir / "abilities").mkdir(parents=True)
    for rid, body in (rule_files or {"SA_1": SA_1, "SA_2": SA_2, "SA_3": SA_3,
                                     "SA_4": SA_4, "CORE": CORE}).items():
        (rules_dir / "abilities" / f"{rid}.yaml").write_text(body)
    (d / "situations").mkdir()
    for name, body in situation_files.items():
        (d / "situations" / name).write_text(body)
    (d / "hero.json").write_text(json.dumps(hero))
    return d


def run(situation_files, **kw):
    d = tree(situation_files, **kw)
    v = vocab.load()
    book, errors = rules.check(d / "rules", v)
    assert errors == [], [str(e) for e in errors]
    reach = compile.build_rules(book, v)["reach"]
    return situations.check(d / "situations", book, reach, v)


def ok(situation_files, **kw):
    out, errors = run(situation_files, **kw)
    assert errors == [], [str(e) for e in errors]
    return {s["id"]: s for s in out}


def one(body, **kw):
    """The one situation `S` of a file with no heroFile, whose situation is `body`."""
    return ok({"a.yaml": "situations:\n  - id: S\n" + body}, **kw)["S"]


def errors_of(body):
    _, errors = run({"a.yaml": "situations:\n  - id: S\n" + body})
    return [e.message for e in errors]


class PendingTests(unittest.TestCase):
    def test_the_brief_fixture(self):
        s = ok({"main.yaml": MAIN})
        self.assertEqual(s["1.2"]["pending"], ["SA_1.r1"])
        self.assertEqual(s["1.10"]["pending"], [])

    def test_a_line_from_a_clause_on_an_open_ruling_is_pending_even_unowned(self):
        s = one("    expect: { at: { lines: [{ value: 2, from: SA_2.X1 }] } }\n")
        self.assertEqual(s["pending"], ["SA_2.r2"])

    def test_an_unowned_rule_on_the_path_is_not_pending(self):
        s = one("    expect: { at: { total: 0 } }\n")
        self.assertEqual(s["pending"], [])

    def test_a_ruling_cited_by_a_line_is_pending(self):
        s = one("    expect: { aw: { lines: [{ value: 1, from: SA_1.T2, ruling: r1 }] } }\n")
        self.assertEqual(s["pending"], ["SA_1.r1"])
        self.assertEqual(s["expect"][0]["lines"][0]["ruling"], ["SA_1.r1"])

    def test_a_ruling_cited_by_not_applied_is_pending(self):
        s = one("    expect:\n"
                "      notApplied: [{ rule: SA_2, reason: notOwned, ruling: r2 }]\n")
        self.assertEqual(s["pending"], ["SA_2.r2"])
        self.assertEqual(s["expectSituation"]["notApplied"],
                         [{"rule": "SA_2", "reason": "notOwned", "ruling": ["SA_2.r2"]}])

    def test_a_ruling_cited_by_a_query_not_applied_is_pending(self):
        s = one("    expect: { aw: { notApplied: [{ rule: SA_2, clause: X1, reason: notOwned, ruling: r2 }] } }\n")
        self.assertEqual(s["pending"], ["SA_2.r2"])

    def test_a_core_rule_on_the_path_is_pending_without_being_owned(self):
        s = one("    expect: { pa: { total: -1 } }\n")
        self.assertEqual(s["pending"], ["CORE.k1"])

    # Ruling R30: an open ruling on a `"*"` entry counts only for a situation that expects
    # situation-level results or has `sequence` / `rolls`; query expectations count their
    # queried targets' entries only.
    def test_star_counts_for_situation_level_results(self):
        for key in ("offered", "notOffered", "questions", "texts", "events", "fp", "qs", "spent",
                    "success", "result", "legal"):
            s = one(f"    hero: {{ abilities: {{ SA_3: 1 }} }}\n    expect: {{ {key}: [] }}\n")
            self.assertEqual(s["pending"], ["SA_3.s3"], key)

    def test_star_counts_for_a_sequence_or_rolls(self):
        s = one("    hero: { abilities: { SA_3: 1 } }\n    sequence: [{ step: x }]\n")
        self.assertEqual(s["pending"], ["SA_3.s3"])
        s = one("    hero: { abilities: { SA_3: 1 } }\n    rolls: [12]\n    expect: { aw: { total: 0 } }\n")
        self.assertEqual(s["pending"], ["SA_3.s3"])

    def test_star_does_not_count_for_query_expectations_only(self):
        s = one("    hero: { abilities: { SA_3: 1 } }\n    expect: { aw: { total: 0 } }\n")
        self.assertEqual(s["pending"], [])

    def test_star_does_not_count_for_a_situation_level_not_applied_only(self):
        s = one("    hero: { abilities: { SA_3: 1 } }\n"
                "    expect: { notApplied: [{ rule: SA_2, reason: notOwned }] }\n")
        self.assertEqual(s["pending"], [])

    def test_a_cited_star_ruling_still_counts_for_a_query(self):
        s = one("    hero: { abilities: { SA_3: 1 } }\n"
                "    expect: { aw: { lines: [{ value: 0, ruling: SA_3.s3 }] } }\n")
        self.assertEqual(s["pending"], ["SA_3.s3"])

    def test_owned_through_the_query_context(self):
        s = one("    hero: { abilities: { SA_1: 1 } }\n    expect: { \"at(with: Rabenschnabel)\": { total: 1 } }\n")
        self.assertEqual(s["pending"], ["SA_1.r1"])
        self.assertEqual(s["expect"][0]["query"], "at(with: Rabenschnabel)")

    def test_a_decided_ruling_is_not_pending(self):
        s = one("    hero: { abilities: { SA_4: 1 } }\n"
                "    expect: { at: { lines: [{ value: 1, from: SA_4.D1, ruling: d1 }] } }\n")
        self.assertEqual(s["pending"], [])

    def test_rulings_cited_inside_a_sequence_are_pending(self):
        s = one("    sequence:\n"
                "      - expect: { aw: { lines: [{ value: 1, from: SA_1.T2, ruling: r1 }] } }\n"
                "      - expect: { notApplied: [{ rule: SA_2, reason: x, ruling: r2 }] }\n"
                "      - expect: { at: { lines: [{ value: 9, from: CORE.K1 }] } }\n")
        self.assertEqual(s["pending"], ["CORE.k1", "SA_1.r1", "SA_2.r2"])

    def test_pending_is_sorted_and_unique(self):
        s = one("    hero: { abilities: { SA_1: 1, SA_3: 1 } }\n"
                "    expect:\n"
                "      at: { lines: [{ value: 1, from: SA_1.T1, ruling: r1 }, { value: 2, from: SA_2.X1 }] }\n"
                "      pa: { total: 0 }\n"
                "      texts: [{ text: hallo }]\n")
        self.assertEqual(s["pending"], ["CORE.k1", "SA_1.r1", "SA_2.r2", "SA_3.s3"])


HERO_MERGE = """\
heroFile: ../hero.json
hero:
  abilities: { SA_1: 1 }
  attributes: { KO: 15 }
  values: { "at(with:Rabenschnabel)": 16, aw: 7 }
situations:
  - id: "1"
    hero:
      advantages: { ADV_3: true }
      disadvantages: { DISADV_4: { sid: 4 } }
      talents: { TAL_2: 3 }
      techniques: { CT_5: 12 }
      values: { aw: 8 }
      states: { liegend: 1 }
      conditions: { COND_1: 2 }
  - id: "2"
"""


class HeroTests(unittest.TestCase):
    def setUp(self):
        self.s = ok({"a.yaml": HERO_MERGE})

    def facts(self, sid):
        return {f["name"]: (f["value"], f["owner"]) for f in self.s[sid]["facts"]}

    def test_the_file_hero_replaces_the_hero_files_maps_whole(self):
        self.assertEqual(self.s["2"]["owned"], {"SA_1": {"level": 1}, "ADV_1": {"level": 2},
                                                "DISADV_2": {"level": 1, "option": 3}})

    def test_the_situation_hero_replaces_maps_whole(self):
        self.assertEqual(self.s["1"]["owned"], {"SA_1": {"level": 1}, "ADV_3": {"level": 1},
                                                "DISADV_4": {"level": 1, "option": 4},
                                                "liegend": {"level": 1}, "COND_1": {"level": 2}})

    def test_values_merge_key_by_key_as_canonical_queries(self):
        self.assertEqual(self.s["2"]["base"], {"at(with: Rabenschnabel)": 16, "aw": 7})
        self.assertEqual(self.s["1"]["base"], {"at(with: Rabenschnabel)": 16, "aw": 8})

    def test_attributes_techniques_talents_merge_key_by_key(self):
        f2, f1 = self.facts("2"), self.facts("1")
        self.assertEqual(f2["attr.MU"], (12, "sheet"))
        self.assertEqual(f2["attr.KO"], (15, "sheet"))
        self.assertEqual(f2["ktw.CT_5"], (10, "sheet"))
        self.assertEqual(f1["ktw.CT_5"], (12, "sheet"))
        self.assertEqual(f1["fw.TAL_1"], (5, "sheet"))
        self.assertEqual(f1["fw.TAL_2"], (3, "sheet"))
        self.assertNotIn("fw.TAL_2", f2)

    def test_a_second_select_option_is_option2(self):
        # SA_9 (Group 6): the talent (`sid`) and its Anwendungsgebiet (`sid2`).
        s = one("    hero: { abilities: { SA_1: { sid: TAL_10, sid2: 2 } } }\n")
        self.assertEqual(s["owned"], {"SA_1": {"level": 1, "option": "TAL_10", "option2": 2}})

    def test_spells_are_fw_facts(self):
        # probe-magie (Group 7): a spell's FW is the sheet fact `fw.SPELL_…`, as a talent's.
        s = one("    hero: { spells: { SPELL_21: 9 }, talents: { TAL_8: 6 } }\n")
        self.assertEqual(s["facts"], [{"name": "fw.SPELL_21", "value": 9, "owner": "sheet"},
                                      {"name": "fw.TAL_8", "value": 6, "owner": "sheet"}])

    def test_without_hero_file(self):
        s = one("    hero: { abilities: { SA_1: 3 }, attributes: { MU: 11 } }\n")
        self.assertEqual(s["owned"], {"SA_1": {"level": 3}})
        self.assertEqual(s["facts"], [{"name": "attr.MU", "value": 11, "owner": "sheet"}])


class SectionTests(unittest.TestCase):
    def test_each_section_states_facts_of_its_owner(self):
        s = one("    rulesets: [focus]\n"
                "    loadout: { weapon: Rabenschnabel, shield.size: large }\n"
                "    choose: { action.attack: main, choice.formation: true }\n"
                "    gm: { gmFact.behind: true }\n"
                "    opponent: { has: [SA_7] }\n"
                "    ally: { has: [SA_8] }\n"
                "    round: { doubleAttack: true }\n"
                "    rolls: { hit.zone: head }\n")
        self.assertEqual(s["facts"], [
            {"name": "action.attack", "value": "main", "owner": "player"},
            {"name": "ally.has", "value": ["SA_8"], "owner": "player"},
            {"name": "choice.formation", "value": True, "owner": "player"},
            {"name": "gmFact.behind", "value": True, "owner": "gm"},
            {"name": "hit.zone", "value": "head", "owner": "roll"},
            {"name": "loadout.shield.size", "value": "large", "owner": "loadout"},
            {"name": "loadout.weapon", "value": "Rabenschnabel", "owner": "loadout"},
            {"name": "opponent.has", "value": ["SA_7"], "owner": "gm"},
            {"name": "round.doubleAttack", "value": True, "owner": "round"},
            {"name": "rulesets", "value": ["focus"], "owner": "gm"},
        ])
        self.assertEqual(s["rolls"], [])

    def test_loadout_takes_a_full_loadout_fact_as_is(self):
        s = one("    loadout: { hero.mounted: true, loadout.shield: Großschild, weapon: Rabenschnabel }\n")
        self.assertEqual(s["facts"], [
            {"name": "hero.mounted", "value": True, "owner": "loadout"},
            {"name": "loadout.shield", "value": "Großschild", "owner": "loadout"},
            {"name": "loadout.weapon", "value": "Rabenschnabel", "owner": "loadout"},
        ])
        self.assertEqual(errors_of("    loadout: { round.parries: 1 }\n"), ["unknown fact loadout.round.parries"])

    def test_file_rulesets_are_overridden_by_the_situation(self):
        s = ok({"a.yaml": "rulesets: [a]\nsituations:\n  - id: '1'\n  - id: '2'\n    rulesets: [b]\n"})
        self.assertEqual(s["1"]["facts"], [{"name": "rulesets", "value": ["a"], "owner": "gm"}])
        self.assertEqual(s["2"]["facts"], [{"name": "rulesets", "value": ["b"], "owner": "gm"}])

    def test_rolls_as_dice_and_sequence_pass_through(self):
        s = one("    rolls: [15, 16, 10]\n"
                "    sequence:\n      - expect: { ini: { result: 17 } }\n")
        self.assertEqual(s["rolls"], [15, 16, 10])
        self.assertEqual(s["sequence"], [{"expect": {"ini": {"result": 17}}}])

    def test_the_compiled_shape(self):
        s = one("    name: Eins\n"
                "    appToday: same\n"
                "    note: n\n"
                "    expect:\n"
                "      at: { total: 1, result: 15, legal: true }\n"
                "      offered: [{ choice: formation, from: SA_1.T1 }]\n"
                "      fp: 3\n")
        self.assertEqual(s, {
            "id": "S", "file": "a.yaml", "name": "Eins", "owned": {}, "facts": [], "base": {},
            "rolls": [], "sequence": [],
            "expect": [{"query": "at", "total": 1, "result": 15, "legal": True}],
            "expectSituation": {"offered": [{"choice": "formation", "from": "SA_1.T1"}], "fp": 3},
            "pending": [],
        })


class ErrorTests(unittest.TestCase):
    def test_fact_in_the_wrong_section(self):
        self.assertEqual(errors_of("    choose: { gmFact.behind: true }\n"),
                         ["fact gmFact.behind is owned by gm, not choose"])

    def test_prefixed_section_names_the_prefixed_fact(self):
        self.assertEqual(errors_of("    ally: { dodges: 1 }\n"), ["unknown fact ally.dodges"])
        self.assertEqual(errors_of("    round: { number: 2 }\n    opponent: { rs: 4 }\n"), [])

    def test_round_fact_stated_by_gm(self):
        self.assertEqual(errors_of("    gm: { round.parries: 1 }\n"),
                         ["fact round.parries is owned by round, not gm"])

    def test_unknown_fact(self):
        self.assertEqual(errors_of("    choose: { flavour: sweet }\n"), ["unknown fact flavour"])

    def test_unknown_expect_key(self):
        self.assertEqual(errors_of("    expect: { attack_main: { total: 1 } }\n"),
                         ["unknown expect key attack_main"])

    def test_unknown_clause_in_expect(self):
        self.assertEqual(errors_of("    expect: { at: { lines: [{ value: 1, from: SA_1.T9 }] } }\n"),
                         ["unknown clause in expect SA_1.T9"])
        self.assertEqual(errors_of("    expect: { at: { lines: [{ value: 1, from: NOPE.T1 }] } }\n"),
                         ["unknown clause in expect NOPE.T1"])

    def test_unknown_rule_in_not_applied(self):
        self.assertEqual(errors_of("    expect: { notApplied: [{ rule: NOPE, reason: notOwned }] }\n"),
                         ["unknown rule in expect NOPE"])

    def test_unknown_ruling_in_expect(self):
        self.assertEqual(errors_of("    expect: { at: { lines: [{ value: 1, from: SA_1.T1, ruling: nope }] } }\n"),
                         ["unknown ruling in expect nope"])

    def test_group_1_additions(self):
        # A query's base value, the level a leveled rule acts at, and the Group 1 loadout facts.
        self.assertEqual(errors_of(
            "    loadout: { armour: Platte, armour.belastung: 3, armour.extraPenalty: 0, other: Linkhand }\n"
            "    expect:\n"
            "      at: { result: 16, base: { value: 16, from: SA_1.T1 } }\n"
            '      "level(rule: SA_1)": { result: 1 }\n'), [])

    def test_group_2_additions(self):
        # The Group 2 facts a situation states, and the natural GS as a base value.
        self.assertEqual(errors_of(
            "    hero: { values: { gs: 14, gsNatural: 8 } }\n"
            "    loadout: { other: weapon, other.technique: CT_3, twoHanded: false, shield.structurePoints: 30 }\n"
            "    round: { phase: start, defendedThisAttack: false }\n"
            "    choose: { action.runUp: 4, choice.finte: 2 }\n"), [])

    def test_group_3_additions(self):
        # A mount's profile owned as a creature, its values as bases, the gait and a replaced
        # line's value before the replacement (`was`).
        self.assertEqual(errors_of(
            "    hero: { creatures: { svellttaler-kaltblut: true }, values: { mount.gs: 12, mount.iniBase: 14 } }\n"
            "    loadout: { hero.mounted: true }\n"
            "    choose: { choice.order: niederreiten, action.gait: galopp, action.gaitChange: false }\n"
            "    expect: { at: { lines: [{ value: -2, was: -4, from: SA_1.T1 }] } }\n"), [])
        s = one("    hero: { creatures: { svellttaler-kaltblut: true } }\n")
        self.assertEqual(s["owned"]["svellttaler-kaltblut"], {"level": 1})

    def test_group_4_additions(self):
        # The armour worn per zone, the RS of a zone and the RS-factor score as queries, the hit's
        # side and the hand the weapon is in (trefferzonen, trefferzonen-ruestungsschutz).
        self.assertEqual(errors_of(
            "    loadout: { armourPiece.torso: Kettenrüstung, armourPiece.armLinks: Lederrüstung, weaponHand: rechts }\n"
            "    rolls: { hit.zone: arme, hit.side: rechts }\n"
            "    expect:\n"
            '      "rs(zone: armLinks)": { result: 3 }\n'
            "      armourScore: { result: 26 }\n"), [])

    def test_group_8_additions(self):
        # Item state by instance in the loadout section (`item.<instance>.loaded`, kept as a full
        # name), the weapon's instance and Ladezeit, the player's movement and melee, the band and
        # sight as GM facts, and the query `item.ladezeit` (probe-fernkampf).
        s = one("    loadout: { weapon: Kurzbogen, weapon.instance: kurzbogen1, weapon.ladezeit: 1,"
                " item.kurzbogen1.loaded: false, quiver: true }\n"
                "    choose: { hero.lastMovement: geht, hero.inMelee: false }\n"
                "    gm: { target.rangeBand: weit, gmFact.sicht: 2 }\n"
                "    expect:\n"
                "      item.ladezeit: { result: 1 }\n"
                '      "fk(with: Kurzbogen)": { lines: [{ kind: capped }] }\n')
        names = {f["name"]: f["owner"] for f in s["facts"]}
        self.assertEqual(names["item.kurzbogen1.loaded"], "loadout")
        self.assertEqual(names["loadout.weapon.instance"], "loadout")
        self.assertEqual(names["loadout.quiver"], "loadout")
        self.assertEqual(names["hero.lastMovement"], "player")
        self.assertEqual(names["target.rangeBand"], "gm")
        self.assertEqual([q["query"] for q in s["expect"]], ["item.ladezeit", "fk(with: Kurzbogen)"])

    def test_unknown_keys(self):
        self.assertEqual(errors_of("    colour: red\n"), ["unknown key colour"])
        self.assertEqual(errors_of("    expect: { at: { totl: 1 } }\n"), ["unknown key totl"])
        self.assertEqual(errors_of("    expect: { at: { lines: [{ value: 1, form: SA_1.T1 }] } }\n"),
                         ["unknown key form"])
        self.assertEqual(errors_of("    hero: { armour: [Platte] }\n"), ["unknown hero key armour"])

    def test_owned_value_forms(self):
        self.assertEqual(errors_of("    hero: { advantages: [ADV_5] }\n"),
                         ["wrong type for hero.advantages"])
        self.assertEqual(errors_of("    hero: { advantages: { ADV_5: many } }\n"),
                         ["wrong type for hero.advantages.ADV_5"])

    def test_unknown_values_query(self):
        self.assertEqual(errors_of("    hero: { values: { atk: 3 } }\n"), ["unknown target atk"])

    def test_missing_id_and_duplicates(self):
        _, errors = run({"a.yaml": "situations:\n  - name: x\n  - id: '1'\n",
                         "b.yaml": "situations:\n  - id: '1'\n"})
        self.assertEqual([e.message for e in errors], ["missing key id", "duplicate situation id 1"])

    def test_missing_hero_file(self):
        _, errors = run({"a.yaml": "heroFile: nope.json\nsituations: []\n"})
        self.assertEqual([e.message for e in errors], ["heroFile not found: nope.json"])

    def test_errors_carry_file_and_line(self):
        _, errors = run({"a.yaml": "situations:\n  - id: S\n    choose: { gmFact.behind: true }\n"})
        self.assertTrue(errors[0].file.endswith("a.yaml"))
        self.assertEqual(errors[0].line, 3)


class OrderTests(unittest.TestCase):
    def test_sorted_by_file_then_numeric_id(self):
        out, errors = run({"b.yaml": "situations:\n  - id: '1.1'\n",
                           "a.yaml": "situations:\n  - id: '2.10'\n  - id: '2.9'\n  - id: '10.1'\n"})
        self.assertEqual(errors, [])
        self.assertEqual([(s["file"], s["id"]) for s in out],
                         [("a.yaml", "2.9"), ("a.yaml", "2.10"), ("a.yaml", "10.1"), ("b.yaml", "1.1")])


class CommandTests(unittest.TestCase):
    def run_main(self, argv):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = main(argv)
        return code, buf.getvalue()

    def test_build_writes_situations_json(self):
        d = tree({"main.yaml": MAIN})
        out = d / "build"
        code, text = self.run_main(["build", "--rules", str(d / "rules"),
                                    "--situations", str(d / "situations"), "--out", str(out)])
        self.assertEqual(code, 0, text)
        self.assertEqual(text.splitlines(), [f"wrote {out / 'rules.json'} (5 rules)",
                                             f"wrote {out / 'situations.json'} (2 situations, 1 pending)"])
        obj = json.loads((out / "situations.json").read_text())
        self.assertEqual(obj["vocabularyVersion"], vocab.load().version)
        self.assertEqual([(s["id"], s["pending"]) for s in obj["situations"]],
                         [("1.2", ["SA_1.r1"]), ("1.10", [])])

    def test_situations_default_to_the_sibling_of_the_rules(self):
        d = tree({"main.yaml": MAIN})
        code, text = self.run_main(["check", "--rules", str(d / "rules")])
        self.assertEqual(code, 0, text)
        self.assertTrue(text.endswith(", 2 situations (1 pending)\n"), text)

    def test_check_reports_situation_errors(self):
        d = tree({"a.yaml": "situations:\n  - id: S\n    choose: { gmFact.behind: true }\n"})
        code, text = self.run_main(["check", "--rules", str(d / "rules"),
                                    "--situations", str(d / "situations")])
        self.assertEqual(code, 1)
        self.assertEqual(text.splitlines(),
                         [f"{d / 'situations' / 'a.yaml'}:3: fact gmFact.behind is owned by gm, not choose",
                          "1 errors"])

    def test_only_filters_situation_errors(self):
        d = tree({"a.yaml": "situations:\n  - id: S\n    choose: { gmFact.behind: true }\n",
                  "b.yaml": "situations:\n  - id: T\n"})
        code, text = self.run_main(["check", "--rules", str(d / "rules"),
                                    "--situations", str(d / "situations"), "--only", "b.yaml"])
        self.assertEqual(code, 0, text)
        code, text = self.run_main(["check", "--rules", str(d / "rules"),
                                    "--situations", str(d / "situations"), "--only", "a.yaml"])
        self.assertEqual(code, 1, text)

    def test_build_fails_on_situation_errors(self):
        d = tree({"a.yaml": "situations:\n  - id: S\n    expect: { nope: 1 }\n"})
        out = d / "build"
        code, text = self.run_main(["build", "--rules", str(d / "rules"),
                                    "--situations", str(d / "situations"), "--out", str(out)])
        self.assertEqual(code, 1)
        self.assertIn("unknown expect key nope", text)
        self.assertFalse((out / "situations.json").exists())


if __name__ == "__main__":
    unittest.main()
