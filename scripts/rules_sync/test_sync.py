"""sync.py: `make rules-sync` end to end, against a `FakeFetcher` site and a temp rules root.

Reuses `FakeFetcher`, `BASE`, `_index` and `_rule` from `test_resolve.py` rather than building a
fake site from scratch.
"""
import contextlib
import datetime
import io
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from rules_review import rulefiles

from rules_sync import pages, sync
from rules_sync.test_resolve import BASE, FIXTURES, FakeFetcher, _index, _rule

D1 = datetime.date(2026, 9, 26)
D2 = datetime.date(2026, 9, 27)

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

# No `source.url` at all -- only an `also[].url`. `check.rule_sources` still yields one
# `RuleSource` for this rule (the `also` entry), which must never be mistaken for a primary
# source and adopted into `source.hash`.
SA_40_NO_PRIMARY = """\
id: SA_40
name: Platzhalter Vierzig
kind: specialAbility
source:
  hash: null
  also:
    - { url: https://dsa.ulisses-regelwiki.de/a.html }
clauses: []
"""

# source.url points at an index page, not a rule page.
SA_50_INDEX_SOURCE = """\
id: SA_50
name: Platzhalter Fünfzig
kind: specialAbility
source:
  url: https://dsa.ulisses-regelwiki.de/kat_eins.html
  hash: null
clauses: []
"""

# source.url points at a page ("d.html") that a later sync will no longer reach -- `pages.merge`
# then keeps the page's old `kind`/`hash` and adds `gone: <date>`.
SA_60_ON_A_PAGE_THAT_GOES_AWAY = """\
id: SA_60
name: Platzhalter Sechzig
kind: specialAbility
source:
  url: https://dsa.ulisses-regelwiki.de/d.html
  hash: sha256:old
  checked: 2026-01-01
clauses: []
"""

SA_61_NULL_HASH_ON_THE_SAME_PAGE = """\
id: SA_61
name: Platzhalter Einundsechzig
kind: specialAbility
source:
  url: https://dsa.ulisses-regelwiki.de/d.html
  hash: null
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


def site_with_d():
    """`site()` plus one more rule page ("d.html"), linked from Kategorie Zwei. A later sync
    against plain `site()` no longer reaches it, so it becomes a `gone` page in the registry."""
    out = site()
    out[BASE + "kat_zwei.html"] = _index([("Regel C", "c.html"), ("Regel D", "d.html")])
    out[BASE + "d.html"] = _rule("Regel D", "Text D")
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

    def test_adopt_ids_readopts_a_rule_that_already_has_a_hash(self):
        status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root,
                           adopt_ids=["SA_1"], today=D1)
        self.assertEqual(status, 0)
        reg = pages.read(self.pages_path)
        b_hash = reg.pages["b.html"]["hash"]
        self.assertNotEqual(b_hash, "sha256:existing")
        got = (self.rules_root / "abilities" / "SA_1.yaml").read_text(encoding="utf-8")
        self.assertIn(f"hash: {b_hash}", got)
        self.assertNotIn("sha256:existing", got)
        self.assertIn("checked: 2026-09-26", got)
        self.assertNotIn("checked: 2026-01-01", got)

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
        (self.rules_root / "abilities" / "SA_10.yaml").write_text(SA_10, encoding="utf-8")
        self.pages_path = self.dir / "pages.yaml"
        patcher = mock.patch.object(rulefiles, "ROOT", self.rules_root)
        patcher.start()
        self.addCleanup(patcher.stop)

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_a_flow_style_source_is_refused_but_a_good_rule_in_the_same_run_still_adopts(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root,
                               adopt_all=True, today=D1)
        self.assertEqual(status, 1)
        text = out.getvalue()
        self.assertIn("cannot adopt SA_20:", text)
        self.assertEqual(text.count("adopted SA_10 ← a.html"), 1)
        got20 = (self.rules_root / "abilities" / "SA_20.yaml").read_text(encoding="utf-8")
        self.assertEqual(got20, SA_20_FLOW, "the unwritable file is left exactly as it was")
        got10 = (self.rules_root / "abilities" / "SA_10.yaml").read_text(encoding="utf-8")
        self.assertNotIn("hash: null", got10)


class AdoptWithoutPatchingRulefilesRootTests(unittest.TestCase):
    """Regression: `set_source_hash(s.path.relative_to(rulefiles.ROOT), ...)` raised `ValueError`
    whenever `rules_root` did not equal `rulefiles.ROOT` -- including the ordinary case where
    nothing patches `rulefiles.ROOT` away from the real `specs/rules`, or `--rules-root` names the
    same directory but spelled relatively. `s.path.resolve()` sidesteps both: an absolute path on
    the right of `ROOT / path` wins outright."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.rules_root = self.dir / "rules"
        (self.rules_root / "abilities").mkdir(parents=True)
        (self.rules_root / "abilities" / "SA_10.yaml").write_text(SA_10, encoding="utf-8")
        self.pages_path = self.dir / "pages.yaml"

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_adopt_works_with_an_unpatched_rulefiles_root(self):
        self.assertNotEqual(rulefiles.ROOT, self.rules_root,
                             "this test is only meaningful when ROOT is left unpatched")
        status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root,
                           adopt_all=True, today=D1)
        self.assertEqual(status, 0)
        got = (self.rules_root / "abilities" / "SA_10.yaml").read_text(encoding="utf-8")
        self.assertNotIn("hash: null", got)

    def test_adopt_works_with_a_relative_rules_root(self):
        rel = Path(os.path.relpath(self.rules_root, Path.cwd()))
        status = sync.run(FakeFetcher(site()), self.pages_path, rel, adopt_all=True, today=D1)
        self.assertEqual(status, 0)
        got = (self.rules_root / "abilities" / "SA_10.yaml").read_text(encoding="utf-8")
        self.assertNotIn("hash: null", got)


