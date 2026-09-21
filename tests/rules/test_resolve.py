"""Task 10: resolve every combat rule to its page on the rule website, by name.

The suite runs entirely against the synthetic fixture site under
`tests/rules/fixtures/` -- `index_*.html` for the index pages and `rule_i`..
`rule_n` for the leaves. None of it is a capture of a real page: the Data
Policy (AGENTS.md) keeps rule prose and ability names out of git, and the
fixtures are modelled on the real markup *structure* only.

The fixture site is three levels deep and deliberately awkward in the same four
ways the real one is: an anchor text that carries a Stufen ladder the rule's
name does not, a percent-encoded href, one name published at two URLs, and a
rule that is only reachable two index levels down at a lowercase-hyphenated
path in its own directory. That last one is the whole argument for the task --
nothing about a rule's id or name produces that URL, so it must come from the
site's own anchor.
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest
import requests
import yaml

from scripts.rules_sync import check as sync_check
from scripts.rules_sync import resolve
from scripts.rules_sync.normalise import ContentContainerEmpty, normalise_html

FIXTURES = Path(__file__).parent / "fixtures"
BASE = "https://wiki.invalid/"

#: The fixture site. Keys are paths under BASE, values are fixture files.
SITE = {
    "frefre.html": "index_root.html",
    "ph_kategorie.html": "index_category.html",
    "ph_stile.html": "index_nested.html",
    "ph_stile/unterkategorie.html": "index_subcategory.html",
    "ph_erweitert.html": "index_inline.html",
    "ph_stile/unterkategorie/platzhalter-stil.html": "rule_l_nested_style.html",
    "PH_Eins.html": "rule_i_publication.html",
    "PH_Zwei.html": "rule_j_ladder_title.html",
    "PH_Drei.html": "rule_k_publication_drift.html",
    "PH_Gru%C3%9F.html": "rule_m_umlaut_slug.html",
    "PH_DoppelA.html": "rule_n_doppel.html",
    "PH_DoppelB.html": "rule_n_doppel.html",
    "PH_Qual.html": "rule_n_doppel.html",
}

TRAIL = {
    3: ("Platzhalter-Kategorie",),
    9: ("Platzhalter-Stile",),
    11: ("Platzhalter-Erweitert",),
}


class FakeFetcher:
    """`check.Fetcher`'s interface, served from disk with no network and no
    sleep. `network_calls` counts distinct URLs so a test can assert the same
    page is not fetched twice within a run."""

    def __init__(self, site=None):
        self.site = dict(site if site is not None else SITE)
        self.requested: list[str] = []
        self.network_calls = 0

    def get(self, url: str) -> str:
        self.requested.append(url)
        assert url.startswith(BASE), f"crawl left the fixture site: {url}"
        path = url[len(BASE):]
        if path not in self.site:
            raise AssertionError(f"fixture site has no page at {path!r}")
        if self.requested.count(url) == 1:
            self.network_calls += 1
        return (FIXTURES / self.site[path]).read_text(encoding="utf-8")


def target(rule_id, name, group_id, text, book, page):
    return resolve.RuleTarget(rule_id, name, group_id, text, ((book, page),))


#: Seed rules for the fixture site. The `text` of each is a subset of its
#: page's rule paragraph, as an Optolith seed is of the wiki's copy.
TARGETS = [
    target("PH_1", "Platzhalter-Eins", 3,
           "Der Platzhalter erhoeht den erfundenen Beispielwert um zwei Punkte.",
           "Platzhalter-Regelwerk", 42),
    target("PH_2", "Platzhalter-Zwei", 3,
           "Der Platzhalter senkt den erfundenen Beispielwert um zwei Punkte pro Stufe.",
           "Platzhalter-Regelwerk", 43),
    target("PH_3", "Platzhalter-Drei", 3,
           "Der Platzhalter verschiebt den erfundenen Beispielwert einmal pro Platzhalter-Runde.",
           "Platzhalter-Regelwerk", 44),
    target("PH_4", "Platzhalter-Gruß", 3,
           "Der Platzhalter ruecke um eine erfundene Beispielstrecke vor.",
           "Platzhalter-Regelwerk", 45),
    target("PH_5", "Platzhalter-Doppel", 3,
           "Der Platzhalter erscheint zweimal im Platzhalter-Verzeichnis.",
           "Platzhalter-Regelwerk", 50),
    target("PH_6", "Platzhalter-Eins-und-Zwei", 3,
           "Diese Platzhalter-Regel steht auf keiner Platzhalter-Uebersicht.",
           "Platzhalter-Regelwerk", 60),
    target("PH_8", "Platzhalter-Qualifiziert", 3,
           "Diese Platzhalter-Regel traegt auf der Uebersicht einen Zusatz.",
           "Platzhalter-Regelwerk", 70),
    target("PH_7", "Platzhalter-Stil", 9,
           "Der Platzhalter-Stil gewaehrt dem Platzhalter einen erfundenen Beispielvorteil.",
           "Platzhalter-Kompendium", 21),
]


def crawl_fixture_site(fetcher=None):
    fetcher = fetcher or FakeFetcher()
    crawls = {}
    for group_id, trail in TRAIL.items():
        index_url = resolve.follow_trail(fetcher, BASE + "frefre.html", trail)
        crawls[group_id] = resolve.crawl(fetcher, index_url, group_id)
    return fetcher, crawls


def resolve_fixture_site():
    fetcher, crawls = crawl_fixture_site()
    return {r.rule_id: r for r in resolve.resolve_targets(TARGETS, crawls, fetcher)}, crawls


# ── name reduction ───────────────────────────────────────────────────────────

# Every string below is a placeholder, not an ability name (Data Policy,
# AGENTS.md). What is real is the *shape*: a ladder suffix, an en dash, a
# typographic apostrophe, doubled whitespace and an eszett all occur in the
# site's anchor texts, and each is what the case is here to exercise.
@pytest.mark.parametrize("left, right", [
    ("Platzhalter-Eins I-III", "Platzhalter-Eins"),
    ("Platzhalter Zwei Worte I-II", "Platzhalter Zwei Worte"),
    ("Platzhalter-Drei I", "Platzhalter-Drei"),
    ("Platzhalter-Vier I–II", "Platzhalter-Vier"),        # en dash, as the site mixes them
    ("Platzhalter’Fünf-Stil", "Platzhalter'Fünf-Stil"),   # typographic vs plain apostrophe
    ("  Doppelte   Leerzeichen ", "Doppelte Leerzeichen"),
    ("PLATZHALTER", "platzhalter"),
])
def test_normalise_name_makes_the_site_and_the_seed_spellings_compare_equal(left, right):
    """The site titles a laddered ability `<name> I-III` and the seed names it
    without the ladder. Without this reduction every laddered rule in the
    corpus -- a large minority of the combat groups -- reports as unresolved."""
    assert resolve.normalise_name(left) == resolve.normalise_name(right)


def test_normalise_name_keeps_genuinely_different_names_apart():
    assert resolve.normalise_name("Platzhalter") != resolve.normalise_name("Platzhaltar")
    assert resolve.normalise_name("Platzhalter-Gruß") != resolve.normalise_name("Platzhalter-Grüße")
    assert resolve.normalise_name("Platzhalter-Stil") != resolve.normalise_name("Platzhalter Stil")


def test_normalise_name_folds_eszett_the_way_casefold_does():
    """`str.casefold` maps ß to ss, so the two spellings of an eszett name
    compare equal. That is recorded here rather than worked around: no two
    abilities in the combat groups differ only in that spelling, and the *URL*
    is still taken from the site's own percent-encoded href, never respelled
    from the folded name -- `test_a_percent_encoded_href_resolves_to_exactly_what_the_site_publishes`
    is the guard on that."""
    assert resolve.normalise_name("Platzhalter-Gruß") == resolve.normalise_name("Platzhalter-Gruss")


# ── index pages are their own path ───────────────────────────────────────────

@pytest.mark.parametrize("fixture", [
    "index_root.html", "index_category.html",
    "index_nested.html", "index_subcategory.html",
])
def test_normalise_html_raises_on_every_index_fixture_by_design(fixture):
    """Acceptance criterion 2, asserted rather than assumed: an index page's
    `#main` is empty and its link list sits outside it, so the normaliser
    raises. That is correct behaviour (Task 5 fix round 4) and the reason index
    pages are parsed on their own path instead of through `normalise_html`."""
    with pytest.raises(ContentContainerEmpty):
        normalise_html((FIXTURES / fixture).read_text(encoding="utf-8"))


def test_index_anchors_reads_text_and_href_and_collapses_the_mobile_copy():
    """The site prints its link list twice, once for the mobile menu. The
    second copy must not become a second candidate for the same name."""
    html = (FIXTURES / "index_category.html").read_text(encoding="utf-8")
    anchors = resolve.index_anchors(html)
    assert ("Platzhalter-Eins", "PH_Eins.html") in anchors
    assert [a for a in anchors if a[0] == "Platzhalter-Eins"] == [
        ("Platzhalter-Eins", "PH_Eins.html")
    ]
    # Two different pages under one name stay two anchors: that is ambiguity,
    # not duplication, and it must survive to be reported.
    assert sorted(h for t, h in anchors if t == "Platzhalter-Doppel") == [
        "PH_DoppelA.html", "PH_DoppelB.html"
    ]


def test_index_anchors_ignores_a_rule_page():
    """A rule page carries none of these anchors, which is what makes the
    classification below unambiguous."""
    html = (FIXTURES / "rule_i_publication.html").read_text(encoding="utf-8")
    assert resolve.index_anchors(html) == []


@pytest.mark.parametrize("fixture, kind", [
    ("index_category.html", "index"),
    ("index_subcategory.html", "index"),
    ("index_inline.html", "index"),
    ("rule_i_publication.html", "rule"),
    ("rule_l_nested_style.html", "rule"),
])
def test_classify_page_separates_indexes_from_rule_pages(fixture, kind):
    assert resolve.classify_page(
        (FIXTURES / fixture).read_text(encoding="utf-8")
    )[0] == kind


def test_classify_page_reports_a_page_with_neither_rule_text_nor_anchors():
    """`rule_h_empty_container.html` models the five real pages Task 5 fix round
    4 found whose `#main` is present and empty with no link list either. That is
    a property of the site, not a failure of the crawl -- so it is classified
    `broken`, reported with the normaliser's own message, and yields no entry."""
    kind, detail = resolve.classify_page(
        (FIXTURES / "rule_h_empty_container.html").read_text(encoding="utf-8")
    )
    assert kind == "broken"
    assert "empty content container" in detail


