#!/usr/bin/env python3
"""Crawl the DSA rule website from its root menu down, recording every page.

Ported from `origin/feat/rules-data-pipeline`'s `scripts/rules_sync/resolve.py`
(git show origin/feat/rules-data-pipeline:scripts/rules_sync/resolve.py). That
module resolved a fixed list of Optolith combat-group rules to their pages by
name, crawling only the five index subtrees those groups live under. Task 3 of
the 2026-09-26 rule-website page-tracking plan widens the crawl to the whole
site and drops the per-rule resolution this task has no seed database for.

Kept unchanged (bodies and docstrings): `index_anchors`, `page_base`,
`page_title`, `_fold`, `normalise_name` (and the regexes they use),
`INDEX_ANCHOR_SELECTOR`, `Problem`, `_same_site` -- all of it is generic
page parsing and crawl bookkeeping that has nothing to do with which five
groups the branch was scoped to. `classify_page` gained a third signal in the
final fix wave (Ruling R4): a content container that is a list of links.

Not ported (owner's ruling): `GROUP_INDEX_TRAIL`, `follow_trail`,
`COMBAT_GROUPS`, the three per-rule identity signals (`confirm_identity`,
`text_containment`, `parse_publications` and the book-title spelling rules),
`RuleTarget`, `Resolution`, `load_targets`, `render_report`, `write_map`,
`run`, `main`, and every `sqlite3` use. Those all belonged to matching a named
Optolith rule against a crawl scoped to five categories; this module instead
walks every category reachable from the site's own root menu and records what
it finds, with no name to match and no database to read.

Never guess a URL from an id
----------------------------
The site's own URLs are not derivable. Three shapes live side by side in the
authored corpus today: `KSF_Sturmangriff.html`, the percent-encoded
`KSF_Vorsto%C3%9F.html`, and a lowercase-hyphenated slug two directories deep
under a category path. No rule about ids or names produces all three, and a
resolver that special-cases the third has not solved the problem. So every URL
here comes from an `href` the site itself publishes, under an anchor text the
site itself writes, and is carried through as the site wrote it but for its spelling:
`check.canonical_url` gives the spellings the site serves one page under (`ö`/`%C3%B6`,
`(`/`%28`, a query's `%20`/`+`) one key.
"""
from __future__ import annotations

import difflib
import re
import unicodedata
from dataclasses import dataclass, field
from typing import NamedTuple
from urllib.parse import urljoin, urlsplit

import requests
from bs4 import BeautifulSoup

from rules_sync.check import BASE_URL, PageMissing, canonical_url
from rules_sync.normalise import (
    _DYNAMIC_WIDGET_SELECTOR,
    ContentContainerEmpty,
    ContentContainerNotFound,
    hash_html,
    normalise_html,
)

#: Index anchors on this site all carry this class, on index pages and nowhere
#: else -- verified: every rule page fetched in a full live run has zero of
#: them, and every index page has at least one. That makes it, and not the
#: content container, the thing that says which kind of page this is.
INDEX_ANCHOR_SELECTOR = "a.ulSubMenu"

#: The site root's top-level category menu.
ROOT_MENU_SELECTOR = "ul.sf-menu.level_1 > li > a"

#: The site's selection widget (`zauberauswahl.html`, `talentauswahl.html`, ... -- 32 cached
#: pages on 2026-09-26): a filter bar and one block per first letter around a grid of plain links.
#: No rule page carries it. Its filter bar lists every publication, so the link-text share
#: below cannot see these pages as the listings they are (0.07--0.75 on the cached ones). The
#: LISTING_LINKS floor still applies: `geodenritualauswahl.html`, with 2 links, stays `rule`.
SELECTION_GRID_SELECTOR = ".body_einzeln"

#: The site's search module. A detail URL the site does not know (`vorteil.html?vorteil=<a name
#: it has no page for>`) is answered with the search page for that name, whose results link
#: spelling variants of it: 101 such answers in the first content-link crawl of 2026-09-27, and
#: the module on no other page. Recorded as `broken`, never followed.
SEARCH_SELECTOR = ".mod_search"
SEARCH_DETAIL = ("the site answered with its search page: it has no page at this URL "
                 "(the page it searched for is in the query)")

