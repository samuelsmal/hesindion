"""The draft rule files as a model, and the few edits the review tool makes to them.

The edits are surgical: they rewrite the lines of one key and leave every other line — comments,
flow mappings, folded text — as it was, so a review shows up in git as a one-hunk diff. Every
edit re-parses the result and refuses to write unless exactly the intended value changed.
"""

import datetime
import json
import re
import textwrap
from dataclasses import dataclass, field
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
RULES = HERE / "rules"
SITUATIONS = HERE / "situations"
SHARED = RULES / "rulings.yaml"
SWEEPS = HERE / "sweeps"


# --- model ------------------------------------------------------------------------------------

@dataclass
class Clause:
    id: str
    line: int                      # 1-based line of `- id:`
    data: dict
    raw: str                       # the clause's lines without `- id:` and `text:`, comments kept

    @property
    def encoded(self):
        return self.data.get("effects") not in (None, "none")


@dataclass
class Ruling:
    id: str
    owner: str
    path: Path
    line: int
    data: dict

    @property
    def state(self):
        if self.data.get("status") == "decided":
            return "decided"
        if self.data.get("answer") not in (None, ""):
            return "answered"
        return "open"


@dataclass
class Situation:
    file: str
    id: str
    name: str
    line: int
    app_today: str | None
    refs: set

    @property
    def diverges(self):
        return self.app_today is not None and not str(self.app_today).startswith("same")


@dataclass
class Rule:
    id: str
    name: str
    kind: str
    path: Path
    data: dict = field(default_factory=dict)
    clauses: list = field(default_factory=list)
    rulings: list = field(default_factory=list)
    situations: list = field(default_factory=list)
    format_notes: list = field(default_factory=list)   # (line, text)
    error: str | None = None

    @property
    def reviewed(self):
        return self.data.get("reviewed")

    @property
    def agent_pass(self):
        return self.data.get("agent_pass")

    def flagged(self, item_id):
        """The flag's note if the agent pass names this clause or ruling, else None."""
        ap = self.agent_pass or {}
        return ap.get("note") if item_id in (ap.get("about") or []) else None

    def rulings_in(self, state):
        return [r for r in self.rulings if r.state == state]

    @property
    def to_answer(self):
        """Open rulings, less those sent back to the agent: their options are being redone."""
        return [r for r in self.rulings_in("open") if not self.flagged(r.id)]

    @property
    def needs_you(self):
        """What the owner has to do here, most urgent first."""
        out = []
        if self.error:
            out.append("fix the YAML")
        if n := len(self.to_answer):
            out.append(f"answer {n} ruling{'s' * (n > 1)}")
        if not self.reviewed and self.kind != "shared" and not self.error:
            out.append("review")
        return out

    @property
    def needs_agent(self):
        out = []
        if n := len(self.rulings_in("answered")):
            out.append(f"process {n} answer{'s' * (n > 1)}")
        if self.agent_pass:
            out.append("flagged")
        return out


def load():
    rules = []
    for path in sorted(RULES.rglob("*.yaml")):
        rules.append(_load_rule(path))
    situations = _load_situations()
    for s in situations:
        for rule in rules:
            if rule.id in s.refs or (rule.kind == "shared" and s.refs & {x.id for x in rule.rulings}):
                rule.situations.append(s)
    return rules


@dataclass
class Sweep:
    """The rules that affect one hero: the hero's own abilities, advantages, disadvantages and
    items, less those skipped, plus the core rules the sweep file lists."""
    name: str
    wanted: dict                   # rule id → why it is in the sweep
    skipped: dict                  # rule id → why it is not

    def of(self, rules):
        """The loaded rules in the sweep; the shared rulings always are."""
        return [r for r in rules if r.id in self.wanted or r.kind == "shared"]

    def missing(self, rules):
        """(id, why) for every rule in the sweep without a file yet."""
        have = {r.id for r in rules}
        return [(i, why) for i, why in self.wanted.items() if i not in have]


def load_sweep(name):
    path = SWEEPS / f"{name}.yaml"
    if not path.exists():
        known = ", ".join(sorted(p.stem for p in SWEEPS.glob("*.yaml"))) or "none"
        raise FileNotFoundError(f"no sweep {name!r} in {SWEEPS.relative_to(HERE)} (known: {known})")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    skipped = {str(k): str(v) for k, v in (data.get("skip") or {}).items()}
    wanted = {}
    if hero := data.get("hero"):
        for rule_id in _hero_rule_ids(json.loads((path.parent / hero).read_text(encoding="utf-8"))):
            if rule_id not in skipped:
                wanted[rule_id] = OWN.get(rule_id.split("_")[0], "on the sheet")
    for k, v in (data.get("rules") or {}).items():
        wanted[str(k)] = str(v)
    return Sweep(name=data.get("name", name), wanted=wanted, skipped=skipped)