def test_an_index_whose_main_is_not_empty_is_still_an_index():
    """`index_inline.html` normalises to text, because its link list sits
    inside a non-empty `#main` rather than outside it. Classifying by the
    content container alone files it as a rule page and never descends -- the
    first live run did exactly that and reported all 74 rules in that category
    unresolved. The anchors decide."""
    html = (FIXTURES / "index_inline.html").read_text(encoding="utf-8")
    assert normalise_html(html), "this page does yield text, unlike its siblings"
    assert resolve.classify_page(html)[0] == "index"


def test_a_crawl_descends_through_an_inline_index():
    fetcher = FakeFetcher()
    index = resolve.follow_trail(fetcher, BASE + "frefre.html", TRAIL[11])
    result = resolve.crawl(fetcher, index, 11)
    assert [(e.name, e.url) for e in result.entries] == [
        ("Platzhalter-Eins", BASE + "PH_Eins.html")
    ]


# ── navigation and crawling ──────────────────────────────────────────────────

def test_follow_trail_navigates_by_anchor_text_not_by_url():
    fetcher = FakeFetcher()
    assert resolve.follow_trail(
        fetcher, BASE + "frefre.html", ("Platzhalter-Kategorie",)
    ) == BASE + "ph_kategorie.html"


def test_follow_trail_reports_a_category_it_cannot_find():
    """A renamed category is a thing to report, not to work around: the error
    names the page and lists what the page does offer."""
    fetcher = FakeFetcher()
    with pytest.raises(LookupError) as exc:
        resolve.follow_trail(fetcher, BASE + "frefre.html", ("Platzhalter-Erfunden",))
    assert "Platzhalter-Erfunden" in str(exc.value)
    assert "Platzhalter-Kategorie" in str(exc.value)


