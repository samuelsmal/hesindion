"""The mechanical move of the draft rule and situations files to the engine's vocabulary (spec
§10.3 step 1, plan Task 7).

A fixed old → new table, applied in ruamel.yaml's round-trip mode so comments survive. Everything
the table does not cover is left as it is and listed in `MIGRATION.md` as residue for a hand
edit: nothing is guessed. A clause's `text`, a situation's `expect` values and a rule's
`reviewed` are never touched.

ruamel re-emits a whole file in its own layout (flow-mapping spacing, the indentation of a
top-level list, aligned values). So the file is written line by line: a line whose YAML the table
did not change is copied from the input as it was; a changed line keeps the input's whitespace
around the tokens that stayed; only new lines are ruamel's.

    cd scripts && uv run --with pyyaml --with ruamel.yaml python -m rulec.migrate ../specs/rules
"""
import copy
import io
import re
import sys
from collections import namedtuple
from difflib import SequenceMatcher
from pathlib import Path

from ruamel.yaml import YAML
from ruamel.yaml.comments import CommentedMap, CommentedSeq
from ruamel.yaml.scalarstring import DoubleQuotedScalarString

from . import layout
from . import vocab as vocab_mod
from .errors import RulecError
from .forms import Forms

Residue = namedtuple("Residue", "line path key reason")

RULE_ID = re.compile(r"^[A-Z]+_\d+$")          # SA_862, ITEMTPL_19, COND_6, …
MIGRATION = "MIGRATION.md"
REVIEWS = "Reviews reset by hand edits"

# --- the mechanical map -----------------------------------------------------------------------
RULE_KEYS = {"catalog_id": "catalogId", "agent_pass": "agentPass", "tiers": "levels"}
RULING_KEYS = {"why_recommended": "whyRecommended", "applies_to": "appliesTo"}
FILE_KEYS = {"hero_file": "heroFile", "base_hero": "hero"}
SITUATION_KEYS = {"app_today": "appToday"}
EXPECT_KEYS = {
    "not_offered": "notOffered", "not_applied": "notApplied", "ini_base": "iniBase", "le_max": "leMax",
    "pa_shield": "pa(with: shield)", "shield_parry": "pa(with: shield)", "parry_shield": "pa(with: shield)",
    "pa_weapon": "pa(with: weapon)",
    "parry_main": "pa(with: mainHand)", "parry_off": "pa(with: offHand)",
    "attack_main": "at(with: mainHand)", "attack_off": "at(with: offHand)",
}
WHEN_KEYS = {
    "manoeuvre": "action.manoeuvre", "attack": "action.attack", "defence": "action.defence",
    "roll.with": "action.with", "roll.with.shieldSize": "loadout.shield.size",
    "roll.with.reach": "loadout.reach",
    "weapon.technique": "loadout.weapon.technique", "loadout.technique": "loadout.weapon.technique",
    "ruleset": "rulesets", "any_of": "any", "all_of": "all",
}
TELL_TO = {"opponent": "opponent", "hero": "player", "player": "player"}
# old verb -> the verb it becomes; an effect that already has the new verb keeps the old one
NEW_VERB = {"apply_level": "useLevel", "halve": "multiply", "shift": "add", "opponent_add": "add",
            "remove": "suppress", "requires": "require", "excludes": "forbid", "charge": "cost"}
EFFECT_META = ("when", "ruling", "because", "phase")
_RENAME_PAIRS = ({*RULE_KEYS.items(), *RULING_KEYS.items(), *FILE_KEYS.items(),
                  *SITUATION_KEYS.items(), *EXPECT_KEYS.items(), *WHEN_KEYS.items(),
                  *NEW_VERB.items(), ("unless", "when"), ("effects", "none"), ("why", "none"),
                  ("check", "check.talent")})

_VOCAB = None


def _vocab():
    global _VOCAB
    if _VOCAB is None:
        _VOCAB = vocab_mod.load()
    return _VOCAB


def _yaml(top_level_list=False):
    y = YAML(typ="rt")
    y.preserve_quotes = True
    # 4096, not 100: at 100 ruamel re-wraps the long flow lines of a changed line.
    y.width = 4096
    # The rule files indent a list under its key by 4 with the dash at 2; the root's rulings.yaml, a
    # list at the top, has its dashes at column 0.
    y.indent(mapping=2, sequence=2 if top_level_list else 4, offset=0 if top_level_list else 2)
    y.brace_single_entry_mapping_in_flow_sequence = True     # `[{ a: 1 }]`, not `[a: 1]`
    y.representer.add_representer(
        type(None), lambda r, _: r.represent_scalar("tag:yaml.org,2002:null", "null"))
    return y


