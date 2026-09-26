"""check.py: the fetcher's cache and max age; the rule files' sources."""
import datetime
import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

import requests

from rules_sync import check


class FakeResponse:
    def __init__(self, text, status_code=200):
        self.text = text
        self.status_code = status_code

    def raise_for_status(self):
        if self.status_code >= 400:
            raise requests.HTTPError(f"{self.status_code} error", response=self)


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


class ScriptedSession:
    """Answers each GET with the next scripted outcome: an exception instance to raise, or an
    HTTP status code (200 answers with a page)."""

    def __init__(self, *outcomes):
        self.outcomes = list(outcomes)
        self.calls = []

    def get(self, url, headers=None, timeout=None):
        self.calls.append(url)
        outcome = self.outcomes.pop(0)
        if isinstance(outcome, BaseException):
            raise outcome
        return FakeResponse(f"<html>{url}</html>", status_code=outcome)


class RetryTests(unittest.TestCase):
    """Controller ruling R5: a transient failure is retried, up to three attempts in all, with a
    growing pause; a page the site says is not there is its own exception; anything else fails."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        patcher = mock.patch.object(check.time, "sleep")
        self.sleep = patcher.start()
        self.addCleanup(patcher.stop)

    def fetch(self, *outcomes):
        session = ScriptedSession(*outcomes)
        fetcher = check.Fetcher(self.dir, session)
        return fetcher, session

    def test_a_timeout_then_a_page_is_one_network_call(self):
        f, session = self.fetch(requests.Timeout("slow"), 200)
        self.assertEqual(f.get("https://x/a.html"), "<html>https://x/a.html</html>")
        self.assertEqual(len(session.calls), 2)
        self.assertEqual(f.network_calls, 1, "only a successful fetch counts")

    def test_the_pause_grows_with_the_attempt(self):
        f, _ = self.fetch(requests.ConnectionError("reset"), 503, 200)
        f.get("https://x/a.html")
        self.assertEqual([c.args[0] for c in self.sleep.call_args_list],
                          [check.DELAY * 1, check.DELAY * 2, check.DELAY * 3])

    def test_5xx_and_429_are_retried(self):
        for status in (500, 502, 503, 429):
            with self.subTest(status=status):
                f, session = self.fetch(status, 200)
                f.get(f"https://x/{status}.html")
                self.assertEqual(len(session.calls), 2)

    def test_three_failures_raise_the_last_error_and_count_nothing(self):
        f, session = self.fetch(requests.Timeout("1"), requests.Timeout("2"), requests.Timeout("3"))
        with self.assertRaises(requests.Timeout):
            f.get("https://x/a.html")
        self.assertEqual(len(session.calls), 3)
        self.assertEqual(f.network_calls, 0)
        self.assertFalse(f._cache_path("https://x/a.html").exists())

    def test_three_5xx_raise_an_http_error(self):
        f, session = self.fetch(503, 503, 503)
        with self.assertRaises(requests.HTTPError) as ctx:
            f.get("https://x/a.html")
        self.assertNotIsInstance(ctx.exception, check.PageMissing)
        self.assertEqual(len(session.calls), 3)

    def test_404_and_410_are_page_missing_and_not_retried(self):
        for status in (404, 410):
            with self.subTest(status=status):
                f, session = self.fetch(status)
                with self.assertRaises(check.PageMissing):
                    f.get(f"https://x/{status}.html")
                self.assertEqual(len(session.calls), 1)
                self.assertTrue(issubclass(check.PageMissing, requests.HTTPError))

    def test_the_timeout_outlasts_the_sites_slowest_search(self):
        # An unknown detail URL is redirected to the site's search for its name; with a
        # paragraph-long name that search took 29 s on 2026-09-27, three times over the old 15 s.
        seen = []

        class Session(ScriptedSession):
            def get(self, url, headers=None, timeout=None):
                seen.append(timeout)
                return super().get(url, headers, timeout)

        check.Fetcher(self.dir, Session(200)).get("https://x/a.html")
        self.assertEqual(seen, [check.TIMEOUT])
        self.assertGreaterEqual(check.TIMEOUT, 60)

    def test_another_4xx_fails_at_once(self):
        f, session = self.fetch(403)
        with self.assertRaises(requests.HTTPError) as ctx:
            f.get("https://x/a.html")
        self.assertNotIsInstance(ctx.exception, check.PageMissing)
        self.assertEqual(len(session.calls), 1)


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
        self.assertEqual([(s.rule_id, s.url, s.hash, s.primary) for s in got], [
            ("SA_1", "https://dsa.ulisses-regelwiki.de/KSF_Beispiel.html", "sha256:abc", True),
            # An `also` page has no hash of its own: `source.hash` is the primary page's.
            ("SA_1", "https://dsa.ulisses-regelwiki.de/KSF_Zweit.html", None, False),
        ])
        self.assertTrue(got[0].reviewed)
        self.assertTrue(got[1].reviewed)

    def test_a_rule_with_only_also_urls_has_no_primary_source(self):
        root = Path(tempfile.mkdtemp())
        (root / "abilities").mkdir()
        (root / "abilities" / "SA_3.yaml").write_text(
            "id: SA_3\nsource:\n  hash: null\n  also:\n    - { url: https://dsa.ulisses-regelwiki.de/A.html }\n"
            "clauses: []\n", encoding="utf-8")
        got = check.rule_sources(root)
        self.assertEqual([(s.url, s.primary) for s in got],
                          [("https://dsa.ulisses-regelwiki.de/A.html", False)])

    def test_primary_defaults_to_true_for_existing_callers(self):
        self.assertTrue(check.RuleSource("R", Path("r.yaml"), "u", None, False).primary)

    def test_canonical_url_joins_and_drops_the_fragment(self):
        self.assertEqual(check.canonical_url("KSF_Vorsto%C3%9F.html#x"),
                          "https://dsa.ulisses-regelwiki.de/KSF_Vorsto%C3%9F.html")


if __name__ == "__main__":
    unittest.main()
