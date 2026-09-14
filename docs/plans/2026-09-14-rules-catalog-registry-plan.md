# Rules Catalog — Registry Implementation Plan (steps 0 and 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make coverage a measured number: every rule id in `rules.db` gets a catalog entry with a status the build enforces, the importer stops classifying abilities off the dead effects table, and the effects layer is deleted.

**Architecture:** A YAML catalog in `specs/data/` is validated and compiled into a `catalog` table in `rules.db` by the existing Python build script; a snapshot of the per-status counts is committed beside it and the build fails when the counts move without it. The Swift side reads the table through `RulesDatabase`, shows the status on the rule detail screen, and tests assert every id has an entry and every `byHand` pointer names a symbol that exists in the source tree. No engine changes: that is step 2 (design §7).

**Tech Stack:** Python 3.11 + PyYAML (build script, `unittest`), SQLite, Swift/SwiftUI, XCTest.

**User decisions (already made):**
- Scope: every rule has a status; mechanics only for the app's check domains.
- Rules live in data with a closed vocabulary, not in Swift.
- The Regelwiki page is the source of the rule text; Optolith contributes only structured ids, cost, prerequisites, technique ids, unlock ids.
- Authoring is an LLM pipeline with human spot review (step 4, not this plan).
- A rule applies to a hero exactly when its id is among the hero's traits, never by profession or name.
- Design approved at `docs/plans/2026-09-14-rules-catalog-design.md`; this plan is its §7 steps 0 and 1.

---

## File structure

**Create**
- `Hesindion/Models/CombatSpecialAbilityGroup.swift` — the four combat group ids from Optolith, checked against `rules.db` by name.
- `HesindionTests/CombatSpecialAbilityGroupTests.swift` — the ids name what they claim; the importer files every combat-group ability as combat.
- `scripts/build_rules_db/catalog.py` — load, validate, count, snapshot-check and write the catalog. Pure functions over dicts so they are testable without a database.
- `scripts/build_rules_db/test_catalog.py` — `unittest` for `catalog.py`.
- `scripts/build_rules_db/scaffold_catalog.py` — writes the one-time skeleton (every id as `todo`).
- `specs/data/rules-catalog.yaml` — the catalog.
- `specs/data/rules-catalog.snapshot.json` — per-status counts.
- `HesindionTests/RulesCatalogTests.swift` — every id has an entry, pointers resolve, coverage floor, labels localized, sample hero carries nothing `todo`.

**Modify**
- `Hesindion/Services/RulesDatabase.swift` — `RuleDetail.groupId`; remove `RuleEffect`/`lookupEffects`; add `CatalogStatus`, `CatalogEntry`, `lookupCatalogEntry`, `catalogEntries(status:)`, `catalogStatusCounts`, `ruleIdsWithoutCatalogEntry`, `lookupGroupName`.
- `Hesindion/Services/OptolithImportService.swift` — `isCombatSpecialAbility` reads the group id.
- `Hesindion/Models/Hero.swift` — `beidhaendigerKampfLevel` by id; comment on `specialAbility(_:)`.
- `Hesindion/Models/CombatAbility.swift` — add `beidhaendigerKampf`; remove `Wiring`.
- `Hesindion/Views/RuleDetailView.swift` — the effects section becomes the catalog status.
- `Hesindion/Theme/Strings.swift` — catalog keys.
- `HesindionTests/CombatAbilityCoverageTests.swift` — drop the effects and wiring tests; add the new name.
- `scripts/build_rules_db/build_db.py` — `--catalog`/`--snapshot`/`--repo-root`/`--update-snapshot`; no `effects` table; `catalog` table.
- `Makefile` — `rules-db` target.
- `AGENTS.md`, `CHANGELOG.md`.

**Delete**
- `Hesindion/Engine/RuleEffectModifiers.swift`, `specs/data/rules.yaml`, `scripts/scrape_effects/`.

The Xcode project uses file-system synchronized groups, so adding and deleting Swift files needs no `project.pbxproj` edit. `Hesindion/Resources/rules.db` is tracked in git (despite the `.gitignore` line) and is what the tests read; rebuilding it is part of tasks 5 and 7 and the rebuilt file is committed as it has been so far.

**Test commands.** `make test-ui` runs the whole `HesindionTests` target on one simulator and is the verify for every Swift task; there is no narrower Makefile target and the Makefile is the only sanctioned way to run xcodebuild. Python tests: `python3 -m unittest discover -s scripts/build_rules_db -v`. The Optolith source lives at `/Users/SamuelvonBaussnern/proj/50_priv/dsa_companion_data/Data`.

---

### Task 1: Classify combat abilities by group, not by the effects table

**Goal:** The importer files a Sonderfertigkeit as combat when Optolith's group says so, which fixes 217 of 226 combat abilities landing in the general list.

**Files:**
- Create: `Hesindion/Models/CombatSpecialAbilityGroup.swift`
- Create: `HesindionTests/CombatSpecialAbilityGroupTests.swift`
- Modify: `Hesindion/Services/RulesDatabase.swift` (`RuleDetail`, `lookup(id:)`, new `lookupGroupName`)
- Modify: `Hesindion/Services/OptolithImportService.swift:461-467`
- Modify: `Hesindion/Models/Hero.swift:433-445` (comment only)
- Modify: `CHANGELOG.md`

**Acceptance Criteria:**
- [ ] `CombatSpecialAbilityGroup` has four cases whose raw values are the `groups.id` rows named Kampf, Kampf (erweitert), Kampfstile (bewaffnet), Kampfstile (unbewaffnet), and a test checks each name against `rules.db`.
- [ ] After importing Boronmir, SA_884 is in `combatSpecialAbilities` and no trait in `generalSpecialAbilities` belongs to a combat group.
- [ ] `OptolithImportService` no longer reads `rule.effects`.

**Verify:** `make test-ui` → `** TEST SUCCEEDED **`, with `CombatSpecialAbilityGroupTests` listed as passed.

**Steps:**

- [ ] **Step 1: Write the failing tests**

`HesindionTests/CombatSpecialAbilityGroupTests.swift`:

```swift
import XCTest
@testable import Hesindion

/// The importer used to file a Sonderfertigkeit as combat when `rules.db` had a
/// combat-scoped *effects* row for it. That table covered ten of the 226 combat
/// abilities, so Plänkler-Formation, Gezielter Angriff and 214 others landed in
/// the general list. Optolith's group id is the classification the data
/// actually carries; these tests hold the enum to the table it came from.
final class CombatSpecialAbilityGroupTests: XCTestCase {

    private func requireDatabase() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else {
            throw XCTSkip("rules.db unavailable in this run")
        }
    }

    private static let expected: [CombatSpecialAbilityGroup: String] = [
        .kampf: "Kampf",
        .kampfErweitert: "Kampf (erweitert)",
        .kampfstileBewaffnet: "Kampfstile (bewaffnet)",
        .kampfstileUnbewaffnet: "Kampfstile (unbewaffnet)",
    ]

    func testEveryIdNamesTheGroupItIsCalled() throws {
        try requireDatabase()
        XCTAssertEqual(CombatSpecialAbilityGroup.allCases.count, Self.expected.count)
        for group in CombatSpecialAbilityGroup.allCases {
            XCTAssertEqual(RulesDatabase.shared.lookupGroupName(group.rawValue), Self.expected[group], "\(group)")
        }
    }

    func testAGroupOutsideTheFourIsNotCombat() {
        XCTAssertFalse(CombatSpecialAbilityGroup.contains(groupId: 1))    // Allgemein
        XCTAssertFalse(CombatSpecialAbilityGroup.contains(groupId: nil))
        XCTAssertTrue(CombatSpecialAbilityGroup.contains(groupId: 3))
    }

    /// Plänkler-Formation (SA_884) is the ability that hid: no effects row, so
    /// it went to the general list. Boronmir carries it.
    func testTheImporterFilesEveryCombatGroupAbilityAsCombat() throws {
        try requireDatabase()
        let hero = try TestData.importBoronmir(into: TestData.makeContainer())
        XCTAssertTrue(hero.combatSpecialAbilities.contains { $0.ruleId == "SA_884" },
                      "Plänkler-Formation is filed as general")
        for trait in hero.generalSpecialAbilities {
            let groupId = RulesDatabase.shared.lookup(id: trait.ruleId)?.groupId
            XCTAssertFalse(CombatSpecialAbilityGroup.contains(groupId: groupId),
                           "\(trait.ruleId) \(trait.name) is a combat ability filed as general")
        }
    }
}
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `make test-ui`
Expected: build failure, `cannot find 'SpecialAbilityGroup' in scope` and `value of type 'RuleDetail' has no member 'groupId'`.

- [ ] **Step 3: Add the enum**

`Hesindion/Models/CombatSpecialAbilityGroup.swift`:

```swift
import Foundation

