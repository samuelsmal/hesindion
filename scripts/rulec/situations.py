"""Load, validate and compile the situations files (spec §4.6, §10.1–10.2). Collects every error.

A situations file is `{heroFile?, hero?, rulesets?, situations: [...]}`. Each situation states:

- `hero`: the rules it owns and its sheet values, layered hero file → file `hero` → situation
  `hero`. The rule-owning maps (`abilities`, `advantages`, `disadvantages`, `conditions`,
  `states`) are replaced whole by a later layer; `values` (query string → base value),
  `attributes`, `techniques` and `talents` are merged key by key. An owned entry is a level
  (int), `{sid: n}` (→ `option`, level 1) or `true` (level 1).
- facts, each in the section of its owner (`SECTIONS`); a prefixed section names the fact with
  its prefix (`round: { parries: 1 }` is `round.parries`). `rolls` is either dice (a list, passed
  through) or roll facts (a mapping). `rulesets` is the gm fact of that name.
- `expect`: `expectKeys` go to `expectSituation`; any other key must be a query string
  (`at(with: Rabenschnabel)`) and holds `expectQueryKeys`.

A situation is *pending* (§10.2) on every open ruling that lies on its path: cited by an expected
line or `notApplied` entry, resting on an effect of a clause an expected line comes `from`, or
resting on an effect the reach index lists for a queried target or `"*"` whose rule the
situation owns (or whose kind is `core`).

`sequence` is passed through unvalidated; the action layer (Tasks 25–28) defines its steps.
"""
import re
from pathlib import Path

from . import hero as hero_mod
from . import yamlload
from .errors import RulecError
from .forms import Forms
from .rules import SHARED, _plain

RULE_MAPS = ("abilities", "advantages", "disadvantages", "conditions", "states")
FACT_MAPS = {"attributes": "attr.", "techniques": "ktw.", "talents": "fw."}
HERO_KEYS = RULE_MAPS + ("values",) + tuple(FACT_MAPS)
# The rule map an Optolith activatable belongs to, by its id's prefix.
_OPTOLITH_MAPS = (("DISADV_", "disadvantages"), ("ADV_", "advantages"), ("SA_", "abilities"))
ATTRIBUTES = set(hero_mod.ATTR.values())
# section -> (owner, prefix)
SECTIONS = {
    "choose": ("player", ""),
    "gm": ("gm", ""),
    "opponent": ("gm", "opponent."),
    "ally": ("player", "ally."),
    "round": ("round", "round."),
    "loadout": ("loadout", "loadout."),
    "rolls": ("roll", ""),
}
STAR = "*"


def _is_int(x):
    return isinstance(x, int) and not isinstance(x, bool)


def _line(mapping, key=None, default=None):
    return (yamlload.line_of(mapping, key) if key is not None else None) or getattr(mapping, "line", None) or default


def query_string(target: dict) -> str:
    """The canonical query string of a normalized target: `at`, `at(with: Rabenschnabel)`."""
    ctx = [k for k in target if k != "name"]
    return target["name"] + (f"({ctx[0]}: {target[ctx[0]]})" if ctx else "")


def _numeric_id(sid: str):
    return tuple(int(n) for n in re.findall(r"\d+", sid)), sid


def _effect_rulings(effect, out):
    """Every ruling an effect rests on, its nested effects' included."""
    out.update(effect.get("ruling") or [])
    for val in (effect.get("payload") or {}).values():
        if isinstance(val, list):
            for x in val:
                if isinstance(x, dict) and "verb" in x:
                    _effect_rulings(x, out)
    return out


def check(situations_dir: Path, book: dict, reach: dict, v, shared_rulings=()):
    """Validate and compile every `*.yaml` under `situations_dir` against the checked `book`, its
    `reach` index and the vocabulary. `shared_rulings` is `rules.shared_rulings(rules_dir)`.
    Returns `(situations, errors)`; `situations` is sorted by file, then by the id's numbers."""
    situations_dir = Path(situations_dir)
    rulings = {r["id"]: r["status"] for r in shared_rulings}
    rulings.update({r["id"]: r["status"] for rule in book.values() for r in rule.get("rulings", [])})
    ctx = _Context(book, reach, v, rulings)
    out, errors, seen = [], [], set()
    for path in sorted(situations_dir.rglob("*.yaml")):
        _File(path, path.relative_to(situations_dir).as_posix(), ctx, errors, seen).compile(out)
    errors.sort(key=lambda e: (e.file or "", e.line or 0))
    out.sort(key=lambda s: (s["file"], _numeric_id(s["id"])))
    return out, errors


