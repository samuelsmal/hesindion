#!/usr/bin/env python3
"""Deterministic drift check for `specs/rules/*.yaml`.

For each authored rule file, compares its recorded `source.hash` against a
fresh hash of the text `source.url` serves today (see normalise.py for the
text -> hash reduction). No model is involved -- this is the half of rule
reconciliation that is fully reproducible; a later, separate piece adds an
LLM authoring agent on top of it.

Reports each rule as one of:

  ok                `source.hash` still matches a fresh fetch of `source.url`.
  drifted           it no longer matches -- the wiki text looks like it
                     changed since `source.checked`, or the URL could not be
                     fetched.
  unverified        the file still carries the placeholder every migrated
                     rule was seeded with (`url: .../UNVERIFIED`,
                     `checked: 1970-01-01`, `hash: sha256:<64 zeros>`) and has
                     never been checked against a real page. Resolving real
                     URLs for these is a separate task's job; this script
                     only reports the marker, it never guesses.
  structure-changed  the fetched page has neither `id="main"` nor a `<main>`
                     element (normalise.py's `ContentContainerNotFound`) --
                     this normaliser no longer knows what part of the page is
                     the rule text, so it refuses to guess (fix round 2: the
                     previous fallback to `<body>` silently picked up a
                     dynamic widget and reported permanent false drift; see
                     the report). This needs a human to look at the page and
                     update the normaliser, not a routine re-check.

Exit code is 0 unless at least one rule is `drifted` or `structure-changed`
-- an `unverified` rule does not fail the build.

Requests are cached on disk under `.cache/rules_sync/` (git-ignored) and
rate-limited to one per second between actual network fetches, matching the
`DELAY`/`HEADERS` politeness convention `scripts/scrape_effects/
scrape_effects.py` already uses for this host (the value is not imported
from there -- ADR-0007 slates that module for deletion, and this one should
not depend on it). A cache hit makes no network call and does not sleep.
"""
from __future__ import annotations

import argparse
import hashlib
import sys
import time
from pathlib import Path
from typing import NamedTuple

import requests
import yaml

from scripts.rules_sync.normalise import ContentContainerNotFound, hash_html

REPO_ROOT = Path(__file__).resolve().parents[2]
RULES_DIR = REPO_ROOT / "specs" / "rules"
CACHE_DIR = REPO_ROOT / ".cache" / "rules_sync"

# Politeness convention for dsa.ulisses-regelwiki.de -- same values as
# scripts/scrape_effects/scrape_effects.py, defined locally rather than
# imported from it (that module is slated for deletion, ADR-0007; this one
# should not depend on it).
DELAY = 1.0
HEADERS = {"User-Agent": "DSA-Companion-Scraper/1.0"}

# Files under specs/rules/ that are not one-rule-per-file authored specs.
NON_RULE_FILES = {"schema.json", "SOURCES.yaml"}

UNVERIFIED_URL = "https://dsa.ulisses-regelwiki.de/UNVERIFIED"
UNVERIFIED_HASH = "sha256:" + "0" * 64
UNVERIFIED_CHECKED = "1970-01-01"

__all__ = ["Fetcher", "Result", "check_rule", "iter_rule_files", "run", "main"]


class Result(NamedTuple):
    rule_id: str
    status: str  # "ok" | "drifted" | "unverified" | "structure-changed"
    detail: str


class Fetcher:
    """Disk-cached, rate-limited HTTP GET.

    A cache hit reads the on-disk capture and returns immediately: no network
    call, no sleep. A cache miss sleeps `DELAY` seconds (politeness, matching
    the existing scraper), fetches, and writes the capture to disk before
    returning it. `network_calls` counts only real fetches, so a test (or a
    caller) can assert that a second run against a warm cache makes zero of
    them.
    """

    def __init__(self, cache_dir: Path = CACHE_DIR, session: "requests.Session | None" = None):
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.session = session or requests.Session()
        self.network_calls = 0

    def _cache_path(self, url: str) -> Path:
        digest = hashlib.sha256(url.encode("utf-8")).hexdigest()
        return self.cache_dir / f"{digest}.html"

    def get(self, url: str) -> str:
        cache_path = self._cache_path(url)
        if cache_path.exists():
            return cache_path.read_text(encoding="utf-8")

        time.sleep(DELAY)
        response = self.session.get(url, headers=HEADERS, timeout=15)
        response.raise_for_status()
        self.network_calls += 1

        cache_path.write_text(response.text, encoding="utf-8")
        return response.text


