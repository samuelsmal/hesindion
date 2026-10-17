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

from rules_sync import check, resolve
from rules_sync.normalise import hash_html, normalise_html

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

    def test_a_menu_page_with_rule_text_of_its_own_is_a_rule_page(self):
        # GR_Zustand.html (18 menu anchors) carries the rules every Zustand shares, and
        # Kampfregeln.html 12139 characters of text: 105 menu pages of 2026-09-27 had text of
        # their own that no hash watched.
        html = _index([("Belastung", "Sta_Belastung.html"), ("Furcht", "Sta_Furcht.html")],
                      main=f"<h1>Zustände</h1><p>{LONG}</p>")
        kind, text = resolve.classify_page(html)
        self.assertEqual(kind, "rule")
        self.assertIn("Regeltext", text)

    def test_a_menu_page_that_is_mostly_its_links_stays_an_index(self):
        # SF_Erweitertekampfstilsonderfertigkeiten.html: headings and its menu inside #main,
        # 0.61 of the text link text; the closest page with rule text had 0.47.
        links = [(f"Kampftechnik {n}", f"kt{n}.html") for n in range(8)]
        menu = "".join(f'<a class="ulSubMenu" href="{h}">{t}</a>' for t, h in links)
        html = _index(links, main=f"<h1>Erweitert</h1><p>Alle (ungefiltert)</p>{menu}")
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
        site = self.site()
        got = resolve.crawl(FakeFetcher(site))
        a = got.pages[BASE + "a.html"]
        self.assertEqual((a.kind, a.title, a.trail), ("rule", "Regel A", ("Kategorie Eins", "Regel A")))
        self.assertEqual(a.hash, hash_html(site[BASE + "a.html"]))
        self.assertEqual(got.pages[BASE + "b.html"].trail, ("Kategorie Eins", "Unter", "Regel B"))
        self.assertEqual(got.pages[BASE + "kat_eins.html"].kind, "index")
        self.assertIsNone(got.pages[BASE + "kat_eins.html"].hash)
        leer = got.pages[BASE + "leer.html"]
        self.assertEqual(leer.kind, "broken")
        self.assertEqual(leer.detail, resolve.classify_page(site[BASE + "leer.html"])[1])
        self.assertNotIn(BASE, got.pages, "the root is the entry point, not a stored page")
        self.assertFalse([p for p in got.problems if p.fatal])

    def test_max_depth_zero_stops_at_the_top_categories(self):
        got = resolve.crawl(FakeFetcher(self.site()), max_depth=0)
        self.assertTrue(any(p.fatal and "kat_eins.html" in p.detail for p in got.problems))

    def test_a_link_back_to_the_root_is_never_refetched(self):
        # The root's own home link, echoed on every index page, must not send
        # the crawl back to the entry point -- it is never fetched a second
        # time and never recorded in `pages`.
        class CountingFetcher(FakeFetcher):
            def __init__(self, pages):
                super().__init__(pages)
                self.calls = []

            def get(self, url):
                self.calls.append(url)
                return super().get(url)

        site = self.site()
        site[BASE + "kat_eins.html"] = _index(
            [("Home", BASE), ("Unter", "unter.html"), ("Regel A", "a.html")]
        )
        fetcher = CountingFetcher(site)
        got = resolve.crawl(fetcher)
        self.assertNotIn(BASE, got.pages)
        self.assertEqual(fetcher.calls.count(BASE), 1)

    def test_a_missing_page_is_fatal(self):
        site = self.site()
        del site[BASE + "unter.html"]
        got = resolve.crawl(FakeFetcher(site))
        self.assertTrue(any(p.fatal and "unter.html" in p.detail for p in got.problems))

    def test_max_pages_is_fatal(self):
        got = resolve.crawl(FakeFetcher(self.site()), max_pages=3)
        self.assertTrue(any(p.fatal and "stopped" in p.detail for p in got.problems))

    # ADR-0017: a root that cannot be fetched, or has no top menu,
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


def _listing(links, heading="A"):
    """A page shaped like the site's `*auswahl.html` selection pages: plain links in `#main`,
    no `a.ulSubMenu`, under a one-letter heading."""
    anchors = "".join(f'<a href="{h}">{t}</a>' for t, h in links)
    return (f'<html><head><base href="{BASE}"></head><body>'
            f'<div id="main"><h1>{heading}</h1><div>{anchors}</div></div></body></html>')


