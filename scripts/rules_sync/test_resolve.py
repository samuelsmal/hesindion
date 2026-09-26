"""Tests for scripts/rules_sync/resolve.py.

Two families. The first ports the branch's tests of the functions this module
keeps unchanged (`normalise_name`/`_fold`, `index_anchors`, `classify_page`),
against the same `fixtures/index_*.html`/`rule_*.html` used by
`test_normalise.py`. The dropped branch tests -- `follow_trail`, the old
per-group `crawl`, the identity signals, publications, `load_targets`,
`render_report`, `write_map`, `run`/`main` -- exercised functions this task
does not port; see task-3-report.md for the full list.

The second is new: `root_categories` and the site-wide `crawl`, against
`fixtures/site_root.html` and a small synthetic index/rule site built inline
(`_index`/`_rule`), including the controller's ruling that a root which
cannot be fetched, or has no top menu, is a fatal `Problem` rather than a
raised exception.
"""
from __future__ import annotations

import pathlib
import unittest

import requests

from rules_sync import resolve
from rules_sync.normalise import normalise_html

FIXTURES = pathlib.Path(__file__).parent / "fixtures"


# ── name reduction (ported) ─────────────────────────────────────────────────

class NormaliseNameTests(unittest.TestCase):
    def test_makes_the_site_and_the_seed_spellings_compare_equal(self):
        # Every string here is a placeholder, not an ability name (Data
        # Policy, AGENTS.md). What is real is the *shape*: a ladder suffix, an
        # en dash, a typographic apostrophe, doubled whitespace and an eszett
        # all occur in the site's anchor texts, and each is what the case is
        # here to exercise.
        cases = [
            ("Platzhalter-Eins I-III", "Platzhalter-Eins"),
            ("Platzhalter Zwei Worte I-II", "Platzhalter Zwei Worte"),
            ("Platzhalter-Drei I", "Platzhalter-Drei"),
            ("Platzhalter-Vier I–II", "Platzhalter-Vier"),  # en dash, as the site mixes them
            ("Platzhalter’Fünf-Stil", "Platzhalter'Fünf-Stil"),  # typographic vs plain apostrophe
            ("  Doppelte   Leerzeichen ", "Doppelte Leerzeichen"),
            ("PLATZHALTER", "platzhalter"),
        ]
        for left, right in cases:
            with self.subTest(left=left, right=right):
                self.assertEqual(resolve.normalise_name(left), resolve.normalise_name(right))

    def test_keeps_genuinely_different_names_apart(self):
        self.assertNotEqual(resolve.normalise_name("Platzhalter"), resolve.normalise_name("Platzhaltar"))
        self.assertNotEqual(resolve.normalise_name("Platzhalter-Gruß"), resolve.normalise_name("Platzhalter-Grüße"))
        self.assertNotEqual(resolve.normalise_name("Platzhalter-Stil"), resolve.normalise_name("Platzhalter Stil"))

    def test_folds_eszett_the_way_casefold_does(self):
        # `str.casefold` maps ß to ss, so the two spellings of an eszett name
        # compare equal.
        self.assertEqual(resolve.normalise_name("Platzhalter-Gruß"), resolve.normalise_name("Platzhalter-Gruss"))


# ── index pages are their own path (ported) ─────────────────────────────────

class IndexAnchorsTests(unittest.TestCase):
    def test_reads_text_and_href_and_collapses_the_mobile_copy(self):
        html = (FIXTURES / "index_category.html").read_text(encoding="utf-8")
        anchors = resolve.index_anchors(html)
        self.assertIn(("Platzhalter-Eins", "PH_Eins.html"), anchors)
        self.assertEqual(
            [a for a in anchors if a[0] == "Platzhalter-Eins"],
            [("Platzhalter-Eins", "PH_Eins.html")],
        )
        # Two different pages under one name stay two anchors: that is
        # ambiguity, not duplication.
        self.assertEqual(
            sorted(h for t, h in anchors if t == "Platzhalter-Doppel"),
            ["PH_DoppelA.html", "PH_DoppelB.html"],
        )

    def test_ignores_a_rule_page(self):
        html = (FIXTURES / "rule_i_publication.html").read_text(encoding="utf-8")
        self.assertEqual(resolve.index_anchors(html), [])


class ClassifyPageTests(unittest.TestCase):
    def test_separates_indexes_from_rule_pages(self):
        cases = [
            ("index_category.html", "index"),
            ("index_subcategory.html", "index"),
            ("index_inline.html", "index"),
            ("rule_i_publication.html", "rule"),
            ("rule_l_nested_style.html", "rule"),
        ]
        for fixture, kind in cases:
            with self.subTest(fixture=fixture):
                html = (FIXTURES / fixture).read_text(encoding="utf-8")
                self.assertEqual(resolve.classify_page(html)[0], kind)

    def test_reports_a_page_with_neither_rule_text_nor_anchors(self):
        # Models the real pages whose #main is present and empty with no link
        # list either -- a property of the site, not a failure of the crawl.
        kind, detail = resolve.classify_page(
            (FIXTURES / "rule_h_empty_container.html").read_text(encoding="utf-8")
        )
        self.assertEqual(kind, "broken")
        self.assertIn("empty content container", detail)

    def test_an_index_whose_main_is_not_empty_is_still_an_index(self):
        # index_inline.html normalises to text, because its link list sits
        # inside a non-empty #main rather than outside it. The anchors, not
        # the content container, are what decide.
        html = (FIXTURES / "index_inline.html").read_text(encoding="utf-8")
        self.assertTrue(normalise_html(html), "this page does yield text, unlike its siblings")
        self.assertEqual(resolve.classify_page(html)[0], "index")


