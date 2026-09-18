"""The rules catalog: one entry per rule id in rules.db, with a status the build enforces.

Design: docs/plans/2026-09-14-rules-catalog-design.md §4. This file is steps 1 and 2
of §7: statuses, pointers, and — for `implemented` — clauses checked against
`specs/data/rule-vocabulary.json` and compiled to JSON.

load_catalog, validate, status_counts, check_snapshot and write_snapshot are pure
functions over dicts, testable without a database. import_catalog and
write_catalog_table read and write a live sqlite3.Connection.
"""

import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path

import yaml

STATUSES = ("implemented", "byHand", "noRollEffect", "todo")
REQUIRED = ("id", "name", "group", "status")
# The design's §4 entry fields.
KNOWN_KEYS = {
    "id", "name", "group", "status", "note", "why", "pointer", "reviewed",
    "sources", "text", "cost", "prerequisites", "unlocks", "applies_with", "clauses",
}
CLAUSE_KEYS = {"kind", "domains", "when", "effects", "tiers"}
# Entries for core rules that have no Optolith id (design §4). Exempt from the
# rules.db checks; everything else about them is checked like any other entry.
CORE_PREFIX = "GRW_"


class CatalogError(Exception):
    pass


SCALAR_TYPES = {"string", "strings", "int", "number", "bool"}
# The enums every check below reaches for by name.
REQUIRED_ENUMS = ("kind", "domain", "target", "span")


