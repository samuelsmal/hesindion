"""The fetch side of page tracking, and what the rule files say about their pages.

Ported from feat/rules-data-pipeline. `Fetcher` is its disk-cached, rate-limited GET, plus a
`max_age`: `make rules-sync` has to see today's page, so a copy older than that is fetched
again, while a run that stopped half-way resumes from the copies it already made.
"""
from __future__ import annotations

import datetime
import hashlib
import time
from pathlib import Path
from typing import NamedTuple
from urllib.parse import urljoin

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


def canonical_url(url: str) -> str:
    """`url` joined against the site root, fragment dropped, otherwise unchanged."""
    return urljoin(BASE_URL, url.strip()).partition("#")[0]


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

        time.sleep(DELAY)
        response = self.session.get(url, headers=HEADERS, timeout=15)
        response.raise_for_status()
        self.network_calls += 1

        cache_path.write_text(response.text, encoding="utf-8")
        return response.text


class RuleSource(NamedTuple):
    rule_id: str
    path: Path
    url: str
    hash: "str | None"
    reviewed: bool


def rule_sources(root: Path = layout.ROOT) -> list[RuleSource]:
    """One entry per page a rule file names: `source.url`, and any `source.also[].url`."""
    out = []
    for path in layout.rule_files(root):
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        if not isinstance(doc, dict):
            continue
        source = doc.get("source") or {}
        urls = [source.get("url")] + [a.get("url") for a in source.get("also") or [] if isinstance(a, dict)]
        for url in filter(None, urls):
            out.append(RuleSource(str(doc.get("id", path.stem)), path, canonical_url(str(url)),
                                  source.get("hash"), bool(doc.get("reviewed"))))
    return out
