import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from rulec import compile, rules, vocab
from rulec.__main__ import main
from rulec.errors import RulecError

HEAD = """\
id: {id}
name: {id}
kind: specialAbility
source: {{ url: x, book: y, page: 1, checked: 2026-09-24, hash: null }}
reviewed: null
"""

A = HEAD.format(id="A") + """\
clauses:
  - id: A1
    text: "A eins"
    effects:
      - add: { to: [pa, aw], value: -1 }
rulings:
  - id: a-ruling
    question: q
    answer: null
"""

B = HEAD.format(id="B") + """\
levels: 3
clauses:
  - id: B1
    text: "B eins"
    effects:
      - useLevel: { rule: B, as: "level - 1" }
  - id: B2
    text: "B zwei"
    effects:
      - add: { to: at, value: level }
rulings: []
"""

C = HEAD.format(id="C") + """\
clauses:
  - id: C1
    text: "C eins"
    effects:
      - provide: { name: t.x, value: { a: 1 } }
rulings: []
"""

SHARED = """\
- id: round-up
  question: q
  answer: up
"""


def write_tree(files, shared=SHARED):
    d = Path(tempfile.mkdtemp())
    (d / "abilities").mkdir()
    for name, body in files.items():
        (d / "abilities" / f"{name}.yaml").write_text(body)
    (d / "rulings.yaml").write_text(shared)
    return d


def compile_tree(d):
    v = vocab.load()
    book, errors = rules.check(d, v)
    assert errors == [], [str(e) for e in errors]
    return compile.build_rules(book, v, rules.shared_rulings(d))


def compile_fixture(with_c=False):
    files = {"A": A, "B": B}
    if with_c:
        files["C"] = C
    return compile_tree(write_tree(files))


def one_rule(clauses, levels=None, extra=None):
    """A tree with rule X (the given clauses) plus the named extra rules."""
    body = HEAD.format(id="X") + (f"levels: {levels}\n" if levels else "") + "clauses:\n" + clauses + "rulings: []\n"
    return compile_tree(write_tree({"X": body, **(extra or {})}))


def build_twice():
    obj = compile_fixture()
    out = Path(tempfile.mkdtemp())
    compile.write(obj, out / "one" / "rules.json")
    compile.write(compile_fixture(), out / "two" / "rules.json")
    return ((out / "one" / "rules.json").read_text(encoding="utf-8"),
            (out / "two" / "rules.json").read_text(encoding="utf-8"))


def ref(rule, clause, index=0):
    return {"rule": rule, "clause": clause, "index": index}