def is_snake(key) -> bool:
    """A snake_case key. A query key (`check.modifier(talent: TAL_8)`) is judged by its target
    name: the context value is a name (a rule or talent id), not a key."""
    if isinstance(key, str) and "(" in key:
        key = key.split("(", 1)[0]
    return isinstance(key, str) and "_" in key and not RULE_ID.match(key)


# --- small CommentedMap helpers ---------------------------------------------------------------
def _replace_key(m, old, new, value=None, keep_value=True):
    """Put `new` at `old`'s position (with `value`, or old's value) and carry old's comment.
    Never overwrites: callers check first, and a mapping that already has `new` raises."""
    if new in m and new != old:
        raise ValueError(f"{new} is already a key")
    comment = m.ca.items.pop(old, None)
    idx = list(m.keys()).index(old)
    val = m.pop(old)
    m.insert(idx, new, val if keep_value else value)
    if comment is not None:
        m.ca.items[new] = comment


def _rename(m, table):
    for old in [k for k in m if k in table]:
        if table[old] not in m:
            new = table[old]
            if "(" in new:
                new = DoubleQuotedScalarString(new)
            _replace_key(m, old, new)


def _flow_like(src, new):
    """`new` in the flow or block style of `src`."""
    if isinstance(src, (CommentedMap, CommentedSeq)) and src.fa.flow_style():
        new.fa.set_flow_style()
    return new


def _cmap(src, *pairs):
    return _flow_like(src, CommentedMap(pairs))


# --- conditions (`when`, `unless`, `requires`) ------------------------------------------------
def _map_condition(c):
    """Apply the `when` rows to condition `c` in place; recurses through any/all/not."""
    if not isinstance(c, CommentedMap):
        return
    for k in list(c.keys()):
        if k not in c:
            continue
        val = c[k]
        if k == "gm.fact" and isinstance(val, str) and f"gmFact.{val}" not in c:
            _replace_key(c, k, f"gmFact.{val}", True, keep_value=False)
        elif k == "choice" and isinstance(val, str) and f"choice.{val}" not in c:
            _replace_key(c, k, f"choice.{val}", True, keep_value=False)
            if "bonus" in c and f"choice.{val}.bonus" not in c:
                _replace_key(c, "bonus", f"choice.{val}.bonus")
        elif k == "check" and _talent_check(val) and "check.talent" not in c:
            _replace_key(c, k, "check.talent")
        elif k in WHEN_KEYS and WHEN_KEYS[k] not in c:
            _replace_key(c, k, WHEN_KEYS[k])
    for k, val in c.items():
        if k in ("any", "all") and isinstance(val, list):
            for item in val:
                _map_condition(item)
        elif k == "not":
            _map_condition(val)


def _talent_check(val):
    """`check: X` names a talent only when X is not a kind of check: the drafts also write
    `check: at`, `check: aw`, `check: talent`, where `check.talent` would change the meaning."""
    return isinstance(val, str) and val != "talent" and not _vocab().is_target(val)


def _non_facts(c):
    """The keys of condition `c` that are not facts of the vocabulary (after mapping)."""
    v = _vocab()
    if not isinstance(c, dict) or not c:
        return ["<not a mapping>"]
    out = []
    for k, val in c.items():
        if k in ("any", "all"):
            if not isinstance(val, list):
                out.append(k)
            for item in val if isinstance(val, list) else []:
                out += _non_facts(item)
        elif k == "not":
            out += _non_facts(val)
        elif v.fact_owner(str(k)) is None:
            out.append(str(k))
    return out


def _map_whens(node):
    """Every `when:` mapping anywhere under `node` (effect payloads included)."""
    if isinstance(node, dict):
        for k, val in node.items():
            if k == "when":
                _map_condition(val)
            _map_whens(val)
    elif isinstance(node, list):
        for item in node:
            _map_whens(item)


# --- effects ----------------------------------------------------------------------------------
def _only(payload, required, optional=()):
    return (isinstance(payload, dict) and set(required) <= set(payload)
            and set(payload) <= set(required) | set(optional))


