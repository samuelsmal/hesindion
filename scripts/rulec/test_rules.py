import contextlib
import io
import tempfile
import textwrap
import unittest
from pathlib import Path

from rulec import rules, vocab
from rulec.__main__ import main

VALID = """\
id: SA_1
name: Test
kind: specialAbility
source: { url: x, book: y, page: 1, checked: 2026-09-24, hash: null }
reviewed: null
levels: 3
clauses:
  - id: T1
    text: "Eins"
    effects:
      - add: { to: at, value: 2 }
        when: { hero.mounted: true }
  - id: T2
    text: "Zwei"
    none: purchase cost
rulings: []
"""

# A second rule without `levels`, for the cross-rule checks.
SA_2 = """\
id: SA_2
name: Zwei
kind: specialAbility
source: { url: x, book: y, page: 2, checked: 2026-09-24, hash: null }
reviewed: null
clauses:
  - id: Z1
    text: "Z"
    effects:
      - add: { to: pa, value: 1 }
rulings:
  - id: other-ruling
    question: q
    answer: null
"""


def write(text, extra=None, shared="[]\n"):
    d = Path(tempfile.mkdtemp())
    (d / "abilities").mkdir()
    (d / "abilities" / "SA_1.yaml").write_text(text)
    (d / "rulings.yaml").write_text(shared)
    for name, body in (extra or {}).items():
        (d / name).write_text(body)
    return d


def check(text, extra=None, shared="[]\n"):
    return rules.check(write(text, extra, shared), vocab.load())  # -> (normalized rules, [RulecError])


EFFECT = "      - add: { to: at, value: 2 }"


