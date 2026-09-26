# Rules engine and rule format — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Paths moved on 2026-09-26 (ADR-0015, "Where the rules live").** The steps below keep the paths
> they were written with. Read them as: `docs/rules-rework/examples/rules/<x>` → `specs/rules/<x>`;
> `docs/rules-rework/examples/{situations,sweeps,checks.yaml,RULINGS.md,MIGRATION.md,conflict-fingerprints.json,README.md}`
> → `specs/rules/…`; `docs/rules-rework/examples/{review,rulefiles,rulings,test_rulefiles}.py` →
> `scripts/rules_review/…`; `docs/sample_heros/` → `specs/heroes/`. The write-ups (`<example>.md`) stay
> in `docs/rules-rework/examples/`. A rule path in `MIGRATION.md` or `RULINGS.md` no longer starts
> with `rules/`.

**Goal:** Build the new rules engine beside the old one: a closed rule vocabulary, the `rulec`
compiler from YAML to JSON, every draft rule and situation moved into that vocabulary, and a
pure Swift engine (evaluator, checks as staged procedures, state over time, the log and its
export) that passes every decided situation of examples 1–22.

**Architecture:** `specs/rules/vocabulary.json` is the one contract. `scripts/rulec/` (Python)
validates `docs/rules-rework/examples/rules/**` and `situations/*.yaml` against it and writes
`build/rules/rules.json` and `build/rules/situations.json`. A local Swift package
`Packages/RulesEngine` (no SwiftData, no UIKit) decodes them and answers
`(Query, Situation) → Breakdown` and `(Action, Situation) → [Event]`; its XCTest harness runs
every compiled situation. Nothing in the app target changes: wiring a domain in is the cut-over
(spec §9), which is follow-up work.

**Tech Stack:** Python 3.11 via `uv` (PyYAML to read, ruamel.yaml for the comment-preserving
migration), Swift 6.3 Swift Package (`swift test` on macOS, XCTest), Make.

**Spec:** `docs/plans/2026-09-24-rules-engine-design.md` (§ numbers below refer to it). The
worked examples in `docs/rules-rework/examples/` and their `README.md` are the acceptance data.

## Global Constraints

- Branch `review/neobrutalism-swiftui-audit`, worktree `review-neobrutalism-swiftui`. Commit
  locally after every task; **do not push**. Commit with an explicit pathspec
  (`git commit <paths> -m …`), because other sessions share the index. Commit messages end
  with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- **One language (§3.1).** Every key, verb, target, fact and reason code is lowerCamelCase and
  spelled the same in YAML, JSON and Swift. Domain terms stay German (`wundschwelle`,
  `belastung`, `kampfrunde`, `ladezeit`), structural words English (`add`, `when`, `lines`).
  No mapping layer anywhere: Swift enum raw values are the JSON strings.
- **The vocabulary is closed.** A new verb, target, fact, payload field or reason code is added
  in one change to `specs/rules/vocabulary.json` **and** `Packages/RulesEngine/Sources/RulesEngine/Vocabulary.swift`,
  with a `rulec` test and (for a verb) an interpreter test. There is never per-rule code: no
  `if rule.id == "SA_…"` anywhere in Python or Swift.
- **Situations are the acceptance data, not something to fit.** An executor must not change a
  situation's `expect` values, or a clause's `text`, to make a test pass. When an expectation
  looks wrong, stop, leave it failing, and report it with the situation id. The one exception
  is a pure re-keying that §10.1 prescribes (e.g. `pa_shield` → `pa(with: shield)`).
- **`reviewed`.** A mechanical re-encoding keeps a rule's `reviewed`. A hand edit that changes
  what a clause *does* (another number, target, condition, or an effect dropped or added) sets
  that rule's `reviewed: null` and adds a line to `docs/rules-rework/examples/MIGRATION.md`.
- **Open rulings apply nothing (§4.7).** Never encode an open ruling's recommended option as if
  it were decided. The 13 open rulings stay open.
- Python runs through `uv`: `uv run --with pyyaml --with ruamel.yaml python …`. The rulec
  tests: `make test-rulec`. The engine tests: `make test-rules-engine` (added in Tasks 6 and 19).
  The review tool tests: `make test-rules-review`.
- The old engine (`Hesindion/Engine/*`, `specs/data/rules-catalog.yaml`, `make rules-db`,
  `make test-ui`) is not touched by this plan, except in Task 36.
- Rounding where a page does not say: **round up** (the shared `round-up` ruling).

**User decisions (already made):**
- "Whole engine at once": the format, the evaluator, the staged checks and state over time come in one plan.
- "Compile to JSON (Rec.)": Python validates and compiles, and Swift reads JSON. The app has no YAML parser.
- "Decided ones pass (Rec.)": the engine is done when every situation that rests only on decided rulings passes. Those resting on an open ruling are reported as *pending*, and `appToday` is never tested.
- "Beside, per domain (Rec.)": the new engine is built and tested beside the old one and is not wired into the app.
- "A: declarative (Rec.)": rules use a closed verb vocabulary on a fixed phase pipeline.
- "don't forget plan to update the rules-to-be-reviewed as well": Tasks 7–16 move the rule files, the situations and the review tooling.
- "same language everywhere, in the engine as well as in the yaml files": §3.1 applies, and the rules are in the constraints above.
- "track there from where the modifiers come (that should also be visible in the UI)": every line carries its provenance (Tasks 20, 21). The UI side is the cut-over gate (§9), which is not part of this plan.
- "the log for that should be easily exportable such that I can use it to improve the app": Task 27.

**Plan decisions** (made here, within the spec):
- The engine is a local Swift package, `Packages/RulesEngine`. It is pure, so `swift test` runs
  it on macOS in seconds without a simulator. The app will link it at the first cut-over.
- `rulec` lives in `scripts/rulec/` and the vocabulary in `specs/rules/vocabulary.json`. The
  compiled JSON goes to `build/rules/`, which is gitignored and rebuilt by `make rules-json`.
  Until the last domain moves over, `make rules-db` (`catalog.py`) keeps serving the old
  engine (spec §9).
- `rulec` resolves `heroFile` (the Optolith JSON) into plain facts at compile time, so the
  Swift package never reads Optolith files.
- The migration is committed in steps: one commit for the mechanical rewrite (Task 7), then one
  per domain group of hand edits (Tasks 8–15). The spec asks for one commit reviewed as a diff;
  `git diff <Task 7 parent>..<Task 16>` gives that diff, and each step is still reviewable on
  its own.

## Phases

| Phase | Tasks | Produces |
|---|---|---|
| 0 | 0 | the pending example work committed, so the migration starts from a clean base |
| A — format and compiler | 1–6 | vocabulary, `rulec` (validate, compile rules and situations), make targets |
| A′ — moving the examples | 7–18 | every rule and situations file in the new format, the review tooling and README moved |
| B — the engine | 19–29 | Swift package: vocabulary, model, evaluator, harness, action layer, procedures, state, log |
| C — green | 30–36 | every decided situation passes, domain by domain in cut-over order (§9) |
| D — documents | 37–38 | ADR, AGENTS.md, CHANGELOG; `rules.db` out of git |

---
## Phase 0

### Task 0: Commit the pending example work

**Goal:** The migration rewrites every rule and situations file, so examples 19–22, the move of
14–18 to Boronmir's 2026-09-24 values, and his dated hero file are committed first. That way the
migration's diff shows only the migration.