def _verb_rows(e):
    """Apply the effect rows to effect `e` in place. Returns the list of effects it becomes
    (more than one only for `provides`)."""
    if "unless" in e and "when" not in e:
        cond = e["unless"]
        _map_condition(cond)
        _replace_key(e, "unless", "when", _cmap(cond, ("not", cond)), keep_value=False)

    for k in list(e.keys()):
        p = e[k]
        if k in NEW_VERB and NEW_VERB[k] in e:
            continue
        if k == "apply_level" and _only(p, ("rule", "level")):
            _replace_key(p, "level", "as")
            _replace_key(e, k, "useLevel")
        elif k == "halve" and _only(p, ("value",), ("round",)):
            new = _cmap(p, ("to", p["value"]), ("by", 0.5))
            if "round" in p:
                new["round"] = p["round"]
            _replace_key(e, k, "multiply", new, keep_value=False)
        elif k == "shift" and _only(p, ("param", "steps", "table")):
            param = str(p["param"])
            to = param if param.startswith("spell.") else f"spell.{param}"
            new = _cmap(p, ("to", to), ("value", p["steps"]), ("scale", p["table"]))
            _replace_key(e, k, "add", new, keep_value=False)
        elif k == "opponent_add" and _only(p, ("to", "value")):
            to = p["to"]
            if isinstance(to, list):
                to = _flow_like(to, CommentedSeq(f"opponent.{t}" for t in to))
            else:
                to = f"opponent.{to}"
            _replace_key(e, k, "add", _cmap(p, ("to", to), ("value", p["value"])), keep_value=False)
        elif k == "remove" and _only(p, ("line",)):
            new = _cmap(p, ("line", _cmap(p, ("line", p["line"]))))
            _replace_key(e, k, "suppress", new, keep_value=False)
        elif k == "requires" and isinstance(p, dict):
            that = copy.deepcopy(p)
            _map_condition(that)
            if not _non_facts(that):
                _replace_key(e, k, "require", _cmap(p, ("that", that)), keep_value=False)
        elif k == "excludes" and _only(p, ("manoeuvre",)):
            new = _cmap(p, ("what", _cmap(p, ("manoeuvre", p["manoeuvre"]))), ("together", True))
            _replace_key(e, k, "forbid", new, keep_value=False)
        elif k == "tell" and _tell_ok(p):
            (who, text), = p.items()
            e[k] = _cmap(p, ("to", TELL_TO[who]), ("text", text))
        elif k == "charge" and _only(p, ("amount", "pool")):
            new = _cmap(p, ("pool", p["pool"]), ("amount", p["amount"]))
            _replace_key(e, k, "cost", new, keep_value=False)
        elif k == "gain" and _only(p, ("state",)):
            e[k] = _cmap(p, ("rule", p["state"]))
    _map_whens(e)

    if "provides" in e and _provides_ok(e["provides"]):
        return _split_provides(e)
    return [e]


def _tell_ok(p):
    return (isinstance(p, dict) and len(p) == 1 and next(iter(p)) in TELL_TO
            and isinstance(next(iter(p.values())), str))


def _provides_ok(p):
    return isinstance(p, dict) and p and "from" not in p and not any(is_snake(k) for k in p)


def _split_provides(e):
    p = e["provides"]
    out = []
    names = list(p.keys())
    for i, name in enumerate(names):
        new = CommentedMap()
        for k in e:
            if k == "provides":
                new["provide"] = _cmap(p, ("name", name), ("value", p[name]))
                if name in p.ca.items:
                    new["provide"].ca.items["value"] = p.ca.items[name]
            else:
                new[k] = e[k] if i == len(names) - 1 else copy.deepcopy(e[k])
        out.append(new)
    # The effect's own comments (after its last key) go with the last copy.
    last = out[-1]
    for k, c in e.ca.items.items():
        last.ca.items["provide" if k == "provides" else k] = c
    if e.ca.comment:
        out[0].ca.comment = e.ca.comment
    return out


def _effects(seq):
    if not isinstance(seq, CommentedSeq):
        return
    i = 0
    while i < len(seq):
        e = seq[i]
        if isinstance(e, CommentedMap):
            new = _verb_rows(e)
            if not (len(new) == 1 and new[0] is e):
                comment = seq.ca.items.pop(i, None)
                seq[i] = new[0]
                for j, extra in enumerate(new[1:], 1):
                    seq.insert(i + j, extra)
                if comment is not None:
                    seq.ca.items[i + len(new) - 1] = comment
                i += len(new) - 1
        i += 1


# --- rules ------------------------------------------------------------------------------------
def _clause(c):
    if not isinstance(c, CommentedMap):
        return
    if c.get("effects") == "none" and "why" in c and "none" not in c:
        keys = list(c.keys())
        why_comment = c.ca.items.pop("why", None)
        why = c.pop("why")
        _replace_key(c, "effects", "none", why, keep_value=False)
        if why_comment is not None and keys.index("why"):   # what followed `why` stays
            prev = keys[keys.index("why") - 1]
            _hang_after_key(c, "none" if prev == "effects" else prev, why_comment)
    elif isinstance(c.get("effects"), list) and "why" in c:
        why = " ".join(str(c["why"]).split())
        keys = list(c.keys())
        why_comment = c.ca.items.pop("why", None)
        c.pop("why")
        if why_comment is not None and keys.index("why"):
            _hang_after_key(c, keys[keys.index("why") - 1], why_comment)
        c.yaml_set_comment_before_after_key("effects", before=f"why: {why}", indent=c.lc.col)
    _effects(c.get("effects"))