/// The Optolith special-ability groups that make an ability a *combat* one.
///
/// The raw values are `groups.id` in `rules.db`, which is Optolith's `gr`.
/// `CombatSpecialAbilityGroupTests` checks each one against the group's name, so a
/// wrong number fails a test instead of silently filing an ability out of reach.
enum CombatSpecialAbilityGroup: Int, CaseIterable {
    case kampf = 3
    case kampfstileBewaffnet = 9
    case kampfstileUnbewaffnet = 10
    case kampfErweitert = 11

    /// Whether an ability in this group belongs in `Hero.combatSpecialAbilities`.
    static func contains(groupId: Int?) -> Bool {
        guard let groupId else { return false }
        return CombatSpecialAbilityGroup(rawValue: groupId) != nil
    }
}
```

- [ ] **Step 4: Expose the group id and group name from the database**

In `Hesindion/Services/RulesDatabase.swift`, change `RuleDetail`:

```swift
struct RuleDetail: Identifiable {
    let id: String
    let category: String
    /// Optolith's group (`groups.id`), nil for categories that have none.
    let groupId: Int?
    let name: String
    let description: String
    let cost: String?
    let levels: Int?
    let max: Int?
    let effects: [RuleEffect]
    let spellDetail: SpellDetail?
}
```

In `lookup(id:)`, select the group and pass it through:

```swift
        let sql = """
            SELECT r.id, r.category, i.name, i.description, r.cost, r.levels, r.max, r.group_id
            FROM rules r
            JOIN rules_i18n i ON i.rule_id = r.id AND i.locale = ?
            WHERE r.id = ?
            """
```

```swift
        let max = col_int_opt(stmt, 6)
        let groupId = col_int_opt(stmt, 7)
```

```swift
        return RuleDetail(
            id: ruleId, category: category, groupId: groupId, name: name, description: desc,
            cost: cost, levels: levels, max: max, effects: effects,
            spellDetail: spellDetail
        )
```

Add after `allCombatTechniqueIds()`:

```swift
    /// The name of an Optolith group, for the tests that hold the group enums to the table.
    func lookupGroupName(_ id: Int) -> String? {
        let sql = "SELECT name FROM groups WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return col_text(stmt, 0)
    }
```

- [ ] **Step 5: Reclassify in the importer**

Replace `isCombatSpecialAbility` in `Hesindion/Services/OptolithImportService.swift`:

```swift
    /// Whether an ability belongs in `combatSpecialAbilities`: Optolith's group
    /// says so. The effects table used to decide this and covered ten abilities.
    private func isCombatSpecialAbility(id: String) -> Bool {
        CombatSpecialAbilityGroup.contains(groupId: rules.lookup(id: id)?.groupId)
    }
```

- [ ] **Step 6: Correct the comment on `Hero.specialAbility(_:)`**

In `Hesindion/Models/Hero.swift`, replace the doc comment above `func specialAbility(_ ruleId: String)` with:

```swift
    /// A Sonderfertigkeit by rule id, wherever the importer filed it.
    ///
    /// The importer sorts an SA into `combatSpecialAbilities` or
    /// `generalSpecialAbilities` by its Optolith group (`CombatSpecialAbilityGroup`).
    /// It used to ask the effects table instead, which had rows for ten combat
    /// abilities, so Plänkler-Formation (SA_884), Gezielter Angriff (SA_160) and
    /// Gezielter Schuss (SA_161) all sat in the general list while every lookup
    /// searched the combat one. Heroes imported before that fix still carry the
    /// old split, so the lookup searches both lists and does not care.
```

- [ ] **Step 7: Run the tests**

Run: `make test-ui`
Expected: `** TEST SUCCEEDED **`. If `HeroDetailViewSnapshotTests` fails because Boronmir's Plänkler-Formation moved from the general list to the combat list, delete the failing reference images under `HesindionTests/Snapshots/__Snapshots__/HeroDetailViewSnapshotTests/` and run `make test-ui-record-only ONLY=HesindionTests/HeroDetailViewSnapshotTests`, then `make test-ui` again. Record-only never overwrites an existing reference, which is why they are deleted first.

- [ ] **Step 8: Changelog and commit**

Under `## [Unreleased]` → `### Fixed` in `CHANGELOG.md`, add as the first bullet:

```markdown
- **217 of the 226 combat Sonderfertigkeiten were filed as general abilities.** The importer asked whether `rules.db` had a combat-scoped effects row for an ability, and that table had rows for nine of them. It reads Optolith's group now (`CombatSpecialAbilityGroup`, checked against the database by name), so an imported Riposte or Sturmangriff lands in the combat list like Finte does
```

```bash
git add Hesindion/Models/CombatSpecialAbilityGroup.swift HesindionTests/CombatSpecialAbilityGroupTests.swift Hesindion/Services/RulesDatabase.swift Hesindion/Services/OptolithImportService.swift Hesindion/Models/Hero.swift CHANGELOG.md HesindionTests/Snapshots/__Snapshots__
git commit -m "fix(import): a combat ability is one Optolith files under Kampf, not one the effects table knows"
```

---

### Task 2: Beidhändiger Kampf by id

**Goal:** The one remaining name-matched ability gets its id, and the id is covered like the others.

**Files:**
- Modify: `Hesindion/Models/Hero.swift:295-301`
- Modify: `Hesindion/Models/CombatAbility.swift`
- Modify: `HesindionTests/CombatAbilityCoverageTests.swift:48-70`

**Acceptance Criteria:**
- [ ] `CombatAbility.beidhaendigerKampf == "SA_42"` and `testEveryAbilityIdNamesTheAbilityItIsCalled` expects "Beidhändiger Kampf" for it.
- [ ] `Hero.beidhaendigerKampfLevel` reads `tier(of: .beidhaendigerKampf)` and no `name.contains` remains in `Hero.swift`.

**Verify:** `make test-ui` → `** TEST SUCCEEDED **`; `grep -n "name.contains" Hesindion/Models/Hero.swift` → no output.

**Steps:**

- [ ] **Step 1: Extend the expectation**

In `HesindionTests/CombatAbilityCoverageTests.swift`, add to the `expected` dictionary in `testEveryAbilityIdNamesTheAbilityItIsCalled`:

```swift
            .beidhaendigerKampf: "Beidhändiger Kampf",
```

Add a test after `testTierIsReadFromEitherList`:

```swift
    /// Used to be found by `name.contains("Beidhändiger Kampf")`, which a renamed
    /// or untranslated export defeats.
    func testBeidhaendigerKampfIsReadById() {
        let hero = hero(with: .beidhaendigerKampf, inCombatList: true, tier: 2)
        XCTAssertEqual(hero.beidhaendigerKampfLevel, 2)
        XCTAssertEqual(hero.dualAttackPenalty, 0)
        XCTAssertEqual(Hero(name: "Ohne").dualAttackPenalty, -2)
    }
```

- [ ] **Step 2: Run to see it fail**

Run: `make test-ui`
Expected: build failure `type 'CombatAbility' has no member 'beidhaendigerKampf'`.

- [ ] **Step 3: Add the case**

In `Hesindion/Models/CombatAbility.swift`, insert after `case belastungsgewoehnung = "SA_41"`:

```swift
    case beidhaendigerKampf   = "SA_42"
```

and in `wiring`, add before the `.berittenerKampf` case:

```swift
        case .beidhaendigerKampf:
            .byHand("Hero.beidhaendigerKampfLevel — each tier takes 1 off the −2 dual-attack penalty")
```

- [ ] **Step 4: Read it by id**

Replace in `Hesindion/Models/Hero.swift`:

```swift
    /// Level of Beidhändiger Kampf (SA_42). Each level reduces the −2 dual-attack penalty by 1.
    var beidhaendigerKampfLevel: Int {
        tier(of: .beidhaendigerKampf)
    }
```

- [ ] **Step 5: Run and commit**

Run: `make test-ui`
Expected: `** TEST SUCCEEDED **`.

```bash
git add Hesindion/Models/Hero.swift Hesindion/Models/CombatAbility.swift HesindionTests/CombatAbilityCoverageTests.swift
git commit -m "fix(combat): Beidhändiger Kampf is SA_42, not a name to search for"
```

---

### Task 3: The catalog module, tested without a database

**Goal:** Pure Python functions that load a catalog, list every problem with it, count statuses, compare against a snapshot, and write the `catalog` table.

**Files:**
- Create: `scripts/build_rules_db/catalog.py`
- Create: `scripts/build_rules_db/test_catalog.py`

**Acceptance Criteria:**
- [ ] `validate` reports: an id missing from the catalog, an id not in the rules, a duplicate id, a name that differs from the rules, an unknown status, a `byHand` without a pointer, a pointer file that does not exist, a symbol not found in the file, a `todo` without `why`.
- [ ] `check_snapshot` returns `[]` when counts equal the snapshot, and messages naming "backwards" when implemented+byHand shrank and "grew" when todo rose.
- [ ] `write_catalog_table` creates the table and one row per entry.

