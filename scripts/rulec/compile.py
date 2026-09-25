"""Compile a checked rule book to `rules.json` (spec §5.4, §11).

`build_rules(book, v, shared)` returns the JSON object; `write(obj, path)` writes it byte-for-byte
deterministically. Nothing here knows a rule by name: indexing is driven by the verb alone.

The reach index maps a target name to the top-level effects that can change it, each as
`{rule, clause, index}`, every list sorted:

- `add`/`set`/`multiply`/`cap`/`floor` go under each of their `to` names, `derive` under its `to`
  (the full name, prefix included: `opponent.at`; a context like `at(with: X)` indexes as `at`).
- `forbid`/`limit` (`what`) and `require` (`for`) whose selector is `defence` go under `pa` and/or
  `aw`: an id `aw` or naming a dodge (`ausweichen`/`dodge`) under `aw`, an id `pa` or a parry
  (`…parry`/`…parade`) under `pa`, any other defence id under both. An `attack` selector goes under
  both `at` and `fk`. An id with the `opponent.` prefix goes under the opponent's target:
  `defence: [opponent.weaponParry]` under `opponent.pa`, `attack: [opponent.x]` under
  `opponent.at` and `opponent.fk`.
- `useLevel` goes under every key the named rule reaches; `replace`/`suppress` under every key
  the clause (or rule) their `line` selector names reaches. These are resolved after the direct
  verbs by a bounded fixed-point loop, not recursion: their keys are merged back into their own
  rule and clause, and the round repeats until no set grows, so chains are followed (X uses R's
  level, R uses S's level: X reaches R's and S's targets). When that is nothing, the effect goes
  under `"*"`.
- Every other effect — `offer`, `ask`, `tell`, `provide`, a `require` with no `for` (or another
  selector kind), and all action-layer verbs — goes under `"*"`, which every query evaluates.

Nested effects (`check.onSuccess/onFailure`, `offer.costs`, `process.completes`) are **not**
indexed: they are reached through their parent, which is always under `"*"`, and run only when
the parent runs them. Indexing them on their own would let a query apply them without the parent.

A clause with `effects` whose top-level effects are all `provide`s nobody reads can never fire:
the build fails with `clause can never fire: RULE.CLAUSE`. A provide is read when
- a `table(name, …)` reference or an `add`'s `scale` names it (exact name match), or
- a fact or target read anywhere (a `when` comparison, a value operand; not an `ask`) is its name
  or lies below it: an equipment row `loadout.weapon` is read by `loadout.weapon.technique`, a
  mount profile's `mount.gs` by reiterkampf's proportion, or
- it declares `readBy` (`display`, `loadout`, `roll`): reference data the app shows, resolves the
  loadout from, or rolls on, which no rule computes with (the hit-zone tables, a disadvantage's
  option names).
"""
import datetime as _dt
import json
import re
from pathlib import Path

from .errors import RulecError

STAR = "*"
_TO_VERBS = {"add", "set", "multiply", "cap", "floor", "derive"}
_LEGALITY_SELECTOR = {"forbid": "what", "limit": "what", "require": "for"}
_TABLE_IN_TEXT = re.compile(r"table\(\s*([\w.-]+)\s*,")


def _names(to):
    """The target names of a normalized `target` or `targets` field."""
    return [t["name"] for t in (to if isinstance(to, list) else [to])]


_OPPONENT = "opponent."


def _side(i):
    """An id's side prefix (`opponent.` or none) and the id without it."""
    s = str(i)
    return (_OPPONENT, s[len(_OPPONENT):]) if s.startswith(_OPPONENT) else ("", s)


def _defence_targets(ids):
    keys = set()
    for i in ids:
        side, s = _side(i)
        s = s.lower()
        if s == "aw" or "ausweich" in s or "dodge" in s:
            keys.add(side + "aw")
        elif s == "pa" or s.endswith("parry") or s.endswith("parade"):
            keys.add(side + "pa")
        else:
            keys |= {side + "pa", side + "aw"}
    return keys


def _attack_targets(ids):
    sides = {_side(i)[0] for i in ids} or {""}
    return {side + t for side in sides for t in ("at", "fk")}


def _direct_keys(effect):
    """The reach keys of an effect that does not depend on other rules; None for useLevel,
    replace and suppress, which are resolved in later passes."""
    verb, p = effect["verb"], effect["payload"]
    if verb in _TO_VERBS:
        return set(_names(p["to"]))
    if verb in ("useLevel", "replace", "suppress"):
        return None
    if verb in _LEGALITY_SELECTOR:
        sel = p.get(_LEGALITY_SELECTOR[verb])
        if sel is not None and sel["kind"] == "defence":
            return _defence_targets(sel["ids"])
        if sel is not None and sel["kind"] == "attack":
            return _attack_targets(sel["ids"])
    return {STAR}


def _table_reads(x, out):
    """Every table name read anywhere in `x`: normalized `{"table": {"name": …}}` values and any
    `table(name, …)` text (fields not normalized as values, e.g. `rule` fields or data)."""
    if isinstance(x, dict):
        t = x.get("table")
        if isinstance(t, dict) and isinstance(t.get("name"), str):
            out.add(t["name"])
        for v in x.values():
            _table_reads(v, out)
    elif isinstance(x, list):
        for v in x:
            _table_reads(v, out)
    elif isinstance(x, str):
        out.update(_TABLE_IN_TEXT.findall(x))
    return out


def _scale_reads(x, out):
    """Every scale name an `add` steps along (`add: { …, scale: NAME }`), nested effects included."""
    if isinstance(x, dict):
        if x.get("verb") == "add" and isinstance(x.get("payload", {}).get("scale"), str):
            out.add(x["payload"]["scale"])
        for v in x.values():
            _scale_reads(v, out)
    elif isinstance(x, list):
        for v in x:
            _scale_reads(v, out)
    return out


