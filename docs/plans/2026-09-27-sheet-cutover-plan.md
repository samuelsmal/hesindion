# Domain 1 cut-over: the sheet's derived values — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every base value the app shows or rolls against (LE max, Wundschwelle, INI, AW, GS, AT/PA per technique, weapon and shield) comes from `Packages/RulesEngine`, and a tap on it shows its lines with their origin.

**Architecture:** The app maps its SwiftData `Hero` into a plain `HeroSheet` (package type), which becomes an engine `Situation`. `SheetValues` evaluates every base value once per distinct `HeroSheet` and hands the views a `Breakdown` per value. Belastung and Zustände stay in Swift for the rolls until domains 2 and 4; the roll screens read the base without the `COND_1` lines.

**Tech Stack:** Swift 6.2 package (`Packages/RulesEngine`, XCTest), SwiftUI + SwiftData app (Swift 5 mode, iOS 26), `rulec` (Python, `uv`), Make.

**Spec:** [`docs/plans/2026-09-27-sheet-cutover-design.md`](2026-09-27-sheet-cutover-design.md) — read it first; the parent is [`2026-09-24-rules-engine-design.md`](2026-09-24-rules-engine-design.md) §9.

## Global Constraints

- **Data Policy (AGENTS.md):** no DSA rule prose in code comments, docs or commit messages. Rule ids, clause ids and our own numbers only.
- **Project conventions (AGENTS.md):** Makefile targets for every build/test; new Swift files land in the app target automatically (the project uses `PBXFileSystemSynchronizedRootGroup`); only the local package reference needs `project.pbxproj` edits. User-facing strings go through `L("key")` in `Hesindion/Theme/Strings.swift`, English and German.
- **Rounding (ADR-0006):** the engine owns it now; no Swift code recomputes a base value.
- **Fact names are the engine's:** `attr.MU`…`attr.KK`, `ktw.CT_n`, `fw.TAL_n`, `hero.purchased.le`, `species.le`, `loadout.weapon`, `loadout.shield`, `loadout.other` (`shield`), `loadout.armour`, `loadout.armour.belastung`, `loadout.armour.extraPenalty`, `item.<name>.template`, `item.<name>.technique`, `item.<name>.atMod`, `item.<name>.paMod`, `check.kind`, `check.talent`, `check.hinderedByBelastung`, `choice.belastungZaehlt`. Base key for GS: `Situation.base["gs"]`.
- **Queries:** `leMax`, `wundschwelle`, `iniBase`, `aw`, `gs`, `at(with: X)`, `pa(with: X)`, `check.modifier`.
- **No double counting:** until domain 2, a roll screen reads `withoutBelastung`; until domain 4, `HeroSheet` holds no Zustände and no current LE; the talent check takes only the `COND_1` lines from the engine.
- **Commits:** end every commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Do not push.
- **Verification commands:** `make test-rules-engine` (package), `make test-rulec` (Python), `make test` (app unit tests), `make test-ui` (UI tests). `make test`/`make test-ui` need `DSA_DATA` for `rules-db`.

**User decisions (already made):**
- Approach A: `HeroSheet` in the package, the mapping in the app, values computed live, `rules.json` bundled like `rules.db`.
- Every reader of a base value switches in this change, not only the sheet.
- Belastung: the sheet shows the engine's lines; the rolls keep `SharedModifiers.encumbrance` until domain 2, with a guard test.
- No Zustände and no current LE in `HeroSheet` until domain 4.
- GS joins domain 1.
- Talent checks get the engine's `COND_1` line now, with the "Vor der Probe" reminder: "Für diese Probe abgelegt", "Belastung nicht anwenden" (shown struck through), "Belastung zählt" (maybe-talents). Choices hold for one check; a link opens the loadout picker.
- A tap on a value opens a half-height breakdown sheet.
- Design doc lives in `docs/plans/`; so does this plan.

**Changes from the spec found while planning** (the spec's intent is kept; these are the mechanics):
1. The engine reads no talent table (`CheckAttributes.swift` in the harness says so). `rulec` also writes `build/rules/checks.json`, the package gets a public `CheckTable`, and the app bundles `checks.json` beside `rules.json`.
2. Only three items have a rule file (`ITEMTPL_19`, `_29`, `_35`). An item whose template has one enters the engine under the **rule's name** (the rules' `when`s compare names, `ITEMTPL_29.GR1`); any other item enters under its own name with `item.<name>.technique/atMod/paMod` stated.
3. `MeleeWeapon` stores no AT/PA-Mod (the import folds it into `at`/`pa`), `Shield` no AT-Mod, and heroes imported before ADR-0006 have no `speciesId`. New stored **inputs** (`MeleeWeapon.atModifier/paModifier`, `Shield.atModifier`, `DerivedValues.speciesLE`) are added in SchemaV5 and back-filled at launch from the old folded values.
4. Because the back-fill reads them, the old folded fields (`CombatTechnique.at/pa`, `MeleeWeapon.at/pa`, `Shield.at/pa`, `LifeEnergyValue.base/bonus/max`) are deleted in SchemaV7 (Task 11), after the owner confirms every device ran a build with SchemaV6. Every other deletion of spec §4 is in Task 9 (SchemaV6).
5. The app and the package both define `Situation`. In an app file that imports `RulesEngine`, write `RulesEngine.Situation` for the engine's and `Hesindion.Situation` for the app's. App test classes that call `SheetValues` or `TalentBelastung` (both `@MainActor`) are marked `@MainActor`.

---

## File Structure

**Package (`Packages/RulesEngine/Sources/RulesEngine/`):**
- `HeroSheet.swift` (new) — the input struct and `Situation(sheet:)`. One responsibility: turn plain hero inputs into engine facts.
- `CheckTable.swift` (new) — the talent/spell table (`attributes`, `hinderedByBelastung`), decoded from `checks.json`. Moved out of the test harness.

**Package tests (`Packages/RulesEngine/Tests/RulesEngineTests/`):**
- `HeroSheetTests.swift` (new); `Harness/CheckAttributes.swift` (modified: uses `CheckTable`).

**rulec (`scripts/rulec/`):** `compile.py` (writes `checks.json`), `test_compile.py`.

**App (`Hesindion/`):**
- `RulesEngine/RulesEngineStore.swift` (new) — loads `rules.json` + `checks.json`, holds one `Engine`.
- `RulesEngine/HeroSheetMapping.swift` (new) — `Hero` → `HeroSheet`.
- `RulesEngine/SheetValues.swift` (new) — the cache and the per-value breakdowns.
- `RulesEngine/SheetInputBackfill.swift` (new) — the launch back-fill of the new inputs.
- `RulesEngine/TalentBelastung.swift` (new) — the talent check's `COND_1` line and the reminder state.
- `Views/BreakdownSheet.swift` (new) — the breakdown view.
- `Views/VorDerProbeRow.swift` (new) — the reminder row.
- `Migration/SchemaV5.swift`, `Migration/SchemaV6.swift` (new), `Migration/MigrationPlan.swift` (modified).
- Modified readers: `Views/HeroDetailView.swift`, `Views/CombatLoadoutPicker.swift`, `Views/CombatRootView.swift`, `Views/CombatSetupViews.swift`, `Views/CombatDefenseSetupView.swift`, `Views/CombatAttackViews.swift`, `Views/CombatFernkampfViews.swift`, `Views/CombatWoundEffectViews.swift`, `Views/CombatDamageViews.swift`, `Views/CombatDamageOutcomeBox.swift`, `Views/HeilungSheet.swift`, `Views/CommandPaletteOverlay.swift`, `Views/TalentProbeModal.swift`, `Engine/PassierschlagRoll.swift`, `Models/Hero.swift`, `Models/LogEntry.swift`.
- Deleted code: parts of `Engine/DerivedValueFormulas.swift`, `Services/DerivedValueRepair.swift`, `Services/OptolithImportService.swift`.

**App tests (`HesindionTests/`):** `RulesEngineStoreTests.swift`, `HeroSheetMappingTests.swift`, `SheetValuesTests.swift`, `SheetInputBackfillTests.swift`, `TalentBelastungTests.swift` (new); `Fixtures/HeroSheets/*.json` (new, generated).

**UI tests (`HesindionUITests/`):** `SheetBreakdownTests.swift` (new).

**Build:** `Makefile`, `.gitignore`, `Hesindion.xcodeproj/project.pbxproj`.

**Specs/docs:** `specs/data/rules-catalog.yaml`, `specs/data/rules-catalog.snapshot.json`, `AGENTS.md`, `CHANGELOG.md`, the spec's status line.

---

### Task 1: `checks.json` and a public `CheckTable`

**Goal:** `make rules-json` writes `build/rules/checks.json`, and the package exposes `CheckTable` to decode it, so the app can state `check.hinderedByBelastung`.

**Files:**
- Modify: `scripts/rulec/compile.py` (the `build` output step that writes `rules.json` and `situations.json`)
- Modify: `scripts/rulec/test_compile.py`
- Create: `Packages/RulesEngine/Sources/RulesEngine/CheckTable.swift`
- Modify: `Packages/RulesEngine/Tests/RulesEngineTests/Harness/CheckAttributes.swift`
- Test: `Packages/RulesEngine/Tests/RulesEngineTests/HeroSheetTests.swift` (create; first test lives here)

**Acceptance Criteria:**
- [ ] `make rules-json` writes `build/rules/checks.json`, a JSON object `{ "checks": { "TAL_n": { "attributes": [...], "hinderedByBelastung": true|false|"maybe" }, ... } }` equal to `situations.json`'s `checks`
- [ ] `CheckTable.decode(_:)` is public and returns `hinderedByBelastung["TAL_5"] == .bool(true)` for the real file
- [ ] The harness's `CheckAttributes.table(from:)` builds its `Table` through `CheckTable`; the harness result is unchanged (285 passed, 0 failed, 11 pending, 12 conflict, 1 unsupported)
- [ ] `make test-rulec` passes

**Verify:** `make test-rulec && make test-rules-engine 2>&1 | grep "harness:"` → `harness: 285 passed, 0 failed, 11 pending, 12 conflict, 1 unsupported`

**Steps:**

- [ ] **Step 1: Find the writer.** Run `grep -n "situations.json\|rules.json" scripts/rulec/compile.py scripts/rulec/__main__.py`. The build step writes both files from one `checks` dict (the `checks` key of `situations.json`).

- [ ] **Step 2: Write the failing rulec test** in `scripts/rulec/test_compile.py`, following the file's existing build tests (they build into a temp dir):

```python
    def test_build_writes_checks_json_equal_to_the_situations_checks(self):
        out = Path(self.tmp) / "out"
        self.build_into(out)          # use the helper the other build tests use
        checks = json.loads((out / "checks.json").read_text(encoding="utf-8"))
        situations = json.loads((out / "situations.json").read_text(encoding="utf-8"))
        self.assertEqual(checks, {"checks": situations["checks"]})
```

If the file has no `build_into` helper, call the same function the neighbouring build test calls, with the same arguments.

- [ ] **Step 3: Run it.** `make test-rulec` → FAIL (`checks.json` missing).

- [ ] **Step 4: Write `checks.json`** next to `situations.json` in the build step:

```python
    (out / "checks.json").write_text(
        json.dumps({"checks": checks}, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
        encoding="utf-8")
```