#: A page with no `a.ulSubMenu` is still an index when its content container is a list of links:
#: at least LISTING_LINKS same-site links whose text is at least LISTING_SHARE of the container's
#: normalised text. Calibrated on the 4582 cached `rule` pages of 2026-09-26 (final-fix-report.md):
#: outside the selection grid, the share runs continuously from 0 to 0.625 on pages that carry
#: rule text (tables of weapons or special abilities, optional rules), then jumps to 0.78 and
#: 0.85 on the two overview pages (`Heldenerschaffung.html`, `Spezielle_Nahkampfregeln.html`).
#: The cut sits in that gap; 0.5 would have taken four pages of rule text with it.
LISTING_LINKS = 3
LISTING_SHARE = 0.7
#: A page with `a.ulSubMenu` anchors is a rule page when its content container has rule text of
#: its own, less than this share of it link text. Calibrated on the 107 menu pages of 2026-09-27
#: whose container normalised to text: the extended-combat menu page (headings and its menu inside
#: `#main`) has 0.61, the highest page with rule text 0.47.
MENU_LINK_SHARE = 0.5

#: Guard rails on the crawl. Pages reached through content links sit deeper than the index
#: trails (4 below a top category on 2026-09-26); MAX_PAGES is a stop against a redesign or a
#: cycle, far above the site's actual size.
MAX_DEPTH = 20
MAX_PAGES = 20000

#: hrefs that never name a page.
_NOT_A_PAGE = ("mailto:", "javascript:", "tel:", "data:")
_WS_RE = re.compile(r"\s+")

#: Fuzzy cutoff for the near-miss page titles a name is offered against. These
#: are suggestions for a human, never a resolution.
CANDIDATE_CUTOFF = 0.72
CANDIDATE_COUNT = 5

#: A trailing Stufen ladder as the site's titles and anchors spell it:
#: " I", " I-II", " I-III", " I–IV" (en dash included -- the site mixes them).
_LADDER_SUFFIX_RE = re.compile(r"\s+[IVX]+(?:\s*[-–—]\s*[IVX]+)?\s*$", re.IGNORECASE)
_SITE_TITLE_SUFFIX_RE = re.compile(r"\s*-\s*DSA\s+Regel-Wiki\s*$", re.IGNORECASE)


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


@dataclass(frozen=True)
class CrawledPage:
    url: str
    kind: str                 # rule | index | broken
    title: str
    hash: "str | None"
    trail: tuple[str, ...]
    detail: str = ""


@dataclass
class SiteCrawl:
    pages: dict[str, CrawledPage] = field(default_factory=dict)
    problems: list[Problem] = field(default_factory=list)

    @property
    def fatal_problems(self) -> list[Problem]:
        return [p for p in self.problems if p.fatal]


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


def _container(soup):
    return soup.find(id="main") or soup.find("main")


def _page_link(href: str, base: str) -> "str | None":
    """The canonical URL an href in the content names, or `None` when it names no page of this
    site: empty, a fragment, `mailto:`/`javascript:`, off-site, or not an `.html` path (a PDF, an
    image). The query string is kept as the site wrote it, spelled by `canonical_url`."""
    href = (href or "").strip()
    if not href or href.startswith("#") or href.lower().startswith(_NOT_A_PAGE):
        return None
    url = canonical_url(urljoin(base, href))
    parts = urlsplit(url)
    if not _same_site(url, BASE_URL) or not parts.path.endswith(".html"):
        return None
    return url


def _anchor_text(anchor) -> str:
    return _WS_RE.sub(" ", anchor.get_text().replace("\xa0", " ")).strip()


