"""The sanitised workspace must not state a withheld rule's *encoding*.

`test_propose.py`'s `test_no_withheld_id_or_name_survives_anywhere_in_the_workspace`
guards the half of contamination that has a token to grep for: the rule id and the
German ability name. This module guards the other half, which has none.

The gap it closes, found by the whole-branch review (finding 1): documentation
written at the end of the branch stated four of the ten golden rules' graded rows
in prose -- a tier ladder as a parenthetical pair of numbers, an encoded row
spelled in schema field names, an opponent-side value quoted as a display string,
a `dice` row's recipient named in English. None of those sentences contains a rule
id or a German ability name, so `_redact_references` left every one of them
standing, and the workspace test passed while the answer key walked in. The
failure that follows is worse than a low score: the next calibration run grades a
copy, reports a *better* Tier 1 than 7/10, and the improvement is attributed to
whichever input fix shipped that month. `docs/rules-pipeline-status.md` §2 and
`test_calibration.py`'s rubric both say byte equality with the golden encoding is
evidence of contamination rather than success -- this is the check that can say so.

What it does
------------
Build the workspace with **every** authored rule withheld -- the strictest
redaction the driver can produce -- and then read what survived, looking for four
shapes in which an encoding has actually been restated on this branch. Each probe
is deliberately narrow, and each is written against a shape that was observed, not
imagined:

1. **A row spelled in schema field names** -- three or more `<tier-1 field> <its
   value>` pairs of one row inside one 60-token window (`modifier target: at,
   scope: combat, value: 2` ... `gmFlag: opponentOnFoot`).
2. **A tier ladder stated as tier-and-value pairs** -- two or more of one rule's
   `(tier, value)` rows, with the tier spelled as a tier ("Stufe II", "tier 2").
3. **A graded number beside its target**, in a passage that still points at a
   rule the agent has to encode (`PA -4`, `BE -1`, `+2 AT`, `-2 ... Ausweichen`).
   Targets are matched in the spellings prose actually uses -- the uppercase DSA
   abbreviation or the German word -- never as the authored lowercase token, so
   the English prepositions *at* and *be* cannot trigger it.
4. **A token that belongs to exactly one authored rule**, appearing in a narrative
   file. `specs/rules/schema.json` and `specs/rules/vocabulary.yaml` are exempt:
   glossing a registered token beside its meaning is their job, and Task 6 fix
   round 2 ruled that those glosses stay ("lose the pointer, keep the mechanics").
   An ADR has no such job, and ADR-0008 is where `defenderShield` came back.
5. **A Swift symbol whose name *is* a row's `target` in English**, quoted in a
   copied file. The Swift itself is never copied, so a `file:line` citation says
   nothing; the symbol name says the field. This was the 2026-09-22 shape: one
   identifier naming a row's target, and one naming its gate, its target and the
   sign of its value in a single camelCase word, both inside a paragraph
   asserting that no field was stated. `CheckDomain`'s cases and the authored
   `scope` tokens are exempt by name -- a domain is *where* a modifier applies,
   not what it modifies, and they contain the same English words.

Probe 3's "points at a rule" test is the load-bearing idea, and it is worth
stating plainly: the reference material is *supposed* to describe mechanics -- that
is what makes it precedent. What it must never do is attach a graded number to a
rule the agent is being asked to encode. Redaction already marks every such
attachment, because it replaced the id or the name with `a withheld rule`; a
chapter rule has no ability name, so its `source.title` counts as an attachment
too. Without that filter the probe fires on `AGENTS.md`'s reach-penalty and
Beengte-Umgebung tables, which describe unauthored Swift constants that happen to
share two numbers with two golden rows -- a false positive, and the kind that
teaches a maintainer to weaken the check.

What it cannot catch
--------------------
**Any leak whose wording shares no tokens with the encoding.** "The mounted relief
is one point, and it eases only weapon-and-shield work" restates a row completely
and matches nothing here. This is a mechanical check against a semantic problem,
and the residual is not small: prose is the format the leak arrives in. It is a
ratchet against the shapes that have already happened, not a proof of isolation.
Three further known gaps, stated so nobody infers coverage from a green run:

- A number written as a word ("two"), a value stated without its target, or a
  target stated without its value, are all invisible.
- **The strongest leak of the 2026-09-22 review was invisible to all five
  probes.** ADR-0007 carried a *negative* row statement -- it told a grader that
  a graded rule has no row of a given kind and where the mechanic lives instead
  -- in plain prose, with no number and no code span. Probe 3 needs a value,
  probe 5 reads code spans only, and the pre-fix file returned zero hits from
  every probe here. A negative statement grades as surely as a positive one,
  because Tier 1 grades a rule's *row set*. Nothing below closes this; it is
  named because it happened, and because a green run on that file meant nothing.
- **Probe 5 knows three targets, not eight.** `TARGET_SYMBOL_WORDS` covers only
  the targets whose English word is not also this app's own navigation and view
  vocabulary. `at`, `ini`, `gs` and `le` are left out on purpose: a probe that
  fired on `attackChoice`, `initiativeRoll` or `CombatAttackViews` would be
  turned off within a week, and a probe that is turned off catches nothing at
  all. A symbol named after one of those four targets is not caught here, and a
  symbol named in German (`belastungPenalty`) is not caught by any probe.
- The two residual leaks `docs/rules-pipeline-status.md` §2 records as judged and
  accepted stay accepted: neither states a number, so neither probe fires. That
  is deliberate, not luck -- see that section before widening anything here.
- The workspace is only one of the two inputs. A brief reaching the model as a
  system prompt is `propose.ids_named_in_agent_briefs`'s job, and the wiring that
  builds the real workspace still has no end-to-end test (review finding 7).
"""
import pathlib
import re
import sqlite3