class RuleValidationTests(unittest.TestCase):
    def one_error(self, errors, prefix, line):
        self.assertEqual(len(errors), 1, [str(e) for e in errors])
        self.assertTrue(errors[0].message.startswith(prefix), errors[0].message)
        self.assertEqual(errors[0].line, line)
        self.assertTrue(errors[0].file.endswith("SA_1.yaml"), errors[0].file)

    def test_a_valid_file_has_no_errors(self):
        book, errors = check(VALID)
        self.assertEqual(errors, [])
        eff = book["SA_1"]["clauses"][0]["effects"][0]
        self.assertEqual(eff["verb"], "add")
        self.assertEqual(eff["payload"], {"to": [{"name": "at"}], "value": {"number": 2}})
        self.assertEqual(eff["phase"], "add")
        self.assertEqual(eff["origin"], {"rule": "SA_1", "clause": "T1", "index": 0})
        self.assertEqual(eff["when"], {"fact": "hero.mounted", "is": True})
        self.assertEqual(eff["ruling"], [])
        self.assertIsNone(eff["because"])
        self.assertEqual(book["SA_1"]["clauses"][1]["none"], "purchase cost")

    # --- one error each -----------------------------------------------------------------------
    def test_unknown_verb(self):
        _, errors = check(VALID.replace(EFFECT, "      - raise: { to: at, by: 2 }"))
        self.assertEqual([e.message.split(":")[0] for e in errors], ["unknown verb raise"])
        self.assertEqual(errors[0].line, 11)

    def test_unknown_key_on_a_rule(self):
        _, errors = check(VALID.replace("name: Test\n", "name: Test\ncolour: red\n"))
        self.one_error(errors, "unknown key colour", 3)

    def test_unknown_key_on_a_clause(self):
        _, errors = check(VALID.replace('    text: "Eins"\n', '    text: "Eins"\n    colour: red\n'))
        self.one_error(errors, "unknown key colour", 10)

    def test_unknown_key_on_an_effect(self):
        _, errors = check(VALID.replace("        when: { hero.mounted: true }\n",
                                        "        when: { hero.mounted: true }\n        colour: red\n"))
        self.one_error(errors, "unknown key colour", 13)

    def test_unknown_target(self):
        _, errors = check(VALID.replace(EFFECT, "      - add: { to: nope, value: 2 }"))
        self.one_error(errors, "unknown target", 11)

    def test_unknown_fact(self):
        _, errors = check(VALID.replace("hero.mounted: true", "hero.flying: true"))
        self.one_error(errors, "unknown fact", 12)

    def test_clause_with_no_body(self):
        _, errors = check(VALID.replace("    none: purchase cost\n", ""))
        self.one_error(errors, "clause needs exactly one of effects, unencoded, none", 13)

    def test_clause_with_two_bodies(self):
        _, errors = check(VALID.replace("    none: purchase cost", "    none: x\n    unencoded: y"))
        self.one_error(errors, "clause needs exactly one of effects, unencoded, none", 16)

    def test_unknown_ruling(self):
        _, errors = check(VALID.replace("        when: { hero.mounted: true }\n",
                                        "        when: { hero.mounted: true }\n        ruling: nope\n"))
        self.one_error(errors, "unknown ruling nope", 13)

    def test_unknown_clause_in_via(self):
        _, errors = check(VALID.replace("        when: { hero.mounted: true }\n",
                                        "        when: { hero.mounted: true }\n"
                                        "      - suppress: { line: { line: SA_1.T9 } }\n"))
        self.one_error(errors, "unknown clause in via", 13)

    def test_value_outside_the_four_forms(self):
        _, errors = check(VALID.replace(EFFECT, '      - add: { to: at, value: "2 + x" }'))
        self.one_error(errors, "value outside the four forms", 11)

    def test_missing_field(self):
        _, errors = check(VALID.replace(EFFECT, "      - add: { to: at }"))
        self.one_error(errors, "missing field value", 11)

    def test_wrong_type_for_field(self):
        _, errors = check(VALID.replace(EFFECT, "      - useLevel: { rule: 3, as: 1 }"))
        self.one_error(errors, "wrong type for field rule", 11)

    def test_use_level_names_a_rule_without_levels(self):
        _, errors = check(VALID.replace(EFFECT, "      - useLevel: { rule: SA_2, as: 1 }"),
                          extra={"abilities/SA_2.yaml": SA_2})
        self.one_error(errors, "useLevel names a rule without levels", 11)

    def test_use_level_needs_exactly_one_of_as_lower_by(self):
        _, errors = check(VALID.replace(EFFECT, "      - useLevel: { rule: SA_1, as: 1, lowerBy: 1 }"))
        self.one_error(errors, "useLevel needs exactly one of as, lowerBy", 11)
        _, errors = check(VALID.replace(EFFECT, "      - useLevel: { rule: SA_1 }"))
        self.one_error(errors, "useLevel needs exactly one of as, lowerBy", 11)

    def test_replace_names_a_clause_without_effects(self):
        _, errors = check(VALID.replace(EFFECT, "      - replace: { line: { line: SA_1.T2 }, with: 3 }"))
        self.one_error(errors, "replace names a clause without effects", 11)

    def test_two_clauses_without_an_id_report_missing_key_twice(self):
        _, errors = check(VALID.replace("  - id: T1\n    text:", "  - text:")
                          .replace("  - id: T2\n    text:", "  - text:"))
        self.assertEqual([(e.message, e.line) for e in errors],
                         [("missing key id", 8), ("missing key id", 12)])

    def test_unknown_phase(self):
        _, errors = check(VALID.replace("        when: { hero.mounted: true }\n",
                                        "        when: { hero.mounted: true }\n        phase: late\n"))
        self.one_error(errors, "unknown phase late", 13)

    def test_errors_are_collected_not_stopped_at_the_first(self):
        text = (VALID.replace(EFFECT, "      - raise: { to: at, by: 2 }")
                .replace("hero.mounted: true", "hero.flying: true")
                .replace("name: Test\n", "name: Test\ncolour: red\n"))
        _, errors = check(text)
        self.assertEqual(len(errors), 2, [str(e) for e in errors])  # raise's `when` never parsed
        self.assertEqual({e.message.split(" ")[1] for e in errors}, {"key", "verb"})

    def test_unknown_key_on_a_ruling_in_a_rule_file(self):
        text = VALID.replace("rulings: []\n", textwrap.dedent("""\
            rulings:
              - id: r
                question: q
                answer: null
                source: somewhere
            """))
        _, errors = check(text)
        self.one_error(errors, "unknown key source", 20)

    def test_unknown_key_on_a_shared_ruling(self):
        shared = "- id: round-up\n  question: q\n  answer: null\n  colour: red\n"
        _, errors = check(VALID, shared=shared)
        self.assertEqual([(e.message, e.line) for e in errors], [("unknown key colour", 4)])
        self.assertTrue(errors[0].file.endswith("rulings.yaml"), errors[0].file)

    def test_a_ruling_may_name_what_to_see(self):
        shared = "- id: round-up\n  question: q\n  answer: yes\n  see: [docs/adr/0006.md]\n"
        _, errors = check(VALID, shared=shared)
        self.assertEqual(errors, [])

    # --- vocabulary added by the Group 1 hand migration (plan Task 8) -------------------------
    def test_group_1_facts_have_their_owners(self):
        v = vocab.load()
        expected = {"ktw.current": "loadout", "technique.leit": "loadout", "species.le": "sheet",
                    "hero.purchased.le": "sheet", "belastung.source": "derived",
                    "check.kind": "player", "check.hinderedByBelastung": "derived",
                    "loadout.armour.belastung": "loadout", "loadout.armour.extraPenalty": "loadout",
                    "loadout.other": "loadout", "loadout.other.paMod": "loadout"}
        self.assertEqual({f: v.fact_owner(f) for f in expected}, expected)

    def test_a_derive_over_the_group_1_facts(self):
        book, errors = check(VALID.replace(EFFECT + "\n        when: { hero.mounted: true }\n", textwrap.indent(
            textwrap.dedent("""\
                - derive:
                    to: pa
                    sum:
                      - { of: ktw.current, per: 2, round: up }
                      - { of: technique.leit, above: 8, per: 3, round: down }
                - derive: { to: leMax, sum: [{ of: species.le }, { of: attr.KO, times: 2 }] }
                - derive: { to: "level(rule: SA_1)", sum: [{ of: loadout.armour.belastung }] }
                - useLevel: { rule: SA_1, lowerBy: level, min: 0 }
                  when: { belastung.source: armour }
                """), "      ")))
        self.assertEqual(errors, [])
        effects = book["SA_1"]["clauses"][0]["effects"]
        self.assertEqual(effects[2]["payload"]["to"], {"name": "level", "rule": "SA_1"})
        self.assertEqual(effects[3]["when"], {"fact": "belastung.source", "is": "armour"})

    def test_a_suppress_by_rule_kind(self):
        book, errors = check(VALID.replace(EFFECT, "      - suppress: { line: { ruleKind: condition } }"))
        self.assertEqual(errors, [])
        self.assertEqual(book["SA_1"]["clauses"][0]["effects"][0]["payload"]["line"],
                         {"kind": "ruleKind", "ids": ["condition"]})

    def test_an_offer_default_may_be_a_bool(self):
        book, errors = check(VALID.replace(EFFECT, "      - offer: { choice: belastungZaehlt, default: false }"))
        self.assertEqual(errors, [])
        self.assertIs(book["SA_1"]["clauses"][0]["effects"][0]["payload"]["default"], False)

    # --- vocabulary added by the Group 2 hand migration (plan Task 9) -------------------------
    def test_group_2_facts_have_their_owners(self):
        v = vocab.load()
        expected = {"round.defendedThisAttack": "round", "round.phase": "round",
                    "query.result": "derived", "hero.gs": "derived", "action.runUp": "player",
                    "loadout.other.technique": "loadout", "loadout.twoHanded": "loadout",
                    "loadout.shield.structurePoints": "loadout"}
        self.assertEqual({f: v.fact_owner(f) for f in expected}, expected)
        self.assertTrue(v.is_target("gsNatural"))
        self.assertIn("destroyed", v.raw["itemFields"])

    def test_the_group_2_encodings(self):
        # mehrfache-verteidigung MV1/MV3, SA_62 ST1/ST2, SA_59 SS3, beidhaendiger-kampf ZW1.
        book, errors = check(VALID.replace(EFFECT + "\n        when: { hero.mounted: true }\n", textwrap.indent(
            textwrap.dedent("""\
                - when: { round.defendedThisAttack: true }
                  forbid: { what: { defence: [pa, aw] } }
                - when: { query.result: { atMost: 0 } }
                  forbid: { what: { defence: [pa, aw] } }
                - require: { that: { action.runUp: { atLeast: 4 }, hero.gs: { atLeast: 4 } }, for: { choice: sturm } }
                - add: { to: tp, value: { of: [gs, 4], per: 2, round: up, max: [10, gsNatural] } }
                - when: { round.phase: start, loadout.shield.structurePoints: { atMost: 0 } }
                  item: { instance: { loadout: shield }, change: { destroyed: true } }
                - when: { loadout.twoHanded: true, loadout.other.technique: CT_6 }
                  forbid: { what: { loadout: other } }
                """), "      ")))
        self.assertEqual(errors, [])
        effects = book["SA_1"]["clauses"][0]["effects"]
        self.assertEqual(effects[1]["when"], {"fact": "query.result", "atMost": 0})
        self.assertEqual(effects[3]["payload"]["value"]["proportion"]["max"],
                         {"each": [{"number": 10}, {"target": {"name": "gsNatural"}}]})
        self.assertEqual(effects[4]["payload"]["change"], {"destroyed": True})

    def test_group_3_vocabulary(self):
        v = vocab.load()
        expected = {"reach.gap": "derived", "query.target": "derived", "action.gait": "player",
                    "action.gaitChange": "player"}
        self.assertEqual({f: v.fact_owner(f) for f in expected}, expected)
        self.assertTrue(v.is_target("carryingCapacity"))
        self.assertTrue(v.is_target("mount.carryingCapacity"))
        self.assertIn("ridden", v.raw["itemFields"])
        self.assertIn("was", v.raw["lineKeys"])
        self.assertTrue({"actions", "freeActions"} <= set(v.raw["pools"]))

    def test_the_group_3_encodings(self):
        # reichweite RW3 / SA_172 U1, reiterkampf RK6, RK7, RK9, RK12, svellttaler-kaltblut SK12.
        book, errors = check(VALID.replace(EFFECT + "\n        when: { hero.mounted: true }\n", textwrap.indent(
            textwrap.dedent("""\
                - when: { reach.gap: { atLeast: 1 } }
                  add: { to: at, value: { of: reach.gap, times: -2 } }
                - when: { hero.mounted: true, query.target: [at, pa, aw, fk] }
                  add: { to: aw, value: -2 }
                - when: { choice.jumpOff: true }
                  item: { instance: { loadout: mount }, change: { ridden: false } }
                - when: { action.gaitChange: true, action.gait: galopp }
                  cost: { pool: freeActions, amount: 1 }
                - offer: { choice: order, options: [flucht], costs: [{ cost: { pool: actions, amount: 1 } }] }
                - set: { to: mount.carryingCapacity, value: 210 }
                """), "      ")))
        self.assertEqual(errors, [])
        effects = book["SA_1"]["clauses"][0]["effects"]
        self.assertEqual(effects[0]["payload"]["value"]["proportion"]["of"], {"fact": "reach.gap"})
        self.assertEqual(effects[1]["when"]["all"][1], {"fact": "query.target", "in": ["at", "pa", "aw", "fk"]})
        self.assertEqual(effects[2]["payload"]["change"], {"ridden": False})
        self.assertEqual(effects[4]["payload"]["costs"][0]["payload"]["pool"], "actions")
        self.assertEqual(effects[5]["payload"]["to"], [{"name": "mount.carryingCapacity"}])

    def test_group_4_vocabulary(self):
        v = vocab.load()
        expected = {"hit.overWundschwelle": "derived", "hit.side": "roll", "hit.heldInHand": "derived",
                    "hit.zoneRs": "derived", "hero.leCurrent": "derived", "loadout.weaponHand": "loadout",
                    "loadout.weapon.schadensschwelle": "loadout", "loadout.weapon.leit": "loadout",
                    "loadout.weapon.ownLeit": "loadout", "loadout.armourPiece.kopf": "loadout",
                    "hit.mountSp": "roll"}
        self.assertEqual({f: v.fact_owner(f) for f in expected}, expected)
        self.assertTrue(v.is_target("armourScore"))
        self.assertIn("held", v.raw["itemFields"])

    GAIN_BY_TABLE = textwrap.dedent("""\
        - provide: { name: SA_1.effect, value: { kopf: SA_2, beine: SA_2 } }
        - when: { hit.overWundschwelle: { atLeast: 1 } }
          check:
            of: { talent: TAL_8 }
            modifier: { of: hit.sp, per: wundschwelle, times: -1, round: down }
            onFailure:
              - gain: { rule: "table(SA_1.effect, hit.zone)" }
              - when: { hit.zone: arme, hit.heldInHand: weapon }
                item: { instance: { loadout: weapon }, change: { held: false } }
        """)

    def test_the_group_4_encodings(self):
        # trefferzonen TZ8/TZ11 (a `rule` field read from a provided table), schaden S1/S3,
        # trefferzonen-ruestungsschutz RS2/RS4.
        body = self.GAIN_BY_TABLE + textwrap.dedent("""\
            - derive: { to: sp, sum: [{ of: hit.tp }, { of: rs, times: -1 }] }
            - floor: { to: sp, min: 0 }
            - add: { to: tp, value: { of: technique.leit, above: loadout.weapon.schadensschwelle } }
            - set: { to: rs, value: { of: hit.zoneRs } }
            - derive: { to: armourScore, sum: [{ of: "rs(zone: kopf)" }, { of: "rs(zone: torso)", times: 5 }] }
            - when: { hero.leCurrent: { atMost: 0 } }
              tell: { to: player, text: "im Sterben" }
            - check: { of: { talent: TAL_6 }, modifier: { of: hit.mountSp, per: 5, times: -1, round: down } }
            - forbid: { what: { loadout: secondArmour } }
              because: eine Rüstung
            """)
        book, errors = check(VALID.replace(EFFECT + "\n        when: { hero.mounted: true }\n",
                                           textwrap.indent(body, "      ")), extra={"abilities/SA_2.yaml": SA_2})
        self.assertEqual(errors, [])
        effects = book["SA_1"]["clauses"][0]["effects"]
        fail = effects[1]["payload"]["onFailure"]
        self.assertEqual(fail[0]["payload"]["rule"], {"table": {"name": "SA_1.effect", "key": "hit.zone"}})
        self.assertEqual(fail[1]["payload"]["change"], {"held": False})
        self.assertEqual(effects[4]["payload"]["value"]["proportion"]["above"],
                         {"fact": "loadout.weapon.schadensschwelle"})

    def test_a_rule_table_must_be_provided_and_name_rules(self):
        body = self.GAIN_BY_TABLE.replace("name: SA_1.effect", "name: SA_1.other")
        _, errors = check(VALID.replace(EFFECT + "\n        when: { hero.mounted: true }\n",
                                        textwrap.indent(body, "      ")), extra={"abilities/SA_2.yaml": SA_2})
        self.assertEqual([e.message for e in errors], ["unknown table SA_1.effect"])
        body = self.GAIN_BY_TABLE.replace("beine: SA_2", "beine: NOPE")
        _, errors = check(VALID.replace(EFFECT + "\n        when: { hero.mounted: true }\n",
                                        textwrap.indent(body, "      ")), extra={"abilities/SA_2.yaml": SA_2})
        self.assertEqual([e.message for e in errors], ["unknown rule in table SA_1.effect: NOPE"])

    def test_group_5_vocabulary(self):
        v = vocab.load()
        expected = {"hero.conditionLevels": "derived", "hero.levelOf.COND_6": "derived"}
        self.assertEqual({f: v.fact_owner(f) for f in expected}, expected)
        self.assertIsNone(v.fact_owner("hero.levelOf."))                      # a family needs a rule id

    def test_the_group_5_encodings(self):
        # COND_6.SZ3 (the Stufe from the LE thresholds as one derive), SZ2 (a check lifting a status for one
        # action), ADV_49.ZH1/ZH3 (useLevel on the Stufe the hero has; a keep), zustaende.Z3 (the
        # cap over the lines of every rule of kind condition) and Z5 (eight Stufen in sum).
        body = textwrap.dedent("""\
            - derive:
                to: "level(rule: SA_1)"
                sum:
                  - { of: leMax, above: leCurrent, times: 4, per: leMax, round: down, max: 3 }
                  - { of: 6, above: leCurrent, max: 1 }
            - when: { level: { atLeast: 3 } }
              check:
                of: { talent: TAL_8, with: Handlungsfähigkeit bewahren }
                onSuccess:
                  - gain: { rule: SA_2, levels: -1, span: action }
            - when: { hero.levelOf.SA_1: [2, 3] }
              useLevel: { rule: SA_1, as: "level - 1" }
            - when: { hero.levelOf.SA_1: 3 }
              useLevel: { rule: SA_1, as: level }
            - cap: { to: [at, check.modifier, gs, ini], over: { ruleKind: condition }, min: -5 }
            - when: { hero.conditionLevels: { atLeast: 8 } }
              gain: { rule: SA_2 }
            """)
        book, errors = check(VALID.replace(EFFECT + "\n        when: { hero.mounted: true }\n",
                                           textwrap.indent(body, "      ")), extra={"abilities/SA_2.yaml": SA_2})
        self.assertEqual(errors, [])
        effects = book["SA_1"]["clauses"][0]["effects"]
        self.assertEqual(effects[0]["payload"]["to"], {"name": "level", "rule": "SA_1"})
        quarters = effects[0]["payload"]["sum"][0]["proportion"]
        self.assertEqual((quarters["of"], quarters["above"], quarters["per"], quarters["max"]),
                         ({"target": {"name": "leMax"}}, {"target": {"name": "leCurrent"}},
                          {"target": {"name": "leMax"}}, 3))
        self.assertEqual(effects[0]["payload"]["sum"][1]["proportion"]["of"], {"number": 6})
        self.assertEqual(effects[2]["when"], {"fact": "hero.levelOf.SA_1", "in": [2, 3]})
        self.assertEqual(effects[3]["payload"]["as"], {"level": {"times": 1, "plus": 0}})   # a keep
        self.assertEqual(effects[4]["payload"]["over"], {"kind": "ruleKind", "ids": ["condition"]})
        self.assertEqual(effects[4]["phase"], "cap")

    # --- vocabulary added by the Group 6 hand migration (plan Task 13) -------------------------
    def test_group_6_vocabulary(self):
        v = vocab.load()
        expected = {"fw.current": "derived", "check.spent": "derived", "check.ones": "roll",
                    "check.twenties": "roll", "check.onOption": "derived",
                    "check.applicationOnOption": "derived"}
        self.assertEqual({f: v.fact_owner(f) for f in expected}, expected)
        self.assertEqual(v.fact_owner("fw.TAL_7"), "sheet")                   # the family is untouched
        self.assertIn("result", v.raw["expectKeys"])

    def test_the_group_6_encodings(self):
        # fertigkeitsproben FP2 (forbid on an EEW ≤ 0), FP3/FP5 (the pool and FP derives), QS1 (the
        # provided table read by a derive), QS2 (the floor), FM2 (a signed GM modifier), ADV_4 B1/B5
        # (Begabung's reroll and its forbid), SA_9.FS1 (+2 on check.fw), TAL_7.critical.
        body = textwrap.dedent("""\
            - when: { query.target: check.attribute, query.result: { atMost: 0 } }
              forbid: { what: { check: [talent, spell, liturgy] } }
            - derive: { to: check.fw, sum: [{ of: fw.current }] }
            - derive: { to: check.fp, sum: [{ of: check.fw }, { of: check.spent, times: -1 }] }
            - provide: { name: SA_1.qs, value: { "0-3": 1, "4-6": 2, "16+": 6 } }
            - when: { check.result: success }
              derive: { to: check.qs, sum: ["table(SA_1.qs, check.fp)"] }
            - when: { check.result: success }
              floor: { to: check.fp, min: 1 }
            - when: { gmFact.checkModifier: { below: 0 } }
              add: { to: check.modifier, value: { of: 0, above: gmFact.checkModifier, times: -1 } }
            - when: { check.onOption: true }
              reroll: { die: { dice: any }, keep: better, max: 1, per: action }
            - when: { check.twenties: { atLeast: 2 } }
              forbid: { what: { line: SA_1.T1 } }
            - when: { check.onOption: true, check.applicationOnOption: true }
              add: { to: check.fw, value: 2 }
            - when: { check.talent: TAL_7, check.ones: { atLeast: 2 } }
              set: { to: check.fp, value: { of: fw.current, times: 2 } }
            """)
        book, errors = check(VALID.replace(EFFECT + "\n        when: { hero.mounted: true }\n",
                                           textwrap.indent(body, "      ")))
        self.assertEqual(errors, [])
        effects = book["SA_1"]["clauses"][0]["effects"]
        self.assertEqual(effects[0]["payload"]["what"], {"kind": "check", "ids": ["talent", "spell", "liturgy"]})
        self.assertEqual(effects[2]["payload"]["sum"][1]["proportion"]["of"], {"fact": "check.spent"})
        self.assertEqual(effects[2]["payload"]["sum"][0]["proportion"]["of"], {"target": {"name": "check.fw"}})
        self.assertEqual(effects[4]["payload"]["sum"], [{"table": {"name": "SA_1.qs", "key": "check.fp"}}])
        self.assertEqual(effects[5]["phase"], "cap")
        neg = effects[6]["payload"]["value"]["proportion"]
        self.assertEqual((neg["of"], neg["above"], neg["times"]),
                         ({"number": 0}, {"fact": "gmFact.checkModifier"}, -1))
        self.assertEqual(effects[7]["payload"]["die"], {"kind": "dice", "ids": ["any"]})
        self.assertEqual(effects[7]["phase"], "action")
        self.assertEqual(effects[9]["payload"]["to"], [{"name": "check.fw"}])
        self.assertEqual(effects[10]["payload"]["value"]["proportion"]["times"], 2)

    # --- normalization ------------------------------------------------------------------------
    def test_rulings_are_qualified_and_get_a_status(self):
        text = VALID.replace(
            "        when: { hero.mounted: true }\n",
            "        when: { hero.mounted: true }\n"
            "        ruling: [schildspalter-shield-bonus, round-up, SA_2.other-ruling]\n",
        ).replace("rulings: []\n", textwrap.dedent("""\
            rulings:
              - id: schildspalter-shield-bonus
                question: q
                answer: yes
            """))
        shared = "- id: round-up\n  question: q\n  answer: null\n"
        book, errors = check(text, extra={"abilities/SA_2.yaml": SA_2}, shared=shared)
        self.assertEqual(errors, [])
        eff = book["SA_1"]["clauses"][0]["effects"][0]
        self.assertEqual(eff["ruling"],
                         ["SA_1.schildspalter-shield-bonus", "shared.round-up", "SA_2.other-ruling"])
        self.assertEqual([(r["id"], r["status"]) for r in book["SA_1"]["rulings"]],
                         [("SA_1.schildspalter-shield-bonus", "decided")])
        self.assertEqual([(r["id"], r["status"]) for r in book["SA_2"]["rulings"]],
                         [("SA_2.other-ruling", "open")])
        self.assertEqual(rules.shared_rulings(write(VALID, shared=shared)),
                         [{"id": "shared.round-up", "question": "q", "answer": None,
                           "status": "open"}])

    def test_the_effect_phase_key_overrides_the_verb_phase(self):
        book, errors = check(VALID.replace("        when: { hero.mounted: true }\n",
                                           "        when: { hero.mounted: true }\n        phase: cap\n"))
        self.assertEqual(errors, [])
        self.assertEqual(book["SA_1"]["clauses"][0]["effects"][0]["phase"], "cap")

    def test_nested_effects_get_a_dotted_origin_index(self):
        nested = textwrap.indent(textwrap.dedent("""\
            - check:
                of: { talent: Zechen }
                onFailure:
                  - add: { to: at, value: -1 }
                  - tell: { to: player, text: hicks }
            """), "      ")
        book, errors = check(VALID.replace(EFFECT + "\n        when: { hero.mounted: true }\n",
                                           EFFECT + "\n" + nested))
        self.assertEqual(errors, [])
        outer = book["SA_1"]["clauses"][0]["effects"][1]
        self.assertEqual(outer["origin"]["index"], 1)
        self.assertEqual(outer["payload"]["of"], {"kind": "talent", "ids": ["Zechen"]})
        inner = outer["payload"]["onFailure"]
        self.assertEqual([e["origin"]["index"] for e in inner], ["1.onFailure.0", "1.onFailure.1"])
        self.assertEqual(inner[1]["payload"], {"to": "player", "text": "hicks"})
        self.assertEqual(inner[1]["phase"], "player")