**Verify:** `python3 -m unittest discover -s scripts/build_rules_db -v` → `OK` with 9 tests.

**Steps:**

- [ ] **Step 1: Write the tests**

`scripts/build_rules_db/test_catalog.py`:

```python
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

import catalog


RULES = {"SA_1": "Erste", "SA_2": "Zweite"}


def entry(**kw):
    base = {"id": "SA_1", "name": "Erste", "group": "Kampf", "status": "todo", "why": "not yet read"}
    base.update(kw)
    return base


class ValidateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "Hero.swift").write_text("struct Hero {\n    var golgaritenActive: Bool\n}\n")

    def tearDown(self):
        self.tmp.cleanup()

    def test_a_complete_catalog_has_no_problems(self):
        entries = [entry(), entry(id="SA_2", name="Zweite")]
        self.assertEqual(catalog.validate(entries, RULES, self.root), [])

    def test_a_rule_without_an_entry_is_a_problem(self):
        problems = catalog.validate([entry()], RULES, self.root)
        self.assertIn("SA_2: no catalog entry", problems)

    def test_an_entry_the_rules_do_not_know_is_a_problem(self):
        entries = [entry(), entry(id="SA_2", name="Zweite"), entry(id="SA_9", name="Neunte")]
        self.assertIn("SA_9: not in rules.db", catalog.validate(entries, RULES, self.root))

    def test_a_duplicate_and_a_wrong_name_and_an_unknown_status_are_problems(self):
        entries = [entry(), entry(), entry(id="SA_2", name="Falsch", status="maybe")]
        problems = catalog.validate(entries, RULES, self.root)
        self.assertIn("SA_1: listed twice", problems)
        self.assertIn("SA_2: name is 'Falsch', rules.db says 'Zweite'", problems)
        self.assertTrue(any(p.startswith("SA_2: status 'maybe'") for p in problems))

    def test_by_hand_needs_a_pointer_that_resolves(self):
        ok = entry(status="byHand", note="x", pointer={"file": "Hero.swift", "symbol": "golgaritenActive"})
        no_pointer = entry(id="SA_2", name="Zweite", status="byHand", note="x")
        self.assertEqual(catalog.validate([ok, no_pointer], RULES, self.root),
                         ["SA_2: byHand needs pointer {file, symbol}"])
        no_file = entry(id="SA_2", name="Zweite", status="byHand", pointer={"file": "Nope.swift", "symbol": "x"})
        self.assertEqual(catalog.validate([ok, no_file], RULES, self.root),
                         ["SA_2: pointer file Nope.swift does not exist"])
        no_symbol = entry(id="SA_2", name="Zweite", status="byHand", pointer={"file": "Hero.swift", "symbol": "golgariten"})
        self.assertEqual(catalog.validate([ok, no_symbol], RULES, self.root),
                         ["SA_2: symbol 'golgariten' not found in Hero.swift"])

    def test_todo_needs_a_why(self):
        entries = [entry(why=None), entry(id="SA_2", name="Zweite")]
        self.assertIn("SA_1: todo without why", catalog.validate(entries, RULES, self.root))


class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "snap.json"

    def tearDown(self):
        self.tmp.cleanup()

    def test_counts_and_an_equal_snapshot(self):
        entries = [entry(), entry(id="SA_2", name="Zweite", status="byHand", note="x",
                                  pointer={"file": "a", "symbol": "b"})]
        counts = catalog.status_counts(entries)
        self.assertEqual(counts, {"implemented": 0, "byHand": 1, "noRollEffect": 0, "todo": 1})
        catalog.write_snapshot(counts, self.path)
        self.assertEqual(catalog.check_snapshot(counts, self.path), [])

    def test_shrinking_coverage_and_growing_todo_are_named(self):
        self.path.write_text(json.dumps({"implemented": 1, "byHand": 1, "noRollEffect": 0, "todo": 0}))
        problems = catalog.check_snapshot({"implemented": 0, "byHand": 1, "noRollEffect": 0, "todo": 1}, self.path)
        self.assertTrue(any("backwards" in p for p in problems))
        self.assertTrue(any("grew" in p for p in problems))
        self.assertTrue(any("--update-snapshot" in p for p in problems))


class TableTests(unittest.TestCase):
    def test_the_table_holds_one_row_per_entry(self):
        conn = sqlite3.connect(":memory:")
        entries = [entry(), entry(id="SA_2", name="Zweite", status="byHand", note="by hand",
                                  pointer={"file": "Hero.swift", "symbol": "x"},
                                  reviewed={"by": "sam", "date": "2026-09-14"})]
        catalog.write_catalog_table(conn, entries)
        rows = conn.execute("SELECT rule_id, status, note, pointer_file, pointer_symbol, reviewed_by, reviewed_on "
                            "FROM catalog ORDER BY rule_id").fetchall()
        self.assertEqual(rows, [
            ("SA_1", "todo", "not yet read", None, None, None, None),
            ("SA_2", "byHand", "by hand", "Hero.swift", "x", "sam", "2026-09-14"),
        ])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to see them fail**

Run: `python3 -m unittest discover -s scripts/build_rules_db -v`
Expected: `ModuleNotFoundError: No module named 'catalog'`.

- [ ] **Step 3: Write the module**

`scripts/build_rules_db/catalog.py`:

```python
"""The rules catalog: one entry per rule id in rules.db, with a status the build enforces.

Design: docs/plans/2026-09-14-rules-catalog-design.md §4. This file is step 1 of §7:
statuses and pointers only, no clauses yet.
"""

import json
import re
from pathlib import Path

import yaml

STATUSES = ("implemented", "byHand", "noRollEffect", "todo")
REQUIRED = ("id", "name", "group", "status")


class CatalogError(Exception):
    pass


def load_catalog(path: Path) -> list[dict]:
    with open(path, "r", encoding="utf-8") as f:
        doc = yaml.safe_load(f)
    if not isinstance(doc, list):
        raise CatalogError(f"{path}: the catalog must be a list of entries")
    return doc


def validate(entries: list[dict], rules: dict[str, str], repo_root: Path) -> list[str]:
    """Every problem with the catalog, as one line each. Empty means valid.

    `rules` maps every rule id in rules.db to its German name.
    """
    problems: list[str] = []
    seen: set[str] = set()
    for e in entries:
        rid = e.get("id", "?")
        missing = [k for k in REQUIRED if k not in e]
        if missing:
            problems.append(f"{rid}: missing {', '.join(missing)}")
            continue
        if rid in seen:
            problems.append(f"{rid}: listed twice")
        seen.add(rid)
        if rid not in rules:
            problems.append(f"{rid}: not in rules.db")
            continue
        if e["name"] != rules[rid]:
            problems.append(f"{rid}: name is {e['name']!r}, rules.db says {rules[rid]!r}")
        status = e["status"]
        if status not in STATUSES:
            problems.append(f"{rid}: status {status!r} is not one of {', '.join(STATUSES)}")
            continue
        if status == "byHand":
            problems.extend(_check_pointer(rid, e.get("pointer"), repo_root))
        if status == "todo" and not e.get("why"):
            problems.append(f"{rid}: todo without why")
    for rid in rules:
        if rid not in seen:
            problems.append(f"{rid}: no catalog entry")
    return problems


def _check_pointer(rid: str, pointer, repo_root: Path) -> list[str]:
    if not isinstance(pointer, dict) or "file" not in pointer or "symbol" not in pointer:
        return [f"{rid}: byHand needs pointer {{file, symbol}}"]
    path = repo_root / pointer["file"]
    if not path.is_file():
        return [f"{rid}: pointer file {pointer['file']} does not exist"]
    text = path.read_text(encoding="utf-8")
    pattern = r"(?<![A-Za-z0-9_])" + re.escape(pointer["symbol"]) + r"(?![A-Za-z0-9_])"
    if not re.search(pattern, text):
        return [f"{rid}: symbol {pointer['symbol']!r} not found in {pointer['file']}"]
    return []


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


def write_catalog_table(conn, entries: list[dict]) -> None:
    conn.execute("DROP TABLE IF EXISTS catalog")
    conn.execute("""
        CREATE TABLE catalog (
            rule_id        TEXT PRIMARY KEY,
            status         TEXT NOT NULL,
            note           TEXT,
            pointer_file   TEXT,
            pointer_symbol TEXT,
            reviewed_by    TEXT,
            reviewed_on    TEXT
        )
    """)
    for e in entries:
        pointer = e.get("pointer") or {}
        reviewed = e.get("reviewed") or {}
        conn.execute(
            "INSERT INTO catalog VALUES (?, ?, ?, ?, ?, ?, ?)",
            (
                e["id"],
                e["status"],
                e.get("note") or e.get("why"),
                pointer.get("file"),
                pointer.get("symbol"),
                reviewed.get("by"),
                str(reviewed["date"]) if reviewed.get("date") is not None else None,
            ),
        )
    conn.commit()