import pytest
import yaml

from scripts.rules_sync.propose import DEFAULT_DB, REPO_ROOT, prepare_workspace
from tests.rules.test_calibration import TIER1_FIELDS

RULES_DIR = REPO_ROOT / "specs" / "rules"
NON_RULE_FILES = {"schema.json", "SOURCES.yaml", "vocabulary.yaml"}
#: The registries. Their glosses state a token's meaning on purpose.
REGISTRIES = {"schema.json", "vocabulary.yaml"}

PLACEHOLDER = ("a", "withheld", "rule")

#: How prose spells an authored `target`. The authored token is lowercase (`at`,
#: `be`, `pa`); prose uses the DSA abbreviation or the German word, and matching
#: those case-sensitively is what keeps the English words *at* and *be* out.
TARGET_SPELLINGS = {
    "at": ("AT", "Attacke"),
    "pa": ("PA", "Parade"),
    "aw": ("AW", "Ausweichen"),
    "be": ("BE", "Belastung"),
    "ini": ("INI", "Initiative"),
    "gs": ("GS", "Geschwindigkeit"),
    "le": ("LE", "Lebenspunkte"),
    "sinnesschaerfe": ("Sinnesschärfe", "Sinnesschaerfe"),
}

ROMAN = {1: "i", 2: "ii", 3: "iii", 4: "iv", 5: "v"}

#: Probe 5. An authored `target`, and the English word a Swift symbol that
#: implements such a row is named after. Deliberately partial -- the module
#: docstring says which targets are left out and why.
TARGET_SYMBOL_WORDS = {
    "be": ("encumbrance", "encumbered"),
    "aw": ("dodge", "evasion"),
    "pa": ("parry",),
}

#: `CheckDomain`'s cases and the authored `scope` tokens, flattened and
#: lowercased. These carry a target's English word without naming a row: a
#: domain is where a modifier applies, not what it modifies.
DOMAIN_SYMBOLS = {
    "meleeattack", "meleeparry", "meleedodge", "rangedattack",
    "spellcasting", "liturgycasting", "talentcheck", "meleedefense",
}

#: A markdown code span, and an identifier inside one. Probe 5 reads only what
#: is quoted as code: prose naming a mechanic in English is probe 3's business,
#: and this probe is about a *symbol* standing in for a field.
#: Either case to start: Swift type names are PascalCase, and a lowercase-only
#: pattern would have missed a symbol whose *first* word is the target word
#: (`EncumbranceModifier` -> the match starts at `ncumbrance`, which hits
#: nothing). That was a silent miss inside the targets this probe claims.
_CODE_SPAN = re.compile(r"`([^`\n]+)`")
_IDENTIFIER = re.compile(r"[A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z][A-Za-z0-9]*)*")