class _Context:
    def __init__(self, book, reach, v, rulings):
        self.book, self.reach, self.v, self.rulings = book, reach, v, rulings
        self.effects = {}                                   # (rule, clause, index) -> effect
        self.clauses = {}                                   # "RULE.CLAUSE" -> clause
        for rid, rule in book.items():
            for c in rule["clauses"]:
                if c.get("id") is not None:
                    self.clauses[f"{rid}.{c['id']}"] = c
                for e in c.get("effects", []):
                    o = e["origin"]
                    self.effects[(o["rule"], o["clause"], o["index"])] = e

    def open(self, ids):
        return {i for i in ids if self.rulings.get(i) == "open"}


class _File:
    def __init__(self, path, rel, ctx, errors, seen):
        self.path, self.file, self.rel = path, str(path), rel
        self.ctx, self.v, self.errors, self.seen = ctx, ctx.v, errors, seen
        self.forms = Forms(ctx.v, self.file)

    def err(self, msg, line):
        self.errors.append(RulecError(msg, self.file, line))

    def _g(self, fn):
        """Run a `Forms` conversion; report its error and return None instead of raising."""
        try:
            return fn()
        except RulecError as e:
            self.errors.append(e if e.file else RulecError(e.message, self.file, e.line))
            return None

    # --- the file -----------------------------------------------------------------------------
    def compile(self, out):
        try:
            doc = yamlload.load(self.path)
        except Exception as e:                              # YAML syntax
            self.err(f"yaml: {e}", None)
            return
        if not isinstance(doc, dict):
            self.err("a situations file is a mapping", 1)
            return
        for k in doc:
            if k not in self.v.raw["situationFileKeys"]:
                self.err(f"unknown key {k}", _line(doc, k))
        base = self.hero_file(doc)
        if "hero" in doc:
            base = _merge(base, self.hero(doc["hero"], _line(doc, "hero")))
        file_rulesets = doc.get("rulesets")
        items = doc.get("situations") or []
        if not isinstance(items, list):
            self.err("wrong type for field situations", _line(doc, "situations"))
            return
        for s in items:
            compiled = self.situation(s, base, file_rulesets, _line(doc, "situations"))
            if compiled is not None:
                out.append(compiled)

    def hero_file(self, doc):
        layer = _empty_layer()
        if "heroFile" not in doc:
            return layer
        name, line = doc["heroFile"], _line(doc, "heroFile")
        path = self.path.parent / str(name)
        if not path.is_file():
            self.err(f"heroFile not found: {name}", line)
            return layer
        try:
            h = hero_mod.from_optolith(path)
        except Exception as e:                              # not an Optolith file
            self.err(f"heroFile unreadable: {name}: {e}", line)
            return layer
        for rid, entry in h["owned"].items():
            section = next((m for p, m in _OPTOLITH_MAPS if rid.startswith(p)), "abilities")
            layer["owned"].setdefault(section, {})[rid] = entry
        for f in h["facts"]:
            for key, prefix in FACT_MAPS.items():
                if f["name"].startswith(prefix):
                    layer[key][f["name"][len(prefix):]] = f["value"]
        return layer

    def hero(self, raw, line):
        """One `hero` mapping as a layer: {owned: {map: {id: entry}}, values, attributes, …}."""
        layer = _empty_layer()
        if not isinstance(raw, dict):
            self.err("wrong type for field hero", line)
            return layer
        for k, val in raw.items():
            kline = _line(raw, k, line)
            if k not in HERO_KEYS:
                self.err(f"unknown hero key {k}", kline)
            elif not isinstance(val, dict):
                self.err(f"wrong type for hero.{k}", kline)
            elif k in RULE_MAPS:
                layer["owned"][k] = {}
                for rid, entry in val.items():
                    o = _owned_entry(entry)
                    if o is None:
                        self.err(f"wrong type for hero.{k}.{rid}", _line(val, rid, kline))
                    else:
                        layer["owned"][k][str(rid)] = o
            else:
                for name, n in val.items():
                    nline = _line(val, name, kline)
                    if not _is_int(n):
                        self.err(f"wrong type for hero.{k}.{name}", nline)
                    elif k == "values":
                        t = self._g(lambda: self.forms.target(name, nline))
                        if t is not None:
                            layer["values"][query_string(t)] = n
                    elif k == "attributes" and name not in ATTRIBUTES:
                        self.err(f"unknown attribute {name}", nline)
                    else:
                        layer[k][str(name)] = n
        return layer

    # --- one situation ------------------------------------------------------------------------
    def situation(self, s, base, file_rulesets, line):
        if not isinstance(s, dict):
            self.err("a situation is a mapping", line)
            return None
        for k in s:
            if k not in self.v.raw["situationKeys"]:
                self.err(f"unknown key {k}", _line(s, k))
        if "id" not in s:
            self.err("missing key id", _line(s))
            return None
        sid = str(s["id"])
        if sid in self.seen:
            self.err(f"duplicate situation id {sid}", _line(s, "id"))
        self.seen.add(sid)

        layer = _merge(base, self.hero(s["hero"], _line(s, "hero"))) if "hero" in s else base
        owned = {rid: e for m in layer["owned"].values() for rid, e in m.items()}
        facts = {}
        for key, prefix in FACT_MAPS.items():
            for name, n in layer[key].items():
                facts[prefix + name] = {"name": prefix + name, "value": n, "owner": "sheet"}
        rulesets = s.get("rulesets", file_rulesets)
        if rulesets is not None:
            facts["rulesets"] = {"name": "rulesets", "value": _plain(rulesets),
                                 "owner": self.v.fact_owner("rulesets")}
        rolls = []
        for section, (owner, prefix) in SECTIONS.items():
            if section not in s:
                continue
            raw, sline = s[section], _line(s, section)
            if section == "rolls" and isinstance(raw, list):
                rolls = _plain(raw)
                continue
            if not isinstance(raw, dict):
                self.err(f"wrong type for field {section}", sline)
                continue
            for k, val in raw.items():
                name, kline = prefix + str(k), _line(raw, k, sline)
                actual = self.v.fact_owner(name)
                if actual is None:
                    self.err(f"unknown fact {name}", kline)
                elif actual != owner:
                    self.err(f"fact {name} is owned by {actual}, not {section}", kline)
                else:
                    facts[name] = {"name": name, "value": _plain(val), "owner": owner}

        cited, from_clauses, queried = set(), set(), set()
        expect, expect_situation = self.expect(s, cited, from_clauses, queried)

        ctx = self.ctx
        pending = ctx.open(cited)
        for ref in from_clauses:
            for e in ctx.clauses[ref].get("effects", []):
                pending |= ctx.open(_effect_rulings(e, set()))
        for target in queried | {STAR}:
            for ref in ctx.reach.get(target, []):
                rule = ctx.book.get(ref["rule"])
                if rule is None or not (ref["rule"] in owned or rule.get("kind") == "core"):
                    continue
                e = ctx.effects.get((ref["rule"], ref["clause"], ref["index"]))
                if e is not None:
                    pending |= ctx.open(_effect_rulings(e, set()))

        return {
            "id": sid, "file": self.rel, "name": s.get("name"),
            "owned": owned,
            "facts": [facts[k] for k in sorted(facts)],
            "base": dict(layer["values"]),
            "rolls": rolls,
            "sequence": _plain(s.get("sequence") or []),
            "expect": expect,
            "expectSituation": expect_situation,
            "pending": sorted(pending),
        }

    # --- expect -------------------------------------------------------------------------------
    def expect(self, s, cited, from_clauses, queried):
        expect, situation = [], {}
        raw = s.get("expect")
        if raw is None:
            return expect, situation
        if not isinstance(raw, dict):
            self.err("wrong type for field expect", _line(s, "expect"))
            return expect, situation
        keys, query_keys = self.v.raw["expectKeys"], self.v.raw["expectQueryKeys"]
        for k, val in raw.items():
            kline = _line(raw, k, _line(s, "expect"))
            if k in keys:
                situation[k] = self.expect_value(k, val, kline, cited, from_clauses)
                continue
            try:
                t = Forms(self.v, self.file).target(k, kline)
            except RulecError:
                self.err(f"unknown expect key {k}", kline)
                continue
            if not isinstance(val, dict):
                self.err(f"wrong type for expect {k}", kline)
                continue
            q = {"query": query_string(t)}
            queried.add(t["name"])
            for qk, qv in val.items():
                qline = _line(val, qk, kline)
                if qk not in query_keys:
                    self.err(f"unknown key {qk}", qline)
                    continue
                q[qk] = self.expect_value(qk, qv, qline, cited, from_clauses)
            expect.append(q)
        return expect, situation

    def expect_value(self, key, val, line, cited, from_clauses):
        if key == "lines":
            return self.entries(val, line, lambda e, l: self.line(e, l, cited, from_clauses))
        if key == "notApplied":
            return self.entries(val, line, lambda e, l: self.not_applied(e, l, cited))
        if key in ("offered", "notOffered"):
            return self.entries(val, line, self.offer)
        return _plain(val)

    def entries(self, val, line, fn):
        if not isinstance(val, list):
            self.err("wrong type: a list of mappings", line)
            return _plain(val)
        out = []
        for e in val:
            if not isinstance(e, dict):
                self.err("wrong type: a list of mappings", line)
                continue
            out.append(fn(e, _line(e, None, line)))
        return out

    def line(self, e, line, cited, from_clauses):
        out = _plain(e)
        for k in e:
            if k not in self.v.raw["lineKeys"]:
                self.err(f"unknown key {k}", _line(e, k, line))
        rule = None
        if "from" in e:
            ref = str(e["from"])
            if ref in self.ctx.clauses:
                from_clauses.add(ref)
                rule = ref.rpartition(".")[0]
            else:
                self.err(f"unknown clause in expect {ref}", _line(e, "from", line))
        if "ruling" in e:
            out["ruling"] = self.rulings(e["ruling"], rule, _line(e, "ruling", line), cited)
        return out

    def not_applied(self, e, line, cited):
        out = _plain(e)
        rule = e.get("rule")
        if rule not in self.ctx.book:
            self.err(f"unknown rule in expect {rule}", _line(e, "rule", line))
            rule = None
        elif "clause" in e and f"{rule}.{e['clause']}" not in self.ctx.clauses:
            self.err(f"unknown clause in expect {rule}.{e['clause']}", _line(e, "clause", line))
        if "ruling" in e:
            out["ruling"] = self.rulings(e["ruling"], rule, _line(e, "ruling", line), cited)
        return out

    def offer(self, e, line):
        if "from" in e and str(e["from"]) not in self.ctx.clauses:
            self.err(f"unknown clause in expect {e['from']}", _line(e, "from", line))
        return _plain(e)

    def rulings(self, raw, rule, line, cited):
        """A cited ruling (or list) as qualified ids, resolved like an effect's `ruling`."""
        names = raw if isinstance(raw, list) else [raw]
        out = []
        for name in names:
            candidates = ([f"{rule}.{name}"] if rule else []) + [f"{SHARED}.{name}", str(name)]
            q = next((c for c in candidates if c in self.ctx.rulings), None)
            if q is None:
                self.err(f"unknown ruling in expect {name}", line)
                continue
            cited.add(q)
            out.append(q)
        return out


def _empty_layer():
    return {"owned": {}, "values": {}, **{k: {} for k in FACT_MAPS}}


def _merge(base, over):
    """`over` on top of `base`: rule maps replaced whole, the value maps merged key by key."""
    return {"owned": {**base["owned"], **over["owned"]},
            **{k: {**base[k], **over[k]} for k in ("values", *FACT_MAPS)}}


def _owned_entry(raw):
    if raw is True:
        return {"level": 1}
    if _is_int(raw):
        return {"level": raw}
    if isinstance(raw, dict) and "sid" in raw and set(raw) <= {"sid", "level"} \
            and (_is_int(raw.get("level", 1))):
        return {"level": raw.get("level", 1), "option": raw["sid"]}
    return None