(`checks` is the same dict the step puts under `situations.json`'s `"checks"`.) Run `make test-rulec` → PASS.

- [ ] **Step 5: Write the failing package test** in the new `HeroSheetTests.swift`:

```swift
import XCTest
@testable import RulesEngine

final class HeroSheetTests: XCTestCase {
    func testTheCheckTableDecodesTheBuiltFile() throws {
        let data = try Data(contentsOf: Repo.url("build/rules/checks.json"))
        let table = try CheckTable.decode(data)
        XCTAssertEqual(table.hinderedByBelastung["TAL_5"], .bool(true))
        XCTAssertEqual(table.attributes["TAL_5"], ["KO", "KK", "KK"])
    }
}
```

(`Repo.url` is the harness helper that `CheckAttributes` already uses.)

- [ ] **Step 6: Create `CheckTable.swift`:**

```swift
import Foundation

/// The Probe table rulec compiles from `specs/rules/checks.yaml` into `build/rules/checks.json`:
/// each talent's and spell's three attributes, and each talent's Belastung flag. The engine reads
/// no such table; its caller (the app, the harness) states `check.hinderedByBelastung` from it.
public struct CheckTable: Equatable, Sendable {
    /// Talent or spell id → its three attributes, by the sheet's names (`attr.<name>`).
    public var attributes: [String: [String]]
    /// Talent id → `true`, `false` or `"maybe"` (COND_1.belastung-reach).
    public var hinderedByBelastung: [String: JSONValue]

    public init(attributes: [String: [String]] = [:], hinderedByBelastung: [String: JSONValue] = [:]) {
        self.attributes = attributes
        self.hinderedByBelastung = hinderedByBelastung
    }

    /// Reads a file whose top level has `checks` (`checks.json`, and `situations.json` too).
    public static func decode(_ data: Data) throws -> CheckTable {
        struct Row: Decodable { var attributes: [String]; var hinderedByBelastung: JSONValue? }
        struct File: Decodable { var checks: [String: Row] }
        let rows = try JSONDecoder().decode(File.self, from: data).checks
        return CheckTable(attributes: rows.mapValues(\.attributes),
                          hinderedByBelastung: rows.compactMapValues(\.hinderedByBelastung))
    }
}
```

- [ ] **Step 7: Point the harness at it.** In `Harness/CheckAttributes.swift`, make `Table` a typealias for `CheckTable` and replace the body of `table(from:)`:

```swift
    typealias Table = CheckTable

    static func table(from url: URL) -> Table {
        guard let data = try? Data(contentsOf: url) else { return Table() }
        return (try? CheckTable.decode(data)) ?? Table()
    }
```

Keep `shared`, `all` and `hinderedByBelastung` as they are.

- [ ] **Step 8: Run** `make test-rules-engine`. Expected: all tests pass, and the `harness:` line is unchanged.

- [ ] **Step 9: Commit.**

```bash
git add scripts/rulec/compile.py scripts/rulec/test_compile.py Packages/RulesEngine
git commit -m "feat(rulec): checks.json, and the package's CheckTable reads it

The engine reads no talent table; the app will state check.hinderedByBelastung
from it, as the harness does.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

```json:metadata
{"files": ["scripts/rulec/compile.py", "scripts/rulec/test_compile.py", "Packages/RulesEngine/Sources/RulesEngine/CheckTable.swift", "Packages/RulesEngine/Tests/RulesEngineTests/Harness/CheckAttributes.swift", "Packages/RulesEngine/Tests/RulesEngineTests/HeroSheetTests.swift"], "verifyCommand": "make test-rulec && make test-rules-engine 2>&1 | grep 'harness:'", "acceptanceCriteria": ["make rules-json writes build/rules/checks.json equal to situations.json's checks", "CheckTable.decode is public; TAL_5 hinderedByBelastung == .bool(true)", "harness line unchanged: 285 passed, 0 failed, 11 pending, 12 conflict, 1 unsupported", "make test-rulec passes"], "modelTier": "standard"}
```

---

### Task 2: `HeroSheet` and `Situation(sheet:)`

**Goal:** A public, `Hashable` `HeroSheet` in the package that becomes the same facts `scripts/rulec/hero.py` writes, plus the loadout, species LE and species GS; Boronmir's sheet values through it equal the harness's.

**Files:**
- Create: `Packages/RulesEngine/Sources/RulesEngine/HeroSheet.swift`
- Modify: `Packages/RulesEngine/Tests/RulesEngineTests/HeroSheetTests.swift`

**Acceptance Criteria:**
- [ ] `HeroSheet` is `public struct … : Codable, Hashable, Sendable` with `owned`, `attributes`, `techniques`, `talents`, `purchasedLE`, `speciesLE`, `speciesGS`, `items`, `loadout`
- [ ] `Situation(sheet:)` states every input as a fact with the owner `sheet` (hero values) or `loadout` (loadout and item facts), and sets `base["gs"]` from `speciesGS`
- [ ] An item with `template` states only `item.<name>.template`; an item without states `technique`, `atMod`, `paMod`
- [ ] Boronmir (the values of `specs/rules/situations/kampfwerte.yaml`'s header, SA_41 II, ADV_25 II, ADV_54): `leMax` 37, `at(with: Rabenschnabel)` 16, `pa(with: Rabenschnabel)` 8 (9 − 1 for its PA-Mod), and `at(with: Rabenschnabel)` with the Großschild in the shield slot 15 (GR1)
- [ ] With Plattenrüstung (Belastung 3) and SA_41 II, `at(with: Rabenschnabel)` carries exactly one `COND_1` line of −1

**Verify:** `swift test --package-path Packages/RulesEngine --filter HeroSheetTests` → all pass

**Steps:**

- [ ] **Step 1: Write the failing tests** (append to `HeroSheetTests`):

```swift
    static let book: RuleBook = try! RuleBook.load(from: Repo.url("build/rules/rules.json"))

    /// Boronmir as kampfwerte.yaml's header states him.
    static func boronmir(loadout: HeroSheet.Loadout = .init(),
                         items: [HeroSheet.Item] = []) -> HeroSheet {
        HeroSheet(
            owned: ["SA_41": .init(level: 2), "ADV_25": .init(level: 2), "ADV_54": .init(level: 1)],
            attributes: ["MU": 14, "KL": 12, "IN": 13, "CH": 13, "FF": 11, "GE": 14, "KO": 15, "KK": 14],
            techniques: ["CT_5": 14, "CT_12": 12, "CT_10": 10, "CT_9": 10, "CT_3": 8],
            talents: [:], purchasedLE: 0, speciesLE: 5, speciesGS: 8,
            items: items, loadout: loadout)
    }

    static let rabenschnabel = HeroSheet.Item(name: "Rabenschnabel", template: "ITEMTPL_19")
    static let grossschild = HeroSheet.Item(name: "Großschild", template: "ITEMTPL_29")

    func result(_ q: String, _ sheet: HeroSheet) -> Int? {
        Engine(book: Self.book).evaluate(Query(q), in: Situation(sheet: sheet)).result
    }

    func testTheSheetFactsAreHeroPysAndTheLoadouts() {
        let s = Situation(sheet: Self.boronmir(loadout: .init(weapon: "Rabenschnabel"),
                                               items: [Self.rabenschnabel]))
        XCTAssertEqual(s.facts["attr.KO"]?.value, .int(15))
        XCTAssertEqual(s.facts["attr.KO"]?.owner, .sheet)
        XCTAssertEqual(s.facts["ktw.CT_5"]?.value, .int(14))
        XCTAssertEqual(s.facts["hero.purchased.le"]?.value, .int(0))
        XCTAssertEqual(s.facts["species.le"]?.value, .int(5))
        XCTAssertEqual(s.facts["loadout.weapon"]?.value, .string("Rabenschnabel"))
        XCTAssertEqual(s.facts["loadout.weapon"]?.owner, .loadout)
        XCTAssertEqual(s.facts["item.Rabenschnabel.template"]?.value, .string("ITEMTPL_19"))
        XCTAssertNil(s.facts["item.Rabenschnabel.atMod"])
        XCTAssertEqual(s.base["gs"], 8)
        XCTAssertEqual(s.owned["SA_41"]?.level, 2)
    }

    func testAnItemWithoutARuleFileStatesItsOwnStats() {
        let axe = HeroSheet.Item(name: "Streitaxt", technique: "CT_5", atMod: 0, paMod: -1)
        let s = Situation(sheet: Self.boronmir(loadout: .init(weapon: "Streitaxt"), items: [axe]))
        XCTAssertEqual(s.facts["item.Streitaxt.technique"]?.value, .string("CT_5"))
        XCTAssertEqual(s.facts["item.Streitaxt.paMod"]?.value, .int(-1))
        XCTAssertNil(s.facts["item.Streitaxt.template"])
    }

    func testBoronmirsSheetValues() {
        let armed = Self.boronmir(loadout: .init(weapon: "Rabenschnabel"), items: [Self.rabenschnabel])
        XCTAssertEqual(result("leMax", armed), 37)
        XCTAssertEqual(result("at(with: Rabenschnabel)", armed), 16)
        XCTAssertEqual(result("pa(with: Rabenschnabel)", armed), 8)
        let shielded = Self.boronmir(loadout: .init(weapon: "Rabenschnabel", shield: "Großschild"),
                                     items: [Self.rabenschnabel, Self.grossschild])
        XCTAssertEqual(result("at(with: Rabenschnabel)", shielded), 15)
    }

    func testPlateGivesOneBelastungLineAfterBelastungsgewoehnung() {
        let plate = Self.boronmir(
            loadout: .init(weapon: "Rabenschnabel", armour: "Plattenrüstung", armourBelastung: 3),
            items: [Self.rabenschnabel])
        let b = Engine(book: Self.book).evaluate(Query("at(with: Rabenschnabel)"), in: Situation(sheet: plate))
        let belastung = b.lines.filter { $0.origin?.rule == "COND_1" }
        XCTAssertEqual(belastung.map(\.value), [-1])
    }
```

- [ ] **Step 2: Run** `swift test --package-path Packages/RulesEngine --filter HeroSheetTests` → compile error (`HeroSheet` missing).

- [ ] **Step 3: Create `HeroSheet.swift`:**

```swift
import Foundation

/// What the app knows about a hero that the sheet's values rest on (domain 1, the cut-over design
/// docs/plans/2026-09-27-sheet-cutover-design.md §2): plain values, no SwiftData. `Situation(sheet:)`
/// turns it into the facts scripts/rulec/hero.py writes for a hero file, plus the loadout.
/// No Zustände and no current LE until domain 4 (design §3).
public struct HeroSheet: Codable, Hashable, Sendable {
    /// A piece the hero owns. `name` is the name the rules know it by: the rule's own name when
    /// `template` names an equipment rule in the book (ITEMTPL_29.GR1 compares names), else the
    /// app's. Without a template, `technique`, `atMod` and `paMod` describe it.
    public struct Item: Codable, Hashable, Sendable {
        public var name: String
        public var template: String?
        public var technique: String?
        public var atMod: Int?
        public var paMod: Int?

        public init(name: String, template: String? = nil, technique: String? = nil,
                    atMod: Int? = nil, paMod: Int? = nil) {
            self.name = name; self.template = template; self.technique = technique
            self.atMod = atMod; self.paMod = paMod
        }
    }

    /// The slots, by item name. `shield` fills `loadout.other: shield` as well.
    public struct Loadout: Codable, Hashable, Sendable {
        public var weapon: String?
        public var shield: String?
        public var armour: String?
        public var armourBelastung: Int
        public var armourExtraPenalty: Int

        public init(weapon: String? = nil, shield: String? = nil, armour: String? = nil,
                    armourBelastung: Int = 0, armourExtraPenalty: Int = 0) {
            self.weapon = weapon; self.shield = shield; self.armour = armour
            self.armourBelastung = armourBelastung; self.armourExtraPenalty = armourExtraPenalty
        }
    }

    public var owned: [String: OwnedRule]
    /// `MU` … `KK` → value.
    public var attributes: [String: Int]
    /// `CT_n` → KtW.
    public var techniques: [String: Int]
    /// `TAL_n` → FW.
    public var talents: [String: Int]
    /// The LE bought with AP (lebensenergie.LE2).
    public var purchasedLE: Int
    /// The species' LE-Grundwert; nil when the app cannot say (the engine then asks).
    public var speciesLE: Int?
    /// The species' GS, the base of `gs`; nil when the app cannot say.
    public var speciesGS: Int?
    public var items: [Item]
    public var loadout: Loadout

    public init(owned: [String: OwnedRule], attributes: [String: Int], techniques: [String: Int],
                talents: [String: Int], purchasedLE: Int, speciesLE: Int?, speciesGS: Int?,
                items: [Item], loadout: Loadout) {
        self.owned = owned; self.attributes = attributes; self.techniques = techniques
        self.talents = talents; self.purchasedLE = purchasedLE; self.speciesLE = speciesLE
        self.speciesGS = speciesGS; self.items = items; self.loadout = loadout
    }

    /// This sheet with `slot` holding `item` (nil empties it): a weapon's own values on the sheet
    /// are the values with that weapon in hand.
    public func with(weapon: String?) -> HeroSheet { var s = self; s.loadout.weapon = weapon; return s }
    public func with(shield: String?) -> HeroSheet { var s = self; s.loadout.shield = shield; return s }
    public func with(armour: String?, belastung: Int, extraPenalty: Int) -> HeroSheet {
        var s = self
        s.loadout.armour = armour
        s.loadout.armourBelastung = belastung
        s.loadout.armourExtraPenalty = extraPenalty
        return s
    }
}

extension Situation {
    /// The situation the sheet states: the hero's facts (owner `sheet`), the loadout and the
    /// items' facts (owner `loadout`), and the species GS as the base of `gs`.
    public init(sheet: HeroSheet) {
        var facts: [Fact] = []
        func state(_ name: String, _ value: JSONValue, _ owner: Owner) {
            facts.append(Fact(name: name, value: value, owner: owner))
        }
        for (a, v) in sheet.attributes { state("attr.\(a)", .int(v), .sheet) }
        for (t, v) in sheet.techniques { state("ktw.\(t)", .int(v), .sheet) }
        for (t, v) in sheet.talents { state("fw.\(t)", .int(v), .sheet) }
        state("hero.purchased.le", .int(sheet.purchasedLE), .sheet)
        if let le = sheet.speciesLE { state("species.le", .int(le), .sheet) }

        let l = sheet.loadout
        if let w = l.weapon { state("loadout.weapon", .string(w), .loadout) }
        if let s = l.shield {
            state("loadout.shield", .string(s), .loadout)
            state("loadout.other", .string("shield"), .loadout)
        }
        if let a = l.armour {
            state("loadout.armour", .string(a), .loadout)
            state("loadout.armour.belastung", .int(l.armourBelastung), .loadout)
            state("loadout.armour.extraPenalty", .int(l.armourExtraPenalty), .loadout)
        }
        for item in sheet.items {
            if let t = item.template {
                state("item.\(item.name).template", .string(t), .loadout)
            } else {
                if let t = item.technique { state("item.\(item.name).technique", .string(t), .loadout) }
                if let v = item.atMod { state("item.\(item.name).atMod", .int(v), .loadout) }
                if let v = item.paMod { state("item.\(item.name).paMod", .int(v), .loadout) }
            }
        }
        var base: [String: Int] = [:]
        if let gs = sheet.speciesGS { base["gs"] = gs }
        self.init(owned: sheet.owned, facts: facts, base: base)
    }
}
```

- [ ] **Step 4: Run** the filter again. If `pa(with: Rabenschnabel)` is not 8, print the breakdown (`dump(b.lines)`) and compare with `kampfwerte.yaml` 16.1–16.4 before changing anything: the expected numbers come from the rule files, not from this plan. If a number in the plan disagrees with a passing situation of `kampfwerte.yaml`, the situation wins; fix the test's number and say so in the commit message.

- [ ] **Step 5: Run the whole package suite** `make test-rules-engine` → all pass, harness line unchanged.

- [ ] **Step 6: Commit.**

```bash
git add Packages/RulesEngine
git commit -m "feat(rules-engine): HeroSheet, the app's plain hero inputs, and Situation(sheet:)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

```json:metadata
{"files": ["Packages/RulesEngine/Sources/RulesEngine/HeroSheet.swift", "Packages/RulesEngine/Tests/RulesEngineTests/HeroSheetTests.swift"], "verifyCommand": "swift test --package-path Packages/RulesEngine --filter HeroSheetTests", "acceptanceCriteria": ["HeroSheet is public Codable, Hashable, Sendable with owned, attributes, techniques, talents, purchasedLE, speciesLE, speciesGS, items, loadout", "Situation(sheet:) states facts with owner sheet or loadout and base[gs] from speciesGS", "template items state only item.<name>.template; others state technique/atMod/paMod", "Boronmir: leMax 37, at(with: Rabenschnabel) 16, pa 8, at with Großschild 15", "Plattenrüstung + SA_41 II: exactly one COND_1 line of -1 on at"], "modelTier": "standard"}
```

---

### Task 3: Bundle the rule book and link the package

**Goal:** The app links `RulesEngine`, bundles `rules.json` and `checks.json` as build products, and `RulesEngineStore` loads them once.

**Files:**
- Modify: `Makefile` (targets `rules-json`, `require-rules-db` neighbours, `build`, `build-iphone`, `deploy`, `deploy-kombucha`, `test`, `test-ui`, `test-ui-record`, `test-ui-record-only`, `.PHONY`)
- Modify: `.gitignore`
- Modify: `Hesindion.xcodeproj/project.pbxproj`
- Create: `Hesindion/RulesEngine/RulesEngineStore.swift`
- Test: `HesindionTests/RulesEngineStoreTests.swift`

**Acceptance Criteria:**
- [ ] `make rules-json` copies `build/rules/rules.json` and `build/rules/checks.json` into `Hesindion/Resources/`; both are gitignored
- [ ] `require-rules-json` fails with `rules.json missing: run make rules-json` when either file is missing; every target that ships the app depends on it; `test`, `test-ui`, `test-ui-record`, `test-ui-record-only` depend on `rules-json`
- [ ] The Xcode project has an `XCLocalSwiftPackageReference` to `Packages/RulesEngine` and the `Hesindion` target links the `RulesEngine` product
- [ ] `RulesEngineStore.shared.engine` loads from the bundle; its book's `vocabularyVersion == Vocabulary.version`; `checks.hinderedByBelastung["TAL_5"] == .bool(true)`

**Verify:** `make test` (runs `RulesEngineStoreTests` with the rest) → `** TEST SUCCEEDED **`

**Steps:**

- [ ] **Step 1: Makefile.** Add `RULES_JSON = Hesindion/Resources/rules.json` and `CHECKS_JSON = Hesindion/Resources/checks.json` next to `RULES_DB`. Extend `rules-json`:

```make
rules-json:
	$(RULEC) build --out ../build/rules
	cp build/rules/rules.json $(RULES_JSON)
	cp build/rules/checks.json $(CHECKS_JSON)
```

Add, after `require-rules-db`:

```make
# rules.json and checks.json are build products too (the rules engine's book and the Probe table,
# docs/plans/2026-09-27-sheet-cutover-design.md §2): gitignored, copied in by make rules-json.
require-rules-json:
	@if [ ! -f '$(RULES_JSON)' ] || [ ! -f '$(CHECKS_JSON)' ]; then \
		echo "rules.json missing: run make rules-json"; \
		exit 1; \
	fi
```

Change `build: require-rules-db` to `build: require-rules-db require-rules-json`, and the same for `build-iphone`, `deploy`, `deploy-kombucha`. Change `test: rules-db boot` to `test: rules-db rules-json boot`, and the same for `test-ui`, `test-ui-record`, `test-ui-record-only`. Add `require-rules-json` to `.PHONY`.

- [ ] **Step 2: `.gitignore`.** Add `Hesindion/Resources/rules.json` and `Hesindion/Resources/checks.json` under the `rules.db` line.

- [ ] **Step 3: Link the local package.** In `project.pbxproj`, mirror how `MarkdownUI` is wired (lines ~10, ~73, ~136, ~221, ~622–644), with new unique 24-hex ids:
  - a `PBXBuildFile` `/* RulesEngine in Frameworks */` with `productRef` to the new product dependency;
  - that build file in the `Hesindion` target's `PBXFrameworksBuildPhase` `files`;
  - the product dependency in the `Hesindion` target's `packageProductDependencies`;
  - in the `PBXProject`'s `packageReferences`, the new `XCLocalSwiftPackageReference "Packages/RulesEngine"`;
  - a new section:

```
/* Begin XCLocalSwiftPackageReference section */
		<ID_REF> /* XCLocalSwiftPackageReference "Packages/RulesEngine" */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = Packages/RulesEngine;
		};
/* End XCLocalSwiftPackageReference section */
```

  - in `XCSwiftPackageProductDependency`:

```
		<ID_PROD> /* RulesEngine */ = {
			isa = XCSwiftPackageProductDependency;
			productName = RulesEngine;
		};
```

  Then run `xcodebuild -project Hesindion.xcodeproj -list` (must parse) and `make build` (must link).

- [ ] **Step 4: Write the failing test** `HesindionTests/RulesEngineStoreTests.swift`:

```swift
import XCTest
import RulesEngine
@testable import Hesindion

final class RulesEngineStoreTests: XCTestCase {
    func testTheBundledBookLoadsWithTheAppsVocabulary() throws {
        let store = try XCTUnwrap(RulesEngineStore.shared)
        XCTAssertEqual(store.engine.book.vocabularyVersion, Vocabulary.version)
    }

    func testTheBundledCheckTableIsTheBuiltOne() throws {
        let store = try XCTUnwrap(RulesEngineStore.shared)
        XCTAssertEqual(store.checks.hinderedByBelastung["TAL_5"], .bool(true))
    }
}
```

- [ ] **Step 5: Create `Hesindion/RulesEngine/RulesEngineStore.swift`:**

```swift
import Foundation
import RulesEngine

/// The rules engine and its book, loaded once from the bundle (`rules.json`, `checks.json`, both
/// copied in by `make rules-json`). nil when either is missing or was built for another
/// vocabulary: the screens then show `L("rulesEngine.unavailable")` instead of a number, and
/// `RulesEngineStoreTests` fails before a release.
final class RulesEngineStore: Sendable {
    let engine: Engine
    let checks: CheckTable

    static let shared: RulesEngineStore? = {
        guard let rules = Bundle.main.url(forResource: "rules", withExtension: "json"),
              let checks = Bundle.main.url(forResource: "checks", withExtension: "json"),
              let book = try? RuleBook.load(from: rules),
              let data = try? Data(contentsOf: checks),
              let table = try? CheckTable.decode(data) else { return nil }
        return RulesEngineStore(engine: Engine(book: book), checks: table)
    }()

    init(engine: Engine, checks: CheckTable) {
        self.engine = engine
        self.checks = checks
    }
}
```

Add `"rulesEngine.unavailable"` to `Strings.swift`: English `"Rules not loaded"`, German `"Regeln nicht geladen"`.

- [ ] **Step 6: Run** `make test` → the two new tests pass, nothing else changes.

- [ ] **Step 7: Commit.**

```bash
git add Makefile .gitignore Hesindion.xcodeproj/project.pbxproj Hesindion/RulesEngine Hesindion/Theme/Strings.swift HesindionTests/RulesEngineStoreTests.swift
git commit -m "build: the app links RulesEngine and bundles rules.json and checks.json

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

```json:metadata
{"files": ["Makefile", ".gitignore", "Hesindion.xcodeproj/project.pbxproj", "Hesindion/RulesEngine/RulesEngineStore.swift", "Hesindion/Theme/Strings.swift", "HesindionTests/RulesEngineStoreTests.swift"], "verifyCommand": "make test", "acceptanceCriteria": ["make rules-json copies rules.json and checks.json into Hesindion/Resources; both gitignored", "require-rules-json guards every shipping target; test targets depend on rules-json", "project links RulesEngine via XCLocalSwiftPackageReference", "RulesEngineStore loads with vocabularyVersion == Vocabulary.version and TAL_5 flag true"], "modelTier": "standard"}
```

---

### Task 4: SchemaV5 — the new stored inputs and their back-fill

**Goal:** The inputs the engine needs and the store lacks (`MeleeWeapon.atModifier/paModifier`, `Shield.atModifier`, `DerivedValues.speciesLE`) exist, the import writes them, and a launch pass fills them for existing heroes from the old folded values.

**Files:**
- Create: `Hesindion/Migration/SchemaV5.swift`
- Modify: `Hesindion/Migration/MigrationPlan.swift`
- Modify: `Hesindion/Models/MeleeWeapon.swift`, `Hesindion/Models/Shield.swift`, `Hesindion/Models/DerivedValues.swift`
- Modify: `Hesindion/Services/OptolithImportService.swift` (`computeDerivedValues` ~:870–960; weapons ~:662–688; shields ~:628–660)
- Create: `Hesindion/RulesEngine/SheetInputBackfill.swift`
- Modify: `Hesindion/ContentView.swift:20` (call the back-fill next to `DerivedValueRepair.repairAll`)
- Test: `HesindionTests/SheetInputBackfillTests.swift`

**Acceptance Criteria:**
- [ ] New properties with defaults: `MeleeWeapon.atModifier: Int? = nil`, `.paModifier: Int? = nil`; `Shield.atModifier: Int? = nil`; `DerivedValues.speciesLE: Int? = nil`. nil means "not known yet".
- [ ] `SchemaV5` lists the same models; `migrateV4toV5` is lightweight
- [ ] A fresh import sets them from the Optolith item (`item.at`, `item.pa`; shield AT-Mod) and the species base LP
- [ ] `SheetInputBackfill.fill(_ hero:)` sets, for each nil: `weapon.atModifier = weapon.at − ct.at`, `weapon.paModifier = weapon.pa − ct.pa`, `shield.atModifier = shield.at − shieldCT.at`, `speciesLE = lebensenergie.base − 2·KO`; it is idempotent (second call returns `false`) and writes nothing it cannot derive (a weapon whose technique the hero lacks stays nil)
- [ ] Boronmir's import (`specs/heroes/Boronmir Siebenfeld von Greifenfurt.json`): Rabenschnabel atModifier 0, paModifier −1; Großschild atModifier −6; speciesLE 5

**Verify:** `make test` → `** TEST SUCCEEDED **`, including `SheetInputBackfillTests`

**Steps:**

- [ ] **Step 1: Write the failing tests** `HesindionTests/SheetInputBackfillTests.swift`. Build the store and import the way `HesindionTests/SampleHeroImportTests.swift` does (reuse its helper for an in-memory container and for importing a file from `specs/heroes`):

```swift
import XCTest
import SwiftData
@testable import Hesindion

final class SheetInputBackfillTests: XCTestCase {
    func testTheImportWritesTheNewInputs() throws {
        let hero = try SampleHeroes.importHero(named: "Boronmir Siebenfeld von Greifenfurt")
        let raben = try XCTUnwrap(hero.meleeWeapons.first { $0.templateId == "ITEMTPL_19" })
        XCTAssertEqual(raben.atModifier, 0)
        XCTAssertEqual(raben.paModifier, -1)
        let schild = try XCTUnwrap(hero.shields.first { $0.templateId == "ITEMTPL_29" })
        XCTAssertEqual(schild.atModifier, -6)
        XCTAssertEqual(hero.derivedValues?.speciesLE, 5)
    }

    func testTheBackfillDerivesThemFromTheFoldedValues() throws {
        let hero = try SampleHeroes.importHero(named: "Boronmir Siebenfeld von Greifenfurt")
        for w in hero.meleeWeapons { w.atModifier = nil; w.paModifier = nil }
        for s in hero.shields { s.atModifier = nil }
        hero.derivedValues?.speciesLE = nil

        XCTAssertTrue(SheetInputBackfill.fill(hero))
        let raben = try XCTUnwrap(hero.meleeWeapons.first { $0.templateId == "ITEMTPL_19" })
        XCTAssertEqual(raben.atModifier, 0)
        XCTAssertEqual(raben.paModifier, -1)
        XCTAssertEqual(hero.shields.first { $0.templateId == "ITEMTPL_29" }?.atModifier, -6)
        XCTAssertEqual(hero.derivedValues?.speciesLE, 5)
        XCTAssertFalse(SheetInputBackfill.fill(hero), "idempotent")
    }
}
```

If `SampleHeroImportTests` has no reusable helper, extract its import code into `HesindionTests/SampleHeroes.swift` as `enum SampleHeroes { static func importHero(named: String) throws -> Hero }` in this step, and make `SampleHeroImportTests` call it.

- [ ] **Step 2: Run** `make test` → compile errors (properties missing).

- [ ] **Step 3: Add the properties.** In each model, next to the fields they unfold:

```swift
    /// The item's AT-Mod, unfolded (sheet cut-over, SchemaV5). nil until the import or
    /// `SheetInputBackfill` sets it. The engine reads this, not `at`.
    var atModifier: Int? = nil
```

(and `paModifier` on `MeleeWeapon`; `speciesLE: Int? = nil` on `DerivedValues` with a comment "the species' LE-Grundwert; nil until the import or the back-fill sets it").

- [ ] **Step 4: SchemaV5.** Copy `SchemaV4.swift` to `SchemaV5.swift`, rename the enum to `SchemaV5`, `Schema.Version(5, 0, 0)`. In `MigrationPlan.swift` add `SchemaV5.self` to `schemas`, `migrateV4toV5` to `stages`:

```swift
    static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: SchemaV4.self,
        toVersion: SchemaV5.self
    )