def _grid(links, filler=""):
    """The site's selection widget: letter blocks (`div.body_einzeln`) in a `div.body` grid."""
    anchors = "".join(f'<a href="{h}">{t}</a>' for t, h in links)
    return (f'<html><head><base href="{BASE}"></head><body><div id="main">'
            f'<div class="filter_einzeln">Publikation [Alle] {filler}</div>'
            f'<div class="body"><div class="body_einzeln"><h1>A</h1></div>{anchors}</div>'
            f'</div></body></html>')


def _rule_with_links(title, text, links):
    anchors = " ".join(f'<a href="{h}">{t}</a>' for t, h in links)
    return (f'<html><head><base href="{BASE}"><title>{title} - DSA Regel-Wiki</title></head>'
            f'<body><div id="main"><h1>{title}</h1><p>{text} {anchors}</p></div></body></html>')


LONG = "Ein ganz gewöhnlicher Regeltext mit vielen Wörtern darin. " * 6


class ListingClassifyTests(unittest.TestCase):
    """ADR-0017: a page whose content container is a list of links is an index, though it
    carries no `a.ulSubMenu`. Calibrated on the cached site (ADR-0017)."""

    def test_a_page_that_is_all_links_is_an_index(self):
        html = _listing([("Eins", "x.html?x=Eins"), ("Zwei", "x.html?x=Zwei"), ("Drei", "x.html?x=Drei")])
        self.assertEqual(resolve.classify_page(html)[0], "index")

    def test_the_selection_grid_is_an_index_however_much_filter_text_it_carries(self):
        links = [(f"Name{i}", f"z.html?z=Name{i}") for i in range(3)]
        html = _grid(links, filler="Regelwerk Aventurische Magie Aventurische Magie II " * 20)
        self.assertLess(resolve.link_text_share(html), 0.5, "the filter text drowns the links")
        self.assertEqual(resolve.classify_page(html)[0], "index")

    def test_a_short_rule_page_with_two_links_stays_a_rule(self):
        html = _rule_with_links("Regel", "Kurz.", [("Eins", "eins.html"), ("Zwei", "zwei.html")])
        self.assertEqual(resolve.classify_page(html)[0], "rule")

    def test_a_rule_page_with_many_links_in_running_text_stays_a_rule(self):
        links = [(f"Verweis{i}", f"v{i}.html") for i in range(5)]
        html = _rule_with_links("Regel", LONG, links)
        self.assertEqual(resolve.classify_page(html)[0], "rule")

    def test_a_link_list_under_the_threshold_stays_a_rule(self):
        # 3 links whose text is well under LISTING_SHARE of the page: a rule page with a
        # "see also" line, not a listing.
        links = [("Eins", "eins.html"), ("Zwei", "zwei.html"), ("Drei", "drei.html")]
        html = _rule_with_links("Regel", "Ein Satz Regeltext, der länger ist als die Verweise.", links)
        self.assertLess(resolve.link_text_share(html), resolve.LISTING_SHARE)
        self.assertEqual(resolve.classify_page(html)[0], "rule")


def _search(links):
    """What the site answers for a detail URL it does not know: its search page, whose results
    link spelling variants of the name."""
    anchors = "".join(f'<div class="even"><a href="{h}">{t}</a> Treffer im Regeltext</div>' for t, h in links)
    return (f'<html><head><base href="{BASE}"><title>Suche - DSA Regel-Wiki</title></head><body>'
            f'<div id="main"><div class="mod_search block"><form action="suche.html">'
            f'<input name="keywords"></form>{anchors}</div></div></body></html>')


class SearchPageTests(unittest.TestCase):
    def test_the_sites_search_page_is_broken_and_says_why(self):
        kind, detail = resolve.classify_page(_search([("x", "x.html?x=a"), ("y", "x.html?x=b"), ("z", "z.html")]))
        self.assertEqual(kind, "broken")
        self.assertIn("search page", detail)

    def test_a_search_pages_results_are_not_followed(self):
        site = {
            BASE: (FIXTURES / "site_root.html").read_text(encoding="utf-8"),
            BASE + "kat_eins.html": _grid([("Eins", "x.html?x=Eins"), ("Zwei", "x.html?x=Zwei"),
                                           ("Unbekannt", "x.html?x=Unbekannt")]),
            BASE + "x.html?x=Eins": _rule("Eins", "Text Eins"),
            BASE + "x.html?x=Zwei": _rule("Zwei", "Text Zwei"),
            BASE + "x.html?x=Unbekannt": _search([("eins", "x.html?x=eins")]),
            BASE + "kat_zwei.html": _index([]),
        }
        got = resolve.crawl(FakeFetcher(site))
        self.assertFalse(got.fatal_problems, got.problems)
        self.assertEqual(got.pages[BASE + "x.html?x=Unbekannt"].kind, "broken")
        self.assertNotIn(BASE + "x.html?x=eins", got.pages)