class CheckCommandTests(unittest.TestCase):
    def run_main(self, argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = main(argv)
        return code, out.getvalue()

    def test_ok_on_a_valid_tree(self):
        code, out = self.run_main(["check", "--rules", str(write(VALID))])
        self.assertEqual(code, 0)
        self.assertEqual(out, "ok: 1 rules, 2 clauses, 1 effects\n")

    def test_errors_and_count(self):
        d = write(VALID.replace(EFFECT, "      - raise: { to: at, by: 2 }")
                  .replace("name: Test\n", "name: Test\ncolour: red\n"))
        code, out = self.run_main(["check", "--rules", str(d)])
        self.assertEqual(code, 1)
        lines = out.splitlines()
        path = str(d / "abilities" / "SA_1.yaml")
        self.assertEqual(lines, [f"{path}:3: unknown key colour",
                                 f"{path}:12: unknown verb raise",
                                 "2 errors"])

    def test_only_filters_by_file_suffix(self):
        d = write(VALID.replace(EFFECT, "      - raise: { to: at, by: 2 }"))
        code, out = self.run_main(["check", "--rules", str(d), "--only", "SA_9.yaml"])
        self.assertEqual(code, 0)
        self.assertTrue(out.startswith("ok: 1 rules, 2 clauses, "), out)


if __name__ == "__main__":
    unittest.main()