def _operand_reads(x, out):
    """Every fact and target name read in `x`, a normalized condition or value: `{"fact": …}` in a
    comparison or operand, `{"target": {"name": …}}` as an operand."""
    if isinstance(x, dict):
        if isinstance(x.get("fact"), str):
            out.add(x["fact"])
        t = x.get("target")
        if isinstance(t, dict) and isinstance(t.get("name"), str):
            out.add(t["name"])
        for v in x.values():
            _operand_reads(v, out)
    elif isinstance(x, list):
        for v in x:
            _operand_reads(v, out)
    return out


def _fact_reads(effects, out):
    """Every fact or target name the `effects` read: in `when` and in the payload, nested effects
    (`onFailure`, `costs`, `completes`) included. An `ask` names the fact it asks for, which is
    not a read, and a `provide`'s payload is data."""
    for e in effects:
        if not isinstance(e, dict):
            continue
        _operand_reads(e.get("when"), out)
        if e["verb"] in ("ask", "provide"):
            continue
        for v in e["payload"].values():
            if isinstance(v, list) and any(isinstance(x, dict) and "verb" in x for x in v):
                _fact_reads(v, out)
            else:
                _operand_reads(v, out)
    return out


def _is_read(name, tables, facts):
    """A provide is read when a `table(...)` or a scale names it exactly, or when a fact or target
    read anywhere is its name or lies below it (`loadout.weapon` is read by
    `loadout.weapon.technique`: the row provides the facts the loadout states)."""
    return name in tables or any(f == name or f.startswith(name + ".") for f in facts)


def _check_reachable(rules_sorted):
    clauses = [r["clauses"] for r in rules_sorted]
    tables = _table_reads(clauses, set()) | _scale_reads(clauses, set())
    facts = _fact_reads([e for cs in clauses for c in cs for e in c.get("effects", [])], set())
    for r in rules_sorted:
        for c in r["clauses"]:
            if "effects" not in c:
                continue
            if all(e["verb"] == "provide" and "readBy" not in e["payload"]
                   and not _is_read(e["payload"]["name"], tables, facts) for e in c["effects"]):
                raise RulecError(f"clause can never fire: {r['id']}.{c['id']}")


def _reach(rules_sorted):
    keys = {}                                           # (rule, clause, index) -> set of keys
    by_rule, by_clause = {}, {}
    late = []
    for r in rules_sorted:
        for c in r["clauses"]:
            for e in c.get("effects", []):
                o = e["origin"]
                ref = (o["rule"], o["clause"], o["index"])
                k = _direct_keys(e)
                if k is None:
                    late.append((ref, e))
                    continue
                keys[ref] = k
                by_rule.setdefault(o["rule"], set()).update(k)
                by_clause.setdefault(f"{o['rule']}.{o['clause']}", set()).update(k)

    # useLevel, replace and suppress: a fixed-point loop, not recursion. Each round recomputes
    # their keys from the current rule and clause reach and merges them back, so chains
    # (useLevel of a rule that itself uses another's level, suppress of such a rule) are followed.
    # Sets only grow and are bounded by the finite key set, so the loop terminates.
    for ref, _ in late:
        keys[ref] = set()
    changed = True
    while changed:
        changed = False
        for ref, e in late:
            if e["verb"] == "useLevel":
                k = set(by_rule.get(e["payload"]["rule"], ()))
            else:                                       # replace / suppress
                sel, k = e["payload"]["line"], set()
                for i in sel["ids"]:
                    if sel["kind"] == "line":
                        k |= by_clause.get(str(i), set())
                    elif sel["kind"] == "rule":
                        k |= by_rule.get(str(i), set())
            if not k <= keys[ref]:
                keys[ref] |= k
                by_rule.setdefault(ref[0], set()).update(k)
                by_clause.setdefault(f"{ref[0]}.{ref[1]}", set()).update(k)
                changed = True
    for ref, _ in late:                                 # reaches nothing: evaluated by every query
        keys[ref] = keys[ref] or {STAR}

    reach = {}
    for ref, ks in keys.items():
        for k in ks:
            reach.setdefault(k, set()).add(ref)
    return {k: [{"rule": r, "clause": c, "index": i} for r, c, i in sorted(refs, key=_ref_key)]
            for k, refs in reach.items()}


def _ref_key(ref):
    r, c, i = ref
    return (r, c, (0, i, "") if isinstance(i, int) else (1, 0, str(i)))


def _jsonable(x):
    if isinstance(x, dict):
        return {k: _jsonable(v) for k, v in x.items()}
    if isinstance(x, (list, tuple)):
        return [_jsonable(v) for v in x]
    if isinstance(x, (_dt.date, _dt.datetime)):
        return x.isoformat()
    return x


def build_rules(book: dict, v, shared_rulings=()) -> dict:
    """The `rules.json` object for a checked `book` ({ruleId: normalized rule}). `shared_rulings`
    is `rules.shared_rulings(rules_dir)`. Raises `RulecError` on a clause that can never fire."""
    rules_sorted = [book[k] for k in sorted(book)]
    _check_reachable(rules_sorted)
    rulings = list(shared_rulings) + [x for r in rules_sorted for x in r.get("rulings", [])]
    return _jsonable({
        "vocabularyVersion": v.version,
        "vocabularySha256": v.sha256,
        "rules": rules_sorted,
        "rulings": sorted(rulings, key=lambda x: x["id"]),
        "reach": _reach(rules_sorted),
    })


def dumps(obj) -> str:
    return json.dumps(obj, sort_keys=True, ensure_ascii=False, indent=1) + "\n"


def write(obj, path: Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(dumps(obj).encode("utf-8"))