def test_crawl_descends_through_a_category_of_categories():
    """The style indexes on the real site list categories, not rules. A crawl
    that assumed one level would find nothing there at all."""
    _, crawls = crawl_fixture_site()
    urls = {e.name: e.url for e in crawls[9].entries}
    assert urls == {
        "Platzhalter-Stil": BASE + "ph_stile/unterkategorie/platzhalter-stil.html",
        "Platzhalter-Stil der Platzhalter":
            BASE + "ph_stile/unterkategorie/platzhalter-stil.html",
    }


def test_one_page_listed_under_two_anchor_texts_is_recorded_under_both():
    """The extended combat abilities are indexed once per weapon group and
    again all together, so the same page is reached under more than one
    spelling. Keeping only the first would make a rule whose seed name matches
    the second report as unresolved for no reason."""
    _, crawls = crawl_fixture_site()
    url = BASE + "ph_stile/unterkategorie/platzhalter-stil.html"
    assert sorted(e.name for e in crawls[9].entries if e.url == url) == [
        "Platzhalter-Stil", "Platzhalter-Stil der Platzhalter",
    ]


def test_crawl_carries_the_href_through_verbatim():
    """Including its percent-encoding. Re-spelling the href from the name
    produces a different URL, and a 404 at the other end."""
    _, crawls = crawl_fixture_site()
    urls = {e.name: e.url for e in crawls[3].entries}
    assert urls["Platzhalter-Gruß"] == BASE + "PH_Gru%C3%9F.html"


