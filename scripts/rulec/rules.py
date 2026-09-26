"""Load, validate and normalize the rule files (spec §4, §11). Collects every error.

Nothing here knows a rule by name: every check is driven by `specs/rules/vocabulary.json`.
"""
from pathlib import Path

from . import yamlload
from .errors import RulecError
from .forms import _TABLE, Forms

EFFECT_META = {"when", "ruling", "because", "phase"}
SHARED = "shared"
CLAUSE_BODIES_MSG = "clause needs exactly one of effects, unencoded, none"

# field type -> name of the vocabulary list the value must be a member of
_MEMBER_LISTS = {"span": "spans", "pool": "pools", "audience": "audiences",
                 "owner": "owners", "rounding": "rounding", "reader": "readers"}


def _is_int(x):
    return isinstance(x, int) and not isinstance(x, bool)


def _is_number(x):
    return isinstance(x, (int, float)) and not isinstance(x, bool)


_PLAIN_TYPES = {
    "int": _is_int,
    "number": _is_number,
    "string": lambda x: isinstance(x, str),
    "name": lambda x: isinstance(x, str),
    "bool": lambda x: isinstance(x, bool),
    "list": lambda x: isinstance(x, list),
}


def _plain(x):
    """LineDicts back to plain dicts and lists, so the normalized book compares and dumps cleanly."""
    if isinstance(x, dict):
        return {k: _plain(v) for k, v in x.items()}
    if isinstance(x, list):
        return [_plain(v) for v in x]
    return x


def _key_line(mapping, key, default=None):
    return yamlload.line_of(mapping, key) or getattr(mapping, "line", None) or default


# --- rulings ----------------------------------------------------------------------------------
def _normalize_ruling(prefix, r):
    out = _plain(r)
    out["id"] = f"{prefix}.{r['id']}"
    out["status"] = "open" if r.get("answer") is None else "decided"
    return out


def _check_ruling_keys(r, path, v, errors):
    """Every key of a ruling must be one of the vocabulary's `rulingKeys` (spec §4.7)."""
    if v is None:
        return
    for k in r:
        if k not in v.raw["rulingKeys"]:
            errors.append(RulecError(f"unknown key {k}", str(path), _key_line(r, k)))


def _load_shared(rules_dir: Path, errors, v=None):
    path = rules_dir / "rulings.yaml"
    if not path.exists():
        return []
    try:
        shared = yamlload.load(path) or []
    except Exception as e:                           # YAML syntax
        errors.append(RulecError(f"yaml: {e}", str(path)))
        return []
    if not isinstance(shared, list):
        errors.append(RulecError("rulings.yaml is a list of rulings", str(path), 1))
        return []
    out = []
    for r in shared:
        if not isinstance(r, dict) or "id" not in r:
            errors.append(RulecError("a ruling needs an id", str(path), getattr(r, "line", None)))
            continue
        _check_ruling_keys(r, path, v, errors)
        out.append(_normalize_ruling(SHARED, r))
    return out


def shared_rulings(rules_dir: Path) -> list:
    """The normalized rulings of `rules/rulings.yaml` (qualified `shared.<id>`, with `status`)."""
    return _load_shared(Path(rules_dir), [])


def _rule_rulings(rid, path, doc, errors, v=None):
    raw = doc.get("rulings") or []
    if not isinstance(raw, list):
        errors.append(RulecError("wrong type for field rulings", str(path), _key_line(doc, "rulings")))
        return []
    out = []
    for r in raw:
        if not isinstance(r, dict) or "id" not in r:
            errors.append(RulecError("a ruling needs an id", str(path),
                                     getattr(r, "line", None) or _key_line(doc, "rulings")))
            continue
        _check_ruling_keys(r, path, v, errors)
        out.append(_normalize_ruling(rid, r))
    return out