class AdoptSkipsARuleWithNoPrimarySourceTests(unittest.TestCase):
    """A rule file with no `source.url` -- only `also[].url` -- must never have an also-page's
    hash written into `source.hash`: `--adopt` skips it silently, `--adopt-ids` reports it and
    fails the run."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.rules_root = self.dir / "rules"
        (self.rules_root / "abilities").mkdir(parents=True)
        (self.rules_root / "abilities" / "SA_40.yaml").write_text(SA_40_NO_PRIMARY, encoding="utf-8")
        self.pages_path = self.dir / "pages.yaml"
        patcher = mock.patch.object(rulefiles, "ROOT", self.rules_root)
        patcher.start()
        self.addCleanup(patcher.stop)

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_adopt_all_skips_it_silently(self):
        status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root,
                           adopt_all=True, today=D1)
        self.assertEqual(status, 0)
        got = (self.rules_root / "abilities" / "SA_40.yaml").read_text(encoding="utf-8")
        self.assertEqual(got, SA_40_NO_PRIMARY)

    def test_adopt_ids_reports_it_and_writes_nothing(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root,
                               adopt_ids=["SA_40"], today=D1)
        self.assertEqual(status, 1)
        self.assertIn("cannot adopt SA_40: no source.url", out.getvalue())
        got = (self.rules_root / "abilities" / "SA_40.yaml").read_text(encoding="utf-8")
        self.assertEqual(got, SA_40_NO_PRIMARY)


class AdoptIdsWhosePageIsNotARuleTests(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.rules_root = self.dir / "rules"
        (self.rules_root / "abilities").mkdir(parents=True)
        (self.rules_root / "abilities" / "SA_50.yaml").write_text(SA_50_INDEX_SOURCE, encoding="utf-8")
        self.pages_path = self.dir / "pages.yaml"
        patcher = mock.patch.object(rulefiles, "ROOT", self.rules_root)
        patcher.start()
        self.addCleanup(patcher.stop)

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_a_named_id_whose_page_is_an_index_returns_1_and_writes_nothing(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root,
                               adopt_ids=["SA_50"], today=D1)
        self.assertEqual(status, 1)
        self.assertIn("is not a current rule page", out.getvalue())
        got = (self.rules_root / "abilities" / "SA_50.yaml").read_text(encoding="utf-8")
        self.assertEqual(got, SA_50_INDEX_SOURCE)


class AdoptOnAGonePageTests(unittest.TestCase):
    """A page that used to be a current `kind: rule` page but is no longer reachable keeps its
    old `kind` and `hash` in the registry and gains `gone: <date>` (`pages.merge`). `adopt()`'s
    `page.get("gone")` check must refuse it exactly like any other non-current page: `--adopt-ids`
    reports and writes nothing, `--adopt` on a null-hash rule silently skips it."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.rules_root = self.dir / "rules"
        (self.rules_root / "abilities").mkdir(parents=True)
        (self.rules_root / "abilities" / "SA_60.yaml").write_text(
            SA_60_ON_A_PAGE_THAT_GOES_AWAY, encoding="utf-8")
        (self.rules_root / "abilities" / "SA_61.yaml").write_text(
            SA_61_NULL_HASH_ON_THE_SAME_PAGE, encoding="utf-8")
        self.pages_path = self.dir / "pages.yaml"
        patcher = mock.patch.object(rulefiles, "ROOT", self.rules_root)
        patcher.start()
        self.addCleanup(patcher.stop)
        # First sync: d.html exists and is a current rule page.
        first = sync.run(FakeFetcher(site_with_d()), self.pages_path, self.rules_root, today=D1)
        self.assertEqual(first, 0)

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_adopt_ids_on_a_gone_page_is_refused_and_writes_nothing(self):
        before = (self.rules_root / "abilities" / "SA_60.yaml").read_text(encoding="utf-8")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            # Second sync: the link to d.html is gone, so its page becomes `gone` in the registry.
            status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root,
                               adopt_ids=["SA_60"], today=D2)
        self.assertEqual(status, 1)
        self.assertIn("cannot adopt SA_60:", out.getvalue())
        reg = pages.read(self.pages_path)
        self.assertEqual(reg.pages["d.html"]["gone"], D2)
        self.assertEqual(reg.pages["d.html"]["kind"], "rule")
        after = (self.rules_root / "abilities" / "SA_60.yaml").read_text(encoding="utf-8")
        self.assertEqual(before, after)

    def test_adopt_all_skips_a_null_hash_rule_on_a_gone_page(self):
        before = (self.rules_root / "abilities" / "SA_61.yaml").read_text(encoding="utf-8")
        status = sync.run(FakeFetcher(site()), self.pages_path, self.rules_root,
                           adopt_all=True, today=D2)
        self.assertEqual(status, 0)
        after = (self.rules_root / "abilities" / "SA_61.yaml").read_text(encoding="utf-8")
        self.assertEqual(before, after)


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

    def test_a_first_sync_says_so_instead_of_since_none(self):
        from rules_sync.resolve import SiteCrawl
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            sync.report(SiteCrawl(), pages.Registry(synced=None), pages.Registry())
        text = out.getvalue()
        self.assertIn("first sync", text)
        self.assertNotIn("since None", text)


if __name__ == "__main__":
    unittest.main()
