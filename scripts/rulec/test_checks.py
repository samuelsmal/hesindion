"""The Probe table (`checks.yaml`, Task 34): each talent's and spell's three attributes, a talent's
Belastung flag and its Anwendungsgebiete, the caller's data the harness hands in (as the app did from
rules.db). rulec checks it, writes it into situations.json, and resolves an owned rule's numeric
`sid2` (SA_9's Anwendungsgebiet id) into the application's name."""
import contextlib
import io
import json
import unittest
from pathlib import Path

from rulec import checks, compile, rules, situations, vocab
from rulec.__main__ import ROOT, main
from rulec.test_situations import MAIN, tree

TABLE = """\
TAL_10: { attributes: [KL, IN, IN], hinderedByBelastung: maybe, applications: { 1: Hinterhalt entdecken, 2: Suchen, 3: Wahrnehmen } }
TAL_7: { attributes: [GE, KO, KK], hinderedByBelastung: true }
SPELL_21: { attributes: [MU, KL, CH] }
"""


def load(text):
    d = Path(tree({})) / "checks.yaml"
    d.write_text(text)
    return checks.load(d)


class TableTests(unittest.TestCase):
    def test_the_table_loads(self):
        table, errors = load(TABLE)
        self.assertEqual([str(e) for e in errors], [])
        self.assertEqual(table["TAL_10"], {"attributes": ["KL", "IN", "IN"], "hinderedByBelastung": "maybe",
                                           "applications": {"1": "Hinterhalt entdecken", "2": "Suchen",
                                                            "3": "Wahrnehmen"}})
        self.assertEqual(table["TAL_7"], {"attributes": ["GE", "KO", "KK"], "hinderedByBelastung": True})
        self.assertEqual(table["SPELL_21"], {"attributes": ["MU", "KL", "CH"]})

    def test_bad_rows_are_errors(self):
        _, errors = load("TAL_1: { attributes: [MU, KL] }\n"
                         "TAL_2: { attributes: [MU, KL, XX] }\n"
                         "TAL_3: { attributes: [MU, KL, IN], hinderedByBelastung: often }\n"
                         "TAL_4: { attributes: [MU, KL, IN], applications: { eins: Suchen } }\n"
                         "TAL_5: { attributes: [MU, KL, IN], cost: B }\n"
                         "Sinnesschaerfe: { attributes: [MU, KL, IN] }\n"
                         "SPELL_1: { attributes: [MU, KL, IN], hinderedByBelastung: true }\n")
        self.assertEqual([(e.line, e.message) for e in errors], [
            (1, "TAL_1: attributes are three of MU, KL, IN, CH, FF, GE, KO, KK"),
            (2, "TAL_2: attributes are three of MU, KL, IN, CH, FF, GE, KO, KK"),
            (3, "TAL_3: hinderedByBelastung is true, false or maybe"),
            (4, "TAL_4: an application is an int id and its name"),
            (5, "TAL_5: unknown key cost"),
            (6, "unknown check subject Sinnesschaerfe"),
            (7, "SPELL_1: only a talent has hinderedByBelastung"),
        ])


class ApplicationTests(unittest.TestCase):
    def compile(self, body, table):
        d = tree({"a.yaml": "situations:\n  - id: S\n" + body})
        v = vocab.load()
        book, _ = rules.check(d, v)
        out, errors = situations.check(d / "situations", book, compile.build_rules(book, v)["reach"], v,
                                       checks=table)
        self.assertEqual([str(e) for e in errors], [])
        return out[0]

    def test_a_numeric_sid2_is_the_applications_name(self):
        table, _ = load(TABLE)
        s = self.compile("    hero: { abilities: { SA_1: { sid: TAL_10, sid2: 2 } } }\n", table)
        self.assertEqual(s["owned"], {"SA_1": {"level": 1, "option": "TAL_10", "option2": "Suchen"}})

    def test_an_unknown_id_or_the_players_words_stay(self):
        table, _ = load(TABLE)
        s = self.compile("    hero: { abilities: { SA_1: { sid: TAL_10, sid2: 9 } } }\n", table)
        self.assertEqual(s["owned"]["SA_1"]["option2"], 9)
        s = self.compile("    hero: { abilities: { SA_1: { sid: TAL_10, sid2: Spuren lesen } } }\n", table)
        self.assertEqual(s["owned"]["SA_1"]["option2"], "Spuren lesen")
        s = self.compile("    hero: { abilities: { SA_1: { sid: TAL_7, sid2: 2 } } }\n", table)
        self.assertEqual(s["owned"]["SA_1"]["option2"], 2)


class CommandTests(unittest.TestCase):
    def test_build_writes_the_table_into_situations_json(self):
        d = tree({"main.yaml": MAIN})
        (d / "checks.yaml").write_text(TABLE)
        out = d / "build"
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = main(["build", "--rules", str(d), "--out", str(out)])
        self.assertEqual(code, 0, buf.getvalue())
        obj = json.loads((out / "situations.json").read_text())
        self.assertEqual(obj["checks"]["TAL_10"]["attributes"], ["KL", "IN", "IN"])
        self.assertEqual(obj["checks"]["TAL_10"]["applications"]["2"], "Suchen")

    def test_a_bad_table_fails_the_check(self):
        d = tree({"main.yaml": MAIN})
        (d / "checks.yaml").write_text("TAL_1: { attributes: [MU] }\n")
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = main(["check", "--rules", str(d)])
        self.assertEqual(code, 1)
        self.assertIn("TAL_1: attributes are three", buf.getvalue())

    def test_the_examples_table_names_every_check_the_situations_state(self):
        # The harness runs a stated check with the Probe from this table (no rules.db).
        table, errors = checks.load(ROOT / "checks.yaml")
        self.assertEqual([str(e) for e in errors], [])
        self.assertEqual(table["TAL_10"]["attributes"], ["KL", "IN", "IN"])
        self.assertEqual(table["TAL_10"]["applications"]["2"], "Suchen")
        v = vocab.load()
        book, _ = rules.check(ROOT, v)
        out = compile.build_rules(book, v, rules.shared_rulings(ROOT))
        sits, _ = situations.check(ROOT / "situations", book, out["reach"], v,
                                   rules.shared_rulings(ROOT), checks=table)
        stated = {f["value"] for s in sits for f in s["facts"] if f["name"] in ("check.talent", "check.spell")}
        self.assertTrue(stated)
        self.assertEqual(sorted(stated - set(table)), [])


if __name__ == "__main__":
    unittest.main()