def iter_rule_files(rules_dir: Path = RULES_DIR):
    """Yield each authored rule YAML file, in a stable (sorted) order."""
    for path in sorted(rules_dir.glob("*.yaml")):
        if path.name in NON_RULE_FILES:
            continue
        yield path


def _is_unverified(url: str, checked: str, recorded_hash: str) -> bool:
    # Any one of the three placeholder markers is enough to call it
    # unverified -- a partially-filled-in file (e.g. a real URL pasted in but
    # `checked`/`hash` not yet updated) is still not something we've actually
    # checked against a real page.
    return url == UNVERIFIED_URL or checked == UNVERIFIED_CHECKED or recorded_hash == UNVERIFIED_HASH


def check_rule(path: Path, fetcher: Fetcher) -> Result:
    """Check one authored rule file against the wiki. Never raises on a
    fetch failure -- that is reported as `drifted` with the error as detail,
    not a crash that would take the whole run down. A missing content
    container (`ContentContainerNotFound`) is reported as `structure-changed`,
    not `drifted` -- it is a categorically different failure (the page's
    template changed, not its text) that needs a human to update the
    normaliser, not a routine re-check."""
    doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    rule_id = doc.get("id", path.stem)
    source = doc.get("source") or {}
    url = str(source.get("url", ""))
    checked = str(source.get("checked", ""))
    recorded_hash = str(source.get("hash", ""))

    if _is_unverified(url, checked, recorded_hash):
        return Result(rule_id, "unverified", "placeholder not yet resolved")

    try:
        html = fetcher.get(url)
    except requests.RequestException as exc:
        return Result(rule_id, "drifted", f"fetch failed: {exc}")

    try:
        current_hash = hash_html(html)
    except ContentContainerNotFound as exc:
        return Result(rule_id, "structure-changed", f"{url}: {exc}")

    if current_hash == recorded_hash:
        return Result(rule_id, "ok", "")
    return Result(rule_id, "drifted", f"recorded {recorded_hash} != current {current_hash}")


def run(rules_dir: Path = RULES_DIR, fetcher: "Fetcher | None" = None) -> int:
    """Check every authored rule file, print a table, return the process exit
    code (0 unless something drifted or a page's structure changed)."""
    fetcher = fetcher or Fetcher()
    results = [check_rule(path, fetcher) for path in iter_rule_files(rules_dir)]

    id_width = max((len(r.rule_id) for r in results), default=2)
    for r in results:
        line = f"{r.rule_id.ljust(id_width)}  {r.status:<18}"
        if r.detail:
            line += f"  {r.detail}"
        print(line)

    ok = [r for r in results if r.status == "ok"]
    drifted = [r for r in results if r.status == "drifted"]
    unverified = [r for r in results if r.status == "unverified"]
    structure_changed = [r for r in results if r.status == "structure-changed"]
    print(
        f"\n{len(ok)} ok, {len(drifted)} drifted, {len(unverified)} unverified, "
        f"{len(structure_changed)} structure-changed out of {len(results)} rule(s) "
        f"-- {fetcher.network_calls} network call(s) made"
    )

    return 1 if (drifted or structure_changed) else 0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--rules-dir", type=Path, default=RULES_DIR,
        help="Directory of authored specs/rules/*.yaml files (default: %(default)s)",
    )
    parser.add_argument(
        "--cache-dir", type=Path, default=CACHE_DIR,
        help="On-disk HTTP cache directory (default: %(default)s)",
    )
    args = parser.parse_args()
    sys.exit(run(args.rules_dir, Fetcher(args.cache_dir)))


if __name__ == "__main__":
    main()
