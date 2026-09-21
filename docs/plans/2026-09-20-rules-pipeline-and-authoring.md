# Rules Pipeline and Ability Authoring — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development
> (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

> **How to read this file (updated 2026-09-21, branch `feat/rules-data-pipeline`; last
> code/corpus commit `f276b14`, this update `cdcb332`).**
> This is a current-state document, not the aspirational one it started as. Each task carries a
> **Status** line naming what happened and the commit range where it landed. The **Acceptance
> Criteria** boxes are authoritative and are ticked where met, with an annotation where a criterion
> was amended or superseded by evidence. The **Steps** blocks are the recipe as originally written
> and are deliberately *not* ticked: several were amended by controller rulings during execution, so
> a step's text is a record of the plan, not a description of the code. Read the code, the ADRs and
> `docs/rules-pipeline-status.md` for what is true now.
>
> **Before running anything, read `docs/rules-pipeline-status.md`.** The calibration gate (Task 7)
> failed and no authoring wave may start.

**Goal:** Make rule data single-sourced, verifiable against the rule website, and complete — so that a
special ability reaches the app by being authored, never by being programmed.

**Architecture:** One authored YAML file per rule under `specs/rules/` holding our mechanical
encoding plus provenance and **no rule prose**; `rules.db` becomes a generated, untracked artifact;
a deterministic drift checker compares the rule website against recorded hashes; and a two-agent
authoring pipeline (author + independent verifier) proposes encodings for human review, calibrated
against a hand-authored golden corpus before it is run at scale.

**Tech Stack:** Python 3 (pyyaml, requests, beautifulsoup4, jsonschema, pytest), SQLite, Make,
Claude Code subagents (`.claude/agents/`).

**Spec:** `docs/adr/0007-rule-website-as-single-rule-source.md` and
`docs/adr/0008-rules-as-data-combat-engine.md`

## Status board

| Task | Status | Commits |
|---|---|---|
| 1 — untrack and generate `rules.db` | **done** | `ef01e80..5529a74` |
| 2 — authored-rule schema and linter | **done**, 1 fix round | `5529a74..2758121`, ADR amendment `66bac80`, rulings `4f36aab` |
| 3 — migrate the legacy effect sets | **done**, 1 fix round, 1 parked ruling | `4f36aab..7953f0d`, `faabe52` |
| 4 — the golden corpus | **done**, 1 fix round | `6806b0d..284f378` |
| 5 — `rules-sync-check` drift detection | **done**, 4 fix rounds | `faabe52..b616f48` |
| 6 — authoring subagents and driver | **done**, 2 fix rounds | `e6cbd61..ae67901` |
| 7 — calibration gate (user-ordered) | **FAILED, closed honestly — Tier 1 7/10** | `ae67901..505c721`, fix round `22ee6d2` |
| 8 — coverage ratchet | **not started** | — |
| 9 — authoring waves | **BLOCKED on Task 7's five blockers** | — |
| 10 — resolve rules to their page by name | **done** — 201/232 resolved, 10/10 golden; backfill left to a separate act | `fe7e944..14e23af` |
| 11a — withholding follows the rule graph | **done** — mechanism + withholding report, no live run | `0d55ce3` |
| 11 — measure per-rule stability | **not started**, prerequisite 11a now done | plan text `e564c86` |
| 12 — author the rules the app hardcodes | **started**: `CHAP_Reiterkampf` authored, backlog open | `c93105a..2e468fd`, `9aef3d2`, `a3508e2`, `1ceb48d` |
| 13 — GS is a species rule | **Swift done**, corpus half open (belongs to Task 12) | `f276b14` |

Work on this branch that belongs to no task: the doubled-relief fix `3c3ff91`, the "rule website"
terminology correction `877cb6c`, the combat-scoped mounted relief `030230e`, ADR-0009 and rule sets
as data `693b123`, the calibration carve-out guard `113cb27`, the lint-waiver lifetime `98125a5`, and
the `UNCLEAR-RULESET:` marker `6f90201`. All are described in `CHANGELOG.md` under `[Unreleased]`.

## Scope

This plan delivers the **data half**: the pipeline, the schema, the authoring setup, and rule
coverage. It produces working, testable software on its own — a verifiable database build, a drift
report, a linter, and an authored corpus.

The **Swift half** of ADR-0008 (`EngineResult`, the effect handlers, `DamageExpression`, maneuver
slots, reminder cards, the parity harness) is a separate plan, written after this one lands. The two
meet at the schema defined in Task 2: this plan writes the data, that plan consumes it. Task 1's
classification fix is the one Swift change included here, because it is three lines and it fixes
shipped bugs today.

## Global Constraints

- **No DSA rule prose in git.** `AGENTS.md` Data Policy. Authored files carry ids, mechanics and
  provenance only. A `text:` key anywhere under `specs/rules/` is a lint failure.
- **The agent proposes; a human commits.** No task may add a path where generated encodings reach
  `main` without review.
- **One simulator for tests** (`make test` flags) — never widen the destination set.
- **Never commit to `main`** — branch per task group, PR to merge.
- Rule IDs are Optolith IDs (`SA_62`, `ADV_5`, `COND_1`) and are the join key everywhere.

**User decisions (already made):**
- "Full data-driven engine in one pass" — no flag-guarded dual engine.
- Opponent-side effects stay GM-only (ADR-0005 reaffirmed); they are reminders, not simulation.
- "Honour the policy: effects + provenance only" — no rule text in git, `rules.db` untracked.
- Abilities stack: one Basismanöver + one active Spezialmanöver + unlimited passives per Kampfrunde.
- Completeness of rule coverage is part of the implementation, delivered by a subagent setup.

---

## File Structure

| Path | Responsibility |
|---|---|
| `specs/rules/<RULE_ID>.yaml` | One authored rule: id, subgroup, provenance, effects. No prose. |
| `specs/rules/SOURCES.yaml` | Pinned Optolith snapshot: version + per-file SHA-256. |
| `specs/rules/schema.json` | JSON Schema for an authored rule file. The contract between this plan and the engine plan. |
| `scripts/rules_lint/lint.py` | Validates every authored file against the schema + repo rules (no prose, known ids). |
| `scripts/rules_sync/check.py` | Deterministic: fetch rule-website page, normalise, hash, compare, report drift. |
| `scripts/rules_sync/propose.py` | Batches rules, fans out to subagents, collects YAML, lints, writes for review. |
| `scripts/rules_sync/normalise.py` | Shared text normalisation (used by both check and propose). |
| `scripts/build_rules_db/build_db.py` | Existing builder; reads `specs/rules/` instead of `specs/data/rules.yaml`. |
| `.claude/agents/rule-author.md` | Subagent: rule text → effect encoding. |
| `.claude/agents/rule-verifier.md` | Subagent: rule text → effect encoding, independently; diffs against the author's. |
| `tests/rules/` | pytest suite for linter, normaliser, checker, and the coverage ratchet. |

Deleted by this plan: `specs/data/rules.yaml`, `HARDCODED_EFFECTS` in
`scripts/scrape_effects/scrape_effects.py`.

---

### Task 1: Stop shipping a stale, committed database

**Status: DONE** — `ef01e80..5529a74`. Review clean. One deferred minor (a redundant retained
assertion in `HesindionTests/HeroImportTests.swift`), listed in `docs/rules-pipeline-status.md` §7.

**Goal:** `rules.db` becomes a generated, untracked artifact with a reproducible build, and the
import classification stops depending on hand-authored effects.

**Files:**
- Modify: `Makefile` (new targets, after the `clean:` target at line 116)
- Modify: `Hesindion/Services/OptolithImportService.swift:463-467`
- Create: `specs/rules/SOURCES.yaml`
- Create: `scripts/build_rules_db/verify_db.py`
- Modify: `HesindionTests/HeroImportTests.swift` (assert the split, not the union)
- Modify: `AGENTS.md` (Build & Run: the rules-db step)

**Acceptance Criteria:**
- [x] `git ls-files Hesindion/Resources/rules.db` prints nothing.
- [x] `make rules-db` rebuilds the database from the pinned source; `make rules-db-verify` exits 0.
- [x] `make rules-db` fails with a named message when the source directory is missing or its
      checksums do not match `SOURCES.yaml`.
- [x] Importing `docs/sample_heros/Boronmir Siebenfeld von Greifenfurt.json` puts `SA_884` and
      `SA_661` in `combatSpecialAbilities`, not `generalSpecialAbilities`.
- [x] `hero.hasPlaenklerFormation == true` for that hero.

**Verify:** `make rules-db && make rules-db-verify && make test-ui` → all green.

**Steps:**

- [ ] **Step 1: Untrack the database, keeping the file on disk**

```bash
git rm --cached Hesindion/Resources/rules.db
git check-ignore -v Hesindion/Resources/rules.db   # now reports .gitignore:5 — the entry finally bites
```

- [ ] **Step 2: Pin the source data**

```bash
python3 - <<'PY' > specs/rules/SOURCES.yaml
import hashlib, pathlib, yaml
root = pathlib.Path("/Users/SamuelvonBaussnern/proj/50_priv/dsa_companion_data/Data/de-DE")
files = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.glob("*.yaml"))}
print(yaml.safe_dump({"optolith": {"path_hint": str(root), "files": files}}, sort_keys=True))
PY
```

- [ ] **Step 3: Write the verifier** — `scripts/build_rules_db/verify_db.py`

```python
"""Rebuild rules.db to a temp path and compare canonical dumps.

SQLite does not guarantee byte-stable files, so compare `.dump` output, not bytes.
"""
import hashlib, subprocess, sys, tempfile, pathlib

def dump_hash(db: pathlib.Path) -> str:
    out = subprocess.run(["sqlite3", str(db), ".dump"], capture_output=True, check=True).stdout
    return hashlib.sha256(out).hexdigest()

def main(shipped: str, source: str, rules: str) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        fresh = pathlib.Path(tmp) / "rules.db"
        subprocess.run([sys.executable, "scripts/build_rules_db/build_db.py",
                        "--source", source, "--effects", rules, "--output", str(fresh)], check=True)
        if dump_hash(pathlib.Path(shipped)) != dump_hash(fresh):
            print("rules.db is stale — run `make rules-db`", file=sys.stderr)
            return 1
    print("rules.db is current")
    return 0

if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
```

- [ ] **Step 4: Add the Makefile targets** (after `clean:`)

```makefile
RULES_SOURCE ?= /Users/SamuelvonBaussnern/proj/50_priv/dsa_companion_data/Data
RULES_DB     := Hesindion/Resources/rules.db

RULES_EFFECTS ?= specs/data/rules.yaml     # Task 3 flips this to specs/rules

rules-db:
	@test -d "$(RULES_SOURCE)" || { echo "Rules source not found: $(RULES_SOURCE) (set RULES_SOURCE=…)"; exit 1; }
	python3 scripts/build_rules_db/check_sources.py --source "$(RULES_SOURCE)" --pins specs/rules/SOURCES.yaml
	python3 scripts/build_rules_db/build_db.py --source "$(RULES_SOURCE)" --effects "$(RULES_EFFECTS)" --output "$(RULES_DB)"

rules-db-verify:
	python3 scripts/build_rules_db/verify_db.py "$(RULES_DB)" "$(RULES_SOURCE)" "$(RULES_EFFECTS)"
```

**Controller ruling (pre-flight):** `build_db.py` only learns to read a *directory* of rule files in
Task 3, so this task keeps the legacy single-file path in `RULES_EFFECTS`. Task 3 flips it. Do not
point it at `specs/rules` here — the build will fail.

- [ ] **Step 5: Fix the classification** — `OptolithImportService.swift:463-467`

```swift
/// A rule is a combat special ability when the ruleset says so — Kampf, Kampfstile
/// (bewaffnet/unbewaffnet), Kampf (erweitert) and Befehle — not when someone has already
/// hand-written an effect for it. See ADR-0008.
private func isCombatSpecialAbility(id: String) -> Bool {
    guard let groupId = rules.lookupGroupId(id) else { return false }
    return [3, 9, 10, 11, 12].contains(groupId)
}
```

Add `lookupGroupId(_:)` to `RulesDatabase` beside `lookupEffects`:

```swift
func lookupGroupId(_ ruleId: String) -> Int? {
    let sql = "SELECT group_id FROM rules WHERE id = ?"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, ruleId, -1, SQLITE_TRANSIENT)
    guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
    return Int(sqlite3_column_int(stmt, 0))
}
```

- [ ] **Step 6: Make the import test assert the split it deliberately avoided**

Replace `HeroImportTests.swift:62-64`:

```swift
// Combat SAs are classified from the ruleset's own grouping (ADR-0008), so Plänkler-Formation
// and Golgariten-Stil are combat abilities even though only one of them has authored effects.
#expect(hero.combatSpecialAbilities.contains { $0.ruleId == "SA_884" })
#expect(hero.combatSpecialAbilities.contains { $0.ruleId == "SA_661" })
#expect(hero.generalSpecialAbilities.allSatisfy { !$0.ruleId.hasPrefix("SA_88") })
```

- [ ] **Step 7: Run and commit**

```bash
make rules-db && make rules-db-verify && make test-ui
git add -A && git commit -m "build(rules): generate rules.db, pin its source, classify combat SAs by group"
```

---

### Task 2: The authored-rule schema and its linter

**Status: DONE** — `5529a74..2758121`, after one fix round of eleven findings. The review passed the
spec and did *not* approve the first schema as a 232-file contract: `modifier` gained required
`target` and `scope` plus `side: hero|opponent`, `dice` gained `recipient`, `actionEconomy` gained
`forbids` beside `grants`, and a ninth effect type `recovery` was added — ADR-0008 was amended to
nine types in `66bac80`, before any file was authored, because that was the cheap moment. Six minors
were deferred; two of them are closed today and the rest are in
`docs/rules-pipeline-status.md` §7.

**Goal:** An authored rule file has one machine-checkable shape, and the shape is the contract the
engine plan consumes.

**Files:**
- Create: `specs/rules/schema.json`
- Create: `scripts/rules_lint/lint.py`, `scripts/rules_lint/requirements.txt`
- Create: `tests/rules/test_lint.py`
- Modify: `Makefile` (target `rules-lint`)

**Acceptance Criteria:**
- [x] A valid file passes; unknown effect `type`, unknown condition predicate, missing `source.hash`
      and a `text:` key each fail with a message naming the file and the offending key.
- [x] `make rules-lint` exits non-zero if any file under `specs/rules/` is invalid.

**Verify:** `python3 -m pytest tests/rules/test_lint.py -v` → 6 passed.

**Steps:**

- [ ] **Step 1: Write the schema** — `specs/rules/schema.json` (draft 2020-12, abridged to its
      distinctive parts; the eight effect types and ten predicates of ADR-0008 are closed enums)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["id", "subgroup", "source"],
  "additionalProperties": false,
  "properties": {
    "id":       { "type": "string", "pattern": "^(SA|ADV|DISADV|COND|CT)_[0-9]+$" },
    "subgroup": { "enum": ["passiv", "basismanoever", "spezialmanoever", "none"] },
    "source": {
      "type": "object",
      "required": ["url", "checked", "hash"],
      "additionalProperties": false,
      "properties": {
        "url":     { "type": "string", "format": "uri" },
        "book":    { "type": "string" },
        "page":    { "type": "integer" },
        "checked": { "type": "string", "format": "date" },
        "hash":    { "type": "string", "pattern": "^sha256:[0-9a-f]{64}$" }
      }
    },
    "excludes": { "type": "array", "items": { "type": "string" } },
    "effects": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["type"],
        "properties": {
          "type": { "enum": ["modifier", "parameterOverride", "dice", "actionEconomy",
                             "probe", "legality", "stateGain", "reminder"] },
          "tier": { "type": "integer", "minimum": 1, "maximum": 3 },
          "when": {
            "type": "array",
            "items": {
              "type": "object",
              "maxProperties": 1,
              "propertyNames": { "enum": ["combatTechnique", "targetState", "mounted",
                                          "targetSize", "attribute", "runUp", "weaponReach",
                                          "defenseCount", "armorAtMost", "offHandWeapon"] }
            }
          }
        }
      }
    }
  }
}
```

- [ ] **Step 2: Write the failing test first** — `tests/rules/test_lint.py`

```python
import pathlib, textwrap, pytest
from scripts.rules_lint.lint import lint_file