class ContentLinksTests(unittest.TestCase):
    def test_keeps_the_query_byte_for_byte_and_skips_what_is_not_a_page(self):
        html = _listing([
            ("Angst", "zauber.html?zauber=Angst+ausl%C3%B6sen"),
            ("Mail", "mailto:someone@example.org"),
            ("Anker", "#oben"),
            ("Skript", "javascript:void(0)"),
            ("Fremd", "https://example.org/x.html"),
            ("Heft", "files/regeln.pdf"),
            ("Bild", "bilder/karte.png"),
            ("Leer", ""),
            ("Angst", "zauber.html?zauber=Angst+ausl%C3%B6sen#top"),
        ])
        self.assertEqual(resolve.content_links(html, BASE + "zauberauswahl.html"),
                          [("Angst", BASE + "zauber.html?zauber=Angst+ausl%C3%B6sen")])

    def test_joins_against_the_declared_base_not_the_page(self):
        html = _listing([("Tier", "vor-und-nachteile/tier.html")])
        self.assertEqual(resolve.content_links(html, BASE + "vor-und-nachteile/x.html"),
                          [("Tier", BASE + "vor-und-nachteile/tier.html")])


class ContentLinkCrawlTests(unittest.TestCase):
    def site(self):
        root = (FIXTURES / "site_root.html").read_text(encoding="utf-8")
        return {
            BASE: root,
            # Kategorie Eins is a selection page: plain #main links in the selection grid, one
            # with a query, beside links that name no page of the site.
            BASE + "kat_eins.html": _grid([
                ("Ablativum", "zauber.html?zauber=Ablativum"),
                ("Angst", "zauber.html?zauber=Angst+ausl%C3%B6sen"),
                ("Regel A", "a.html"),
                ("Mail", "mailto:x@example.org"),
                ("Fremd", "https://example.org/y.html"),
                ("Heft", "regeln.pdf"),
            ]),
            BASE + "zauber.html?zauber=Ablativum": _rule("Ablativum", "Text Abl"),
            BASE + "zauber.html?zauber=Angst+ausl%C3%B6sen": _rule("Angst", "Text Angst"),
            # A rule page whose #main cross-links to another rule page nothing else lists.
            BASE + "a.html": _rule_with_links("Regel A", LONG, [("Regel Q", "q.html")]),
            BASE + "q.html": _rule("Regel Q", "Text Q"),
            BASE + "kat_zwei.html": _index([("Regel C", "c.html")]),
            BASE + "c.html": _rule("Regel C", "Text C"),
        }

    def test_a_listing_is_an_index_and_its_query_children_are_crawled_as_they_are_written(self):
        got = resolve.crawl(FakeFetcher(self.site()))
        self.assertFalse(got.fatal_problems, got.problems)
        self.assertEqual(got.pages[BASE + "kat_eins.html"].kind, "index")
        angst = got.pages[BASE + "zauber.html?zauber=Angst+ausl%C3%B6sen"]
        self.assertEqual((angst.kind, angst.trail), ("rule", ("Kategorie Eins", "Angst")))
        self.assertIn(BASE + "zauber.html?zauber=Ablativum", got.pages)

    def test_a_rule_pages_cross_link_is_followed(self):
        got = resolve.crawl(FakeFetcher(self.site()))
        q = got.pages[BASE + "q.html"]
        self.assertEqual((q.kind, q.trail), ("rule", ("Kategorie Eins", "Regel A", "Regel Q")))

    def test_an_index_path_wins_over_a_shorter_cross_reference(self):
        # c2.html is one cross-reference below a rule page at depth 1 (a.html), and two index
        # steps below Kategorie Zwei. The site's own index trail is the one recorded: a cross-
        # reference only finds pages no index leads to.
        site = self.site()
        site[BASE + "a.html"] = _rule_with_links("Regel A", LONG, [("Regel Q", "q.html"), ("Verweis", "c2.html")])
        site[BASE + "kat_zwei.html"] = _index([("Unter", "unter2.html")])
        site[BASE + "unter2.html"] = _index([("Regel C2", "c2.html")])
        site[BASE + "c2.html"] = _rule("Regel C2", "Text C2")
        got = resolve.crawl(FakeFetcher(site))
        self.assertFalse(got.fatal_problems, got.problems)
        self.assertEqual(got.pages[BASE + "c2.html"].trail, ("Kategorie Zwei", "Unter", "Regel C2"))
        self.assertEqual(got.pages[BASE + "q.html"].trail, ("Kategorie Eins", "Regel A", "Regel Q"))

    def test_a_menu_pages_intro_text_links_are_cross_references(self):
        # Kategorie Zwei is a menu index whose #main intro text links c2.html; its own menu
        # reaches c2.html only two steps down. The menu trail is the one recorded -- the intro
        # link is followed (c3.html, which nothing else lists, is found) but does not re-home.
        site = self.site()
        site[BASE + "kat_zwei.html"] = _index(
            [("Unter", "unter2.html")],
            main='<p>Siehe <a href="c2.html">Zustand</a> und <a href="c3.html">Sonst</a>.</p>')
        site[BASE + "unter2.html"] = _index([("Regel C2", "c2.html")])
        site[BASE + "c2.html"] = _rule("Regel C2", "Text C2")
        site[BASE + "c3.html"] = _rule("Regel C3", "Text C3")
        got = resolve.crawl(FakeFetcher(site))
        self.assertFalse(got.fatal_problems, got.problems)
        self.assertEqual(got.pages[BASE + "c2.html"].trail, ("Kategorie Zwei", "Unter", "Regel C2"))
        self.assertEqual(got.pages[BASE + "c3.html"].trail, ("Kategorie Zwei", "Sonst"))

    def test_mail_offsite_and_pdf_links_are_never_fetched(self):
        class Recording(FakeFetcher):
            calls = []

            def get(self, url):
                self.calls.append(url)
                return super().get(url)

        fetcher = Recording(self.site())
        fetcher.calls = []
        resolve.crawl(fetcher)
        self.assertFalse([u for u in fetcher.calls if "mailto" in u or "example.org" in u or u.endswith(".pdf")])

    def test_a_page_the_site_says_is_missing_is_a_note_and_left_out(self):
        class Missing(FakeFetcher):
            def get(self, url):
                if url == BASE + "q.html":
                    raise check.PageMissing(f"404 page missing: {url}")
                return super().get(url)

        got = resolve.crawl(Missing(self.site()))
        self.assertNotIn(BASE + "q.html", got.pages)
        self.assertFalse(got.fatal_problems)
        self.assertTrue(any(not p.fatal and "q.html" in p.detail for p in got.problems))

    def test_max_depth_is_twenty(self):
        self.assertEqual(resolve.MAX_DEPTH, 20)

    def test_a_rule_page_at_max_depth_with_nothing_new_to_follow_is_not_fatal(self):
        site = self.site()
        site[BASE + "q.html"] = _rule_with_links("Regel Q", LONG, [("Regel A", "a.html")])
        got = resolve.crawl(FakeFetcher(site), max_depth=2)
        self.assertFalse(got.fatal_problems, got.problems)

    def test_a_page_at_max_depth_with_new_links_is_fatal(self):
        got = resolve.crawl(FakeFetcher(self.site()), max_depth=1)
        self.assertTrue(any(p.fatal and "a.html" in p.detail and "max depth" in p.detail
                             for p in got.problems))