REMEDY = (
    "A file the agents read states a withheld rule's graded encoding. Cite the "
    "rule file instead of restating it (`see specs/rules/<id>.yaml`, which the "
    "workspace withholds), or name the clause by position and mechanism the way "
    "an authored `note` does. Do not weaken this test to make it pass: the "
    "calibration gate grades exactly these fields, so a sentence that survives "
    "here is a sentence the next run can copy. See the module docstring and "
    "docs/rules-pipeline-review-findings.md finding 1."
)

_WORD = re.compile(r"[+-]?\d+(?:\.\d+)?|[A-Za-zÄÖÜäöüß_][A-Za-zÄÖÜäöüß0-9_]*")
_DASHES = str.maketrans({"−": "-", "–": "-", "—": "-", "‑": "-"})


# ── reading the corpus ───────────────────────────────────────────────────────

def graded_rows() -> dict[str, list[dict]]:
    """Every authored rule's non-reminder effect rows -- exactly what Tier 1 grades."""
    out: dict[str, list[dict]] = {}
    for path in sorted(RULES_DIR.glob("*.yaml")):
        if path.name in NON_RULE_FILES:
            continue
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        rows = [e for e in (doc.get("effects") or [])
                if isinstance(e, dict) and e.get("type") != "reminder"]
        if rows:
            out[path.stem] = rows
    return out


def _german_names(rule_ids) -> dict[str, str]:
    conn = sqlite3.connect(f"file:{DEFAULT_DB}?mode=ro", uri=True)
    try:
        placeholders = ",".join("?" * len(rule_ids))
        return dict(conn.execute(
            "SELECT rule_id, name FROM rules_i18n WHERE locale = 'de-DE' AND "
            f"rule_id IN ({placeholders})", sorted(rule_ids)).fetchall())
    finally:
        conn.close()


def _chapter_titles() -> set[str]:
    """A chapter rule's page title. It has no `rules_i18n` row and so no German
    name to redact, which means a sentence can still point at it by title."""
    titles = set()
    for path in sorted(RULES_DIR.glob("CHAP_*.yaml")):
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        title = (doc.get("source") or {}).get("title")
        if title:
            titles.add(str(title))
    return titles


# ── one file, tokenised once ─────────────────────────────────────────────────

class Passage:
    """A file's text as a token list, with the indexes the probes need."""

    def __init__(self, text: str):
        self.text = text.translate(_DASHES)
        self.tokens, self.starts = [], []
        for m in _WORD.finditer(self.text):
            self.tokens.append(m.group(0))
            self.starts.append(m.start())
        self.lower = [t.lower() for t in self.tokens]
        self.by_lower: dict[str, list[int]] = {}
        self.by_exact: dict[str, list[int]] = {}
        for i, tok in enumerate(self.tokens):
            self.by_lower.setdefault(tok.lower(), []).append(i)
            self.by_exact.setdefault(tok, []).append(i)

    def quote(self, i: int, before: int = 110, after: int = 200) -> str:
        start = self.starts[i] if self.starts else 0
        return " ".join(self.text[max(0, start - before):start + after].split())

    def numbers(self, value) -> list[int]:
        """Where `value` appears, in any spelling prose uses for a modifier:
        `2`, `+2`, `-1` (any dash, normalised on construction)."""
        text = str(value)
        spellings = {text}
        if not text.startswith("-"):
            spellings.add("+" + text)
        return sorted(i for s in spellings for i in self.by_exact.get(s, []))

    def word(self, token: str, *, exact_case: bool = False) -> list[int]:
        return (self.by_exact if exact_case else self.by_lower).get(
            token if exact_case else token.lower(), [])

    def slug(self, slug: str) -> list[int]:
        """Where a camelCase or dotted token appears, in code or in English:
        `defenderShield`, `defender shield`, `defender's shield`."""
        parts = [p.lower() for p in re.findall(r"[A-Za-z][a-z0-9]*|\d+", slug)]
        if not parts:
            return []
        if len(parts) == 1:
            return self.by_lower.get(parts[0], [])
        hits = []
        for i in self.by_lower.get(parts[0], []):
            j, k = i + 1, 1
            while j < len(self.lower) and k < len(parts) and j - i <= len(parts) + 2:
                if self.lower[j] == parts[k]:
                    k += 1
                elif self.lower[j] in ("s", "the", "a", "of", "its"):
                    pass
                else:
                    break
                j += 1
            if k == len(parts):
                hits.append(i)
        return hits

    def points_at_a_rule(self, i: int, span: int = 50, titles=()) -> bool:
        """Does the passage around token `i` still point at a rule the agent has
        to encode? Redaction left `a withheld rule` wherever it removed an id or
        a name; a chapter rule keeps its page title, having no name to remove."""
        lo, hi = max(0, i - span), min(len(self.lower), i + span)
        window = self.lower[lo:hi]
        for k in range(len(window) - 2):
            if tuple(window[k:k + 3]) == PLACEHOLDER:
                return True
        return any(t.lower() in window for t in titles)