def load_vocabulary(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        vocab = json.load(f)
    for key in ("predicates", "effects", "enums", "combinators"):
        if key not in vocab:
            raise CatalogError(f"{path}: vocabulary has no {key!r}")
    for name in REQUIRED_ENUMS:
        if name not in vocab["enums"]:
            raise CatalogError(f"{path}: vocabulary has no enum {name!r}")
    for table in ("predicates", "effects"):
        for name, sig in vocab[table].items():
            tokens = list(sig.get("args", {}).values())
            if "value" in sig:
                tokens.append(sig["value"])
            for token in tokens:
                if not _known_type(token, vocab):
                    raise CatalogError(f"{path}: {table} {name}: unknown type {token!r}")
    return vocab


def _known_type(token, vocab: dict) -> bool:
    if token in SCALAR_TYPES:
        return True
    # The one exception: `choice` declares `value: list:effect`, which names the
    # effects table itself rather than an enum. _check_effect checks it by hand.
    if token == "list:effect":
        return True
    if isinstance(token, str) and (token.startswith("enum:") or token.startswith("list:")):
        return token.split(":", 1)[1] in vocab["enums"]
    return False


def load_catalog(path: Path) -> list[dict]:
    with open(path, "r", encoding="utf-8") as f:
        doc = yaml.safe_load(f)
    if not isinstance(doc, list):
        raise CatalogError(f"{path}: the catalog must be a list of entries")
    return doc


def validate(entries: list[dict], rules: dict[str, str], repo_root: Path,
             groups: dict[str, str] | None = None, vocabulary: dict | None = None) -> list[str]:
    """Every problem with the catalog, as one line each. Empty means valid.

    `rules` maps every rule id in rules.db to its German name. `groups`, when given,
    maps every rule id to its expected group label; omit it to skip that check.
    `vocabulary`, when given, is what `implemented` clauses are checked against;
    omit it to check statuses and pointers only.
    """
    problems: list[str] = []
    seen: set[str] = set()
    implemented_ids = {e["id"] for e in entries
                       if isinstance(e, dict) and e.get("status") == "implemented" and "id" in e}
    for i, e in enumerate(entries):
        if not isinstance(e, dict):
            problems.append(f"entry {i}: not a mapping")
            continue
        rid = e.get("id", "?")
        missing = [k for k in REQUIRED if k not in e]
        if missing:
            problems.append(f"{rid}: missing {', '.join(missing)}")
            continue
        for k in sorted(e):
            if k not in KNOWN_KEYS:
                problems.append(f"{rid}: unknown key {k!r}")
        if rid in seen:
            problems.append(f"{rid}: listed twice")
        seen.add(rid)
        core = isinstance(rid, str) and rid.startswith(CORE_PREFIX)
        if not core:
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
            if not e.get("note"):
                problems.append(f"{rid}: byHand without note")
        if status == "todo" and not e.get("why"):
            problems.append(f"{rid}: todo without why")
        if status == "noRollEffect" and not e.get("note"):
            problems.append(f"{rid}: noRollEffect without note")
        if status == "implemented":
            clauses = e.get("clauses")
            if not isinstance(clauses, list) or not clauses:
                problems.append(f"{rid}: implemented needs a non-empty clauses list")
            elif vocabulary is not None:
                problems.extend(_check_clauses(rid, e, vocabulary, implemented_ids))
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


def _check_clauses(rid: str, e: dict, vocab: dict, implemented_ids: set[str]) -> list[str]:
    problems: list[str] = []
    if "applies_with" in e:
        problems.extend(_check_predicate(rid, e["applies_with"], vocab, "applies_with"))
    for i, c in enumerate(e["clauses"]):
        where = f"clause {i}"
        if not isinstance(c, dict):
            problems.append(f"{rid}: {where} is not a mapping")
            continue
        for k in sorted(c):
            if k not in CLAUSE_KEYS:
                problems.append(f"{rid}: {where}: unknown clause key {k!r}")
        kinds = vocab["enums"]["kind"]
        if c.get("kind") not in kinds:
            problems.append(f"{rid}: {where}: kind {c.get('kind')!r} is not one of {', '.join(kinds)}")
        domains = c.get("domains")
        if not isinstance(domains, list) or not domains:
            problems.append(f"{rid}: {where}: needs a non-empty domains list")
        else:
            for d in domains:
                if d not in vocab["enums"]["domain"]:
                    problems.append(f"{rid}: {where}: unknown domain {d!r}")
        if "when" in c:
            problems.extend(_check_predicate(rid, c["when"], vocab, where))
        effects = c.get("effects")
        if not isinstance(effects, list) or not effects:
            problems.append(f"{rid}: {where}: needs a non-empty effects list")
        else:
            for j, eff in enumerate(effects):
                problems.extend(_check_effect(rid, eff, vocab, f"{where} effect {j}", implemented_ids))
        if "tiers" in c:
            if c.get("kind") != "offer":
                problems.append(f"{rid}: {where}: tiers is only for an offer")
            t = c["tiers"]
            if not (t == "owned" or (isinstance(t, int) and not isinstance(t, bool) and t > 0)):
                problems.append(f"{rid}: {where}: tiers is {t!r}, expected 'owned' or a positive integer")
    return problems


def _check_predicate(rid: str, p, vocab: dict, where: str) -> list[str]:
    if isinstance(p, list):
        return [x for q in p for x in _check_predicate(rid, q, vocab, where)]
    if isinstance(p, str):
        sig = vocab["predicates"].get(p)
        if sig is None:
            return [f"{rid}: {where}: unknown predicate {p!r}"]
        if sig.get("value") or sig.get("required"):
            return [f"{rid}: {where}: {p} needs an argument"]
        return []
    if isinstance(p, dict) and len(p) == 1:
        name, arg = next(iter(p.items()))
        if name in ("all", "any"):
            if not isinstance(arg, list) or not arg:
                return [f"{rid}: {where}: {name} needs a non-empty list"]
            return [x for q in arg for x in _check_predicate(rid, q, vocab, where)]
        if name == "not":
            return _check_predicate(rid, arg, vocab, where)
        sig = vocab["predicates"].get(name)
        if sig is None:
            return [f"{rid}: {where}: unknown predicate {name!r}"]
        problems = _check_args(rid, name, arg, sig, vocab, where)
        # One of the three rules the vocabulary's signatures cannot express
        # (with `target: talent` needing an id and `modifyRule` naming an
        # implemented entry, both in `_check_effect`): only the roster entry
        # stores GM facts, so the other two spans have nowhere to live yet.
        # `RulePredicate.init(from:)` refuses the same two.
        if name == "gm.fact" and isinstance(arg, dict) and arg.get("span") not in ("opponent", "attack"):
            problems.append(
                f"{rid}: {where}: gm.fact span {arg.get('span')!r} has no store yet; only opponent and attack")
        return problems
    return [f"{rid}: {where}: a predicate is a name, a {{name: argument}} mapping, or a list"]


def _check_effect(rid: str, eff, vocab: dict, where: str, implemented_ids: set[str]) -> list[str]:
    if not (isinstance(eff, dict) and len(eff) == 1):
        return [f"{rid}: {where}: an effect is a {{name: arguments}} mapping"]
    name, arg = next(iter(eff.items()))
    sig = vocab["effects"].get(name)
    if sig is None:
        return [f"{rid}: {where}: unknown effect {name!r}"]
    if name == "choice":
        # The signature's `value: list:effect` is descriptive only; this branch checks it.
        if not isinstance(arg, list) or len(arg) < 2:
            return [f"{rid}: {where}: choice needs at least two options"]
        return [x for k, o in enumerate(arg)
                for x in _check_effect(rid, o, vocab, f"{where} option {k}", implemented_ids)]
    if not isinstance(arg, dict):
        return [f"{rid}: {where}: {name} takes a mapping"]
    arg = _with_talent_target(arg)
    problems = _check_args(rid, name, arg, sig, vocab, where)
    # The other two of the three rules a signature cannot express (the third is
    # gm.fact's span, in `_check_predicate`): an argument that is only required
    # for one value of another, and a cross-entry reference.
    if arg.get("target") == "talent" and "talentId" not in arg:
        problems.append(f"{rid}: {where}: target talent needs an id")
    if name == "multiply":
        problems.extend(_check_factor(rid, where, "multiply.factor", arg.get("factor")))
    if name == "modifyRule":
        if arg.get("id") not in implemented_ids:
            problems.append(f"{rid}: {where}: modifyRule names {arg.get('id')!r}, which is not an implemented entry")
        if not any(k in arg for k in ("add", "set", "multiply")):
            problems.append(f"{rid}: {where}: modifyRule needs add, set or multiply")
        if "multiply" in arg:
            problems.extend(_check_factor(rid, where, "modifyRule.multiply", arg.get("multiply")))
    return problems


def _check_factor(rid: str, where: str, label: str, value) -> list[str]:
    # `RuleEvaluator` does `Int(Double(unit) * factor)`, which traps on overflow —
    # a factor has to stay in a range no plausible rule leaves (a multiplier
    # never doubles more than a handful of times over). The type itself is
    # `_check_type`'s job (`number`); this only bounds a value that is already
    # numeric, so a wrong type is not reported twice.
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return []
    if not (0 <= value <= 10):
        return [f"{rid}: {where}: {label} {value!r} must be between 0 and 10"]
    return []


def _with_talent_target(arg: dict) -> dict:
    """`target: { talent: TAL_8 }` becomes `target: talent, talentId: TAL_8`."""
    target = arg.get("target")
    if isinstance(target, dict) and list(target) == ["talent"]:
        arg = dict(arg)
        arg["target"] = "talent"
        arg["talentId"] = target["talent"]
    return arg


def _check_args(rid: str, name: str, arg, sig: dict, vocab: dict, where: str) -> list[str]:
    if "value" in sig:
        return _check_type(rid, name, arg, sig["value"], vocab, where)
    if not isinstance(arg, dict):
        return [f"{rid}: {where}: {name} takes a mapping"]
    problems: list[str] = []
    for k in sorted(arg):
        if k not in sig["args"]:
            problems.append(f"{rid}: {where}: {name} has no argument {k!r}")
    for k in sig.get("required", []):
        if k not in arg:
            problems.append(f"{rid}: {where}: {name} needs {k}")
    for k, v in arg.items():
        if k in sig["args"]:
            problems.extend(_check_type(rid, f"{name}.{k}", v, sig["args"][k], vocab, where))
    return problems


def _check_type(rid: str, name: str, v, t: str, vocab: dict, where: str) -> list[str]:
    is_int = isinstance(v, int) and not isinstance(v, bool)
    if t == "string":
        ok = isinstance(v, str) and bool(v)
    elif t == "strings":
        ok = (isinstance(v, str) and bool(v)) or (isinstance(v, list) and bool(v) and all(isinstance(x, str) for x in v))
    elif t == "int":
        ok = is_int
    elif t == "number":
        ok = is_int or isinstance(v, float)
    elif t == "bool":
        ok = isinstance(v, bool)
    elif t.startswith("enum:"):
        ok = v in vocab["enums"].get(t[5:], [])
    elif t.startswith("list:"):
        allowed = vocab["enums"].get(t[5:], [])
        ok = isinstance(v, list) and bool(v) and all(x in allowed for x in v)
    else:
        # load_vocabulary rejects every token this function does not know, so
        # reaching here means a vocabulary that never passed through it.
        ok = False
    return [] if ok else [f"{rid}: {where}: {name} is {v!r}, expected {t}"]


# --- Normalisation: the YAML forms become one JSON shape the Swift decoder reads.

def normalize_predicate(p) -> dict:
    if isinstance(p, list):
        return {"all": [normalize_predicate(q) for q in p]}
    if isinstance(p, str):
        return {"is": p}
    name, arg = next(iter(p.items()))
    if name in ("all", "any"):
        return {name: [normalize_predicate(q) for q in arg]}
    if name == "not":
        return {"not": normalize_predicate(arg)}
    if isinstance(arg, dict):
        return {"is": name, **arg}
    return {"is": name, "value": arg}


def normalize_effect(e) -> dict:
    name, arg = next(iter(e.items()))
    if name == "choice":
        return {"effect": "choice", "options": [normalize_effect(o) for o in arg]}
    return {"effect": name, **_with_talent_target(arg)}


def normalize_clause(c: dict) -> dict:
    out = {"kind": c["kind"], "domains": list(c["domains"]),
           "effects": [normalize_effect(e) for e in c["effects"]]}
    if "when" in c:
        out["when"] = normalize_predicate(c["when"])
    if "tiers" in c:
        out["tiers"] = c["tiers"]
    return out


def entry_json(e: dict) -> tuple[str | None, str | None]:
    """(applies_with, clauses) as JSON text, or (None, None) unless implemented."""
    if e.get("status") != "implemented":
        return None, None
    dumps = lambda o: json.dumps(o, ensure_ascii=False, sort_keys=True)
    applies = dumps(normalize_predicate(e["applies_with"])) if "applies_with" in e else None
    return applies, dumps([normalize_clause(c) for c in e["clauses"]])


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


def source_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_catalog_table(conn, entries: list[dict], source_sha256: str | None = None,
                        vocabulary_sha256: str | None = None) -> None:
    conn.execute("DROP TABLE IF EXISTS catalog")
    conn.execute("""
        CREATE TABLE catalog (
            rule_id        TEXT PRIMARY KEY,
            name           TEXT NOT NULL,
            status         TEXT NOT NULL,
            note           TEXT,
            pointer_file   TEXT,
            pointer_symbol TEXT,
            reviewed_by    TEXT,
            reviewed_on    TEXT,
            applies_with   TEXT,
            clauses        TEXT
        )
    """)
    conn.execute("DROP TABLE IF EXISTS catalog_meta")
    conn.execute("""
        CREATE TABLE catalog_meta (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
    """)
    if source_sha256 is not None:
        conn.execute("INSERT INTO catalog_meta VALUES (?, ?)", ("source_sha256", source_sha256))
    if vocabulary_sha256 is not None:
        conn.execute("INSERT INTO catalog_meta VALUES (?, ?)", ("vocabulary_sha256", vocabulary_sha256))
    for e in entries:
        pointer = e.get("pointer") or {}
        reviewed = e.get("reviewed") or {}
        applies, clauses = entry_json(e)
        conn.execute(
            "INSERT INTO catalog (rule_id, name, status, note, pointer_file, pointer_symbol, "
            "reviewed_by, reviewed_on, applies_with, clauses) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                e["id"],
                e["name"],
                e["status"],
                e.get("note") or e.get("why"),
                pointer.get("file"),
                pointer.get("symbol"),
                reviewed.get("by"),
                str(reviewed["date"]) if reviewed.get("date") is not None else None,
                applies,
                clauses,
            ),
        )
    conn.commit()


def import_catalog(conn: sqlite3.Connection, catalog_path: Path, snapshot_path: Path,
                    repo_root: Path, update_snapshot: bool, vocabulary_path: Path) -> None:
    entries = load_catalog(catalog_path)
    vocabulary = load_vocabulary(vocabulary_path)
    rules = dict(conn.execute(
        "SELECT rule_id, name FROM rules_i18n WHERE locale = 'de-DE'"
    ).fetchall())
    groups = dict(conn.execute("""
        SELECT r.id, COALESCE(g.name, c.name)
        FROM rules r
        JOIN categories c ON c.id = r.category
        LEFT JOIN groups g ON g.id = r.group_id AND g.category = r.category
    """).fetchall())
    problems = validate(entries, rules, repo_root, groups, vocabulary)
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
    write_catalog_table(conn, entries, source_hash(catalog_path), source_hash(vocabulary_path))
    print("  catalog: " + ", ".join(f"{s} {counts[s]}" for s in STATUSES))