# --- the whole tree ---------------------------------------------------------------------------
def check(rules_dir: Path, v):
    """Load every rule file under `rules_dir`. Returns `(book, errors)`: `book` maps rule id to its
    normalized rule; `errors` is every `RulecError` found, sorted by file and line."""
    rules_dir = Path(rules_dir)
    errors: list[RulecError] = []
    raw = {}
    for path in sorted(rules_dir.rglob("*.yaml")):
        if path.name == "rulings.yaml":
            continue
        try:
            doc = yamlload.load(path)
        except Exception as e:                       # YAML syntax
            errors.append(RulecError(f"yaml: {e}", str(path)))
            continue
        if not isinstance(doc, dict):
            errors.append(RulecError("a rule file is a mapping", str(path), 1))
            continue
        rid = doc.get("id", path.stem)
        if not isinstance(rid, str):
            errors.append(RulecError("wrong type for field id", str(path), _key_line(doc, "id", 1)))
            continue
        if rid in raw:
            errors.append(RulecError(f"duplicate rule id {rid}", str(path), _key_line(doc, "id", 1)))
            continue
        raw[rid] = (path, doc)

    shared = _load_shared(rules_dir, errors, v)
    per_rule = {rid: _rule_rulings(rid, path, doc, errors, v) for rid, (path, doc) in raw.items()}
    known_rulings = {r["id"] for r in shared} | {r["id"] for rs in per_rule.values() for r in rs}

    book, pending = {}, []
    for rid, (path, doc) in raw.items():
        book[rid] = _Rule(rid, path, doc, v, known_rulings, errors, pending).build(per_rule[rid])
    _cross_checks(book, pending, errors)
    errors.sort(key=lambda e: (e.file or "", e.line or 0))
    return book, errors


def _cross_checks(book, pending, errors):
    """The checks that need every rule loaded: `via` (line selectors), `useLevel.rule`, `rule`
    fields and `replace.line`."""
    def clause(ref):
        rule_id, _, clause_id = ref.rpartition(".")
        rule = book.get(rule_id)
        if rule is None:
            return None
        return next((c for c in rule["clauses"] if c.get("id") == clause_id), None)

    provided = {}                                    # provide name -> [its data values]
    for rule in book.values():
        for c in rule["clauses"]:
            for e in c.get("effects", []):
                if e["verb"] == "provide":
                    provided.setdefault(e["payload"]["name"], []).append(e["payload"]["value"])

    for kind, value, file, line in pending:
        if kind == "ruleTable":
            # A `rule` field's `table(name, key)`: the table must be provided, and every rule it
            # maps a key to must exist (trefferzonen.TZ8's Wundeffekt by zone, TZ11).
            if value not in provided:
                errors.append(RulecError(f"unknown table {value}", file, line))
            for data in provided.get(value, []):
                rows = data.values() if isinstance(data, dict) else [data]
                for rid in rows:
                    if not isinstance(rid, str) or rid not in book:
                        errors.append(RulecError(f"unknown rule in table {value}: {rid}", file, line))
        elif kind == "scale":
            if value not in provided:
                errors.append(RulecError(f"unknown scale {value}", file, line))
        elif kind == "rule":
            if value not in book:
                errors.append(RulecError(f"unknown rule {value}", file, line))
        elif kind == "useLevel":
            if value not in book:
                errors.append(RulecError(f"unknown rule {value}", file, line))
            elif book[value].get("levels") is None:
                errors.append(RulecError(f"useLevel names a rule without levels: {value}", file, line))
        elif kind == "via":
            if clause(value) is None:
                errors.append(RulecError(f"unknown clause in via {value}", file, line))
        elif kind == "replace":
            c = clause(value)                        # an unknown clause is reported as `via`
            if c is not None and "effects" not in c:
                errors.append(RulecError(f"replace names a clause without effects: {value}", file, line))