# ── the four probes ──────────────────────────────────────────────────────────

def _field_value_pairs(row: dict) -> list[tuple[str, str | None]]:
    """`(field, value)` for the tier-1 fields of one row, `when` flattened into
    its predicates. A boolean predicate (`mounted: true`) is a pair with no value."""
    pairs: list[tuple[str, str | None]] = []
    for field, value in row.items():
        if field not in TIER1_FIELDS:
            continue
        if field == "when":
            for predicate in (value or []):
                if not isinstance(predicate, dict):
                    continue
                for name, arg in predicate.items():
                    if isinstance(arg, bool):
                        pairs.append((name, None))
                    elif isinstance(arg, dict):
                        for key, sub in arg.items():
                            pairs.append((name, str(key)))
                            pairs.append((name, str(sub)))
                    else:
                        pairs.append((name, str(arg)))
        elif isinstance(value, bool):
            continue
        elif isinstance(value, (str, int, float)):
            pairs.append((field, str(value)))
    return pairs


def _spelled_rows(p: Passage, rule_id: str, rows) -> list[tuple[str, str, str]]:
    """Probe 1: a row written out in schema field names."""
    found = []
    for row in rows:
        located: list[tuple[int, str]] = []
        for field, value in _field_value_pairs(row):
            field_at = p.slug(field)
            if value is None:
                located += [(i, field) for i in field_at]
                continue
            value_at = set(p.numbers(value) if re.fullmatch(r"-?\d+(?:\.\d+)?", value)
                           else p.slug(value))
            for i in field_at:
                for j in (i + 1, i + 2, i + 3):
                    if j in value_at:
                        located.append((i, f"{field}={value}"))
                        break
        located.sort()
        for a, (start, _) in enumerate(located):
            group = {name for i, name in located[a:] if i - start <= 60}
            if len(group) >= 3:
                found.append((rule_id, f"row spelled out: {', '.join(sorted(group))}",
                              p.quote(start)))
                break
    return found


def _tier_ladders(p: Passage, rule_id: str, rows) -> list[tuple[str, str, str]]:
    """Probe 2: a ladder given as tier-and-value pairs."""
    ladder = {(r["tier"], r["value"]) for r in rows
              if isinstance(r.get("tier"), int) and isinstance(r.get("value"), int)
              # a rule whose value equals its tier would match any numbered list
              and r["value"] != r["tier"]}
    if len(ladder) < 2:
        return []
    hits: dict[tuple[int, int], int] = {}
    for tier, value in ladder:
        spellings = {str(tier), ROMAN.get(tier, "")}
        for i, token in enumerate(p.lower):
            if token not in spellings or i == 0:
                continue
            if p.lower[i - 1] not in ("stufe", "stufen", "tier", "level"):
                continue
            if any(abs(i - j) <= 4 for j in p.numbers(value)):
                hits.setdefault((tier, value), i)
    if len(hits) < 2:
        return []
    first = min(hits.values())
    stated = ", ".join(f"tier {t} -> {v}" for t, v in sorted(hits))
    return [(rule_id, f"tier ladder stated: {stated}", p.quote(first))]


def _numbers_beside_their_target(p: Passage, rule_id: str, rows, titles
                                 ) -> list[tuple[str, str, str]]:
    """Probe 3: a graded value next to its target, where the passage still points
    at a rule the agent has to encode."""
    found = []
    for row in rows:
        target, value = row.get("target"), row.get("value")
        if target is None or not isinstance(value, (int, float)):
            continue
        for spelling in TARGET_SPELLINGS.get(target, (target,)):
            for i in p.word(spelling, exact_case=True):
                if not any(abs(i - j) <= 2 for j in p.numbers(value)):
                    continue
                if not p.points_at_a_rule(i, titles=titles):
                    continue
                found.append((rule_id, f"{target} {value:+} stated beside a rule "
                                       f"the run withholds", p.quote(i)))
                break
            else:
                continue
            break
    return found