def content_links(html: str, page_url: str) -> list[tuple[str, str]]:
    """The `(anchor text, absolute URL)` of every same-site page linked from the content
    container (`#main`, else `<main>`), in document order, first anchor per URL. Joined against
    `page_base`, never rebuilt: an href is carried through as written, query included, spelled
    by `canonical_url`."""
    soup = BeautifulSoup(html, "html.parser")
    container = _container(soup)
    if container is None:
        return []
    base = page_base(html, page_url)
    out: list[tuple[str, str]] = []
    seen: set[str] = set()
    for anchor in container.find_all("a"):
        url = _page_link(anchor.get("href"), base)
        if url is None or url in seen:
            continue
        seen.add(url)
        text = _anchor_text(anchor) or (anchor.get("title") or "").strip() or url[len(BASE_URL):]
        out.append((text, url))
    return out


def _listing_counts(html: str) -> tuple[int, int, int, bool]:
    """(same-site links, their text length, container text length, selection grid present),
    over the container as `normalise_html` sees it (scripts, styles and the widget removed)."""
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style"]):
        tag.decompose()
    for widget in soup.select(_DYNAMIC_WIDGET_SELECTOR):
        widget.decompose()
    container = _container(soup)
    if container is None:
        return 0, 0, 0, False
    base = page_base(html, BASE_URL)
    links = [a for a in container.find_all("a") if _page_link(a.get("href"), base)]
    link_chars = sum(len(_anchor_text(a)) for a in links)
    try:
        text_chars = len(normalise_html(html))
    except (ContentContainerEmpty, ContentContainerNotFound):
        text_chars = 0
    return len(links), link_chars, text_chars, bool(container.select(SELECTION_GRID_SELECTOR))


def link_text_share(html: str) -> float:
    """How much of the content container's normalised text is the text of its same-site links."""
    _, link_chars, text_chars, _ = _listing_counts(html)
    return link_chars / text_chars if text_chars else 0.0


def _anchor_text_share(html: str) -> float:
    """How much of the content container's normalised text is anchor text, whatever the anchor
    links to; 0.0 for a container with no text."""
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style"]):
        tag.decompose()
    for widget in soup.select(_DYNAMIC_WIDGET_SELECTOR):
        widget.decompose()
    container = _container(soup)
    try:
        text_chars = len(normalise_html(html))
    except (ContentContainerEmpty, ContentContainerNotFound):
        return 0.0
    return sum(len(_anchor_text(a)) for a in container.find_all("a")) / text_chars


def is_listing(html: str) -> bool:
    """A content container that is a list of links (Ruling R4, calibrated -- see LISTING_SHARE):
    the site's selection grid, or at least LISTING_LINKS links making up LISTING_SHARE of the text."""
    links, link_chars, text_chars, grid = _listing_counts(html)
    if links < LISTING_LINKS:
        return False
    return grid or (text_chars > 0 and link_chars / text_chars >= LISTING_SHARE)


