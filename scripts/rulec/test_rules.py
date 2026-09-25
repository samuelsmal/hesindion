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