def _hang_after_key(m, key, comment):
    """Hang `comment` (the comment slot of a removed key: the lines that followed its value) after
    the value of `m[key]`, going down to the last node of a block value."""
    new = comment[2] if len(comment) > 2 else None
    if new is None:
        return
    node, slot = m, key
    while True:
        val = node[slot]
        if not isinstance(val, (CommentedMap, CommentedSeq)) or not val or val.fa.flow_style():
            break
        if getattr(val.ca, "end", None):              # comments after the whole block
            val.ca.end.append(new)
            return
        node, slot = val, (list(val.keys())[-1] if isinstance(val, CommentedMap) else len(val) - 1)
    idx = 2 if isinstance(node, CommentedMap) else 0      # the slot after a value
    entry = node.ca.items.setdefault(slot, [None, None, None, None] if idx == 2 else [None, None])
    if entry[idx] is None:
        entry[idx] = new
    else:
        entry[idx].value = entry[idx].value + new.value


def _ruling(r):
    if isinstance(r, CommentedMap):
        _rename(r, RULING_KEYS)


def migrate_rule_doc(doc):
    if isinstance(doc, CommentedSeq):                # rulings.yaml: a list of rulings
        for r in doc:
            _ruling(r)
        return
    if not isinstance(doc, CommentedMap):
        return
    _rename(doc, RULE_KEYS)
    for c in doc.get("clauses") or []:
        _clause(c)
    for r in doc.get("rulings") or []:
        _ruling(r)


# --- situations -------------------------------------------------------------------------------
def _choose(ch):
    if not isinstance(ch, CommentedMap) or "bonus" not in ch:
        return
    chosen = [k for k, val in ch.items() if k != "bonus" and val is True]
    if len(chosen) != 1 or _vocab().fact_owner(str(chosen[0])) is not None:
        return
    x = chosen[0]
    if f"choice.{x}" in ch or f"choice.{x}.bonus" in ch:
        return
    _replace_key(ch, x, f"choice.{x}")
    _replace_key(ch, "bonus", f"choice.{x}.bonus")


def _expect(node):
    if isinstance(node, CommentedMap):
        _rename(node, EXPECT_KEYS)
        for val in node.values():
            _expect(val)
    elif isinstance(node, list):
        for item in node:
            _expect(item)


def _expects_under(node):
    if isinstance(node, dict):
        for k, val in node.items():
            if k == "expect":
                _expect(val)
            else:
                _expects_under(val)
    elif isinstance(node, list):
        for item in node:
            _expects_under(item)


def migrate_situations_doc(doc):
    if not isinstance(doc, CommentedMap):
        return
    _rename(doc, FILE_KEYS)
    for s in doc.get("situations") or []:
        if not isinstance(s, CommentedMap):
            continue
        _rename(s, SITUATION_KEYS)
        _choose(s.get("choose"))
        _expects_under(s)


# --- residue ----------------------------------------------------------------------------------
_OLD_VERB_WHY = {
    "apply_level": lambda p: _extra(p, ("rule", "level")),
    "halve": lambda p: _extra(p, ("value", "round")),
    "shift": lambda p: _extra(p, ("param", "steps", "table")),
    "opponent_add": lambda p: _extra(p, ("to", "value")),
    "remove": lambda p: _extra(p, ("line",)),
    "requires": lambda p: "a key that is not a fact: " + ", ".join(_non_facts(_mapped(p))),
    "excludes": lambda p: _extra(p, ("manoeuvre",)),
    "charge": lambda p: _extra(p, ("amount", "pool")),
    "provides": lambda p: ("`from` is a pointer, not a named value" if isinstance(p, dict) and "from" in p
                           else "a snake_case name, or not a mapping of names"),
    "unless": lambda p: "next to a `when`: which of the two conditions wins is not mechanical",
}


def _mapped(p):
    p = copy.deepcopy(p)
    _map_condition(p)
    return p


