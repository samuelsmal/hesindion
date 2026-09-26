"""make rules-coverage: how many rule-website pages are processed, per top category and status,
and which rule files to reprocess.

Offline: reads `pages.yaml` and the rule files only, no network access.

    make rules-coverage                # the table and the sections
    make rules-coverage LIST=new       # the page keys and titles of one status
    make rules-coverage CHECK=1        # exit 1 on a changed page, a rule whose page is unknown,
                                       # or a rule on a non-rule page (index, broken, gone)
"""
from __future__ import annotations

import argparse
import collections
import sys
from pathlib import Path

import yaml

from rulec import layout
from rules_sync import pages, resolve
from rules_sync.check import rule_sources

#: First match wins, in this order (also the `--list` vocabulary and the table's column order,
#: after the leading `pages` column).
STATUSES = ("new", "skipped", "drafted", "reviewed", "changed", "unhashed", "gone")
COLUMNS = ("pages",) + STATUSES
CATEGORY_WIDTH = 45
COLUMN_WIDTH = 10


def status(reg, key, named) -> str:
    """One `kind: rule` page's status, first match wins (task-7-brief.md)."""
    page = reg.pages[key]
    if page.get("gone"):
        return "gone"
    if reg.skip_reason(key):
        return "skipped"
    if not named:
        return "new"
    # Only a rule's `source.url` carries a hash; an `also` page is named, never compared.
    primaries = [s for s in named if s.primary]
    if any(s.hash and s.hash != page.get("hash") for s in primaries):
        return "changed"
    if any(s.hash is None for s in primaries):
        return "unhashed"
    return "reviewed" if all(s.reviewed for s in named) else "drafted"


def _group_by_key(sources) -> dict:
    by_key = collections.defaultdict(list)
    for s in sources:
        by_key[pages.key_of(s.url)].append(s)
    return by_key


def statuses(reg, sources) -> dict:
    """One status per `kind: rule` page in `reg`. `index` and `broken` pages are left out."""
    by_key = _group_by_key(sources)
    return {
        key: status(reg, key, by_key.get(key, []))
        for key, entry in reg.pages.items()
        if entry.get("kind") == "rule"
    }


def unknown(reg, sources) -> list:
    """The rule sources whose URL key names no page in `reg` at all."""
    return [s for s in sources if pages.key_of(s.url) not in reg.pages]


def on_non_rule_page(reg, sources) -> list:
    """`(rule id, page key, kind)` for every rule source whose page is known but is not a
    current rule page: `index`, `broken`, or `gone`. Sorted, one line per rule and page."""
    out = set()
    for s in sources:
        key = pages.key_of(s.url)
        page = reg.pages.get(key)
        if page is None:
            continue
        kind = "gone" if page.get("gone") else page.get("kind")
        if kind != "rule":
            out.add((s.rule_id, key, kind))
    return sorted(out)


def _rule_name(source, cache: dict) -> str:
    """The rule file's `name:`, cached per path; the rule id when there is none."""
    if source.path not in cache:
        try:
            doc = yaml.safe_load(source.path.read_text(encoding="utf-8")) or {}
        except OSError:
            doc = {}
        cache[source.path] = doc.get("name") if isinstance(doc, dict) else None
    return cache[source.path] or source.rule_id


def render(reg, sources, st: dict) -> str:
    by_key = _group_by_key(sources)
    cats = collections.defaultdict(collections.Counter)
    total = collections.Counter()
    index_count = sum(1 for e in reg.pages.values() if e.get("kind") == "index")
    broken_count = sum(1 for e in reg.pages.values() if e.get("kind") == "broken")

    for key, s in st.items():
        cat = reg.pages[key].get("in", "").split(pages.SEP)[0]
        cats[cat]["pages"] += 1
        cats[cat][s] += 1
        total["pages"] += 1
        total[s] += 1

    def row(label, counts) -> str:
        cells = "".join(f"{counts[col]:>{COLUMN_WIDTH}}" for col in COLUMNS)
        return f"{label:<{CATEGORY_WIDTH}}{cells}"

    lines = [f"{'category':<{CATEGORY_WIDTH}}" + "".join(f"{c:>{COLUMN_WIDTH}}" for c in COLUMNS)]
    for cat in sorted(cats):
        lines.append(row(cat, cats[cat]))
    lines.append(row("total", total))
    lines.append(f"\nindex pages: {index_count}, broken pages: {broken_count}")

    changed_keys = sorted(k for k, s in st.items() if s == "changed")
    if changed_keys:
        lines.append("\nchanged:")
        for key in changed_keys:
            page = reg.pages[key]
            ids = sorted({s.rule_id for s in by_key.get(key, [])
                          if s.primary and s.hash and s.hash != page.get("hash")})
            lines.append(f"  {key}: {', '.join(ids)}")

    skipped_with_rules = sorted(k for k, s in st.items() if s == "skipped" and by_key.get(k))
    if skipped_with_rules:
        lines.append("\nskipped but has rules:")
        for key in skipped_with_rules:
            ids = sorted({s.rule_id for s in by_key.get(key, [])})
            lines.append(f"  {key}: {', '.join(ids)}")

    wrong_kind = on_non_rule_page(reg, sources)
    if wrong_kind:
        lines.append("\nrules on a non-rule page:")
        for rule_id, key, kind in wrong_kind:
            lines.append(f"  {rule_id} {key} ({kind})")

    unk = unknown(reg, sources)
    if unk:
        lines.append("\nrules with an unknown page:")
        titles = [e.get("title", "") for e in reg.pages.values()]
        name_cache: dict = {}
        for s in sorted(unk, key=lambda s: s.rule_id):
            cands = resolve.candidates(_rule_name(s, name_cache), titles)[:5]
            suffix = f" -> {', '.join(cands)}" if cands else ""
            lines.append(f"  {s.rule_id} {s.url}{suffix}")

    return "\n".join(lines) + "\n"


def run(pages_path: Path = pages.PATH, rules_root: Path = layout.ROOT, *,
        list_status: "str | None" = None, check: bool = False) -> int:
    if not pages_path.exists():
        print("no pages.yaml yet: run make rules-sync")
        return 1 if check else 0

    reg = pages.read(pages_path)
    sources = rule_sources(rules_root)
    st = statuses(reg, sources)

    if list_status is not None:
        if list_status not in STATUSES:
            print(f"usage: --list must be one of {', '.join(STATUSES)}")
            return 2
        for key in sorted(k for k, s in st.items() if s == list_status):
            print(f"{key}\t{reg.pages[key].get('title', '')}")
        return 0

    print(render(reg, sources, st))
    if check and (any(s == "changed" for s in st.values()) or unknown(reg, sources)
                  or on_non_rule_page(reg, sources)):
        return 1
    return 0


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", dest="list_status")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--pages", type=Path, default=pages.PATH)
    ap.add_argument("--rules-root", type=Path, default=layout.ROOT)
    a = ap.parse_args(argv)
    sys.exit(run(a.pages, a.rules_root, list_status=a.list_status, check=a.check))