# --- one rule file ----------------------------------------------------------------------------
class _Rule:
    def __init__(self, rid, path, doc, v, known_rulings, errors, pending):
        self.rid, self.path, self.file, self.doc, self.v = rid, path, str(path), doc, v
        self.known_rulings, self.errors, self.pending = known_rulings, errors, pending
        self.forms = Forms(v, self.file)

    def err(self, msg, line):
        self.errors.append(RulecError(msg, self.file, line))

    def build(self, rulings):
        doc, v = self.doc, self.v
        spec = v.raw["ruleKeys"]
        allowed = set(spec["required"]) | set(spec["optional"])
        for k in doc:
            if k not in allowed:
                self.err(f"unknown key {k}", _key_line(doc, k))
        for k in spec["required"]:
            if k not in doc:
                self.err(f"missing key {k}", doc.line or 1)
        if "kind" in doc and doc["kind"] not in v.raw["kinds"]:
            self.err(f"unknown kind {doc['kind']}", _key_line(doc, "kind"))

        rule = {k: _plain(doc[k]) for k in doc if k in allowed and k not in ("clauses", "rulings")}
        rule["id"] = self.rid
        rule["rulings"] = rulings
        clauses = doc.get("clauses") or []
        if not isinstance(clauses, list):
            self.err("wrong type for field clauses", _key_line(doc, "clauses"))
            clauses = []
        rule["clauses"] = []
        seen = set()
        for c in clauses:
            nc = self.clause(c)
            if nc is None:
                continue
            cid = nc.get("id")
            if cid is not None and not isinstance(cid, str):
                self.err("wrong type for field id", _key_line(c, "id"))
                continue
            if cid is not None:                     # an id-less clause is already `missing key id`
                if cid in seen:
                    self.err(f"duplicate clause id {cid}", _key_line(c, "id"))
                seen.add(cid)
            rule["clauses"].append(nc)
        return rule

    def clause(self, c):
        if not isinstance(c, dict):
            self.err("a clause is a mapping", _key_line(self.doc, "clauses"))
            return None
        spec = self.v.raw["clauseKeys"]
        bodies = spec["oneOf"]
        allowed = set(spec["required"]) | set(spec["optional"]) | set(bodies)
        for k in c:
            if k not in allowed:
                self.err(f"unknown key {k}", _key_line(c, k))
        for k in spec["required"]:
            if k not in c:
                self.err(f"missing key {k}", c.line)
        present = [k for k in c if k in bodies]
        if len(present) != 1:
            line = _key_line(c, present[1]) if len(present) > 1 else c.line
            self.err(f"{CLAUSE_BODIES_MSG} (has {', '.join(present) or 'none of them'})", line)

        out = {k: _plain(c[k]) for k in c if k in allowed and k != "effects"}
        if "effects" in c:
            effects = c["effects"]
            if not isinstance(effects, list):
                self.err("wrong type for field effects", _key_line(c, "effects"))
                effects = []
            cid = c.get("id")
            normalized = (self.effect(e, cid, i, _key_line(c, "effects")) for i, e in enumerate(effects))
            out["effects"] = [ne for ne in normalized if ne is not None]
        return out

    # --- effects ------------------------------------------------------------------------------
    def effect(self, e, cid, index, line):
        """One normalized effect, or None when it has an error (already reported)."""
        if not isinstance(e, dict):
            self.err("an effect is a mapping", line)
            return None
        verbs = self.v.verbs
        found = [k for k in e if k in verbs]
        stray = [k for k in e if k not in verbs and k not in EFFECT_META]
        if not found:
            if stray:
                self.err(f"unknown verb {stray[0]}", _key_line(e, stray[0]))
                for k in stray[1:]:
                    self.err(f"unknown key {k}", _key_line(e, k))
            else:
                self.err("effect has no verb", e.line)
            return None
        ok = True
        for k in stray:
            self.err(f"unknown key {k}", _key_line(e, k))
            ok = False
        for k in found[1:]:
            self.err(f"effect has more than one verb: {k}", _key_line(e, k))
            ok = False
        verb = found[0]
        vline = _key_line(e, verb)

        payload = self.payload(verb, e[verb], vline, cid, index)
        ok = ok and payload is not None

        when = None
        if e.get("when") is not None:
            when = self._g(lambda: self.forms.condition(e["when"], _key_line(e, "when")))
            ok = ok and when is not _BAD

        phase = verbs[verb]["phase"]
        if "phase" in e:
            if e["phase"] not in self.v.raw["phases"]:
                self.err(f"unknown phase {e['phase']}", _key_line(e, "phase"))
                ok = False
            else:
                phase = e["phase"]

        because = e.get("because")
        if because is not None and not isinstance(because, str):
            self.err("wrong type for field because", _key_line(e, "because"))
            ok = False

        ruling = self.rulings(e)
        ok = ok and ruling is not None
        if not ok:
            return None
        return {"verb": verb, "payload": payload, "when": when, "ruling": ruling,
                "because": because, "phase": phase,
                "origin": {"rule": self.rid, "clause": cid, "index": index}}

    def rulings(self, e):
        if "ruling" not in e or e["ruling"] is None:
            return []
        names = e["ruling"] if isinstance(e["ruling"], list) else [e["ruling"]]
        line = _key_line(e, "ruling")
        out = []
        for name in names:
            if not isinstance(name, str):
                self.err("wrong type for field ruling", line)
                return None
            for q in (f"{self.rid}.{name}", f"{SHARED}.{name}", name):
                if q in self.known_rulings:
                    out.append(q)
                    break
            else:
                self.err(f"unknown ruling {name}", line)
                return None
        return out

    def payload(self, verb, raw, vline, cid, index):
        spec = self.v.verbs[verb]
        if not isinstance(raw, dict):
            self.err(f"wrong type for field {verb}: its payload is a mapping", vline)
            return None
        ok = True
        for k in raw:
            if k not in spec["fields"] and k not in spec["optional"]:
                self.err(f"unknown key {k}", _key_line(raw, k, vline))
                ok = False
        for k in spec["fields"]:
            if k not in raw:
                self.err(f"missing field {k}", vline)
                ok = False
        out = {}
        for k, ftype in {**spec["fields"], **spec["optional"]}.items():
            if k not in raw:
                continue
            val = self.field(ftype, k, raw[k], _key_line(raw, k, vline), cid, index)
            if val is _BAD:
                ok = False
                continue
            out[k] = val
            if ftype == "rule" and verb != "useLevel":        # useLevel's rule is checked below
                kind, ref = ("ruleTable", val["table"]["name"]) if isinstance(val, dict) else ("rule", val)
                self.pending.append((kind, ref, self.file, _key_line(raw, k, vline)))
        if verb == "add" and ok and "scale" in out:
            # A step along an ordered scale: the scale is a provided table, and every target
            # is one whose value lies on a scale (`scale: true`, the spell parameters).
            for t in out["to"]:
                if not self.v.raw["targets"].get(t["name"], {}).get("scale"):
                    self.err(f"{t['name']} is not on a scale", _key_line(raw, "to", vline))
                    ok = False
            self.pending.append(("scale", out["scale"], self.file, _key_line(raw, "scale", vline)))
        if verb == "offer" and ok and "labels" in out:
            options = [str(o) for o in out.get("options") or []]
            for k in out["labels"]:
                if k not in options:
                    self.err(f"label {k} is no option of {out['choice']}", _key_line(raw, "labels", vline))
                    ok = False
        if verb == "useLevel" and ok and ("as" in raw) == ("lowerBy" in raw):
            self.err("useLevel needs exactly one of as, lowerBy", vline)
            ok = False
        if verb == "useLevel" and ok:
            self.pending.append(("useLevel", raw["rule"], self.file, _key_line(raw, "rule", vline)))
        if verb == "replace" and ok:
            sel = out["line"]
            if sel["kind"] != "line":
                self.err("replace names a line: `line: { line: RULE.CLAUSE }`", _key_line(raw, "line", vline))
                return None
            for ref in sel["ids"]:
                self.pending.append(("replace", str(ref), self.file, _key_line(raw, "line", vline)))
        return out if ok else None

    def field(self, ftype, name, val, line, cid, index):
        wrong = lambda: self._bad(f"wrong type for field {name}", line)
        f = self.forms
        if ftype == "target":
            return self._g(lambda: f.target(val, line))
        if ftype == "targets":
            return self._g(lambda: f.targets(val, line))
        if ftype == "value":
            return self._g(lambda: f.value(val, line))
        if ftype == "values":
            if not isinstance(val, list):
                return wrong()
            return self._g(lambda: [f.value(x, line) for x in val])
        if ftype == "condition":
            return self._g(lambda: f.condition(val, line))
        if ftype == "selector":
            sel = self._g(lambda: f.selector(val, line))
            if sel is not _BAD and sel["kind"] == "line":
                for ref in sel["ids"]:
                    self.pending.append(("via", str(ref), self.file, line))
            return sel
        if ftype == "fact":
            if not isinstance(val, str):
                return wrong()
            if self.v.fact_owner(val) is None:
                return self._bad(f"unknown fact {val}", line)
            return val
        if ftype == "effects":
            if not isinstance(val, list):
                return wrong()
            out, ok = [], True
            for i, e in enumerate(val):
                ne = self.effect(e, cid, f"{index}.{name}.{i}", line)
                ok = ok and ne is not None
                out.append(ne)
            return out if ok else _BAD
        if ftype == "rule":
            if not isinstance(val, str):
                return wrong()
            if m := _TABLE.match(val):                 # the rule a provided table names for a key
                return {"table": {"name": m.group(1), "key": m.group(2)}}
            return val
        if ftype in _MEMBER_LISTS:
            if not isinstance(val, str):
                return wrong()
            if val not in self.v.raw[_MEMBER_LISTS[ftype]]:
                return self._bad(f"unknown {ftype} {val}", line)
            return val
        if ftype == "pools":
            if not isinstance(val, list) or not all(isinstance(p, str) for p in val):
                return wrong()
            for p in val:
                if p not in self.v.raw["pools"]:
                    return self._bad(f"unknown pool {p}", line)
            return list(val)
        if ftype in _PLAIN_TYPES:
            return _plain(val) if _PLAIN_TYPES[ftype](val) else wrong()
        if ftype == "data":
            return _plain(val)
        if ftype == "itemChange":
            if not isinstance(val, dict) or not val:
                return wrong()
            for k in val:
                if k not in self.v.raw["itemFields"]:
                    return self._bad(f"unknown item field {k}", _key_line(val, k, line))
            return _plain(val)
        if ftype == "split":
            if (not isinstance(val, dict) or set(val) - {"pools", "min"}
                    or not isinstance(val.get("pools"), list)
                    or not isinstance(val.get("min", {}), dict)
                    or not all(_is_int(n) for n in val.get("min", {}).values())):
                return wrong()
            for p in list(val["pools"]) + list(val.get("min", {})):
                if p not in self.v.raw["pools"]:
                    return self._bad(f"unknown pool {p}", line)
            return {"pools": list(val["pools"]), "min": dict(val.get("min", {}))}
        if ftype == "labels":
            # An offer's option → the picker's label, the `term` of the lines that read the
            # option (zaubermodifikationen.ZM1, Task 35). Checked against `options` below.
            if (not isinstance(val, dict) or not val
                    or not all(isinstance(t, str) and t for t in val.values())):
                return wrong()
            return {str(k): str(t) for k, t in val.items()}
        if ftype == "duration":
            # `{ minutes: 5 }`, `{ rounds: 1 }`, or the count read from a fact: the interval a
            # spell's own data states (`{ minutes: spell.interval }`, zaubermodifikationen.ZM5).
            if (not isinstance(val, dict) or len(val) != 1
                    or next(iter(val)) not in ("minutes", "rounds")):
                return wrong()
            n = next(iter(val.values()))
            if isinstance(n, str):
                if self.v.fact_owner(n) is None:
                    return self._bad(f"unknown fact {n}", line)
            elif not _is_int(n):
                return wrong()
            return _plain(val)
        return self._bad(f"unknown field type {ftype}", line)   # vocabulary out of step with rulec

    def _bad(self, msg, line):
        self.err(msg, line)
        return _BAD

    def _g(self, fn):
        """Run a `Forms` conversion; report its error and return _BAD instead of raising."""
        try:
            return fn()
        except RulecError as err:
            self.errors.append(err if err.file else RulecError(err.message, self.file, err.line))
            return _BAD


_BAD = object()