def _extra(p, allowed):
    if not isinstance(p, dict):
        return "the payload is not a mapping"
    extra = [str(k) for k in p if k not in allowed]
    missing = [k for k in allowed if k not in p]
    parts = []
    if extra:
        parts.append("keys outside the row: " + ", ".join(extra))
    if missing:
        parts.append("missing " + ", ".join(missing))
    return "; ".join(parts) or "does not fit its row"


def _verb_why(k, p, effect):
    if k in NEW_VERB and NEW_VERB[k] in effect:
        return f"the effect already has `{NEW_VERB[k]}`: two verbs in one effect"
    if k in _OLD_VERB_WHY:
        return _OLD_VERB_WHY[k](p)
    return "no one-to-one verb"


def _label(item, i):
    """`[F4]` for a list item with an id, `["19.2"]` for a numeric one, else `[i]`."""
    ident = item.get("id") if isinstance(item, CommentedMap) else None
    if ident is None:
        return f"[{i}]"
    if isinstance(ident, str) and re.match(r"^[\d.]+$", ident):
        return f'["{ident}"]'
    return f"[{ident}]"


class _Scan:
    def __init__(self):
        v = _vocab()
        self.v = v
        self.forms = Forms(v)
        self.out = []
        self.rule_keys = set(v.raw["ruleKeys"]["required"]) | set(v.raw["ruleKeys"]["optional"])
        ck = v.raw["clauseKeys"]
        self.clause_keys = set(ck["required"]) | set(ck["optional"]) | set(ck["oneOf"])
        self.ruling_keys = set(v.raw["rulingKeys"])

    def add(self, m, k, path, reason):
        line = m.lc.key(k)[0] + 1
        self.out.append(Residue(line, f"{path}.{k}" if path else str(k), str(k), reason))

    def walk(self, node, path, ctx=None):
        if isinstance(node, CommentedSeq):
            for i, item in enumerate(node):
                self.walk(item, f"{path}{_label(item, i)}", ctx)
            return
        if not isinstance(node, CommentedMap):
            return
        for k, val in node.items():
            reason, child = self.check(ctx, node, k, val)
            if reason is None and is_snake(k):
                reason = "snake_case key, no mapping"
            if reason is not None:
                self.add(node, k, path, reason)
            self.walk(val, f"{path}.{k}" if path else str(k), child)

    def check(self, ctx, m, k, val):
        """(reason or None, context for the value)."""
        if ctx == "rule":
            child = {"clauses": "clause", "rulings": "ruling"}.get(k)
            return (None if k in self.rule_keys else "not a rule key in the vocabulary"), child
        if ctx == "clause":
            if k == "why":
                return "`why` without `effects: none`: the clause has no body to carry it", None
            return (None if k in self.clause_keys else "not a clause key in the vocabulary"), \
                ("effect" if k == "effects" else None)
        if ctx == "ruling":
            return (None if k in self.ruling_keys else "not a ruling key in the vocabulary"), None
        if ctx == "effect":
            if k in self.v.verbs:
                reason = self.check_verb(k, val)
                return reason, (f"payload:{k}" if reason is None else None)
            if k in EFFECT_META:
                if k == "when" and not isinstance(val, dict):
                    return "`when` is not a condition mapping", None
                return None, ("cond" if k == "when" else None)
            return _verb_why(k, val, m), None
        if ctx and ctx.startswith("payload:"):
            verb = self.v.verbs[ctx.split(":", 1)[1]]
            fields = {**verb["fields"], **verb.get("optional", {})}
            if k not in fields:
                return f"not a field of `{ctx.split(':', 1)[1]}`", None
            return None, ("cond" if fields[k] == "condition" else None)
        if ctx == "cond":
            if k in ("any", "all"):
                return None, "cond"
            if k == "not":
                return None, "cond"
            if k == "check" and isinstance(val, str):
                return (f"`check: {val}` names the kind of check, not a talent: "
                        "`check.talent` would change the meaning"), None
            return (None if self.v.fact_owner(str(k)) else "not a fact in the vocabulary"), None
        if ctx == "file":
            child = "situation" if k == "situations" else None
            ok = k in self.v.raw["situationFileKeys"]
            return (None if ok else "not a situations-file key in the vocabulary"), child
        if ctx == "situation":
            ok = k in self.v.raw["situationKeys"]
            return (None if ok else "not a situation key in the vocabulary"), \
                {"expect": "expect", "choose": "choose"}.get(k)
        if ctx == "choose":                           # the player's facts
            return (None if self.v.fact_owner(str(k)) else "not a fact in the vocabulary"), None
        if ctx == "expect":
            if k in self.v.raw["expectKeys"]:
                return None, None
            try:
                self.forms.target(k)
                return None, None
            except RulecError:
                return "neither an expect key nor a query", None
        return None, None

    def check_verb(self, k, p):
        """A new verb whose payload still has an old row's shape."""
        if k == "gain" and isinstance(p, dict) and "state" in p:
            return "gain: " + _extra(p, ("state",))
        if k == "tell" and isinstance(p, dict) and set(p) & set(TELL_TO):
            if len(p) == 1:
                return "tell: the text is a structure, not a text"
            return "tell: more than one key, the audience is not mechanical"
        return None