```

Also change the container's schema to `SchemaV5` wherever `SchemaV4` is named as current (`grep -rn "SchemaV4" Hesindion`).

- [ ] **Step 5: The import.** In `OptolithImportService`, where a `MeleeWeapon` is built with `at: baseAT + item.at`, also set `atModifier: item.at`, `paModifier: item.pa` (use the same values the fold adds). For shields, set `atModifier` to the AT-Mod the fold adds. In `computeDerivedValues`, set `speciesLE` to the species base LP it already computes. Keep the folded values as they are (Task 11 removes them).

- [ ] **Step 6: The back-fill** `Hesindion/RulesEngine/SheetInputBackfill.swift`:

```swift
import Foundation
import SwiftData

/// Fills the inputs SchemaV5 added (`atModifier`, `paModifier`, `speciesLE`) for heroes imported
/// before them, from the folded values the import stored: a weapon's AT/PA minus its technique's,
/// a shield's AT minus the Schilde technique's, LE base minus twice KO. Writes nothing it cannot
/// derive. Runs at launch until SchemaV6 drops the folded values (sheet cut-over plan, Task 11).
enum SheetInputBackfill {
    /// - Returns: `true` if anything changed. Idempotent.
    @discardableResult
    static func fill(_ hero: Hero) -> Bool {
        var changed = false
        let techniques = Dictionary(hero.combatTechniques.map { ($0.ruleId, $0) },
                                    uniquingKeysWith: { a, _ in a })
        for w in hero.meleeWeapons {
            guard let ct = techniques[w.combatTechniqueId] else { continue }
            if w.atModifier == nil { w.atModifier = w.at - ct.at; changed = true }
            if w.paModifier == nil { w.paModifier = w.pa - ct.pa; changed = true }
        }
        if let ct = techniques["CT_10"] {
            for s in hero.shields where s.atModifier == nil {
                s.atModifier = s.at - ct.at
                changed = true
            }
        }
        if let dv = hero.derivedValues, dv.speciesLE == nil, let ko = hero.attributes?.ko {
            dv.speciesLE = dv.lebensenergie.base - 2 * ko
            changed = true
        }
        return changed
    }