OWN = {"SA": "own special ability", "ADV": "own advantage", "DISADV": "own disadvantage",
       "ITEMTPL": "own equipment"}


def _hero_rule_ids(hero):
    """The Optolith ids an exported hero carries rules for: activatables and item templates."""
    ids = [k for k, v in (hero.get("activatable") or {}).items() if v]
    ids += [it["template"] for it in (hero.get("belongings", {}).get("items") or {}).values()
            if it.get("template")]
    return list(dict.fromkeys(ids))


def _load_rule(path):
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    rel = path.relative_to(HERE)
    try:
        data = yaml.safe_load(text)
    except yaml.YAMLError as e:
        return Rule(id=path.stem, name="(does not parse)", kind="error", path=rel, error=str(e))
    if isinstance(data, list):                       # rules/rulings.yaml
        rule = Rule(id="shared", name="Rulings across rules", kind="shared", path=rel)
        items = data
    else:
        rule = Rule(id=data.get("id", path.stem), name=data.get("name", ""),
                    kind=data.get("kind", "?"), path=rel, data=data)
        items = data.get("rulings") or []
        section = key_range(lines, "clauses")
        for c in data.get("clauses") or []:
            n = item_line(lines, c["id"], section)
            rule.clauses.append(Clause(id=c["id"], line=n + 1, data=c,
                                       raw=_clause_body(lines, n)))
    section = key_range(lines, "rulings") if rule.kind != "shared" else (0, len(lines))
    for r in items:
        n = item_line(lines, r["id"], section)
        rule.rulings.append(Ruling(id=r["id"], owner=rule.id, path=rel, line=n + 1, data=r))
    rule.format_notes = [(i + 1, l.split("# FORMAT:", 1)[1].strip())
                         for i, l in enumerate(lines) if "# FORMAT:" in l]
    return rule


def _load_situations():
    out = []
    for path in sorted(SITUATIONS.glob("*.yaml")):
        text = path.read_text(encoding="utf-8")
        try:
            data = yaml.safe_load(text) or {}
        except yaml.YAMLError:
            continue
        lines = text.splitlines()
        for s in data.get("situations") or []:
            n = item_line(lines, str(s["id"]), (0, len(lines)))
            out.append(Situation(file=path.stem, id=str(s["id"]), name=s.get("name", ""),
                                 line=n + 1, app_today=s.get("app_today"), refs=_refs(s)))
    return out


def _refs(node):
    """Every rule id and ruling id a situation names: `SA_62.ST2` gives SA_62 and ST2."""
    out = set()
    if isinstance(node, dict):
        for k, v in node.items():
            if k not in ("name", "app_today"):          # prose, not references
                out |= _refs(k) | _refs(v)
    elif isinstance(node, list):
        for v in node:
            out |= _refs(v)
    elif isinstance(node, str):
        for word in re.findall(r"[A-Za-z_][\w-]*(?:\.[\w-]+)?", node):
            out |= set(word.split("."))
    return out


def _clause_body(lines, n):
    start, end = item_range(lines, n)
    out, skip = [], None
    for line in lines[start + 1:end]:
        ind = indent(line)
        if skip is not None and (not line.strip() or ind > skip):
            continue
        skip = None
        if line.strip().startswith("text:"):
            skip = ind
            continue
        out.append(line)
    base = min((indent(l) for l in out if l.strip()), default=0)
    return "\n".join(l[base:] for l in out).rstrip()


# --- line ranges ------------------------------------------------------------------------------

def indent(line):
    return len(line) - len(line.lstrip(" "))


def block_end(lines, start, key_indent):
    """End (exclusive) of the value that begins on `start`: the following lines that are blank
    or indented deeper than `key_indent`, without trailing blank lines. A comment indented no
    deeper than the key does not end the value, and belongs to it only if more of it follows."""
    end = start + 1
    last = start + 1
    while end < len(lines):
        line = lines[end]
        if line.lstrip().startswith("#"):
            end += 1
            if indent(line) > key_indent:
                last = end
            continue
        if line.strip() and indent(line) <= key_indent:
            break
        end += 1
        if line.strip():
            last = end
    return last


def key_range(lines, key):
    """(start, end) of a top-level key and its value, or None."""
    for i, line in enumerate(lines):
        if re.match(rf"{re.escape(key)}:(\s|$)", line):
            return i, block_end(lines, i, 0)
    return None


def item_line(lines, item_id, section):
    """0-based line of `- id: <item_id>` within `section`."""
    lo, hi = section or (0, len(lines))
    pat = re.compile(rf"\s*-\s+id:\s*[\"']?{re.escape(item_id)}[\"']?\s*(#.*)?$")
    for i in range(lo, hi):
        if pat.match(lines[i]):
            return i
    raise KeyError(item_id)


