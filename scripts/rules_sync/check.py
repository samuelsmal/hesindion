"""The fetch side of page tracking, and what the rule files say about their pages.

Ported from feat/rules-data-pipeline. `Fetcher` is its disk-cached, rate-limited GET, plus a
`max_age`: `make rules-sync` has to see today's page, so a copy older than that is fetched
again, while a run that stopped half-way resumes from the copies it already made.
"""
from __future__ import annotations

import datetime
import hashlib
import re
import time
import unicodedata
from pathlib import Path
from typing import NamedTuple
from urllib.parse import urljoin, urlsplit, urlunsplit

import requests
import yaml

from rulec import layout

REPO_ROOT = Path(__file__).resolve().parents[2]
CACHE_DIR = REPO_ROOT / ".cache" / "rules_sync"
BASE_URL = "https://dsa.ulisses-regelwiki.de/"

# Politeness convention for dsa.ulisses-regelwiki.de -- same values as
# scripts/scrape_effects/scrape_effects.py, defined locally rather than
# imported from it (that module is slated for deletion, ADR-0007; this one
# should not depend on it).
DELAY = 1.0
HEADERS = {"User-Agent": "DSA-Companion-Scraper/1.0"}

#: Controller ruling R5: a timeout, a dropped connection, a 5xx or a 429 is tried again, up to
#: this many attempts in all, pausing `DELAY * attempt` before each one.
ATTEMPTS = 3
#: Seconds to wait for one response. An unknown detail URL is redirected (302) to the site's
#: search for its name, and a paragraph-long name took that search 29 s on 2026-09-27.
TIMEOUT = 60
_RETRY_STATUS = frozenset({429}) | frozenset(range(500, 600))
_MISSING_STATUS = frozenset({404, 410})


class PageMissing(requests.HTTPError):
    """The site answered 404 or 410: the page is not there. Not retried, and not a crawl failure
    -- the crawl notes it and leaves the page out, so `pages.merge` marks a known page `gone`."""


#: A run of percent escapes, decoded together so that a UTF-8 sequence decodes as one character.
_ESCAPES_RE = re.compile(r"(?:%[0-9A-Fa-f]{2})+")
#: The ASCII characters an escape is decoded to: RFC 3986's unreserved ones, the sub-delims
#: that split nothing on this site, and the space (written back as `+` or `%20`). `/ ? & = + ; # %` stay escaped: decoding one could split a
#: query value or join two.
_DECODED = frozenset("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~()!*' ")


def _escape(char: str) -> str:
    return "".join(f"%{b:02X}" for b in char.encode("utf-8"))


def _decode_escapes(match: "re.Match") -> str:
    run = match.group(0)
    try:
        text = bytes.fromhex(run.replace("%", "")).decode("utf-8")
    except UnicodeDecodeError:
        return run.upper()
    return "".join(c if c in _DECODED or ord(c) > 127 else _escape(c) for c in text)


def _canonical_part(part: str, space: str) -> str:
    text = unicodedata.normalize("NFC", _ESCAPES_RE.sub(_decode_escapes, part))
    return "".join(space if c == " " else _escape(c) if ord(c) > 127 else c for c in text)


def canonical_url(url: str) -> str:
    """`url` joined against the site root, fragment dropped, and spelled one way: the site
    serves the same page under `ö`, `o\u0308`, `%C3%B6` and `%c3%b6`, and under `(`/`%28`, and a
    query's `%20` is its `+`. Non-ASCII is escaped as NFC UTF-8, the unreserved characters and
    `()!*'` are not, a query's space is `+` and a path's `%20`. Every other escape (`%2F`,
    `%26`, `%2B`, …) is kept, hex in upper case, and so is an escape that is no UTF-8."""
    parts = urlsplit(urljoin(BASE_URL, url.strip()))
    return urlunsplit((parts.scheme, parts.netloc, _canonical_part(parts.path, "%20"),
                       _canonical_part(parts.query, "+"), ""))


class Fetcher:
    """Disk-cached, rate-limited HTTP GET.

    A cache hit reads the on-disk capture and returns immediately: no network
    call, no sleep. A cache miss sleeps `DELAY` seconds (politeness, matching
    the existing scraper), fetches, and writes the capture to disk before
    returning it. `network_calls` counts only real fetches, so a test (or a
    caller) can assert that a second run against a warm cache makes zero of
    them.

    `max_age`, `None` by default, controls whether a cached copy is still
    considered fresh: `None` means any cached copy is used regardless of age
    (the branch's behaviour); `timedelta(0)` means every URL is fetched again
    (no cached copy is ever fresh); anything in between makes a copy younger
    than `max_age` a cache hit and an older one a cache miss.
    """

    def __init__(self, cache_dir: Path = CACHE_DIR, session=None, max_age: "datetime.timedelta | None" = None):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.session = session or requests.Session()
        self.max_age = max_age
        self.network_calls = 0

    def _cache_path(self, url: str) -> Path:
        digest = hashlib.sha256(url.encode("utf-8")).hexdigest()
        return self.cache_dir / f"{digest}.html"

    def _fresh(self, path: Path) -> bool:
        if not path.exists():
            return False
        if self.max_age is None:
            return True
        return time.time() - path.stat().st_mtime < self.max_age.total_seconds()

    def get(self, url: str) -> str:
        cache_path = self._cache_path(url)
        if self._fresh(cache_path):
            return cache_path.read_text(encoding="utf-8")

        response = self._fetch(url)
        self.network_calls += 1
        cache_path.write_text(response.text, encoding="utf-8")
        return response.text

    def _fetch(self, url: str):
        """One page off the network, retrying a transient failure (`ATTEMPTS` in all). The pause
        before attempt n is `DELAY * n`: the first is the ordinary politeness delay."""
        for attempt in range(1, ATTEMPTS + 1):
            last = attempt == ATTEMPTS
            time.sleep(DELAY * attempt)
            try:
                response = self.session.get(url, headers=HEADERS, timeout=TIMEOUT)
            except (requests.Timeout, requests.ConnectionError):
                if last:
                    raise
                continue
            status = getattr(response, "status_code", 200)
            if status in _MISSING_STATUS:
                raise PageMissing(f"{status} page missing: {url}", response=response)
            if status in _RETRY_STATUS and not last:
                continue
            response.raise_for_status()
            return response
        raise AssertionError("unreachable")               # pragma: no cover


class RuleSource(NamedTuple):
    rule_id: str
    path: Path
    url: str
    hash: "str | None"
    reviewed: bool
    #: `source.url` (True) or a `source.also[].url` (False). `source.hash` is the primary
    #: page's hash, so an `also` entry carries `hash=None`: it has no hash of its own.
    primary: bool = True


def rule_sources(root: Path = layout.ROOT) -> list[RuleSource]:
    """One entry per page a rule file names: `source.url` first (primary, with `source.hash`),
    then any `source.also[].url` (not primary, no hash)."""
    out = []
    for path in layout.rule_files(root):
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        if not isinstance(doc, dict):
            continue
        source = doc.get("source") or {}
        rule_id, reviewed = str(doc.get("id", path.stem)), bool(doc.get("reviewed"))
        if source.get("url"):
            out.append(RuleSource(rule_id, path, canonical_url(str(source["url"])),
                                  source.get("hash"), reviewed, True))
        for also in source.get("also") or []:
            if isinstance(also, dict) and also.get("url"):
                out.append(RuleSource(rule_id, path, canonical_url(str(also["url"])), None, reviewed, False))
    return out