def test_crawl_fetches_each_page_once_within_a_group():
    """Two groups whose subtrees share a page each fetch it (the second read is
    a cache hit, so it costs nothing and is not a second network call), but a
    single crawl never walks the same page twice."""
    fetcher = FakeFetcher()
    index = resolve.follow_trail(fetcher, BASE + "frefre.html", TRAIL[3])
    fetcher.requested.clear()
    resolve.crawl(fetcher, index, 3)
    assert len(fetcher.requested) == len(set(fetcher.requested))


# ── publication parsing ──────────────────────────────────────────────────────

def test_parse_publications_splits_run_together_entries_and_drops_the_edition():
    """Normalisation glues the entries together, so the split is on the page
    numbers. The `(4. Auflage)` qualifier and the bracketed weapon-group notes
    the site adds are not part of a book's name and Optolith has neither."""
    text = (
        "Publikation(en): Platzhalter-Regelwerk (4. Auflage), Seite 42 "
        "Platzhalter-Kompendium, Seite 18 [Platzhalter-Waffen] "
        "Platzhalter-Goetterwirken I, Seite 21"
    )
    assert resolve.parse_publications(text) == [
        ("Platzhalter-Regelwerk", 42, 42),
        ("Platzhalter-Kompendium", 18, 18),
        ("Platzhalter-Goetterwirken I", 21, 21),
    ]


@pytest.mark.parametrize("heading", [
    "Publikation:", "Publikationen:", "Publikation(en):", "Publikationen(en):",
])
def test_parse_publications_accepts_every_heading_the_site_writes(heading):
    """Four spellings of one heading are live on the site. Matching only the
    parenthesised one read 28 real pages as having no publication line at all
    -- a failing identity signal caused entirely by the reader."""
    assert resolve.parse_publications(f"{heading} Platzhalter-Regelwerk, Seite 42") == [
        ("Platzhalter-Regelwerk", 42, 42)
    ]


@pytest.mark.parametrize("text, expected", [
    ("Publikation: Platzhalter-Werk, Seiten 16 - 17", [("Platzhalter-Werk", 16, 17)]),
    ("Publikation: Platzhalter-Werk Seite 19", [("Platzhalter-Werk", 19, 19)]),
    ("Publikation: Platzhalter-Werk, Seite 59; Platzhalter-Kodex, Seite 22",
     [("Platzhalter-Werk", 59, 59), ("Platzhalter-Kodex", 22, 22)]),
])
def test_parse_publications_handles_the_sites_four_punctuations(text, expected):
    """A page range, an entry with no comma before `Seite`, and a
    semicolon-joined list -- all three are live shapes."""
    assert resolve.parse_publications(text) == expected


def test_parse_publications_on_a_page_without_the_line():
    assert resolve.parse_publications("Regel: irgendein Platzhalter.") == []


@pytest.mark.parametrize("seed, site, same", [
    ("Platzhalter-Kompendium II", "Platzhalter-Kompendium 2", True),
    ("Platzhalter-Kompendium I", "Platzhalter-Kompendium", True),
    ("Platzhalter-Werk", "Platzhalter-Werk (4. Auflage)", True),
    ("Platzhalter-Kompendium", "Platzhalter-Kompendium 2", False),
    ("Platzhalter-Kompendium II", "Platzhalter-Kompendium 3", False),
])
def test_a_books_volume_numeral_is_a_spelling_not_a_different_book(seed, site, same):
    """The seed writes a volume in roman numerals and the site in arabic, and
    the site writes volume one with no numeral at all. 55 of the 96
    book-not-listed reports in the first full live run were exactly this --
    noise that would have buried the real disagreements. A seed with no volume
    still does not match a site volume 2."""
    assert (resolve._book_key(seed) == resolve._book_key(site)) is same


def test_a_page_range_contains_the_page_the_seed_records():
    """A rule printed across a page break is listed as `Seiten N - M` and the
    seed records the first of them."""
    ok, detail = resolve._publication_verdict(
        (("Platzhalter-Werk", 17),),
        [("Platzhalter-Werk", 16, 17)],
    )
    assert ok, detail


def test_text_containment_is_a_fraction_of_the_seed_not_of_the_page():
    """The page carries more than the rule paragraph, so a symmetric measure
    would score a correct match badly for reasons unrelated to identity."""
    assert resolve.text_containment("alpha beta", "alpha beta gamma delta") == 1.0
    assert resolve.text_containment("alpha beta", "alpha gamma") == 0.5
    assert resolve.text_containment("", "alpha") == 0.0


# ── resolution ───────────────────────────────────────────────────────────────

def test_a_plain_rule_resolves_and_all_three_signals_agree():
    results, _ = resolve_fixture_site()
    res = results["PH_1"]
    assert res.status == "resolved"
    assert res.url == BASE + "PH_Eins.html"
    assert {s.signal for s in res.signals} == {"title", "text", "publication"}
    assert all(s.ok for s in res.signals)