def scan(doc, kind):
    s = _Scan()
    if kind == "rule":
        if isinstance(doc, CommentedSeq):
            s.walk(doc, "", "ruling")
        else:
            s.walk(doc, "", "rule")
    else:
        s.walk(doc, "", "file")
    return s.out


# --- text: keep the input's layout ------------------------------------------------------------
# (trivia, token): trivia is whitespace, newlines and comments, which the transfer keeps as it was
_TRIVIA = r"""((?:\s|(?<!\S)\#[^\n]*)*)"""
_TOKEN = re.compile(_TRIVIA + r"""("(?:\\.|[^"\\])*"|'(?:''|[^'])*'|[^\s{}\[\],:#"']+|\S)""")
_TAIL = re.compile(_TRIVIA + r"$")
_BLOCK = re.compile(r"""^(\s*)(?:-\s+)*[^#'"]*?:\s*[|>][-+0-9]*\s*(?:#.*)?$""")


def _tokens(text):
    toks, pos = [], 0
    while pos < len(text):
        if _TAIL.match(text, pos):
            break
        m = _TOKEN.match(text, pos)
        toks.append((m.group(1), m.group(2)))
        pos = m.end()
    return toks, text[pos:]


def _in_block_flags(lines):
    """For each line: is it inside a block scalar (`>` or `|`)?"""
    flags, block_indent = [], None
    for line in lines:
        body = line.rstrip("\n")
        indent = len(body) - len(body.lstrip())
        if block_indent is not None and (not body.strip() or indent > block_indent):
            flags.append(True)
            continue
        block_indent = None
        flags.append(False)
        m = _BLOCK.match(body)
        if m:
            block_indent = len(m.group(1))
    return flags


def _space_braces(line):
    """`{a: 1}` → `{ a: 1 }`, the drafts' flow-mapping style, outside quotes and comments."""
    out, quote, i = [], None, 0
    while i < len(line):
        ch = line[i]
        if quote:
            out.append(ch)
            if ch == "\\" and quote == '"' and i + 1 < len(line):
                out.append(line[i + 1])
                i += 1
            elif ch == quote:
                quote = None
        elif ch in "\"'" and (i == 0 or line[i - 1] in " {[,:"):
            quote = ch
            out.append(ch)
        elif ch == "#" and (i == 0 or line[i - 1] == " "):
            out.append(line[i:])
            break
        elif ch == "{" and i + 1 < len(line) and line[i + 1] not in " }\n":
            out.append("{ ")
        elif ch == "}" and out and out[-1][-1:] not in (" ", "{"):
            out.append(" }")
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def _transfer(o, b, m):
    """Line `m` (ruamel's, changed from ruamel's line `b`) with the whitespace and comments of
    `o`, the input line(s) `b` was emitted from."""
    ot, otail = _tokens(o.rstrip("\n"))
    bt, _ = _tokens(b.rstrip("\n"))
    mt, _ = _tokens(m.rstrip("\n"))
    if [t for _, t in ot] != [t for _, t in bt]:
        return _space_braces(m)
    sm = SequenceMatcher(None, [t for _, t in bt], [t for _, t in mt], autojunk=False)
    if not _same_line(bt, mt):                       # not the same line changed, a new one
        return _space_braces(m)
    parts, pending = [], ""
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            for n, (ws, t) in enumerate(ot[i1:i2]):
                parts.append((pending + ws if n == 0 and pending else ws) + t)
            pending = "" if i2 > i1 else pending
        elif tag in ("replace", "insert"):
            for n, (ws, t) in enumerate(mt[j1:j2]):
                if n == 0 and tag == "replace":
                    ws = pending + ot[i1][0]
                    pending = ""
                parts.append(ws + t)
        if tag in ("replace", "delete"):             # a comment in the trivia of a dropped token stays
            dropped = ot[i1 + (1 if tag == "replace" else 0):i2]
            pending += "".join(ws for ws, _ in dropped if "#" in ws)
    text = "".join(parts) + pending + otail
    text = "\n".join(_space_braces(x) for x in text.split("\n"))
    return text + ("\n" if m.endswith("\n") else "")