def classify_page(html: str) -> tuple[str, str]:
    """`("rule", text)`, `("index", "")` or `("broken", reason)`.

    First, a page carrying the site's search module (`SEARCH_SELECTOR`) is
    `("broken", SEARCH_DETAIL)`: the site's answer for a URL it has no page at.
    Then three signals, in this order:

    * **The page publishes `a.ulSubMenu` anchors** -> it is an index, unless its
      container has rule text of its own (less than `MENU_LINK_SHARE` of it
      anchor text): then it is a rule page as well, hashed, and the crawl still
      follows its menu. This has to come first, because it is the only signal
      that covers *every* index on this site. Most of them have an empty
      `#main` with the link list outside it, but not all: the extended-combat
      category publishes its links **inside** `#main`, above its sub-category
      headings, so it normalises to text and the container test alone calls it
      a rule page. It was found this way -- the first live run reported all 74
      rules in that group unresolved and named the page it had misread. And
      some menu pages carry the rules their sub-pages share (`GR_Zustand.html`,
      `Kampfregeln.html`): 105 of them on 2026-09-27.
    * **Its content container is a list of links** (`is_listing`) -> an index.
      The site's selection pages (`zauberauswahl.html` and its kind) publish
      hundreds of plain links in `#main` and no `a.ulSubMenu`; read as rule
      pages, they hid every spell, liturgy and talent behind them (Ruling R4).
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
    container = _container(BeautifulSoup(html, "html.parser"))
    if container is not None and container.select_one(SEARCH_SELECTOR):
        return "broken", SEARCH_DETAIL
    if index_anchors(html):
        if is_listing(html) or _anchor_text_share(html) >= MENU_LINK_SHARE:
            return "index", ""
        try:
            return "rule", normalise_html(html)
        except (ContentContainerEmpty, ContentContainerNotFound):
            return "index", ""
    if is_listing(html):
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


def root_categories(html: str, url: str) -> list[tuple[str, str]]:
    """The top categories the site root's menu lists, as (anchor text, absolute URL)."""
    soup = BeautifulSoup(html, "html.parser")
    anchors = soup.select(ROOT_MENU_SELECTOR)
    if not anchors:
        raise LookupError(f"{url}: no top menu ({ROOT_MENU_SELECTOR}) -- the site's markup changed")
    base = page_base(html, url)
    out = []
    for a in anchors:
        text, href = a.get_text(strip=True), (a.get("href") or "").strip()
        child = canonical_url(urljoin(base, href))
        if text and href and _same_site(child, url) and child.endswith(".html") and (text, child) not in out:
            out.append((text, child))
    return out