def test_a_ladder_titled_page_resolves_to_the_rule_named_without_the_ladder():
    results, _ = resolve_fixture_site()
    assert results["PH_2"].status == "resolved"
    assert results["PH_2"].url == BASE + "PH_Zwei.html"


def test_a_percent_encoded_href_resolves_to_exactly_what_the_site_publishes():
    results, _ = resolve_fixture_site()
    assert results["PH_4"].status == "resolved"
    assert results["PH_4"].url == BASE + "PH_Gru%C3%9F.html"


def test_a_rule_two_index_levels_down_resolves():
    results, _ = resolve_fixture_site()
    assert results["PH_7"].status == "resolved"
    assert results["PH_7"].url == (
        BASE + "ph_stile/unterkategorie/platzhalter-stil.html"
    )


def test_two_of_three_signals_is_reported_not_recorded():
    """Title and rule text agree; the publication line names the right book and
    a different page. That is exactly the shape one of the ten golden rules
    already has, and it is a thing for a human to look at -- so the rule is
    reported with the disagreement named, and the URL is not recorded."""
    results, _ = resolve_fixture_site()
    res = results["PH_3"]
    assert res.status == "needs-review"
    assert res.url == BASE + "PH_Drei.html"
    failed = [s for s in res.signals if not s.ok]
    assert [s.signal for s in failed] == ["publication"]
    assert "page differs" in failed[0].detail
    assert "99" in failed[0].detail and "44" in failed[0].detail


def test_a_name_published_at_two_urls_is_reported_with_both_candidates():
    results, _ = resolve_fixture_site()
    res = results["PH_5"]
    assert res.status == "ambiguous"
    assert res.url is None
    assert sorted(res.candidates) == [
        "Platzhalter-Doppel -> " + BASE + "PH_DoppelA.html",
        "Platzhalter-Doppel -> " + BASE + "PH_DoppelB.html",
    ]


def test_every_candidate_is_printed_in_one_shape():
    """`render_report` prints them all under one `candidate:` label, so an
    ambiguous rule's candidates and an unresolved rule's must not be two
    different shapes."""
    results, _ = resolve_fixture_site()
    reported = [r for r in results.values() if r.candidates]
    assert {r.status for r in reported} == {"ambiguous", "unresolved"}
    for res in reported:
        for candidate in res.candidates:
            assert " -> " + BASE in candidate, (res.rule_id, candidate)


def test_a_name_on_no_index_is_reported_with_the_candidates_considered():
    results, _ = resolve_fixture_site()
    res = results["PH_6"]
    assert res.status == "unresolved"
    assert res.url is None
    assert res.candidates, "an unresolved rule reports what was considered"
    assert all(" -> " in c for c in res.candidates)


def test_a_qualifier_the_site_adds_is_a_candidate_and_not_a_match():
    """The site disambiguates a few entries with a trailing parenthetical the
    seed does not carry. Dropping it is a judgement about which of two things
    the rule is, so it is reported for a reviewer rather than resolved."""
    results, _ = resolve_fixture_site()
    res = results["PH_8"]
    assert res.status == "unresolved"
    assert res.url is None
    assert res.candidates[0] == (
        "Platzhalter-Qualifiziert (Platzhalter-Technik) -> " + BASE + "PH_Qual.html"
    )


def test_nothing_is_resolved_outside_its_own_group():
    """`Platzhalter-Stil` is published under the style category only. A rule
    filed in the combat group must not pick it up."""
    fetcher, crawls = crawl_fixture_site()
    misfiled = [target("PH_8", "Platzhalter-Stil", 3, "irrelevant", "X", 1)]
    res = resolve.resolve_targets(misfiled, crawls, fetcher)[0]
    assert res.status == "unresolved"


def test_report_names_every_reported_rule_with_its_candidates():
    results, crawls = resolve_fixture_site()
    report = resolve.render_report(list(results.values()), crawls)
    assert "Reported, not guessed:" in report
    for rule_id in ("PH_3", "PH_5", "PH_6", "PH_8"):
        assert rule_id in report
    assert "PH_DoppelA.html" in report
    assert "4 resolved" in report


# ── the map ──────────────────────────────────────────────────────────────────

def test_write_map_records_only_confirmed_rules_and_reports_the_rest(tmp_path):
    results, _ = resolve_fixture_site()
    path = tmp_path / "resolved_urls.json"
    resolve.write_map(path, list(results.values()))
    payload = json.loads(path.read_text(encoding="utf-8"))

    assert set(payload["resolved"]) == {"PH_1", "PH_2", "PH_4", "PH_7"}
    assert payload["resolved"]["PH_4"] == BASE + "PH_Gru%C3%9F.html"
    reported = {entry["id"]: entry for entry in payload["reported"]}
    assert set(reported) == {"PH_3", "PH_5", "PH_6", "PH_8"}
    assert reported["PH_5"]["candidates"]
    assert reported["PH_3"]["url"] == BASE + "PH_Drei.html"