VALID = textwrap.dedent("""
    id: SA_62
    subgroup: spezialmanoever
    source:
      url: https://dsa.ulisses-regelwiki.de/SA_62.html
      book: US25001
      page: 249
      checked: 2026-09-20
      hash: sha256:{h}
    excludes: [SA_48]
    effects:
      - type: dice
        add: "2 + ceil(self.gs / 2)"
        when: [{{runUp: 4}}, {{attribute: {{gs: 4}}}}]
""").format(h="0" * 64)

def write(tmp_path: pathlib.Path, body: str) -> pathlib.Path:
    p = tmp_path / "SA_62.yaml"; p.write_text(body); return p

def test_valid_file_passes(tmp_path):
    assert lint_file(write(tmp_path, VALID)) == []

def test_rule_text_is_rejected(tmp_path):
    errs = lint_file(write(tmp_path, VALID + "text: Das Manöver …\n"))
    assert any("text" in e and "Data Policy" in e for e in errs)

def test_unknown_effect_type_is_rejected(tmp_path):
    errs = lint_file(write(tmp_path, VALID.replace("type: dice", "type: teleport")))
    assert any("teleport" in e for e in errs)

def test_unknown_predicate_is_rejected(tmp_path):
    errs = lint_file(write(tmp_path, VALID.replace("runUp: 4", "phaseOfMoon: full")))
    assert any("phaseOfMoon" in e for e in errs)