def crawl(fetcher, root_url: str = BASE_URL, *, max_depth: int = MAX_DEPTH,
          max_pages: int = MAX_PAGES) -> SiteCrawl:
    """Breadth-first walk from the root menu's categories through every page the site links.

    From every page fetched -- index, listing or rule -- the crawl follows its `a.ulSubMenu`
    anchors, then every same-site page link in its content container (`content_links`, Ruling
    R4): a selection page's plain links, a rule page's cross-references. Each page is returned
    with the trail of anchor texts by which it was first reached, breadth-first -- along index
    edges first (menu anchors, and a listing page's list): every other content link, a rule
    page's or a menu page's intro text's, is a cross-reference, followed only once no index edge
    is left, so it adds the pages no index leads to without re-homing the rest.

    Fatal (the run did not look where it said it would): a fetch that failed after the
    fetcher's retries, a page at `max_depth` that still links to pages not yet seen, the page
    cap, and a top category read as a rule page that links nowhere -- the shape that once hid
    whole categories. Not fatal: a page with no text and no anchors (`broken`), a page the site
    answers 404/410 for (`PageMissing`: left out, so `pages.merge` marks a known one gone), and a
    top category that carries rule text but links on (noted; its links are followed).

    Controller ruling R1: a root that cannot be fetched (`requests.RequestException`)
    or that has no top menu (`root_categories` raising `LookupError`) is a fatal
    `Problem` naming the root URL and the reason -- the crawl returns its (empty)
    `SiteCrawl` rather than raising, the same as any other fatal crawl problem.
    """
    result = SiteCrawl()
    try:
        root_html = fetcher.get(root_url)
    except requests.RequestException as exc:
        result.problems.append(Problem(True, f"{root_url}: fetch failed: {exc}"))
        return result
    try:
        categories = root_categories(root_html, root_url)
    except LookupError as exc:
        result.problems.append(Problem(True, str(exc)))
        return result
    # The root itself is never a category page (it is the entry point, not
    # something `pages` records), and an index whose link list loops back to
    # it -- the home link every page carries -- must not re-fetch or re-store
    # it either.
    seen = {canonical_url(root_url)}
    queue = [(url, 0, (text,)) for text, url in categories]
    seen.update(url for url, _, _ in queue)
    # Cross-references (content links other than a listing page's own list) wait here, first
    # finding kept, until no index edge has anything left to offer: a page's trail is the site's
    # own index trail wherever it has one. Crawling them in plain breadth-first order moved 650
    # of the 5230 pages of 2026-09-26 into another top category (final-fix-report.md).
    pending: dict[str, tuple[int, tuple[str, ...]]] = {}
    while queue or pending:
        if not queue:
            queue = [(url, depth, trail) for url, (depth, trail) in pending.items() if url not in seen]
            seen.update(url for url, _, _ in queue)
            pending = {}
            continue
        url, depth, trail = queue.pop(0)
        if len(result.pages) >= max_pages:
            result.problems.append(Problem(True, f"crawl stopped at {max_pages} pages -- look at the site"))
            break
        try:
            html = fetcher.get(url)
        except PageMissing as exc:
            # Not fatal: the site says the page is not there. A link to it is the site's own
            # dead link; a page `pages.yaml` knew becomes `gone` when the merge misses it.
            result.problems.append(Problem(False, f"{url}: {exc}"))
            continue
        except requests.RequestException as exc:
            # Fatal: a page that could not be fetched may have been an index,
            # and everything behind it is missing from the crawl with no sign
            # in any single page's result. A retry costs nothing -- the pages
            # that did arrive are on disk.
            result.problems.append(Problem(True, f"{url}: fetch failed: {exc}"))
            continue
        kind, detail = classify_page(html)
        if kind == "broken":
            # Not fatal: a page that carries no rule text and no anchors is a
            # property of this site (Task 5 fix round 4 found five of them),
            # not a failure of the crawl.
            # Nor is anything on it followed: an empty page links nowhere, and a search page's
            # results are spelling variants of a name, not the site's own links.
            result.problems.append(Problem(False, f"{url}: {detail}"))
            result.pages[url] = CrawledPage(url, "broken", page_title(html), None, trail, detail)
            continue
        if kind == "rule":
            result.pages[url] = CrawledPage(url, "rule", page_title(html), hash_html(html), trail)
        else:
            result.pages[url] = CrawledPage(url, "index", page_title(html), None, trail)

        # The site's index edges: its menu anchors, or -- on a listing page, which has none --
        # the listing itself. Every other content link is a cross-reference.
        base = page_base(html, url)
        menu = [(text, canonical_url(urljoin(base, href))) for text, href in index_anchors(html)]
        content = content_links(html, url)
        if menu:
            links = [(text, child, True) for text, child in menu] + [(t, c, False) for t, c in content]
        else:
            links = [(text, child, kind == "index") for text, child in content]
        children: dict[str, tuple[str, bool]] = {}
        for text, child, is_index_edge in links:
            # An index edge claims a page a cross-reference is still holding; a cross-reference
            # never takes one over.
            if (_same_site(child, root_url) and child not in seen and child not in children
                    and (is_index_edge or child not in pending)):
                children[child] = (text, is_index_edge)

        if depth == 0 and kind == "rule":
            if children:
                result.problems.append(Problem(False, f"{url}: top category {trail[0]!r} reads as a "
                                                      f"rule page; following its {len(children)} link(s)"))
            else:
                result.problems.append(Problem(True, f"{url}: top category {trail[0]!r} reads as a "
                                                     f"rule page and links nowhere -- its pages are missing"))
        if not children:
            continue
        if depth >= max_depth:
            # Fatal: the pages below this one are missing from the crawl --
            # not something any single page's absence would otherwise reveal.
            result.problems.append(Problem(True, f"{url}: max depth {max_depth} reached, "
                                                 f"not following {len(children)} link(s)"))
            continue
        for child, (text, is_index_edge) in children.items():
            if is_index_edge:
                seen.add(child)
                pending.pop(child, None)
                queue.append((child, depth + 1, trail + (text,)))
            else:
                pending[child] = (depth + 1, trail + (text,))
    return result


def candidates(name: str, titles) -> list[str]:
    """Near-miss page titles for a name, for a person to look at. Never a resolution."""
    by_key = {}
    for t in titles:
        by_key.setdefault(normalise_name(t), t)
    keys = difflib.get_close_matches(normalise_name(name), list(by_key), n=CANDIDATE_COUNT, cutoff=CANDIDATE_CUTOFF)
    return [by_key[k] for k in keys]