# ── inputs ───────────────────────────────────────────────────────────────────

def _seed_db(path: Path):
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE rules (id TEXT PRIMARY KEY, category TEXT, group_id INTEGER);
        CREATE TABLE rules_i18n (
            rule_id TEXT, locale TEXT, name TEXT, description TEXT,
            level1 TEXT, level2 TEXT, level3 TEXT, level4 TEXT
        );
        """
    )
    conn.execute("INSERT INTO rules VALUES ('PH_1', 'special_ability', 3)")
    conn.execute("INSERT INTO rules VALUES ('PH_9', 'special_ability', 1)")
    conn.execute(
        "INSERT INTO rules_i18n VALUES ('PH_1','de-DE','Platzhalter-Eins','Grundtext',"
        "'Stufentext eins',NULL,NULL,NULL)"
    )
    conn.execute(
        "INSERT INTO rules_i18n VALUES ('PH_9','de-DE','Platzhalter-Neun','Grundtext',"
        "NULL,NULL,NULL,NULL)"
    )
    conn.commit()
    conn.close()


def _seed_source(root: Path):
    (root / "de-DE").mkdir(parents=True)
    (root / "de-DE" / "Books.yaml").write_text(
        yaml.safe_dump([{"id": "PH25001", "name": "Platzhalter-Regelwerk"}]),
        encoding="utf-8",
    )
    (root / "de-DE" / "SpecialAbilities.yaml").write_text(
        yaml.safe_dump([
            {"id": "PH_1", "name": "Platzhalter-Eins",
             "src": [{"id": "PH25001", "firstPage": 42}]},
        ]),
        encoding="utf-8",
    )


def test_load_targets_joins_the_seed_text_and_resolves_the_book_id(tmp_path):
    db = tmp_path / "rules.db"
    source = tmp_path / "Data"
    _seed_db(db)
    _seed_source(source)

    targets = resolve.load_targets(db, source, groups=(3,))
    assert [t.rule_id for t in targets] == ["PH_1"], "group filter is applied"
    assert targets[0].name == "Platzhalter-Eins"
    assert "Stufentext eins" in targets[0].text, "per-Stufe columns are part of the text"
    assert targets[0].sources == (("Platzhalter-Regelwerk", 42),), "book id resolved to its name"


def test_load_targets_says_what_to_do_when_the_untracked_db_is_missing(tmp_path):
    with pytest.raises(FileNotFoundError) as exc:
        resolve.load_targets(tmp_path / "absent.db", tmp_path, groups=(3,))
    assert "make rules-db" in str(exc.value)


# ── politeness ───────────────────────────────────────────────────────────────

class _Response:
    def __init__(self, text):
        self.text = text

    def raise_for_status(self):
        return None


class _RecordingSession:
    def __init__(self):
        self.calls = 0

    def get(self, url, headers=None, timeout=None):
        self.calls += 1
        return _Response(f"<html><body><div id='main'><p>{url}</p></div></body></html>")


def test_a_second_run_against_a_warm_cache_makes_zero_network_calls(tmp_path, monkeypatch):
    """The politeness contract `make rules-resolve` is built on, asserted on
    the real `check.Fetcher` this module reuses rather than on a stand-in."""
    monkeypatch.setattr(sync_check.time, "sleep", lambda _seconds: None)
    session = _RecordingSession()
    urls = [BASE + name for name in ("a.html", "b.html", "c.html")]

    first = sync_check.Fetcher(tmp_path / "cache", session=session)
    for url in urls:
        first.get(url)
    assert first.network_calls == 3 and session.calls == 3

    second = sync_check.Fetcher(tmp_path / "cache", session=session)
    for url in urls:
        second.get(url)
    assert second.network_calls == 0, "a warm cache must make no network calls"
    assert session.calls == 3, "and must not reach the session at all"


def test_the_resolver_fetches_through_the_shared_fetcher():
    """Not a second fetcher with its own delay and its own User-Agent."""
    assert resolve.Fetcher is sync_check.Fetcher
    assert resolve.CACHE_DIR == sync_check.CACHE_DIR


# ── crawl problems are fatal; per-rule results are not ───────────────────────

class BrokenFetcher(FakeFetcher):
    """Serves the fixture site but refuses one URL, the way a network hiccup or
    a renamed page does."""

    def __init__(self, broken):
        super().__init__()
        self.broken = broken

    def get(self, url):
        if url == self.broken:
            raise requests.RequestException("simulated failure")
        return super().get(url)


def test_a_page_that_could_not_be_fetched_is_a_fatal_crawl_problem():
    """Not a per-rule result: a page that did not arrive may have been an index,
    and everything behind it is missing from the map with no sign in any
    individual rule's line."""
    fetcher = BrokenFetcher(BASE + "PH_Eins.html")
    index = resolve.follow_trail(fetcher, BASE + "frefre.html", TRAIL[3])
    result = resolve.crawl(fetcher, index, 3)
    assert [p.detail for p in result.fatal_problems] == [
        BASE + "PH_Eins.html" + ": fetch failed: simulated failure"
    ]


