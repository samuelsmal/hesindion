"""The review tool's edits touch only the lines they mean to.

    make test-rules-review
"""

import datetime
import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

import rulefiles as rf

DAY = datetime.date(2026, 9, 23)

RULE = """\
# a comment at the top
id: SA_1
name: Beispiel
source: { url: https://example.org, checked: 2026-09-23 }
reviewed: null             # { by, date } once a person has read every clause
# Optolith says page 249. The page wins.

clauses:
  - id: C1
    text: >
      Ein Satz.
    effects:
      - add: { to: at, value: -2 }
        # FORMAT: a note that belongs to the clause

rulings:
  - id: first
    status: open
    question: Which?
    options:
      a: { says: "this", app: "no change" }
      b: { says: "that", app: "a change" }
    recommended: a
    answer: null

  - id: second
    status: open
    question: And this?
    answer: >
      An earlier answer
      over two lines.
"""


class EditTests(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.path = self.dir / "SA_1.yaml"
        self.path.write_text(RULE, encoding="utf-8")
        self.shared = rf.SHARED
        rf.SHARED = self.dir / "rulings.yaml"

    def tearDown(self):
        rf.SHARED = self.shared
        shutil.rmtree(self.dir)

    def changed_lines(self):
        old, new = RULE.splitlines(), self.path.read_text(encoding="utf-8").splitlines()
        return [l for l in new if l not in old], [l for l in old if l not in new]

    def test_an_option_letter_replaces_null(self):
        rf.set_answer(self.path, "first", "b")
        added, removed = self.changed_lines()
        self.assertEqual(added, ["    answer: b"])
        self.assertEqual(removed, ["    answer: null"])

    def test_own_words_replace_a_folded_answer(self):
        rf.set_answer(self.path, "second", "Neither; " + "the GM decides " * 10)
        data = yaml.safe_load(self.path.read_text(encoding="utf-8"))
        self.assertTrue(data["rulings"][1]["answer"].startswith("Neither; the GM decides"))
        self.assertIsNone(data["rulings"][0]["answer"])
        self.assertNotIn("over two lines.", self.path.read_text(encoding="utf-8"))

    def test_an_empty_answer_reopens(self):
        rf.set_answer(self.path, "second", "")
        data = yaml.safe_load(self.path.read_text(encoding="utf-8"))
        self.assertIsNone(data["rulings"][1]["answer"])

    def test_reviewed_keeps_the_comments(self):
        rf.set_reviewed(self.path, "@someone", DAY)
        text = self.path.read_text(encoding="utf-8")
        self.assertIn('reviewed: { by: "@someone", date: 2026-09-23 }             # { by, date }', text)
        self.assertIn("# Optolith says page 249. The page wins.", text)
        rf.set_reviewed(self.path, None)
        self.assertEqual(self.path.read_text(encoding="utf-8"), RULE)

    def test_a_flag_goes_after_reviewed_and_comes_off_cleanly(self):
        rf.set_agent_pass(self.path, "@someone", "the options miss a case", ["C1", "first"], DAY)
        data = yaml.safe_load(self.path.read_text(encoding="utf-8"))
        self.assertEqual(data["agent_pass"]["about"], ["C1", "first"])
        self.assertEqual(data["agent_pass"]["requested"], {"by": "@someone", "date": DAY})
        rf.clear_agent_pass(self.path)
        self.assertEqual(self.path.read_text(encoding="utf-8"), RULE)

    def test_a_shared_ruling_is_found_at_the_top_level(self):
        rf.SHARED.write_text("- id: round-up\n  status: open\n  answer: null\n", encoding="utf-8")
        rf.set_answer(rf.SHARED, "round-up", "a")
        self.assertEqual(rf.SHARED.read_text(encoding="utf-8"),
                         "- id: round-up\n  status: open\n  answer: a\n")

    def test_an_unknown_ruling_is_refused(self):
        with self.assertRaises(KeyError):
            rf.set_answer(self.path, "third", "a")
        self.assertEqual(self.path.read_text(encoding="utf-8"), RULE)


class ModelTests(unittest.TestCase):
    def test_every_example_file_loads_with_its_lines(self):
        for rule in rf.load():
            self.assertIsNone(rule.error, rule.path)
            lines = (rf.HERE / rule.path).read_text(encoding="utf-8").splitlines()
            for item in rule.clauses + rule.rulings:
                self.assertIn(f"id: {item.id}", lines[item.line - 1], f"{rule.path}:{item.line}")


if __name__ == "__main__":
    unittest.main()