**Files:**
- Commit (already on disk): everything under `docs/rules-rework/examples/` that `git status` shows as modified or untracked
- Commit: `docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json` (untracked; the situations' hero file)
- Do **not** commit: `docs/sample_heros/Boronmir Siebenfeld von Greifenfurt.json` (the user's own edit, not ours)

**Acceptance Criteria:**
- [ ] `make test-rules-review` passes: the unit tests pass and `rulings.py --check` reports RULINGS.md current.
- [ ] `git status --porcelain docs/rules-rework/examples` prints nothing.
- [ ] The undated Boronmir file is still modified and uncommitted.

**Verify:** `make test-rules-review && git status --porcelain docs/rules-rework/examples | wc -l` → tests OK, `0`

**Steps:**

- [ ] **Step 1: Check the tree is consistent**

Run: `make test-rules-review`
Expected: `OK` from unittest, then no output from `rulings.py --check` (exit 0). If `--check`
fails because RULINGS.md is stale, run `uv run --with pyyaml python docs/rules-rework/examples/rulings.py`
and re-run.

- [ ] **Step 2: Commit**

```bash
git add docs/rules-rework/examples "docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json"
git commit docs/rules-rework/examples "docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json" -m "docs(rules): examples 19–22 and examples 14–18 on Boronmir's 2026-09-24 values

Example 19 covers Formation, Eisern and Schlechte Eigenschaft. Examples 20–22 probe magic,
ranged combat and talent checks. Examples 14–18 move to his new sheet.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## Phase A — the format and its compiler

### Task 1: The vocabulary

**Goal:** `specs/rules/vocabulary.json` lists every verb with its payload fields and phase,
every target, fact (with owner), value form, reason code, span, pool, event and allowed key. A
Python loader reads it, and tests check that it is consistent with itself.

**Files:**
- Create: `specs/rules/vocabulary.json`
- Create: `scripts/rulec/__init__.py` (empty), `scripts/rulec/vocab.py`
- Test: `scripts/rulec/test_vocab.py`

**Acceptance Criteria:**
- [ ] `vocabulary.json` lists exactly the 22 verbs of spec §4.3, each with `phase`, `fields` (required) and `optional`.
- [ ] Every field type a verb uses is one of the `fieldTypes`.
- [ ] Every fact and fact family has an `owner` from `owners`.
- [ ] Every key in the file is lowerCamelCase (a test walks all keys and all enum strings).
- [ ] `vocab.fact_owner("attr.MU") == "sheet"`, `vocab.fact_owner("gmFact.fromBehind") == "gm"`, `vocab.fact_owner("nope") is None`.

**Verify:** `uv run --with pyyaml python -m unittest discover -s scripts/rulec -t scripts -p 'test_vocab.py' -v` → all OK

**Steps:**

- [ ] **Step 1: Write the failing tests** in `scripts/rulec/test_vocab.py`:

```python
import re
import unittest

from rulec import vocab

CAMEL = re.compile(r"^[a-z][a-zA-Z0-9]*(\.[a-zA-Z0-9]+)*\.?$")
SPEC_VERBS = {"add", "set", "multiply", "cap", "floor", "useLevel", "replace", "suppress",
              "forbid", "require", "limit", "offer", "ask", "tell", "provide", "derive",
              "check", "gain", "cost", "process", "item", "reroll"}


class VocabularyTests(unittest.TestCase):
    def setUp(self):
        self.v = vocab.load()

    def test_the_verbs_are_the_specs_22(self):
        self.assertEqual(set(self.v.verbs), SPEC_VERBS)

    def test_every_verb_has_a_phase_or_runs_on_the_action_layer(self):
        phases = set(self.v.raw["phases"]) | {"data", "player", "action"}
        for name, verb in self.v.verbs.items():
            self.assertIn(verb["phase"], phases, name)

    def test_every_field_type_is_declared(self):
        types = set(self.v.raw["fieldTypes"])
        for name, verb in self.v.verbs.items():
            for f, t in {**verb["fields"], **verb.get("optional", {})}.items():
                self.assertIn(t, types, f"{name}.{f}")

    def test_every_fact_has_an_owner(self):
        owners = set(self.v.raw["owners"])
        for name, fact in {**self.v.raw["facts"], **self.v.raw["factFamilies"]}.items():
            self.assertIn(fact["owner"], owners, name)

    def test_all_names_are_lower_camel_case(self):
        def walk(node, path="$"):
            if isinstance(node, dict):
                for k, v in node.items():
                    self.assertRegex(k, CAMEL, path)
                    walk(v, f"{path}.{k}")
            elif isinstance(node, list):
                for x in node:
                    if isinstance(x, str):
                        self.assertRegex(x, CAMEL, path)
        walk(self.v.raw)

    def test_fact_owner_resolves_families(self):
        self.assertEqual(self.v.fact_owner("attr.MU"), "sheet")
        self.assertEqual(self.v.fact_owner("gmFact.fromBehind"), "gm")
        self.assertEqual(self.v.fact_owner("hero.mounted"), "loadout")
        self.assertIsNone(self.v.fact_owner("nope"))

    def test_targets_accept_prefixes_and_contexts(self):
        self.assertTrue(self.v.is_target("pa"))
        self.assertTrue(self.v.is_target("opponent.pa"))
        self.assertFalse(self.v.is_target("pa_shield"))
        self.assertEqual(self.v.target_contexts("pa"), ["with"])
```

- [ ] **Step 2: Run to see them fail**

Run: `cd scripts && uv run --with pyyaml python -m unittest rulec.test_vocab -v`
Expected: `ModuleNotFoundError: No module named 'rulec.vocab'`

- [ ] **Step 3: Write `specs/rules/vocabulary.json`.** Use 2-space indentation and sort keys
at every level except `phases`, which stays in pipeline order. This is version 1. The
migration (Tasks 7–16) extends it under the Global Constraints; the verb list itself never
changes.

```json
{
  "version": 1,
  "owners": ["sheet", "loadout", "player", "gm", "round", "roll", "derived"],
  "phases": ["base", "level", "add", "lines", "multiply", "cap", "legality"],
  "reasons": ["conditionFalse", "unknownFact", "openRuling", "requirementNotMet", "forbidden",
              "suppressed", "replaced", "overridden", "rulesetOff", "outOfContext"],
  "kinds": ["specialAbility", "advantage", "disadvantage", "condition", "state", "core",
            "equipment", "creature", "talent"],
  "spans": ["action", "round", "fight", "whileFormed", "untilCleared"],
  "pools": ["le", "asp", "kap", "schips", "ammunition"],
  "events": ["paid", "progressed", "completed", "brokenOff", "itemChanged", "gained", "cleared", "logged"],
  "audiences": ["player", "gm", "opponent"],
  "rounding": ["up", "down"],
  "itemFields": ["loaded", "strung", "structurePoints", "damaged"],
  "selectorKinds": ["action", "attack", "defence", "manoeuvre", "choice", "check", "talent", "spell",
                    "loadout", "line", "rule", "lineKind", "dice", "target"],
  "valueForms": ["number", "level", "proportion", "table"],
  "fieldTypes": ["target", "targets", "value", "values", "fact", "condition", "effects", "rule",
                 "selector", "int", "number", "string", "bool", "name", "span", "pool", "pools",
                 "audience", "owner", "rounding", "list", "itemChange", "split", "duration", "data"],
  "ruleKeys": {
    "required": ["id", "name", "kind", "source", "reviewed", "clauses"],
    "optional": ["group", "ruleset", "levels", "options", "provides", "rulings", "agentPass",
                 "catalogId", "passive", "manoeuvre", "techniques"]
  },
  "clauseKeys": {
    "required": ["id", "text"],
    "oneOf": ["effects", "unencoded", "none"],
    "optional": ["name", "page"]
  },
  "effectKeys": ["when", "ruling", "because", "phase"],
  "rulingKeys": ["id", "status", "question", "context", "situations", "options", "recommended",
                 "whyRecommended", "answer", "decided", "appliesTo", "notes"],
  "verbs": {
    "add":      {"phase": "add",      "fields": {"to": "targets", "value": "value"}, "optional": {"per": "fact", "scale": "name"}},
    "set":      {"phase": "add",      "fields": {"to": "targets", "value": "value"}, "optional": {}},
    "multiply": {"phase": "multiply", "fields": {"to": "targets", "by": "number"}, "optional": {"round": "rounding", "line": "selector"}},
    "cap":      {"phase": "cap",      "fields": {"to": "targets"}, "optional": {"min": "value", "max": "value", "over": "selector"}},
    "floor":    {"phase": "cap",      "fields": {"to": "targets", "min": "value"}, "optional": {}},
    "useLevel": {"phase": "level",    "fields": {"rule": "rule"}, "optional": {"as": "value", "lowerBy": "value", "min": "int"}},
    "replace":  {"phase": "lines",    "fields": {"line": "selector", "with": "value"}, "optional": {}},
    "suppress": {"phase": "lines",    "fields": {"line": "selector"}, "optional": {}},
    "forbid":   {"phase": "legality", "fields": {"what": "selector"}, "optional": {"together": "bool"}},
    "require":  {"phase": "legality", "fields": {"that": "condition"}, "optional": {"for": "selector", "enables": "bool"}},
    "limit":    {"phase": "legality", "fields": {"what": "selector", "max": "int", "per": "span"}, "optional": {}},
    "offer":    {"phase": "player",   "fields": {"choice": "name"}, "optional": {"options": "list", "span": "span", "default": "string", "costs": "effects"}},
    "ask":      {"phase": "player",   "fields": {"fact": "fact", "who": "owner"}, "optional": {"options": "list"}},
    "tell":     {"phase": "player",   "fields": {"to": "audience", "text": "string"}, "optional": {}},
    "provide":  {"phase": "data",     "fields": {"name": "name", "value": "data"}, "optional": {}},
    "derive":   {"phase": "base",     "fields": {"to": "target", "sum": "values"}, "optional": {}},
    "check":    {"phase": "action",   "fields": {"of": "selector"}, "optional": {"modifier": "value", "onSuccess": "effects", "onFailure": "effects"}},
    "gain":     {"phase": "action",   "fields": {"rule": "rule"}, "optional": {"levels": "int", "span": "span"}},
    "cost":     {"phase": "action",   "fields": {"pool": "pool", "amount": "value"}, "optional": {"split": "split", "fallThrough": "pools", "onFailure": "number", "every": "duration"}},
    "process":  {"phase": "action",   "fields": {"id": "name", "steps": "value", "advancedBy": "selector"}, "optional": {"completes": "effects", "breaksOff": "condition", "span": "span", "exclusive": "bool"}},
    "item":     {"phase": "action",   "fields": {"instance": "selector", "change": "itemChange"}, "optional": {}},
    "reroll":   {"phase": "action",   "fields": {"die": "selector", "keep": "name"}, "optional": {"max": "int", "per": "span"}}
  },
  "targets": {
    "at": {"contexts": ["with"]}, "pa": {"contexts": ["with"]}, "aw": {"contexts": []},
    "fk": {"contexts": ["with"]}, "tp": {"contexts": ["with"]}, "rs": {"contexts": ["zone"]},
    "ini": {"contexts": []}, "iniBase": {"contexts": []}, "gs": {"contexts": []},
    "leMax": {"contexts": []}, "leCurrent": {"contexts": []}, "aspMax": {"contexts": []},
    "kapMax": {"contexts": []}, "wundschwelle": {"contexts": []}, "sp": {"contexts": []},
    "schips": {"contexts": []}, "belastung": {"contexts": []},
    "regeneration.le": {"contexts": []}, "regeneration.asp": {"contexts": []}, "regeneration.kap": {"contexts": []},
    "check.attribute": {"contexts": ["index"]}, "check.modifier": {"contexts": ["talent", "spell"]},
    "check.fw": {"contexts": ["talent", "spell"]}, "check.fp": {"contexts": []}, "check.qs": {"contexts": []},
    "check.dice": {"contexts": []},
    "spell.cost": {"contexts": [], "scale": true}, "spell.castingTime": {"contexts": [], "scale": true},
    "spell.range": {"contexts": [], "scale": true}, "spell.duration": {"contexts": [], "scale": true},
    "item.ladezeit": {"contexts": ["with"]}, "item.structurePoints": {"contexts": ["with"]}
  },
  "targetPrefixes": ["opponent.", "mount.", "ally."],
  "facts": {
    "level":                     {"owner": "sheet",   "type": "int"},
    "option":                    {"owner": "sheet",   "type": "int"},
    "hero.has":                  {"owner": "sheet",   "type": "ruleId"},
    "hero.mounted":              {"owner": "loadout", "type": "bool"},
    "ally.has":                  {"owner": "player",  "type": "ruleId"},
    "opponent.has":              {"owner": "gm",      "type": "ruleId"},
    "rulesets":                  {"owner": "gm",      "type": "list"},
    "loadout.weapon":            {"owner": "loadout", "type": "string"},
    "loadout.weapon.technique":  {"owner": "loadout", "type": "string"},
    "loadout.weapon.kind":       {"owner": "loadout", "type": "string"},
    "loadout.shield":            {"owner": "loadout", "type": "string"},
    "loadout.shield.size":       {"owner": "loadout", "type": "string"},
    "loadout.reach":             {"owner": "loadout", "type": "string"},
    "loadout.armour":            {"owner": "loadout", "type": "string"},
    "action.attack":             {"owner": "player",  "type": "string"},
    "action.defence":            {"owner": "player",  "type": "string"},
    "action.manoeuvre":          {"owner": "player",  "type": "string"},
    "action.with":               {"owner": "player",  "type": "string"},
    "round.number":              {"owner": "round",   "type": "int"},
    "round.defencesMade":        {"owner": "round",   "type": "int"},
    "round.parries":             {"owner": "round",   "type": "int"},
    "round.dodges":              {"owner": "round",   "type": "int"},
    "round.doubleAttack":        {"owner": "round",   "type": "bool"},
    "clock.minutes":             {"owner": "round",   "type": "int"},
    "hit.zone":                  {"owner": "roll",    "type": "string"},
    "hit.tp":                    {"owner": "roll",    "type": "int"},
    "hit.sp":                    {"owner": "derived", "type": "int"},
    "check.talent":              {"owner": "player",  "type": "string"},
    "check.application":         {"owner": "player",  "type": "string"},
    "check.result":              {"owner": "roll",    "type": "string"}
  },
  "factFamilies": {
    "attr.":     {"owner": "sheet",   "type": "int"},
    "ktw.":      {"owner": "sheet",   "type": "int"},
    "fw.":       {"owner": "sheet",   "type": "int"},
    "mount.":    {"owner": "sheet",   "type": "any"},
    "creature.": {"owner": "sheet",   "type": "any"},
    "item.":     {"owner": "loadout", "type": "any"},
    "choice.":   {"owner": "player",  "type": "any"},
    "spell.":    {"owner": "player",  "type": "any"},
    "gmFact.":   {"owner": "gm",      "type": "any"},
    "opponent.": {"owner": "gm",      "type": "any"},
    "target.":   {"owner": "gm",      "type": "any"},
    "roll.":     {"owner": "roll",    "type": "any"},
    "stage.":    {"owner": "roll",    "type": "any"}
  },
  "comparisons": ["is", "in", "atLeast", "atMost", "above", "below"],
  "situationFileKeys": ["heroFile", "hero", "rulesets", "situations"],
  "situationKeys": ["id", "name", "hero", "loadout", "choose", "gm", "opponent", "ally", "rulesets",
                    "round", "rolls", "sequence", "expect", "appToday", "note"],
  "expectKeys": ["offered", "notOffered", "notApplied", "questions", "legal", "events", "texts",
                 "fp", "qs", "spent", "success"],
  "expectQueryKeys": ["total", "result", "values", "lines", "notApplied", "legal"],
  "lineKeys": ["value", "from", "via", "ruling", "source", "kind"],
  "lineKinds": ["base", "add", "set", "levelAs", "replaced", "multiplied", "capped", "floored",
                "rerolled", "free"]
}
```

(The `"ruleId"` and `"any"` fact types are the only non-field types. Add `"factTypes": ["int", "bool", "string", "list", "ruleId", "any"]`
next to `fieldTypes`, and a test that every fact's `type` is in it.)

- [ ] **Step 4: Write `scripts/rulec/vocab.py`**

```python
"""The rule vocabulary (specs/rules/vocabulary.json): the one contract between the YAML, rulec
and the Swift engine. Read-only; nothing here knows a rule by name."""

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PATH = REPO / "specs" / "rules" / "vocabulary.json"


@dataclass(frozen=True)
class Vocabulary:
    raw: dict
    sha256: str

    @property
    def version(self) -> int:
        return self.raw["version"]

    @property
    def verbs(self) -> dict:
        return self.raw["verbs"]

    def fact_owner(self, name: str) -> str | None:
        if name in self.raw["facts"]:
            return self.raw["facts"][name]["owner"]
        for prefix, fam in self.raw["factFamilies"].items():
            if name.startswith(prefix) and len(name) > len(prefix):
                return fam["owner"]
        return None

    def is_target(self, name: str) -> bool:
        if name in self.raw["targets"]:
            return True
        return any(name.startswith(p) and name[len(p):] in self.raw["targets"]
                   for p in self.raw["targetPrefixes"])

    def target_contexts(self, name: str) -> list[str]:
        for p in [""] + self.raw["targetPrefixes"]:
            if name.startswith(p) and name[len(p):] in self.raw["targets"]:
                return self.raw["targets"][name[len(p):]]["contexts"]
        return []


def load(path: Path = PATH) -> Vocabulary:
    data = path.read_bytes()
    return Vocabulary(raw=json.loads(data), sha256=hashlib.sha256(data).hexdigest())
```

- [ ] **Step 5: Run the tests**

Run: `cd scripts && uv run --with pyyaml python -m unittest rulec.test_vocab -v`
Expected: 8 tests OK (the seven above plus the fact-type test from Step 3).

- [ ] **Step 6: Commit**

```bash
git add specs/rules/vocabulary.json scripts/rulec/__init__.py scripts/rulec/vocab.py scripts/rulec/test_vocab.py
git commit specs/rules scripts/rulec -m "feat(rulec): the rule vocabulary, version 1

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---
### Task 2: Parsing the value forms, targets, conditions and selectors

**Goal:** One module turns the YAML shorthands into the normalized JSON shapes the Swift engine
decodes: the four value forms (§4.5), target strings (§4.4), `when` conditions (§4.6) and
selectors. Each parse error carries the file and line.

**Files:**
- Create: `scripts/rulec/yamlload.py` (a YAML loader that keeps line numbers), `scripts/rulec/errors.py`, `scripts/rulec/forms.py`
- Test: `scripts/rulec/test_forms.py`

**Acceptance Criteria:**
- [ ] `parse_value(2)` → `{"number": 2}`; `"level - 1"` → `{"level": {"times": 1, "plus": -1}}`; `"2 * level"` → `{"level": {"times": 2, "plus": 0}}`; `"-level"` → `{"level": {"times": -1, "plus": 0}}`.
- [ ] `parse_value({"of": "hit.sp", "per": "hero.wundschwelle", "round": "down"})` → a `proportion` with every default filled in (`times` 1, `above` 0, `round`, `min`/`max` null). A `per` that names a fact or target is kept as `{"fact": …}`, and a number as `{"number": …}`.
- [ ] `parse_value("table(trefferzonen.TZ11, hit.zone)")` → `{"table": {"name": "trefferzonen.TZ11", "key": "hit.zone"}}`.
- [ ] `parse_value("ktw + floor(MU / 3)")` raises `RulecError` with the message `value outside the four forms` and the line.
- [ ] `parse_target("pa(with: shield)")` → `{"name": "pa", "with": "shield"}`. `"opponent.at"` → `{"name": "opponent.at"}`. `"pa_shield"` raises `unknown target`. `"aw(with: x)"` raises `aw takes no context with`.
- [ ] `parse_condition({"hero.mounted": True, "round.defencesMade": {"atLeast": 1}})` → `{"all": [{"fact": "hero.mounted", "is": true}, {"fact": "round.defencesMade", "atLeast": 1}]}`. A single fact is not wrapped in `all`. A list value becomes `in`. `any`, `all` and `not` nest. An unknown fact raises `unknown fact`.
- [ ] `parse_selector({"defence": ["pa", "aw"]})` → `{"kind": "defence", "ids": ["pa", "aw"]}`. Two kinds in one selector raise `a selector names exactly one kind`.

**Verify:** `uv run --with pyyaml python -m unittest discover -s scripts/rulec -t scripts -p 'test_forms.py' -v` → all OK

**Steps:**

- [ ] **Step 1: Write the failing tests** (`scripts/rulec/test_forms.py`). Write one test per
acceptance line above, asserting the exact dicts shown there. Error cases use
`with self.assertRaisesRegex(RulecError, "value outside the four forms")`. Also add:

```python
    def test_line_numbers_survive_loading(self):
        doc = yamlload.loads("a: 1\nb:\n  c: [1, 2]\n", "x.yaml")
        self.assertEqual(doc["b"].line, 3)          # 1-based line of the mapping's first key
        self.assertEqual(yamlload.line_of(doc, "b"), 2)
```

- [ ] **Step 2: Run them to see them fail**

Run: `uv run --with pyyaml python -m unittest discover -s scripts/rulec -t scripts -p 'test_forms.py' -v`
Expected: ImportError on `rulec.forms`.

- [ ] **Step 3: Implement `errors.py` and `yamlload.py`**

```python
# errors.py
class RulecError(Exception):
    def __init__(self, message: str, file: str | None = None, line: int | None = None):
        self.message, self.file, self.line = message, file, line
        super().__init__(f"{file or '?'}:{line or '?'}: {message}")
```

```python
# yamlload.py
"""PyYAML's SafeLoader, but every mapping remembers the 1-based line of each of its keys, so
rulec can name the line of any error."""
import yaml


class LineDict(dict):
    line: int = 0
    key_lines: dict

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.key_lines = {}


class _Loader(yaml.SafeLoader):
    pass


def _construct_mapping(loader, node, deep=False):
    loader.flatten_mapping(node)
    m = LineDict()
    m.line = node.start_mark.line + 1
    for k_node, v_node in node.value:
        k = loader.construct_object(k_node, deep=deep)
        m[k] = loader.construct_object(v_node, deep=deep)
        m.key_lines[k] = k_node.start_mark.line + 1
    return m


_Loader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_mapping)


def loads(text: str, name: str):
    return yaml.load(text, Loader=_Loader)


def load(path):
    return loads(path.read_text(encoding="utf-8"), str(path))


def line_of(mapping, key) -> int | None:
    return getattr(mapping, "key_lines", {}).get(key)
```

- [ ] **Step 4: Implement `forms.py`**

```python
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
                 "round": raw.get("round", "up"), "min": raw.get("min"), "max": raw.get("max")}
            if p["round"] not in self.v.raw["rounding"]:
                self.err(f"unknown rounding {p['round']}", line)
            return {"proportion": p}
        self.err("value outside the four forms", line)

    def operand(self, raw, line):
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
```

(`parse_value`, `parse_target`, … in the tests are `Forms(vocab.load()).value`, `.target`, and so on.)

- [ ] **Step 5: Run the tests.** Expected: all OK.

- [ ] **Step 6: Commit**

```bash
git add scripts/rulec/errors.py scripts/rulec/yamlload.py scripts/rulec/forms.py scripts/rulec/test_forms.py
git commit scripts/rulec -m "feat(rulec): parse values, targets, conditions and selectors

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Validating the rule files

**Goal:** `python -m rulec check` loads every rule file and reports each compile error in §11
that concerns rules, naming the file and line. It stops only after collecting all errors, not
at the first.

**Files:**
- Create: `scripts/rulec/rules.py` (load + validate + normalize one rule file and the shared rulings), `scripts/rulec/__main__.py` (CLI: `check`, `build`)
- Test: `scripts/rulec/test_rules.py`, fixtures written to a temp dir inside the tests

**Acceptance Criteria:**
- [ ] Each of these is a separate test, and each produces exactly one `RulecError` whose message starts with the quoted text and whose line is that of the offending key:
  - `unknown verb` (e.g. `raise:`)
  - `unknown key` (on a rule, clause or effect)
  - `unknown target`
  - `unknown fact`
  - `clause needs exactly one of effects, unencoded, none`, both when the clause has none and when it has two
  - `unknown ruling` (an effect's `ruling:` names none in the file, in `rules/rulings.yaml`, or as `<ruleId>.<rulingId>`)
  - `unknown clause in via`
  - `value outside the four forms`
  - `missing field` (a verb without a required field)
  - `wrong type for field` (e.g. `useLevel: { rule: 3 }`)
  - `useLevel names a rule without levels`
  - `useLevel needs exactly one of as, lowerBy`
  - `replace names a clause without effects`
- [ ] Rulings are normalized to qualified ids: `SA_59.schildspalter-shield-bonus` for one in a rule file, `shared.round-up` for one in `rules/rulings.yaml`. Each gets a `status` of `open` or `decided` (open when `answer` is null).
- [ ] Every normalized effect has `verb`, `payload`, `when` (or null), `ruling` (a list), `because`, `phase` (from the verb, or from the effect's own `phase:` key, which must be one of `phases`), and `origin: {rule, clause, index}`.
- [ ] `python -m rulec check --rules <dir>` exits 1 and prints `file:line: message` for every error, then `N errors`. With no errors it prints `ok: R rules, C clauses, E effects` and exits 0.

**Verify:** `uv run --with pyyaml python -m unittest discover -s scripts/rulec -t scripts -p 'test_rules.py' -v` → all OK

**Steps:**

- [ ] **Step 1: Write the failing tests.** Use a helper that writes a minimal valid rule and lets each test break one part:

```python
import tempfile, textwrap, unittest
from pathlib import Path

from rulec import rules, vocab

VALID = """\
id: SA_1
name: Test
kind: specialAbility
source: { url: x, book: y, page: 1, checked: 2026-09-24, hash: null }
reviewed: null
levels: 3
clauses:
  - id: T1
    text: "Eins"
    effects:
      - add: { to: at, value: 2 }
        when: { hero.mounted: true }
  - id: T2
    text: "Zwei"
    none: purchase cost
rulings: []
"""


def check(text, extra=None):
    d = Path(tempfile.mkdtemp())
    (d / "abilities").mkdir()
    (d / "abilities" / "SA_1.yaml").write_text(text)
    (d / "rulings.yaml").write_text("[]\n")
    for name, body in (extra or {}).items():
        (d / name).write_text(body)
    return rules.check(d, vocab.load())          # -> (normalized rules, [RulecError])


class RuleValidationTests(unittest.TestCase):
    def test_a_valid_file_has_no_errors(self):
        book, errors = check(VALID)
        self.assertEqual(errors, [])
        eff = book["SA_1"]["clauses"][0]["effects"][0]
        self.assertEqual(eff["verb"], "add")
        self.assertEqual(eff["payload"], {"to": [{"name": "at"}], "value": {"number": 2}})
        self.assertEqual(eff["phase"], "add")
        self.assertEqual(eff["origin"], {"rule": "SA_1", "clause": "T1", "index": 0})

    def test_unknown_verb(self):
        _, errors = check(VALID.replace("- add: { to: at, value: 2 }", "- raise: { to: at, by: 2 }"))
        self.assertEqual([e.message.split(":")[0] for e in errors], ["unknown verb raise"])
        self.assertEqual(errors[0].line, 11)

    def test_clause_with_two_bodies(self):
        _, errors = check(VALID.replace("    none: purchase cost", "    none: x\n    unencoded: y"))
        self.assertTrue(errors[0].message.startswith("clause needs exactly one of effects, unencoded, none"))
```

Write the other ten error tests the same way: break exactly one thing in `VALID`, then assert
one error with that message prefix and line.

- [ ] **Step 2: Run them to see them fail.** Expected: ImportError on `rulec.rules`.

- [ ] **Step 3: Implement `rules.py`.** Its structure:

```python
"""Load, validate and normalize the rule files (spec §4, §11). Collects every error."""
from pathlib import Path

from . import yamlload
from .errors import RulecError
from .forms import Forms

EFFECT_META = {"when", "ruling", "because", "phase"}


def check(rules_dir: Path, v):
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
        raw[doc.get("id", path.stem)] = (path, doc)
    shared = yamlload.load(rules_dir / "rulings.yaml") or []
    rulings = _collect_rulings(raw, shared)          # {qualified id: {"status", "answer", "question"}}
    book = {}
    for rid, (path, doc) in raw.items():
        book[rid] = _rule(rid, path, doc, v, rulings, raw, errors)
    _cross_checks(book, errors, raw)                 # via, useLevel, replace (need all rules loaded)
    return book, errors
```

`_rule` checks the header keys against `ruleKeys`, and `kind` against `kinds`. For each clause
it checks `clauseKeys`, then the exactly-one-of rule. For each effect it:

1. finds the one key that is a verb; any key that is neither a verb nor in `EFFECT_META` is an
   `unknown key`;
2. checks `fields` and `optional` against the verb's spec;
3. converts each field by its type:
   - `targets` / `target` → `Forms.targets` / `Forms.target`
   - `value` → `Forms.value`
   - `values` → a list of `Forms.value`
   - `condition` → `Forms.condition`
   - `selector` → `Forms.selector`
   - `effects` → a recursive `_effect` list, whose origin index is `"<parent>.<field>.<i>"`
   - `rule` → a str that must be a known rule id (checked in `_cross_checks`)
   - `span` / `pool` / `pools` / `audience` / `owner` / `rounding` → membership in the named list
   - `int` / `number` / `string` / `bool` / `name` / `list` → the Python type
   - `data` → kept as it is
   - `itemChange` → a mapping whose keys are in `itemFields`
   - `split` → `{pools: [...], min: {pool: int}}`
   - `duration` → `{minutes: int}` or `{rounds: int}`
4. qualifies each `ruling` name: first a ruling of this file, then a shared one, then an
   already qualified `RULE.id`.

`_cross_checks` resolves `via` entries (`RULE.CLAUSE`), `useLevel.rule` (which must have
`levels`) and `replace.line` (`kind: line`, whose ids are `RULE.CLAUSE` and must have
`effects`).

Also write the rule's `rulings` into the normalized rule with a qualified `id` and `status`.

- [ ] **Step 4: Implement the `check` subcommand in `__main__.py`**

```python
import argparse, sys
from pathlib import Path

from . import rules, vocab

EXAMPLES = Path(__file__).resolve().parents[2] / "docs" / "rules-rework" / "examples"


def main(argv=None):
    p = argparse.ArgumentParser(prog="rulec")
    sub = p.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("--rules", type=Path, default=EXAMPLES / "rules")
    c.add_argument("--situations", type=Path, default=EXAMPLES / "situations")
    c.add_argument("--only", nargs="*", default=None, help="report errors only for these files")
    b = sub.add_parser("build")
    b.add_argument("--rules", type=Path, default=EXAMPLES / "rules")
    b.add_argument("--situations", type=Path, default=EXAMPLES / "situations")
    b.add_argument("--out", type=Path, required=True)
    a = p.parse_args(argv)
    v = vocab.load()
    book, errors = rules.check(a.rules, v)
    if a.cmd == "check" and a.only is not None:
        errors = [e for e in errors if any(str(e.file).endswith(o) for o in a.only)]
    for e in errors:
        print(e)
    if errors:
        print(f"{len(errors)} errors")
        return 1
    n_cl = sum(len(r["clauses"]) for r in book.values())
    n_ef = sum(len(c.get("effects", [])) for r in book.values() for c in r["clauses"])
    print(f"ok: {len(book)} rules, {n_cl} clauses, {n_ef} effects")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

(Task 4 adds the `build` path and Task 5 adds situations to both commands.)

- [ ] **Step 5: Run the tests.** Expected: all OK. Then run it on the real drafts, which
still use the old format, just to see it runs:
`cd scripts && uv run --with pyyaml python -m rulec check | tail -1` → `N errors` with N in the
hundreds. That is expected; Tasks 7–16 bring it to 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/rulec/rules.py scripts/rulec/__main__.py scripts/rulec/test_rules.py
git commit scripts/rulec -m "feat(rulec): validate the rule files against the vocabulary

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Compiling rules.json and the reach index

**Goal:** `python -m rulec build --out build/rules` writes a deterministic `rules.json`. It holds
the rules, the rulings, a reach index from each target to the effects that can change it, and
the vocabulary's version and hash. The build fails on a clause that can never fire.

**Files:**
- Create: `scripts/rulec/compile.py`
- Modify: `scripts/rulec/__main__.py` (the `build` command)
- Test: `scripts/rulec/test_compile.py`

**Acceptance Criteria:**
- [ ] `rules.json` has these top-level keys: `vocabularyVersion`, `vocabularySha256`, `rules` (a list sorted by id), `rulings` (a list sorted by qualified id, including the shared ones) and `reach` (`{targetName: [{rule, clause, index}]}`, each list sorted).
- [ ] Two builds of the same input give byte-identical files: `json.dumps(sort_keys=True, ensure_ascii=False, indent=1)`, with a trailing newline.
- [ ] Reach is indexed as follows:
  - `add`/`set`/`multiply`/`cap`/`floor` go under each of their `to` names, and `derive` under its `to`.
  - `useLevel` goes under every target the named rule reaches.
  - `replace`/`suppress` go under the targets of the clause the line selector names.
  - `forbid`/`require`/`limit` whose selector is `defence` go under `pa` and/or `aw` (whichever the ids name); `attack` goes under `at`/`fk`.
  - Every other effect (`offer`, `ask`, `tell`, a `require` with no `for`, and all action-layer verbs) goes under the key `"*"`, which every query evaluates.
- [ ] Reachability: a clause with `effects` whose effects are all `provide` that no `table(...)` value anywhere names fails with `clause can never fire: RULE.CLAUSE`. Every other effect is reachable through the index or `"*"`.
- [ ] A test compiles a two-rule fixture and asserts the exact `reach` dict.

**Verify:** `uv run --with pyyaml python -m unittest discover -s scripts/rulec -t scripts -p 'test_compile.py' -v` → all OK

**Steps:**

- [ ] **Step 1: Write the failing tests.** Use a fixture with rule `A`, where `A1` is
`add: { to: [pa, aw], value: -1 }`, and rule `B` with `levels: 3`, where `B1` is
`useLevel: { rule: B, as: "level - 1" }` and `B2` is `add: { to: at, value: level }`. Also
`C1: provide: { name: t.x, value: {a: 1} }`, which nothing reads.

```python
    def test_reach_index(self):
        out = compile_fixture()                 # rules.check + compile.build_rules
        self.assertEqual(out["reach"]["pa"], [{"rule": "A", "clause": "A1", "index": 0}])
        self.assertEqual(out["reach"]["at"], [{"rule": "B", "clause": "B1", "index": 0},
                                               {"rule": "B", "clause": "B2", "index": 0}])

    def test_unread_provide_can_never_fire(self):
        with self.assertRaisesRegex(RulecError, "clause can never fire: C.C1"):
            compile_fixture(with_c=True)

    def test_build_is_deterministic(self):
        a, b = build_twice()
        self.assertEqual(a, b)
        self.assertTrue(a.endswith("\n"))
```

- [ ] **Step 2: Run them to see them fail.**
- [ ] **Step 3: Implement `compile.build_rules(book, v) -> dict` and `compile.write(obj, path)`** as specified above. For `useLevel`, first index all the direct verbs, then add the `useLevel` entries from the rule's own reached targets. That is a two-pass loop, not recursion.
- [ ] **Step 4: Wire `build` in `__main__.py`**: `check` → on errors exit 1 → `compile.write(build_rules(...), out / "rules.json")` → print `wrote build/rules/rules.json (R rules)`.
- [ ] **Step 5: Run the tests.** Expected: all OK.
- [ ] **Step 6: Commit**

```bash
git add scripts/rulec/compile.py scripts/rulec/__main__.py scripts/rulec/test_compile.py
git commit scripts/rulec -m "feat(rulec): compile rules.json with the reach index

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Situations: hero, facts with owners, expectations, pending

**Goal:** `rulec` validates the situations files in the §10.1 format and compiles them to
`situations.json`. It resolves the Optolith hero file into facts, checks that each stated fact
sits in the section of its owner, turns every `expect` query string into a target, and marks a
situation *pending* when an open ruling lies on its path.

**Files:**
- Create: `scripts/rulec/situations.py`, `scripts/rulec/hero.py`
- Modify: `scripts/rulec/__main__.py` (both commands also handle situations; `build` writes `situations.json`)
- Test: `scripts/rulec/test_situations.py`, `scripts/rulec/test_hero.py`

**Acceptance Criteria:**
- [ ] `hero.from_optolith(path)` turns the 2026-09-24 Boronmir file into:
  - `owned["ADV_54"] == {"level": 1}`, and `owned["ADV_25"] == {"level": 2}`
  - `owned["DISADV_37"] == {"level": 1, "option": 2}` (the `sid`)
  - facts `attr.MU = 14`, `attr.KO = 15` and `attr.KK = 14` (ATTR_1..8 → MU, KL, IN, CH, FF, GE, KO, KK)
  - `ktw.CT_5 = 14` and `fw.TAL_23 = 9`, all with owner `sheet`
  - no entries for activatables whose list is empty
- [ ] Merging: the file-level `hero` overrides the hero file, and the situation's `hero` overrides that. The rule-owning maps (`abilities`, `advantages`, `disadvantages`, `conditions`, `states`) are replaced whole. `values`, `attributes`, `techniques` and `talents` are merged key by key.
- [ ] Each section may state only facts of its owner:

  | Section | Owner |
  |---|---|
  | `choose` | player |
  | `gm` | gm (`opponent:` is shorthand for `gm` with the prefix `opponent.`) |
  | `ally` | player (prefix `ally.`) |
  | `round` | round (prefix `round.`) |
  | `loadout` | loadout (prefix `loadout.`) |
  | `rolls` | roll |

  A fact in the wrong section is `fact <name> is owned by <owner>, not <section>`.
- [ ] Each `expect` key is either one of the `expectKeys` or a query string that `Forms.target` accepts; anything else is `unknown expect key`. Each line's `from: RULE.CLAUSE` must exist (`unknown clause in expect`).
- [ ] A situation's `pending` is the sorted list of open rulings (qualified ids) that are either cited by an expected line or `notApplied` entry, or attached to an effect that the reach index lists for a queried target and whose rule the situation owns (or whose kind is `core`).
- [ ] `situations.json`: `{vocabularyVersion, situations: [{id, file, name, owned, facts: [{name, value, owner}], base: {queryString: int}, rolls, sequence, expect: [{query, total?, result?, values?, lines?, notApplied?, legal?}], expectSituation: {offered?, notOffered?, questions?, events?, texts?, fp?, qs?, spent?, success?}, pending}]}`, sorted by file, then by the numeric parts of the id.

**Verify:** `uv run --with pyyaml python -m unittest discover -s scripts/rulec -t scripts -p 'test_*.py' -v` → all OK

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - `test_hero.py` loads the real dated Boronmir file (path from `REPO`) and asserts the values above.
  - `test_situations.py` writes a fixture rule `SA_1` with an open ruling `r1` on the effect of `T1` (`add` to `at`), and a situations file with two situations. One expects `at` with a line `from: SA_1.T1`, so it must be pending with `["SA_1.r1"]`. The other expects only `aw`, so its `pending` is `[]`. Add one test for each error message.

- [ ] **Step 2: Run them to see them fail.**

- [ ] **Step 3: Implement `hero.py`**

```python
import json
from pathlib import Path

ATTR = {"ATTR_1": "MU", "ATTR_2": "KL", "ATTR_3": "IN", "ATTR_4": "CH",
        "ATTR_5": "FF", "ATTR_6": "GE", "ATTR_7": "KO", "ATTR_8": "KK"}


def from_optolith(path: Path) -> dict:
    d = json.loads(path.read_text(encoding="utf-8"))
    owned = {}
    for rid, entries in (d.get("activatable") or {}).items():
        if not entries:
            continue
        e = entries[0]
        owned[rid] = {"level": e.get("tier", 1)}
        if "sid" in e:
            owned[rid]["option"] = e["sid"]
    facts = [{"name": f"attr.{ATTR[a['id']]}", "value": a["value"], "owner": "sheet"}
             for a in d["attr"]["values"]]
    facts += [{"name": f"ktw.{k}", "value": v, "owner": "sheet"} for k, v in sorted(d.get("ct", {}).items())]
    facts += [{"name": f"fw.{k}", "value": v, "owner": "sheet"} for k, v in sorted(d.get("talents", {}).items())]
    return {"id": d["id"], "owned": owned, "facts": facts}
```

- [ ] **Step 4: Implement `situations.py`**: `check(situations_dir, book, reach, v) -> (compiled list, errors)`, following the acceptance criteria. It resolves `heroFile` relative to the situations file. The situation's `hero` keys `abilities`/`advantages`/`disadvantages`/`conditions`/`states` become `owned` entries. Their values are a level (`int`), `{sid: n}` (→ `option`), or `true` (→ level 1). `values` keys are query strings, so run them through `Forms.target` and keep the canonical query string, e.g. `at(with: Rabenschnabel)`.

- [ ] **Step 5: Wire it into `__main__.py`.** `check` reports situation errors too. `build` also writes `situations.json`, and prints `wrote … (S situations, P pending)`.

- [ ] **Step 6: Run all rulec tests.** Expected: all OK.

- [ ] **Step 7: Commit**

```bash
git add scripts/rulec/situations.py scripts/rulec/hero.py scripts/rulec/__main__.py scripts/rulec/test_situations.py scripts/rulec/test_hero.py
git commit scripts/rulec -m "feat(rulec): compile situations with facts, owners and pending rulings

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Make targets

**Goal:** `make test-rulec`, `make rules-check` and `make rules-json` exist and are documented
in the Makefile beside the rules-review targets.

**Files:**
- Modify: `Makefile` (the `.PHONY` line, and a new block after `test-rules-review`)

**Acceptance Criteria:**
- [ ] `make test-rulec` runs every `scripts/rulec/test_*.py`.
- [ ] `make rules-check` runs `python -m rulec check` and exits with its status.
- [ ] `make rules-json` writes `build/rules/rules.json` and `build/rules/situations.json` (`build/` is already gitignored).

**Verify:** `make test-rulec` → OK

**Steps:**

- [ ] **Step 1: Add the targets**

```make
# The new rule format's compiler (docs/plans/2026-09-24-rules-engine-design.md). Validates the
# rule and situation files against specs/rules/vocabulary.json and compiles them to JSON for
# the Swift engine (Packages/RulesEngine).
RULEC = cd scripts && uv run --with pyyaml python -m rulec

test-rulec:
	uv run --with pyyaml python -m unittest discover -s scripts/rulec -t scripts -p 'test_*.py' -v

rules-check:
	$(RULEC) check

rules-json:
	$(RULEC) build --out ../build/rules
```

Also add `test-rulec rules-check rules-json` to `.PHONY`.

- [ ] **Step 2: Run** `make test-rulec`. Expected: OK. (`make rules-check` still fails on the drafts until Task 16.)
- [ ] **Step 3: Commit**

```bash
git commit Makefile -m "build: make test-rulec, rules-check and rules-json

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---
## Phase A′ — moving the examples into the format

### Task 7: `migrate.py` and the mechanical rewrite

**Goal:** A script rewrites every rule and situations file with a fixed old→new table while
keeping comments and layout, and lists everything it cannot map in `MIGRATION.md`. Its output
is committed on its own, so that the diff is the mechanical part only.

**Files:**
- Create: `scripts/rulec/migrate.py`, `scripts/rulec/test_migrate.py`
- Create (generated): `docs/rules-rework/examples/MIGRATION.md`
- Modify (generated): every `docs/rules-rework/examples/rules/**/*.yaml` and `situations/*.yaml`

**Acceptance Criteria:**
- [ ] The script uses ruamel.yaml in round-trip mode (`typ="rt"`, `preserve_quotes=True`, `width=100`, mapping indent 2, sequence indent 4, offset 2), so comments survive. A test migrates a snippet with a `# FORMAT:` comment on an effect and finds the comment in the output.
- [ ] It applies exactly the tables in "Mechanical map" below. A test covers each row.
- [ ] Afterwards, the only snake_case keys left in any file are residue that `MIGRATION.md` lists. Keys that are rule ids (`^[A-Z]+_\d+$`, `^ITEMTPL_\d+$`) and prose values are never touched.
- [ ] `MIGRATION.md` has one section per file. Each section has a checkbox per residue item (`- [ ] L<line> <path in the doc>: <old key> — <why not mechanical>`), and a closing section, "Reviews reset by hand edits", that is empty for now.
- [ ] The script is idempotent: running it twice leaves the files unchanged the second time. A test checks this.
- [ ] Every rule's `reviewed` value is byte-identical before and after. A test checks this over the real files, using a copy in a temp dir.

**Verify:** `uv run --with pyyaml --with ruamel.yaml python -m unittest discover -s scripts/rulec -t scripts -p 'test_migrate.py' -v` → OK; then `git diff --stat docs/rules-rework/examples | tail -1` shows ~90 files changed

**Mechanical map** (the right-hand column of spec §4.3 where the payload maps one to one; everything else is residue):

| Where | Old | New |
|---|---|---|
| rule | `catalog_id`, `agent_pass`, `tiers` | `catalogId`, `agentPass`, `levels` |
| ruling | `why_recommended`, `applies_to` | `whyRecommended`, `appliesTo` |
| clause | `effects: none` + `why: X` | `none: X` |
| clause | `effects: [...]` + `why: X` | `effects: [...]` with `# why: X` as a comment above `effects` |
| effect | `apply_level: { rule: R, level: L }` | `useLevel: { rule: R, as: L }` |
| effect | `halve: { value: T, round: R }` | `multiply: { to: T, by: 0.5, round: R }` |
| effect | `shift: { param: P, steps: N, table: S }` | `add: { to: spell.P, value: N, scale: S }` |
| effect | `opponent_add: { to: T, value: V }` (no other keys) | `add: { to: opponent.T, value: V }` |
| effect | `remove: { line: L }` | `suppress: { line: { line: L } }` |
| effect | `requires: { any_of: [...] }` / `requires: { <fact>: v, ... }` (only fact keys) | `require: { that: { any: [...] } }` / `require: { that: { <fact>: v, ... } }` |
| effect | `excludes: { manoeuvre: M }` | `forbid: { what: { manoeuvre: M }, together: true }` |
| effect | `tell: { opponent: X }` / `{ hero: X }` / `{ player: X }` | `tell: { to: opponent, text: X }` / `to: player` / `to: player` |
| effect | `provides: { k1: v1, k2: v2 }` | one `provide: { name: k, value: v }` effect per key; each copy keeps `when`, `ruling` and `because` |
| effect | `charge: { amount: A, pool: P }` (only these) | `cost: { pool: P, amount: A }` |
| effect | `gain: { state: S }` (only this) | `gain: { rule: S }` |
| effect | `unless: C` (no `when`) | `when: { not: C }` |
| effect | `set: { to: T, value: V }` where T is a target | unchanged |
| `when` | `gm.fact: X` | `gmFact.X: true` |
| `when` | `choice: X` + `bonus: B` | `choice.X: true` + `choice.X.bonus: B` |
| `when` | `choice: X` | `choice.X: true` |
| `when` | `manoeuvre`, `attack`, `defence` | `action.manoeuvre`, `action.attack`, `action.defence` |
| `when` | `roll.with`, `roll.with.shieldSize`, `roll.with.reach` | `action.with`, `loadout.shield.size`, `loadout.reach` |
| `when` | `weapon.technique`, `loadout.technique` | `loadout.weapon.technique` |
| `when` | `ruleset: X` | `rulesets: X` |
| `when` | `check: X` | `check.talent: X` |
| `when` | `any_of`, `all_of` | `any`, `all` |
| situations file | `hero_file`, `base_hero` | `heroFile`, `hero` |
| situation | `app_today` | `appToday` |
| situation | `choose: { X: true, bonus: B }` (X not a known fact) | `choose: { choice.X: true, choice.X.bonus: B }` |
| expect | `not_offered`, `not_applied`, `ini_base`, `le_max` | `notOffered`, `notApplied`, `iniBase`, `leMax` |
| expect | `pa_shield`, `shield_parry`, `parry_shield` | `pa(with: shield)` |
| expect | `pa_weapon` | `pa(with: weapon)` |
| expect | `parry_main`, `parry_off`, `attack_main`, `attack_off` | `pa(with: mainHand)`, `pa(with: offHand)`, `at(with: mainHand)`, `at(with: offHand)` |
| any key | other `a_b_c` keys that are not rule ids | **residue**, never guessed |

**Steps:**

- [ ] **Step 1: Write the failing tests**: one per table row, each migrating a small YAML string with `migrate.migrate_text(text, kind="rule"|"situations")` and comparing to the expected text; plus the comment, idempotence and `reviewed` tests.

```python
    def test_effects_none_with_why_becomes_none(self):
        src = "clauses:\n  - id: X1\n    text: t\n    effects: none\n    why: purchase cost\n"
        out, residue = migrate.migrate_text(src, kind="rule")
        self.assertIn("    none: purchase cost\n", out)
        self.assertNotIn("effects", out)
        self.assertEqual(residue, [])

    def test_unknown_verb_is_residue_not_guessed(self):
        src = "clauses:\n  - id: X1\n    text: t\n    effects:\n      - raise: { line: A.B, by: 1 }\n"
        out, residue = migrate.migrate_text(src, kind="rule")
        self.assertIn("raise:", out)
        self.assertEqual([(r.key, r.reason) for r in residue], [("raise", "no one-to-one verb")])
```

- [ ] **Step 2: Run them to see them fail.**
- [ ] **Step 3: Implement `migrate.py`.** It has three parts:
  - `migrate_text(text, kind) -> (new_text, [Residue(line, path, key, reason)])`
  - `migrate_tree(examples_dir)`, which walks the rule and situations files, writes the files, and writes `MIGRATION.md`
  - `main()`

  Each table row is a small function over ruamel's `CommentedMap`. To rename a key, use
  `m.insert(m.keys().index(old), new, m.pop(old))`, so that the key keeps its position; carry
  the comment over with `m.ca.items[new] = m.ca.items.pop(old)` when there is one.

- [ ] **Step 4: Run the tests.** Expected: all OK.
- [ ] **Step 5: Run it on the examples and look at the result**

```bash
cd scripts && uv run --with pyyaml --with ruamel.yaml python -m rulec.migrate ../docs/rules-rework/examples
git diff --stat ../docs/rules-rework/examples | tail -1
grep -c '^- \[ \]' ../docs/rules-rework/examples/MIGRATION.md
```

Read `git diff` for three files: `SA_862.yaml`, `kampfwerte.yaml` and `situations/boronmir-neu.yaml`.
Check that the comments and the folded `text: >` blocks are unchanged, and that only mapped keys
moved. If ruamel reflowed a folded block, set `yaml.width = 4096` and re-run from a clean
checkout (`git checkout -- docs/rules-rework/examples`).

- [ ] **Step 6: Commit the tool, then the rewrite, as two commits**

```bash
git add scripts/rulec/migrate.py scripts/rulec/test_migrate.py
git commit scripts/rulec/migrate.py scripts/rulec/test_migrate.py -m "feat(rulec): migrate.py, the old→new key table

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
git add docs/rules-rework/examples
git commit docs/rules-rework/examples -m "docs(rules): mechanical move of the draft files to the engine's vocabulary

Generated by scripts/rulec/migrate.py. MIGRATION.md lists what is left for hand edits.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Tasks 8–15: the hand edits, one domain group each

Each of these eight tasks has the same shape. They differ only in their files, listed per
task below. Rule paths are relative to `docs/rules-rework/examples/rules/` and situations to
`docs/rules-rework/examples/situations/`, all with the `.yaml` extension. Before starting one, read **Appendix A: Residue guide** at the end of this plan.

**Goal (each task):** Every residue item in `MIGRATION.md` for the group's files is resolved.
`make rules-check` reports no error in those files, and every clause keeps its verbatim text.

**Acceptance Criteria (each task):**
- [ ] `cd scripts && uv run --with pyyaml python -m rulec check --only <each file of the group>` prints `ok` (the filter hides errors in other groups' files).
- [ ] Every residue checkbox of the group's files in `MIGRATION.md` is ticked.
- [ ] No clause `text` and no `expect` value changed: `git diff` on the group's files shows no `-` line inside a `text:` block or on an expected number. Re-keying under §10.1 is allowed.
- [ ] Every rule whose clause meaning changed has `reviewed: null`, and has a line under "Reviews reset by hand edits" in `MIGRATION.md`, in the form `RULE.CLAUSE: what changed`.
- [ ] Every vocabulary addition sits in `specs/rules/vocabulary.json` with a `rulec` test, and is listed in the task's commit message.
- [ ] A line that cites a rule with no rule file (e.g. `COND_2`, `COND_4`, `STATE_2`, `GRW_zustandsbegrenzung`, `bewusstlos`, `handlungsunfaehig`) is handled one of two ways:
  - Re-key it to the clause that holds the rule, e.g. `zustaende.Z3`.
  - Otherwise, draft the rule file from its wiki page by README "Layout of the draft rule files": verbatim clauses, `reviewed: null`, `source.checked` today. List it in the commit message as newly drafted.

  Pseudo-references such as `from: KO`, `from: derived` or `from: the` become `source: sheet` lines with no `from`, since they are base values.

**Verify (each task):** `make test-rulec && cd scripts && uv run --with pyyaml python -m rulec check --only <files>` → `ok: …`

**Steps (each task):**

- [ ] **Step 1:** List the group's residue: `grep -n -A200 '^## <file>' docs/rules-rework/examples/MIGRATION.md`, one file at a time.
- [ ] **Step 2:** For each item, find its pattern in Appendix A and re-encode it. When no pattern fits, add a vocabulary entry: a new target, fact, payload field or selector kind is allowed. **A new verb is not allowed**: the verb list is fixed (spec §4.3). If an item truly fits no verb, stop and report it.
- [ ] **Step 3:** Run `rulec check --only …` and fix until `ok`.
- [ ] **Step 4:** Walk each situation of the group and compare it with its old version (`git show HEAD~N:<path>`): same queries, same numbers, same cited clauses.
- [ ] **Step 5:** Commit the group's files, `MIGRATION.md`, and the vocabulary and tests if they changed:

```bash
git commit docs/rules-rework/examples specs/rules scripts/rulec -m "docs(rules): hand-migrate <group>

Vocabulary: <additions or 'none'>. Reviews reset: <RULE.CLAUSE list or 'none'>.
Newly drafted: <rule files or 'none'>.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

#### Task 8: Group 1, the sheet and derived values

**Files:**
- Rules: `core/kampfwerte`, `core/at-pa-modifikatoren`, `core/lebensenergie`, `core/regeneration`, `core/ruestung-und-belastung`, `core/schicksalspunkte`, `core/schilde`, `core/waffeneigenschaften`, `conditions/COND_1`, `abilities/SA_41`, `advantages/ADV_25`, `advantages/ADV_44`, `advantages/ADV_54`, `disadvantages/DISADV_57`, `equipment/ITEMTPL_19`, `equipment/ITEMTPL_29`, `equipment/ITEMTPL_35`
- Situations: `kampfwerte`, `lebensenergie`, `belastung`, `verweichlicht`

This group's `derive` encodings are the basis for the others. Use Appendix A §A.1 for
`kampfwerte` KW1–KW3, the LE base and the Wundschwelle.

#### Task 9: Group 2, manoeuvres and defences

**Files:**
- Rules: `core/mehrfache-verteidigung`, `core/kampfsonderfertigkeiten`, `core/passierschlag`, `core/beidhaendiger-kampf`, `abilities/SA_42`, `advantages/ADV_5`, `abilities/SA_48`, `abilities/SA_51`, `abilities/SA_65`, `abilities/SA_66`, `abilities/SA_67`, `abilities/SA_59`, `abilities/SA_40`, `abilities/SA_884`, `abilities/SA_862`, `abilities/SA_923`, `abilities/SA_62`, `disadvantages/DISADV_37`
- Situations: `mehrfache-verteidigung`, `finte`, `wuchtschlag`, `beidhaendiger-kampf`, `kampfreflexe`, `sturmangriff`, `boronmir-sf`, `boronmir-neu`

#### Task 10: Group 3, the fighting situation (reach, mounted, position, size)

**Files:**
- Rules: `core/reichweite`, `core/reiterkampf`, `core/vorteilhafte-position`, `core/angriff-von-hinten`, `core/beengte-umgebung`, `core/groessenkategorie`, `abilities/SA_43`, `abilities/SA_661`, `abilities/SA_152`, `abilities/SA_172`, `abilities/SA_173`, `creatures/maechtiger-schlag`, `creatures/ruhiges-temperament`, `creatures/svellttaler-kaltblut`
- Situations: `reichweite`, `reiterkampf`, `kampfsituationen`, `kupperus-und-waffen`

#### Task 11: Group 4, damage and hit zones

**Files:**
- Rules: `core/schaden`, `core/trefferzonen`, `core/trefferzonen-ruestungsschutz`, `abilities/SA_160`, `conditions/STATE_13`
- Situations: `trefferzonen`

The consequence chain TP → RS → SP → Wundschwelle → Wundeffekt check is encoded as in Appendix A §A.5.

#### Task 12: Group 5, Zustände

**Files:**
- Rules: `conditions/COND_6`, `conditions/STATE_10`, `core/zustaende`, `advantages/ADV_49`, `advantages/ADV_75`
- Situations: `schmerz`, `liegend`

#### Task 13: Group 6, talent checks

**Files:**
- Rules: `core/fertigkeitsproben`, `advantages/ADV_4`, `abilities/SA_9`
- Situations: `probe-fertigkeiten`

These are the staged checks of spec §6 (Appendix A §A.4).

#### Task 14: Group 7, magic

**Files:**
- Rules: `core/zaubermodifikationen`, `abilities/SA_74`
- Situations: `probe-magie`

Costs, splits and the fall-through are in Appendix A §A.6.

#### Task 15: Group 8, ranged combat

**Files:**
- Rules: `core/fernkampf`, `core/ladezeiten`, `abilities/SA_60`, `abilities/SA_161`
- Situations: `probe-fernkampf`

Processes and item state are in Appendix A §A.7. The page on länger dauernde Handlungen was
not found (spec §14). Before fixing the `process` payload, search for it once more:

```bash
curl -s https://dsa.ulisses-regelwiki.de/ | grep -io 'l[äa]nger[^"<]*handlung[^"<]*' | sort -u
```

If the page is found, cite it in `ladezeiten.yaml`'s `source.also`. If it is not, keep the
payload to what Zielen and Laden need (steps, what advances them, what breaks them off). Add an
open ruling `ladezeiten.laengere-handlungen`, which asks whether any other action continues
across rounds.

---

### Task 16: Everything loads

**Goal:** The whole example set compiles with no errors. This proves that the vocabulary covers
all 22 examples (spec §10.3 step 2).

**Files:**
- Modify: `docs/rules-rework/examples/MIGRATION.md` (final counts)

**Acceptance Criteria:**
- [ ] `make rules-check` prints `ok: R rules, C clauses, E effects` and exits 0.
- [ ] `make rules-json` writes both files. `situations.json` holds 303 or more situations, and the number of pending ones is printed.
- [ ] `grep -c '^- \[ \]' docs/rules-rework/examples/MIGRATION.md` → `0`.
- [ ] A new test, `test_examples.py`, runs `rules.check` and `situations.check` over the real examples and asserts no errors. From here on, `make test-rulec` guards the migrated files.
- [ ] `grep -rnE '^\s*[a-z]+_[a-z_]+:' docs/rules-rework/examples/rules docs/rules-rework/examples/situations` finds no key, only prose.

**Verify:** `make test-rulec && make rules-json` → OK, `wrote … (S situations, P pending)`

**Steps:**
- [ ] **Step 1:** Run `make rules-check` and fix what is left. Errors that cross groups are usually a `via` or `replace` naming a clause that another group renamed.
- [ ] **Step 2:** Add `scripts/rulec/test_examples.py`:

```python
import unittest
from rulec import rules, situations, compile, vocab
from rulec.__main__ import EXAMPLES


class TheExamplesCompile(unittest.TestCase):
    def test_no_errors(self):
        v = vocab.load()
        book, errors = rules.check(EXAMPLES / "rules", v)
        self.assertEqual([str(e) for e in errors], [])
        out = compile.build_rules(book, v)
        sits, serrors = situations.check(EXAMPLES / "situations", book, out["reach"], v)
        self.assertEqual([str(e) for e in serrors], [])
        self.assertGreaterEqual(len(sits), 303)
```

- [ ] **Step 3:** Record the counts in the head of `MIGRATION.md`: rules, clauses, effects, situations, pending, and vocabulary additions per group.
- [ ] **Step 4: Commit**

```bash
git add scripts/rulec/test_examples.py
git commit scripts/rulec/test_examples.py docs/rules-rework/examples/MIGRATION.md -m "test(rulec): every example rule and situation compiles

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 17: The review tooling reads the new keys

**Goal:** `make rules-review`, `rules-sweep`, `rules-queue` and `test-rules-review` work on the
migrated files. The three edits the tool makes (`reviewed`, `answer`, `agentPass`) still write
one-hunk diffs.

**Files:**
- Modify: `docs/rules-rework/examples/rulefiles.py`: `agent_pass` → `agentPass` (the key read at l.88 and written at l.424/431/435), `app_today` → `appToday` (l.61, 66, 225, 234). A clause now counts as encoded when it has `effects`, and as "nothing to do" when it has `none` or `unencoded`, where before it had `effects: none`. See `Clause.encoded` at l.34.
- Modify: `docs/rules-rework/examples/review.py`: `why_recommended` → `whyRecommended` (l.202–203, 299–300); `app_today` → `appToday` (l.217); clause display shows `none:` and `unencoded:` reasons
- Modify: `docs/rules-rework/examples/rulings.py`: `why_recommended` → `whyRecommended` (l.95–96)
- Modify: `docs/rules-rework/examples/test_rulefiles.py`: fixtures in the new format
- Modify: `docs/rules-rework/examples/sweeps/boronmir.yaml`: only if a key in it changed; the sweep keys `skip`, `rules`, `hero` stay

**Acceptance Criteria:**
- [ ] `make test-rules-review` passes.
- [ ] `make rules-sweep SWEEP=boronmir` lists the same rules, with 0 not drafted, as it did before the migration. For the baseline, unpack the examples at Task 7's parent commit into the scratchpad (`git archive <sha> docs/rules-rework/examples | tar -x -C <scratchpad>/before`) and run its `review.py --sweep boronmir --list` there. Diff the two rule lists.
- [ ] A test marks a rule reviewed, answers a ruling and sets `agentPass` on a migrated fixture. Each edit gives a one-hunk diff, and the file still passes `rulec check`.

**Verify:** `make test-rules-review && make rules-sweep SWEEP=boronmir | tail -3` → OK, and the same summary line as before

**Steps:**
- [ ] **Step 1:** Update `test_rulefiles.py`'s fixtures to the new keys. Add the one-hunk-and-still-compiles test, which calls `rulec.rules.check` on a temp dir holding the edited file. Run it and see it fail.
- [ ] **Step 2:** Make the renames listed under Files.
- [ ] **Step 3:** Run `make test-rules-review` and the sweep. Compare the sweep with its pre-migration output.
- [ ] **Step 4: Commit**

```bash
git commit docs/rules-rework/examples/rulefiles.py docs/rules-rework/examples/review.py docs/rules-rework/examples/rulings.py docs/rules-rework/examples/test_rulefiles.py docs/rules-rework/examples/sweeps -m "feat(rules-review): read and write the engine's vocabulary

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 18: The examples README and RULINGS.md

**Goal:** The examples README describes the new format, so a reviewer and the agent pass write
new rules in it. RULINGS.md is regenerated.

**Files:**
- Modify: `docs/rules-rework/examples/README.md`: section "Layout of the draft rule files" (l.21–41) rewritten; "What waits for an agent" (l.109–124) says to run `make rules-check` after every edit
- Modify (generated): `docs/rules-rework/examples/RULINGS.md`

**Acceptance Criteria:**
- [ ] The layout section shows spec §4.1's file header, and the rule that a clause has exactly one of `effects` / `unencoded` / `none`. It gives the verb table of §4.3 with one example each, taken from a real migrated clause (e.g. `SA_862.F2` for `add`, `COND_6` for `useLevel`). It covers the four value forms, facts and their owners, and the rule that the vocabulary is closed. It links `specs/rules/vocabulary.json` and the design.
- [ ] The line "DRAFT FORMAT — see ../../README.md" at the top of every file still points at a section that exists.
- [ ] `make test-rules-review` passes (`rulings.py --check` included).

**Verify:** `make test-rules-review` → OK

**Steps:**
- [ ] **Step 1:** Rewrite the two sections, then regenerate RULINGS.md: `uv run --with pyyaml python docs/rules-rework/examples/rulings.py`.
- [ ] **Step 2:** Run `make test-rules-review`.
- [ ] **Step 3: Commit**

```bash
git commit docs/rules-rework/examples/README.md docs/rules-rework/examples/RULINGS.md -m "docs(rules): the examples README describes the engine's rule format

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---
## Phase B — the engine (Swift package)

All types below are `public` and `Sendable`, and value types unless stated otherwise. The
package imports only Foundation.

### Task 19: The package and its vocabulary

**Goal:** `Packages/RulesEngine` builds and tests with `swift test`. `Vocabulary.swift` holds
the vocabulary as Swift enums whose raw values are the JSON strings, and a test holds it equal
to `specs/rules/vocabulary.json`.

**Files:**
- Create: `Packages/RulesEngine/Package.swift`
- Create: `Packages/RulesEngine/Sources/RulesEngine/Vocabulary.swift`
- Test: `Packages/RulesEngine/Tests/RulesEngineTests/VocabularyTests.swift`, `Packages/RulesEngine/Tests/RulesEngineTests/Repo.swift`
- Modify: `Makefile` (`test-rules-engine`, `.PHONY`)

**Acceptance Criteria:**
- [ ] `swift test --package-path Packages/RulesEngine` runs and passes.
- [ ] `Verb.allCases` has 22 cases whose raw values equal the JSON `verbs` keys. `Owner`, `ReasonCode`, `RuleKind`, `Span`, `Pool`, `EventKind`, `Audience`, `LineKind` and `Phase` each equal their JSON list. `Vocabulary.version` equals the JSON's `version`.
- [ ] `Vocabulary.targets`, `targetPrefixes`, `facts` (name → owner) and `factFamilies` equal the JSON.
- [ ] `make test-rules-engine` runs `make rules-json`, then `swift test`.

**Verify:** `make test-rules-engine` → `Test Suite 'All tests' passed`

**Steps:**

- [ ] **Step 1: Write the package manifest**

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RulesEngine",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "RulesEngine", targets: ["RulesEngine"])],
    targets: [
        .target(name: "RulesEngine"),
        .testTarget(name: "RulesEngineTests", dependencies: ["RulesEngine"]),
    ]
)
```

- [ ] **Step 2: Write the failing test**

```swift
// Repo.swift
import Foundation

enum Repo {
    /// Tests/RulesEngineTests/Repo.swift → repository root.
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static func url(_ path: String) -> URL { root.appending(path: path) }
}
```

```swift
// VocabularyTests.swift
import XCTest
@testable import RulesEngine

final class VocabularyTests: XCTestCase {
    private func json() throws -> [String: Any] {
        let data = try Data(contentsOf: Repo.url("specs/rules/vocabulary.json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testTheEnumsEqualTheJSON() throws {
        let v = try json()
        XCTAssertEqual(v["version"] as? Int, Vocabulary.version)
        XCTAssertEqual(Set((v["verbs"] as! [String: Any]).keys), Set(Verb.allCases.map(\.rawValue)))
        XCTAssertEqual(v["owners"] as? [String], Owner.allCases.map(\.rawValue))
        XCTAssertEqual(v["phases"] as? [String], Phase.allCases.map(\.rawValue))
        XCTAssertEqual(v["reasons"] as? [String], ReasonCode.allCases.map(\.rawValue))
        XCTAssertEqual(v["kinds"] as? [String], RuleKind.allCases.map(\.rawValue))
        XCTAssertEqual(v["spans"] as? [String], Span.allCases.map(\.rawValue))
        XCTAssertEqual(v["pools"] as? [String], Pool.allCases.map(\.rawValue))
        XCTAssertEqual(v["events"] as? [String], EventKind.allCases.map(\.rawValue))
        XCTAssertEqual(v["audiences"] as? [String], Audience.allCases.map(\.rawValue))
        XCTAssertEqual(v["lineKinds"] as? [String], LineKind.allCases.map(\.rawValue))
        XCTAssertEqual(Set((v["targets"] as! [String: Any]).keys), Vocabulary.targets)
        XCTAssertEqual(v["targetPrefixes"] as? [String], Vocabulary.targetPrefixes)
        let facts = (v["facts"] as! [String: [String: String]]).mapValues { $0["owner"]! }
        XCTAssertEqual(facts, Vocabulary.facts.mapValues(\.rawValue))
        let fams = (v["factFamilies"] as! [String: [String: String]]).mapValues { $0["owner"]! }
        XCTAssertEqual(fams, Vocabulary.factFamilies.mapValues(\.rawValue))
    }

    func testEachVerbKnowsItsLayer() throws {
        let verbs = try json()["verbs"] as! [String: [String: Any]]
        for verb in Verb.allCases {
            XCTAssertEqual(verbs[verb.rawValue]?["phase"] as? String, verb.layerName, verb.rawValue)
        }
    }
}
```

- [ ] **Step 3: Run it to see it fail**: `swift test --package-path Packages/RulesEngine` → compile errors (types missing).

- [ ] **Step 4: Write `Vocabulary.swift`**

```swift
import Foundation

public enum Verb: String, Codable, CaseIterable, Sendable {
    case add, set, multiply, cap, floor, useLevel, replace, suppress
    case forbid, require, limit, offer, ask, tell, provide, derive
    case check, gain, cost, process, item, reroll

    /// The pipeline phase a value verb runs in (spec §5.2); nil for data, player and action verbs.
    public var phase: Phase? {
        switch self {
        case .derive: .base
        case .useLevel: .level
        case .add, .set: .add
        case .replace, .suppress: .lines
        case .multiply: .multiply
        case .cap, .floor: .cap
        case .forbid, .require, .limit: .legality
        default: nil
        }
    }

    /// The JSON's `phase` field: a phase name, or data / player / action.
    public var layerName: String {
        if let phase { return phase.rawValue }
        switch self {
        case .provide: return "data"
        case .offer, .ask, .tell: return "player"
        default: return "action"
        }
    }
}

public enum Phase: String, Codable, CaseIterable, Comparable, Sendable {
    case base, level, add, lines, multiply, cap, legality
    public static func < (a: Phase, b: Phase) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}

public enum Owner: String, Codable, CaseIterable, Sendable { case sheet, loadout, player, gm, round, roll, derived }
public enum ReasonCode: String, Codable, CaseIterable, Sendable {
    case conditionFalse, unknownFact, openRuling, requirementNotMet, forbidden
    case suppressed, replaced, overridden, rulesetOff, outOfContext
}
public enum RuleKind: String, Codable, CaseIterable, Sendable {
    case specialAbility, advantage, disadvantage, condition, state, core, equipment, creature, talent
}
public enum Span: String, Codable, CaseIterable, Sendable { case action, round, fight, whileFormed, untilCleared }
public enum Pool: String, Codable, CaseIterable, Sendable { case le, asp, kap, schips, ammunition }
public enum EventKind: String, Codable, CaseIterable, Sendable {
    case paid, progressed, completed, brokenOff, itemChanged, gained, cleared, logged
}
public enum Audience: String, Codable, CaseIterable, Sendable { case player, gm, opponent }
public enum LineKind: String, Codable, CaseIterable, Sendable {
    case base, add, set, levelAs, replaced, multiplied, capped, floored, rerolled, free
}

public enum Vocabulary {
    public static let version = 1
    public static let targets: Set<String> = [
        "at", "pa", "aw", "fk", "tp", "rs", "ini", "iniBase", "gs", "leMax", "leCurrent", "aspMax",
        "kapMax", "wundschwelle", "sp", "schips", "belastung", "regeneration.le", "regeneration.asp",
        "regeneration.kap", "check.attribute", "check.modifier", "check.fw", "check.fp", "check.qs",
        "check.dice", "spell.cost", "spell.castingTime", "spell.range", "spell.duration",
        "item.ladezeit", "item.structurePoints",
    ]
    public static let targetPrefixes = ["opponent.", "mount.", "ally."]
    public static let facts: [String: Owner] = [
        "level": .sheet, "option": .sheet, "hero.has": .sheet, "hero.mounted": .loadout,
        "ally.has": .player, "opponent.has": .gm, "rulesets": .gm,
        "loadout.weapon": .loadout, "loadout.weapon.technique": .loadout, "loadout.weapon.kind": .loadout,
        "loadout.shield": .loadout, "loadout.shield.size": .loadout, "loadout.reach": .loadout,
        "loadout.armour": .loadout, "action.attack": .player, "action.defence": .player,
        "action.manoeuvre": .player, "action.with": .player, "round.number": .round,
        "round.defencesMade": .round, "round.parries": .round, "round.dodges": .round,
        "round.doubleAttack": .round, "clock.minutes": .round, "hit.zone": .roll, "hit.tp": .roll,
        "hit.sp": .derived, "check.talent": .player, "check.application": .player, "check.result": .roll,
    ]
    public static let factFamilies: [String: Owner] = [
        "attr.": .sheet, "ktw.": .sheet, "fw.": .sheet, "mount.": .sheet, "creature.": .sheet,
        "item.": .loadout, "choice.": .player, "spell.": .player, "gmFact.": .gm,
        "opponent.": .gm, "target.": .gm, "roll.": .roll, "stage.": .roll,
    ]

    public static func owner(ofFact name: String) -> Owner? {
        if let o = facts[name] { return o }
        return factFamilies.first { name.hasPrefix($0.key) && name.count > $0.key.count }?.value
    }
}
```

(Tasks 8–15 may have grown the vocabulary. Copy the targets, facts and families from the
**current** `specs/rules/vocabulary.json`, not from this listing.)

- [ ] **Step 5: Add the Makefile target**

```make
# The new rules engine (Packages/RulesEngine): pure Swift, runs on macOS without a simulator.
test-rules-engine: rules-json
	swift test --package-path Packages/RulesEngine
```

- [ ] **Step 6: Run** `make test-rules-engine`. Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add Packages/RulesEngine Makefile
git commit Packages/RulesEngine Makefile -m "feat(engine): the RulesEngine package and its vocabulary

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 20: The rule model and `rules.json`

**Goal:** The package decodes `build/rules/rules.json` into immutable `RuleBook` values. Each
verb's payload is decoded into a typed struct, and a book built for another vocabulary version
is refused.

**Files:**
- Create: `Packages/RulesEngine/Sources/RulesEngine/Model/JSONValue.swift`, `Model/Forms.swift` (`ValueExpr`, `Condition`, `TargetRef`, `Selector`, `ClauseRef`), `Model/Payload.swift`, `Model/Rule.swift` (`Rule`, `Clause`, `Effect`, `Ruling`, `RuleBook`)
- Test: `Tests/RulesEngineTests/RuleBookTests.swift`, `Tests/RulesEngineTests/Fixtures/mini-rules.json`

**Acceptance Criteria:**
- [ ] `RuleBook.load(from:)` decodes `build/rules/rules.json` without error. The test skips, with the message "run make rules-json", when the file is missing.
- [ ] A hand-written fixture with one effect per verb decodes each into its own `Payload` case. `Payload` is an enum with one case per `Verb`, each holding a struct whose fields are the vocabulary's.
- [ ] `vocabularyVersion != Vocabulary.version` throws `RuleBookError.vocabularyMismatch(found:expected:)`.
- [ ] `TargetRef("pa(with: shield)")` parses, and its `description` gives the same string back. `TargetRef.matches(_:)`: an effect target `pa` with no context matches a query `pa(with: shield)`; `pa(with: weapon)` does not.
- [ ] `RuleBook.effects(reaching: "pa")` returns the `Effect`s the reach index lists, plus those under `"*"`.

**Verify:** `make test-rules-engine` → pass

**Steps:**

- [ ] **Step 1: Write the failing tests.** Write `mini-rules.json` by hand in the exact
shape of Task 4's output: one rule per verb, with `reach` filled in. Then:

```swift
final class RuleBookTests: XCTestCase {
    func testEveryVerbDecodesToItsPayload() throws {
        let book = try RuleBook.load(from: Bundle.module.url(forResource: "mini-rules", withExtension: "json")!)
        let verbs = Set(book.rules.values.flatMap { $0.clauses.flatMap(\.effects) }.map(\.payload.verb))
        XCTAssertEqual(verbs, Set(Verb.allCases))
    }

    func testAnotherVocabularyIsRefused() throws {
        var raw = try String(contentsOf: Bundle.module.url(forResource: "mini-rules", withExtension: "json")!, encoding: .utf8)
        raw = raw.replacingOccurrences(of: "\"vocabularyVersion\": 1", with: "\"vocabularyVersion\": 99")
        XCTAssertThrowsError(try RuleBook.decode(Data(raw.utf8))) {
            XCTAssertEqual($0 as? RuleBookError, .vocabularyMismatch(found: 99, expected: Vocabulary.version))
        }
    }

    func testTheRealBookDecodes() throws {
        let url = Repo.url("build/rules/rules.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "run make rules-json")
        let book = try RuleBook.load(from: url)
        XCTAssertNotNil(book.rules["SA_862"])
        XCTAssertFalse(book.effects(reaching: "at").isEmpty)
    }

    func testTargetRefRoundTrips() {
        XCTAssertEqual(TargetRef("pa(with: shield)").description, "pa(with: shield)")
        XCTAssertTrue(TargetRef("pa").matches(TargetRef("pa(with: shield)")))
        XCTAssertFalse(TargetRef("pa(with: weapon)").matches(TargetRef("pa(with: shield)")))
    }
}
```

Add `resources: [.copy("Fixtures")]` to the test target in `Package.swift`.

- [ ] **Step 2: Run to see it fail.**

- [ ] **Step 3: Implement the model.** The shapes are those of Tasks 2–4. The core
declarations:

```swift
public indirect enum JSONValue: Codable, Hashable, Sendable {
    case null, bool(Bool), int(Int), double(Double), string(String), array([JSONValue]), object([String: JSONValue])
    // init(from:) tries bool, int, double, string, array, object in that order
}

public struct TargetRef: Codable, Hashable, Sendable, CustomStringConvertible {
    public var name: String
    public var context: [String: String]           // "with", "zone", "index", "talent", "spell"
    public init(_ text: String)                    // parses "pa(with: shield)"
    public var description: String                 // "pa(with: shield)" / "pa"
    /// An effect target with no context reaches every context; one with a context reaches only it.
    public func matches(_ query: TargetRef) -> Bool {
        name == query.name && context.allSatisfy { query.context[$0.key] == $0.value }
    }
    // JSON form is {"name": "pa", "with": "shield"}: decode "name", every other key into context.
}

public enum Operand: Codable, Hashable, Sendable { case number(Double), fact(String), target(TargetRef) }

public enum ValueExpr: Codable, Hashable, Sendable {
    case number(Double)
    case level(times: Int, plus: Int)
    case proportion(Proportion)
    case table(name: String, key: String)
}
public struct Proportion: Codable, Hashable, Sendable {
    public var of: Operand, per: Operand, times: Double, above: Double
    public var round: Rounding, min: Int?, max: Int?
}
public enum Rounding: String, Codable, Sendable { case up, down }

public indirect enum Condition: Codable, Hashable, Sendable {
    case all([Condition]), any([Condition]), not(Condition)
    case fact(name: String, comparison: Comparison)
}
public enum Comparison: Codable, Hashable, Sendable {
    case `is`(JSONValue), `in`([JSONValue]), atLeast(Double), atMost(Double), above(Double), below(Double)
}

public struct Selector: Codable, Hashable, Sendable { public var kind: String; public var ids: [String]; public var with: String? }
public struct ClauseRef: Codable, Hashable, Sendable, CustomStringConvertible {
    public var rule: String, clause: String
    public var description: String { "\(rule).\(clause)" }
}

public struct Effect: Codable, Hashable, Sendable {
    public var payload: Payload
    public var when: Condition?
    public var ruling: [String]
    public var because: String?
    public var phase: Phase?          // nil for data / player / action verbs
    public var origin: EffectOrigin   // rule, clause, index (index may be "0" or "0.onFailure.1")
}

public enum Payload: Hashable, Sendable {
    case add(Add), set(SetValue), multiply(Multiply), cap(Cap), floor(Floor), useLevel(UseLevel)
    case replace(Replace), suppress(Suppress), forbid(Forbid), require(Require), limit(Limit)
    case offer(Offer), ask(Ask), tell(Tell), provide(Provide), derive(Derive)
    case check(Check), gain(Gain), cost(Cost), process(Process), item(ItemChange), reroll(Reroll)
    public var verb: Verb { … }   // one line per case
}
// One struct per case, fields exactly as vocabulary.json's `fields` + `optional`, e.g.
public struct Add: Codable, Hashable, Sendable { public var to: [TargetRef]; public var value: ValueExpr; public var per: String?; public var scale: String? }
public struct Check: Codable, Hashable, Sendable { public var of: Selector; public var modifier: ValueExpr?; public var onSuccess: [Effect]; public var onFailure: [Effect] }
public struct Cost: Codable, Hashable, Sendable {
    public var pool: Pool; public var amount: ValueExpr
    public var split: Split?; public var fallThrough: [Pool]; public var onFailure: Double?; public var every: Duration?
}
// The other 19 structs mirror vocabulary.json's `fields` (non-optional) and `optional` (optional)
// one to one, with the Swift types of their field types (targets → [TargetRef], value → ValueExpr,
// selector → Selector, effects → [Effect], condition → Condition, span → Span, pool → Pool, …).
// UseLevel is { rule: String; as: ValueExpr?; lowerBy: ValueExpr?; min: Int? }.

public enum ClauseBody: Hashable, Sendable { case effects([Effect]), unencoded(String), none(String) }
public struct Clause: Hashable, Sendable { public var id: String, text: String, body: ClauseBody; public var effects: [Effect] { … } }
public struct Ruling: Codable, Hashable, Sendable { public var id: String, status: Status, question: String?, answer: String?; public enum Status: String, Codable, Sendable { case open, decided } }
public struct Rule: Hashable, Sendable {
    public var id: String, name: String, kind: RuleKind, ruleset: String?
    public var levels: Int?, options: String?, provides: [String: JSONValue]
    public var clauses: [Clause], rulings: [String]
}
public struct RuleBook: Sendable {
    public let rules: [String: Rule]
    public let rulings: [String: Ruling]
    public let reach: [String: [EffectOrigin]]
    public let sha256: String
    public static func load(from url: URL) throws -> RuleBook
    public static func decode(_ data: Data) throws -> RuleBook
    public func effect(at origin: EffectOrigin) -> Effect?
    public func effects(reaching target: String) -> [Effect]  // reach[target] + reach["*"], in index order
    public func table(_ name: String) -> JSONValue?           // a `provide`d value by name
}
public enum RuleBookError: Error, Equatable { case vocabularyMismatch(found: Int, expected: Int) }
```

`Payload`'s `Codable`: `Effect` decodes `{"verb": "add", "payload": {...}}` by switching on
`verb`. Write this by hand, not with a generic key lookup, so that a missing field fails on
decode.

- [ ] **Step 4: Run the tests.** Expected: pass.
- [ ] **Step 5: Commit**

```bash
git add Packages/RulesEngine
git commit Packages/RulesEngine -m "feat(engine): decode rules.json into typed rules

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 21: Situations, facts and the tri-state `when`

**Goal:** `Situation` holds what is known, each fact with its owner. Conditions evaluate to yes,
no or unknown, and never guess an unknown fact (§4.6). The four value forms evaluate, and
every evaluation reports the facts it read.

**Files:**
- Create: `Sources/RulesEngine/Situation.swift`, `Sources/RulesEngine/Evaluation/Conditions.swift`, `Sources/RulesEngine/Evaluation/Values.swift`
- Test: `Tests/RulesEngineTests/ConditionTests.swift`, `Tests/RulesEngineTests/ValueTests.swift`

**Acceptance Criteria:**
- [ ] `Situation` has these fields:
  - `owned: [String: OwnedRule]` (level, option)
  - `facts: [String: Fact]` (name, value, owner)
  - `base: [String: Int]`, keyed by query string
  - `rolls: [Int]`
  - `pools: [Pool: PoolState]` (current, max)
  - `processes`, `items` and `clock`, which start empty and are filled in by Task 28
  - `heroId: String?`
- [ ] It is `Codable`. Its `init` takes the `situations.json` shape: `owned`, the `facts` list, `base`, `rolls`.
- [ ] `hero.has: X` is yes when `owned[X]` exists and no otherwise, and never unknown, because the sheet is complete. `ally.has: X` and `opponent.has: X` read the facts `ally.has` / `opponent.has`, which are lists, and are **unknown** when those facts are absent.
- [ ] Any other absent fact is unknown. `all` is no if any part is no, else unknown if any part is unknown, else yes. `any` is the dual. `not(unknown)` is unknown.
- [ ] `is` against a list-valued fact means contains. `atLeast`/`atMost`/`above`/`below` compare numbers.
- [ ] Each evaluation returns the `FactUse`s (name, value, owner) that it read. Unknown ones are listed in `unknown: [String]` with their owner from `Vocabulary.owner(ofFact:)`.
- [ ] Values:
  - `level(times:plus:)` uses the effective level passed in.
  - A proportion computes `max(0, of − above) × times / per`, rounded as stated, then clamped by `min`/`max`.
  - `table(name, key)` looks up `book.table(name)[factValue(key)]`.
  - An operand that is a target is evaluated through a closure `resolve: (TargetRef) -> Int?`, so the evaluator can recurse. That closure has a depth guard of 8, returning nil beyond it.
- [ ] Tests:
  - KW1: `of attr.MU, above 8, per 3, round down` with MU 14 gives 2.
  - Wundschwelle: `of attr.KO, per 2, round up` with KO 15 gives 8.
  - `level - 1` at level 3 gives 2.
  - A table lookup finds its value, and a missing key gives nil and the unknown fact.

**Verify:** `make test-rules-engine` → pass

**Steps:**
- [ ] **Step 1: Write the failing tests** for each criterion. Build situations inline:

```swift
let s = Situation(owned: ["SA_862": .init(level: 1)],
                  facts: [Fact(name: "hero.mounted", value: .bool(false), owner: .loadout)])
let c = Condition.all([.fact(name: "hero.mounted", comparison: .is(.bool(false))),
                       .fact(name: "gmFact.fromBehind", comparison: .is(.bool(true)))])
let r = Conditions.evaluate(c, in: s)
XCTAssertEqual(r.truth, .unknown)
XCTAssertEqual(r.unknown, [UnknownFact(name: "gmFact.fromBehind", owner: .gm)])
XCTAssertEqual(r.used, [FactUse(name: "hero.mounted", value: .bool(false), owner: .loadout)])
```

- [ ] **Step 2: Run to see it fail.**
- [ ] **Step 3: Implement** `Conditions.evaluate(_:in:level:) -> ConditionResult { truth: Truth, used: [FactUse], unknown: [UnknownFact] }` and `Values.evaluate(_:level:in:book:resolve:) -> ValueResult { value: Int?, used, unknown }`. `Truth` is `enum { case yes, no, unknown }`. Values are computed in `Double` and rounded once, at the end.
- [ ] **Step 4: Run the tests.** Expected: pass.
- [ ] **Step 5: Commit**

```bash
git commit Packages/RulesEngine -m "feat(engine): situations, facts with owners, tri-state conditions and the four value forms

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 22: The evaluator, phases 1–3, with provenance

**Goal:** `Engine.evaluate(_ query: Query, in: Situation) -> Breakdown` runs the base, level and
add phases. It decides which rules apply to the hero, and every line carries rule, clause,
`via`, ruling and the facts it used, with their owners (§5.5).

**Files:**
- Create: `Sources/RulesEngine/Engine.swift`, `Sources/RulesEngine/Breakdown.swift`, `Sources/RulesEngine/Evaluation/Applicability.swift`, `Sources/RulesEngine/Evaluation/Pipeline.swift`
- Test: `Tests/RulesEngineTests/PipelineTests.swift`, `Tests/RulesEngineTests/Fixtures/pipeline-rules.json`

**Acceptance Criteria:**
- [ ] `Breakdown` has these fields:
  - `query`
  - `base: Line?`
  - `lines: [Line]`, excluding the base line
  - `total: Int`, the sum of `lines`
  - `result: Int?`, which is `base + total`, or nil without a base
  - `notApplied: [NotApplied]`, `offers: [Offer]`, `questions: [Question]`, `texts: [TextLine]` and `legal: Legality`

  `Line` has `value`, `kind: LineKind`, `origin: ClauseRef?`, `via: [ClauseRef]`, `ruling: String?`, `facts: [FactUse]` and `note: String?`.
- [ ] Applicability: a rule applies when it meets one of these:
  - its kind is `core` and its `ruleset` (if any) is in the fact `rulesets` (otherwise `notApplied` with `rulesetOff`);
  - it is owned (`owned[id]`, which covers conditions, states, abilities, advantages, disadvantages and creatures);
  - its kind is `equipment` and a `loadout.*` fact names the item whose template id is the rule id (fact `item.<name>.template`);
  - it has an effect `require` with `enables: true` whose `that` is yes. Its lines then carry `via: [that clause]`, as in example 19.3.

  A rule that does not apply and is not owned is silent: it does not go into `notApplied`.
- [ ] Base (phase 1): `situation.base[query.description]`, or `base[query.name]` when there is no context match, gives a line of kind `.base` with owner `sheet` and the note "Grundwert laut Bogen". Otherwise the first applicable `derive` reaching the query gives a `.base` line from its sum, with the used facts.
- [ ] Level (phase 2): each applicable `useLevel` changes the effective level of its target rule, to `as` or to the target's level minus `lowerBy`, floored at `min` (default 0). This adds a `.levelAs` line of value 0 with the note "Stufe X wirkt wie Y", and every later line of that rule carries `via: [useLevel's clause]`. A rule's effective level is `owned[id].level` when useLevel does not touch it.
- [ ] Add (phase 3): for each applicable `set`/`add` reaching the query whose `when` is yes, its value is added (`add`, times the fact `per` when given), or the running value is set (`set` → a `.set` line whose value is `target − (base + sum so far)`). Within the phase, all `set`s apply before `add`s. When there are two `set`s, the later one in rule-id order wins, and the other goes to `notApplied` with `overridden`.
- [ ] An effect whose `when` is no goes to `notApplied(rule, clause, conditionFalse, because)`. One whose `when` is unknown goes to `notApplied(…, unknownFact)` and adds one `Question` per unknown fact, with its owner. One resting on an open ruling goes to `notApplied(…, openRuling)` and adds a `TextLine` with the clause text and the ruling's question. A line resting on a decided ruling sets `ruling` to that id (→ *Auslegung*).
- [ ] Pipeline tests, on a fixture book, cover:
  - a derive base
  - a stated base
  - two adds
  - a set before an add
  - useLevel with `via`
  - an unknown GM fact giving a question
  - an open ruling giving a text
  - an `enables` require giving `via`

**Verify:** `make test-rules-engine` → pass

**Steps:**

- [ ] **Step 1: Write the fixture and the failing tests.** Example of one:

```swift
func testUseLevelLinesCarryVia() throws {
    // COND_1 (levels 4): B3 add { to: [at, pa, aw], value: "-level" }
    // SA_41 (levels 2): G1 useLevel { rule: COND_1, lowerBy: level, min: 0 } — lowerBy at SA_41's own level
    let s = Situation(owned: ["COND_1": .init(level: 3), "SA_41": .init(level: 2)], facts: [])
    let b = engine.evaluate(Query("at"), in: s)
    let line = try XCTUnwrap(b.lines.first { $0.origin == ClauseRef(rule: "COND_1", clause: "B3") })
    XCTAssertEqual(line.value, -1)
    XCTAssertEqual(line.via, [ClauseRef(rule: "SA_41", clause: "G1")])
    XCTAssertTrue(b.lines.contains { $0.kind == .levelAs && $0.note == "Stufe 3 wirkt wie 1" })
}
```

(`useLevel.as` is evaluated with `level` bound to the **target** rule's owned level;
`useLevel.lowerBy` is evaluated with `level` bound to the **acting** rule's own level, and the
result is subtracted from the target's. Write both rules in the doc comment on `UseLevel`.)

- [ ] **Step 2: Run to see it fail.**
- [ ] **Step 3: Implement.** `Engine` is a struct holding the `RuleBook`. `evaluate` goes
through these steps:
  1. collect the candidates with `book.effects(reaching: query.name)`, filtered by `TargetRef.matches`;
  2. work out applicability per rule, and memoize it within the call;
  3. run the phases in `Phase.allCases` order. Each phase is its own `private func` in `Pipeline.swift`, taking and returning an `inout PipelineState` (lines, notApplied, questions, texts, effective levels, via map).

  A `derive` or proportion that needs another target calls `evaluate` recursively. Use a depth
  counter, and never a cache that outlives the call: the engine keeps nothing between calls
  (§3).
- [ ] **Step 4: Run the tests.** Expected: pass.
- [ ] **Step 5: Commit**

```bash
git commit Packages/RulesEngine -m "feat(engine): evaluate base, level and add phases with provenance on every line

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 23: The evaluator, phases 4–7, and the player-facing parts of the breakdown

**Goal:** Line control, multiply, cap and floor, and legality run, each leaving a line or a
not-applied entry. The breakdown's offers, questions, texts and legality are filled in.
`Engine.offers(in:)` lists every offer the situation allows.

**Files:**
- Modify: `Sources/RulesEngine/Evaluation/Pipeline.swift`, `Sources/RulesEngine/Engine.swift`
- Test: `Tests/RulesEngineTests/PipelineTests.swift` (continued)

**Acceptance Criteria:**
- [ ] `replace { line, with }`: the named clause's effect is evaluated with `with` in place of its `value`. Its `per`, targets and `when` are kept, so SA_923's −2 step still counts defences. The line keeps its origin, gets `kind: .replaced`, and `via` gets the replacer. The value it would have had goes to `notApplied(replaced)` with the replacer as text.
- [ ] `suppress { line }`: the line is removed and goes to `notApplied(suppressed)` with `because`.
- [ ] `multiply`:
  - With `line`, only that line is scaled.
  - Without it, the running result (base + lines) is scaled.
  - Either way the delta becomes a `.multiplied` line, rounded as stated (default up). Example: TP doubled on 1W6+4 = 7 gives a line of +7.
- [ ] `cap { over, min, max }`: the sum of the selected lines is bounded, and the difference becomes a `.capped` line. With `over: {lineKind: condition}` the lines are those from rules of kind `condition`. This is the −5 Zustand cap: Schmerz III (−3) + Belastung II (−2) + Betäubung I (−1) = −6 gives a capped line of +1.
- [ ] `floor { min }`: the result is bounded below, and the difference becomes a `.floored` line.
- [ ] Legality:
  - `forbid` whose selector matches the query or the situation's `action.*` facts sets `legal.allowed = false`, adding `NotApplied(forbidden, because)`.
  - `require { that, for }`, when false, does the same with `requirementNotMet`.
  - `limit { what, max, per }`, when the count fact (`round.parries` and the like, named by the selector) has reached `max`, does the same.
  - A result ≤ 0 on a defence query is forbidden by whichever rule says so (`kampfwerte`/`schilde`), never by a built-in check.
- [ ] `Engine.offers(in:) -> [Offer]`: every applicable `offer` whose `when` is not no, with `legal` false when a `forbid` on that choice fires (`because` is kept). `Engine.evaluate` also puts into `offers` those that reach the query.
- [ ] `tell` → `TextLine(audience, text, origin)`. `ask` → `Question(fact, owner: who)`. Unencoded clauses of applicable rules reaching the query → `TextLine`.
- [ ] A modifier the player types in (fact `choice.freeModifier`, a number, stated for the query's target) becomes a `.free` line with the note "frei eingegeben" and owner `player`. A GM's modifier (`gmFact.modifier`) becomes an `.add` line with owner `gm`. No number changes without a line (§5.5).
- [ ] At run time the engine never throws (§11). An effect whose value cannot be computed (a table key with no row, an operand out of the recursion depth) gives a `TextLine` "Regel konnte nicht angewandt werden: RULE.CLAUSE – <reason>" and no line. A test checks both cases.
- [ ] Tests cover each bullet, plus the Zustand cap example above as numbers.

**Verify:** `make test-rules-engine` → pass

**Steps:**
- [ ] **Step 1:** Extend the fixture and write one failing test per bullet.
- [ ] **Step 2:** Run to see it fail.
- [ ] **Step 3:** Implement the four phase functions and `offers(in:)`.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5: Commit**

```bash
git commit Packages/RulesEngine -m "feat(engine): line control, multiply, caps, legality, offers and texts

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 24: The situations harness

**Goal:** One XCTest runs every compiled situation through the engine and matches it by
§10.2's rules. Failures are reported with the situation id and a diff, pending ones with their
ruling ids. Situations whose expectations need the action layer are reported as *unsupported*
until Tasks 26–28 exist. A report is written to `build/rules/harness-report.json`.

**Files:**
- Create: `Tests/RulesEngineTests/Harness/CompiledSituation.swift` (decodes `situations.json`), `Harness/Matcher.swift`, `Harness/HarnessReport.swift`, `Tests/RulesEngineTests/SituationsHarnessTests.swift`
- Test: `Tests/RulesEngineTests/MatcherTests.swift`

**Acceptance Criteria:**
- [ ] Matching (§10.2):
  - A query's `total` and `result` compare exactly when given.
  - Each expected line must match an actual line by `from` (rule.clause), `value`, and `via` / `ruling` / `source` when given. Order does not matter, and actual lines the situation does not mention are not checked.
  - `notApplied` matches by rule (and clause, when given) and reason code.
  - `offered` / `notOffered` match by choice and origin clause against `Engine.offers(in:)`.
  - `questions` match by fact name.
  - `legal` compares when given.
- [ ] A situation with a non-empty `pending` that mismatches is counted as pending, not as a failure. One that matches is counted as passing, and its `pending` is noted in the report as "passes with ruling open".
- [ ] A situation with `sequence`, `rolls`, `events`, `fp`, `qs`, `spent` or `success` is `unsupported` until the action layer can run it. The harness asks `ActionRunner.canRun(_:)`, which returns false until Task 26.
- [ ] Only `failed` fails the test. It emits one `XCTFail` per failed situation, with its id, file and mismatch list.
- [ ] Env var `RULES_FILES=kampfwerte,lebensenergie` limits the run to those situations files, so Phase C can go one domain at a time.
- [ ] `build/rules/harness-report.json`: `{passed: [ids], failed: [{id, mismatches}], pending: [{id, rulings, mismatches}], unsupported: [ids]}`. The one-line summary is printed as `harness: P passed, F failed, N pending, U unsupported`.
- [ ] `MatcherTests` check the matcher against hand-built breakdowns: extra lines ignored, a missing line reported, a wrong `via` reported, reason codes compared.

**Verify:** `make test-rules-engine` → MatcherTests pass. The harness test runs and prints its summary. It may fail at this point: Phase C makes it green.

**Steps:**
- [ ] **Step 1: Write `MatcherTests`** (red).
- [ ] **Step 2: Implement** `CompiledSituation` (Codable, the Task 5 shape), `Matcher.match(_ expected: CompiledSituation, engine:) -> [Mismatch]` and `HarnessReport`.
- [ ] **Step 3: Write `SituationsHarnessTests.testEverySituation`.** It loads both JSON files (skipping with "run make rules-json" if they are missing), filters by `RULES_FILES`, runs, writes the report, prints the summary, and fails on `failed`.
- [ ] **Step 4:** Run `make test-rules-engine`. Record the first summary line in the commit message: it is Phase C's baseline.
- [ ] **Step 5: Commit**

```bash
git commit Packages/RulesEngine -m "test(engine): the situations harness

First run: harness: P passed, F failed, N pending, U unsupported.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

If the red harness test is in the way of the other tests during Phase B, set
`RULES_FILES=none` in the Makefile's `test-rules-engine` until Task 30. Say so in this
commit's message.

---

### Task 25: The action layer: events and pools

**Goal:** `(Action, Situation) → [Event]` for costs and gains, and `Situation.applying(_ events:)`,
which is the one place state changes (§7). Paying LeP lowers LE but is not damage.

**Files:**
- Create: `Sources/RulesEngine/Actions/Action.swift`, `Actions/Event.swift`, `Actions/ActionLayer.swift`, `Actions/Pools.swift`
- Test: `Tests/RulesEngineTests/PoolTests.swift`, `Tests/RulesEngineTests/EventTests.swift`

**Acceptance Criteria:**
- [ ] `Event` is `{ kind: EventKind, origin: ClauseRef?, pool: Pool?, amount: Int?, rule: String?, levels: Int?, process: String?, item: String?, change: [String: JSONValue]?, note: String? }`. It is Codable, and each event carries its origin like a line.
- [ ] `cost { pool, amount }` gives `paid(pool, amount)`. When the pool cannot pay and `fallThrough` is set, the rest goes to the next pool (AsP, then LeP). `split { pools, min }` takes the player's split from the fact `choice.split.<pool>` and checks each minimum, giving a `Question` when the split is unknown. `onFailure: 0.5` halves the amount, rounded up, when `check.result` is `failure`.
- [ ] `gain { rule, levels }` gives `gained(rule, levels)`, and a negative level gives `cleared`.
- [ ] `Situation.applying([Event]) -> Situation`:
  - `paid` lowers `pools[pool].current`;
  - `paid(le)` lowers LE only, with no RS, no Wundschwelle and no Wundeffekt. A test proves that no event of those kinds follows.
  - `gained` / `cleared` change `owned[rule].level`, removing the rule at 0.
  - A rule reading `leCurrent` sees the lowered value on the next query. A test checks this with a fixture rule whose `when` is `{ leCurrent: { below: 20 } }`: before paying it does not apply, after paying it does.
- [ ] `ActionLayer.perform(_ action: Action, in: Situation) -> ActionResult { events, breakdowns, questions, texts }`. `Action` is an enum: `.cast(spell: String, modifications: [String])`, `.pay(Pool, Int)`, `.state(rule: String, levels: Int)`, and the procedure actions that Tasks 26–28 add.

**Verify:** `make test-rules-engine` → PoolTests and EventTests pass

**Steps:**
- [ ] **Step 1: Write failing tests.** Include the probe-magie case: 8 AsP asked, AsP 5 → `paid(asp, 5)`, `paid(le, 3)`.
- [ ] **Step 2:** Run to see it fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5: Commit**

```bash
git commit Packages/RulesEngine -m "feat(engine): the action layer, events and pools

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 26: Staged checks: the 3W20 procedure

**Goal:** A talent, spell or liturgy check runs as the §6 state machine: start → dice → reroll
→ confirm. Each stage is a target that rules hook into. The dice come in from outside, and the
log keeps both faces of a rerolled die.

**Files:**
- Create: `Sources/RulesEngine/Procedures/CheckProcedure.swift`, `Procedures/ProcedureState.swift`
- Modify: `Actions/Action.swift` (`.check(CheckRequest)`), `Tests/RulesEngineTests/Harness/Matcher.swift` (`ActionRunner.canRun` true for 3W20 situations; run them through the procedure and compare `fp`, `qs`, `spent`, `success` and the stage queries)
- Test: `Tests/RulesEngineTests/CheckProcedureTests.swift`

**Acceptance Criteria:**
- [ ] `CheckProcedure.start(request, in: s, engine:)` returns `.awaitingDice` with three `check.attribute(index: i)` breakdowns. Each is the attribute plus one shared `check.modifier` breakdown: every Erschwernis, the GM's modifier as a line with owner `gm`, and Belastung where it reaches. A `check.fw` breakdown is also returned: FW plus Fertigkeitsspezialisierung as its own line, since it is not an Erleichterung. Any attribute value ≤ 0 makes the check illegal.
- [ ] `.dice([Int])` gives the result: FP left, `spent` per die, success, and Doppel-1 / Doppel-20 counted from the faces. It also gives the open `reroll` offers: every applicable `reroll` effect (Begabung, a Schip) whose `when` holds and whose `max`/`per` limit is not used up.
- [ ] `.reroll(die: Int, face: Int)` replaces that die and adds a line of kind `.rerolled` with note `"W\(die+1): \(old) → \(new), \(rule name)"`. Begabung and a Schip can be taken in either order, and each is offered until used.
- [ ] `.confirm` gives `check.qs` from the QS table (0 FP counts as QS 1, per `fertigkeitsproben`), and the events: a `cost` paid (half on failure), `logged` with QS, and any `onSuccess` / `onFailure` effects of a `check` effect. A failed Autoritätsglaube check yields `logged` with the note "gibt nach".
- [ ] The procedure is `(state, input) → (state, breakdowns, offers, events)`, pure, with no stored state outside the returned value.
- [ ] Unit tests use probe-fertigkeiten's numbers: rolls [15, 16, 10] against eew [12, 14, 14] with FW 10 gives FP 3, QS 1. The reroll of die 2 from 19 to 11 gives spent [0, 5, 0], FP 3, QS 1 before, and the new result after.

**Verify:** `make test-rules-engine` → CheckProcedureTests pass. `RULES_FILES=probe-fertigkeiten` shows 0 unsupported.

**Steps:**
- [ ] **Step 1:** Write the failing tests from the numbers above.
- [ ] **Step 2:** Run to see it fail.
- [ ] **Step 3:** Implement the state machine as an enum `ProcedureState { case awaitingDice(Stages), rolled(Stages, Result, [Offer]), confirmed(Stages, Result, [Event]) }` with `func step(_ input: ProcedureInput, engine:, situation:) -> StepResult`. Wire the harness: a situation with `rolls` and a `check.*` query or a `fp` / `qs` / `spent` expectation runs `start` → `dice(rolls)`, then each `choose.reroll` as `.reroll`, then `.confirm`.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5: Commit**

```bash
git commit Packages/RulesEngine -m "feat(engine): checks as staged procedures (3W20)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 27: Combat rolls and the damage chain

**Goal:** A 1W20 combat roll runs as target → dice → result → consequence. A confirmation roll
is itself a check. The consequence chain TP → RS → SP → Wundschwelle → Wundeffekt check is a
sequence of targets, each with its own lines.

**Files:**
- Create: `Sources/RulesEngine/Procedures/CombatRoll.swift`, `Procedures/DamageChain.swift`
- Modify: `Actions/Action.swift` (`.attack`, `.defend`, `.takeHit`), `Harness/Matcher.swift` (these situations become runnable)
- Test: `Tests/RulesEngineTests/CombatRollTests.swift`, `Tests/RulesEngineTests/DamageChainTests.swift`

**Acceptance Criteria:**
- [ ] `CombatRoll.start(.attack(with:) / .defend(kind:with:), in:)` gives the §5 breakdown of AT, PA, AW or FK as its `target` stage. `dice([d20])` gives success, or a 1 / 20 needing confirmation. `.confirm(d20)` resolves it with the confirmation as a `check` on the same target.
- [ ] `DamageChain.run(hit: tp, zone:, in:)` evaluates `tp`, then `rs(zone:)`, then `sp`, each a query with its own lines (`sp` = max(0, tp − rs) comes from `schaden`'s `derive`, not built in). Then:
  - it compares `sp` with `wundschwelle`, via the trefferzonen rule's effects;
  - when a Wundeffekt check is due, it returns a pending `check` from the `trefferzonen` rules, with its `onFailure` → `gain`.
- [ ] The chain does no arithmetic of its own: every number comes from the rules. A test runs the chain on a fixture book whose `sp` derive is `tp − rs − 1`, and expects SP one lower than with the real book.
- [ ] The trefferzonen numbers work, e.g. Boronmir, Wundschwelle 9 with Eisern: 8 SP → no Wundeffekt, and `notApplied` has `trefferzonen.TZ8` with `conditionFalse`.

**Verify:** `make test-rules-engine` → CombatRollTests, DamageChainTests pass

**Steps:**
- [ ] **Step 1:** Write the failing tests (numbers from `situations/trefferzonen.yaml` and `boronmir-neu.yaml` 19.6–19.8).
- [ ] **Step 2:** Run to see it fail.
- [ ] **Step 3:** Implement both procedures the same way as Task 26: pure step functions.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5: Commit**

```bash
git commit Packages/RulesEngine -m "feat(engine): combat rolls and the TP→RS→SP→Wundschwelle chain

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 28: State over time: processes, items, spans, the clock

**Goal:** A process (Zielen, Laden, Bogen spannen, a multi-action cast), item state keyed by
instance, spans, and a game clock the player advances are all data in `Situation`, changed only
by events (§7).

**Files:**
- Create: `Sources/RulesEngine/State/Process.swift`, `State/ItemState.swift`, `State/Clock.swift`
- Modify: `Situation.swift` (fields), `Actions/ActionLayer.swift` (`.advance(process:)`, `.advanceClock(minutes:)`, `.endRound`, `.endFight`), `Situation.applying` (the new events)
- Test: `Tests/RulesEngineTests/ProcessTests.swift`, `Tests/RulesEngineTests/ItemStateTests.swift`, `Tests/RulesEngineTests/ClockTests.swift`

**Acceptance Criteria:**
- [ ] `ProcessState { id, rule, progress, steps, startedRound }`:
  - `process { id, steps, advancedBy, completes, breaksOff }` starts one when its `advancedBy` action happens, and each such action gives `progressed`;
  - reaching `steps` gives `completed` plus the `completes` effects;
  - `breaksOff` turning yes gives `brokenOff`;
  - a process outlives `.endRound`.

  Test: Laden of a Leichte Armbrust, Ladezeit 4 with Schnellladen halved to 2 (`multiply` on `item.ladezeit`), completes after 2 actions and sets `item.loaded`.
- [ ] `ItemState` is keyed by **instance id** (`item.<instance>.*` facts), never by name: two identical daggers are two items, and a test proves it. `item { instance, change }` gives `itemChanged`. A shield's current StP goes down with Schildspalter, and at 0 the item is destroyed and leaves the loadout.
- [ ] Spans:
  - `.endRound` clears facts and choices with span `round`;
  - `.endFight` clears `fight`;
  - `whileFormed` lasts until its choice is cleared;
  - `untilCleared` lasts until a `cleared` event.
- [ ] `Clock { round: Int, minutes: Int }`. `.advanceClock(minutes:)` fires every `cost { every }` that is due, e.g. "2 AsP pro 5 Minuten": after 12 minutes, two payments of 2. It also fires the Zustand durations that are stated as spans.

**Verify:** `make test-rules-engine` → the three test classes pass. `RULES_FILES=probe-fernkampf,probe-magie` shows 0 unsupported.

**Steps:**
- [ ] **Step 1:** Write failing tests for each criterion.
- [ ] **Step 2:** Run to see it fail.
- [ ] **Step 3:** Implement. Wire the harness so that `sequence` steps run as actions in order, each step's `expect` checked against the state after it.
- [ ] **Step 4:** Run. Expected: pass.
- [ ] **Step 5: Commit**

```bash
git commit Packages/RulesEngine -m "feat(engine): processes, item state by instance, spans and the game clock

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 29: The log and its export

**Goal:** Each query and action can be recorded as a `LogEntry` holding everything in §8. The
log exports as JSON Lines, and one entry exports as a draft situations file. Exporting a run
and reading it back reproduces the same breakdown.

**Files:**
- Create: `Sources/RulesEngine/Log/LogEntry.swift`, `Log/LogExport.swift`, `Log/SituationDraft.swift`
- Test: `Tests/RulesEngineTests/LogTests.swift`
- Create (recorded by the test): `scripts/rulec/fixtures/draft-from-log.yaml`
- Test (Python): `scripts/rulec/test_draft_fixture.py`

**Acceptance Criteria:**
- [ ] `LogEntry` is Codable with these fields:
  - `id: UUID`, `date: Date`
  - `kind: query | action`
  - `query: Query?`, `action: Action?`
  - `situation: Situation`, which is complete: facts with owners, owned rules, pools, processes, items and clock
  - `breakdowns: [Breakdown]`
  - `offersTaken: [String]`, `answers: [String: JSONValue]`
  - `rolls: [Int]`, `rerolls: [Reroll]`, `events: [Event]`
  - `appVersion: String`, `rulesSha256: String`, `vocabularyVersion: Int`, `heroId: String?`
  - `note: String?`, `flagged: Bool`
- [ ] `LogExport.jsonLines(_ entries: [LogEntry]) -> String`: one entry per line, keys sorted, ISO-8601 dates, a trailing newline. Every field name is lowerCamelCase and in the vocabulary's language. A test checks every key against `^[a-z][a-zA-Z0-9]*$`.
- [ ] `SituationDraft.yaml(from: LogEntry, id: String, name: String) -> String` writes a situations-file stub in the §10.1 format:
  - the hero as `hero:` values (owned rules, attributes, base values);
  - the facts in their owners' sections (`choose`, `gm`, `round`, `loadout`);
  - the `rolls`;
  - `expect` with what the engine computed (total, result, lines with `from`, `via`, `ruling`);
  - `appToday` with the player's note.
- [ ] `SituationDraft.compiled(from:)` gives the `CompiledSituation` of the same draft.
- [ ] Round trip: for every harness situation that passes, running it → `LogEntry` → `SituationDraft.compiled` → running it again gives an equal `Breakdown`.
- [ ] Across languages, record-style (like `RuleVocabularyTests`): the Swift test writes the draft of situation 19.1 to `scripts/rulec/fixtures/draft-from-log.yaml` and fails once if the file changed. The Python test `test_draft_fixture.py` compiles that file with `situations.check` against the real rules and asserts no errors.

**Verify:** `make test-rules-engine && make test-rulec` → both pass

**Steps:**
- [ ] **Step 1:** Write the failing Swift tests (the key-case check, the round trip, and the fixture record) and the Python fixture test.
- [ ] **Step 2:** Run to see them fail.
- [ ] **Step 3:** Implement. The YAML writer is a small emitter for exactly the draft's shapes: mappings, flow lists of scalars, quoted strings. It is not a general YAML library.
- [ ] **Step 4:** Run both suites; commit the recorded fixture.
- [ ] **Step 5: Commit**

```bash
git add Packages/RulesEngine scripts/rulec/fixtures scripts/rulec/test_draft_fixture.py
git commit Packages/RulesEngine scripts/rulec -m "feat(engine): the log, its JSON Lines export and entry-as-situation drafts

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---
## Phase C — green, domain by domain (cut-over order, §9)

### Tasks 30–36: making each domain's decided situations pass

These seven tasks share one shape. They go in the order of spec §9, because later domains
rest on earlier ones: melee needs the sheet, damage needs melee.

**Goal (each task):** Every situation in the domain's files that rests only on decided
rulings passes. The pending ones are listed with their rulings, and none is unsupported.

**Acceptance Criteria (each task):**
- [ ] `RULES_FILES=<files> make test-rules-engine` prints `harness: P passed, 0 failed, N pending, 0 unsupported`.
- [ ] Every fix is in one of these places:
  - the engine: an interpreter, a phase, applicability or a procedure;
  - the vocabulary, per the Global Constraints;
  - a rule file's **encoding**, which also sets `reviewed: null` and adds a line to MIGRATION.md.

  None is an `if` on a rule id or a situation id. `grep -rnE '"(SA|ADV|DISADV|COND|STATE|ITEMTPL)_[0-9]+"' Packages/RulesEngine/Sources` finds nothing.
- [ ] No `expect` value was changed. A situation that is wrong in its expectation is left failing and reported to the user with its id and the reasoning. It is not fixed by the executor.
- [ ] Each fix to the engine has a unit test of its own, besides the harness.
- [ ] The commit message lists the domain's harness summary before and after the task, and the pending situations with their rulings.

**Verify (each task):** `RULES_FILES=<files> make test-rules-engine` → `0 failed … 0 unsupported`

**Steps (each task):**
- [ ] **Step 1:** Run the domain's harness. Save the report: `cp build/rules/harness-report.json <scratchpad>/<domain>-before.json`.
- [ ] **Step 2:** Group the failures by their first mismatch (a missing line from X, a wrong total, a wrong reason code). Each group is usually one missing interpreter feature.
- [ ] **Step 3:** For each group, write a failing unit test for the engine feature on a fixture book, implement it, and re-run the harness.
- [ ] **Step 4:** Continue until the criteria hold. Then run the **full** harness (`make test-rules-engine` without the filter) to check that earlier domains still pass.
- [ ] **Step 5:** Commit with the summaries in the message:

```bash
git commit Packages/RulesEngine specs/rules scripts/rulec docs/rules-rework/examples -m "feat(engine): <domain> situations pass

Before: harness: … After: harness: … Pending: <id (ruling), …>

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

| Task | Domain | `RULES_FILES` |
|---|---|---|
| 30 | Derived values and the sheet | `kampfwerte,lebensenergie,belastung,verweichlicht` |
| 31 | Melee attack and defence | `mehrfache-verteidigung,finte,wuchtschlag,beidhaendiger-kampf,kampfreflexe,sturmangriff,reichweite,reiterkampf,kampfsituationen,kupperus-und-waffen,boronmir-sf,boronmir-neu` |
| 32 | Damage (TP → RS → SP → Wundschwelle, Wundeffekte) | `trefferzonen` (and every damage query in the Task 31 files, which must stay green) |
| 33 | Zustände and the cap | `schmerz,liegend` |
| 34 | Talent checks | `probe-fertigkeiten` |
| 35 | Spells and liturgies | `probe-magie` |
| 36 | Ranged combat | `probe-fernkampf` |

**Task 30 only:** remove any `RULES_FILES=none` that Task 24 put in the Makefile.

**Task 36 also:** run the full harness and record the final line in `MIGRATION.md`'s head and
in the commit. The engine's done criterion (spec §2) is `0 failed, 0 unsupported` over all 303+
situations, with every pending one naming an open ruling.

---

## Phase D — documents

### Task 37: ADR, AGENTS.md, CHANGELOG

**Goal:** The design is recorded as an ADR that supersedes ADR-0012 to 0014. AGENTS.md says
where the rules now live and how they are built and tested, and the CHANGELOG notes the new
engine package.

**Files:**
- Create: `docs/adr/0015-declarative-rules-engine.md` (format of `docs/adr/0000-template.md`)
- Modify: `docs/adr/0012-rule-website-as-single-rule-source.md`, `0013-rules-as-data-combat-engine.md`, `0014-rule-provenance-and-rule-sets.md` (status line → "Superseded by ADR-0015")
- Modify: `AGENTS.md`: the commands block (l.22–23: add `make rules-check`, `make rules-json`, `make test-rulec`, `make test-rules-engine`), and the rules-catalog paragraph (l.103). That paragraph gets a new first sentence: the new engine is `Packages/RulesEngine` fed by `rulec` from `docs/rules-rework/examples/`; domains switch over per the design's §9; until a domain has switched, the catalog paragraph that follows still describes it.
- Modify: `CHANGELOG.md` `[Unreleased]` → `Added`: "A new rules engine, built beside the old one and not yet used by any screen, …"

**Acceptance Criteria:**
- [ ] ADR-0015 states the context, the decision (the §2 decisions table), and the consequences: the cut-over gates of §9, and the vocabulary being closed. It links the design and this plan.
- [ ] The three old ADRs point to ADR-0015.
- [ ] AGENTS.md's commands list the four new targets. The rules paragraph names the package, `rulec`, the vocabulary file, and the rule that no domain switches until its screen shows every line's origin.
- [ ] The CHANGELOG entry is under `[Unreleased]` / `Added`, written for a player ("every number will say which rule it came from").

**Verify:** `grep -n "ADR-0015" docs/adr/0012-*.md docs/adr/0013-*.md docs/adr/0014-*.md AGENTS.md | wc -l` → ≥ 4

**Steps:**
- [ ] **Step 1:** Write the ADR from the template.
- [ ] **Step 2:** Edit the three status lines, AGENTS.md and the CHANGELOG.
- [ ] **Step 3: Commit**

```bash
git commit docs/adr AGENTS.md CHANGELOG.md -m "docs: ADR-0015, the declarative rules engine; AGENTS.md and CHANGELOG

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 38: `rules.db` leaves git

**Goal:** As decided on 2026-09-23 (spec §13), `Hesindion/Resources/rules.db` is a build
product, no longer committed. A build without it stops with a clear message instead of
crashing at launch (`RulesDatabase.swift:86` `fatalError`).

**Files:**
- Modify: `.gitignore` (add `Hesindion/Resources/rules.db`)
- Modify: `Makefile`: a `require-rules-db` guard that `build`, `build-iphone`, `deploy`, `deploy-kombucha`, `test` and `test-ui` depend on. The guard fails with `rules.db missing: run make rules-db (needs DSA_DATA=…/dsa_companion_data/Data)`.
- Modify: `AGENTS.md` (Data Policy and the commands block: `make rules-db` is required once after a clone)
- Run: `git rm --cached Hesindion/Resources/rules.db`

**Acceptance Criteria:**
- [ ] `git ls-files Hesindion/Resources/rules.db` prints nothing, and the file is still on disk.
- [ ] With the file moved away temporarily, `make build` exits non-zero with the guard's message and no `xcodebuild` output. With it back, `make build` succeeds.
- [ ] AGENTS.md says a fresh clone needs `make rules-db` before the first build, and where `DSA_DATA` comes from.

**Verify:** `mv Hesindion/Resources/rules.db /tmp/rules.db.bak && make build; echo $?; mv /tmp/rules.db.bak Hesindion/Resources/rules.db` → the message and a non-zero code

**Steps:**
- [ ] **Step 1:** Add the guard target and the dependencies.
- [ ] **Step 2:** Run the Verify command, then `make build` with the file in place.
- [ ] **Step 3:** Run `git rm --cached Hesindion/Resources/rules.db`, add the ignore line, and edit AGENTS.md.
- [ ] **Step 4: Commit**

```bash
git commit .gitignore Makefile AGENTS.md Hesindion/Resources/rules.db -m "build: rules.db is built, not committed

Decided 2026-09-23. make rules-db builds it; the build targets refuse to run without it.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## Appendix A: Residue guide (for Tasks 8–15)

Each pattern shows the old encoding that `migrate.py` leaves as residue and the new one. The
clause text is never touched.

### A.1 Derived values: `set` with a formula → `derive`

```yaml
# old (kampfwerte.KW1)
- set: { value: technique.at, to: "ktw + floor(max(0, MU - 8) / 3)" }
# new
- derive:
    to: at
    sum:
      - { of: ktw.current }                       # KtW of the technique in hand (fact added in Task 8)
      - { of: attr.MU, above: 8, per: 3, round: down }
```

The same applies to KW2, where the Leiteigenschaft is a fact `technique.leit` resolved by the
loadout (`{ of: technique.leit, above: 8, per: 3, round: down }` plus
`{ of: ktw.current, per: 2, round: up }`). It applies to KW3 (`{ of: attr.GE, per: 2, round: up }`)
and the Wundschwelle (`{ of: attr.KO, per: 2, round: up }`). For the LE base, use
`{ of: species.le }` + `{ of: attr.KO, times: 2 }`. Add the facts `ktw.current`,
`technique.leit` and `species.le` (owners `loadout`, `loadout`, `sheet`) to the vocabulary in
Task 8.

### A.2 One rule changing another's level: `lower` / `keep` → `useLevel`

```yaml
# old (SA_41.G1)
- lower: { condition: COND_1, source: armour, by: 1, per: tier, min: 0 }
  ruling: table-shift
# new
- useLevel: { rule: COND_1, lowerBy: level, min: 0 }
  when: { belastung.source: armour }
  ruling: table-shift
```

`lowerBy` is evaluated at the **acting** rule's own level (SA_41 at II gives 2). `as` is
evaluated at the **target** rule's level (Zäher Hund: `as: "level - 1"`). A `useLevel` carries
exactly one of the two, and rulec checks this (Task 3). `belastung.source` is a new `derived`
fact, meaning where the Belastung came from. Add it in Task 8.

### A.3 A count: `per` stays on `add`

```yaml
# old (mehrfache-verteidigung.MV1)
- add: { to: check, value: -3, per: round.defencesMade }
  id: MV1.step
# new
- add: { to: [pa, aw], value: -3, per: round.defencesMade }
```

The effect-level `id` goes: SA_923 names the clause (`replace: { line: { line: mehrfache-verteidigung.MV1 }, with: -2 }`).
`replace` swaps the replaced effect's `value` **before** `per`, and keeps its targets and `when`.
State this in `Replace`'s doc comment (Task 20), and implement it that way in Task 23.
`forbid: { second_defence_against: same_attack }` becomes
`forbid: { what: { defence: [pa, aw] } }` with `when: { round.defendedThisAttack: true }`
(a new `round` fact).

### A.4 Checks and their stages: `requires_check` / `on_failure` / `defines` → `check`, stage targets

```yaml
# old (trefferzonen.TZ8)
- requires_check:
    talent: Selbstbeherrschung
    application: "table(TZ11, hit.zone).application"
    modifier: { value: -1, per: hero.wundschwelle, of: hit.sp, round: down }
  on_failure: { effect: "table(TZ11, hit.zone)" }
# new
- check:
    of: { talent: TAL_23, with: "table(trefferzonen.TZ11.application, hit.zone)" }
    modifier: { of: hit.sp, per: wundschwelle, times: -1, round: down }
    onFailure:
      - gain: { rule: "table(trefferzonen.TZ11.effect, hit.zone)" }
```

TZ11's `table:` becomes two `provide`s, `trefferzonen.TZ11.application` and
`trefferzonen.TZ11.effect`, keyed by zone. In Task 11, let a `rule` field accept a `table(...)`
form. Torso's "zusätzlich 1W3+1 SP" is an `unencoded` part of the effect's text until a dice
value form exists. Do not invent one: list it in MIGRATION.md as an open question.

The staged 3W20 check (`fertigkeitsproben`'s `defines: { stages: … }`) has no effect of its
own. Its clauses become `none: "the procedure itself (spec §6), built into the check procedure"`,
and the per-stage rules hook in with the normal verbs:
- Fertigkeitsspezialisierung is `add: { to: check.fw, value: 2 }` with `when: { check.application: … }`.
- Begabung is `reroll: { die: { dice: any }, keep: better, max: 1, per: action }`.
- The QS table is `provide: { name: fertigkeitsproben.qs, value: {…} }`, read by `table(fertigkeitsproben.qs, check.fp)`.

### A.5 The damage chain

- The SP derivation is `derive: { to: sp, sum: [ { of: hit.tp }, { of: rs, times: -1 } ] }` with `floor: { to: sp, min: 0 }`.
- Wundschwelle comparisons are `when: { hit.sp: { atLeast: … } }` against a `derived` fact `hit.overWundschwelle` (a count computed by a proportion). Add that fact in Task 11 rather than a comparison between two facts: comparisons take constants.
- Opponent-side effects (`opponent_add` with `per` or `round`) become `add` on `opponent.<target>`, with `per` kept.

### A.6 Costs: `charge` / `costs` / `split` → `cost`

```yaml
# new (zaubermodifikationen, AsP with LeP fall-through)
- cost: { pool: asp, amount: 8, fallThrough: [le] }
# split with a minimum in one pool (Verbotene Pforten)
- cost: { pool: asp, amount: "table(zaubermodifikationen.kosten, spell.cost)", split: { pools: [asp, le], min: { asp: 1 } } }
# recurring
- cost: { pool: asp, amount: 2, every: { minutes: 5 } }
# half on failure
- cost: { pool: asp, amount: …, onFailure: 0.5 }
```

A parameter moved along a scale is `add: { to: spell.castingTime, value: 1, scale: zauberdauer }`,
where the scale is a `provide` of the ordered list.

### A.7 Processes and items: `process` / `lasts` / loaded / strung

```yaml
# new (ladezeiten)
- process: { id: laden, steps: { of: item.ladezeit }, advancedBy: { action: laden }, completes: [ { item: { instance: { loadout: weapon }, change: { loaded: true } } } ], breaksOff: { action.attack: melee } }
# Schnellladen (SA_60)
- multiply: { to: item.ladezeit, by: 0.5, round: up }
```

Use `span:` for "for the rest of the round" (`round`), "this fight" (`fight`), "while the
formation stands" (`whileFormed`) and "until removed" (`untilCleared`).

### A.8 Everything else

| Old | New |
|---|---|
| `raise: { line: X, by: n }` | `replace: { line: { line: X }, with: <old value + n> }`. If the raise depends on a level, use `add` with the same target and `when` as X, and name X in the comment |
| `cancel` / `cancels` / `exempt: { from: X }` | `suppress: { line: { line: X } }` or `{ rule: X }`, with `because` |
| `opponent_may_only` | `limit` on the opponent's side: `forbid: { what: { defence: [opponent.pa] } }` (plus `because`) for what they may not do |
| `gates: { clauses, ruleset }` | a `when: { rulesets: <slug> }` on each gated effect |
| `not_allowed` / `allow` | `forbid` / (nothing: allowed is the default) |
| `show` / `choose` | `tell` / `offer` |
| `table` / `table_for` / `scale` / `define` / `defines` | `provide` |
| `damage`, `result`, `roll`, `recompute`, `change`, `apply`, `then`, `after`, `split` at effect level | the verb whose job it is (`check`, `gain`, `cost`, `item`, `multiply`), per A.4–A.7; if none fits, report it |
| top-level `applies_when`, `applies_to_side`, `requires_ruleset`, `fokus` | `ruleset: fokus.<slug>` and/or a rule-level `require: { that: … }` (no `for`) in the first clause that states it |
| top-level `stats`, `profile`, `scale` (creatures) | `provides:` |
| clause `status`, `ruling`, `lifts`, `enables` | `ruling` moves onto the effects it concerns; the others become effects (`suppress`, `require … enables: true`) |
| `side: opponent` in `when` | the effect's targets get the `opponent.` prefix; drop the fact |
| `event` / `incoming` / `cause` in `when` | a `gmFact.<name>` fact (the GM states what happened) |
| `talent.hinderedByBelastung` | a `derived` fact `check.hinderedByBelastung`, whose value comes from the talent's `provide`d property |