```

- [ ] **Step 4: Run and commit**

Run: `python3 -m unittest discover -s scripts/build_rules_db -v`
Expected: `Ran 9 tests` … `OK`.

```bash
git add scripts/build_rules_db/catalog.py scripts/build_rules_db/test_catalog.py
git commit -m "feat(rules): the catalog module — validate, count, snapshot, write"
```

---

### Task 4: Remove the effects layer from the app

**Goal:** Nothing in Swift reads the `effects` table any more, so the table can go in the next task without a red build in between.

**Files:**
- Delete: `Hesindion/Engine/RuleEffectModifiers.swift`
- Modify: `Hesindion/Services/RulesDatabase.swift` (`RuleEffect`, `RuleDetail.effects`, `lookupEffects`)
- Modify: `Hesindion/Views/RuleDetailView.swift:62-70, 101-125`
- Modify: `Hesindion/Models/CombatAbility.swift` (`Wiring`, `wiring`, doc comment)
- Modify: `HesindionTests/CombatAbilityCoverageTests.swift:120-175`
- Modify: `Hesindion/Theme/Strings.swift` (remove `"effects"` in both dictionaries)

**Acceptance Criteria:**
- [ ] `grep -rn "RuleEffect\|lookupEffects\|\.effects\b\|\.wiring\|Wiring" Hesindion HesindionTests --include='*.swift'` prints nothing.
- [ ] `CombatAbilityCoverageTests` keeps the id, name, either-list, tier and sample-hero tests and loses the three that were about the effects table or `wiring`.

**Verify:** `make test-ui` → `** TEST SUCCEEDED **`; the grep above → no output.

**Steps:**

- [ ] **Step 1: Delete the dead reader**

```bash
git rm Hesindion/Engine/RuleEffectModifiers.swift
```

- [ ] **Step 2: Remove the effects type and lookup from `RulesDatabase.swift`**

Delete the `struct RuleEffect { … }` declaration, the `let effects: [RuleEffect]` line in `RuleDetail`, the `let effects = lookupEffects(ruleId: ruleId)` line and the `effects: effects,` argument in `lookup(id:)`, and the whole `func lookupEffects(ruleId:) -> [RuleEffect]` method. The `RuleDetail` initialiser call in `lookup(id:)` becomes:

```swift
        return RuleDetail(
            id: ruleId, category: category, groupId: groupId, name: name, description: desc,
            cost: cost, levels: levels, max: max,
            spellDetail: spellDetail
        )
```

- [ ] **Step 3: Drop the effects section from the rule detail screen**

In `Hesindion/Views/RuleDetailView.swift`, delete the `if !rule.effects.isEmpty { … }` block (the heading and the `ForEach`) and the whole `private func effectRow(_ effect: RuleEffect) -> some View { … }`. The catalog status takes this place in Task 6.

In `Hesindion/Theme/Strings.swift`, delete the two lines `"effects": "Effects",` and `"effects": "Effekte",`.

- [ ] **Step 4: Remove `Wiring` from `CombatAbility`**

Replace the whole of `Hesindion/Models/CombatAbility.swift` with:

```swift
import Foundation

/// Every Sonderfertigkeit this app does something with, in one list.
///
/// The ids were written inline at each of a dozen call sites, which is how three
/// of them ended up pointing at the wrong ability with the right name in a
/// comment beside it. They live here now, and `CombatAbilityCoverageTests`
/// checks each one against `rules.db` — a typo fails a test instead of silently
/// switching a rule off.
///
/// Where each one is reached in code is recorded in the rules catalog
/// (`specs/data/rules-catalog.yaml`, status `byHand`), and `RulesCatalogTests`
/// checks that every pointer names a symbol that exists. See issue #27.
enum CombatAbility: String, CaseIterable {
    case aufmerksamkeit       = "SA_40"
    case belastungsgewoehnung = "SA_41"
    case beidhaendigerKampf   = "SA_42"
    case berittenerKampf      = "SA_43"
    case finte                = "SA_48"
    case schildspalter        = "SA_59"
    case vorstoss             = "SA_66"
    case wuchtschlag          = "SA_67"
    case gezielterAngriff     = "SA_160"
    case gezielterSchuss      = "SA_161"
    case golgaritenStil       = "SA_661"
    case plaenklerFormation   = "SA_884"
}
```

- [ ] **Step 5: Trim the coverage tests**

In `HesindionTests/CombatAbilityCoverageTests.swift`, delete `testAFromEffectsClaimSurvivesTheLiveEngine`, `testEveryHandWiredAbilitySaysWhatReachesIt` and `testTheEffectsTableCoverageIsKnown` together with their doc comments (everything from `// MARK: - Something actually implements it` down to, but not including, the doc comment of `testTheSampleHeroCarriesNoAbilityTheAppIgnores`). Replace the file's leading doc comment item 3 with:

```swift
/// 3. **Nothing implements it.** Where each ability is reached is recorded in
///    the rules catalog; `RulesCatalogTests` checks the pointers (issue #27).
```

- [ ] **Step 6: Run and commit**

Run: `make test-ui`
Expected: `** TEST SUCCEEDED **`.

```bash
git add -A Hesindion HesindionTests
git commit -m "refactor(rules): the app no longer reads the effects table"
```

---

### Task 5: Build the catalog into rules.db, drop the effects table

**Goal:** `make rules-db` compiles `specs/data/rules-catalog.yaml` into a `catalog` table, fails on any catalog problem or snapshot drift, and the effects layer's files are gone.

**Files:**
- Create: `scripts/build_rules_db/scaffold_catalog.py`
- Create: `specs/data/rules-catalog.yaml` (generated, then committed)
- Create: `specs/data/rules-catalog.snapshot.json`
- Modify: `scripts/build_rules_db/build_db.py` (`parse_args`, `create_schema`, `print_stats`, `main`; delete `import_effects`, `_insert_effect`)
- Modify: `Makefile`
- Modify: `Hesindion/Resources/rules.db` (rebuilt)
- Delete: `specs/data/rules.yaml`, `scripts/scrape_effects/`

**Acceptance Criteria:**
- [ ] `make rules-db` exits 0 and prints `catalog: implemented 0, byHand 0, noRollEffect 0, todo 2675`.
- [ ] `sqlite3 Hesindion/Resources/rules.db "select count(*) from catalog"` → `2675`; `"select name from sqlite_master where name='effects'"` → empty.
- [ ] Removing one line from the catalog and running `make rules-db` exits 1 and names the id with `no catalog entry`.

**Verify:** `make rules-db` → `Built Hesindion/Resources/rules.db successfully.`; `make test-ui` → `** TEST SUCCEEDED **`.

**Steps:**

- [ ] **Step 1: The scaffold**

`scripts/build_rules_db/scaffold_catalog.py`:

```python
#!/usr/bin/env python3
"""Write the catalog skeleton: every rule id in an existing rules.db as a `todo` entry.

Run once. Afterwards the build lists any id that is missing from the catalog, and a
missing id is added by hand as one line in the same shape.
"""

import argparse
import sqlite3
from pathlib import Path


def parse_args():
    p = argparse.ArgumentParser(description="Write the rules catalog skeleton")
    p.add_argument("--db", required=True, type=Path, help="An existing rules.db to take the ids from")
    p.add_argument("--output", required=True, type=Path, help="Path of the catalog YAML to write")
    return p.parse_args()


def quoted(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    args = parse_args()
    if args.output.exists():
        raise SystemExit(f"{args.output} exists; the build lists missing ids, add them by hand")
    conn = sqlite3.connect(str(args.db))
    rows = conn.execute("""
        SELECT r.id, i.name, COALESCE(g.name, c.name)
        FROM rules r
        JOIN rules_i18n i ON i.rule_id = r.id
        JOIN categories c ON c.id = r.category
        LEFT JOIN groups g ON g.id = r.group_id
        ORDER BY r.category, CAST(substr(r.id, instr(r.id, '_') + 1) AS INTEGER)
    """).fetchall()
    lines = [
        "# The rules catalog — docs/plans/2026-09-14-rules-catalog-design.md §4.",
        "# One entry per rule id in rules.db. The build fails on a missing or unknown id,",
        "# an unknown status, a byHand pointer that does not resolve, or a todo without why.",
        "#",
        "# status: implemented | byHand | noRollEffect | todo",
        "",
    ]
    for rid, name, group in rows:
        lines.append(f"- {{ id: {rid}, name: {quoted(name)}, group: {quoted(group)}, status: todo, why: not yet read }}")
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {len(rows)} entries to {args.output}")


if __name__ == "__main__":
    main()
```

