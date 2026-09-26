"""check.py: the fetcher's cache and max age; the rule files' sources."""
import datetime
import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

from rules_sync import check


class FakeResponse:
    def __init__(self, text):
        self.text = text

    def raise_for_status(self):
        pass


class FakeSession:
    def __init__(self):
        self.calls = []

    def get(self, url, headers=None, timeout=None):
        self.calls.append(url)
        return FakeResponse(f"<html>{url}</html>")


class FetcherTests(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.session = FakeSession()
        patcher = mock.patch.object(check.time, "sleep")
        self.sleep = patcher.start()
        self.addCleanup(patcher.stop)

    def test_a_warm_cache_makes_no_call_without_max_age(self):
        check.Fetcher(self.dir, self.session).get("https://x/a.html")
        f = check.Fetcher(self.dir, self.session)
        f.get("https://x/a.html")
        self.assertEqual(f.network_calls, 0)
        self.assertEqual(len(self.session.calls), 1)

    def test_max_age_zero_fetches_again(self):
        check.Fetcher(self.dir, self.session).get("https://x/a.html")
        f = check.Fetcher(self.dir, self.session, max_age=datetime.timedelta(0))
        f.get("https://x/a.html")
        self.assertEqual(f.network_calls, 1)

    def test_a_young_copy_is_used_an_old_one_is_not(self):
        f = check.Fetcher(self.dir, self.session, max_age=datetime.timedelta(hours=20))
        f.get("https://x/a.html")
        f.get("https://x/b.html")
        old = time.time() - 21 * 3600
        os.utime(f._cache_path("https://x/b.html"), (old, old))
        f2 = check.Fetcher(self.dir, self.session, max_age=datetime.timedelta(hours=20))
        f2.get("https://x/a.html")
        f2.get("https://x/b.html")
        self.assertEqual(f2.network_calls, 1)

    def test_a_real_fetch_sleeps_a_cache_hit_does_not(self):
        f = check.Fetcher(self.dir, self.session)
        f.get("https://x/a.html")
        f.get("https://x/a.html")
        self.assertEqual(self.sleep.call_count, 1)

    def test_second_fetch_of_the_same_url_makes_no_network_call(self):
        # Ported from origin/feat/rules-data-pipeline's
        # test_second_fetch_of_the_same_url_makes_no_network_call: the
        # same Fetcher instance, called twice, hits the network once.
        f = check.Fetcher(self.dir, self.session)
        first = f.get("https://x/a.html")
        second = f.get("https://x/a.html")
        self.assertEqual(first, second)
        self.assertEqual(len(self.session.calls), 1)
        self.assertEqual(f.network_calls, 1)


RULE = """\
id: SA_1
name: Beispiel
kind: specialAbility
source:
  url: https://dsa.ulisses-regelwiki.de/KSF_Beispiel.html#top
  checked: 2026-09-24
  also:
    - { book: Irgendwas, page: 3 }
    - { url: https://dsa.ulisses-regelwiki.de/KSF_Zweit.html }
  hash: sha256:abc
reviewed: { by: "@x", date: 2026-09-25 }
clauses: []
"""


class RuleSourceTests(unittest.TestCase):
    def test_reads_url_also_url_hash_and_reviewed(self):
        root = Path(tempfile.mkdtemp())
        (root / "abilities").mkdir()
        (root / "abilities" / "SA_1.yaml").write_text(RULE, encoding="utf-8")
        (root / "abilities" / "SA_2.yaml").write_text("id: SA_2\nclauses: []\n", encoding="utf-8")
        got = check.rule_sources(root)
        self.assertEqual([(s.rule_id, s.url, s.hash) for s in got], [
            ("SA_1", "https://dsa.ulisses-regelwiki.de/KSF_Beispiel.html", "sha256:abc"),
            ("SA_1", "https://dsa.ulisses-regelwiki.de/KSF_Zweit.html", "sha256:abc"),
        ])
        self.assertTrue(got[0].reviewed)

    def test_canonical_url_joins_and_drops_the_fragment(self):
        self.assertEqual(check.canonical_url("KSF_Vorsto%C3%9F.html#x"),
                          "https://dsa.ulisses-regelwiki.de/KSF_Vorsto%C3%9F.html")


if __name__ == "__main__":
    unittest.main()