def _renamed(a, b):
    """Is key `b` what the table makes of key `a`?"""
    if a == b or (a, b) in _RENAME_PAIRS:
        return True
    if a == "gm.fact":
        return b.startswith("gmFact.")
    return b.startswith("choice.") and (a in ("choice", "bonus") or b == f"choice.{a}")


def _same_line(bt, mt):
    """Is ruamel's line `m` a change of its line `b`, rather than a new line that happens to sit
    at the same place? Its key must be `b`'s or what the table renames it to, and half of its
    words must agree (a bare `key:` / `key: >` / `key: value` line is exempt)."""
    bw = [t.strip("\"'") for _, t in bt if re.match(r"[\w\"']", t)]
    mw = [t.strip("\"'") for _, t in mt if re.match(r"[\w\"']", t)]
    if not bw or not mw or not _renamed(bw[0], mw[0]):
        return False
    if len(bt) <= 3 and len(mt) <= 3:
        return True
    return SequenceMatcher(None, bw, mw, autojunk=False).ratio() >= 0.5


def _norm(line):
    return "".join(t for _, t in _tokens(line.rstrip("\n"))[0])


def _chunks(O, B):
    """Line correspondences between the input `O` and ruamel's re-emission `B`: one line to one
    where the tokens agree (whitespace aside), else a block of lines to a block."""
    for tag, i1, i2, j1, j2 in SequenceMatcher(None, O, B, autojunk=False).get_opcodes():
        if tag == "equal":
            yield from ([j1 + d, j1 + d + 1, i1 + d, i1 + d + 1] for d in range(i2 - i1))
            continue
        on = [_norm(x) for x in O[i1:i2]]
        bn = [_norm(x) for x in B[j1:j2]]
        for t2, a1, a2, b1, b2 in SequenceMatcher(None, on, bn, autojunk=False).get_opcodes():
            if t2 == "equal":
                yield from ([j1 + b1 + d, j1 + b1 + d + 1, i1 + a1 + d, i1 + a1 + d + 1]
                            for d in range(a2 - a1))
            else:
                yield [j1 + b1, j1 + b2, i1 + a1, i1 + a2]


def _shape(line):
    return re.match(r"\s*(?:-\s+)*", line).group(0)


def _reconcile(orig, base, new):
    O = orig.splitlines(keepends=True)
    B = base.splitlines(keepends=True)
    M = new.splitlines(keepends=True)
    if B == M:
        return orig
    # chunks: [b1, b2, o1, o2], covering B and O in order
    chunks, pending = [], None
    for c in _chunks(O, B):
            if pending is not None:
                c[2], pending = pending, None
            if c[0] == c[1] and chunks:              # O lines ruamel dropped: keep with the last chunk
                chunks[-1][3] = c[3]
            elif c[0] == c[1]:
                pending = c[2]
            else:
                chunks.append(c)
    chunk_of = {}
    for n, c in enumerate(chunks):
        for j in range(c[0], c[1]):
            chunk_of[j] = n
    ops = SequenceMatcher(None, B, M, autojunk=False).get_opcodes()
    eq_op = {}
    for n, (tag, j1, j2, _, _) in enumerate(ops):
        if tag == "equal":
            for j in range(j1, j2):
                eq_op[j] = n
    kept = [len({eq_op.get(j) for j in range(c[0], c[1])}) == 1 and eq_op.get(c[0]) is not None
            for c in chunks]
    in_block = _in_block_flags(M)

    def fresh(k):
        return M[k] if in_block[k] else _space_braces(M[k])

    out, emitted = [], set()
    for tag, j1, j2, k1, k2 in ops:
        if tag == "equal":
            for d in range(j2 - j1):
                n = chunk_of[j1 + d]
                if kept[n]:
                    if n not in emitted:
                        out += O[chunks[n][2]:chunks[n][3]]
                        emitted.add(n)
                else:
                    out.append(fresh(k1 + d))
        elif tag == "replace":
            # A changed line keeps its input line's whitespace when both sit at the same place
            # in the structure (same indentation and list dashes).
            bs = [_shape(x) for x in B[j1:j2]]
            ms = [_shape(x) for x in M[k1:k2]]
            for t2, a1, a2, b1, b2 in SequenceMatcher(None, bs, ms, autojunk=False).get_opcodes():
                for d in range(b2 - b1):
                    k = k1 + b1 + d
                    c = chunks[chunk_of[j1 + a1 + d]] if t2 == "equal" else None
                    if c and c[1] - c[0] == 1 and c[3] > c[2] and not in_block[k]:
                        out.append(_transfer("".join(O[c[2]:c[3]]), B[j1 + a1 + d], M[k]))
                    else:
                        out.append(fresh(k))
        else:
            out += [fresh(k) for k in range(k1, k2)]
    return "".join(out)


