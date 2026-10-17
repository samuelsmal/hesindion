"""specs/rules/pages.yaml: every page of the rule website, its hash, and what is skipped.

`make rules-sync` writes it; a person edits only `skip`. Nothing here decides a page's status:
that is derived from this file and the rule files, by `coverage.py`.
"""
from __future__ import annotations

import datetime
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from rulec import layout
from rules_sync.check import BASE_URL, canonical_url

PATH = layout.ROOT / layout.PAGES
FIELDS = ("title", "in", "kind", "hash", "fetched", "skip", "gone", "detail")
HEADER = ("# Every page of https://dsa.ulisses-regelwiki.de/, written by `make rules-sync`.\n"
          "# Edit only `skip` (here, or on a page). Status is derived: `make rules-coverage`.\n")
SEP = " / "

#: `yaml.safe_dump` appends an explicit `...` end-of-document marker after a
#: bare (unquoted) top-level scalar -- never after a quoted scalar or a flow
#: collection. `_line` is also used to dump a bare page key on its own, so
#: that marker has to come back off, or it lands mid-line in the written file
#: and breaks the round trip.
_DOC_END = "\n..."


def key_of(url: str) -> str:
    return url[len(BASE_URL):] if url.startswith(BASE_URL) else url


@dataclass
class Registry:
    synced: "datetime.date | None" = None
    skip: dict = field(default_factory=dict)
    pages: dict = field(default_factory=dict)

    def skip_reason(self, key: str) -> "str | None":
        page = self.pages.get(key, {})
        if page.get("skip"):
            return page["skip"]
        trail = page.get("in", "")
        best = None
        for prefix, reason in self.skip.items():
            if trail == prefix or trail.startswith(prefix + SEP):
                if best is None or len(prefix) > len(best[0]):
                    best = (prefix, reason)
        return best[1] if best else None


def merge(old: Registry, crawl, today: datetime.date) -> Registry:
    if crawl.fatal_problems:
        raise ValueError("the crawl did not finish; pages.yaml not written:\n"
                          + "\n".join(str(p) for p in crawl.fatal_problems))
    new = Registry(synced=today, skip=dict(old.skip))
    for url, page in crawl.pages.items():
        key = key_of(url)
        before = old.pages.get(key, {})
        entry = {"title": page.title, "in": SEP.join(page.trail), "kind": page.kind}
        if page.hash:
            entry["hash"] = page.hash
            entry["fetched"] = before["fetched"] if before.get("hash") == page.hash else today
        if before.get("skip"):
            entry["skip"] = before["skip"]
        if page.detail:
            entry["detail"] = page.detail
        new.pages[key] = entry
    for key, before in old.pages.items():
        if key not in new.pages:
            new.pages[key] = {**before, "gone": before.get("gone") or today}
    return new


def _canonical_pages(entries: dict) -> dict:
    """`entries` keyed by `canonical_url`'s spelling. Where two keys spell one page, a current
    entry wins over a gone one, then one with its own `skip`, then the first key; a `skip` on
    the losing entry is kept."""
    groups: dict[str, list] = {}
    for key in sorted(entries, key=str):
        groups.setdefault(key_of(canonical_url(str(key))), []).append(entries[key])
    out = {}
    for key, group in groups.items():
        entry = dict(min(group, key=lambda e: (bool(e.get("gone")), not e.get("skip"))))
        skip = next((e["skip"] for e in group if e.get("skip")), None)
        if skip and not entry.get("skip"):
            entry["skip"] = skip
        out[key] = entry
    return out


def load(text: str) -> Registry:
    doc = yaml.safe_load(text) or {}
    return Registry(doc.get("synced"), dict(doc.get("skip") or {}),
                    _canonical_pages(dict(doc.get("pages") or {})))


def _line(value) -> str:
    text = yaml.safe_dump(value, default_flow_style=True, allow_unicode=True,
                           sort_keys=False, width=10**9).strip()
    return text[: -len(_DOC_END)] if text.endswith(_DOC_END) else text


def dump(reg: Registry) -> str:
    out = [HEADER, f"synced: {reg.synced}\n" if reg.synced else "synced: null\n"]
    out.append("skip:\n" if reg.skip else "skip: {}\n")
    for prefix in sorted(reg.skip):
        out.append(f"  {_line({prefix: reg.skip[prefix]})[1:-1]}\n")
    out.append("pages:\n")
    for key in sorted(reg.pages):
        entry = {f: reg.pages[key][f] for f in FIELDS if reg.pages[key].get(f) is not None}
        out.append(f"  {_line(key)}: {_line(entry)}\n")
    return "".join(out)


def read(path: Path = PATH) -> Registry:
    return load(path.read_text(encoding="utf-8")) if path.exists() else Registry()


def write(reg: Registry, path: Path = PATH) -> None:
    path.write_text(dump(reg), encoding="utf-8")
