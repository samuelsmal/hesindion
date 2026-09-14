"""The rules catalog: one entry per rule id in rules.db, with a status the build enforces.

Design: docs/plans/2026-09-14-rules-catalog-design.md §4. This file is step 1 of §7:
statuses and pointers only, no clauses yet.
"""

import json
import re
import sqlite3
import sys
from pathlib import Path

import yaml

STATUSES = ("implemented", "byHand", "noRollEffect", "todo")
REQUIRED = ("id", "name", "group", "status")


class CatalogError(Exception):
    pass


def load_catalog(path: Path) -> list[dict]:
    with open(path, "r", encoding="utf-8") as f:
        doc = yaml.safe_load(f)
    if not isinstance(doc, list):
        raise CatalogError(f"{path}: the catalog must be a list of entries")
    return doc


def validate(entries: list[dict], rules: dict[str, str], repo_root: Path,
             groups: dict[str, str] | None = None) -> list[str]:
    """Every problem with the catalog, as one line each. Empty means valid.

    `rules` maps every rule id in rules.db to its German name. `groups`, when given,
    maps every rule id to its expected group label; omit it to skip that check.
    """
    problems: list[str] = []
    seen: set[str] = set()
    for i, e in enumerate(entries):
        if not isinstance(e, dict):
            problems.append(f"entry {i}: not a mapping")
            continue
        rid = e.get("id", "?")
        missing = [k for k in REQUIRED if k not in e]
        if missing:
            problems.append(f"{rid}: missing {', '.join(missing)}")
            continue
        if rid in seen:
            problems.append(f"{rid}: listed twice")
        seen.add(rid)
        if rid not in rules:
            problems.append(f"{rid}: not in rules.db")
            continue
        if e["name"] != rules[rid]:
            problems.append(f"{rid}: name is {e['name']!r}, rules.db says {rules[rid]!r}")
        if groups is not None and rid in groups and e["group"] != groups[rid]:
            problems.append(f"{rid}: group is {e['group']!r}, rules.db says {groups[rid]!r}")
        status = e["status"]
        if status not in STATUSES:
            problems.append(f"{rid}: status {status!r} is not one of {', '.join(STATUSES)}")
            continue
        if status == "byHand":
            problems.extend(_check_pointer(rid, e.get("pointer"), repo_root))
        if status == "todo" and not e.get("why"):
            problems.append(f"{rid}: todo without why")
        if status == "noRollEffect" and not e.get("note"):
            problems.append(f"{rid}: noRollEffect without note")
    for rid in rules:
        if rid not in seen:
            problems.append(f"{rid}: no catalog entry")
    return problems


def _check_pointer(rid: str, pointer, repo_root: Path) -> list[str]:
    if not isinstance(pointer, dict) or "file" not in pointer or "symbol" not in pointer:
        return [f"{rid}: byHand needs pointer {{file, symbol}}"]
    file = pointer["file"]
    if Path(file).is_absolute() or ".." in Path(file).parts:
        return [f"{rid}: pointer file {file} must be a relative path inside the repository"]
    symbol = pointer["symbol"]
    if not isinstance(symbol, str) or not symbol:
        return [f"{rid}: pointer symbol must be a non-empty string"]
    path = repo_root / file
    if not path.is_file():
        return [f"{rid}: pointer file {file} does not exist"]
    text = path.read_text(encoding="utf-8")
    # Kept identical to the Swift test RulesCatalogTests.testEveryPointerNamesASymbolThatExists.
    pattern = r"(?<![A-Za-z0-9_])" + re.escape(symbol) + r"(?![A-Za-z0-9_])"
    if not re.search(pattern, text):
        return [f"{rid}: symbol {symbol!r} not found in {file}"]
    return []


def status_counts(entries: list[dict]) -> dict[str, int]:
    counts = {s: 0 for s in STATUSES}
    for e in entries:
        counts[e["status"]] += 1
    return counts


def check_snapshot(counts: dict[str, int], snapshot_path: Path) -> list[str]:
    """Empty when the counts equal the committed snapshot; otherwise why not."""
    if not snapshot_path.is_file():
        return [f"snapshot {snapshot_path} is missing; build with --update-snapshot to create it"]
    snap = json.loads(snapshot_path.read_text(encoding="utf-8"))
    if snap == counts:
        return []
    problems = [f"catalog counts {counts} differ from snapshot {snap}"]
    if counts["implemented"] + counts["byHand"] < snap["implemented"] + snap["byHand"]:
        problems.append("coverage went backwards: fewer implemented + byHand rules than the snapshot")
    if counts["todo"] > snap["todo"]:
        problems.append("todo grew: a rule lost its status, or a new rule id has no real entry yet")
    problems.append("if this is intended, build with --update-snapshot and commit the snapshot with the catalog")
    return problems


def write_snapshot(counts: dict[str, int], path: Path) -> None:
    path.write_text(json.dumps(counts, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_catalog_table(conn, entries: list[dict]) -> None:
    conn.execute("DROP TABLE IF EXISTS catalog")
    conn.execute("""
        CREATE TABLE catalog (
            rule_id        TEXT PRIMARY KEY,
            status         TEXT NOT NULL,
            note           TEXT,
            pointer_file   TEXT,
            pointer_symbol TEXT,
            reviewed_by    TEXT,
            reviewed_on    TEXT
        )
    """)
    for e in entries:
        pointer = e.get("pointer") or {}
        reviewed = e.get("reviewed") or {}
        conn.execute(
            "INSERT INTO catalog VALUES (?, ?, ?, ?, ?, ?, ?)",
            (
                e["id"],
                e["status"],
                e.get("note") or e.get("why"),
                pointer.get("file"),
                pointer.get("symbol"),
                reviewed.get("by"),
                str(reviewed["date"]) if reviewed.get("date") is not None else None,
            ),
        )
    conn.commit()


def import_catalog(conn: sqlite3.Connection, catalog_path: Path, snapshot_path: Path,
                    repo_root: Path, update_snapshot: bool) -> None:
    entries = load_catalog(catalog_path)
    rules = dict(conn.execute(
        "SELECT rule_id, name FROM rules_i18n WHERE locale = 'de-DE'"
    ).fetchall())
    groups = dict(conn.execute("""
        SELECT r.id, COALESCE(g.name, c.name)
        FROM rules r
        JOIN categories c ON c.id = r.category
        LEFT JOIN groups g ON g.id = r.group_id AND g.category = r.category
    """).fetchall())
    problems = validate(entries, rules, repo_root, groups)
    if problems:
        for p in problems:
            print(f"  catalog: {p}", file=sys.stderr)
        raise SystemExit(f"{len(problems)} catalog problem(s); see above")
    counts = status_counts(entries)
    if update_snapshot:
        write_snapshot(counts, snapshot_path)
        print(f"  Wrote snapshot {snapshot_path}")
    else:
        drift = check_snapshot(counts, snapshot_path)
        if drift:
            for d in drift:
                print(f"  catalog: {d}", file=sys.stderr)
            raise SystemExit("catalog counts do not match the snapshot")
    write_catalog_table(conn, entries)
    print("  catalog: " + ", ".join(f"{s} {counts[s]}" for s in STATUSES))
