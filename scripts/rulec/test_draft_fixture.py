"""The engine's log exports one entry as a situations-file draft (spec §8, plan Task 29). The
Swift test `LogTests.testTheDraftOf19_1IsRecordedForRulec` records the draft of situation 19.1 in
`fixtures/draft-from-log.yaml`; here rulec compiles that file against the real rules, so a draft
the engine writes is one rulec accepts."""
import shutil
import tempfile
import unittest
from pathlib import Path

from rulec import compile, rules, situations, vocab
from rulec.__main__ import EXAMPLES

FIXTURE = Path(__file__).parent / "fixtures" / "draft-from-log.yaml"


class TheDraftFromTheLogCompiles(unittest.TestCase):
    def compile(self, directory=None):
        v = vocab.load()
        shared = rules.shared_rulings(EXAMPLES / "rules")
        book, errors = rules.check(EXAMPLES / "rules", v)
        self.assertEqual([str(e) for e in errors], [])
        out = compile.build_rules(book, v, shared)
        if directory is not None:
            return situations.check(directory, book, out["reach"], v, shared)
        with tempfile.TemporaryDirectory() as d:
            shutil.copy(FIXTURE, Path(d) / FIXTURE.name)
            return situations.check(Path(d), book, out["reach"], v, shared)

    def test_no_errors(self):
        sits, errors = self.compile()
        self.assertEqual([str(e) for e in errors], [])
        self.assertEqual([s["id"] for s in sits], ["19.1"])

    def test_the_sections_compile_to_their_owners(self):
        (s,), _ = self.compile()
        owners = {f["name"]: f["owner"] for f in s["facts"]}
        self.assertEqual(owners["attr.MU"], "sheet")
        self.assertEqual(owners["loadout.weapon"], "loadout")
        self.assertEqual(owners["loadout.armour.belastung"], "loadout")
        self.assertEqual(owners["choice.formation"], "player")
        self.assertEqual(s["owned"]["DISADV_37"], {"level": 1, "option": 2})
        self.assertEqual(s["base"]["at(with: Rabenschnabel)"], 16)
        self.assertEqual([q["query"] for q in s["expect"]], ["at", "pa"])
        self.assertTrue(all("from" in line and "value" in line for q in s["expect"] for line in q.get("lines", [])))

    def test_the_draft_states_the_situation_it_was_run_on(self):
        # The engine ran 19.1 as rulec compiles it from the examples; its draft, compiled
        # again, states the same hero, facts, base values and dice.
        (draft,), _ = self.compile()
        examples, _ = self.compile(EXAMPLES / "situations")
        original = next(s for s in examples if s["id"] == "19.1")
        for key in ("owned", "facts", "base", "rolls"):
            self.assertEqual(draft[key], original[key], key)


if __name__ == "__main__":
    unittest.main()
