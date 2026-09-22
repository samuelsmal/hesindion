#!/usr/bin/env python3
"""Resolve every combat rule to its own page on the rule website, by name.

Why this exists
---------------
ADR-0007 makes <https://dsa.ulisses-regelwiki.de/> normative and the Optolith
export a seed. The authoring driver nevertheless feeds agents the seed text,
because almost nothing in this module's scope carries a reviewed `source.url`:
the scope is the 232 rules in combat groups 3, 9, 10, 11 and 12 (`COMBAT_GROUPS`),
of which 28 have an authored file at all and 17 of those still hold the
`UNVERIFIED` placeholder `check.py` reports. This module is
the deterministic half of ADR-0007's reconciliation: it finds each rule's page.
No model is involved, and none is needed.

Never guess a URL from an id
----------------------------
The site's own URLs are not derivable. Three shapes live side by side in the
authored corpus today: `KSF_Sturmangriff.html`, the percent-encoded
`KSF_Vorsto%C3%9F.html`, and a lowercase-hyphenated slug two directories deep
under a category path. No rule about ids or names produces all three, and a
resolver that special-cases the third has not solved the problem. So every URL
here comes from an `href` the site itself publishes, under an anchor text the
site itself writes, and is carried through byte for byte.

How it works
------------
1. **Navigate by name to each group's index.** `GROUP_INDEX_TRAIL` maps an
   Optolith combat group to a path of *anchor texts*, not URLs, followed from
   the site's profane-special-abilities index. Even the index URLs are looked
   up rather than written down.
2. **Crawl each group's index subtree.** Every page fetched is classified:
     * it publishes `a.ulSubMenu` anchors -> an **index** page, whose anchors
       are enqueued. Most index pages here have an **empty `#main`** with the
       link list outside it, so `normalise.normalise_html` raises
       `ContentContainerEmpty` on them. That is correct and deliberate (Task 5
       fix round 4), and it is why index pages are parsed on their own path --
       raw anchors -- rather than routed through the normaliser, which would
       have nothing to give. One category does it the other way round and puts
       its links inside a non-empty `#main`, which is why the anchors and not
       the container are what decides.
     * otherwise it yields text -> a rule page, recorded under every anchor
       text that pointed at it;
     * otherwise -> no rule text and nothing to resolve from; reported.
   An index's children may be indexes themselves (the style categories are),
   so the crawl descends rather than assuming one level.
3. **Match Optolith names against anchor texts**, both reduced by
   `normalise_name` -- which strips the Stufen ladder suffix the site's titles
   carry and the rules' names do not (`... I-III`), folds case, and normalises
   the typographic apostrophes and dashes the site mixes.
4. **Confirm identity per rule by three signals**, the ones Task 4 established
   by hand for the ten golden rules: the page's title line, its rule text
   against the Optolith text, and its `Publikation(en):` line against
   Optolith's `src:` block. All three must agree. Two of three is reported,
   not recorded -- the whole point of the exercise is that where the seed and
   the site disagree, somebody has to look.

Report, never guess
-------------------
A name that matches no anchor, or more than one, is reported with the rule id,
the Optolith name and the candidates considered. So is a page whose identity
signals do not all agree. An unresolved rule is a *result*: `unverified` is a
state this pipeline already reports and a reviewer can act on. Nothing here
writes a URL it did not read off the site under that rule's own name.

Where the map goes
------------------
Into the untracked `rules.db`, via `scripts/build_rules_db/build_db.py` -- no
ability names enter git (Data Policy, AGENTS.md). This module writes the
resolution to `RESOLVED_MAP_PATH` under the git-ignored `.cache/`, which the
builder reads on its next run; `make rules-resolve && make rules-db` is the
pair. It deliberately does **not** rewrite any authored `specs/rules/*.yaml`:
resolving a URL and authoring provenance are different acts, and ADR-0007's
second 2026-09-21 amendment gives `source.hash` to the driver, not here.

Politeness
----------
Fetching is `check.Fetcher` -- the same disk cache under `.cache/rules_sync/`,
the same `DELAY = 1.0` between real requests, the same project User-Agent. A
second run against a warm cache makes zero network calls, and the run prints
the count so that claim can be checked rather than believed.
"""
from __future__ import annotations

import argparse
import difflib
import json
import re
import sqlite3
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path
from typing import NamedTuple
from urllib.parse import urljoin, urlsplit

import requests
import yaml
from bs4 import BeautifulSoup