def _rule_unique_tokens(p: Passage, owners: dict[str, str]) -> list[tuple[str, str, str]]:
    """Probe 4: a registered token that belongs to exactly one authored rule."""
    found = []
    for token, rule_id in sorted(owners.items()):
        for i in p.slug(token):
            found.append((rule_id, f"`{token}` names exactly one authored rule's row",
                          p.quote(i)))
            break
    return found


def _symbols_named_after_a_target(text: str, rows_by_rule: dict[str, list[dict]]
                                  ) -> list[tuple[str, str, str]]:
    """Probe 5: a Swift symbol whose name is a withheld row's `target` in English.

    Matched on the *word set* of the identifier, so `encumbrance`,
    `mountedDodgePenalty` and `Hero.dodgeRelief` all hit while `meleeDodge`
    (a `CheckDomain` case) does not.
    """
    wanted: dict[str, set[str]] = {}
    for rule_id, rows in rows_by_rule.items():
        for row in rows:
            for word in TARGET_SYMBOL_WORDS.get(row.get("target"), ()):
                wanted.setdefault(word, set()).add(rule_id)
    if not wanted:
        return []

    found, seen = [], set()
    for span in _CODE_SPAN.finditer(text):
        for m in _IDENTIFIER.finditer(span.group(1)):
            ident = m.group(0)
            if ident.replace(".", "").lower() in DOMAIN_SYMBOLS:
                continue
            words = {w.lower() for w in re.findall(r"[A-Za-z][a-z0-9]*", ident)}
            for word in sorted(words & set(wanted)):
                if (ident, word) in seen:
                    continue
                seen.add((ident, word))
                quote = " ".join(text[max(0, span.start() - 110):span.end() + 110].split())
                for rule_id in sorted(wanted[word]):
                    found.append((rule_id, f"`{ident}` names a withheld row's target in "
                                           f"English (`{word}`)", quote))
    return found


def unique_tokens(rows_by_rule: dict[str, list[dict]]) -> dict[str, str]:
    """Multi-part tokens (camelCase or dotted) used by exactly one rule's rows.
    Single-word values (`combat`, `opponent`, `ambush`) are the shared vocabulary
    and say nothing about which rule is which."""
    owners: dict[str, set[str]] = {}
    for rule_id, rows in rows_by_rule.items():
        for row in rows:
            for _, value in _field_value_pairs(row):
                if value and re.fullmatch(r"[a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+|"
                                          r"[a-z]+[A-Z][A-Za-z0-9]*", value):
                    owners.setdefault(value, set()).add(rule_id)
    return {token: next(iter(rule_ids)) for token, rule_ids in owners.items()
            if len(rule_ids) == 1}


def leaks_in(text: str, rows_by_rule: dict[str, list[dict]], *,
             narrative: bool = True, titles=()) -> list[tuple[str, str, str]]:
    """Every `(rule_id, shape, quote)` this text states about a withheld rule."""
    p = Passage(text)
    found = []
    for rule_id, rows in sorted(rows_by_rule.items()):
        found += _spelled_rows(p, rule_id, rows)
        found += _tier_ladders(p, rule_id, rows)
        found += _numbers_beside_their_target(p, rule_id, rows, titles)
    if narrative:
        found += _rule_unique_tokens(p, unique_tokens(rows_by_rule))
        found += _symbols_named_after_a_target(text, rows_by_rule)
    return found


# ── the guard ────────────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def withheld_workspace(tmp_path_factory) -> pathlib.Path:
    """The workspace with *every* authored rule withheld -- the most redacted
    tree the driver can build, so anything surviving here survives any run."""
    rows = graded_rows()
    names = _german_names(set(rows))
    return prepare_workspace(tmp_path_factory.mktemp("ws") / "workspace", sorted(rows),
                             exclude_names=list(names.values()))


def test_no_workspace_file_states_a_withheld_rules_graded_encoding(withheld_workspace):
    rows_by_rule = graded_rows()
    titles = _chapter_titles()
    offenders = []
    for path in sorted(withheld_workspace.rglob("*")):
        if not path.is_file():
            continue
        for rule_id, shape, quote in leaks_in(
                path.read_text(encoding="utf-8"), rows_by_rule,
                narrative=path.name not in REGISTRIES, titles=titles):
            offenders.append(
                f"{path.relative_to(withheld_workspace)}: {rule_id} -- {shape}\n"
                f"    ...{quote}...")
    assert offenders == [], "\n".join(["", *offenders, "", REMEDY])


