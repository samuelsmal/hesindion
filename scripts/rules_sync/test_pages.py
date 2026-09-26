"""pages.py: merge keeps skips and dates; the file round-trips."""
import datetime
import unittest

from rulec import layout
from rules_sync import pages
from rules_sync.resolve import CrawledPage, Problem, SiteCrawl

B = "https://dsa.ulisses-regelwiki.de/"
D1, D2 = datetime.date(2026, 9, 26), datetime.date(2026, 10, 3)


def crawl(*items, problems=()):
    c = SiteCrawl()
    for key, kind, h, trail in items:
        c.pages[B + key] = CrawledPage(B + key, kind, key.split(".")[0], h, tuple(trail.split(" / ")))
    c.problems.extend(problems)
    return c


class MergeTests(unittest.TestCase):
    def test_fetched_moves_only_when_the_hash_changes(self):
        r1 = pages.merge(pages.Registry(), crawl(("a.html", "rule", "sha256:1", "K / a"),
                                                  ("b.html", "rule", "sha256:2", "K / b")), D1)
        r2 = pages.merge(r1, crawl(("a.html", "rule", "sha256:1", "K / a"),
                                   ("b.html", "rule", "sha256:9", "K / b")), D2)
        self.assertEqual(r2.pages["a.html"]["fetched"], D1)
        self.assertEqual(r2.pages["b.html"]["fetched"], D2)
        self.assertEqual(r2.synced, D2)

    def test_a_missing_page_is_gone_and_comes_back(self):
        r1 = pages.merge(pages.Registry(), crawl(("a.html", "rule", "sha256:1", "K / a")), D1)
        r2 = pages.merge(r1, crawl(), D2)
        self.assertEqual(r2.pages["a.html"]["gone"], D2)
        r3 = pages.merge(r2, crawl(("a.html", "rule", "sha256:1", "K / a")), D2)
        self.assertNotIn("gone", r3.pages["a.html"])

    def test_skips_survive(self):
        r1 = pages.merge(pages.Registry(), crawl(("a.html", "rule", "sha256:1", "K / a")), D1)
        r1.pages["a.html"]["skip"] = "not a rule"
        r1.skip["K"] = "whole category"
        r2 = pages.merge(r1, crawl(("a.html", "rule", "sha256:1", "K / a")), D2)
        self.assertEqual(r2.pages["a.html"]["skip"], "not a rule")
        self.assertEqual(r2.skip, {"K": "whole category"})

    def test_a_fatal_crawl_is_refused(self):
        with self.assertRaises(ValueError):
            pages.merge(pages.Registry(), crawl(problems=[Problem(True, "x: fetch failed")]), D1)


class SkipTests(unittest.TestCase):
    def test_page_skip_then_longest_trail_prefix(self):
        r = pages.merge(pages.Registry(), crawl(("a.html", "rule", "sha256:1", "A / B / a"),
                                                ("c.html", "rule", "sha256:3", "A / Bx / c")), D1)
        r.skip.update({"A": "outer", "A / B": "inner"})
        self.assertEqual(r.skip_reason("a.html"), "inner")
        self.assertEqual(r.skip_reason("c.html"), "outer")
        r.pages["a.html"]["skip"] = "own"
        self.assertEqual(r.skip_reason("a.html"), "own")


class FileTests(unittest.TestCase):
    def test_round_trip_and_one_line_per_page(self):
        r = pages.merge(pages.Registry(), crawl(("b.html", "rule", "sha256:2", "K: x / b"),
                                                ("a.html", "index", None, "K: x")), D1)
        r.skip["K: x"] = "a reason: with a colon"
        text = pages.dump(r)
        self.assertEqual(pages.dump(pages.load(text)), text)
        body = text.split("pages:\n", 1)[1].splitlines()
        self.assertEqual([l.split(":")[0].strip() for l in body], ["a.html", "b.html"])

    def test_round_trip_survives_german_titles_and_quoting(self):
        # Real titles and trails carry German characters, colons, apostrophes,
        # `/` and `-`. This one page's title alone has an umlaut, an
        # apostrophe, a colon-space and a leading `-`, all at once.
        title = "-Härte's Stunde: Regel"
        c = SiteCrawl()
        c.pages[B + "s.html"] = CrawledPage(B + "s.html", "rule", title, "sha256:7", ("A", "B / C"))
        r = pages.merge(pages.Registry(), c, D1)
        text = pages.dump(r)
        self.assertEqual(pages.dump(pages.load(text)), text)
        self.assertEqual(pages.load(text).pages["s.html"]["title"], title)

    def test_pages_yaml_is_not_a_rule_file(self):
        self.assertNotIn(layout.ROOT / "pages.yaml", layout.rule_files(layout.ROOT))


if __name__ == "__main__":
    unittest.main()