from scripts.rules_sync.check import CACHE_DIR, Fetcher
from scripts.rules_sync.normalise import (
    ContentContainerEmpty,
    ContentContainerNotFound,
    normalise_html,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DB = REPO_ROOT / "Hesindion" / "Resources" / "rules.db"

#: Where the resolution lands for `build_db.py` to carry into `rules.db`. Under
#: `.cache/`, which `.gitignore` already declares a Data Policy boundary: this
#: file names abilities, so it must never become a tracked mapping file. It is
#: a hand-off between two commands, not the map's home -- the map's home is the
#: untracked database, and `make rules-db` is what puts it there.
RESOLVED_MAP_PATH = REPO_ROOT / ".cache" / "rules_resolve" / "resolved_urls.json"

BASE_URL = "https://dsa.ulisses-regelwiki.de/"

#: The profane special-abilities index. Every group index below is found by
#: following anchor *text* from here, so the only URL this module writes down
#: is the one entry point.
ROOT_INDEX_PATH = "frefre.html"

#: Optolith combat groups in scope (plan Task 10, acceptance criterion 1), and
#: the trail of anchor texts that leads from `ROOT_INDEX_PATH` to each one's
#: index. The texts are the site's own category names as it publishes them;
#: they are not the group names Optolith uses, which is why the mapping has to
#: exist at all. The crawl is deliberately not widened beyond these five.
GROUP_INDEX_TRAIL: dict[int, tuple[str, ...]] = {
    3: ("Kampfsonderfertigkeiten",),
    9: ("Kampfstilsonderfertigkeiten", "Bewaffnete Kampfstile"),
    10: ("Kampfstilsonderfertigkeiten", "Unbewaffnete Kampfstile"),
    11: ("Erweiterte Kampfstilsonderfertigkeiten",),
    12: ("Befehlssonderfertigkeiten",),
}

COMBAT_GROUPS = tuple(sorted(GROUP_INDEX_TRAIL))

#: Index anchors on this site all carry this class, on index pages and nowhere
#: else -- verified: every rule page fetched in a full live run has zero of
#: them, and every index page has at least one. That makes it, and not the
#: content container, the thing that says which kind of page this is.
INDEX_ANCHOR_SELECTOR = "a.ulSubMenu"

#: Guard rails on the crawl. The five group subtrees are three levels deep at
#: most; these stop a redesign (or a cycle the visited-set somehow misses) from
#: turning a resolve run into a site-wide scrape.
MAX_DEPTH = 4
MAX_PAGES = 1200

#: How much of the Optolith text must reappear on the page for the text signal
#: to agree. It is a lexical containment, not a semantic comparison: it answers
#: "is this the same rule's page", not "does the page say what the seed says" --
#: which is the question the whole pipeline exists to ask, and which no
#: deterministic code can answer. Calibrated against the ten golden rules and
#: their recorded URLs: the true pairings score 0.83..1.00 and all but one of
#: the ninety false pairings score below 0.50.
TEXT_CONTAINMENT_THRESHOLD = 0.60

#: Fuzzy cutoff for the near-miss candidates an unresolved rule is reported
#: with. These are suggestions for a human, never a resolution.
CANDIDATE_CUTOFF = 0.72
CANDIDATE_COUNT = 5

_WORD_RE = re.compile(r"[0-9A-Za-zÀ-ÿ]+")
#: A trailing Stufen ladder as the site's titles and anchors spell it:
#: " I", " I-II", " I-III", " I–IV" (en dash included -- the site mixes them).
_LADDER_SUFFIX_RE = re.compile(r"\s+[IVX]+(?:\s*[-–—]\s*[IVX]+)?\s*$", re.IGNORECASE)
#: The parenthesised subgroup label a rule page's title line may carry.
_PAREN_SUFFIX_RE = re.compile(r"\s*\([^)]*\)\s*$")
_SITE_TITLE_SUFFIX_RE = re.compile(r"\s*-\s*DSA\s+Regel-Wiki\s*$", re.IGNORECASE)
_EDITION_RE = re.compile(r"\s*\(\s*\d+\s*\.\s*Auflage\s*\)\s*", re.IGNORECASE)
_BRACKET_RE = re.compile(r"\[[^\]]*\]")
#: The heading above the publication list, in all four spellings the live
#: site uses: `Publikation:`, `Publikationen:`, `Publikation(en):` and
#: `Publikationen(en):`. Matching only the first of them read 28 pages as
#: having no publication line at all.
_PUBLICATION_RE = re.compile(r"Publikation(?:en)?(?:\(en\))?\s*:\s*(.*)$")
#: The entry separator on a `Publikation(en):` line, as five live shapes spell
#: it -- written here with invented page numbers, because a real one is seed
#: data and one of them is a golden rule's: `, Seite 11`, a bare ` Seite 12`,
#: `; Seite 13`, `, Seiten 14 - 15` and `, Seiten 16 - 17`. Splitting on this
#: rather than on a separator between entries, because between entries there is
#: frequently no separator at all.
_PUB_SPLIT_RE = re.compile(r"[,;]?\s*Seiten?\s+(\d+)(?:\s*[-\u2013\u2014]\s*(\d+))?")

__all__ = [
    "IndexEntry", "CrawlResult", "Problem", "SignalVerdict", "Resolution", "RuleTarget",
    "normalise_name", "index_anchors", "page_base", "page_title", "parse_publications",
    "text_containment", "classify_page", "crawl", "follow_trail",
    "confirm_identity", "resolve_targets", "load_targets", "render_report",
    "write_map", "run", "main",
]


# ── value types ──────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class IndexEntry:
    """One rule page the site publishes under one anchor text."""
    name: str
    url: str
    group_id: int
    index_url: str


class Problem(NamedTuple):
    """Something that went wrong while crawling, and whether it means the crawl
    did not do what it was asked to do.

    A crawl *problem* and a per-rule *result* are different things and must exit
    differently. `unresolved` and `needs-review` are legitimate results a human
    clears one at a time. A category that could not be reached, a subtree that
    was truncated, or a page that could not be fetched means the run did not
    look where it said it would -- every rule behind it reports `unresolved`
    for a reason that has nothing to do with that rule. The first full live run
    was exactly this shape: 74 rules silently unresolved because one index page
    was misread, caught only because a human read stdout. `fatal` is what makes
    the next one fail the command instead.
    """
    fatal: bool
    detail: str

    def __str__(self) -> str:                      # pragma: no cover - display
        return f"{'FATAL' if self.fatal else 'note '}  {self.detail}"


@dataclass
class CrawlResult:
    entries: list[IndexEntry] = field(default_factory=list)
    index_urls: list[str] = field(default_factory=list)
    problems: list[Problem] = field(default_factory=list)

    @property
    def fatal_problems(self) -> list[Problem]:
        return [p for p in self.problems if p.fatal]

    def by_name(self) -> dict[str, list[IndexEntry]]:
        """Anchor entries keyed by their normalised name. Duplicate (name, url)
        pairs collapse -- the site prints the same list twice on a page, once
        for the mobile menu -- but two *different* urls under one name stay two
        candidates, which is the ambiguity this module reports."""
        out: dict[str, list[IndexEntry]] = {}
        for entry in self.entries:
            bucket = out.setdefault(normalise_name(entry.name), [])
            if not any(e.url == entry.url for e in bucket):
                bucket.append(entry)
        return out


@dataclass(frozen=True)
class SignalVerdict:
    signal: str          # "title" | "text" | "publication"
    ok: bool
    detail: str


@dataclass(frozen=True)
class RuleTarget:
    """One rule as the resolver looks for it: what Optolith calls it, which
    combat group it sits in, the seed text, and the `src:` book/page pairs."""
    rule_id: str
    name: str
    group_id: int
    text: str = ""
    sources: tuple[tuple[str, int], ...] = ()   # (book name, first page)


@dataclass(frozen=True)
class Resolution:
    rule_id: str
    name: str
    group_id: int
    status: str                      # resolved | needs-review | unresolved | ambiguous
    url: str | None
    signals: tuple[SignalVerdict, ...] = ()
    candidates: tuple[str, ...] = ()
    detail: str = ""

    @property
    def confirmed(self) -> bool:
        return self.status == "resolved"


# ── text reduction ───────────────────────────────────────────────────────────

def _fold(text: str) -> str:
    """Case, punctuation and Unicode folding shared by ability names and book
    titles: NFC (so a precomposed umlaut compares equal to a decomposed one),
    the typographic apostrophe and the three dash characters the site mixes
    unified, whitespace collapsed, case folded."""
    text = unicodedata.normalize("NFC", text or "")
    text = text.replace("’", "'").replace("ʼ", "'").replace("`", "'")
    text = text.replace("–", "-").replace("—", "-").replace("−", "-")
    return re.sub(r"\s+", " ", text).strip().casefold()


def normalise_name(name: str) -> str:
    """Reduce an ability name or an anchor text to a comparable key.

    `_fold`, plus a trailing Stufen ladder stripped: `<name> I-III` and
    `<name>` are the same ability under two spellings -- the site titles the
    page with the ladder, Optolith names the rule without it.

    Deliberately not used on a book title. A trailing roman numeral there is a
    *volume*, not a ladder, and stripping it would quietly make `<Buch> II` the
    same book as `<Buch>`. `_book_key` has its own rule.
    """
    return _fold(_LADDER_SUFFIX_RE.sub("", unicodedata.normalize("NFC", name or "")))


def _title_key(title: str) -> str:
    """A rule page's title line reduced for comparison: the site suffix and the
    parenthesised subgroup label removed, then `normalise_name`."""
    text = _SITE_TITLE_SUFFIX_RE.sub("", title or "")
    text = _PAREN_SUFFIX_RE.sub("", text)
    return normalise_name(text)


def _words(text: str) -> set[str]:
    return {w.casefold() for w in _WORD_RE.findall(unicodedata.normalize("NFC", text or ""))}


def text_containment(seed_text: str, page_text: str) -> float:
    """Fraction of the seed text's distinct words that also appear on the page.

    Containment rather than similarity, because the page carries more than the
    rule paragraph (prerequisites, AP cost, publications) and would score badly
    on a symmetric measure for reasons that say nothing about identity.
    """
    seed = _words(seed_text)
    if not seed:
        return 0.0
    return len(seed & _words(page_text)) / len(seed)


# ── page parsing ─────────────────────────────────────────────────────────────

def index_anchors(html: str) -> list[tuple[str, str]]:
    """The `(anchor text, href)` pairs an index page publishes, in document
    order, de-duplicated. This is the index pages' own parsing path: it reads
    the raw markup, because an index page's `#main` is empty and its link list
    sits outside it -- routing it through `normalise_html` raises
    `ContentContainerEmpty`, by design, and yields nothing to parse."""
    soup = BeautifulSoup(html, "html.parser")
    out: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for anchor in soup.select(INDEX_ANCHOR_SELECTOR):
        href = (anchor.get("href") or "").strip()
        text = anchor.get_text(strip=True) or (anchor.get("title") or "").strip()
        if not href or not text:
            continue
        key = (text, href)
        if key in seen:
            continue
        seen.add(key)
        out.append(key)
    return out


def page_base(html: str, page_url: str) -> str:
    """The URL an index page's `href`s are relative to.

    Every page on this site declares `<base href="https://dsa.ulisses-regelwiki.de/">`
    and then writes its anchors from the site root -- a sub-category index that
    itself lives in a directory still links to `<dir>/<page>.html`, not to
    `<page>.html`. Joining those anchors against the page's own URL doubles the
    directory and produces a URL that does not exist; honouring the declared
    base is both what a browser does and the only thing that works here.
    """
    soup = BeautifulSoup(html, "html.parser")
    tag = soup.find("base")
    href = (tag.get("href") if tag else "") or ""
    return urljoin(page_url, href.strip()) if href.strip() else page_url


def page_title(html: str) -> str:
    """A rule page's own title line: the `<h1>` inside the content container,
    falling back to the document `<title>` with the site suffix removed."""
    soup = BeautifulSoup(html, "html.parser")
    container = soup.find(id="main") or soup.find("main")
    if container is not None:
        heading = container.find(["h1", "h2"])
        if heading is not None and heading.get_text(strip=True):
            return heading.get_text(" ", strip=True)
    if soup.title and soup.title.get_text(strip=True):
        return _SITE_TITLE_SUFFIX_RE.sub("", soup.title.get_text(strip=True))
    return ""


def parse_publications(page_text: str) -> list[tuple[str, int, int]]:
    """`(book, first page, last page)` triples from a `Publikation(en):` line.

    The normalised text runs the entries together and punctuates them four
    different ways. All four are live on the site; the examples here are
    written with placeholder book titles and invented pages, the same
    convention the test fixtures use, because a real title and a real page
    number are the seed data this repository deliberately does not carry in
    git (the authored corpus stores a book as an opaque id, `book: US25001`):

        <Buch> (4. Auflage), Seite 11 <Anderes Buch>, Seite 12
        <Buch> Seite 13                       -- no comma before `Seite`
        <Buch>, Seite 14; <Anderes Buch>, Seite 15
        <Buch>, Seiten 16 - 17                -- a rule spanning a page break

    So the split is on the page numbers themselves, taking the separator, the
    singular/plural and the range as optional. A single page is returned as a
    one-page range, so the caller has one shape to compare against.

    Edition qualifiers (`(4. Auflage)`) and the bracketed weapon-group notes
    some entries carry are dropped: neither is part of a book's name and
    Optolith records neither.
    """
    match = _PUBLICATION_RE.search(page_text or "")
    if not match:
        return []
    parts = _PUB_SPLIT_RE.split(match.group(1))
    out: list[tuple[str, int, int]] = []
    # parts alternates book, first, last, book, first, last, ..., remainder.
    for i in range(0, len(parts) - 2, 3):
        book = _clean_book(parts[i])
        # `_PUB_SPLIT_RE`'s first group is a mandatory `(\d+)`, so `first` is
        # always a digit string here; only the range's second group is optional.
        first, last = parts[i + 1], parts[i + 2]
        if not book:
            continue
        out.append((book, int(first), int(last) if last else int(first)))
    return out


def _clean_book(raw: str) -> str:
    text = _BRACKET_RE.sub(" ", raw or "")
    text = _EDITION_RE.sub(" ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text.strip(" ,;")


#: A trailing volume numeral on a book title, roman or arabic.
_VOLUME_RE = re.compile(r"\s+(?:([IVX]+)|(\d+))$", re.IGNORECASE)
_ROMAN = {"i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5, "vi": 6, "vii": 7, "viii": 8, "ix": 9, "x": 10}


def _book_key(book: str) -> str:
    """A book title reduced for comparison.

    Beyond `_fold`, one spelling rule: a **trailing volume numeral is
    normalised**, roman to arabic, and a volume 1 to no volume at all. For a
    book the seed calls `<Buch> II` the site writes `<Buch> 2`; for the one the
    seed calls `<Buch> I` the site, which published that volume before there
    was a second, writes `<Buch>` with no numeral at all. These are two
    spellings of one book, and **55 of the 96 book-not-listed reports in the
    first full live run were this and nothing else** -- noise that would have
    buried the seventeen real disagreements.

    It is a spelling rule and not a judgement: `<Buch> II` and `<Buch> 2` denote
    the same volume under any reading, and a seed `<Buch>` still does not match
    a site `<Buch> 2`. Where the two sources genuinely differ on a title -- the
    site carries three spellings of one series name and two outright typos --
    nothing here papers over it and the rule is reported.
    """
    text = _fold(_clean_book(book))
    match = _VOLUME_RE.search(text)
    if match:
        roman, arabic = match.groups()
        number = _ROMAN.get((roman or "").casefold()) if roman else int(arabic)
        if number:
            text = text[: match.start()] + ("" if number == 1 else f" {number}")
    return text.strip()


def classify_page(html: str) -> tuple[str, str]:
    """`("rule", text)`, `("index", "")` or `("broken", reason)`.

    Two signals, in this order:

    * **The page publishes `a.ulSubMenu` anchors** -> it is an index. This has
      to come first, because it is the only signal that covers *every* index on
      this site. Most of them have an empty `#main` with the link list outside
      it, but not all: the extended-combat category publishes its links
      **inside** `#main`, above its sub-category headings, so it normalises to
      text and the container test alone calls it a rule page. It was found this
      way -- the first live run reported all 74 rules in that group unresolved
      and named the page it had misread.
    * **Otherwise, what `normalise_html` says.** Text -> a rule page.
      `ContentContainerEmpty` with no anchors either -> a page with no rule text
      and nothing to resolve from, reported rather than recorded (the site has
      several of these; Task 5 fix round 4 found five). `ContentContainerNotFound`
      -> the markup changed and a human has to look.

    Note what this does *not* do: it never "fixes" `normalise_html` to make an
    index page normalise. An index page raising `ContentContainerEmpty` is
    correct, and index pages are parsed on their own path here precisely
    because of it.
    """
    if index_anchors(html):
        return "index", ""
    try:
        return "rule", normalise_html(html)
    except ContentContainerEmpty as exc:
        return "broken", str(exc)
    except ContentContainerNotFound as exc:
        return "broken", str(exc)


# ── crawling ─────────────────────────────────────────────────────────────────

def _same_site(url: str, base: str) -> bool:
    a, b = urlsplit(url), urlsplit(base)
    return (a.scheme in ("http", "https")) and a.netloc == b.netloc


def follow_trail(fetcher, root_url: str, trail: tuple[str, ...]) -> str:
    """Walk from `root_url` to an index page by anchor *text*, one hop per
    entry in `trail`. Raises `LookupError` naming what it could not find --
    the site renaming a category is a thing to report, not to work around."""
    url = root_url
    for wanted in trail:
        html = fetcher.get(url)
        base = page_base(html, url)
        matches = [
            urljoin(base, href)
            for text, href in index_anchors(html)
            if normalise_name(text) == normalise_name(wanted)
        ]
        matches = list(dict.fromkeys(matches))
        if len(matches) != 1:
            available = ", ".join(sorted({t for t, _ in index_anchors(html)}))
            raise LookupError(
                f"{url}: {len(matches)} anchor(s) named {wanted!r} "
                f"(available: {available or 'none'})"
            )
        url = matches[0]
    return url


def crawl(
    fetcher,
    start_url: str,
    group_id: int,
    *,
    max_depth: int = MAX_DEPTH,
    max_pages: int = MAX_PAGES,
) -> CrawlResult:
    """Breadth-first walk of one group's index subtree.

    Every page is fetched once and classified. A rule page is recorded under
    *every* anchor text that pointed at it -- the anchor is where the name
    lives, the page is where the proof lives, and the same page is often listed
    on more than one index (the extended combat abilities are indexed once per
    weapon group and again all together). Keeping only the first spelling would
    turn a rule whose seed name matches the second into an unresolved report
    for no reason. An index page's anchors are enqueued, so a category of
    categories -- the style indexes are exactly that -- is walked rather than
    mistaken for a list of rules.
    """
    result = CrawlResult()
    seen: set[str] = set()
    kinds: dict[str, str] = {}
    parents: dict[str, str] = {}
    anchor_texts: dict[str, list[str]] = {}
    queue: list[tuple[str, int]] = [(start_url, 0)]
    seen.add(start_url)

    while queue:
        url, depth = queue.pop(0)
        if len(seen) > max_pages:
            result.problems.append(Problem(True,
                f"crawl stopped at {max_pages} pages (group {group_id}); "
                "the index subtree is larger than expected -- look at the site"
            ))
            break
        try:
            html = fetcher.get(url)
        except requests.RequestException as exc:
            # Fatal: a page that could not be fetched may have been an index,
            # and everything behind it is missing from the map with no sign in
            # any individual rule's result. A retry costs nothing -- the pages
            # that did arrive are on disk.
            result.problems.append(Problem(True, f"{url}: fetch failed: {exc}"))
            continue

        kind, detail = classify_page(html)
        kinds[url] = kind
        if kind == "broken":
            # Not fatal: a page that carries no rule text and no anchors is a
            # property of this site (Task 5 fix round 4 found five of them), not
            # a failure of the crawl. It simply yields no entry.
            result.problems.append(Problem(False, f"{url}: {detail}"))
            continue
        if kind == "rule":
            if url == start_url:
                result.problems.append(Problem(True,
                    f"{url}: expected a category index for group {group_id}, "
                    "but the page yields rule text -- this group resolved nothing"
                ))
            continue

        # index page -- `classify_page` only says so when there are anchors
        result.index_urls.append(url)
        anchors = index_anchors(html)
        if depth >= max_depth:
            result.problems.append(Problem(True,
                f"{url}: max depth {max_depth} reached, not descending -- the "
                "subtree below it is missing from the map"
            ))
            continue
        base = page_base(html, url)
        for text, href in anchors:
            child = urljoin(base, href)
            child, _, _ = child.partition("#")
            if not _same_site(child, start_url):
                continue
            texts = anchor_texts.setdefault(child, [])
            if text not in texts:
                texts.append(text)
            parents.setdefault(child, url)
            if child in seen:
                continue
            seen.add(child)
            queue.append((child, depth + 1))

    for url, kind in kinds.items():
        if kind != "rule":
            continue
        for text in anchor_texts.get(url, ()):
            result.entries.append(IndexEntry(text, url, group_id, parents.get(url, start_url)))

    return result


# ── identity confirmation ────────────────────────────────────────────────────

def confirm_identity(target: RuleTarget, html: str, page_text: str) -> tuple[SignalVerdict, ...]:
    """The three signals Task 4 established, mechanised.

    All three must agree. Two of three is not enough to accept silently: where
    the seed and the site disagree the pipeline is confidently wrong, and that
    disagreement is the thing this whole task exists to surface.
    """
    title = page_title(html)
    title_ok = _title_key(title) == normalise_name(target.name)

    containment = text_containment(target.text, page_text)
    text_ok = containment >= TEXT_CONTAINMENT_THRESHOLD

    published = parse_publications(page_text)
    pub_ok, pub_detail = _publication_verdict(target.sources, published)

    return (
        SignalVerdict("title", title_ok, f"page title {title!r} vs name {target.name!r}"),
        SignalVerdict(
            "text", text_ok,
            f"{containment:.2f} of the seed text's words on the page "
            f"(threshold {TEXT_CONTAINMENT_THRESHOLD:.2f})",
        ),
        SignalVerdict("publication", pub_ok, pub_detail),
    )


def _publication_verdict(
    seed_sources: tuple[tuple[str, int], ...],
    published: list[tuple[str, int, int]],
) -> tuple[bool, str]:
    """Does the page's `Publikation(en):` line list the book and page the seed's
    `src:` block records?

    Three outcomes, distinguished because the remedies differ: the book and
    page agree; the book is listed at a different page (an edition difference
    or an erratum -- Task 4 found one of these among the ten golden rules by
    hand); or the seed's book is not on the page's list at all. Only the first
    is agreement. A range (`Seiten 16 - 17`) contains its pages: a rule that
    spans a page break is printed on both, and the seed records the first.
    """
    if not seed_sources:
        return False, "the seed records no src: block to compare against"
    if not published:
        return False, "the page has no Publikation(en): line"

    def printed_pages(book: str) -> list[tuple[int, int]]:
        return [(f, l) for b, f, l in published if _book_key(b) == _book_key(book)]

    for book, page in seed_sources:
        if any(first <= page <= last for first, last in printed_pages(book)):
            return True, f"{book}, Seite {page}"
    for book, page in seed_sources:
        spans = printed_pages(book)
        if spans:
            shown = ", ".join(str(f) if f == l else f"{f}-{l}" for f, l in spans)
            return False, f"{book}: page differs -- site says {shown}, seed says {page}"
    return False, (
        "book not listed -- site says "
        + "; ".join(_format_span(b, f, l) for b, f, l in published)
        + " / seed says "
        + "; ".join(f"{b}, Seite {p}" for b, p in seed_sources)
    )


def _format_span(book: str, first: int, last: int) -> str:
    return f"{book}, Seite {first}" if first == last else f"{book}, Seiten {first}-{last}"


# ── resolution ───────────────────────────────────────────────────────────────

def _candidate_line(entry: IndexEntry) -> str:
    """One candidate, in the one shape `render_report` prints under
    `candidate:`. Both the ambiguous and the unresolved branch build their
    candidates through this, so a reader never has to work out which of two
    shapes a line is in."""
    return f"{entry.name} -> {entry.url}"


def _candidates_for(key: str, by_name: dict[str, list[IndexEntry]]) -> tuple[str, ...]:
    """What an unresolved rule is reported *with*: the anchors a reviewer should
    look at, never a resolution.

    Two sources, in order. First, anchors whose name matches once a trailing
    parenthetical qualifier is dropped -- the site disambiguates a few of its
    entries that way (`<name> (Kampftechnik)`) and the seed does not, so this is
    almost always the answer and almost never far from it. It is deliberately
    *not* promoted to a match: dropping a qualifier the site thought worth
    adding is a judgement about which of two things a rule is, and this module
    does not make judgements. Second, fuzzy near-misses, which catch a spelling
    that drifted between the two sources.
    """
    out: list[str] = []
    for name_key, entries in by_name.items():
        if _PAREN_SUFFIX_RE.sub("", name_key).strip() == key:
            out.extend(_candidate_line(e) for e in entries)
    near = difflib.get_close_matches(key, list(by_name), n=CANDIDATE_COUNT, cutoff=CANDIDATE_CUTOFF)
    for name_key in near:
        for entry in by_name[name_key]:
            line = _candidate_line(entry)
            if line not in out:
                out.append(line)
    return tuple(out[:CANDIDATE_COUNT])


def resolve_targets(
    targets: list[RuleTarget],
    crawls: dict[int, CrawlResult],
    fetcher,
) -> list[Resolution]:
    """Match each target's name against its group's index anchors, then confirm."""
    indexes = {gid: result.by_name() for gid, result in crawls.items()}
    resolutions: list[Resolution] = []

    for target in sorted(targets, key=lambda t: (t.group_id, t.rule_id)):
        by_name = indexes.get(target.group_id)
        if by_name is None:
            resolutions.append(Resolution(
                target.rule_id, target.name, target.group_id, "unresolved", None,
                detail=f"group {target.group_id} was not crawled",
            ))
            continue

        key = normalise_name(target.name)
        matches = by_name.get(key, [])

        if len(matches) > 1:
            resolutions.append(Resolution(
                target.rule_id, target.name, target.group_id, "ambiguous", None,
                candidates=tuple(_candidate_line(m) for m in matches),
                detail=f"{len(matches)} pages published under this name",
            ))
            continue

        if not matches:
            resolutions.append(Resolution(
                target.rule_id, target.name, target.group_id, "unresolved", None,
                candidates=_candidates_for(key, by_name),
                detail="no anchor on this group's indexes carries this name",
            ))
            continue

        entry = matches[0]
        try:
            html = fetcher.get(entry.url)
        except requests.RequestException as exc:
            resolutions.append(Resolution(
                target.rule_id, target.name, target.group_id, "needs-review", entry.url,
                detail=f"fetch failed: {exc}",
            ))
            continue

        kind, detail = classify_page(html)
        if kind != "rule":
            resolutions.append(Resolution(
                target.rule_id, target.name, target.group_id, "needs-review", entry.url,
                detail=f"the matched page is not a rule page ({kind}: {detail or 'index'})",
            ))
            continue

        signals = confirm_identity(target, html, detail)
        status = "resolved" if all(s.ok for s in signals) else "needs-review"
        resolutions.append(Resolution(
            target.rule_id, target.name, target.group_id, status, entry.url,
            signals=signals,
            detail="" if status == "resolved" else "; ".join(
                f"{s.signal}: {s.detail}" for s in signals if not s.ok
            ),
        ))

    return resolutions


# ── inputs ───────────────────────────────────────────────────────────────────

def load_targets(
    db_path: Path,
    source_dir: Path,
    groups: tuple[int, ...] = COMBAT_GROUPS,
    locale: str = "de-DE",
) -> list[RuleTarget]:
    """Every rule in the given combat groups, as the resolver looks for it.

    Names and seed text come from the generated `rules.db`; the `src:` book and
    page come from the pinned Optolith export, which is where they live -- the
    builder does not carry them into the database.
    """
    if not db_path.exists():
        raise FileNotFoundError(
            f"{db_path} is missing. It is a generated, untracked build artifact: "
            "run `make rules-db` first (AGENTS.md, Data Policy)."
        )
    books = _load_books(source_dir, locale)
    srcs = _load_sources(source_dir, locale)

    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        placeholders = ",".join("?" * len(groups))
        rows = conn.execute(
            f"""SELECT r.id AS id, r.group_id AS group_id, i.name AS name,
                       i.description AS description,
                       i.level1 AS level1, i.level2 AS level2,
                       i.level3 AS level3, i.level4 AS level4
                  FROM rules r
                  JOIN rules_i18n i ON i.rule_id = r.id AND i.locale = ?
                 WHERE r.category = 'special_ability' AND r.group_id IN ({placeholders})
                 ORDER BY r.group_id, r.id""",
            (locale, *groups),
        ).fetchall()
    finally:
        conn.close()

    targets = []
    for row in rows:
        text = " ".join(
            part for part in (
                row["description"], row["level1"], row["level2"],
                row["level3"], row["level4"],
            ) if part
        )
        sources = tuple(
            (books.get(book_id, book_id), page)
            for book_id, page in srcs.get(row["id"], ())
        )
        targets.append(RuleTarget(
            rule_id=row["id"], name=row["name"], group_id=row["group_id"],
            text=text, sources=sources,
        ))
    return targets


def _load_books(source_dir: Path, locale: str) -> dict[str, str]:
    path = source_dir / locale / "Books.yaml"
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or []
    return {entry["id"]: entry.get("name", entry["id"]) for entry in data if entry.get("id")}


def _load_sources(source_dir: Path, locale: str) -> dict[str, tuple[tuple[str, int], ...]]:
    path = source_dir / locale / "SpecialAbilities.yaml"
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or []
    out: dict[str, tuple[tuple[str, int], ...]] = {}
    for entry in data:
        rule_id = entry.get("id")
        if not rule_id:
            continue
        pairs = []
        for src in entry.get("src") or ():
            book_id, page = src.get("id"), src.get("firstPage")
            if book_id and isinstance(page, int):
                pairs.append((book_id, page))
        out[rule_id] = tuple(pairs)
    return out


# ── output ───────────────────────────────────────────────────────────────────

def render_report(resolutions: list[Resolution], crawls: dict[int, CrawlResult]) -> str:
    """The run's report: one line per rule, then the unresolved and ambiguous
    ones in full with the candidates that were considered."""
    lines: list[str] = []
    id_width = max((len(r.rule_id) for r in resolutions), default=6)

    for res in resolutions:
        line = f"{res.rule_id.ljust(id_width)}  {res.status:<13}  {res.url or '-'}"
        if res.detail:
            line += f"\n{' ' * (id_width + 2)}  {res.detail}"
        lines.append(line)

    needs_attention = [r for r in resolutions if r.status in ("unresolved", "ambiguous", "needs-review")]
    if needs_attention:
        lines.append("")
        lines.append("Reported, not guessed:")
        for res in needs_attention:
            lines.append(f"  {res.rule_id} ({res.name}, group {res.group_id}): {res.status}")
            if res.detail:
                lines.append(f"      {res.detail}")
            for candidate in res.candidates:
                lines.append(f"      candidate: {candidate}")
            if not res.candidates and res.status == "unresolved":
                lines.append("      candidate: none close enough to suggest")

    problems = [p for result in crawls.values() for p in result.problems]
    if problems:
        lines.append("")
        lines.append("Crawl problems:")
        lines.extend(f"  {p}" for p in problems)
        if any(p.fatal for p in problems):
            lines.append(
                "  A FATAL crawl problem means this run did not look where it said "
                "it would: rules behind it report `unresolved` for a reason that "
                "has nothing to do with them. Fix it and re-run before reading the "
                "counts below."
            )

    counts = {status: 0 for status in ("resolved", "needs-review", "unresolved", "ambiguous")}
    for res in resolutions:
        counts[res.status] = counts.get(res.status, 0) + 1
    entries = sum(len(result.entries) for result in crawls.values())
    index_pages = sum(len(result.index_urls) for result in crawls.values())
    lines.append("")
    lines.append(
        f"{counts['resolved']} resolved, {counts['needs-review']} needs-review, "
        f"{counts['unresolved']} unresolved, {counts['ambiguous']} ambiguous "
        f"out of {len(resolutions)} rule(s); "
        f"{entries} page(s) indexed across {index_pages} index page(s)"
    )
    return "\n".join(lines)


def write_map(path: Path, resolutions: list[Resolution]) -> None:
    """Write the resolution for `build_db.py` to carry into the untracked
    `rules.db`. Only confirmed rules enter `resolved`: a URL whose identity
    signals disagree is reported, and a reviewer decides. The rest of the file
    is the same report in machine-readable form, for inspection -- it lives
    under the git-ignored `.cache/` because it names abilities."""
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "resolved": {r.rule_id: r.url for r in resolutions if r.confirmed},
        "reported": [
            {
                "id": r.rule_id,
                "name": r.name,
                "group": r.group_id,
                "status": r.status,
                "url": r.url,
                "detail": r.detail,
                "candidates": list(r.candidates),
                "signals": [
                    {"signal": s.signal, "ok": s.ok, "detail": s.detail} for s in r.signals
                ],
            }
            for r in resolutions if not r.confirmed
        ],
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")


# ── driver ───────────────────────────────────────────────────────────────────

def run(
    db_path: Path = DEFAULT_DB,
    source_dir: Path | None = None,
    *,
    groups: tuple[int, ...] = COMBAT_GROUPS,
    fetcher=None,
    map_path: Path = RESOLVED_MAP_PATH,
    base_url: str = BASE_URL,
) -> int:
    fetcher = fetcher or Fetcher()
    targets = load_targets(db_path, source_dir, groups)

    crawls: dict[int, CrawlResult] = {}
    root_url = urljoin(base_url, ROOT_INDEX_PATH)
    for group_id in groups:
        trail = GROUP_INDEX_TRAIL.get(group_id)
        if trail is None:
            crawls[group_id] = CrawlResult(
                problems=[Problem(True, f"group {group_id}: no index trail known")])
            continue
        try:
            index_url = follow_trail(fetcher, root_url, trail)
        except (LookupError, requests.RequestException) as exc:
            crawls[group_id] = CrawlResult(problems=[Problem(
                True, f"group {group_id}: its index could not be reached: {exc}")])
            continue
        # Each group gets its own visited set: two groups whose subtrees
        # overlap must each record the pages they list, and a page fetched
        # twice costs nothing -- the second read is a cache hit.
        crawls[group_id] = crawl(fetcher, index_url, group_id)

    resolutions = resolve_targets(targets, crawls, fetcher)
    print(render_report(resolutions, crawls))
    write_map(map_path, resolutions)
    print(f"\nwrote {map_path} -- run `make rules-db` to carry it into rules.db")
    print(f"{fetcher.network_calls} network call(s) made")

    fatal = [p for result in crawls.values() for p in result.fatal_problems]
    if fatal:
        print(
            f"\n{len(fatal)} FATAL crawl problem(s) -- the resolution above is "
            "incomplete and the map was written anyway so the partial result is "
            "inspectable. Fix and re-run."
        )
    return 1 if fatal else 0


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB,
                        help="Generated rules.db to read names and seed text from "
                             "(default: %(default)s)")
    parser.add_argument("--source", type=Path, required=True,
                        help="Optolith data export (RULES_SOURCE) -- the src: blocks live there")
    parser.add_argument("--groups", default=",".join(str(g) for g in COMBAT_GROUPS),
                        help="Comma-separated combat group ids (default: %(default)s)")
    parser.add_argument("--cache-dir", type=Path, default=CACHE_DIR,
                        help="On-disk HTTP cache directory (default: %(default)s)")
    parser.add_argument("--map", type=Path, default=RESOLVED_MAP_PATH, dest="map_path",
                        help="Where to write the resolution (default: %(default)s)")
    args = parser.parse_args(argv)

    groups = tuple(int(g) for g in args.groups.split(",") if g.strip())
    sys.exit(run(args.db, args.source, groups=groups,
                 fetcher=Fetcher(args.cache_dir), map_path=args.map_path))


if __name__ == "__main__":
    main()
