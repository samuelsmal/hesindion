"""The engine's log exports one entry as a situations-file draft (spec §8, plan Task 29). The
Swift test `LogTests.testTheDraftOf19_1IsRecordedForRulec` records the draft of situation 19.1 in
`fixtures/draft-from-log.yaml`; here rulec compiles that file against the real rules, so a draft
the engine writes is one rulec accepts."""
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from rulec import compile, rules, situations, vocab
from rulec.__main__ import ROOT

FIXTURE = Path(__file__).parent / "fixtures" / "draft-from-log.yaml"
# Written by the engine's round trip (`LogTests.testEveryPassingSituationRoundTrips`, run by
# `make test-rules-engine`): each passing situation's draft (`<id>.yaml`) and the object the
# engine says it compiles to (`<id>.json`).
DRAFTS = Path(__file__).resolve().parents[2] / "build" / "rules" / "drafts"


class TheDraftFromTheLogCompiles(unittest.TestCase):
    def compile(self, directory=None):
        v = vocab.load()
        shared = rules.shared_rulings(ROOT)
        book, errors = rules.check(ROOT, v)
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
        self.assertEqual([s["id"] for s in sits], ["19.1-draft"])

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
        examples, _ = self.compile(ROOT / "situations")
        original = next(s for s in examples if s["id"] == "19.1")
        for key in ("owned", "facts", "base", "rolls"):
            self.assertEqual(draft[key], original[key], key)


class EveryDraftReimports(unittest.TestCase):
    """Spec §8: re-importing a run's draft as a situation reproduces it. The engine compares its
    breakdowns; here rulec reads each draft's YAML back and must compile it to exactly the object
    the engine ran (`SituationDraft.compiledJSON`)."""

    def test_every_draft_compiles_to_what_the_engine_ran(self):
        yamls = sorted(DRAFTS.glob("*.yaml")) if DRAFTS.is_dir() else []
        if not yamls:
            self.skipTest(f"no drafts in {DRAFTS}: run `make test-rules-engine` first")
        v = vocab.load()
        shared = rules.shared_rulings(ROOT)
        book, errors = rules.check(ROOT, v)
        self.assertEqual([str(e) for e in errors], [])
        out = compile.build_rules(book, v, shared)
        sits, errors = situations.check(DRAFTS, book, out["reach"], v, shared)
        self.assertEqual([str(e) for e in errors], [])
        by_id = {s["id"]: s for s in sits}
        self.assertEqual(len(by_id), len(yamls))
        for path in yamls:
            want = json.loads(path.with_suffix(".json").read_text())
            got = by_id[want["id"]]
            for key in ("owned", "facts", "base", "rolls", "expect"):
                self.assertEqual(got[key], want[key], f"{path.name}: {key}")


if __name__ == "__main__":
    unittest.main()