def test_a_page_with_no_rule_text_and_no_anchors_is_not_fatal():
    """The site has several of these (Task 5 fix round 4 found five). They yield
    no entry, which is a property of the site rather than a failure of the run."""
    site = dict(SITE)
    site["PH_Eins.html"] = "rule_h_empty_container.html"
    fetcher = FakeFetcher(site)
    index = resolve.follow_trail(fetcher, BASE + "frefre.html", TRAIL[3])
    result = resolve.crawl(fetcher, index, 3)
    assert result.problems and not result.fatal_problems


def test_a_truncated_subtree_is_fatal():
    """`max_depth` firing means the map is missing everything below that point,
    which is not something any single rule's `unresolved` line would reveal."""
    fetcher = FakeFetcher()
    index = resolve.follow_trail(fetcher, BASE + "frefre.html", TRAIL[9])
    result = resolve.crawl(fetcher, index, 9, max_depth=1)
    assert any("max depth" in p.detail for p in result.fatal_problems)
    assert result.entries == [], "nothing below the truncation point was reached"


def test_a_group_root_that_is_a_rule_page_is_fatal():
    site = dict(SITE)
    site["ph_kategorie.html"] = "rule_i_publication.html"
    fetcher = FakeFetcher(site)
    result = resolve.crawl(fetcher, BASE + "ph_kategorie.html", 3)
    assert any("expected a category index" in p.detail for p in result.fatal_problems)


def test_render_report_warns_when_a_crawl_problem_was_fatal():
    crawls = {3: resolve.CrawlResult(problems=[resolve.Problem(True, "boom")])}
    report = resolve.render_report([], crawls)
    assert "FATAL" in report
    assert "did not look where it said it would" in report


def test_render_report_does_not_cry_fatal_over_a_note():
    crawls = {3: resolve.CrawlResult(problems=[resolve.Problem(False, "a page with no rule text")])}
    report = resolve.render_report([], crawls)
    assert "Crawl problems:" in report
    assert "FATAL" not in report


def _run_against_the_fixture_site(monkeypatch, tmp_path, trail, fetcher=None):
    """`run()` end to end over the fixture site, with a two-rule seed database
    and a two-book Optolith export built in `tmp_path`."""
    db, source = tmp_path / "rules.db", tmp_path / "Data"
    _seed_db(db)
    _seed_source(source)
    monkeypatch.setattr(resolve, "GROUP_INDEX_TRAIL", trail)
    return resolve.run(
        db, source, groups=tuple(trail), fetcher=fetcher or FakeFetcher(),
        map_path=tmp_path / "resolved_urls.json", base_url=BASE,
    )


def test_run_exits_zero_when_only_per_rule_results_need_a_human(monkeypatch, tmp_path):
    """`unresolved` and `needs-review` are legitimate results a reviewer clears
    one at a time. They must not fail the command -- 31 of them is a normal
    live run."""
    assert _run_against_the_fixture_site(monkeypatch, tmp_path, {3: TRAIL[3]}) == 0


def test_run_exits_nonzero_when_a_category_cannot_be_reached(monkeypatch, tmp_path, capsys):
    """The site renaming a category used to append to `problems` and exit 0,
    with every rule in that group reported `unresolved`. That is precisely the
    shape of the first live run's group-11 failure, which only a human reading
    stdout caught."""
    code = _run_against_the_fixture_site(
        monkeypatch, tmp_path, {3: ("Platzhalter-Umbenannt",)}
    )
    assert code == 1
    out = capsys.readouterr().out
    assert "FATAL" in out
    assert "its index could not be reached" in out


def test_run_exits_nonzero_when_a_page_could_not_be_fetched(monkeypatch, tmp_path):
    assert _run_against_the_fixture_site(
        monkeypatch, tmp_path, {3: TRAIL[3]}, BrokenFetcher(BASE + "PH_Eins.html")
    ) == 1


def test_run_writes_the_map_even_when_a_crawl_problem_was_fatal(monkeypatch, tmp_path):
    """So the partial result is inspectable rather than lost. The non-zero exit
    is what says not to trust it."""
    _run_against_the_fixture_site(
        monkeypatch, tmp_path, {3: TRAIL[3]}, BrokenFetcher(BASE + "PH_Eins.html")
    )
    assert (tmp_path / "resolved_urls.json").exists()