Run it against the tracked database:

```bash
python3 scripts/build_rules_db/scaffold_catalog.py --db Hesindion/Resources/rules.db --output specs/data/rules-catalog.yaml
```

Expected: `Wrote 2675 entries to specs/data/rules-catalog.yaml`.

- [ ] **Step 2: Rewrite the build script's arguments and schema**

In `scripts/build_rules_db/build_db.py`, replace `parse_args`:

```python
def parse_args():
    p = argparse.ArgumentParser(description="Build rules.db from DSA YAML data")
    p.add_argument("--source", required=True, type=Path,
                   help="Path to dsa_companion_data/Data/ directory")
    p.add_argument("--catalog", required=True, type=Path,
                   help="Path to specs/data/rules-catalog.yaml")
    p.add_argument("--snapshot", required=True, type=Path,
                   help="Path to specs/data/rules-catalog.snapshot.json")
    p.add_argument("--repo-root", required=True, type=Path,
                   help="Repository root, against which catalog pointers are resolved")
    p.add_argument("--update-snapshot", action="store_true",
                   help="Rewrite the snapshot from the catalog instead of checking against it")
    p.add_argument("--output", default=Path("rules.db"), type=Path,
                   help="Output SQLite database path")
    return p.parse_args()
```

Add `import catalog` after `import yaml`. In `create_schema`, delete the `CREATE TABLE IF NOT EXISTS effects ( … );` statement and the `CREATE INDEX IF NOT EXISTS idx_effects_rule ON effects(rule_id);` line.

- [ ] **Step 3: Replace the effects import with the catalog**

Delete `import_effects` and `_insert_effect`. Add in their place:

```python
def import_catalog(conn: sqlite3.Connection, args) -> None:
    entries = catalog.load_catalog(args.catalog)
    rules = dict(conn.execute("SELECT rule_id, name FROM rules_i18n").fetchall())
    problems = catalog.validate(entries, rules, args.repo_root)
    if problems:
        for p in problems:
            print(f"  catalog: {p}")
        raise SystemExit(f"{len(problems)} catalog problem(s); see above")
    counts = catalog.status_counts(entries)
    if args.update_snapshot:
        catalog.write_snapshot(counts, args.snapshot)
        print(f"  Wrote snapshot {args.snapshot}")
    else:
        drift = catalog.check_snapshot(counts, args.snapshot)
        if drift:
            for d in drift:
                print(f"  catalog: {d}")
            raise SystemExit("catalog counts do not match the snapshot")
    catalog.write_catalog_table(conn, entries)
    print("  catalog: " + ", ".join(f"{s} {counts[s]}" for s in catalog.STATUSES))
```

In `print_stats`, replace the two `effects_count` lines with nothing (keep `prereqs_count`). In `main`, replace `assert args.effects.is_file(), …` with `assert args.catalog.is_file(), f"Catalog not found: {args.catalog}"`, and replace

```python
    print("Importing hand-authored effects...")
    import_effects(conn, args.effects)
```

with

```python
    print("Importing the rules catalog...")
    import_catalog(conn, args)
```

Note: the FTS index is built after the catalog and must stay after it, because `import_catalog` raises before the index exists on a bad catalog, which is the wanted outcome.

- [ ] **Step 4: Makefile target**

Add to the `.PHONY` line: `rules-db`. Add after the `SAMPLE_HEROS = docs/sample_heros` line:

```make
# Optolith source data the rules database is built from (not in this repo).
DSA_DATA ?= ../../dsa_companion_data/Data
RULES_DB = Hesindion/Resources/rules.db
```

Add after the `clean:` recipe:

```make
# Rebuild the bundled rules database from the Optolith YAML and the rules
# catalog. Fails on a catalog problem or when the status counts drift from
# specs/data/rules-catalog.snapshot.json; UPDATE_SNAPSHOT=1 rewrites the snapshot.
rules-db:
	python3 scripts/build_rules_db/build_db.py \
		--source $(DSA_DATA) \
		--catalog specs/data/rules-catalog.yaml \
		--snapshot specs/data/rules-catalog.snapshot.json \
		--repo-root . \
		$(if $(UPDATE_SNAPSHOT),--update-snapshot,) \
		--output $(RULES_DB)
```

- [ ] **Step 5: Build with a fresh snapshot, then delete the old layer**

```bash
rm Hesindion/Resources/rules.db
make rules-db UPDATE_SNAPSHOT=1
```

Expected: `Wrote snapshot specs/data/rules-catalog.snapshot.json`, `catalog: implemented 0, byHand 0, noRollEffect 0, todo 2675`, `Built Hesindion/Resources/rules.db successfully.` The database is removed first because `build_db.py` uses `INSERT OR REPLACE` and would otherwise keep the old `effects` table.

```bash
git rm -r specs/data/rules.yaml scripts/scrape_effects
```

- [ ] **Step 6: Prove the guard**

Delete the `SA_884` line from `specs/data/rules-catalog.yaml`, run `make rules-db`.
Expected: `catalog: SA_884: no catalog entry`, exit 1. Restore the line (`git checkout specs/data/rules-catalog.yaml`), run `make rules-db` again → exit 0.

- [ ] **Step 7: Run the app tests and commit**

Run: `make test-ui`
Expected: `** TEST SUCCEEDED **`.

```bash
git add scripts/build_rules_db specs/data Makefile Hesindion/Resources/rules.db
git commit -m "feat(rules): rules.db carries a catalog with a status for every rule, and no effects table"
```

---

### Task 6: The app reads the catalog

**Goal:** `RulesDatabase` exposes catalog entries and counts, the rule detail screen says what the app does with a rule, and the tests that do not depend on hand entries are in place.

**Files:**
- Modify: `Hesindion/Services/RulesDatabase.swift`
- Modify: `Hesindion/Views/RuleDetailView.swift`
- Modify: `Hesindion/Theme/Strings.swift`
- Create: `HesindionTests/RulesCatalogTests.swift`

**Acceptance Criteria:**
- [ ] `RulesDatabase.shared.lookupCatalogEntry(ruleId: "SA_661")?.status == .todo` on the current database and `ruleIdsWithoutCatalogEntry()` is empty.
- [ ] `RuleDetail.catalog` is populated by `lookup(id:)`.
- [ ] The rule detail screen shows a section "In Hesindion" with the status label and, when present, the note.
- [ ] The four status labels are localized in German.

**Verify:** `make test-ui` → `** TEST SUCCEEDED **`, `RulesCatalogTests` listed.

**Steps:**

- [ ] **Step 1: Write the tests**

`HesindionTests/RulesCatalogTests.swift`:

```swift
import XCTest
@testable import Hesindion

/// The catalog is the app's answer to "which rules does it implement?" — every
/// id in `rules.db` has a status, and a `byHand` status points at the code.
/// The Python build enforces the same things; this is the Swift side reading
/// the table it produced, so a database built by hand cannot slip past.
final class RulesCatalogTests: XCTestCase {

    private func requireDatabase() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else {
            throw XCTSkip("rules.db unavailable in this run")
        }
    }

    /// `HesindionTests/RulesCatalogTests.swift` → repository root.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testEveryRuleHasACatalogEntry() throws {
        try requireDatabase()
        XCTAssertEqual(RulesDatabase.shared.ruleIdsWithoutCatalogEntry(), [])
    }

    func testAnEntryIsReadBack() throws {
        try requireDatabase()
        let entry = try XCTUnwrap(RulesDatabase.shared.lookupCatalogEntry(ruleId: "SA_661"))
        XCTAssertEqual(entry.id, "SA_661")
        XCTAssertEqual(RulesDatabase.shared.lookup(id: "SA_661")?.catalog?.status, entry.status)
    }

    func testTheCountsAddUpToTheRules() throws {
        try requireDatabase()
        let counts = RulesDatabase.shared.catalogStatusCounts()
        let total = counts.values.reduce(0, +)
        XCTAssertEqual(total, 2675, "every rule, counted once")
    }

    /// A `byHand` pointer names a file and a symbol; both must exist, or the
    /// catalog describes code that is not there.
    func testEveryPointerNamesASymbolThatExists() throws {
        try requireDatabase()
        for entry in RulesDatabase.shared.catalogEntries(status: .byHand) {
            guard let pointer = entry.pointer else {
                XCTFail("\(entry.id) is byHand without a pointer")
                continue
            }
            let url = Self.repoRoot.appending(path: pointer.file)
            let text = try String(contentsOf: url, encoding: .utf8)
            let pattern = "(?<![A-Za-z0-9_])" + NSRegularExpression.escapedPattern(for: pointer.symbol) + "(?![A-Za-z0-9_])"
            XCTAssertNotNil(text.range(of: pattern, options: .regularExpression),
                            "\(entry.id): \(pointer.symbol) is not in \(pointer.file)")
        }
    }

    func testStatusLabelsAreLocalized() {
        for status in CatalogStatus.allCases {
            XCTAssertNotEqual(L(status.labelKey), status.labelKey, "missing translation for \(status.labelKey)")
        }
        XCTAssertNotEqual(L("catalog.section"), "catalog.section")
    }
}
```