    static func fillAll(in context: ModelContext) {
        let heroes = (try? context.fetch(FetchDescriptor<Hero>())) ?? []
        if heroes.map(fill).contains(true) { try? context.save() }
    }
}
```

Check the property names against the models before compiling (`combatTechniques`, `meleeWeapons`, `shields`, `ruleId`, `combatTechniqueId` — the Explore map names `CombatTechnique.ruleId` and `MeleeWeapon.combatTechniqueId`; adjust to the real names if they differ). Call `SheetInputBackfill.fillAll(in: modelContext)` in `ContentView.swift` right after `DerivedValueRepair.repairAll(in: modelContext)`.

- [ ] **Step 7: Run** `make test` → PASS.

- [ ] **Step 8: Commit.**

```bash
git add Hesindion HesindionTests
git commit -m "feat(model): SchemaV5 stores the unfolded AT/PA-Mods and the species LE, back-filled at launch

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

```json:metadata
{"files": ["Hesindion/Migration/SchemaV5.swift", "Hesindion/Migration/MigrationPlan.swift", "Hesindion/Models/MeleeWeapon.swift", "Hesindion/Models/Shield.swift", "Hesindion/Models/DerivedValues.swift", "Hesindion/Services/OptolithImportService.swift", "Hesindion/RulesEngine/SheetInputBackfill.swift", "Hesindion/ContentView.swift", "HesindionTests/SheetInputBackfillTests.swift"], "verifyCommand": "make test", "acceptanceCriteria": ["MeleeWeapon.atModifier/paModifier, Shield.atModifier, DerivedValues.speciesLE exist as optional with nil default", "SchemaV5 with lightweight migrateV4toV5", "import sets the new inputs", "SheetInputBackfill.fill derives them from folded values, idempotent, writes nothing underivable", "Boronmir: Rabenschnabel 0/-1, Großschild atModifier -6, speciesLE 5"], "modelTier": "standard"}
```

---

### Task 5: `HeroSheetMapping`, `SheetValues` and the parity fixtures

**Goal:** The app turns a `Hero` into a `HeroSheet`, `SheetValues` computes every base value from it once per distinct sheet, and three guards hold: the mapping equals `hero.py`, the engine's Belastung equals `SharedModifiers.encumbrance`, and the engine's values equal the old stored ones except the named intended differences.

**Files:**
- Modify: `Makefile` (new target `hero-sheet-fixtures`)
- Create: `HesindionTests/Fixtures/HeroSheets/*.json` (generated, committed)
- Create: `Hesindion/RulesEngine/HeroSheetMapping.swift`
- Create: `Hesindion/RulesEngine/SheetValues.swift`
- Test: `HesindionTests/HeroSheetMappingTests.swift`, `HesindionTests/SheetValuesTests.swift`