def test_the_corpus_still_offers_the_guard_something_to_check(withheld_workspace):
    """A guard that quietly stops covering anything passes forever. Two ways this
    one could: the corpus stops yielding graded rows, or the workspace stops
    carrying the narrative files the leaks were written into."""
    rows_by_rule = graded_rows()
    assert len(rows_by_rule) >= 20, rows_by_rule.keys()
    assert sum(len(r) for r in rows_by_rule.values()) >= 50
    assert unique_tokens(rows_by_rule), "no rule-unique token left to check probe 4 with"
    adrs = list((withheld_workspace / "docs" / "adr").glob("*.md"))
    assert len(adrs) >= 5, adrs
    assert (withheld_workspace / "AGENTS.md").exists()


# ── the guard, against each shape it was written for ─────────────────────────

# A rule that cannot exist in any corpus, spelled the way the agent briefs spell
# their worked example, so this fixture can never be mistaken for real data.
FIXTURE = {"SA_000": [
    {"type": "modifier", "target": "at", "scope": "combat", "value": -7, "tier": 1,
     "when": [{"mounted": True}, {"gmFlag": "torchlightOnly"}]},
    {"type": "modifier", "target": "at", "scope": "combat", "value": -9, "tier": 2},
]}


@pytest.mark.parametrize("shape, text", [
    ("a row in field names",
     "The rule already encodes that shape (`modifier target: at, scope: combat, "
     "value: -7`, gated on `mounted` plus `gmFlag: torchlightOnly`)."),
    ("a ladder in tiers",
     "a withheld rule had the correct ladder (-7 at Stufe I, -9 at Stufe II) all along."),
    ("a value beside its target",
     "as the breakdown already does for a withheld rule (“AT −7”)."),
    ("a rule-unique token",
     "`gmFlag` carries what no predicate can, because a withheld rule fires in "
     "torchlight only."),
])
def test_the_guard_reports_each_shape_it_was_written_for(shape, text):
    assert leaks_in(text, FIXTURE, titles=()), shape


@pytest.mark.parametrize("text", [
    # precedent is supposed to state mechanics; only attaching them to a withheld
    # rule is the leak
    "A modifier carries the side it applies to, because an opponent-side number "
    "is display-only and the GM applies it.",
    "The reach matrix penalises a short weapon against a long one: -4 AT/PA.",
    "1. the first step, 2. the second step, 3. the third step.",
])
def test_the_guard_leaves_precedent_alone(text):
    assert leaks_in(text, FIXTURE, titles=()) == [], text


# Probe 5's own fixture: `at` is outside TARGET_SYMBOL_WORDS by design, so FIXTURE
# above cannot exercise this probe.
SYMBOL_FIXTURE = {"SA_000": [
    {"type": "modifier", "target": "be", "scope": "all", "value": -1},
    {"type": "modifier", "target": "aw", "scope": "combat", "value": -2},
]}


@pytest.mark.parametrize("shape, text", [
    ("a symbol that is the target itself",
     "the hand-written `encumbrance` definition is the one this replaces."),
    ("a symbol carrying gate, target and sign at once",
     "`DefenseModifiers.swift:47`'s `mountedDodgePenalty` is the same constant."),
    ("a dotted symbol",
     "computed by `Hero.dodgeRelief` before the roll."),
    # PascalCase: a Swift *type* name, and the case the first version of this
    # probe missed silently -- its identifier pattern started at `ncumbrance`.
    ("a symbol whose first word is the target",
     "registered by `EncumbranceModifier` at launch."),
])
def test_the_guard_reports_a_swift_symbol_named_after_a_withheld_rows_target(shape, text):
    assert leaks_in(text, SYMBOL_FIXTURE, titles=()), shape


@pytest.mark.parametrize("text", [
    # a domain is where a modifier applies, not what it modifies
    "registered for `meleeDodge` and `meleeParry` only, never `talentCheck`.",
    # a file:line citation is the sanctioned form and must stay usable
    "what it computes is at `Hesindion/Engine/SharedModifiers.swift:27-35`.",
    # prose outside a code span is probe 3's business, not probe 5's
    "The engine has one encumbrance definition and several parry paths.",
])
def test_probe_5_leaves_the_sanctioned_forms_alone(text):
    assert leaks_in(text, SYMBOL_FIXTURE, titles=()) == [], text
