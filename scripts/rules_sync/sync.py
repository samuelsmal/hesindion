"""make rules-sync: crawl the rule website into specs/rules/pages.yaml.

    make rules-sync                 # crawl, hash, write pages.yaml
    make rules-sync MAX_AGE=0       # ignore today's cached copies
    make rules-sync ADOPT=1         # also give every rule file with no hash its page's hash
    make rules-sync ADOPT=SA_40     # re-adopt a rule after it was reprocessed
"""
from __future__ import annotations

import argparse
import collections
import datetime
import sys
from pathlib import Path

import yaml

from rulec import layout
from rules_review import rulefiles
from rules_sync import check, pages, resolve


def _primary_source_url(path) -> "str | None":
    """The file's own `source.url`, canonicalised -- `None` when it has none.

    `check.rule_sources` yields `source.url` first and only falls back to `also[].url` entries
    when there is no `source.url` at all (`filter(None, urls)` drops the missing primary). That
    makes the *first* `RuleSource` for a rule id indistinguishable from an `also` entry by shape
    alone, so `adopt` re-reads the file's own `source.url` here and compares it against the
    candidate's URL rather than trust the URL is the primary one.
    """
    doc = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
    if not isinstance(doc, dict):
        return None
    url = (doc.get("source") or {}).get("url")
    return check.canonical_url(str(url)) if url else None


def adopt(reg, sources, ids, all_null, today) -> int:
    status = 0
    firsts = {}
    for s in sources:
        firsts.setdefault(s.rule_id, s)          # source.url comes before also[] in rule_sources
    for rule_id, s in sorted(firsts.items()):
        if not (all_null and s.hash is None) and rule_id not in ids:
            continue
        if _primary_source_url(s.path) != s.url:
            # No `source.url` on this rule -- the candidate above is an `also[].url` entry
            # standing in for it, and must never be written into `source.hash`.
            if rule_id in ids:
                print(f"cannot adopt {rule_id}: no source.url")
                status = 1
            continue
        page = reg.pages.get(pages.key_of(s.url))
        if not page or page.get("kind") != "rule" or page.get("gone"):
            if rule_id in ids:
                print(f"cannot adopt {rule_id}: {s.url} is not a current rule page")
                status = 1
            continue
        try:
            # An absolute, resolved path: `set_source_hash` does `ROOT / path`, and an absolute
            # right-hand side wins outright, so this is correct whether or not `rulefiles.ROOT`
            # happens to equal `rules_root` -- `s.path.relative_to(rulefiles.ROOT)` raised
            # `ValueError` whenever `--rules-root` pointed elsewhere.
            rulefiles.set_source_hash(s.path.resolve(), page["hash"], today)
        except rulefiles.EditRefused as exc:
            print(f"cannot adopt {rule_id}: {exc}")
            status = 1
            continue
        print(f"adopted {rule_id} ← {pages.key_of(s.url)}")
    for missing in sorted(set(ids) - set(firsts)):
        print(f"cannot adopt {missing}: no rule file with a source url")
        status = 1
    return status


def report(crawl, old, new) -> None:
    counts = collections.Counter((p.trail[0], p.kind) for p in crawl.pages.values())
    for top in sorted({t for t, _ in counts}):
        print(f"{top:<45} {counts[top, 'rule']:>5} rule  {counts[top, 'index']:>4} index  "
              f"{counts[top, 'broken']:>3} broken")
    for p in crawl.problems:
        print(p)
    if old.synced is None:
        print("\nfirst sync")
        return
    changed = [k for k, e in new.pages.items()
               if e.get("hash") and old.pages.get(k, {}).get("hash") not in (None, e["hash"])]
    print(f"\n{len(changed)} page(s) changed since {old.synced}")


def run(fetcher, pages_path=pages.PATH, rules_root=layout.ROOT, *, adopt_all=False,
        adopt_ids=(), today=None) -> int:
    today = today or datetime.date.today()
    crawl = resolve.crawl(fetcher)
    old = pages.read(pages_path)
    try:
        new = pages.merge(old, crawl, today)
    except ValueError as exc:
        print(exc)
        return 1
    pages.write(new, pages_path)
    report(crawl, old, new)
    status = 0
    if adopt_all or adopt_ids:
        status = adopt(new, check.rule_sources(rules_root), set(adopt_ids), adopt_all, today)
    print(f"{fetcher.network_calls} network call(s) made")
    return status


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--max-age-hours", type=float, default=20)
    ap.add_argument("--adopt", action="store_true")
    ap.add_argument("--adopt-ids", default="")
    ap.add_argument("--pages", type=Path, default=pages.PATH)
    ap.add_argument("--rules-root", type=Path, default=layout.ROOT)
    a = ap.parse_args(argv)
    fetcher = check.Fetcher(max_age=datetime.timedelta(hours=a.max_age_hours))
    ids = [i for i in a.adopt_ids.split(",") if i]
    sys.exit(run(fetcher, a.pages, a.rules_root, adopt_all=a.adopt, adopt_ids=ids))