def test_missing_hash_is_rejected(tmp_path):
    errs = lint_file(write(tmp_path, VALID.replace(f"  hash: sha256:{'0'*64}\n", "")))
    assert any("hash" in e for e in errs)

def test_filename_must_match_id(tmp_path):
    p = tmp_path / "SA_63.yaml"; p.write_text(VALID)
    assert any("filename" in e for e in lint_file(p))
```

Run: `python3 -m pytest tests/rules/test_lint.py -v` → FAIL (`ModuleNotFoundError: scripts.rules_lint`).

- [ ] **Step 3: Implement the linter** — `scripts/rules_lint/lint.py`

```python
"""Validate authored rule files. Schema first, then the repo rules the schema cannot express."""
import json, pathlib, sys
import yaml
from jsonschema import Draft202012Validator

SCHEMA = json.loads((pathlib.Path(__file__).parents[2] / "specs/rules/schema.json").read_text())
VALIDATOR = Draft202012Validator(SCHEMA)

def lint_file(path: pathlib.Path) -> list[str]:
    errors: list[str] = []
    try:
        doc = yaml.safe_load(path.read_text()) or {}
    except yaml.YAMLError as exc:
        return [f"{path.name}: unparseable YAML: {exc}"]

    if "text" in doc or any("text" in e for e in doc.get("effects", []) if isinstance(e, dict)):
        errors.append(f"{path.name}: 'text' is not allowed — rule prose stays out of git (Data Policy)")

    for err in VALIDATOR.iter_errors(doc):
        errors.append(f"{path.name}: {'.'.join(str(p) for p in err.absolute_path) or '<root>'}: {err.message}")

    if doc.get("id") and path.stem != doc["id"]:
        errors.append(f"{path.name}: filename must match id ({doc['id']}.yaml)")
    return errors

def main(root: str = "specs/rules") -> int:
    files = sorted(pathlib.Path(root).glob("*.yaml"))
    errors = [e for f in files if f.name != "SOURCES.yaml" for e in lint_file(f)]
    for e in errors:
        print(e, file=sys.stderr)
    print(f"{len(files)} rule file(s), {len(errors)} error(s)")
    return 1 if errors else 0