**Acceptance Criteria:**
- [ ] `make hero-sheet-fixtures` writes one JSON per `specs/heroes/*.json` (not `*.companions.yaml`) with `hero.py`'s `owned` and `facts`
- [ ] For each of the four sample heroes, `Situation(sheet: HeroSheetMapping.sheet(for: hero))`'s `attr.*`, `ktw.*`, `fw.*`, `hero.purchased.le` facts and the owned rule ids with levels equal the fixture (options are not compared: `HeroTrait.sid` is a display name)
- [ ] `SheetValues` exposes `leMax`, `wundschwelle`, `iniBase`, `aw`, `gs`, `technique(_:)`, `weapon(_:)`, `shield(_:)` as `SheetValue` (a `Breakdown` plus `result` and `withoutBelastung`); it evaluates once per distinct `HeroSheet`
- [ ] Belastung guard: for each sample hero with its armour equipped and with none, the sum of the `COND_1` lines of `at(with: <selected weapon>)` equals `SharedModifiers.encumbrance`'s line value for `.meleeAttack` (0 when none)
- [ ] Old-vs-new: for each sample hero, `leMax`, `wundschwelle`, `iniBase`, `aw` and each technique's and weapon's AT/PA `withoutBelastung` equal the stored values, except the differences listed by name in the test (Kampfreflexe on INI, Niedrige Lebenskraft on LE, Großschild −1 on the main weapon's AT and on GS)

**Verify:** `make test` → `** TEST SUCCEEDED **`

**Steps:**

- [ ] **Step 1: The fixture target.** Add to the Makefile:

```make
# hero.py's view of every sample hero, for HeroSheetMappingTests (the app's mapping must state the
# same facts). Rerun after a change to specs/heroes or scripts/rulec/hero.py, and commit the JSON.
HERO_SHEET_FIXTURES = HesindionTests/Fixtures/HeroSheets
hero-sheet-fixtures:
	mkdir -p $(HERO_SHEET_FIXTURES)
	cd scripts && uv run --with pyyaml python -c "import json, sys, pathlib; \
from rulec.hero import from_optolith; \
[pathlib.Path('../$(HERO_SHEET_FIXTURES)', p.stem + '.json').write_text(json.dumps(from_optolith(p), ensure_ascii=False, indent=1, sort_keys=True) + '\n', encoding='utf-8') \
 for p in sorted(pathlib.Path('../specs/heroes').glob('*.json'))]"
```

Add it to `.PHONY`, run it, and check that four files appear. Make the folder part of the test bundle: it is inside `HesindionTests/`, which is a synchronized group, so the JSON files are bundle resources.

- [ ] **Step 2: Write the failing mapping test** `HesindionTests/HeroSheetMappingTests.swift`:

```swift
import XCTest
import RulesEngine
@testable import Hesindion

@MainActor
final class HeroSheetMappingTests: XCTestCase {
    struct PyHero: Decodable {
        struct PyOwned: Decodable { var level: Int }
        struct PyFact: Decodable { var name: String; var value: JSONValue }
        var owned: [String: PyOwned]
        var facts: [PyFact]
    }

    static let heroes = ["Boronmir Siebenfeld von Greifenfurt", "Robak Arkanjeff",
                         "Ingra Tochter der Ilpetta", "Lyssandra Silberhaar"]

    func testTheMappingStatesWhatHeroPyStates() throws {
        for name in Self.heroes {
            let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"),
                                    "run make hero-sheet-fixtures")
            let py = try JSONDecoder().decode(PyHero.self, from: Data(contentsOf: url))
            let hero = try SampleHeroes.importHero(named: name)
            let s = RulesEngine.Situation(sheet: HeroSheetMapping.sheet(for: hero))

            XCTAssertEqual(s.owned.mapValues(\.level), py.owned.mapValues(\.level), name)
            let prefixes = ["attr.", "ktw.", "fw.", "hero.purchased.le"]
            let ours = s.facts.values.filter { f in prefixes.contains { f.name.hasPrefix($0) } }
            XCTAssertEqual(Dictionary(uniqueKeysWithValues: ours.map { ($0.name, $0.value) }),
                           Dictionary(uniqueKeysWithValues: py.facts.map { ($0.name, $0.value) }), name)
        }
    }
}
```

If a hero's `owned` differs only by a rule the app does not import as a `HeroTrait` (for example a cantrip or a blessing id outside the six trait arrays), add that array to the mapping rather than excluding the id from the test.

- [ ] **Step 3: Create `HeroSheetMapping.swift`:**

```swift
import Foundation
import RulesEngine

/// `Hero` → `HeroSheet` (sheet cut-over design §2): the only code that knows both models. Reads
/// unfolded inputs only — attributes, KtW, template ids, the SchemaV5 modifiers — never a stored
/// AT/PA. An item whose template has an equipment rule in the book enters under the rule's name.
enum HeroSheetMapping {
    static func sheet(for hero: Hero, book: RuleBook? = RulesEngineStore.shared?.engine.book) -> HeroSheet {
        var owned: [String: OwnedRule] = [:]
        let traits = hero.advantages + hero.disadvantages + hero.generalSpecialAbilities
            + hero.combatSpecialAbilities + hero.cantrips + hero.blessings
        for t in traits where owned[t.ruleId] == nil { owned[t.ruleId] = OwnedRule(level: t.tier ?? 1) }

        var attributes: [String: Int] = [:]
        if let a = hero.attributes {
            attributes = ["MU": a.mu, "KL": a.kl, "IN": a.inValue, "CH": a.ch,
                          "FF": a.ff, "GE": a.ge, "KO": a.ko, "KK": a.kk]
        }
        let techniques = Dictionary(hero.combatTechniques.map { ($0.ruleId, $0.value) },
                                    uniquingKeysWith: { a, _ in a })
        let talents = Dictionary(hero.talents.map { ($0.ruleId, $0.value) },
                                 uniquingKeysWith: { a, _ in a })

        func engineName(_ appName: String, template: String?) -> String {
            Self.engineName(appName, template: template, book: book)
        }
        /// An item with an equipment rule in the book: the rule's name and template only (the rule
        /// provides its stats). Any other: the app's name and its own stats.
        func item(_ appName: String, template: String?, technique: String, at: Int?, pa: Int?) -> HeroSheet.Item {
            if let t = template, let rule = book?.rules[t], rule.kind == .equipment {
                return HeroSheet.Item(name: rule.name, template: t)
            }
            return HeroSheet.Item(name: appName, technique: technique, atMod: at, paMod: pa)
        }
        let weapons = hero.meleeWeapons.map {
            item($0.name, template: $0.templateId, technique: $0.combatTechniqueId,
                 at: $0.atModifier, pa: $0.paModifier)
        }
        let shields = hero.shields.map {
            item($0.name, template: $0.templateId, technique: "CT_10", at: $0.atModifier, pa: $0.paModifier)
        }

        let worn = hero.armors.filter(\.isEquipped)
        let selectedWeapon = hero.meleeWeapons.first { $0.name == hero.selectedWeaponName }
        let selectedShield = hero.shields.first { $0.name == hero.selectedShieldName }
        let loadout = HeroSheet.Loadout(
            weapon: selectedWeapon.map { engineName($0.name, template: $0.templateId) },
            shield: selectedShield.map { engineName($0.name, template: $0.templateId) },
            armour: worn.first?.name,
            armourBelastung: worn.reduce(0) { $0 + $1.encumbrance },
            armourExtraPenalty: worn.reduce(0) { $0 + $1.iniModifier })

        let dv = hero.derivedValues
        return HeroSheet(
            owned: owned, attributes: attributes, techniques: techniques, talents: talents,
            purchasedLE: dv?.lebensenergie.purchased ?? 0,
            speciesLE: dv?.speciesLE,
            speciesGS: dv.map { $0.geschwindigkeit.base },
            items: weapons + shields, loadout: loadout)
    }

    /// The name the rules know an item by: its equipment rule's name when the book has one for
    /// its template, else the app's.
    static func engineName(_ appName: String, template: String?, book: RuleBook?) -> String {
        guard let t = template, let rule = book?.rules[t], rule.kind == .equipment else { return appName }
        return rule.name
    }
}
```

Adjust property names to the real models (`hero.talents`, `Talent.ruleId`, `Talent.value`, `Shield.paModifier`, `hero.selectedShieldName`) — read `Hesindion/Models/Hero.swift:8-13,109-112` first. `Armor.iniModifier` is the extra penalty; if a sample hero's armour has `gsModifier != iniModifier`, list it as an intended difference in Step 6 rather than inventing a second fact (the engine has one `extraPenalty` for GS and INI).

- [ ] **Step 4: Write the failing `SheetValuesTests`:**

```swift
import XCTest
import RulesEngine
@testable import Hesindion

@MainActor
final class SheetValuesTests: XCTestCase {
    func testBoronmirsValuesComeFromTheEngine() throws {
        let hero = try SampleHeroes.importHero(named: "Boronmir Siebenfeld von Greifenfurt")
        let v = try XCTUnwrap(SheetValues.of(hero))
        XCTAssertEqual(v.leMax.result, 37)
        XCTAssertTrue(v.leMax.breakdown.lines.contains { $0.origin?.rule == "ADV_25" })
    }

    func testAnUnchangedSheetIsNotEvaluatedAgain() throws {
        let hero = try SampleHeroes.importHero(named: "Boronmir Siebenfeld von Greifenfurt")
        let a = try XCTUnwrap(SheetValues.of(hero))
        let b = try XCTUnwrap(SheetValues.of(hero))
        XCTAssertTrue(a === b)
        hero.attributes?.ko += 1
        let c = try XCTUnwrap(SheetValues.of(hero))
        XCTAssertFalse(a === c)
        XCTAssertEqual(c.leMax.result, 39)
    }

    /// The heaviest armour the hero owns, worn alone, and then no armour: the engine's COND_1
    /// lines on the main weapon's AT sum to Swift's Belastung line (design §4, until domain 2).
    func testTheEnginesBelastungIsTheSwiftOne() throws {
        for name in HeroSheetMappingTests.heroes {
            let hero = try SampleHeroes.importHero(named: name)
            guard let w = hero.meleeWeapons.first else { continue }
            hero.selectedWeaponName = w.name
            let heaviest = hero.armors.max { $0.encumbrance < $1.encumbrance }
            for wearing in [true, false] {
                for a in hero.armors { a.isEquipped = wearing && a === heaviest }
                let engine = try XCTUnwrap(SheetValues.of(hero)).weapon(w).at.breakdown.lines
                    .filter { $0.origin?.rule == "COND_1" }.reduce(0) { $0 + $1.value }
                let s = Hesindion.Situation(hero: hero, domain: .meleeAttack)
                let swift = SharedModifiers.encumbrance.evaluate(s)?.value ?? 0
                XCTAssertEqual(engine, swift, "\(name), armour \(wearing)")
            }
        }
    }
}
```

Read `ModifierDefinition` in `Hesindion/Engine/ModifierEngine.swift` for the real call that evaluates one definition on a situation, and use it where the test says `.evaluate(s)`. The app's own `Situation` type is `Hesindion.Situation`; the engine's is `RulesEngine.Situation` — qualify both wherever a file imports `RulesEngine`.

- [ ] **Step 5: Create `SheetValues.swift`:**

```swift
import Foundation
import RulesEngine

/// One base value: the engine's breakdown, its result, and the result without the Belastung lines
/// (`COND_1`), which is what a roll screen starts from until domain 2 moves Belastung to the engine
/// (sheet cut-over design §4).
struct SheetValue {
    let breakdown: Breakdown
    var result: Int? { breakdown.result }
    var withoutBelastung: Int? {
        result.map { r in r - breakdown.lines.filter { $0.origin?.rule == "COND_1" }.reduce(0) { $0 + $1.value } }
    }
}

/// Every base value of one hero, from one `HeroSheet` (design §2, §3). `of(_:)` returns the same
/// instance while the hero's sheet is unchanged, so a redraw does not run the engine.
final class SheetValues {
    let sheet: HeroSheet
    private let engine: Engine
    private var memo: [String: SheetValue] = [:]

    private init(sheet: HeroSheet, engine: Engine) {
        self.sheet = sheet
        self.engine = engine
    }

    @MainActor private static var cache: [PersistentIdentifierKey: SheetValues] = [:]

    /// nil when the rules are not loaded (`RulesEngineStore.shared` is nil).
    @MainActor static func of(_ hero: Hero) -> SheetValues? {
        guard let store = RulesEngineStore.shared else { return nil }
        let sheet = HeroSheetMapping.sheet(for: hero, book: store.engine.book)
        let key = PersistentIdentifierKey(hero)
        if let hit = cache[key], hit.sheet == sheet { return hit }
        let values = SheetValues(sheet: sheet, engine: store.engine)
        cache[key] = values
        return values
    }

    private func value(_ query: String, in sheet: HeroSheet? = nil) -> SheetValue {
        let s = sheet ?? self.sheet
        let key = "\(query)|\(s.hashValue)"
        if let hit = memo[key] { return hit }
        let v = SheetValue(breakdown: engine.evaluate(Query(query), in: RulesEngine.Situation(sheet: s)))
        memo[key] = v
        return v
    }

    var leMax: SheetValue { value("leMax") }
    var wundschwelle: SheetValue { value("wundschwelle") }
    var iniBase: SheetValue { value("iniBase") }
    var aw: SheetValue { value("aw") }
    var gs: SheetValue { value("gs") }

    struct Pair { let at: SheetValue; let pa: SheetValue }

    /// A technique with no item (`at(with: CT_5)`).
    func technique(_ ruleId: String) -> Pair {
        Pair(at: value("at(with: \(ruleId))"), pa: value("pa(with: \(ruleId))"))
    }

    /// A weapon's values with that weapon in hand and the current shield.
    func weapon(_ w: MeleeWeapon) -> Pair {
        let name = HeroSheetMapping.engineName(w.name, template: w.templateId, book: engine.book)
        let s = sheet.with(weapon: name)
        return Pair(at: value("at(with: \(name))", in: s), pa: value("pa(with: \(name))", in: s))
    }

    /// A shield's own AT and its shield parry, with that shield carried.
    func shield(_ sh: Shield) -> Pair {
        let name = HeroSheetMapping.engineName(sh.name, template: sh.templateId, book: engine.book)
        let s = sheet.with(shield: name)
        return Pair(at: value("at(with: \(name))", in: s), pa: value("pa(with: \(name))", in: s))
    }
}

/// A `Hero`'s identity as a dictionary key.
struct PersistentIdentifierKey: Hashable {
    let id: ObjectIdentifier
    init(_ hero: Hero) { id = ObjectIdentifier(hero) }
}
```

- [ ] **Step 6: The old-vs-new test.** Add to `SheetValuesTests`:

```swift
    /// The engine's values against what the import stored, per sample hero. Every difference is
    /// intended and named (sheet cut-over design §4); anything else fails.
    func testTheEngineAgreesWithTheStoredValuesExceptTheNamedDifferences() throws {
        let intended: [String: Set<String>] = [
            // hero name → the value keys that differ on purpose, each with its reason in a comment
            "Boronmir Siebenfeld von Greifenfurt": [],
            "Robak Arkanjeff": [],
            "Ingra Tochter der Ilpetta": [],
            "Lyssandra Silberhaar": [],
        ]
        for name in HeroSheetMappingTests.heroes {
            let hero = try SampleHeroes.importHero(named: name)
            let v = try XCTUnwrap(SheetValues.of(hero))
            let dv = try XCTUnwrap(hero.derivedValues)
            var got: [String: (engine: Int?, stored: Int)] = [
                "leMax": (v.leMax.result, dv.lebensenergie.max),
                "wundschwelle": (v.wundschwelle.result, dv.wundschwelle.max),
                "iniBase": (v.iniBase.withoutBelastung, dv.initiative.max),
                "aw": (v.aw.withoutBelastung, dv.ausweichen.max),
            ]
            for ct in hero.combatTechniques {
                got["at(\(ct.ruleId))"] = (v.technique(ct.ruleId).at.withoutBelastung, ct.at)
                if ct.pa > 0 { got["pa(\(ct.ruleId))"] = (v.technique(ct.ruleId).pa.withoutBelastung, ct.pa) }
            }
            for w in hero.meleeWeapons {
                got["at(\(w.name))"] = (v.weapon(w).at.withoutBelastung, w.at)
                got["pa(\(w.name))"] = (v.weapon(w).pa.withoutBelastung, w.pa + (hero.passiveShieldPABonus ?? 0))
            }
            let differing = Set(got.filter { $0.value.engine != $0.value.stored }.keys)
            XCTAssertEqual(differing, intended[name] ?? [], "\(name): \(got.filter { differing.contains($0.key) })")
        }
    }
```

Run it once. It prints each difference with both numbers. For each one, find its cause in the breakdown. Fill `intended` only with differences caused by `SA_51` (Kampfreflexe), `DISADV_28` (Niedrige Lebenskraft), `ITEMTPL_29.GR1` (Großschild on the main weapon's AT), or an armour's `gsModifier != iniModifier`, with a one-line comment each. **Any other difference is a bug in the mapping or in this plan's assumptions: stop and report it to the coordinator** with the breakdown, instead of adding it to `intended`.

- [ ] **Step 7: Run** `make test` → PASS.

- [ ] **Step 8: Commit.**

```bash
git add Makefile HesindionTests Hesindion/RulesEngine
git commit -m "feat(sheet): HeroSheetMapping and SheetValues, held to hero.py, the Swift Belastung and the stored values

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

```json:metadata
{"files": ["Makefile", "HesindionTests/Fixtures/HeroSheets", "Hesindion/RulesEngine/HeroSheetMapping.swift", "Hesindion/RulesEngine/SheetValues.swift", "HesindionTests/HeroSheetMappingTests.swift", "HesindionTests/SheetValuesTests.swift"], "verifyCommand": "make test", "acceptanceCriteria": ["make hero-sheet-fixtures writes one JSON per sample hero", "mapping facts and owned levels equal hero.py for all four sample heroes", "SheetValues exposes leMax, wundschwelle, iniBase, aw, gs, technique, weapon, shield; one evaluation per distinct HeroSheet", "engine COND_1 sum equals SharedModifiers.encumbrance with and without armour", "engine equals stored values except named SA_51, DISADV_28, ITEMTPL_29.GR1, armour gs/ini differences"], "modelTier": "frontier"}
```

---

### Task 6: The breakdown sheet and the hero sheet

**Goal:** `HeroDetailView` shows every base value from `SheetValues`, a tap opens `BreakdownSheet` with the lines, facts and owners, *Auslegung* marks and the not-applied list, and the "(−BE)" suffixes are gone.

**Files:**
- Create: `Hesindion/Views/BreakdownSheet.swift`
- Modify: `Hesindion/Views/HeroDetailView.swift` (LE :443–461, AW/INI/GS/WS :542–550, techniques :851–860, weapons :970–971, shields :1014–1015)
- Modify: `Hesindion/Theme/Strings.swift`
- Test: `HesindionUITests/SheetBreakdownTests.swift`

**Acceptance Criteria:**
- [ ] LE max, Wundschwelle, INI, AW, GS, each technique's AT/PA, each weapon's and shield's AT/PA on the sheet read `SheetValues` (`result`, Belastung included); none reads `DerivedValues.ausweichen/initiative/wundschwelle`, `lebensenergie.max`, `CombatTechnique.at/pa`, `MeleeWeapon.at/pa`, `Shield.at/pa`, `belastungPenalty`, `totalIniPenalty` or `totalGsPenalty`
- [ ] Each value is a button (`accessibilityIdentifier` `sheet.value.<key>`, e.g. `sheet.value.leMax`) that opens `BreakdownSheet` at `.medium` detent
- [ ] `BreakdownSheet` shows: the result; one row per line with value, rule name and clause id (`Kampfwerte · KW1`), `via` rule names; per line its facts as `<label> <value> · <owner>`; a mark `Auslegung <id>` per ruling, which expands to the ruling's `answer` text from the book; a folded `Nicht angewandt (n)` section with rule name and reason
- [ ] When `SheetValues.of(hero)` is nil, each value shows `L("rulesEngine.unavailable")`
- [ ] UI test: tapping LE opens the sheet with at least one line, and the "Nicht angewandt" header exists; a screenshot is attached under the next free number in `docs/screenshots/`

**Verify:** `make test-ui` → `** TEST SUCCEEDED **`

**Steps:**

- [ ] **Step 1: Read what the book offers for labels.** `RuleBook.rules[id].name` is the rule name; `RuleBook.rulings` holds the decided rulings (read `Model/Rule.swift` around the `rulings` property for its shape and the `answer` field). `Owner` labels: add `Strings.swift` keys `owner.sheet` "Heldenbogen"/"Hero sheet", `owner.loadout` "Ausrüstung"/"Loadout", `owner.player` "Spieler"/"Player", `owner.gm` "Meister"/"GM", `owner.round` "Runde"/"Round", `owner.roll` "Wurf"/"Roll", `owner.derived` "abgeleitet"/"derived". Reasons: `reason.<ReasonCode>` for each of the ten codes (German: `conditionFalse` "Bedingung nicht erfüllt", `unknownFact` "Angabe fehlt", `openRuling` "Auslegung offen", `requirementNotMet` "Voraussetzung fehlt", `forbidden` "nicht erlaubt", `suppressed` "unterdrückt", `replaced` "ersetzt", `overridden` "überstimmt", `rulesetOff` "Fokusregel aus", `outOfContext` "nicht in dieser Lage"; English equivalents). Also `breakdown.notApplied` "Nicht angewandt (%d)"/"Not applied (%d)", `breakdown.auslegung` "Auslegung %@"/"Ruling %@".

- [ ] **Step 2: Write the failing UI test** `HesindionUITests/SheetBreakdownTests.swift`, following the seeding and launch pattern of an existing sheet UI test (`grep -ln "HeroDetail\|heroDetail" HesindionUITests`):

```swift
import XCTest

final class SheetBreakdownTests: XCTestCase {
    func testTappingLEOpensItsBreakdown() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeed"]      // use the same seeding flag the other sheet tests use
        app.launch()
        // open the seeded hero's sheet the way the other sheet tests do
        let le = app.buttons["sheet.value.leMax"]
        XCTAssertTrue(le.waitForExistence(timeout: 5))
        le.tap()
        XCTAssertTrue(app.staticTexts["breakdown.result"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["breakdown.line.0"].exists
                      || app.staticTexts.matching(identifier: "breakdown.line.0").firstMatch.exists)
        XCTAssertTrue(app.buttons["breakdown.notApplied"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "NN-sheet-le-breakdown"   // replace NN with the next free number in docs/screenshots/
        shot.lifetime = .keepAlways
        add(shot)
    }
}
```

Replace the launch argument and the navigation with the real ones from the neighbouring test before running it.

- [ ] **Step 3: Create `BreakdownSheet.swift`:**

```swift
import SwiftUI
import RulesEngine

/// One value's breakdown (sheet cut-over design §5): the result, each line with its origin, the
/// facts it read and who stated them, its Auslegung marks, and the rules that did not apply.
struct BreakdownSheet: View {
    let title: String
    let value: SheetValue
    let book: RuleBook
    @State private var showNotApplied = false
    @State private var openRuling: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(title).font(.headline)
                        Spacer()
                        Text(value.result.map(String.init) ?? "–")
                            .font(.dsaMono(.title3, emphasis: true))
                            .accessibilityIdentifier("breakdown.result")
                    }
                }
                Section {
                    if let base = value.breakdown.base { lineRow(base, index: -1) }
                    ForEach(Array(value.breakdown.shownLines.enumerated()), id: \.offset) { i, line in
                        lineRow(line, index: i)
                    }
                }
                Section {
                    DisclosureGroup(isExpanded: $showNotApplied) {
                        ForEach(Array(value.breakdown.notApplied.enumerated()), id: \.offset) { _, n in
                            VStack(alignment: .leading) {
                                Text(ruleName(n.origin.rule)).font(.subheadline)
                                Text(L("reason.\(n.reason.rawValue)")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } label: {
                        Text(String(format: L("breakdown.notApplied"), value.breakdown.notApplied.count))
                    }
                    .accessibilityIdentifier("breakdown.notApplied")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private func lineRow(_ line: Line, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(line.value >= 0 && index >= 0 ? "+\(line.value)" : "\(line.value)")
                    .font(.dsaMono(.body, emphasis: true))
                    .frame(minWidth: 36, alignment: .trailing)
                Text(origin(line)).font(.subheadline)
            }
            ForEach(Array(line.facts.enumerated()), id: \.offset) { _, f in
                Text("\(f.name) \(f.value.display) · \(L("owner.\(f.owner.rawValue)"))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(line.rulings, id: \.self) { r in
                Button(String(format: L("breakdown.auslegung"), r)) { openRuling = (openRuling == r ? nil : r) }
                    .font(.caption)
                if openRuling == r, let answer = rulingAnswer(r) {
                    Text(answer).font(.caption)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("breakdown.line.\(index)")
    }

    private func origin(_ line: Line) -> String {
        guard let o = line.origin else { return L("owner.\((line.owner ?? .sheet).rawValue)") }
        let via = line.via.map { ruleName($0.rule) }
        return "\(ruleName(o.rule)) · \(o.clause)" + (via.isEmpty ? "" : " (\(via.joined(separator: ", ")))")
    }

    private func ruleName(_ id: String) -> String { book.rules[id]?.name ?? id }

    /// The decided answer of a ruling, `RULE.id` or `shared.id`, from the book.
    private func rulingAnswer(_ qualified: String) -> String? {
        book.rulingAnswer(qualified)
    }
}

private extension JSONValue {
    var display: String {
        switch self {
        case .int(let i): "\(i)"
        case .double(let d): "\(d)"
        case .string(let s): s
        case .bool(let b): b ? "ja" : "nein"
        case .null: "–"
        default: "…"
        }
    }
}
```

If the package has no `rulingAnswer(_:)`, add a public one in `Model/Rule.swift` next to the `rulings` storage (it looks up a qualified id — `RULE.id` in the rule's own rulings, `shared.id` in the shared ones — and returns its answer text), with a package test in `HeroSheetTests` for one decided ruling id that appears in a `kampfwerte.yaml` line (`grep -n "ruling:" specs/rules/situations/kampfwerte.yaml`).

- [ ] **Step 4: Wire the sheet.** In `HeroDetailView`, read `let values = SheetValues.of(hero)` once per body. Replace each value listed in the acceptance criteria with a button:

```swift
    @State private var breakdown: (title: String, value: SheetValue)?

    @ViewBuilder private func sheetValue(_ key: String, label: String, _ v: SheetValue?) -> some View {
        Button {
            if let v { breakdown = (L(label), v) }
        } label: {
            FieldRow(label: label, value: v?.result.map(String.init) ?? L("rulesEngine.unavailable"))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sheet.value.\(key)")
    }
```

and present it with `.sheet(item:)` (wrap the tuple in an `Identifiable` struct `BreakdownItem { let id = UUID(); let title: String; let value: SheetValue }` if the tuple cannot be used). Keys: `leMax`, `wundschwelle`, `iniBase`, `aw`, `gs`, `at.<CT_n>`, `pa.<CT_n>`, `weapon.at.<name>`, `weapon.pa.<name>`, `shield.at.<name>`, `shield.pa.<name>`. LE current stays as today (session state).

- [ ] **Step 5: Run** `make test-ui` → PASS; then `make screenshots` and delete any crash log it drops into `docs/screenshots/` (AGENTS.md).

- [ ] **Step 6: Commit.**

```bash
git add Hesindion HesindionUITests docs/screenshots Packages/RulesEngine
git commit -m "feat(sheet): the hero sheet's values come from the rules engine, and a tap shows their breakdown

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

```json:metadata
{"files": ["Hesindion/Views/BreakdownSheet.swift", "Hesindion/Views/HeroDetailView.swift", "Hesindion/Theme/Strings.swift", "HesindionUITests/SheetBreakdownTests.swift", "Packages/RulesEngine/Sources/RulesEngine/Model/Rule.swift"], "verifyCommand": "make test-ui", "acceptanceCriteria": ["every base value on HeroDetailView reads SheetValues; no stored derived value or BE suffix read", "each value is a button sheet.value.<key> opening BreakdownSheet at medium detent", "BreakdownSheet shows result, lines with rule name and clause, via, facts with owner, Auslegung marks with answer, folded Nicht angewandt list", "nil SheetValues shows rulesEngine.unavailable", "UI test opens LE breakdown and attaches a screenshot"], "modelTier": "standard"}
```

---

### Task 7: Every other reader of a base value

**Goal:** The loadout picker, the combat screens, the damage screens, healing and the command palette read their base values from `SheetValues`; the roll screens use `withoutBelastung`, so Swift's Belastung line is not counted twice.

**Files:**
- Modify: `Hesindion/Views/CombatLoadoutPicker.swift:49,58,66`
- Modify: `Hesindion/Views/CombatRootView.swift:179,232,555`
- Modify: `Hesindion/Views/CombatSetupViews.swift:223`
- Modify: `Hesindion/Views/CombatDefenseSetupView.swift:24,30,46`
- Modify: `Hesindion/Views/CombatAttackViews.swift:1163,1174` and its other `.at`/`.pa` reads
- Modify: `Hesindion/Views/CombatFernkampfViews.swift` (its 2 `.at`/`.pa` reads, if they are melee bases)
- Modify: `Hesindion/Engine/PassierschlagRoll.swift`
- Modify: `Hesindion/Views/CombatWoundEffectViews.swift`, `Hesindion/Views/CombatDamageViews.swift` (Wundschwelle)
- Modify: `Hesindion/Views/CombatDamageOutcomeBox.swift`, `Hesindion/Views/HeilungSheet.swift`, `Hesindion/Views/CommandPaletteOverlay.swift`, `Hesindion/Models/Hero.swift`, `Hesindion/Models/LogEntry.swift` (LE max)
- Test: existing UI tests (`HesindionUITests/CombatPreparationFlowTests.swift` reads `initiative.`)

**Acceptance Criteria:**
- [ ] `grep -rn "ausweichen\.\|initiative\.\|wundschwelle\.\|lebensenergie\.max\|lebensenergie\.base\|lebensenergie\.bonus" Hesindion --include='*.swift'` lists only `SheetInputBackfill.swift`, `DerivedValueRepair.swift`, `OptolithImportService.swift`, `DerivedValues.swift` and the model/migration files
- [ ] No view or engine file reads `MeleeWeapon.at/pa`, `Shield.at/pa` or `CombatTechnique.at/pa` except `SheetInputBackfill` and the import
- [ ] Roll screens (attack, defence, INI roll, Passierschlag) use `withoutBelastung`; LE max, Wundschwelle and display-only values use `result`
- [ ] `Hero.passiveShieldPABonus` has no reader left (the engine's `schilde` lines give the passive bonus); delete it
- [ ] `make test` and `make test-ui` pass; any UI test that asserted an old number changes only where the number is one of Task 5's intended differences, and the commit message names each

**Verify:** `make test && make test-ui` → both `** TEST SUCCEEDED **`

**Steps:**

- [ ] **Step 1: List the reads.** Run the grep of the first criterion and `grep -rn "\.at\b\|\.pa\b\|passiveShieldPABonus\|totalIniPenalty\|totalGsPenalty\|belastungPenalty" Hesindion/Views Hesindion/Engine Hesindion/Models --include='*.swift'`. Write the list into the task's working notes; every line must end as one of the replacements below or as a deliberate keep (the back-fill, the import).

- [ ] **Step 2: Replace by kind.**
  - A weapon's base AT for a roll: `SheetValues.of(hero)?.weapon(w).at.withoutBelastung ?? 0`. Its PA: `.weapon(w).pa.withoutBelastung`. Remove the `+ hero.passiveShieldPABonus` beside it: the engine's `pa(with: <weapon>)` already has the shield's passive bonus (`schilde.SCH1`).
  - A shield's own AT/PA: `.shield(s).at/.pa.withoutBelastung`.
  - AW base: `.aw.withoutBelastung`. INI base for the INI roll: `.iniBase.withoutBelastung`, and remove `+ hero.totalIniPenalty` beside it only if `ModifierEngine` adds Belastung to the INI roll; if the INI roll today takes `totalIniPenalty` directly (no Swift line), use `.iniBase.result` (Belastung and the armour's extra penalty included) and delete the `totalIniPenalty` addition. Read the call site to decide, and note which it was in the commit message.
  - Wundschwelle: `.wundschwelle.result`. LE max: `.leMax.result`.
  - A value shown on a screen without a roll (loadout picker chips "AT x / PA y"): `result`.
  - `Hero.swift`/`LogEntry.swift` computed properties that read LE max: give them a `leMax: Int` parameter from the caller, or read `SheetValues.of(self)` if they are `@MainActor`-safe. Prefer the parameter.

- [ ] **Step 3: Delete** `Hero.passiveShieldPABonus`, and `belastungPenalty`, `totalIniPenalty`, `totalGsPenalty`, `armorIniModifier`, `armorGsModifier` if no reader is left (`effectiveBE` stays: `SharedModifiers.encumbrance` reads it).

- [ ] **Step 4: Run** `make test` and `make test-ui`. For each failing assertion on a number, compare with Task 5's `intended` list: change the expected number only if the difference is listed there; otherwise fix the replacement.

- [ ] **Step 5: Commit.**

```bash
git add Hesindion HesindionTests HesindionUITests
git commit -m "feat(combat): every base value is read from the rules engine; rolls start from the base without Belastung

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

```json:metadata
{"files": ["Hesindion/Views/CombatLoadoutPicker.swift", "Hesindion/Views/CombatRootView.swift", "Hesindion/Views/CombatSetupViews.swift", "Hesindion/Views/CombatDefenseSetupView.swift", "Hesindion/Views/CombatAttackViews.swift", "Hesindion/Views/CombatFernkampfViews.swift", "Hesindion/Engine/PassierschlagRoll.swift", "Hesindion/Views/CombatWoundEffectViews.swift", "Hesindion/Views/CombatDamageViews.swift", "Hesindion/Views/CombatDamageOutcomeBox.swift", "Hesindion/Views/HeilungSheet.swift", "Hesindion/Views/CommandPaletteOverlay.swift", "Hesindion/Models/Hero.swift", "Hesindion/Models/LogEntry.swift"], "verifyCommand": "make test && make test-ui", "acceptanceCriteria": ["stored derived values read only by backfill, repair, import, models, migrations", "no view/engine reads MeleeWeapon/Shield/CombatTechnique at/pa", "roll screens use withoutBelastung; display and LE/WS use result", "passiveShieldPABonus deleted", "make test and make test-ui pass; changed expected numbers only for Task 5's intended differences"], "modelTier": "standard"}
```

---

### Task 8: The talent check's Belastung and "Vor der Probe"

**Goal:** A talent check gets the engine's `COND_1` line when the talent is hindered, and a reminder row above the roll offers "Für diese Probe abgelegt" per piece, "Belastung nicht anwenden" and, for maybe-talents, "Belastung zählt"; every choice holds for this check only.

**Files:**
- Create: `Hesindion/RulesEngine/TalentBelastung.swift`
- Create: `Hesindion/Views/VorDerProbeRow.swift`
- Modify: `Hesindion/Views/TalentProbeModal.swift:29-39,63-66`
- Modify: `Hesindion/Theme/Strings.swift`
- Test: `HesindionTests/TalentBelastungTests.swift`, `HesindionUITests/SheetBreakdownTests.swift` (one more test)

**Acceptance Criteria:**
- [ ] `TalentBelastung.lines(hero:talentId:choices:)` returns the engine's `COND_1` lines of `check.modifier` as `ModifierLine(value:, source:, isZustand: true, ruleId: "COND_1")`, for a check with `check.kind: talent`, `check.talent: <id>`, `check.hinderedByBelastung` from `RulesEngineStore.shared.checks`
- [ ] Boronmir in Plattenrüstung (Belastung 3, SA_41 II → Stufe I): Kraftakt (`TAL_5`, hindered) gets one line of −1; a talent flagged `false` gets none; a maybe-talent gets none unless `choices.belastungZaehlt` is true (then −1)
- [ ] `choices.putDown` containing the armour's name gives no line; containing the Großschild changes only what the shield causes; `choices.ignoreBelastung` keeps the lines but marks them struck (`TalentBelastung.Result.struck == true`) and they add 0 to the modifier
- [ ] The −5 cap: `ModifierEngine.applyingZustandCap` sees the line (`isZustand: true`)
- [ ] `TalentProbeModal` shows `VorDerProbeRow` only when the hero wears armour or carries a shield and the talent is not flagged `false`; the row's choices live in the modal's `@State`, so a new modal starts clean; the row has a link that opens `CombatLoadoutPicker` (or the sheet's loadout section)
- [ ] UI test: on the seeded hero with armour equipped, a hindered talent's check shows the row (`vorDerProbe.row`), and toggling `vorDerProbe.ignore` shows the line struck through

**Verify:** `make test && make test-ui` → both `** TEST SUCCEEDED **`

**Steps:**

- [ ] **Step 1: Write the failing tests** `HesindionTests/TalentBelastungTests.swift`:

```swift
import XCTest
@testable import Hesindion

@MainActor
final class TalentBelastungTests: XCTestCase {
    func boronmirInPlate() throws -> Hero {
        let hero = try SampleHeroes.importHero(named: "Boronmir Siebenfeld von Greifenfurt")
        for a in hero.armors { a.isEquipped = a.encumbrance == 3 }   // the Plattenrüstung
        XCTAssertTrue(hero.armors.contains { $0.isEquipped }, "Boronmir owns a Belastung-3 armour")
        return hero
    }

    func testAHinderedTalentGetsTheBelastungLine() throws {
        let r = TalentBelastung.lines(hero: try boronmirInPlate(), talentId: "TAL_5", choices: .init())
        XCTAssertEqual(r.lines.map(\.value), [-1])
        XCTAssertEqual(r.lines.first?.ruleId, "COND_1")
        XCTAssertTrue(r.lines.allSatisfy(\.isZustand))
    }

    func testATalentNotHinderedGetsNone() throws {
        let unhindered = try XCTUnwrap(RulesEngineStore.shared?.checks.hinderedByBelastung
            .first { $0.value == .bool(false) }?.key)
        XCTAssertTrue(TalentBelastung.lines(hero: try boronmirInPlate(), talentId: unhindered, choices: .init()).lines.isEmpty)
    }

    func testAMaybeTalentCountsOnlyWhenThePlayerSaysSo() throws {
        let maybe = try XCTUnwrap(RulesEngineStore.shared?.checks.hinderedByBelastung
            .first { $0.value == .string("maybe") }?.key)
        let hero = try boronmirInPlate()
        XCTAssertTrue(TalentBelastung.lines(hero: hero, talentId: maybe, choices: .init()).lines.isEmpty)
        var yes = TalentBelastung.Choices(); yes.belastungZaehlt = true
        XCTAssertEqual(TalentBelastung.lines(hero: hero, talentId: maybe, choices: yes).lines.map(\.value), [-1])
    }

    func testPuttingTheArmourDownForThisCheckRemovesTheLine() throws {
        let hero = try boronmirInPlate()
        var c = TalentBelastung.Choices()
        c.putDown = Set(hero.armors.filter(\.isEquipped).map(\.name))
        XCTAssertTrue(TalentBelastung.lines(hero: hero, talentId: "TAL_5", choices: c).lines.isEmpty)
        XCTAssertTrue(hero.armors.contains { $0.isEquipped }, "the stored loadout does not change")
    }

    func testIgnoringKeepsTheLineStruckAndAddsNothing() throws {
        var c = TalentBelastung.Choices(); c.ignoreBelastung = true
        let r = TalentBelastung.lines(hero: try boronmirInPlate(), talentId: "TAL_5", choices: c)
        XCTAssertTrue(r.struck)
        XCTAssertEqual(r.effectiveLines.reduce(0) { $0 + $1.value }, 0)
        XCTAssertEqual(r.lines.map(\.value), [-1])
    }
}
```

- [ ] **Step 2: Run** `make test` → compile error.

- [ ] **Step 3: Create `TalentBelastung.swift`:**

```swift
import Foundation
import RulesEngine

/// The talent check's Belastung (sheet cut-over design §6): the engine's COND_1 lines of
/// `check.modifier`, and the player's choices for this one check. The rest of the check stays in
/// Swift until domain 5, so only COND_1's lines are taken.
enum TalentBelastung {
    struct Choices: Equatable {
        /// Items the player put down for this check (by the app's names).
        var putDown: Set<String> = []
        /// "Belastung nicht anwenden": the lines stay, struck through, and add nothing.
        var ignoreBelastung = false
        /// "Belastung zählt", for the talents checks.yaml flags `maybe`.
        var belastungZaehlt = false
    }

    struct Result {
        var lines: [ModifierLine]
        var struck: Bool
        var breakdown: Breakdown?
        /// What the check adds: nothing when struck.
        var effectiveLines: [ModifierLine] { struck ? [] : lines }
    }

    @MainActor
    static func lines(hero: Hero, talentId: String, choices: Choices) -> Result {
        guard let store = RulesEngineStore.shared else { return Result(lines: [], struck: false, breakdown: nil) }
        var sheet = HeroSheetMapping.sheet(for: hero, book: store.engine.book)
        let worn = hero.armors.filter { $0.isEquipped && !choices.putDown.contains($0.name) }
        sheet = sheet.with(armour: worn.first?.name,
                           belastung: worn.reduce(0) { $0 + $1.encumbrance },
                           extraPenalty: worn.reduce(0) { $0 + $1.iniModifier })
        if let s = hero.selectedShieldName, choices.putDown.contains(s) { sheet = sheet.with(shield: nil) }

        var situation = RulesEngine.Situation(sheet: sheet)
        situation.state(Fact(name: "check.kind", value: .string("talent"), owner: .player))
        situation.state(Fact(name: "check.talent", value: .string(talentId), owner: .player))
        if let flag = store.checks.hinderedByBelastung[talentId] {
            situation.state(Fact(name: "check.hinderedByBelastung", value: flag, owner: .derived))
        }
        if choices.belastungZaehlt {
            situation.state(Fact(name: "choice.belastungZaehlt", value: .bool(true), owner: .player))
        }
        let b = store.engine.evaluate(Query("check.modifier"), in: situation)
        let lines = b.lines.filter { $0.origin?.rule == "COND_1" }.map {
            ModifierLine(value: $0.value, source: store.engine.book.rules["COND_1"]?.name ?? "COND_1",
                         isZustand: true, ruleId: "COND_1")
        }
        return Result(lines: lines, struck: choices.ignoreBelastung && !lines.isEmpty, breakdown: b)
    }
}
```

`Situation.state(_:)` must be public for this; if it is internal, add `public` to it in `Packages/RulesEngine/Sources/RulesEngine/Situation.swift` (it is the same call `init` uses), and note it in the commit.

- [ ] **Step 4: Run** `make test` → the five tests pass.

- [ ] **Step 5: The row.** Create `VorDerProbeRow.swift`: a compact card above the dice with the summary (`String(format: L("vorDerProbe.summary"), stufe, total, pieces)` → "Belastung %@: %d · %@"), one toggle per worn armour and the selected shield (`vorDerProbe.putDown.<name>`, label `L("vorDerProbe.putDown")` "Für diese Probe abgelegt"), a toggle `vorDerProbe.ignore` ("Belastung nicht anwenden"), a toggle `vorDerProbe.zaehlt` ("Belastung zählt") only for maybe-talents, and a link button `vorDerProbe.loadout` ("Ausrüstung ändern") that calls an `onOpenLoadout` closure. Bindings go to a `Binding<TalentBelastung.Choices>`. Identifier `vorDerProbe.row` on the card. Add the strings in both languages.

- [ ] **Step 6: Wire `TalentProbeModal`.** Add `@State private var belastungChoices = TalentBelastung.Choices()`. In `modifierLines`, for the non-wound-effect path, append `TalentBelastung.lines(hero:talentId:choices:).effectiveLines` to the `ModifierEngine` result and then apply `ModifierEngine.applyingZustandCap` to the whole list **only if** `evaluate` does not already apply it (read `ModifierEngine.evaluate`; if it does, call `applyingZustandCap` on the combined list after removing the old cap line, so the cap is applied once). Pass the struck lines to `SkillCheckModal` for display: add an optional `struckLines: [ModifierLine] = []` to `SkillCheckConfig`, rendered with `.strikethrough()` and a caption `L("vorDerProbe.struckBy")` "vom Spieler abgeschaltet". Show `VorDerProbeRow` through `SkillCheckModal`'s `hints` slot or a new `header` view parameter — pick the one that keeps `SkillCheckModal` generic, and keep the wound-effect path untouched.

- [ ] **Step 7: UI test.** Add to `SheetBreakdownTests` a test that equips the seeded hero's armour (use the sheet's equipment toggle the other UI tests use), opens a hindered talent's check (Kraftakt), asserts `vorDerProbe.row` exists, taps `vorDerProbe.ignore`, and asserts a static text containing "vom Spieler abgeschaltet" exists. Attach a screenshot with the next free number.

- [ ] **Step 8: Run** `make test && make test-ui` → PASS. Then `make screenshots`.

- [ ] **Step 9: Commit.**

```bash
git add Hesindion HesindionTests HesindionUITests docs/screenshots Packages/RulesEngine
git commit -m "feat(talents): Belastung on talent checks from the rules engine, with the Vor-der-Probe choices

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

```json:metadata
{"files": ["Hesindion/RulesEngine/TalentBelastung.swift", "Hesindion/Views/VorDerProbeRow.swift", "Hesindion/Views/TalentProbeModal.swift", "Hesindion/Views/SkillCheckModal.swift", "Hesindion/Theme/Strings.swift", "HesindionTests/TalentBelastungTests.swift", "HesindionUITests/SheetBreakdownTests.swift"], "verifyCommand": "make test && make test-ui", "acceptanceCriteria": ["TalentBelastung.lines returns COND_1 lines of check.modifier as Zustand ModifierLines", "Boronmir in plate: TAL_5 -1; false-flag talent none; maybe-talent only with belastungZaehlt", "putDown armour removes the line without changing the stored loadout; ignoreBelastung keeps lines struck and adds 0", "the -5 cap counts the line once", "VorDerProbeRow shown only when armour or shield and talent not false; choices reset per modal; loadout link", "UI test shows vorDerProbe.row and the struck line"], "modelTier": "standard"}
```

---

### Task 9: Delete the replaced formulas, stored values and catalog entries

**Goal:** The Swift side of domain 1 is gone except what the rolls still need: the formulas, the repair and the import's computation of WS/AW/INI, the stored `ausweichen`/`initiative`/`wundschwelle` (whole properties that no back-fill reads, so SchemaV6 drops them now), and the catalog entries `ADV_25`, `ADV_54`, `SA_51`, `DISADV_28`.

**Files:**
- Modify: `Hesindion/Engine/DerivedValueFormulas.swift` (delete `wundschwelle`, `ausweichen`, `initiative`; keep `geschwindigkeit`)
- Modify: `Hesindion/Services/DerivedValueRepair.swift` (keep only the GS repair)
- Modify: `HesindionTests/DerivedValueRepairTests.swift`
- Modify: `Hesindion/Services/OptolithImportService.swift` (`computeDerivedValues`: stop computing WS/AW/INI; `hoheLebenskraftBonus` goes)
- Modify: `Hesindion/Models/DerivedValues.swift` (delete `ausweichen`, `initiative`, `wundschwelle` and their `init` parameters)
- Modify: every `DerivedValues(` call site (`grep -rn "DerivedValues(" Hesindion HesindionTests`)
- Modify: `specs/data/rules-catalog.yaml` (entries `ADV_25` :526, `ADV_54` :561, `SA_51` :1400, `DISADV_28` :915), `specs/data/rules-catalog.snapshot.json`
- Create: `Hesindion/Migration/SchemaV6.swift`; modify `Hesindion/Migration/MigrationPlan.swift`
- Test: `HesindionTests/SchemaV6MigrationTests.swift`, `HesindionTests/Fixtures/StoreV5/` (new)

**Acceptance Criteria:**
- [ ] `grep -rn "DerivedValueFormulas\.\(wundschwelle\|ausweichen\|initiative\)\|hoheLebenskraftBonus" Hesindion HesindionTests` → no match
- [ ] `DerivedValues` has no `ausweichen`, `initiative`, `wundschwelle`; `SchemaV6` (version 6.0.0) with a lightweight `migrateV5toV6`
- [ ] A store created by the V5 build opens with V6 (a test builds a V5-shaped container on disk, inserts Boronmir, reopens with the V6 plan and finds the hero with its LE current)
- [ ] `ADV_25`, `ADV_54`, `SA_51`, `DISADV_28` are removed from `rules-catalog.yaml` (the validator's "missing id" rule: if it requires every `rules.db` id to have an entry, give each the status that says "the rules engine owns it" — read the catalog's header for the allowed statuses; if none fits, add a status `engine` to the validator and `specs/data/rule-vocabulary.json` with a test, and say so in the commit); `make rules-db UPDATE_SNAPSHOT=1` rewrites the snapshot
- [ ] `COND_1` and `SA_41` entries stay; `SharedModifiers.encumbrance` stays
- [ ] `make test` and `make test-ui` pass

**Verify:** `make rules-db && make test && make test-ui` → all succeed

**Steps:**

- [ ] **Step 1: The migration test first.** Add `HesindionTests/SchemaV6MigrationTests.swift`: create a container at a temp URL with `Schema(versionedSchema: SchemaV5.self)` and the V5 plan (`HesindionMigrationPlan` before this task's change — build it with `schemas: [SchemaV1…SchemaV5]` by a test-local plan type), insert an imported Boronmir, save, close; reopen with the real plan (now ending at V6); fetch the hero; assert `derivedValues?.lebensenergie.current` is unchanged. Because every schema version lists the live model classes, a V5-shaped store must be produced before the properties are deleted: write the test, run it on the V5 code (PASS), keep the store file as a fixture under `HesindionTests/Fixtures/StoreV5/` (commit it), then change the test to open that fixture only.

- [ ] **Step 2: Delete** the three formulas, their repair branches (keep GS), their repair tests (keep GS's), the import's computation, `hoheLebenskraftBonus`, and the three `DerivedValues` properties with their `init` parameters and call sites.

- [ ] **Step 3: SchemaV6.** Copy `SchemaV5.swift` to `SchemaV6.swift` (`Schema.Version(6, 0, 0)`), add it and `migrateV5toV6` (lightweight) to `MigrationPlan`, and make V6 the current schema wherever V5 was named.

- [ ] **Step 4: The catalog.** Edit the four entries as the first criterion says; run `make rules-db UPDATE_SNAPSHOT=1`; review the snapshot diff (four statuses move, nothing else).

- [ ] **Step 5: Run** `make rules-db && make test && make test-ui` → PASS.

- [ ] **Step 6: Commit.**

```bash
git add Hesindion HesindionTests specs/data
git commit -m "refactor(sheet): the Swift formulas, stored values and catalog entries the engine replaced are gone

WS, AW and INI are no longer stored (SchemaV6); ADV_25, ADV_54, SA_51 and DISADV_28
leave the catalog. COND_1 and SA_41 stay until domain 2.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

```json:metadata
{"files": ["Hesindion/Engine/DerivedValueFormulas.swift", "Hesindion/Services/DerivedValueRepair.swift", "HesindionTests/DerivedValueRepairTests.swift", "Hesindion/Services/OptolithImportService.swift", "Hesindion/Models/DerivedValues.swift", "Hesindion/Migration/SchemaV6.swift", "Hesindion/Migration/MigrationPlan.swift", "HesindionTests/SchemaV6MigrationTests.swift", "HesindionTests/Fixtures/StoreV5", "specs/data/rules-catalog.yaml", "specs/data/rules-catalog.snapshot.json"], "verifyCommand": "make rules-db && make test && make test-ui", "acceptanceCriteria": ["no reference to the deleted formulas or hoheLebenskraftBonus", "DerivedValues has no ausweichen/initiative/wundschwelle; SchemaV6 lightweight", "a V5 store fixture opens with V6 and keeps LE current", "ADV_25, ADV_54, SA_51, DISADV_28 leave the catalog; snapshot rebuilt", "COND_1, SA_41 and SharedModifiers.encumbrance stay", "make test and make test-ui pass"], "modelTier": "standard"}
```

---

### Task 10: Documents

**Goal:** AGENTS.md, the CHANGELOG and the spec say that domain 1 has switched and how.

**Files:**
- Modify: `AGENTS.md` (the paragraph at :114 "A new declarative rules engine is being built beside this one…", the `DerivedValueFormulas`/`DerivedValueRepair` mentions, the `make` target list near the top)
- Modify: `CHANGELOG.md` (`[Unreleased]`)
- Modify: `docs/plans/2026-09-27-sheet-cutover-design.md` (status line)

**Acceptance Criteria:**
- [ ] AGENTS.md: the rules-engine paragraph says the sheet domain (LE, Wundschwelle, INI, AW, GS, AT/PA) reads the engine through `HeroSheetMapping` → `HeroSheet` → `SheetValues`, that roll screens take `withoutBelastung` until domain 2, that `HeroSheet` has no session state until domain 4, the "Vor der Probe" principle, and that `rules.json`/`checks.json` are build products (`make rules-json`, `require-rules-json`); `make hero-sheet-fixtures` is in the target list
- [ ] CHANGELOG `[Unreleased]` has an "Added"/"Changed" entry naming the breakdown sheet, the talent-check Belastung with its three choices, and every intended difference from Task 5 by rule
- [ ] The spec's status line reads `implemented <date>; the folded fields leave in SchemaV7: plan Task 11`
- [ ] No DSA rule prose added (Data Policy)

**Verify:** `git diff --stat HEAD~1 -- AGENTS.md CHANGELOG.md docs/plans` shows the three files; `make test-rules-review` passes (it checks `RULINGS.md`, untouched but cheap to confirm)

**Steps:**

- [ ] **Step 1:** Rewrite the AGENTS.md paragraph's first sentence from "not wired into any screen yet" to what is wired now, keeping the rest of the paragraph (the vocabulary, `rulec`, the §9 order). Add one sentence per criterion item. Remove or correct every sentence that names a deleted symbol (`grep -n "DerivedValueFormulas\|DerivedValueRepair\|passiveShieldPABonus\|totalIniPenalty" AGENTS.md`).
- [ ] **Step 2:** Write the CHANGELOG entry in the file's existing style (bold lead sentence, then details).
- [ ] **Step 3:** Update the spec's status line.
- [ ] **Step 4:** Run `make test-rules-review` → PASS.
- [ ] **Step 5: Commit.**

```bash
git add AGENTS.md CHANGELOG.md docs/plans/2026-09-27-sheet-cutover-design.md
git commit -m "docs: domain 1 (the sheet) reads the rules engine

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

```json:metadata
{"files": ["AGENTS.md", "CHANGELOG.md", "docs/plans/2026-09-27-sheet-cutover-design.md"], "verifyCommand": "make test-rules-review", "acceptanceCriteria": ["AGENTS.md rules paragraph describes the wired sheet domain, withoutBelastung, no session state, Vor der Probe, rules.json/checks.json build products, hero-sheet-fixtures target", "CHANGELOG names breakdown sheet, talent Belastung choices and every intended difference by rule", "spec status line updated", "no DSA rule prose"], "modelTier": "mechanical"}
```

---

### Task 11: SchemaV7 — drop the folded fields (after every device ran V6)

**Goal:** The folded values the back-fill read (`CombatTechnique.at/pa`, `MeleeWeapon.at/pa`, `Shield.at/pa`, `LifeEnergyValue.base/bonus/max`) and `SheetInputBackfill` itself are deleted, once the owner confirms every device launched a build with SchemaV6.

> **USER-ORDERED GATE — NON-SKIPPABLE.** This task was requested by the user in the current conversation. It MUST NOT be closed by walking around it, by declaring it "verified inline", or by substituting a cheaper check. Close only after every item in `acceptanceCriteria` has been re-validated independently, with output captured.

**Files:**
- Modify: `Hesindion/Models/CombatTechnique.swift`, `Hesindion/Models/MeleeWeapon.swift`, `Hesindion/Models/Shield.swift`, `Hesindion/Models/DerivedValues.swift`
- Modify: `Hesindion/Services/OptolithImportService.swift`
- Delete: `Hesindion/RulesEngine/SheetInputBackfill.swift`, `HesindionTests/SheetInputBackfillTests.swift`
- Modify: `Hesindion/ContentView.swift`
- Create: `Hesindion/Migration/SchemaV7.swift`; modify `MigrationPlan.swift`
- Modify: `HesindionTests/SheetValuesTests.swift` (the old-vs-new test reads stored values; turn its expectations into literals first)

**Acceptance Criteria:**
- [ ] The owner confirmed in the conversation that every device (iPhone, iPad, "Karl", "Kombucha") ran a SchemaV6 build (quote the confirmation in the task's close note)
- [ ] Before deleting: `testTheEngineAgreesWithTheStoredValuesExceptTheNamedDifferences` is rewritten to literal expected numbers per hero, taken from a passing run on the V6 code (print them, paste them)
- [ ] The listed properties are gone; `LifeEnergyValue` keeps `purchased` and `current`; `SchemaV7` with lightweight `migrateV6toV7`; a V6 store fixture opens with V7 and keeps LE current and the weapons' `atModifier`/`paModifier`
- [ ] `SheetInputBackfill` and its call are gone; the import no longer folds
- [ ] `make test` and `make test-ui` pass

**Verify:** `make test && make test-ui` → both `** TEST SUCCEEDED **`; `grep -rn "SheetInputBackfill\|\.lebensenergie\.base\|ct\.at\b" Hesindion` → no match

**Steps:**

- [ ] **Step 1:** Ask the owner for the confirmation; do nothing else in this task until it is given.
- [ ] **Step 2:** Freeze the old-vs-new test into literals (run it, print each hero's values, paste them as expected numbers, run again → PASS). Commit.
- [ ] **Step 3:** Make a V6 store fixture exactly as Task 9 Step 1 made the V5 one; add the V6→V7 migration test (PASS on V6 code).
- [ ] **Step 4:** Delete the fields, the back-fill, the fold; add SchemaV7 and its stage; run `make test && make test-ui` → PASS.
- [ ] **Step 5: Commit.**

```bash
git add Hesindion HesindionTests
git commit -m "refactor(model): SchemaV7 drops the folded AT/PA and LE values; the back-fill is done

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

```json:metadata
{"files": ["Hesindion/Models/CombatTechnique.swift", "Hesindion/Models/MeleeWeapon.swift", "Hesindion/Models/Shield.swift", "Hesindion/Models/DerivedValues.swift", "Hesindion/Services/OptolithImportService.swift", "Hesindion/RulesEngine/SheetInputBackfill.swift", "HesindionTests/SheetInputBackfillTests.swift", "Hesindion/ContentView.swift", "Hesindion/Migration/SchemaV7.swift", "Hesindion/Migration/MigrationPlan.swift", "HesindionTests/SheetValuesTests.swift"], "verifyCommand": "make test && make test-ui", "acceptanceCriteria": ["owner confirmed every device ran a SchemaV6 build, quoted in the close note", "old-vs-new test frozen to literal numbers before deletion", "folded properties gone; SchemaV7 lightweight; V6 fixture opens with V7 keeping LE current and item modifiers", "SheetInputBackfill and the fold removed", "make test and make test-ui pass"], "modelTier": "standard", "userGate": true, "tags": ["user-gate"], "gateScope": "owner confirms every device launched a SchemaV6 build before the folded fields are dropped"}
```

---

### Task 12: Close domain 1 — the owner's review of `DISADV_28`

**Goal:** The last rule of the sheet sweep is reviewed, and the done criterion of the spec (§8) holds.

> **USER-ORDERED GATE — NON-SKIPPABLE.** This task was requested by the user in the current conversation. It MUST NOT be closed by walking around it, by declaring it "verified inline", or by substituting a cheaper check. Close only after every item in `acceptanceCriteria` has been re-validated independently, with output captured.

**Files:**
- Modify (by the owner, through the review tool): `specs/rules/disadvantages/DISADV_28.yaml` (`reviewed`)

**Acceptance Criteria:**
- [ ] `make rules-sweep SWEEP=sheet` prints `15 rules, 15 reviewed with nothing open` or lists `trefferzonen` only with its 3 conflicts (TZ.9–TZ.11, which belong to domain 3 and do not block, spec §8)
- [ ] `make test-rules-engine` harness line has 0 failed
- [ ] `make test` and `make test-ui` pass on the final tree
- [ ] The spec's §8 items 1–6 are each checked off in the close note with the command output that shows it

**Verify:** `make rules-sweep SWEEP=sheet && make test-rules-engine 2>&1 | grep harness: && make test && make test-ui`

**Steps:**

- [ ] **Step 1:** Ask the owner to run `make rules-review SWEEP=sheet` and review `DISADV_28`. If the review flags a rule change, run the agent pass (`make rules-queue`, then the change), and re-run `make test-rules-engine`.
- [ ] **Step 2:** Run the Verify command and paste its output into the close note, item by item against spec §8.
- [ ] **Step 3:** Commit the review mark if the owner did not.

```bash
git add specs/rules/disadvantages/DISADV_28.yaml
git commit -m "rules: DISADV_28 reviewed; the sheet domain has switched

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

```json:metadata
{"files": ["specs/rules/disadvantages/DISADV_28.yaml"], "verifyCommand": "make rules-sweep SWEEP=sheet && make test-rules-engine 2>&1 | grep harness: && make test && make test-ui", "acceptanceCriteria": ["rules-sweep sheet: all reviewed, or only trefferzonen's 3 domain-3 conflicts open", "harness 0 failed", "make test and make test-ui pass", "spec §8 items 1-6 checked off with output"], "modelTier": "mechanical", "userGate": true, "tags": ["user-gate"], "gateScope": "owner reviews DISADV_28 and the §8 done criterion is shown with command output"}
```

---

## Dependencies

- Task 2 ← Task 1 (the test file)
- Task 3 ← Task 1 (`checks.json`), Task 2 (the package the app links must build with `HeroSheet`)
- Task 4 ← Task 3 (links the package; independent of engine code otherwise)
- Task 5 ← Tasks 3, 4
- Task 6 ← Task 5
- Task 7 ← Task 5
- Task 8 ← Task 5 (and runs after Task 7 to avoid conflicting edits in `Strings.swift` — sequential)
- Task 9 ← Tasks 6, 7, 8
- Task 10 ← Task 9
- Task 11 ← Task 10, and the owner's confirmation
- Task 12 ← Task 10

Execution is sequential in the order above; Tasks 6 and 7 touch different files but both edit `Strings.swift` and `Hero.swift`, so do not run them in parallel.
