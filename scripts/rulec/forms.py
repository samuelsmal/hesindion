"""The YAML shorthands of the rule format, normalized to the JSON the engine decodes (spec §4.4–4.6)."""
import re

from .errors import RulecError

_LEVEL = re.compile(r"^\s*(?:(-?\d+)\s*\*\s*)?(-)?level\s*(?:([+-])\s*(\d+))?\s*$")
_TABLE = re.compile(r"^\s*table\(\s*([\w.]+)\s*,\s*([\w.]+)\s*\)\s*$")
_TARGET = re.compile(r"^([a-zA-Z][\w.]*)(?:\((\w+):\s*([\w\-äöüÄÖÜß ]+)\))?$")
PROPORTION_KEYS = {"of", "per", "times", "above", "round", "min", "max"}


class Forms:
    def __init__(self, vocab, file=None):
        self.v, self.file = vocab, file

    def err(self, msg, line=None):
        raise RulecError(msg, self.file, line)

    # --- values -----------------------------------------------------------------------------
    def value(self, raw, line=None):
        if isinstance(raw, bool):
            self.err("value outside the four forms", line)
        if isinstance(raw, (int, float)):
            return {"number": raw}
        if isinstance(raw, str):
            if m := _LEVEL.match(raw):
                times = int(m.group(1)) if m.group(1) else 1
                if m.group(2):
                    times = -times
                plus = int(m.group(4)) * (1 if m.group(3) == "+" else -1) if m.group(4) else 0
                return {"level": {"times": times, "plus": plus}}
            if m := _TABLE.match(raw):
                return {"table": {"name": m.group(1), "key": m.group(2)}}
            self.err("value outside the four forms", line)
        if isinstance(raw, dict) and "of" in raw and set(raw) <= PROPORTION_KEYS:
            p = {"of": self.operand(raw["of"], line), "per": self.operand(raw.get("per", 1), line),
                 "times": raw.get("times", 1), "above": raw.get("above", 0),
                 "round": raw.get("round", "up"),
                 "min": self.bound(raw.get("min"), line), "max": self.bound(raw.get("max"), line)}
            if p["round"] not in self.v.raw["rounding"]:
                self.err(f"unknown rounding {p['round']}", line)
            return {"proportion": p}
        self.err("value outside the four forms", line)

    def bound(self, raw, line):
        """A proportion's `min` or `max`: absent (None), a number (kept as is), a fact or target
        (an operand), or a list of those, every one of which holds (`{"each": [...]}`):
        `max: [10, gsNatural]` is at most 10 and at most the natural GS (SA_62.ST2)."""
        if raw is None or (isinstance(raw, (int, float)) and not isinstance(raw, bool)):
            return raw
        if isinstance(raw, list):
            if len(raw) < 2:
                self.err("a list of bounds lists two or more", line)
            return {"each": [self.operand(x, line) for x in raw]}
        if isinstance(raw, str):
            return self.operand(raw, line)
        self.err(f"unknown bound {raw!r}", line)

    def operand(self, raw, line):
        """A number, a fact or a target; a list of those is their sum (`{"sum": [...]}`), taken
        before the proportion's `per` — `(MU + GE) / 2` is `{ of: [attr.MU, attr.GE], per: 2 }`."""
        if isinstance(raw, list):
            if len(raw) < 2:
                self.err("a summed operand lists two or more", line)
            return {"sum": [self.operand(x, line) for x in raw]}
        if isinstance(raw, (int, float)) and not isinstance(raw, bool):
            return {"number": raw}
        if isinstance(raw, str) and (self.v.fact_owner(raw) or self.v.is_target(raw.split("(")[0])):
            return {"fact": raw} if self.v.fact_owner(raw) else {"target": self.target(raw, line)}
        self.err(f"unknown operand {raw!r}", line)

    # --- targets ----------------------------------------------------------------------------
    def target(self, raw, line=None):
        m = _TARGET.match(str(raw).strip())
        if not m or not self.v.is_target(m.group(1)):
            self.err(f"unknown target {raw}", line)
        out = {"name": m.group(1)}
        if m.group(2):
            if m.group(2) not in self.v.target_contexts(m.group(1)):
                self.err(f"{m.group(1)} takes no context {m.group(2)}", line)
            out[m.group(2)] = m.group(3).strip()
        return out

    def targets(self, raw, line=None):
        return [self.target(t, line) for t in (raw if isinstance(raw, list) else [raw])]

    # --- conditions -------------------------------------------------------------------------
    def condition(self, raw, line=None):
        if not isinstance(raw, dict) or not raw:
            self.err("a condition is a mapping", line)
        parts = []
        for k, val in raw.items():
            kline = getattr(raw, "key_lines", {}).get(k, line)
            if k in ("all", "any"):
                parts.append({k: [self.condition(c, kline) for c in val]})
            elif k == "not":
                parts.append({"not": self.condition(val, kline)})
            else:
                if self.v.fact_owner(k) is None:
                    self.err(f"unknown fact {k}", kline)
                parts.append(self._compare(k, val, kline))
        return parts[0] if len(parts) == 1 else {"all": parts}

    def _compare(self, fact, val, line):
        if isinstance(val, list):
            return {"fact": fact, "in": val}
        if isinstance(val, dict):
            (op, arg), = val.items() if len(val) == 1 else self.err("one comparison per fact", line)
            if op not in self.v.raw["comparisons"]:
                self.err(f"unknown comparison {op}", line)
            return {"fact": fact, op: arg}
        return {"fact": fact, "is": val}

    # --- selectors --------------------------------------------------------------------------
    def selector(self, raw, line=None):
        if not isinstance(raw, dict):
            self.err("a selector is a mapping", line)
        kinds = [k for k in raw if k in self.v.raw["selectorKinds"]]
        if len(kinds) != 1:
            self.err("a selector names exactly one kind", line)
        ids = raw[kinds[0]]
        out = {"kind": kinds[0], "ids": ids if isinstance(ids, list) else [ids]}
        if "with" in raw:
            out["with"] = raw["with"]
        extra = set(raw) - {kinds[0], "with"}
        if extra:
            self.err(f"unknown selector keys {sorted(extra)}", line)
        return out