# ── the closed loop ──────────────────────────────────────────────────────────
#
# Plan Task 10's last acceptance criterion -- "the ten golden rules resolve to
# exactly the URLs their authored files already record" -- is the one that says
# the resolver *works* rather than merely runs, and until now it was a number in
# a report rather than a ratchet. These two close that.
#
# **Do not reimplement this against `rules.db`.** It would pass unconditionally:
# `build_db.import_effects` writes the authored `source.url` over whatever
# `import_resolved_urls` put in the same column, so in the database the two can
# never disagree. The only comparison with anything to say is the resolver's own
# map against the authored files, which is what these do.
#
# Data Policy: rule ids and `source.url`s are already tracked in
# `specs/rules/*.yaml`, so nothing new enters git here. Ability *names* are read
# from the (untracked) map and never asserted on.

REPO_ROOT = Path(__file__).resolve().parents[2]
AUTHORED_RULES = REPO_ROOT / "specs" / "rules"
GOLDEN_MANIFEST = REPO_ROOT / "tests" / "rules" / "golden" / "MANIFEST.yaml"

needs_a_resolution = pytest.mark.skipif(
    not resolve.RESOLVED_MAP_PATH.exists(),
    reason=f"no resolution at {resolve.RESOLVED_MAP_PATH} -- run `make rules-resolve`",
)


def _resolution_map():
    return json.loads(resolve.RESOLVED_MAP_PATH.read_text(encoding="utf-8"))


def _resolver_verdict(payload, rule_id):
    """`(url, status)` for one rule, across both halves of the map: `resolved`
    holds the confirmed ones, `reported` the rest -- and a reported rule may
    still carry the URL the resolver arrived at, which is the thing being
    compared. `(None, "absent")` when the resolver had no opinion at all (a
    chapter rule, or a group outside the crawl's scope)."""
    if rule_id in payload["resolved"]:
        return payload["resolved"][rule_id], "resolved"
    for entry in payload["reported"]:
        if entry["id"] == rule_id:
            return entry["url"], entry["status"]
    return None, "absent"


def _authored_urls():
    """`{rule_id: url}` for every authored file carrying a real URL. The 17 that
    still hold the `UNVERIFIED` placeholder have nothing to compare."""
    out = {}
    for path in sorted(AUTHORED_RULES.glob("*.yaml")):
        if path.name in sync_check.NON_RULE_FILES:
            continue
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        url = (doc.get("source") or {}).get("url")
        if doc.get("id") and url and url != sync_check.UNVERIFIED_URL:
            out[doc["id"]] = url
    return out


@needs_a_resolution
def test_the_ten_golden_rules_resolve_to_the_urls_their_files_record():
    """**The criterion the supplement calls the real test**, mechanised.

    Every one of the ten must be in the map -- a rule quietly dropping out of
    the crawl's scope is a regression this would otherwise not see -- and every
    one's resolved URL must equal, byte for byte, what its authored file
    records. The confirmation verdict is deliberately *not* asserted: `SA_62`
    resolves to the right page and is `needs-review` because its publication
    line and the seed disagree on a page number, which is a true report about
    the sources and not a failure of the resolver.
    """
    payload = _resolution_map()
    authored = _authored_urls()
    golden = yaml.safe_load(GOLDEN_MANIFEST.read_text(encoding="utf-8"))["rules"]

    mismatches, missing = [], []
    for rule_id in sorted(golden):
        url, status = _resolver_verdict(payload, rule_id)
        if status == "absent":
            missing.append(rule_id)
        elif url != authored.get(rule_id):
            mismatches.append(f"{rule_id}: resolved {url!r} != authored {authored.get(rule_id)!r}")

    assert not missing, f"golden rules the resolver has no opinion on: {missing}"
    assert not mismatches, "\n".join(mismatches)
    assert len(golden) == 10, "the golden corpus is ten rules; this check is about those ten"


@needs_a_resolution
def test_no_authored_url_disagrees_with_what_the_resolver_resolved():
    """The same check widened past the golden ten: wherever a human has recorded
    a URL *and* the resolver has an opinion, the two must agree. A rule the
    resolver never saw (a chapter rule, or one outside the crawled groups) is
    skipped rather than failed."""
    payload = _resolution_map()
    mismatches = [
        f"{rule_id}: resolved {url!r} != authored {authored_url!r} ({status})"
        for rule_id, authored_url in sorted(_authored_urls().items())
        for url, status in [_resolver_verdict(payload, rule_id)]
        if status != "absent" and url != authored_url
    ]
    assert not mismatches, "\n".join(mismatches)