# --- entry points -----------------------------------------------------------------------------
def migrate_text(text, kind):
    """`(new_text, [Residue])` for one file's text; `kind` is "rule" or "situations"."""
    top_level_list = re.search(r"^- ", text, re.M) is not None
    y = _yaml(top_level_list)
    doc = y.load(text)
    before = io.StringIO()
    y.dump(doc, before)
    if kind == "rule":
        migrate_rule_doc(doc)
    elif kind == "situations":
        migrate_situations_doc(doc)
    else:
        raise ValueError(kind)
    after = io.StringIO()
    y.dump(doc, after)
    out = _reconcile(text, before.getvalue(), after.getvalue())
    return out, scan(_yaml().load(out), kind)


def snake_keys_in_text(text):
    """`[(line, key)]` for every snake_case mapping key in YAML text, found by regex rather than
    by parsing: the independent check the tests hold the residue list against."""
    lines = text.splitlines(keepends=True)
    flags = _in_block_flags(lines)
    out = []
    key = re.compile(r"""(?:^\s*(?:-\s+)*|[{,]\s*)([A-Za-z0-9_.]+|"[^"]*"|'[^']*')\s*:(?=\s|$)""")
    for n, (line, blk) in enumerate(zip(lines, flags), 1):
        if blk:
            continue
        body, quote = [], None
        for i, ch in enumerate(line):                # cut the comment off
            if quote:
                quote = None if ch == quote else quote
            elif ch in "\"'" and (i == 0 or line[i - 1] in " {[,:"):
                quote = ch
            elif ch == "#" and (i == 0 or line[i - 1] == " "):
                break
            body.append(ch)
        for m in key.finditer("".join(body)):
            k = m.group(1).strip("\"'")
            if is_snake(k):
                out.append((n, k))
    return out


def _files(root):
    shared = root / layout.SHARED_RULINGS
    rules = sorted(layout.rule_files(root) + ([shared] if shared.exists() else []))
    sits = sorted((root / layout.SITUATIONS).glob("*.yaml"))
    return [(p, "rule") for p in rules] + [(p, "situations") for p in sits]


def _old_state(md_path):
    """The ticks and the reviews section of an existing MIGRATION.md, so a re-run keeps them."""
    if not md_path.exists():
        return set(), ""
    text = md_path.read_text(encoding="utf-8")
    ticked = set(re.findall(r"^- \[x\] (.*)$", text, re.M))
    head, sep, tail = text.partition(f"\n## {REVIEWS}\n")
    return ticked, tail if sep else ""


def render(root, residue_by_file, ticked=frozenset(), reviews=""):
    lines = [
        "# Migration residue",
        "",
        "Written by `scripts/rulec/migrate.py` (spec §10.3 step 1). Each item is a key the",
        "mechanical old → new table could not move; it is resolved by hand (plan Tasks 8–15) and",
        "ticked. Line numbers are those of the migrated file.",
        "",
        "`- [ ] L<line> <path in the doc>: <old key> — <why not mechanical>`",
    ]
    for p, residue in residue_by_file:
        lines += ["", f"## {p.relative_to(root).as_posix()}", ""]
        if not residue:
            lines.append("No residue.")
        for r in residue:
            item = f"L{r.line} {r.path}: {r.key} — {r.reason}"
            lines.append(f"- [{'x' if item in ticked else ' '}] {item}")
    lines += ["", f"## {REVIEWS}", ""]
    text = "\n".join(lines) + "\n"
    if reviews.strip():
        text += reviews.lstrip("\n")
    return text


def migrate_tree(root):
    """Migrate every rule and situations file under `root` (`specs/rules/`) in place and
    write `root/MIGRATION.md`. Returns `[(path, [Residue])]`."""
    root = Path(root)
    result = []
    for p, kind in _files(root):
        text = p.read_text(encoding="utf-8")
        new, residue = migrate_text(text, kind)
        if new != text:
            p.write_text(new, encoding="utf-8")
        result.append((p, residue))
    md = root / MIGRATION
    ticked, reviews = _old_state(md)
    md.write_text(render(root, result, ticked, reviews), encoding="utf-8")
    return result


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 1:
        print("usage: python -m rulec.migrate <rules root>", file=sys.stderr)
        return 2
    result = migrate_tree(argv[0])
    n = sum(len(r) for _, r in result)
    print(f"migrated {len(result)} files; {n} residue items in {Path(argv[0]) / MIGRATION}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