# ── the site-wide crawl (new) ────────────────────────────────────────────────

class FakeFetcher:
    """Serves a dict of url -> html; anything else raises like requests would."""

    def __init__(self, pages):
        self.pages = pages
        self.network_calls = 0

    def get(self, url):
        if url not in self.pages:
            raise requests.HTTPError(f"404 {url}")
        return self.pages[url]


BASE = "https://dsa.ulisses-regelwiki.de/"


def _index(links, main=""):
    anchors = "".join(f'<a class="ulSubMenu" href="{h}">{t}</a>' for t, h in links)
    return (f'<html><head><base href="{BASE}"></head><body>'
            f'<div id="sub_header"><nav class="mod_navigation">{anchors}</nav></div>'
            f'<div id="main">{main}</div></body></html>')


def _rule(title, text):
    return (f'<html><head><base href="{BASE}"><title>{title} - DSA Regel-Wiki</title></head>'
            f'<body><div id="main"><h1>{title}</h1><p>{text}</p></div></body></html>')


class RootCategoryTests(unittest.TestCase):
    def test_reads_the_top_menu_same_site_only(self):
        html = (FIXTURES / "site_root.html").read_text(encoding="utf-8")
        self.assertEqual(resolve.root_categories(html, BASE), [
            ("Kategorie Eins", BASE + "kat_eins.html"),
            ("Kategorie Zwei", BASE + "kat_zwei.html"),
        ])

    def test_no_menu_is_an_error(self):
        with self.assertRaises(LookupError):
            resolve.root_categories("<html><body></body></html>", BASE)


class CrawlTests(unittest.TestCase):
    def site(self):
        root = (FIXTURES / "site_root.html").read_text(encoding="utf-8")
        return {
            BASE: root,
            BASE + "kat_eins.html": _index([("Unter", "unter.html"), ("Regel A", "a.html")]),
            BASE + "unter.html": _index([("Regel B", "b.html"), ("Regel A", "a.html")]),
            BASE + "a.html": _rule("Regel A", "Text A"),
            BASE + "b.html": _rule("Regel B", "Text B"),
            BASE + "kat_zwei.html": _index([("Leer", "leer.html")]),
            BASE + "leer.html": '<html><body><div id="main"></div></body></html>',
        }

    def test_every_page_with_kind_trail_and_hash(self):
        got = resolve.crawl(FakeFetcher(self.site()))
        a = got.pages[BASE + "a.html"]
        self.assertEqual((a.kind, a.title, a.trail), ("rule", "Regel A", ("Kategorie Eins", "Regel A")))
        self.assertTrue(a.hash.startswith("sha256:"))
        self.assertEqual(got.pages[BASE + "b.html"].trail, ("Kategorie Eins", "Unter", "Regel B"))
        self.assertEqual(got.pages[BASE + "kat_eins.html"].kind, "index")
        self.assertIsNone(got.pages[BASE + "kat_eins.html"].hash)
        self.assertEqual(got.pages[BASE + "leer.html"].kind, "broken")
        self.assertFalse([p for p in got.problems if p.fatal])

    def test_a_missing_page_is_fatal(self):
        site = self.site()
        del site[BASE + "unter.html"]
        got = resolve.crawl(FakeFetcher(site))
        self.assertTrue(any(p.fatal and "unter.html" in p.detail for p in got.problems))

    def test_max_pages_is_fatal(self):
        got = resolve.crawl(FakeFetcher(self.site()), max_pages=3)
        self.assertTrue(any(p.fatal and "stopped" in p.detail for p in got.problems))

    # Controller ruling R1: a root that cannot be fetched, or has no top menu,
    # is a fatal Problem naming the root URL and the reason -- crawl() must
    # not raise either exception itself.

    def test_a_root_that_cannot_be_fetched_is_fatal_not_raised(self):
        class FailingFetcher:
            network_calls = 0

            def get(self, url):
                raise requests.ConnectionError("simulated network failure")

        got = resolve.crawl(FailingFetcher(), root_url=BASE)
        self.assertEqual(got.pages, {})
        self.assertTrue(any(p.fatal and BASE in p.detail and "simulated network failure" in p.detail
                             for p in got.problems))

    def test_a_root_with_no_top_menu_is_fatal_not_raised(self):
        got = resolve.crawl(FakeFetcher({BASE: "<html><body></body></html>"}), root_url=BASE)
        self.assertEqual(got.pages, {})
        self.assertTrue(any(p.fatal and BASE in p.detail and "no top menu" in p.detail
                             for p in got.problems))


class CandidateTests(unittest.TestCase):
    def test_near_titles_are_offered(self):
        self.assertEqual(
            resolve.candidates("Wuchtschlag", ["Wuchtschlag I-III", "Finte"]),
            ["Wuchtschlag I-III"],
        )


if __name__ == "__main__":
    unittest.main()