class TopCategoryGuardTests(unittest.TestCase):
    """A top category read as a rule page is how whole categories went missing. It is fatal
    when it leaves the crawl nothing to follow; when it links on, the links are followed and
    the reading is noted."""

    def site(self, kat_eins):
        return {
            BASE: (FIXTURES / "site_root.html").read_text(encoding="utf-8"),
            BASE + "kat_eins.html": kat_eins,
            BASE + "kat_zwei.html": _index([("Regel C", "c.html")]),
            BASE + "c.html": _rule("Regel C", "Text C"),
            BASE + "v.html": _rule("Vorteile", "Text V"),
        }

    def test_a_top_category_read_as_a_dead_end_rule_page_is_fatal_and_named(self):
        got = resolve.crawl(FakeFetcher(self.site(_rule("Kategorie Eins", LONG))))
        self.assertTrue(any(p.fatal and "kat_eins.html" in p.detail and "top category" in p.detail
                             for p in got.problems), got.problems)

    def test_a_top_category_with_rule_text_and_links_is_followed_and_noted(self):
        page = _rule_with_links("Kategorie Eins", LONG, [("Vorteile", "v.html")])
        got = resolve.crawl(FakeFetcher(self.site(page)))
        self.assertFalse(got.fatal_problems, got.problems)
        self.assertIn(BASE + "v.html", got.pages)
        self.assertTrue(any(not p.fatal and "kat_eins.html" in p.detail and "top category" in p.detail
                             for p in got.problems))


class CandidateTests(unittest.TestCase):
    def test_near_titles_are_offered(self):
        self.assertEqual(
            resolve.candidates("Wuchtschlag", ["Wuchtschlag I-III", "Finte"]),
            ["Wuchtschlag I-III"],
        )


if __name__ == "__main__":
    unittest.main()
