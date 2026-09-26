"""sync.py: `make rules-sync` end to end, against a `FakeFetcher` site and a temp rules root.

Reuses `FakeFetcher`, `BASE`, `_index` and `_rule` from `test_resolve.py` rather than building a
fake site from scratch.
"""
import datetime
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from rules_review import rulefiles

from rules_sync import pages, sync
from rules_sync.test_resolve import BASE, FIXTURES, FakeFetcher, _index, _rule

D1 = datetime.date(2026, 9, 26)

SITE_ROOT = (FIXTURES / "site_root.html").read_text(encoding="utf-8")

SA_10 = """\
id: SA_10
name: Platzhalter Zehn
kind: specialAbility
source:
  url: https://dsa.ulisses-regelwiki.de/a.html
  hash: null
clauses: []
"""

SA_1 = """\
id: SA_1
name: Platzhalter Eins
kind: specialAbility
source:
  url: https://dsa.ulisses-regelwiki.de/b.html
  hash: sha256:existing
  checked: 2026-01-01
clauses: []
"""

SA_20_FLOW = """\
id: SA_20
name: Platzhalter Zwanzig
kind: specialAbility
source: { url: https://dsa.ulisses-regelwiki.de/a.html, hash: null }
clauses: []
"""

SA_30_MULTI_SOURCE = """\
id: SA_30
name: Platzhalter Dreißig
kind: specialAbility
source:
  url: https://dsa.ulisses-regelwiki.de/c.html
  hash: null
  also:
    - { url: https://dsa.ulisses-regelwiki.de/a.html }
clauses: []
"""


def site(with_kat_eins=True):
    out = {
        BASE: SITE_ROOT,
        BASE + "kat_zwei.html": _index([("Regel C", "c.html")]),
        BASE + "c.html": _rule("Regel C", "Text C"),
    }
    if with_kat_eins:
        out[BASE + "kat_eins.html"] = _index([("Regel A", "a.html"), ("Regel B", "b.html")])
        out[BASE + "a.html"] = _rule("Regel A", "Text A")
        out[BASE + "b.html"] = _rule("Regel B", "Text B")
    return out


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.rules_root = self.dir / "rules"
        (self.rules_root / "abilities").mkdir(parents=True)
        (self.rules_root / "abilities" / "SA_10.yaml").write_text(SA_10, encoding="utf-8")
        (self.rules_root / "abilities" / "SA_1.yaml").write_text(SA_1, encoding="utf-8")
        self.pages_path = self.dir / "pages.yaml"
        patcher = mock.patch.object(rulefiles, "ROOT", self.rules_root)
        patcher.start()
        self.addCleanup(patcher.stop)

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_writes_pages_yaml_with_rule_and_index_pages_and_returns_0(self):
        status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root, today=D1)
        self.assertEqual(status, 0)
        reg = pages.read(self.pages_path)
        self.assertEqual(reg.pages["a.html"]["kind"], "rule")
        self.assertEqual(reg.pages["b.html"]["kind"], "rule")
        self.assertEqual(reg.pages["kat_eins.html"]["kind"], "index")
        self.assertEqual(reg.pages["kat_zwei.html"]["kind"], "index")

    def test_adopt_fills_the_null_hash_file_and_leaves_the_other_untouched(self):
        before = (self.rules_root / "abilities" / "SA_1.yaml").read_text(encoding="utf-8")
        status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root,
                           adopt_all=True, today=D1)
        self.assertEqual(status, 0)
        reg = pages.read(self.pages_path)
        a_hash = reg.pages["a.html"]["hash"]
        got = (self.rules_root / "abilities" / "SA_10.yaml").read_text(encoding="utf-8")
        self.assertIn(f"hash: {a_hash}", got)
        self.assertIn("checked: 2026-09-26", got)
        after = (self.rules_root / "abilities" / "SA_1.yaml").read_text(encoding="utf-8")
        self.assertEqual(before, after)

    def test_adopt_ids_for_an_unknown_id_returns_1_and_adopts_nothing(self):
        status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root,
                           adopt_ids=["SA_9"], today=D1)
        self.assertEqual(status, 1)
        got = (self.rules_root / "abilities" / "SA_10.yaml").read_text(encoding="utf-8")
        self.assertIn("hash: null", got)

    def test_a_missing_index_page_returns_1_and_leaves_pages_yaml_untouched(self):
        ok = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root, today=D1)
        self.assertEqual(ok, 0)
        before = self.pages_path.read_text(encoding="utf-8")
        status = sync.run(FakeFetcher(site(with_kat_eins=False)), self.pages_path,
                           self.rules_root, today=D1)
        self.assertEqual(status, 1)
        after = self.pages_path.read_text(encoding="utf-8")
        self.assertEqual(before, after)


class AdoptRefusesAnUneditableSourceTests(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.rules_root = self.dir / "rules"
        (self.rules_root / "abilities").mkdir(parents=True)
        (self.rules_root / "abilities" / "SA_20.yaml").write_text(SA_20_FLOW, encoding="utf-8")
        self.pages_path = self.dir / "pages.yaml"
        patcher = mock.patch.object(rulefiles, "ROOT", self.rules_root)
        patcher.start()
        self.addCleanup(patcher.stop)

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_a_flow_style_source_is_refused_reported_and_does_not_stop_the_run(self):
        status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root,
                           adopt_all=True, today=D1)
        self.assertEqual(status, 1)
        got = (self.rules_root / "abilities" / "SA_20.yaml").read_text(encoding="utf-8")
        self.assertEqual(got, SA_20_FLOW, "the unwritable file is left exactly as it was")


class AdoptFromSourceUrlOnlyTests(unittest.TestCase):
    """A rule with `also[].url` is adopted from `source.url` only (its `also` pages are coverage,
    not the hash the rule file records)."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.rules_root = self.dir / "rules"
        (self.rules_root / "abilities").mkdir(parents=True)
        (self.rules_root / "abilities" / "SA_30.yaml").write_text(SA_30_MULTI_SOURCE, encoding="utf-8")
        self.pages_path = self.dir / "pages.yaml"
        patcher = mock.patch.object(rulefiles, "ROOT", self.rules_root)
        patcher.start()
        self.addCleanup(patcher.stop)

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_the_also_page_is_never_the_one_adopted(self):
        status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root,
                           adopt_all=True, today=D1)
        self.assertEqual(status, 0)
        reg = pages.read(self.pages_path)
        c_hash, a_hash = reg.pages["c.html"]["hash"], reg.pages["a.html"]["hash"]
        self.assertNotEqual(c_hash, a_hash, "the fixture must give the two pages different hashes")
        got = (self.rules_root / "abilities" / "SA_30.yaml").read_text(encoding="utf-8")
        self.assertIn(f"hash: {c_hash}", got)
        self.assertNotIn(f"hash: {a_hash}", got)


class ReportTests(unittest.TestCase):
    def test_report_does_not_crash_on_an_empty_crawl(self):
        from rules_sync.resolve import SiteCrawl
        sync.report(SiteCrawl(), pages.Registry(), pages.Registry())


if __name__ == "__main__":
    unittest.main()