class CompileTests(unittest.TestCase):
    def test_reach_index(self):
        out = compile_fixture()                 # rules.check + compile.build_rules
        self.assertEqual(out["reach"]["pa"], [{"rule": "A", "clause": "A1", "index": 0}])
        self.assertEqual(out["reach"]["at"], [{"rule": "B", "clause": "B1", "index": 0},
                                               {"rule": "B", "clause": "B2", "index": 0}])

    def test_reach_index_is_exact(self):
        self.assertEqual(compile_fixture()["reach"], {
            "pa": [ref("A", "A1")],
            "aw": [ref("A", "A1")],
            "at": [ref("B", "B1"), ref("B", "B2")],
        })

    def test_unread_provide_can_never_fire(self):
        with self.assertRaisesRegex(RulecError, "clause can never fire: C.C1"):
            compile_fixture(with_c=True)

    def test_build_is_deterministic(self):
        a, b = build_twice()
        self.assertEqual(a, b)
        self.assertTrue(a.endswith("\n"))
        self.assertEqual(a, json.dumps(json.loads(a), sort_keys=True, ensure_ascii=False, indent=1) + "\n")

    def test_top_level_keys(self):
        out = compile_fixture()
        v = vocab.load()
        self.assertEqual(set(out), {"vocabularyVersion", "vocabularySha256", "rules", "rulings", "reach"})
        self.assertEqual(out["vocabularyVersion"], v.version)
        self.assertEqual(out["vocabularySha256"], v.sha256)
        self.assertEqual([r["id"] for r in out["rules"]], ["A", "B"])
        self.assertEqual([r["id"] for r in out["rulings"]], ["A.a-ruling", "shared.round-up"])
        self.assertEqual(out["rules"][0]["source"]["checked"], "2026-09-24")   # a date, as ISO text

    def test_read_provide_is_reachable(self):
        out = one_rule("""\
  - id: X1
    text: "Tabelle"
    effects:
      - provide: { name: t.x, value: { a: 1 } }
  - id: X2
    text: "liest sie"
    effects:
      - add: { to: at, value: "table(t.x, a)" }
""")
        self.assertIn(ref("X", "X1"), out["reach"]["*"])
        self.assertEqual(out["reach"]["at"], [ref("X", "X2")])

    def test_provide_read_from_a_nested_effect_is_reachable(self):
        out = one_rule("""\
  - id: X1
    text: "Tabelle"
    effects:
      - provide: { name: t.x, value: { a: 1 } }
  - id: X2
    text: "Probe"
    effects:
      - check: { of: { talent: Willenskraft }, onFailure: [ { add: { to: belastung, value: "table(t.x, a)" } } ] }
""")
        self.assertIn(ref("X", "X1"), out["reach"]["*"])

    def test_a_longer_dotted_name_does_not_read_the_provide(self):
        with self.assertRaisesRegex(RulecError, "clause can never fire: X.X1"):
            one_rule("""\
  - id: X1
    text: "Tabelle"
    effects:
      - provide: { name: t, value: { a: 1 } }
  - id: X2
    text: "liest t.x"
    effects:
      - add: { to: at, value: "table(t.x, a)" }
""")

    def test_nested_effects_are_reached_through_their_parent(self):
        out = one_rule("""\
  - id: X1
    text: "Probe"
    effects:
      - check: { of: { talent: Willenskraft }, onFailure: [ { add: { to: belastung, value: 1 } } ] }
""")
        self.assertEqual(out["reach"], {"*": [ref("X", "X1")]})

    def test_verbs_by_kind(self):
        out = one_rule("""\
  - id: X1
    text: "t"
    effects:
      - derive: { to: wundschwelle, sum: [ 1 ] }
      - set: { to: gs, value: 1 }
      - multiply: { to: tp, by: 2 }
      - cap: { to: [ini], max: 3 }
      - floor: { to: opponent.at, min: 0 }
      - forbid: { what: { defence: shieldParry } }
      - forbid: { what: { defence: aw } }
      - limit: { what: { attack: passierschlag }, per: round, max: 1 }
      - require: { that: { hero.mounted: true }, for: { talent: Reiten } }
      - require: { that: { hero.mounted: true } }
      - tell: { to: player, text: "x" }
""")
        self.assertEqual(out["reach"], {
            "wundschwelle": [ref("X", "X1", 0)],
            "gs": [ref("X", "X1", 1)],
            "tp": [ref("X", "X1", 2)],
            "ini": [ref("X", "X1", 3)],
            "opponent.at": [ref("X", "X1", 4)],
            "pa": [ref("X", "X1", 5)],
            "aw": [ref("X", "X1", 6)],
            "at": [ref("X", "X1", 7)],
            "fk": [ref("X", "X1", 7)],
            "*": [ref("X", "X1", 8), ref("X", "X1", 9), ref("X", "X1", 10)],
        })

    def test_replace_and_suppress_follow_the_named_clause(self):
        out = one_rule("""\
  - id: X1
    text: "t"
    effects:
      - add: { to: [at, pa], value: 1 }
  - id: X2
    text: "u"
    effects:
      - replace: { line: { line: X.X1 }, with: 2 }
      - suppress: { line: { line: X.X1 } }
""")
        self.assertEqual(out["reach"]["at"], [ref("X", "X1"), ref("X", "X2", 0), ref("X", "X2", 1)])
        self.assertEqual(out["reach"]["pa"], out["reach"]["at"])

    def test_use_level_of_a_rule_reaching_no_target_goes_under_star(self):
        out = one_rule("""\
  - id: X1
    text: "t"
    effects:
      - useLevel: { rule: Y, lowerBy: 1 }
""", extra={"Y": HEAD.format(id="Y") + """\
levels: 2
clauses:
  - id: Y1
    text: "y"
    unencoded: true
rulings: []
"""})
        self.assertEqual(out["reach"], {"*": [ref("X", "X1")]})

    def test_main_build_writes_rules_json(self):
        d = write_tree({"A": A, "B": B})
        out = Path(tempfile.mkdtemp()) / "build" / "rules"
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = main(["build", "--rules", str(d), "--out", str(out)])
        self.assertEqual(code, 0, buf.getvalue())
        self.assertEqual(buf.getvalue().strip(), f"wrote {out / 'rules.json'} (2 rules)")
        self.assertEqual(json.loads((out / "rules.json").read_text())["reach"]["pa"], [ref("A", "A1")])

    def test_main_build_fails_on_a_clause_that_can_never_fire(self):
        d = write_tree({"A": A, "B": B, "C": C})
        out = Path(tempfile.mkdtemp())
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = main(["build", "--rules", str(d), "--out", str(out)])
        self.assertEqual(code, 1)
        self.assertIn("clause can never fire: C.C1", buf.getvalue())
        self.assertFalse((out / "rules.json").exists())


if __name__ == "__main__":
    unittest.main()
