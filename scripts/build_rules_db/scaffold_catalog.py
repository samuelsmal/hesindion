#!/usr/bin/env python3
"""Write the catalog skeleton: every rule id in an existing rules.db as a `todo` entry.

Run once. Afterwards the build lists any id that is missing from the catalog, and a
missing id is added by hand as one line in the same shape. To re-scaffold after ids
change, write to a temp path and merge by hand, because overwriting loses every status.
"""

import argparse
import sqlite3
from pathlib import Path


def parse_args():
    p = argparse.ArgumentParser(description="Write the rules catalog skeleton")
    p.add_argument("--db", required=True, type=Path, help="An existing rules.db to take the ids from")
    p.add_argument("--output", required=True, type=Path, help="Path of the catalog YAML to write")
    return p.parse_args()


def quoted(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    args = parse_args()
    if args.output.exists():
        raise SystemExit(f"{args.output} exists; the build lists missing ids, add them by hand")
    conn = sqlite3.connect(str(args.db))
    rows = conn.execute("""
        SELECT r.id, i.name, COALESCE(g.name, c.name)
        FROM rules r
        JOIN rules_i18n i ON i.rule_id = r.id AND i.locale = 'de-DE'
        JOIN categories c ON c.id = r.category
        LEFT JOIN groups g ON g.id = r.group_id AND g.category = r.category
        ORDER BY r.category, CAST(substr(r.id, instr(r.id, '_') + 1) AS INTEGER)
    """).fetchall()
    lines = [
        "# The rules catalog — docs/plans/2026-09-14-rules-catalog-design.md §4.",
        "# One entry per rule id in rules.db. The build fails on a missing or unknown id,",
        "# an unknown status, a byHand pointer that does not resolve, a todo without why,",
        "# a noRollEffect without note, a name or group that does not match rules.db, a",
        "# duplicate id, or counts that differ from rules-catalog.snapshot.json.",
        "#",
        "# status: implemented | byHand | noRollEffect | todo",
        "",
    ]
    for rid, name, group in rows:
        lines.append(f"- {{ id: {rid}, name: {quoted(name)}, group: {quoted(group)}, status: todo, why: not yet read }}")
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {len(rows)} entries to {args.output}")


if __name__ == "__main__":
    main()