- [ ] **Step 2: Run to see it fail**

Run: `make test-ui`
Expected: build failure, `cannot find 'CatalogStatus' in scope`.

- [ ] **Step 3: The catalog types and queries**

In `Hesindion/Services/RulesDatabase.swift`, add after `struct CombatTechniqueDetail { … }`:

```swift
/// What the app does with a rule. The values are the catalog's own strings.
enum CatalogStatus: String, CaseIterable {
    /// Clauses in the catalog drive it through the evaluator (design §3; step 2).
    case implemented
    /// Named in Swift; `pointer` says where.
    case byHand
    /// Read and found to touch no roll the app makes.
    case noRollEffect
    /// Not read yet.
    case todo

    var labelKey: String { "catalog.status.\(rawValue)" }
}

struct CatalogPointer: Equatable {
    let file: String
    let symbol: String
}

struct CatalogEntry: Identifiable, Equatable {
    let id: String
    let status: CatalogStatus
    let note: String?
    let pointer: CatalogPointer?
    let reviewedBy: String?
    let reviewedOn: String?
}
```

Add `let catalog: CatalogEntry?` as the last stored property of `RuleDetail`, and in `lookup(id:)`:

```swift
        let spellDetail = (category == "spell" || category == "liturgy")
            ? lookupSpellDetail(ruleId: ruleId)
            : nil

        return RuleDetail(
            id: ruleId, category: category, groupId: groupId, name: name, description: desc,
            cost: cost, levels: levels, max: max,
            spellDetail: spellDetail,
            catalog: lookupCatalogEntry(ruleId: ruleId)
        )
```

Add after `lookupGroupName`:

```swift
    // MARK: - Catalog

    private static let catalogColumns =
        "rule_id, status, note, pointer_file, pointer_symbol, reviewed_by, reviewed_on"

    private func catalogEntry(from stmt: OpaquePointer?) -> CatalogEntry? {
        guard let status = CatalogStatus(rawValue: col_text(stmt, 1)) else { return nil }
        let file = col_text_opt(stmt, 3)
        let symbol = col_text_opt(stmt, 4)
        let pointer: CatalogPointer? = if let file, let symbol { CatalogPointer(file: file, symbol: symbol) } else { nil }
        return CatalogEntry(
            id: col_text(stmt, 0),
            status: status,
            note: col_text_opt(stmt, 2),
            pointer: pointer,
            reviewedBy: col_text_opt(stmt, 5),
            reviewedOn: col_text_opt(stmt, 6)
        )
    }

    func lookupCatalogEntry(ruleId: String) -> CatalogEntry? {
        let sql = "SELECT \(Self.catalogColumns) FROM catalog WHERE rule_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, ruleId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return catalogEntry(from: stmt)
    }

    func catalogEntries(status: CatalogStatus) -> [CatalogEntry] {
        let sql = "SELECT \(Self.catalogColumns) FROM catalog WHERE status = ? ORDER BY rule_id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, status.rawValue, -1, SQLITE_TRANSIENT)
        var results: [CatalogEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let entry = catalogEntry(from: stmt) { results.append(entry) }
        }
        return results
    }

    func catalogStatusCounts() -> [CatalogStatus: Int] {
        let sql = "SELECT status, COUNT(*) FROM catalog GROUP BY status"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }
        var counts: [CatalogStatus: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let status = CatalogStatus(rawValue: col_text(stmt, 0)) {
                counts[status] = Int(sqlite3_column_int(stmt, 1))
            }
        }
        return counts
    }

    /// Rules the catalog does not mention. The build refuses to produce such a
    /// database; this is the check that the bundled one came from the build.
    func ruleIdsWithoutCatalogEntry() -> [String] {
        let sql = "SELECT id FROM rules WHERE id NOT IN (SELECT rule_id FROM catalog) ORDER BY id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return ["<catalog table missing>"] }
        defer { sqlite3_finalize(stmt) }
        var ids: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW { ids.append(col_text(stmt, 0)) }
        return ids
    }
```

- [ ] **Step 4: The strings**

In `Hesindion/Theme/Strings.swift`, add to the English dictionary next to `"ruleNotFound"`:

```swift
        "catalog.section":              "In Hesindion",
        "catalog.status.implemented":   "Applied automatically",
        "catalog.status.byHand":        "Handled by the app",
        "catalog.status.noRollEffect":  "No effect on any roll in the app",
        "catalog.status.todo":          "Not implemented yet",
```

and to the German dictionary next to its `"ruleNotFound"`:

```swift
        "catalog.section":              "In Hesindion",
        "catalog.status.implemented":   "Automatisch angewendet",
        "catalog.status.byHand":        "Von der App umgesetzt",
        "catalog.status.noRollEffect":  "Wirkt auf keine Probe in der App",
        "catalog.status.todo":          "Noch nicht umgesetzt",
```

- [ ] **Step 5: The rule detail screen**

In `Hesindion/Views/RuleDetailView.swift`, where the effects block was (after the `if !rule.description.isEmpty { … }` block), add:

```swift
                        if let entry = rule.catalog {
                            Text(L("catalog.section"))
                                .font(.dsaHeading(.subheadline))
                                .padding(.top, 4)
                            Text(L(entry.status.labelKey))
                                .font(.dsaBody(.body))
                            if let note = entry.note, !note.isEmpty {
                                Text(note)
                                    .font(.dsaBody(.caption))
                                    .foregroundStyle(.secondary)
                            }
                        }
```

- [ ] **Step 6: Run and commit**

Run: `make test-ui`
Expected: `** TEST SUCCEEDED **`.

```bash
git add Hesindion/Services/RulesDatabase.swift Hesindion/Views/RuleDetailView.swift Hesindion/Theme/Strings.swift HesindionTests/RulesCatalogTests.swift
git commit -m "feat(rules): the app reads the catalog and the rule screen says what it does with a rule"
```

---

### Task 7: The rules the app already handles, recorded

**Goal:** Every rule the app does something with today is `byHand` with a pointer that resolves, the snapshot says so, and the tests hold coverage at that floor.

**Files:**
- Modify: `specs/data/rules-catalog.yaml`
- Modify: `specs/data/rules-catalog.snapshot.json` (via `make rules-db UPDATE_SNAPSHOT=1`)
- Modify: `Hesindion/Resources/rules.db` (rebuilt)
- Modify: `HesindionTests/RulesCatalogTests.swift`
- Modify: `HesindionTests/CombatAbilityCoverageTests.swift` (remove `testTheSampleHeroCarriesNoAbilityTheAppIgnores`)

**Acceptance Criteria:**
- [ ] `make rules-db UPDATE_SNAPSHOT=1` prints `catalog: implemented 0, byHand 46, noRollEffect 0, todo 2629`.
- [ ] Every `CombatAbility` case, ADV_5, ADV_25, ADV_26, ADV_27, ADV_44, ADV_49, ADV_54, DISADV_56, and the 25 Zustände and Status in `StateCatalog` are `byHand`.
- [ ] No Sonderfertigkeit Boronmir carries is `todo`.

**Verify:** `make rules-db` → exit 0 with the counts above; `make test-ui` → `** TEST SUCCEEDED **`.

**Steps:**

- [ ] **Step 1: Write the failing tests**

Add to `HesindionTests/RulesCatalogTests.swift`:

```swift
    /// The floor. Adding entries must not fail this; losing one must.
    func testCoverageDoesNotGoBackwards() throws {
        try requireDatabase()
        let counts = RulesDatabase.shared.catalogStatusCounts()
        XCTAssertGreaterThanOrEqual((counts[.implemented] ?? 0) + (counts[.byHand] ?? 0), 46)
    }

    func testEveryCombatAbilityHasAStatusOtherThanTodo() throws {
        try requireDatabase()
        for ability in CombatAbility.allCases {
            let status = RulesDatabase.shared.lookupCatalogEntry(ruleId: ability.rawValue)?.status
            XCTAssertNotEqual(status, .todo, "\(ability) is in code but the catalog says todo")
            XCTAssertNotNil(status, "\(ability) has no catalog entry")
        }
    }

    func testEveryCatalogStateHasAStatusOtherThanTodo() throws {
        try requireDatabase()
        let ids = ["COND_1", "COND_2", "COND_3", "COND_4", "COND_5", "COND_6", "COND_7", "COND_9",
                   "STATE_1", "STATE_2", "STATE_3", "STATE_5", "STATE_6", "STATE_7", "STATE_8", "STATE_9",
                   "STATE_10", "STATE_11", "STATE_12", "STATE_13", "STATE_14", "STATE_15", "STATE_19",
                   "STATE_20", "STATE_21"]
        XCTAssertEqual(ids.count, StateCatalog.all.count, "one rules.db id per StateCatalog entry")
        for id in ids {
            XCTAssertEqual(RulesDatabase.shared.lookupCatalogEntry(ruleId: id)?.status, .byHand, id)
        }
    }

    /// Importing a hero with an ability nothing handles should fail here, not go
    /// unnoticed at the table. `SA_27` and `SA_29` carry Schriften and Sprachen
    /// and never become traits.
    func testTheSampleHeroCarriesNoAbilityTheAppIgnores() throws {
        try requireDatabase()
        let notAbilities: Set<String> = ["SA_27", "SA_29"]
        let hero = try TestData.importBoronmir(into: TestData.makeContainer())
        let carried = (hero.combatSpecialAbilities + hero.generalSpecialAbilities)
            .map(\.ruleId)
            .filter { !notAbilities.contains($0) }
        XCTAssertFalse(carried.isEmpty)
        for ruleId in carried {
            let status = RulesDatabase.shared.lookupCatalogEntry(ruleId: ruleId)?.status
            XCTAssertNotEqual(status, .todo,
                              "\(ruleId) (\(RulesDatabase.shared.lookup(id: ruleId)?.name ?? "?")) is on the hero sheet and the catalog says todo")
        }
    }
```

Delete `testTheSampleHeroCarriesNoAbilityTheAppIgnores` and its doc comment from `HesindionTests/CombatAbilityCoverageTests.swift`.

- [ ] **Step 2: Run to see them fail**

Run: `make test-ui`
Expected: `testCoverageDoesNotGoBackwards`, `testEveryCombatAbilityHasAStatusOtherThanTodo`, `testEveryCatalogStateHasAStatusOtherThanTodo` and `testTheSampleHeroCarriesNoAbilityTheAppIgnores` fail; everything else passes.

- [ ] **Step 3: Write the hand entries**

In `specs/data/rules-catalog.yaml`, delete the 46 `todo` lines for the ids below and insert these block entries after the header comment, before the first `todo` line. The note says what the code does *today*, discrepancies with the rules included, because that is what a reader with only an id needs.

```yaml
# ---------------------------------------------------------------------------
# Handled by the app today (status byHand). The pointer names the symbol that
# reaches the rule; the build and RulesCatalogTests check it exists.
# ---------------------------------------------------------------------------

- id: SA_40
  name: "Aufmerksamkeit"
  group: "Kampf"
  status: byHand
  pointer: { file: Hesindion/Models/Hero.swift, symbol: hasAufmerksamkeit }
  note: "TalentProbeModal offers +2 on Sinnesschärfe (TAL_10) when the hero has it; a talent modifier, not a combat value."

- id: SA_41
  name: "Belastungsgewöhnung"
  group: "Kampf"
  status: byHand
  pointer: { file: Hesindion/Models/Hero.swift, symbol: effectiveBE }
  note: "Reduces BE by tier before every value derived from it (AT, PA, AW, INI, GS)."

- id: SA_42
  name: "Beidhändiger Kampf"
  group: "Kampf"
  status: byHand
  pointer: { file: Hesindion/Models/Hero.swift, symbol: beidhaendigerKampfLevel }
  note: "Each tier takes 1 off the −2 dual-attack penalty (MeleeModifiers.dualAttackPenalty)."

- id: SA_43
  name: "Berittener Kampf"
  group: "Kampf"
  status: byHand
  pointer: { file: Hesindion/Models/Hero.swift, symbol: hasBerittenerKampf }
  note: "CombatAttackViews offers Sturmangriff zu Pferd when the hero has it."

- id: SA_48
  name: "Finte"
  group: "Kampf"
  status: byHand
  pointer: { file: Hesindion/Models/Hero.swift, symbol: finteTier }
  note: "Offered as a manoeuvre (CombatManeuver): AT −1 per tier, opponent PA −2 per tier as an opponent line."

- id: SA_59
  name: "Schildspalter"
  group: "Kampf"
  status: byHand
  pointer: { file: Hesindion/Models/CombatManeuver.swift, symbol: schildspalter }
  note: "Offered as a manoeuvre on the announcement screen."

- id: SA_66
  name: "Vorstoß"
  group: "Kampf"
  status: byHand
  pointer: { file: Hesindion/Models/CombatManeuver.swift, symbol: vorstoss }
  note: "Offered as a manoeuvre on the announcement screen: AT +2, no defence this round."

- id: SA_67
  name: "Wuchtschlag"
  group: "Kampf"
  status: byHand
  pointer: { file: Hesindion/Models/Hero.swift, symbol: wuchtschlagTier }
  note: "Offered as a manoeuvre, every tier up to the hero's selectable: AT −2 and TP +2 per tier (CombatManeuver, DamageModifiers)."

- id: SA_160
  name: "Gezielter Angriff"
  group: "Kampf"
  status: byHand
  pointer: { file: Hesindion/Models/Hero.swift, symbol: hasGezielterAngriff }
  note: "HitZoneModifiers halves the Zonenaufschlag in melee (Trefferzonen Fokusregel)."

- id: SA_161
  name: "Gezielter Schuss"
  group: "Kampf"
  status: byHand
  pointer: { file: Hesindion/Models/Hero.swift, symbol: hasGezielterSchuss }
  note: "HitZoneModifiers halves the Zonenaufschlag at range (Trefferzonen Fokusregel)."

- id: SA_661
  name: "Golgariten-Stil"
  group: "Kampfstile (bewaffnet)"
  status: byHand
  pointer: { file: Hesindion/Models/Hero.swift, symbol: golgaritenActive }
  note: "Mounted with Rabenschnabel AND Großschild: +2 AT (Vorteilhafte Position) +2 AT, +1 PA, +1 TP. The Regelwiki says +1 PA and no TP, and Rabenschnabel OR Großschild — to be corrected in step 2 (design §4)."

- id: SA_884
  name: "Plänkler-Formation"
  group: "Kampf"
  status: byHand
  pointer: { file: Hesindion/Engine/MeleeModifiers.swift, symbol: plaenklerAT }
  note: "CombatSetupView asks AT or VW per fight; +1 on the chosen one (MeleeModifiers.plaenklerAT, DefenseModifiers.plaenklerVW)."

- id: ADV_5
  name: "Beidhändig"
  group: "Vorteil"
  status: byHand
  pointer: { file: Hesindion/Models/Hero.swift, symbol: hasBeidhaendig }
  note: "Removes the −4 off-hand penalty."

- id: ADV_25
  name: "Hohe Lebenskraft"
  group: "Vorteil"
  status: byHand
  pointer: { file: Hesindion/Services/OptolithImportService.swift, symbol: hoheLebenskraftBonus }
  note: "+1 LeP per tier on import."

- id: ADV_26
  name: "Hohe Seelenkraft"
  group: "Vorteil"
  status: byHand
  pointer: { file: Hesindion/Services/OptolithImportService.swift, symbol: hoheSeelenkraftBonus }
  note: "+1 SK per tier on import."

- id: ADV_27
  name: "Hohe Zähigkeit"
  group: "Vorteil"
  status: byHand
  pointer: { file: Hesindion/Services/OptolithImportService.swift, symbol: hoheZaehigkeitBonus }
  note: "+1 ZK per tier on import."

- id: ADV_44
  name: "Verbesserte Regeneration (Lebensenergie)"
  group: "Vorteil"
  status: byHand
  pointer: { file: Hesindion/Models/Hero.swift, symbol: verbessertRegenerationLEBonus }
  note: "+1 LeP regeneration, +2 at tier II."

- id: ADV_49
  name: "Zäher Hund"
  group: "Vorteil"
  status: byHand
  pointer: { file: Hesindion/Models/Hero.swift, symbol: hasZaeherHund }
  note: "Effective Schmerz is one level lower, except level IV."

- id: ADV_54
  name: "Eisern"
  group: "Vorteil"
  status: byHand
  pointer: { file: Hesindion/Engine/DerivedValueFormulas.swift, symbol: wundschwelle }
  note: "Wundschwelle +1."

- id: DISADV_56
  name: "Gläsern"
  group: "Nachteil"
  status: byHand
  pointer: { file: Hesindion/Engine/DerivedValueFormulas.swift, symbol: wundschwelle }
  note: "Wundschwelle −1."
```

Then the Zustände and Status, all pointing at `StateCatalog`. For each id below, the `group` is `"Zustand (leveled)"` for `COND_` ids and `"Status (binary)"` for `STATE_` ids, the `name` is the one already on the generated line, and the entry reads:

```yaml
- id: COND_1
  name: "Belastung"
  group: "Zustand (leveled)"
  status: byHand
  pointer: { file: Hesindion/Models/StateCatalog.swift, symbol: belastung }
  note: "Derived from equipped armour; the penalty comes from Hero.belastungPenalty, the catalog entry is reminder-only."
```

with these id → symbol → note pairs:

| id | symbol | note |
|---|---|---|
| COND_1 | `belastung` | as above |
| COND_2 | `betaeubung` | "−level on every check (StateModifiers), counts toward the −5 Zustand cap." |
| COND_3 | `entrueckung` | "StateModifiers.entrueckungDef: gottgefällig +(level−1), everything else −level." |
| COND_4 | `furcht` | "−level on every check (StateModifiers), counts toward the cap." |
| COND_5 | `paralyse` | "−level on every check (StateModifiers), counts toward the cap." |
| COND_6 | `schmerz` | "Derived from LP; −level on every check, counts toward the cap; ADV_49 lowers it." |
| COND_7 | `verwirrung` | "−level on every check (StateModifiers), counts toward the cap." |
| COND_9 | `berauscht` | "Reminder only: the app cannot yet tell a Zechen check apart." |
| STATE_1 | `bewegungsunfaehig` | "Reminder and combat-root warning banner; no modifier." |
| STATE_2 | `bewusstlos` | "Reminder only; implies Handlungsunfähig." |
| STATE_3 | `blind` | "Reminder only." |
| STATE_5 | `brennend` | "Reminder only." |
| STATE_6 | `eingeengt` | "Single source of truth for Beengte Umgebung: AT/PA penalty by weapon reach (MeleeModifiers.beengteUmgebungAT)." |
| STATE_7 | `fixiert` | "AW −4 (StateModifiers)." |
| STATE_8 | `handlungsunfaehig` | "Reminder and combat-root warning banner; no modifier." |
| STATE_9 | `krank` | "Reminder only." |
| STATE_10 | `liegend` | "Hero: AT −4, PA/AW −2 (StateModifiers). Opponent: −2 on their defence as an opponent line (OpponentProfile.isProne)." |
| STATE_11 | `stumm` | "Reminder only." |
| STATE_12 | `taub` | "Reminder only." |
| STATE_13 | `ueberrascht` | "Reminder only for the hero; the opponent's surprise is a GM flag (ModifierContext.targetIsSurprised)." |
| STATE_14 | `unsichtbar` | "Reminder only." |
| STATE_15 | `vergiftet` | "Reminder only." |
| STATE_19 | `uebler_geruch` | "Reminder only." |
| STATE_20 | `versteinert` | "Reminder only." |
| STATE_21 | `blutend` | "Reminder only." |

- [ ] **Step 4: Check the two manoeuvre pointers**

`schildspalter` and `vorstoss` are the expected case names in `CombatManeuver`. Confirm before building:

```bash
grep -n "schildspalter\|vorstoss" Hesindion/Models/CombatManeuver.swift
```

If a name differs (for example `vorstoß`), use the identifier the file actually declares in the pointer. The build fails on a symbol it cannot find, so a wrong guess cannot land.

- [ ] **Step 5: Rebuild with the new snapshot**

```bash
make rules-db UPDATE_SNAPSHOT=1
```

Expected: `catalog: implemented 0, byHand 46, noRollEffect 0, todo 2629` and `Built Hesindion/Resources/rules.db successfully.` Any `catalog:` problem line means an entry is wrong; fix the entry, not the check.

- [ ] **Step 6: Run and commit**

Run: `make test-ui`
Expected: `** TEST SUCCEEDED **`.

```bash
git add specs/data/rules-catalog.yaml specs/data/rules-catalog.snapshot.json Hesindion/Resources/rules.db HesindionTests/RulesCatalogTests.swift HesindionTests/CombatAbilityCoverageTests.swift
git commit -m "feat(rules): the 46 rules the app handles are on record, and the count cannot shrink unnoticed"
```

---

### Task 8: Documentation

**Goal:** `AGENTS.md` and the changelog describe the catalog, not the effects table.

**Files:**
- Modify: `AGENTS.md:85-86` and the `## Build & Run` section
- Modify: `CHANGELOG.md`

**Acceptance Criteria:**
- [ ] `grep -n "effects table\|RuleEffectModifiers\|wiring" AGENTS.md` prints nothing.
- [ ] `AGENTS.md` says how to rebuild `rules.db` and what fails the build.

**Verify:** the grep above → no output; `git diff --stat` shows only the two files.

**Steps:**

- [ ] **Step 1: Replace the two AGENTS.md bullets**

Replace the bullet beginning `- **Sonderfertigkeit ids live in \`CombatAbility\`` and the one beginning `- **Every ability is hand-wired today.**` with:

```markdown
- **Sonderfertigkeit ids live in `CombatAbility`, never as bare strings, and every one of them is covered by a test.** An ability can be ignored silently in three ways — a wrong id, the importer filing it out of reach, or nothing implementing it — and none of them show on screen: the ability is on the hero sheet and the roll is merely a little low. So: `CombatAbilityCoverageTests` checks every id against `rules.db` by name, the importer files an ability as combat by its Optolith group (`CombatSpecialAbilityGroup`), and `Hero.specialAbility(_:)` still searches both lists for heroes imported before that fix
- **The rules catalog says what the app does with every rule.** `specs/data/rules-catalog.yaml` has one entry per rule id in `rules.db` with a status — `implemented`, `byHand` (with a pointer to the Swift symbol), `noRollEffect`, `todo` — and `make rules-db` compiles it into the `catalog` table. The build fails on a missing or unknown id, a pointer that does not resolve, or status counts that drift from `specs/data/rules-catalog.snapshot.json` (`UPDATE_SNAPSHOT=1` rewrites it, and the snapshot goes in the same commit). `RulesCatalogTests` checks the same things against the bundled database and holds coverage at its floor. The rule detail screen shows the status. Adding an ability today means wiring it, adding it to `CombatAbility`, and moving its catalog entry from `todo` to `byHand`; **issue #27** and `docs/plans/2026-09-14-rules-catalog-design.md` are where `implemented` entries with clauses arrive (step 2)
```

- [ ] **Step 2: Document the build target**

In `AGENTS.md`, under the `make` block in `## Build & Run`, add the line:

```
make rules-db     # Rebuild Hesindion/Resources/rules.db from the Optolith YAML (DSA_DATA) and the rules catalog
```

- [ ] **Step 3: Changelog**

Under `## [Unreleased]` in `CHANGELOG.md`, add:

```markdown
### Added

- **A rules catalog with a status for every rule.** `rules.db` now says, for each of its 2675 rules, whether the app applies it automatically, handles it in code (and where), has read it and found no roll it touches, or has not read it yet. The build refuses a database where a rule is missing from the catalog, a pointer names code that does not exist, or the counts move without the committed snapshot moving with them; the rule detail screen shows the status. Forty-six rules are on record today. Issue #27
```

and under `### Removed`:

```markdown
- The `effects` table, `specs/data/rules.yaml`, the Regelwiki scraper and `RuleEffectModifiers`. Eighty-two hand-written rows for 26 rules, read by code nothing called; the catalog replaces all of it
```

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md CHANGELOG.md
git commit -m "docs(rules): the catalog replaces the effects table in the agent notes and the changelog"
```

---

## Self-review

**Spec coverage (design §7 steps 0 and 1):** importer off the effects table → Task 1. Catalog file with every id → Tasks 5 and 7. `byHand` with pointers for the rules the app handles → Task 7 (46: the 12 `CombatAbility` cases including SA_42, 8 Vorteile/Nachteile, 25 states, plus ADV_25/26/27 — the design said nineteen before SA_42 and the states were counted). Build compiles it and deletes the effects table, `rules.yaml`, `RuleEffectModifiers`, scraper → Tasks 4 and 5. `CombatAbility.wiring` replaced by the catalog status → Task 4. Structural checks and snapshot → Tasks 3, 5, 6, 7. Coverage a measured number → Task 7's floor test. `GRW_*` entries, clauses, the vocabulary, the evaluator: step 2, not here.

**Placeholders:** none; every step carries its code or its exact command. The two manoeuvre symbols in Task 7 are stated and verified by a grep step and by the build itself.

**Type consistency:** `RuleDetail.groupId` (Task 1) and `RuleDetail.catalog` (Task 6) both appear in the initialiser call shown in Task 6; `lookupGroupName` (Task 1) precedes the `// MARK: - Catalog` block (Task 6); `CatalogStatus.labelKey` is used by the view (Task 6) and the test (Task 6); `catalogEntries(status:)`, `catalogStatusCounts()`, `ruleIdsWithoutCatalogEntry()` are defined in Task 6 and used in Tasks 6 and 7; `catalog.STATUSES`, `validate`, `status_counts`, `check_snapshot`, `write_snapshot`, `write_catalog_table` are defined in Task 3 and called in Task 5.
