#!/usr/bin/env python3
"""Crawl the DSA rule website from its root menu down, recording every page.

Ported from `origin/feat/rules-data-pipeline`'s `scripts/rules_sync/resolve.py`
(git show origin/feat/rules-data-pipeline:scripts/rules_sync/resolve.py). That
module resolved a fixed list of Optolith combat-group rules to their pages by
name, crawling only the five index subtrees those groups live under. Task 3 of
the 2026-09-26 rule-website page-tracking plan widens the crawl to the whole
site and drops the per-rule resolution this task has no seed database for.

Kept unchanged (bodies and docstrings): `index_anchors`, `page_base`,
`page_title`, `classify_page`, `_fold`, `normalise_name` (and the regexes they
use), `INDEX_ANCHOR_SELECTOR`, `Problem`, `_same_site` -- all of it is generic
page parsing and crawl bookkeeping that has nothing to do with which five
groups the branch was scoped to.

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
site itself writes, and is carried through byte for byte.
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

from rules_sync.check import BASE_URL, canonical_url
from rules_sync.normalise import (
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

#: Guard rails on the crawl. The deepest trail seen on 2026-09-26 is 4 below a
#: top category; MAX_PAGES is a stop against a redesign or a cycle, far above
#: the site's actual size.
MAX_DEPTH = 6
MAX_PAGES = 20000

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
    """Breadth-first walk from the root menu's categories through every index page.

    Kept from the branch: an index is a page with `a.ulSubMenu` anchors; its anchors
    are enqueued; a fetch failure, a depth stop and a page cap are fatal because every page behind
    them is missing with no sign of it; a page with no text and no anchors is noted, not fatal.
    New: every page reached is returned, index pages included, each with the trail of anchor
    texts by which it was first reached.

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
    while queue:
        url, depth, trail = queue.pop(0)
        if len(result.pages) >= max_pages:
            result.problems.append(Problem(True, f"crawl stopped at {max_pages} pages -- look at the site"))
            break
        try:
            html = fetcher.get(url)
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
            # not a failure of the crawl. It simply yields no further pages
            # beyond itself.
            result.problems.append(Problem(False, f"{url}: {detail}"))
            result.pages[url] = CrawledPage(url, "broken", page_title(html), None, trail, detail)
            continue
        if kind == "rule":
            result.pages[url] = CrawledPage(url, "rule", page_title(html), hash_html(html), trail)
            continue
        result.pages[url] = CrawledPage(url, "index", page_title(html), None, trail)
        if depth >= max_depth:
            # Fatal: the subtree below this page is missing from the crawl --
            # not something any single page's absence would otherwise reveal.
            result.problems.append(Problem(True, f"{url}: max depth {max_depth} reached, not descending"))
            continue
        base = page_base(html, url)
        for text, href in index_anchors(html):
            child = canonical_url(urljoin(base, href))
            if not _same_site(child, root_url) or child in seen:
                continue
            seen.add(child)
            queue.append((child, depth + 1, trail + (text,)))
    return result


def candidates(name: str, titles) -> list[str]:
    """Near-miss page titles for a name, for a person to look at. Never a resolution."""
    by_key = {}
    for t in titles:
        by_key.setdefault(normalise_name(t), t)
    keys = difflib.get_close_matches(normalise_name(name), list(by_key), n=CANDIDATE_COUNT, cutoff=CANDIDATE_CUTOFF)
    return [by_key[k] for k in keys]