def item_range(lines, n):
    dash = indent(lines[n])
    return n, block_end(lines, n, dash)


# --- rendering values -------------------------------------------------------------------------

def _flow_signature(by, date):
    return f'{{ by: "{by}", date: {date.isoformat()} }}'


def _scalar(key, text, key_indent, width=96):
    """`key: value` as lines; anything longer than a word becomes a folded block."""
    pad = " " * key_indent
    if re.fullmatch(r"[a-z]", text):
        return [f"{pad}{key}: {text}"]
    body = textwrap.wrap(" ".join(text.split()), width - key_indent - 2)
    return [f"{pad}{key}: >"] + [f"{pad}  {l}" for l in body]


# --- edits ------------------------------------------------------------------------------------

class EditRefused(Exception):
    pass


def _normalise(node):
    if isinstance(node, dict):
        return {k: _normalise(v) for k, v in node.items()}
    if isinstance(node, list):
        return [_normalise(v) for v in node]
    if isinstance(node, str):
        return " ".join(node.split())
    return node


def _write_checked(path, lines, new_lines, expect):
    """Write `new_lines` only if they parse to the old data with `expect` applied to it."""
    old = yaml.safe_load("\n".join(lines))
    expect(old)
    text = "\n".join(new_lines) + "\n"
    try:
        new = yaml.safe_load(text)
    except yaml.YAMLError as e:
        raise EditRefused(f"the edit would not parse: {e}") from e
    if _normalise(new) != _normalise(old):
        raise EditRefused("the edit changed more than it should; nothing written")
    path.write_text(text, encoding="utf-8")


def _read(path):
    return (HERE / path).read_text(encoding="utf-8").splitlines()


def set_answer(path, ruling_id, answer):
    """Write an answer (an option letter or free text) into a ruling; empty clears it."""
    path = HERE / path
    lines = _read(path)
    shared = path == SHARED
    section = (0, len(lines)) if shared else key_range(lines, "rulings")
    n = item_line(lines, ruling_id, section)
    start, end = item_range(lines, n)
    key_indent = indent(lines[n]) + 2
    answer = (answer or "").strip()
    new = _scalar("answer", answer, key_indent) if answer else [" " * key_indent + "answer: null"]
    at = next((i for i in range(start + 1, end)
               if indent(lines[i]) == key_indent and lines[i].strip().startswith("answer:")), None)
    if at is None:
        new_lines = lines[:end] + new + lines[end:]
    else:
        new_lines = lines[:at] + new + lines[block_end(lines, at, key_indent):]

    def expect(data):
        items = data if shared else data["rulings"]
        next(r for r in items if r["id"] == ruling_id)["answer"] = answer or None

    _write_checked(path, lines, new_lines, expect)


def _set_top_level(path, key, new_value_lines, value, after="reviewed"):
    path = HERE / path
    lines = _read(path)
    rng = key_range(lines, key)
    if rng is None and not new_value_lines:
        return
    if rng is None:
        anchor = key_range(lines, after)
        at = anchor[1] if anchor else len(lines)
        new_lines = lines[:at] + new_value_lines + lines[at:]
    else:
        start, end = rng
        if new_value_lines and end == start + 1 and (m := re.search(r"\s+#.*$", lines[start])) \
                and len(new_value_lines) == 1:
            new_value_lines = [new_value_lines[0] + m.group(0)]   # keep a trailing comment
        new_lines = lines[:start] + new_value_lines + lines[end:]

    def expect(data):
        if value is None and not new_value_lines:
            data.pop(key, None)
        else:
            data[key] = value

    _write_checked(path, lines, new_lines, expect)


def set_reviewed(path, by, date=None):
    """Mark a rule as read against its page by `by`; `by=None` withdraws it."""
    if by is None:
        return _set_top_level(path, "reviewed", ["reviewed: null"], None)
    date = date or datetime.date.today()
    _set_top_level(path, "reviewed", [f"reviewed: {_flow_signature(by, date)}"],
                   {"by": by, "date": date})


def set_agent_pass(path, by, note, about=(), date=None):
    """Flag a rule for another agent pass, with what the agent should look at: `about` narrows it
    to clause and ruling ids."""
    date = date or datetime.date.today()
    lines = ["agent_pass:", f"  requested: {_flow_signature(by, date)}"]
    value = {"requested": {"by": by, "date": date}}
    if about:
        lines.append(f"  about: [{', '.join(about)}]")
        value["about"] = list(about)
    lines += _scalar("note", note, 2)
    value["note"] = note
    _set_top_level(path, "agent_pass", lines, value)


def clear_agent_pass(path):
    _set_top_level(path, "agent_pass", [], None)