if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
```

- [ ] **Step 4: Run the tests** → 6 passed. Add `rules-lint: \n\tpython3 scripts/rules_lint/lint.py` to the Makefile.

- [ ] **Step 5: Commit** — `git commit -m "feat(rules): authored-rule schema and linter"`

---

### Task 3: Migrate the existing 26 effect sets, delete the duplicates

**Status: DONE** — `4f36aab..7953f0d`, after one fix round. 79 legacy rows became 89 authored effect
rows: the migration had flattened three leveled rules and so kept the worse of two duplicate legacy
sources. One ruling is **parked, not settled**: `SA_41`'s `scope: all` cannot be right, because
`CheckDomain` has no domain for INI or GS at all — recorded in ADR-0008's Consequences (`faabe52`)
as a binding input to the engine plan rather than settled by picking a string. Do not "fix" it by
changing the scope value.

**Goal:** One authored store. `specs/data/rules.yaml` and `HARDCODED_EFFECTS` are gone, and the
database builds from `specs/rules/`.

**Files:**
- Create: `specs/rules/*.yaml` (26 files)
- Create: `scripts/rules_lint/migrate_legacy.py` (one-shot, deleted in the same commit after running)
- Modify: `scripts/build_rules_db/build_db.py` (`--effects` takes a directory)
- Delete: `specs/data/rules.yaml`, `HARDCODED_EFFECTS` block in `scripts/scrape_effects/scrape_effects.py`

**Acceptance Criteria:**
- [x] 26 files under `specs/rules/`, all passing `make rules-lint`. *(28 today: `SA_62`, authored
      in Task 4, and `CHAP_Reiterkampf`, authored after the chapter-rule amendments.)*
- [x] `make rules-db && make rules-db-verify` green.
- [x] **No legacy row is lost.** Every one of the 79 rows maps per the ten-row table below, and the
      migrator prints a reconciliation report (legacy row → authored effect) that accounts for all
      79. The count may exceed 79 where a row needs a sibling effect.
- [x] The `effects` table carries a new `payload` column holding each authored effect as JSON.
- [x] The eight rows whose free-text `condition` is not a combat predicate carry a `gmFlag`
      predicate — they must **not** become unconditional.
- [x] `grep -rn "HARDCODED_EFFECTS\|specs/data/rules.yaml" .` returns nothing. *(Amended by
      controller ruling to scope to code paths — `Makefile`, `scripts/`, `specs/`, `Hesindion/`.
      `CHANGELOG.md` and the ADRs cannot describe a removal without naming what was removed, and a
      true statement about the past stays.)*

**Verify:**
```bash
make rules-lint && make rules-db && make rules-db-verify
sqlite3 Hesindion/Resources/rules.db "select count(*) from effects where payload is null;"   # → 0
```

**Controller rulings (three, made after querying the live data):**

1. **An eleventh `when` predicate, `gmFlag`.** Ten legacy rows carry a free-text `condition`; only
   `mounted` (SA_43, SA_661) maps to an existing predicate. The other eight — `SA_22` "at known
   location", `SA_40` "ambush detection", `SA_661` "mounted vs foot fighter", `ADV_75` "anaesthesia
   or intoxicated", `DISADV_34` "principles violated", `DISADV_35` ×2 — would otherwise become
   **unconditional**, which is worse than today's behaviour: `SA_22` would grant +1 Gassenwissen
   always. `gmFlag` takes a camelCase slug (`knownLocation`, `ambush`, `principlesViolated`),
   constrained by `pattern: ^[a-z][A-Za-z]+$` so prose cannot enter through it. The engine surfaces
   it as a GM toggle, exactly as `ModifierContext.targetIsSurprised` already works under ADR-0005.
   Add it to `specs/rules/schema.json` and to ADR-0008's predicate list.
2. **`effects` gains a `payload` TEXT column** holding the authored effect as JSON verbatim, with
   the legacy columns still populated where they map directly (`type`, `target`→`attribute`,
   `value`, `scope`, `tier`→`level`). Adding a schema field later then costs no DB migration.
3. **A byte-identical round-trip is impossible** — the `description` column has no authored home —
   so the criterion is the reconciliation report, not a row count.

**Steps:**

- [ ] **Step 1: Record the before-state** — `sqlite3 … "select rule_id,type,attribute,value,scope,condition from effects order by 1,2,3" > /tmp/effects_before.txt`
- [ ] **Step 2: Write and run the one-shot migrator** — read `specs/data/rules.yaml`, emit one file
      per rule with the **unverified provenance marker**
      `source: {url: https://dsa.ulisses-regelwiki.de/UNVERIFIED, checked: 1970-01-01, hash: sha256:<64×0>}`
      and the existing effects mapped onto the new types. **The complete mapping** (controller
      ruling after the Task 2 review verified every legacy row against the schema — the plan's
      original three-entry table was wrong in two places):

      | legacy type | rows | new encoding |
      |---|---:|---|
      | `modifier` | 56 | `modifier` **with `target` and `scope` carried over** |
      | `incapacitated` | 6 | `actionEconomy` with `forbids: allActions` |
      | `recovery` | 3 | `recovery` |
      | `opponentModifier` | 3 | `modifier` with `side: opponent` |
      | `damageModifier` | 3 | `dice` |
      | `restriction` | 2 | `actionEconomy` with **`forbids`**, not `grants` — these are removals |
      | `negation` | 2 | **`parameterOverride` … `set: 0`**, not `legality` |
      | `narrative` | 2 | `reminder` |
      | `stateGain` | 1 | `stateGain` |
      | `damageRedirect` | 1 | `dice` with `recipient: defenderShield` |

      **Controller ruling (pre-flight, amended):** the marker URL must match the schema's enforced
      `pattern: ^https?://`, so `TODO` is rejected. (The original ruling cited `format: uri`; the
      Task 2 review established that `format: uri` is not enforced by `jsonschema` at all, and it
      was replaced by the pattern.) `check.py` (Task 5) recognises the zero hash as `unverified`.
- [ ] **Step 3: Teach `build_db.py` to read a directory** — replace the single-file load of
      `--effects` with `sorted(pathlib.Path(arg).glob("*.yaml"))`, skipping `SOURCES.yaml` and
      `schema.json`, and keep the same insert path.
- [ ] **Step 4: Rebuild, diff against `/tmp/effects_before.txt`** — the two must be identical apart
      from the renamed types. Investigate any other difference before continuing.
- [ ] **Step 5: Flip `RULES_EFFECTS` in the Makefile to `specs/rules`**, then delete
      `specs/data/rules.yaml`, the `HARDCODED_EFFECTS` list, the scraper's fallback branch, and the
      migrator itself. Commit.

---

### Task 4: The golden corpus — ten rules authored by hand

**Status: DONE** — `6806b0d..284f378`, after one fix round of five rulings and nine findings. The
reviewer re-fetched all ten URLs itself: 10/10 serve the claimed rule and 10/10 hashes reproduce
from a cold cache. Three substantive rules findings came out of actually consulting the site, all
vindicating ADR-0007's premise, and the pass also found the first of this branch's two live app bugs
(the doubled Belastungsgewöhnung relief, fixed in `3c3ff91`). `tests/rules/golden/` holds a
`MANIFEST.yaml` of hashes rather than duplicate rule bodies — a second copy that can silently
diverge from what it calibrates would let Task 7 grade against a stale reference and pass.

> **Controller ruling (pre-flight): Task 5 runs before this one.** A real `source.hash` cannot be
> computed without `scripts/rules_sync/normalise.py`, and this task's Verify calls `check.py`. Both
> arrive in Task 5.

**Goal:** A reference encoding that the agent pipeline must reproduce before it is trusted with 232.

**Files:**
- Modify: 9 migrated files (`SA_40, 41, 43, 48, 59, 65, 66, 67, 661`) — real provenance, real hashes
- Create: `specs/rules/SA_62.yaml` (Sturmangriff — the rule that started this)
- Create: `tests/rules/golden/` (a copy of the ten, used as pipeline fixtures)

**Acceptance Criteria:**
- [x] Each of the ten has a real `source.url`, `book`, `page`, today's `checked`, and a hash that
      matches the live rule-website text.
- [x] `SA_62` encodes: `runUp ≥ 4` and `gs ≥ 4` preconditions, `dice: 2 + ceil(self.gs / 2)`,
      `actionEconomy: opponentPassierschlagOnFailure`, `excludes: [SA_48]`, `subgroup: spezialmanoever`.
- [~] **SUPERSEDED by the evidence.** `SA_43`'s BE effect carries `when: [{mounted: true}]` — the
      condition the dead loader dropped. *There is no BE effect on `SA_43` any more: the clause is
      the mounted-combat chapter page's, not the ability's, and it is authored in
      `CHAP_Reiterkampf`. The `mounted` condition survives on `SA_43`'s `legality` row, which is
      where the page's clause puts it. An acceptance criterion written before the evidence does not
      outrank the evidence. See `docs/rules-pipeline-status.md` §8 — the first reason given for the
      removal was wrong and the correction is itself a settled item.*

**Verify:** `make rules-lint && python3 -m scripts.rules_sync.check --only specs/rules/SA_62.yaml` → `0 drifted`.
*(The `-m` form is required — invoking the file by path raises `ModuleNotFoundError`, as the Makefile
target already knew. This was a defect in the plan text, not in the code.)*

**Steps:**

- [ ] **Step 1: For each of the ten, open its rule-website page, copy the URL, and record `book`/`page`
      from the Optolith `src:` block** (`SpecialAbilities.yaml` carries `src: [{id, firstPage}]`).
- [ ] **Step 2: Author `SA_62.yaml`** (this is the shape every later rule follows):

```yaml
id: SA_62
subgroup: spezialmanoever
source:
  url: https://dsa.ulisses-regelwiki.de/…
  book: US25001
  page: 249
  checked: 2026-09-20
  hash: sha256:…
excludes: [SA_48]          # combination ban stated by the rule
effects:
  - type: dice
    add: "2 + ceil(self.gs / 2)"       # bonus damage clause
    when: [{runUp: 4}, {attribute: {gs: 4}}]
  - type: actionEconomy
    grants: opponentPassierschlagOnFailure
  - type: reminder                      # defensibility clause, GM-adjudicated
```

**Note the comments.** They describe *which clause* an effect came from, in English. Quoting the
German rule text into a comment walks prose into git through the back door and defeats the Data
Policy — the linter scans comments for exactly this.

Note the rounding: `ceil`, per ADR-0006 — the rule says *"die halbe GS"*, not *"je volle 2"*.

- [ ] **Step 3: Copy the ten into `tests/rules/golden/` and commit.** These files are the calibration
      target in Task 7; changing one means re-running calibration.

---

### Task 5: `rules-sync-check` — deterministic drift detection

**Status: DONE** — `faabe52..b616f48`, after **four** fix rounds, and it ran before Task 4 by
pre-flight ruling (a real `source.hash` cannot be computed without the normaliser). The first
implementation was fatal as built: the site has no `<main>`, so every page fell through to `<body>`,
which carries a per-response anti-spam challenge — three fetches of one page gave three different
hashes and drift detection would have reported 100% drift forever. The binding acceptance test
became idempotence across two live fetches rather than fixture equality. Two deferred minors, in
`docs/rules-pipeline-status.md` §7.

**Goal:** Answer "which of our encodings are based on text the rule website has since changed?" with no model
involved.

**Files:**
- Create: `scripts/rules_sync/normalise.py`, `scripts/rules_sync/check.py`
- Create: `tests/rules/test_normalise.py`, `tests/rules/fixtures/*.html`
- Modify: `Makefile` (`rules-sync-check`)

**Acceptance Criteria:**
- [x] Normalisation is stable across whitespace, `<br>` variants and non-breaking spaces — the same
      rule text hashes identically from two differently-formatted captures of the same page.
- [x] `check.py` reports each rule as `ok`, `drifted` or `unverified` (the `1970-01-01` marker),
      exits 0 when nothing has drifted, 1 otherwise.
- [x] Requests are cached on disk and rate-limited to one per second (reuse `DELAY` from the existing
      scraper); a cached run makes no network calls.

**Verify:** `python3 -m pytest tests/rules/test_normalise.py -v && make rules-sync-check`

**Steps:**

- [ ] **Step 1: Write the normaliser test first** — two fixture HTML files with the same rule text but
      different markup must produce the same `sha256`.
- [ ] **Step 2: Implement `normalise.py`** — BeautifulSoup text extraction, `<br>` → `\n`, NBSP → space,
      collapse runs of whitespace, strip, NFC-normalise, then `sha256`.
- [ ] **Step 3: Implement `check.py`** — for each authored file, fetch `source.url` (cache under
      `.cache/rules_sync/`), normalise, compare to `source.hash`, print a table, exit accordingly.
- [ ] **Step 4: Commit.**

---

### Task 6: The authoring subagents and their driver

**Status: DONE** — `e6cbd61..ae67901`, after two fix rounds. The plan's driver design was
unimplementable as written (a shell script cannot dispatch subagents), resolved with a pluggable
Runner so the test suite makes zero model and zero network calls. **The task's own headline is that
its first end-to-end run measured nothing**: with the repository as cwd both agents read the
hand-authored file and returned it byte-identical. See `docs/rules-pipeline-status.md` §2 — this is
why byte equality with the golden corpus is now evidence of contamination. Three deferred minors
plus the security position, both in §7 and §8 of that document; the security position is now
recorded as an amendment to ADR-0007.

**Goal:** Rule text in, reviewable encoding out — with a second agent that never sees the first one's
answer.

**Files:**
- Create: `.claude/agents/rule-author.md`, `.claude/agents/rule-verifier.md`
- Create: `scripts/rules_sync/propose.py`
- Create: `tests/rules/test_propose.py`

**Acceptance Criteria:**
- [x] `propose.py --ids SA_63,SA_56` writes `specs/rules/SA_63.yaml` and `SA_56.yaml`, each passing
      the linter, plus `.proposals/<id>.review.md` holding the author's rationale, the verifier's
      independent encoding, and their diff.
- [x] Where author and verifier disagree, the review file says so at the top and the YAML is written
      with the disagreement as a comment — never silently resolved. *(Not literally met and could
      not be: `lint.py` rejects every `#` comment as a Data Policy hole, while the same criterion
      demands a lint-clean file. Resolved as a root `note` with a `DISAGREEMENT:` prefix, greppable
      like `UNENCODED:`, which `make rules-lint` then rejects until a human resolves it — so a
      proposal cannot be committed unresolved. Where the author's note will not fit inside the
      schema's 200-character cap beside the marker, the marker wins and the note survives verbatim
      in the review file.)*
- [x] The driver batches at most 12 rules per author agent and runs batches in parallel.
- [x] Selectors: `--ids`, **and `--group N` / `--subgroup N,M`** (Task 9 drives waves by group and
      subgroup, so the flags ship here — controller ruling, pre-flight).
- [x] `.proposals/` is added to `.gitignore`. Review files quote rule clauses in their rationale, so
      they must never be committable (Global Constraint: no prose in git).
- [x] Nothing is committed by the script, and `git status` after a run shows only untracked/modified
      files for review.

**Verify:** `python3 -m pytest tests/rules/test_propose.py -v` (driver logic against recorded agent
outputs — no live agent calls in tests).

**Steps:**

- [ ] **Step 1: Write `.claude/agents/rule-author.md`**

```markdown
---
name: rule-author
description: Encode DSA 5 rule text as Hesindion effect rows. Use for authoring specs/rules/*.yaml from rule-website text.
tools: Read, Write, Grep
---

You encode DSA 5 rules as structured effects for a rules engine. You are given a rule's id,
its rule-website text, and its `subgroup`. You return YAML conforming to `specs/rules/schema.json`.

## Hard rules

1. **Never include the rule text.** No `text:` key, no prose quoted into `description:`. Repo policy.
2. **Encode only what the text states.** No inference from other rules, no "usually", no filling gaps.
3. **What the app cannot adjudicate becomes a `reminder`.** The opponent is not modelled (ADR-0005):
   anything that happens *to the opponent* — damage they take, a status they gain, a weapon they
   drop — is a reminder, never a `stateGain` on the hero.
4. **Rounding is `ceil`** unless the text says *"je volle N"* (ADR-0006).
5. **Conditions come from the closed predicate list** in the schema. If a precondition does not fit
   one of the ten, emit a `reminder` stating it instead of inventing a predicate.
6. **When the text is ambiguous, say so** in your rationale and encode the narrower reading.

## Output

Return exactly two blocks per rule: the YAML, then a short rationale naming, for each effect row,
the clause of the rule text it came from.

## Worked example

<the SA_62 encoding from specs/rules/SA_62.yaml, with its rationale>
```

- [ ] **Step 2: Write `.claude/agents/rule-verifier.md`** — the same brief, plus: it receives the rule
      text *only* (never the author's YAML), produces its own encoding, and the driver diffs the two.
      Give it the closing instruction: *"You are checking whether two independent readings of the
      same rule text agree. Do not attempt to guess what another agent produced."*
- [ ] **Step 3: Implement `propose.py`** — the driver:

```python
"""Fan rules out to authoring subagents, collect, lint, and write for human review.

Determinism boundary: this script does the batching, the file I/O and the diffing.
The model does the encoding. Nothing here commits.
"""
# 1. resolve ids → (id, subgroup, text) from the local rules.db (text is an input, never an output)
# 2. chunk into batches of <= 12
# 3. for each batch: dispatch rule-author; in parallel dispatch rule-verifier per rule
# 4. parse both YAML payloads; lint each; diff author vs verifier effect rows
# 5. write specs/rules/<id>.yaml (+ disagreement comment) and .proposals/<id>.review.md
# 6. print a summary table: id, agree/disagree, lint status
```

- [ ] **Step 4: Test the driver against recorded outputs** — `tests/rules/test_propose.py` feeds
      canned author/verifier payloads and asserts: agreement writes a clean file; disagreement writes
      the comment and flags the summary; a lint failure aborts that rule without writing.
- [ ] **Step 5: Commit.**

---

### Task 7: Calibration gate — the pipeline must reproduce the golden corpus

**Status: FAILED, and closed honestly as a failure** — `ae67901..505c721`, fix round `22ee6d2`. The
acceptance criteria below are **not met** and are deliberately left unticked. Tier 1 scored 7 of 10
and that is the best of four runs of the same ten rules; pooled it is 23/40 ≈ 0.58 with a 95%
interval of roughly [0.40, 0.89]. The three failures are one genuine pipeline error and two caused
by the driver feeding agents the Optolith seed text while ADR-0007 makes the rule website normative.
**The full result, the rubric, the five blockers and the variance datum are in
`docs/rules-pipeline-status.md` §§1–4. Do not start a wave.** Note that criterion 1 below says
"reproduces the hand-authored effect rows for all ten" — read §2 of that document beside it, because
byte-identical output now means the run was contaminated, not that it passed.

**Goal:** Prove the authoring setup is trustworthy before it is pointed at 232 rules.

> **USER-ORDERED GATE — NON-SKIPPABLE.** This task was requested by the user in the current
> conversation. It MUST NOT be closed by walking around it, by declaring it "verified inline", or by
> substituting a cheaper check. Close only after every acceptance criterion has been re-validated
> independently, with output captured.

**Files:**
- Create: `tests/rules/test_calibration.py`
- Modify: `.claude/agents/rule-author.md` (iterate the brief until it passes)

**Acceptance Criteria:**
- [ ] Running `propose.py` over the ten golden ids, into a scratch directory, reproduces the
      hand-authored effect rows for **all ten** — same types, same values, same conditions, same
      tiers. Field order and comments may differ; semantics may not.
- [ ] Author and verifier agree on all ten.
- [ ] The run's summary table is captured in the task's close comment.

**Verify:**
```bash
python3 -m scripts.rules_sync.propose --ids $(ls tests/rules/golden | sed 's/.yaml//' | paste -sd, -) \
    --out /tmp/calibration && python3 -m pytest tests/rules/test_calibration.py -v
```
Expected: `10 passed`, summary table showing `agree` for all ten.

*As built this is wrong in two ways. `tests/rules/golden/` holds only `MANIFEST.yaml` now — the
duplicate rule bodies were deleted in Task 4's fix round precisely so a second copy could not
silently diverge — so the id list comes from the manifest, not from `ls`. And `test_calibration.py`
grades a **recorded** run under `tests/rules/calibration/<date>-<model>/` rather than running the
pipeline, so `pytest` costs no model calls; re-recording is a deliberate act that updates `RUN.yaml`
in the same commit. The actual command that produced the recorded run is `RUN.yaml`'s `command:`
field.*

**Steps:**

- [ ] **Step 1: Write the comparison test** — load each golden file and its scratch counterpart,
      normalise both (sort effect rows, drop comments) and assert equality, reporting the first
      differing row by rule id and index.
- [ ] **Step 2: Run the pipeline. Expect failures on the first attempt** — the likely ones are
      rounding (`ceil` vs integer division), opponent-side effects encoded as `stateGain` instead of
      `reminder`, and invented predicates.
- [ ] **Step 3: Fix the *brief*, never the golden files.** Each failure is a missing instruction in
      `rule-author.md`. Re-run. Iterate until ten of ten.
- [ ] **Step 4: Record the passing summary in the commit message and close the gate.**

---

### Task 8: Coverage ratchet

**Status: NOT STARTED.** Nothing exists: no `tests/rules/test_coverage.py`, no
`specs/rules/COVERAGE.md`, no `HesindionTests/RuleCoverageTests.swift`. It does not depend on the
calibration gate and could be done at any time. Note that ADR-0008's amendment records its known
limit in advance: the ratchet counts abilities and cannot count a chapter rule, which has no
Optolith id.

**Goal:** Missing coverage becomes a number that can only go down, and absence can never be silent.

**Files:**
- Create: `tests/rules/test_coverage.py`
- Create: `specs/rules/COVERAGE.md` (generated report, regenerated by the test)
- Create: `HesindionTests/RuleCoverageTests.swift`

**Acceptance Criteria:**
- [ ] The Python test counts combat rules (`group_id IN (3,9,10,11,12)`) without authored effects and
      fails if the count exceeds the recorded baseline in `COVERAGE.md`.
- [ ] The Swift test asserts that for every rule on the `UITestHero`, the engine yields either
      structured effects or a reminder — never nothing. This is the test that would have caught
      Sturmangriff.
- [ ] `COVERAGE.md` lists, by subgroup, which rules are authored and which are reminder-only.

**Verify:** `python3 -m pytest tests/rules/test_coverage.py -v && make test-ui`

**Steps:**

- [ ] **Step 1: Write the Python ratchet** — read the baseline integer from `COVERAGE.md`'s front
      matter, compare, and rewrite the report on success so the baseline follows coverage downward.
- [ ] **Step 2: Write the Swift no-silent-absence test** — for each `ruleId` on the seeded hero,
      assert `!engine.resolve(context).isEmptyFor(ruleId)`. Until the engine plan lands, assert the
      weaker form: every rule id resolves to a row in `effects` **or** a non-empty `rules_i18n.description`.
- [ ] **Step 3: Commit.**

---

### Task 9: Authoring waves

**Status: BLOCKED.** The calibration gate failed; five blockers stand between here and a wave, and
they are enumerated in `docs/rules-pipeline-status.md` §3. At the measured rate a 222-rule wave
would produce roughly 65–90 wrong encodings, the majority arriving as `agree / ok / written`. When
it does run, **a wave is a review queue, not an authoring pass.**

**Goal:** Complete coverage of what the engine can express, in reviewable increments.

**Files:** `specs/rules/*.yaml` (one PR per wave)

**Acceptance Criteria:**
- [ ] Wave 1 — all 5 Basismanöver and all 35 Spezialmanöver of group 3 (40 rules).
- [ ] Wave 2 — the 49 passive abilities of group 3.
- [ ] Wave 3 — groups 9, 10, 11, 12 (Kampfstile, Kampf erweitert, Befehle; 143 rules).
- [ ] Every wave: `make rules-lint`, `make rules-sync-check`, coverage ratchet down, one PR, human
      review of every `.proposals/*.review.md` where author and verifier disagreed.
- [ ] No wave merges with an unresolved disagreement.

**Verify per wave:**
```bash
make rules-lint && make rules-sync-check && python3 -m pytest tests/rules/ -v && make rules-db-verify
```

**Steps:**

- [ ] **Step 1: Wave 1** — `propose.py --group 3 --subgroup 2,3`. Review, resolve disagreements,
      commit, PR. This wave includes every maneuver the app can offer at the table, so it is the one
      that changes play.
- [ ] **Step 2: Wave 2** — `propose.py --group 3 --subgroup 1`. Expect a high reminder ratio; passive
      abilities that only grant legality or alter another rule's constant are the interesting ones
      (`SA_51` Kampfreflexe, `SA_64` Verbessertes Ausweichen, `SA_168` Meisterparade).
- [ ] **Step 3: Wave 3** — the extended groups, same loop.
- [ ] **Step 4: Update `COVERAGE.md` baseline and `CHANGELOG.md` under `Added`.**

---

## Self-Review

**Spec coverage.** ADR-0007: single authored store (Tasks 2, 3), no prose in git (Task 2 lint rule),
`rules.db` untracked and generated (Task 1), Optolith pinned (Task 1), two-step sync with the
deterministic half separated (Tasks 5, 6), `HARDCODED_EFFECTS` deleted (Task 3). ADR-0008: the schema
and its closed enums (Task 2), the classification fix (Task 1), coverage and no-silent-absence
(Task 8). Not covered here, by design: `EngineResult`, the effect handlers, `DamageExpression`,
maneuver slots and the parity harness — the engine plan.

**Open question deferred to the engine plan.** Ruleset versioning (pinning a printing so errata can be
swapped) is not in this schema. Adding a `ruleset:` key later is additive; retrofitting per-printing
*values* is not. Decide it before Wave 1 authors 40 rules against an unversioned schema.

> **Answered 2026-09-21 by ADR-0009, and this paragraph conflated two things.** The `ruleset:` key
> exists — it is required, has no default, and reaches `rules.db` as a column — but it names which
> *set* a rule belongs to (`core`, `focus.<slug>`, `house.<slug>`), not which *printing*. Versioning
> proper is deliberately out of scope: one current text per rule, with `book`/`page`/`checked`/`hash`
> recording which printing it was verified against and `make rules-sync-check` catching a change.
> `SA_62` is the worked example of what that defers; see ADR-0009 and
> `docs/rules-pipeline-status.md` §6a. It stays reversible — a version dimension would extend
> `ruleset` and the `source` block rather than replace them — so it does not gate Wave 1.

> **Note on spec coverage above:** Task 8's half of it (coverage and no-silent-absence) is **not
> started**, so ADR-0008's coverage ratchet is unbuilt. ADR-0008's amendment also records the
> ratchet's known limit in advance: it counts abilities, and it cannot count a chapter rule.

---

### Task 10: Resolve every rule to its page on the rule website, by name

**Status: DONE.** Added to this plan in `e564c86` after the gate failed; dispatched and built
2026-09-21. `make rules-resolve` resolves every combat rule to its page from the site's own category
indexes. Live run over groups 3, 9, 10, 11 and 12: 232 rules, 315 pages indexed across 6 index pages,
**201 resolved, 26 needs-review, 5 unresolved, 0 ambiguous**; the ten golden rules resolve to exactly
the URLs their authored files already record, 10 of 10; a second run makes zero network calls.

**Blocker 1 is not closed by this.** The task produces the resolution and the report; what remains is
(a) a human's decision on the 31 rules reported rather than confirmed, (b) backfilling the 17
`UNVERIFIED` authored files, which is a separate reviewable act because a `source.hash` is a claim
that a specific page was fetched and normalised (ADR-0007's second 2026-09-21 amendment gives that to
the driver, not to this resolver), and (c) changing `propose.py` to read `source_url` instead of
`rules_i18n.description`. `docs/rules-pipeline-status.md` §3 says which half closed.

**Goal:** Every rule the app can author gains a verified `source.url` on
`https://dsa.ulisses-regelwiki.de/`, resolved from its name through the site's own category
indexes — never guessed from its id.

**Why this exists:** the calibration gate (Task 7) failed partly because the driver feeds agents the
Optolith seed text, while ADR-0007 makes the rule website normative and specifies the propose step
as reading the fetched, normalised page. This is the unbuilt half of that decision, not new scope.

**Files:**
- Create: `scripts/rules_sync/resolve.py`, `tests/rules/test_resolve.py`, `tests/rules/fixtures/index_*.html`
- Modify: `scripts/build_rules_db/build_db.py` (carry the resolved URL into the generated db), `Makefile` (`rules-resolve`)

**Acceptance Criteria:**
- [x] Crawling the category indexes for combat groups 3, 9, 10, 11 and 12 yields a name → URL map
      covering the rules the app can author, built from anchor text and `href`, not extrapolation.
      232 rules in scope; 315 pages indexed across 6 index pages.
- [x] Index pages are handled on their own path: their `#main` is **empty** and their link lists sit
      outside it, so `normalise_html` raises `ContentContainerEmpty` on them by design. **Extended,
      not violated:** that holds for five of the six index pages and is asserted by test, but the
      group-11 category publishes its links *inside* a non-empty `#main`, so the classifier keys on
      the `a.ulSubMenu` anchors rather than on the container. Keying on the container alone reported
      all 74 rules in that group unresolved — found by running it, not by reasoning.
- [x] A name that matches no anchor, or matches more than one, is **reported** — never guessed. The
      report names the rule id, the Optolith name, and the candidates considered. 5 unresolved,
      0 ambiguous; 4 of the 5 are reported with the anchor a reviewer will almost certainly pick.
- [x] Identity is confirmed per rule by the three signals Task 4 established: page title, rule text
      against the Optolith text, and the `Publikation(en):` line against Optolith's `src:` block.
      All three must agree; 26 rules where one did not are reported, not recorded. **Read signal 2
      for what it is:** a lexical containment of the seed's words in the page, which answers "is this
      the same rule's page" and cannot answer "does the page say what the seed says" — the question
      the pipeline exists to ask. It would not have caught `SA_661` by itself.
- [x] The map is generated into the untracked `rules.db`; no ability names enter git (Data Policy).
      Authored files keep carrying only `source.url`, as they already do — none was rewritten.
- [x] Known-awkward cases resolve correctly: `Vorstoß` → `KSF_Vorsto%C3%9F.html`, and Golgariten-Stil
      under `SF_Kampfstilsonderfertigkeiten/bewaffnete-kampfstile/`.
- [x] The ten golden rules resolve to exactly the URLs their authored files already record. **10/10**,
      and `SA_62` is independently flagged for the same page discrepancy Task 4 found by hand.

**Verify:** `python3 -m pytest tests/rules/test_resolve.py -v && make rules-resolve && make rules-db`

---

### Task 11a: Withholding follows the rule graph, not just the rule id

**Status: DONE.** Commits `0d55ce3`. Mechanism only — **no live run was made.**

**Why it exists:** the whole-branch review's §6 (`docs/rules-pipeline-review-findings.md`), recorded
as a controller ruling after the blocker fixes. `specs/rules/CHAP_Reiterkampf.yaml` is a legitimate,
un-withheld authored file that encodes the very clause `SA_661` modifies, and it carries neither
`SA_661` nor its German ability name, so withholding the graded file and redacting its two tokens
left the answer standing in a file the agent was entitled to read. The class generalises as the
corpus grows from 28 files toward 232.

**What was built:** `scripts/rules_sync/rule_graph.py` — the corpus as a graph over three edges
computed from fields the schema already requires (`excludes` walked undirected; a shared
`parameterOverride.parameter` path; a non-reminder effect row agreeing on `type`+`target`+`scope`+
`side`, the axes Tier 1 grades a row's shape by). `prepare_workspace` withholds the **transitive
closure** of the run's rules over that graph, and the run writes `WITHHELD.md` beside its other
artefacts naming what was withheld for which rule under which edge. Per the controller's ruling, no
declared `related:`/`modifies:` schema field was added: the adjacency that leaked is the kind nobody
spots, so an edge depending on an author spotting it inherits the defect.

**Why Task 11 may not run before this:** the five passes cost ≈110 live model calls, and a `SA_661`
number measured through the leak would be a number nobody could attribute. See
`docs/rules-pipeline-status.md` §1 and §2 for the cost, and for the one golden rule the closure
leaves with no in-domain worked precedent.

**Verify:** `python3 -m pytest tests/rules/test_rule_graph.py tests/rules/test_propose.py
tests/rules/test_workspace_leaks.py -v` and `make rules-lint` (28 rule file(s), 0 error(s)). No
model calls, no network.

---

### Task 11: Measure per-rule stability before any wave

**Status: NOT STARTED.** Added to this plan in `e564c86`. Nothing exists. **This is blocker 4**, and
it is the one that has to come first: until the run-to-run spread is known, a ten-rule gate cannot
attribute a fix, so Task 10's effect on the score would not be measurable either.

**Prerequisite: Task 11a, above — DONE (`0d55ce3`).** Until it landed, a workspace handed the
agents an authored file encoding the clause a graded rule modifies, so a per-rule number for any
rule with an authored neighbour would have been suggestive rather than measured. Two consequences
for the acceptance criteria below, both recorded in `docs/rules-pipeline-status.md` §2:

- The run must state **which configuration it used** — the ten ids in one command, as the recorded
  calibration run did, or each rule on its own. They withhold different amounts (12 of 28 files
  against 8 of 28 per rule), so the two are not comparable and a mixed set is not a measurement.
- `SA_661`'s hit rate must be reported **separately**, not folded into an aggregate: after the
  closure it is the only golden rule with no worked precedent for any row shape it must produce, so
  its passes measure something the other nine's do not. The run's own `WITHHELD.md` belongs with the
  recorded output, as the statement of what the measurement controlled for.

**Goal:** Replace a single-sample gate score with per-rule hit rates, so the pipeline's reliability
is a measurement rather than a draw.

**Why this exists:** Task 7's 7/10 was the best of four runs; pooled, the rate is ≈0.58 with a 95%
interval of roughly [0.40, 0.89]. `SA_43` — one `legality` row, one predicate — dropped its
`when: [{mounted: true}]` gate in 2 of 5 passes on identical input, which is ADR-0008's named
failure: a conditional bonus silently becoming unconditional. At that spread the gate cannot
attribute a fix, cannot distinguish 6 from 8, and cannot certify what it is being asked to certify.

**Files:**
- Create: `tests/rules/calibration/<date>-stability/`, `docs/rules-pipeline-stability.md` (tracked; carries no rule prose)
- Modify: `tests/rules/test_calibration.py` (grade a multi-pass run)

**Acceptance Criteria:**
- [ ] Five passes over the ten golden rules, **on rule-website text** (Task 10's URLs), same model,
      same briefs, same workspace — one variable, repeated.
- [ ] Per-rule hit rate reported for all ten, not a single fraction; plus the author/verifier
      agreement rate per rule.
- [ ] Every rule that ever loses a `when` predicate across passes is named, since that failure is
      invisible to both the linter and the cross-check.
- [ ] `SA_41`'s shape is checked specifically — the `shiftSteps` brief fix from Task 7's fix round is
      deductively correct but has never been exercised by a live run.
- [ ] A stated pass bar, fixed before the runs: which per-rule rate, over how many passes, would
      justify a wave — and the honest answer if the data does not reach it.

**Verify:** `python3 -m pytest tests/rules/test_calibration.py -v` (grades recorded output; no model calls)

---

### Task 12: Author the rules the app hardcodes, under our own id namespace

**Status: STARTED, most of the backlog open.** `CHAP_Reiterkampf` is authored (`c93105a..2e468fd`),
establishing the `CHAP_<PageSlug>` namespace, the linter's id derivation and the `chapter` category
in `build_db.py`. Two corrections landed on top: the chapter page's third hardcoded mechanic
(`9aef3d2`) and a linter/schema contradiction over chapter ids (`a3508e2`). ADR-0009's two database
columns — `ruleset` and `source.title` — are implemented ahead of the wave (`1ceb48d`), so every
`CHAP_` file this task authors needs `source.title` or it will not lint. **Not started:** every other
chapter page, the named combat constants, and the derived-value rules. One divergence found by
authoring is recorded and awaits a ruling (`docs/rules-pipeline-status.md` §6b).

**Goal:** Every DSA 5 chapter rule whose constants currently live as Swift literals has an authored
`CHAP_` file, so the engine rewrite has data to read instead of a number to keep.

**Why this exists:** the corpus was built around Optolith ids, and a chapter page has none — so the
rules that bind *anyone in a situation* rather than anyone with an ability had nowhere to go, and
stayed in Swift. Authoring all 232 abilities would have left them there while coverage read as
complete. `CHAP_Reiterkampf` is the first one and establishes the shape (ADR-0007 and ADR-0008,
amendments of 2026-09-21); this task is the rest. It also exposed a live ruling error: `SA_43`'s
note claimed a clause did not exist when it did, because the corpus had no shape that could hold it.

**Files:**
- Create: `specs/rules/CHAP_<Page>.yaml`, one per chapter page
- Modify: `docs/rules-migration-reconciliation.md` (coverage), `CHANGELOG.md`

**The known backlog**, each already a Swift literal, each a page on the rule website:

| Mechanic | Swift today |
|---|---|
| Beengte Umgebung, AT/PA by weapon reach | `Hesindion/Models/CombatManeuver.swift:109` (`beengteUmgebungPenalty`), applied in `MeleeModifiers.swift:79` and `DefenseModifiers.swift:67` |
| Multiple defences, cumulative per Kampfrunde | `Hesindion/Engine/DefenseModifiers.swift:16` (`-(ctx.defenseCount * 3)`) |
| Weapon reach mismatch, AT penalty | `Hesindion/Models/CombatManeuver.swift:100-105` |
| Dual wield, base penalty | `Hero` (ADR-0008's census) |
| Passierschlag | `passierschlag.penalty` per ADR-0008's parameter list |

The table is a starting point, not a closed list: the first step is to enumerate the chapter pages
the combat engine reads from, and a mechanic that turns out to belong to an ability after all is
authored there instead — which is the mistake `SA_43` made in the other direction.

**Two more categories, added by ADR-0009.** Optolith names abilities and nothing else, so `CHAP_` is
not a side namespace beside Optolith's — it is the first instance of **our own** rule namespace, and
these belong in it too. Neither is authored yet and neither has an id shape decided; deciding that is
part of this task.

*Named combat constants.* ADR-0008 turns these into parameters; each is also a rule that can be
cited, and today each is a literal that can be cited as nothing.

| Constant | Swift today |
|---|---|
| `defense.multiplePenaltyPerStep` | `Hesindion/Engine/DefenseModifiers.swift:16` |
| `reach.matrix` | `Hesindion/Models/CombatManeuver.swift:100-105` |
| `zone.*` | `Hesindion/Engine/HitZoneModifiers.swift` |
| `dualWield.penalty`, `passierschlag.penalty` | `Hesindion/Models/Hero.swift`, per ADR-0008's parameter list |

*Derived-value rules.* A hero's GS and their species base LP/SK/ZK are rules the book states, keyed
on species. ADR-0006 exists because one derived-value formula was wrong, and the 2026-09-21 rounding
round corrected more — the failure class runtime provenance is meant to make visible, invisible today
because a derived value has no rule to point at.

| Rule | Swift today |
|---|---|
| Species base LP | `Hesindion/Services/OptolithImportService.swift:796` (`speciesBaseLP`) |
| Species base SK / ZK | `Hesindion/Services/OptolithImportService.swift:803`, `:810` |
| GS | **Swift fixed 2026-09-21 (Task 13); still unauthored.** Was a flat `base: 8` for every hero at `OptolithImportService.swift:888`; now `DerivedValueFormulas.geschwindigkeit(speciesId:)` |
| Wundschwelle, Ausweichen, Initiative | `Hesindion/Engine/DerivedValueFormulas.swift:15`, `:28`, `:33` |

**`source.title` on chapter files (ADR-0009).** A chapter rule has no `rules_i18n` row, so a
breakdown line citing one has no name to display. Each `CHAP_` file authored by this task carries its
page title in `source.title`, and `build_db.py` writes it into the chapter rule's `rules` row.

*Done 2026-09-21, ahead of the wave.* The schema field, the linter rule, the `rules.title` column
and `CHAP_Reiterkampf`'s own title all exist; `make rules-db-verify` checks the column against the
files. The linter requires a chapter `source.title` and requires it to **ASCII-fold to the id's own
slug**, which is ADR-0009's argument for admitting the field turned into a check — a description of
the page cannot pass, only the page's name in its display spelling. Every `CHAP_` file this task
authors therefore needs the field or it will not lint.

**`ruleset` reaches `rules.db`, and `rules-db-verify` checks it (ADR-0009).** Also done
2026-09-21. The engine reads the database, not `specs/rules/`, so the field had to become a `rules`
column before "the engine applies only the sets a hero plays with" could be anything but a sentence.
`make rules-db-verify` compares the column against the authored files rather than against another
copy of the build's output, because a dropped field is dropped identically on both sides of a dump
comparison.

**Acceptance Criteria:**
- [ ] Each page is one authored file, id `CHAP_<PageSlug>` derived from `source.url`, with a real
      `source.hash` verified by `make rules-sync-check` — never a placeholder, which `lint.py`
      rejects for a chapter id by construction.
- [ ] Every file declares its `ruleset` (ADR-0009). A chapter page of the Regelwerk's standard rules
      is `core`; a page the book prints as a Fokus-Regel is `focus.<slug>`, glossed in
      `vocabulary.yaml`. The Trefferzonen rules currently in Swift are the first `focus.` candidate.
- [ ] Every `CHAP_` file carries `source.title`, and `build_db.py` writes it into the chapter rule's
      `rules` row, so a breakdown line citing a chapter rule has a name to display (ADR-0009).
- [ ] Constants that ADR-0008 names as parameters are authored as `parameterOverride` against paths
      that already exist in the corpus or in `schema.json` — `parameter` is the field nothing
      validates, so an invented path lints clean and encodes to nothing (RUN.yaml, `SA_41`).
- [ ] Every clause the grammar cannot express is a `reminder` with an `UNENCODED:` note, so
      `grep -r UNENCODED specs/rules` still enumerates the whole debt.
- [ ] No Swift changes in this task. The engine plan consumes the data; this one writes it.
- [ ] Any divergence found between an authored clause and the Swift that implements it today is
      **recorded** under `[Unreleased]` in `CHANGELOG.md` and left for a ruling — as
      `CHAP_Reiterkampf`'s BE scope was. Numbers at the table do not change as a side effect of
      authoring.

**Verify:** `make rules-lint && python3 -m pytest tests/ -q && make rules-db && make rules-sync-check`

---

### Task 13: GS is a species rule, and the app gave every hero the human value

**Status: Swift DONE** — `f276b14`. The corpus half is open and belongs to Task 12. This was the
second of the branch's two live app bugs; how it was found, and why the method is the reusable part,
is in `docs/rules-pipeline-status.md` §5.

**Status:** Swift done 2026-09-21. The corpus half is open and belongs to Task 12.

**What was wrong:** `OptolithImportService.swift:888` read
`let geschwindigkeit = ResourceValue(base: 8, bonus: 0, max: 8)`, commented *"GS = 8 (Mensch base)"*.
GS is keyed on species — the pinned Optolith source carries `mov` per race in `Data/univ/Races.yaml`,
and **Zwerge are 6**, while Menschen, Elfen and Halbelfen are 8. Every dwarf hero was two Schritt too
fast, and `RaceVariants.yaml` overrides `mov` for none of the ten variants, so those four values are
the whole of what the pinned source knows.

**Blast radius, because GS is displayed and derived from:** `HeroDetailView.swift:545-546` shows it
with `Hero.totalGsPenalty` (`belastungPenalty + armorGsModifier`) beside it;
`CombatDefenseViews.swift:855-887` renders the Flucht outcome as *"GS n Schritt"* and *"GS/2 = n
Schritt"*; and `COND_1`, `COND_5` and `COND_6` all carry `target: gs` modifier rows for the engine
that will read them. `Hero.sturmangriffDamageBonus` is **not** affected — it reads `mountGS`, the
pet's speed, not the hero's.

**What was done** (`3c3ff91`, the Belastungsgewöhnung fix, is the precedent this copies):

- `DerivedValueFormulas.geschwindigkeit(speciesId:) -> Int?` holds the table. It is species-keyed
  rather than attribute-only, which that file's docstring used to claim as its scope; the file's
  actual contract is "the import path and the repair path cannot drift", and GS needs exactly that.
  The species base LP/SK/ZK tables stay in `OptolithImportService`, because each still has one
  caller — `DerivedValueRepair` does not touch those three (ADR-0006).
- **Unknown species returns `nil`, not `8`.** The import falls back to
  `geschwindigkeitFallback` (8) because a hero must have a GS to display and that fallback is
  ADR-0006's already-recorded status quo; the repair *skips* the hero instead, because writing the
  human value is the very thing being corrected, over a number somebody may have fixed by hand.
- `DerivedValueRepair` gains GS, keyed on `PersonalData.speciesId` — the field ADR-0006 began
  persisting so that a species-aware recompute would become possible. Heroes imported before that
  have `speciesId == nil` and are left alone, which is the honest outcome: their species is not
  recorded anywhere the app can read.

**Still open:** GS has no rule to cite. It is on Task 12's derived-value list and ADR-0009 puts
derived-value rules in our own id namespace; authoring it would have made this bug a *wrong citation*
rather than a plausible constant. Fixing the Swift first was the right order — the number is wrong at
the table today and the corpus cannot yet be read by anything — but the authoring is what stops the
next one.

**Acceptance Criteria:**
- [x] GS comes from the species, with the four values taken from the pinned source rather than from
      the code being replaced.
- [x] The unknown-species branch is a deliberate, tested choice, and the import and the repair make
      *different* deliberate choices for it.
- [x] `DerivedValueRepair` stays idempotent, by test.
- [x] `CHANGELOG.md` under `Fixed`, naming what changes at the table.
- [ ] GS authored as a derived-value rule with provenance (Task 12).

**Verify:** `make test-ui`
