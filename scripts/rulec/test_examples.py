import unittest
from rulec import rules, situations, compile, vocab
from rulec.__main__ import EXAMPLES


class TheExamplesCompile(unittest.TestCase):
    def test_no_errors(self):
        v = vocab.load()
        # The shared rulings (rules/rulings.yaml) as `rulec` passes them: situations cite them.
        shared = rules.shared_rulings(EXAMPLES / "rules")
        book, errors = rules.check(EXAMPLES / "rules", v)
        self.assertEqual([str(e) for e in errors], [])
        out = compile.build_rules(book, v, shared)
        sits, serrors = situations.check(EXAMPLES / "situations", book, out["reach"], v, shared)
        self.assertEqual([str(e) for e in serrors], [])
        self.assertGreaterEqual(len(sits), 303)

    def test_both_files_serialize(self):
        # `make rules-json` writes both files: every key a string (a bare YAML `on:` is a bool).
        v = vocab.load()
        shared = rules.shared_rulings(EXAMPLES / "rules")
        book, _ = rules.check(EXAMPLES / "rules", v)
        out = compile.build_rules(book, v, shared)
        sits, _ = situations.check(EXAMPLES / "situations", book, out["reach"], v, shared)
        compile.dumps(out)
        compile.dumps(compile._jsonable({"vocabularyVersion": v.version, "situations": sits}))


if __name__ == "__main__":
    unittest.main()
