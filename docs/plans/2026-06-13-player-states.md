# Player States (Zustände & Status) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Track DSA 5 Zustände (leveled I–IV) and Status (binary) per hero, surface them as prominent table reminders, and feed their penalties into the existing ModifierEngine so skill checks and combat rolls stay mathematically correct — with first-class removal UX.

**Architecture:** A static `StateCatalog` (Swift data, no rules DB per data policy) describes every state; a single new SwiftData `@Model HeroStateEntry` (stateID + level) persists active states via a cascade relationship on `Hero`. A new `StateModifiers` group of `ModifierDefinition`s feeds the existing `ModifierEngine.shared`, and `ModifierEngine.evaluate` gains the GR −5 Zustand-penalty cap. Schmerz migrates into this catalog-driven path; Belastung stays armor-derived but counts toward the cap and the 8-level Handlungsunfähig threshold.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest + swift-snapshot-testing. Build/test via `make test` (iPad Pro 11-inch simulator).

**Design doc:** `docs/plans/2026-06-13-player-states-design.md`

**Pre-existing baseline (do NOT let this list grow):** On clean `main`, these snapshot tests already fail — `CombatRootViewSnapshotTests.testMidCombat`, `HeroListViewSnapshotTests.testEmptyState`, `HeroListViewSnapshotTests.testPopulated`. All other tests pass. Re-record only snapshots this feature intentionally changes.

**Conventions to follow:**
- Localization: all user-facing German via `L("key")` → `DSAStrings.localized` map in `Hesindion/Theme/Strings.swift`.
- Modifier pattern: `ModifierDefinition(id:domains:){ ctx in ... ModifierLine(value:source:) }` (see `Hesindion/Engine/MeleeModifiers.swift`).
- Neo-brutalist UI: 2–3px `Color.dsaBorder` rectangles, monospaced black numerics, group colors. Match `CombatRootView` STATUS section (`Hesindion/Views/CombatRootView.swift:176`).
- Commit after every passing task. Update `CHANGELOG.md` `[Unreleased]` as you go.

---

## Task 0: StateCatalog — definitions & data

**Files:**
- Create: `Hesindion/Models/StateCatalog.swift`
- Test: `HesindionTests/StateCatalogTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import Hesindion

final class StateCatalogTests: XCTestCase {
    func testCoreZustaendePresent() {
        let ids = Set(StateCatalog.all.map(\.id))
        for id in ["schmerz", "belastung", "betaeubung", "furcht", "paralyse",
                   "verwirrung", "berauscht", "entrueckung"] {
            XCTAssertTrue(ids.contains(id), "missing zustand \(id)")
        }
    }

    func testCoreStatusPresent() {
        let ids = Set(StateCatalog.all.map(\.id))
        for id in ["liegend", "blutend", "brennend", "blind", "taub", "stumm",
                   "fixiert", "eingeengt", "ueberrascht", "vergiftet", "krank",
                   "bewegungsunfaehig", "handlungsunfaehig", "bewusstlos",
                   "unsichtbar", "versteinert", "uebler_geruch"] {
            XCTAssertTrue(ids.contains(id), "missing status \(id)")
        }
    }

    func testIdsUnique() {
        let ids = StateCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testZustaendeHaveFourEffectLevels() {
        for def in StateCatalog.all where def.kind == .zustand {
            XCTAssertEqual(def.levelEffectKeys.count, 4, "\(def.id) must define I–IV")
        }
    }

    func testLookupById() {
        XCTAssertEqual(StateCatalog.definition(for: "furcht")?.id, "furcht")
        XCTAssertNil(StateCatalog.definition(for: "nonsense"))
    }

    func testAutoDerivedStatesAreNotManuallyAddable() {
        // Schmerz & Belastung are derived; must not appear in the add-picker list.
        XCTAssertFalse(StateCatalog.manuallyAddable.contains { $0.id == "belastung" })
        XCTAssertFalse(StateCatalog.manuallyAddable.contains { $0.id == "schmerz" })
        XCTAssertTrue(StateCatalog.manuallyAddable.contains { $0.id == "furcht" })
    }
}
```

**Step 2: Run to verify it fails**

Run: `make test 2>&1 | grep StateCatalogTests`
Expected: compile failure (`StateCatalog` undefined).

**Step 3: Implement `StateCatalog.swift`**

Define the types and the full catalog. All display text via localization keys (strings added in Task 4 — keys may not resolve yet, that's fine for compilation).

```swift
import Foundation

enum StateKind: Equatable {
    case zustand   // leveled I–IV
    case status    // binary
}

/// How a state's penalty wires into the ModifierEngine.
enum StateMechanic: Equatable {
    /// `-level` (or fixed) applied to the given domains, labelled, respects schipIgnoreZustand.
    case penalty(domains: Set<CheckDomain>)
    /// Drives existing Beengte-Umgebung weapon-length penalties instead of a flat line.
    case eingeengt
    /// Geweihten bonus/penalty toggle (gottgefällig).
    case entrueckung
    /// No automatic math — reminder only.
    case reminderOnly
}

struct StateDefinition: Identifiable, Equatable {
    let id: String
    let kind: StateKind
    let nameKey: String          // L() key
    let iconSystemName: String
    let mechanic: StateMechanic
    /// I–IV effect summary keys (4 entries for .zustand; 1 for .status).
    let levelEffectKeys: [String]
    let causeKey: String
    let removalKey: String       // decay / how to remove — shown prominently
    /// Statuses this state implies for display (e.g. bewusstlos ⇒ [handlungsunfaehig]).
    let implies: [String]
    /// Level (per Stufe) at which the state counts as Handlungsunfähig (4 for most Zustände; nil otherwise).
    let handlungsunfaehigAtLevel: Int?

    static func == (a: StateDefinition, b: StateDefinition) -> Bool { a.id == b.id }
}

enum StateCatalog {
    static let all: [StateDefinition] = zustaende + statuses

    static func definition(for id: String) -> StateDefinition? {
        all.first { $0.id == id }
    }

    /// States a user can add by hand (excludes auto-derived Schmerz/Belastung).
    static var manuallyAddable: [StateDefinition] {
        all.filter { $0.id != "schmerz" && $0.id != "belastung" }
    }

    static let zustaende: [StateDefinition] = [
        StateDefinition(
            id: "betaeubung", kind: .zustand, nameKey: "state.betaeubung.name",
            iconSystemName: "bolt.horizontal.circle",
            mechanic: .penalty(domains: Set(CheckDomain.allCases)),
            levelEffectKeys: ["state.betaeubung.I", "state.betaeubung.II",
                              "state.betaeubung.III", "state.betaeubung.IV"],
            causeKey: "state.betaeubung.cause", removalKey: "state.betaeubung.removal",
            implies: [], handlungsunfaehigAtLevel: 4),
        StateDefinition(
            id: "furcht", kind: .zustand, nameKey: "state.furcht.name",
            iconSystemName: "exclamationmark.shield",
            mechanic: .penalty(domains: Set(CheckDomain.allCases)),
            levelEffectKeys: ["state.furcht.I", "state.furcht.II",
                              "state.furcht.III", "state.furcht.IV"],
            causeKey: "state.furcht.cause", removalKey: "state.furcht.removal",
            implies: [], handlungsunfaehigAtLevel: 4),
        StateDefinition(
            id: "paralyse", kind: .zustand, nameKey: "state.paralyse.name",
            iconSystemName: "figure.stand",
            mechanic: .penalty(domains: Set(CheckDomain.allCases)),
            levelEffectKeys: ["state.paralyse.I", "state.paralyse.II",
                              "state.paralyse.III", "state.paralyse.IV"],
            causeKey: "state.paralyse.cause", removalKey: "state.paralyse.removal",
            implies: [], handlungsunfaehigAtLevel: nil),   // IV ⇒ Bewegungsunfähig, handled in Hero
        StateDefinition(
            id: "verwirrung", kind: .zustand, nameKey: "state.verwirrung.name",
            iconSystemName: "questionmark.circle",
            mechanic: .penalty(domains: Set(CheckDomain.allCases)),
            levelEffectKeys: ["state.verwirrung.I", "state.verwirrung.II",
                              "state.verwirrung.III", "state.verwirrung.IV"],
            causeKey: "state.verwirrung.cause", removalKey: "state.verwirrung.removal",
            implies: [], handlungsunfaehigAtLevel: 4),
        StateDefinition(
            id: "berauscht", kind: .zustand, nameKey: "state.berauscht.name",
            iconSystemName: "wineglass",
            mechanic: .reminderOnly,    // only Zechen checks; app can't see talent identity yet
            levelEffectKeys: ["state.berauscht.I", "state.berauscht.II",
                              "state.berauscht.III", "state.berauscht.IV"],
            causeKey: "state.berauscht.cause", removalKey: "state.berauscht.removal",
            implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(
            id: "entrueckung", kind: .zustand, nameKey: "state.entrueckung.name",
            iconSystemName: "sparkles",
            mechanic: .entrueckung,
            levelEffectKeys: ["state.entrueckung.I", "state.entrueckung.II",
                              "state.entrueckung.III", "state.entrueckung.IV"],
            causeKey: "state.entrueckung.cause", removalKey: "state.entrueckung.removal",
            implies: [], handlungsunfaehigAtLevel: nil),
        // Auto-derived; present in catalog for display, excluded from manuallyAddable.
        StateDefinition(
            id: "schmerz", kind: .zustand, nameKey: "source.schmerz",
            iconSystemName: "exclamationmark.triangle.fill",
            mechanic: .penalty(domains: Set(CheckDomain.allCases)),
            levelEffectKeys: ["state.schmerz.I", "state.schmerz.II",
                              "state.schmerz.III", "state.schmerz.IV"],
            causeKey: "state.schmerz.cause", removalKey: "state.schmerz.removal",
            implies: [], handlungsunfaehigAtLevel: 4),
        StateDefinition(
            id: "belastung", kind: .zustand, nameKey: "source.belastung",
            iconSystemName: "shippingbox",
            mechanic: .reminderOnly,    // encumbrance modifier already exists separately
            levelEffectKeys: ["state.belastung.I", "state.belastung.II",
                              "state.belastung.III", "state.belastung.IV"],
            causeKey: "state.belastung.cause", removalKey: "state.belastung.removal",
            implies: [], handlungsunfaehigAtLevel: nil),
    ]

    static let statuses: [StateDefinition] = [
        StateDefinition(id: "liegend", kind: .status, nameKey: "state.liegend.name",
            iconSystemName: "figure.fall", mechanic: .penalty(domains: [.meleeAttack, .meleeParry, .meleeDodge]),
            levelEffectKeys: ["state.liegend.effect"], causeKey: "state.liegend.cause",
            removalKey: "state.liegend.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "fixiert", kind: .status, nameKey: "state.fixiert.name",
            iconSystemName: "pin", mechanic: .penalty(domains: [.meleeDodge]),
            levelEffectKeys: ["state.fixiert.effect"], causeKey: "state.fixiert.cause",
            removalKey: "state.fixiert.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "eingeengt", kind: .status, nameKey: "beengteUmgebung",
            iconSystemName: "arrow.down.right.and.arrow.up.left", mechanic: .eingeengt,
            levelEffectKeys: ["state.eingeengt.effect"], causeKey: "state.eingeengt.cause",
            removalKey: "state.eingeengt.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "blutend", kind: .status, nameKey: "state.blutend.name",
            iconSystemName: "drop.fill", mechanic: .reminderOnly,
            levelEffectKeys: ["state.blutend.effect"], causeKey: "state.blutend.cause",
            removalKey: "state.blutend.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "brennend", kind: .status, nameKey: "state.brennend.name",
            iconSystemName: "flame.fill", mechanic: .reminderOnly,
            levelEffectKeys: ["state.brennend.effect"], causeKey: "state.brennend.cause",
            removalKey: "state.brennend.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "blind", kind: .status, nameKey: "state.blind.name",
            iconSystemName: "eye.slash", mechanic: .reminderOnly,
            levelEffectKeys: ["state.blind.effect"], causeKey: "state.blind.cause",
            removalKey: "state.blind.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "taub", kind: .status, nameKey: "state.taub.name",
            iconSystemName: "ear.badge.checkmark", mechanic: .reminderOnly,
            levelEffectKeys: ["state.taub.effect"], causeKey: "state.taub.cause",
            removalKey: "state.taub.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "stumm", kind: .status, nameKey: "state.stumm.name",
            iconSystemName: "mouth", mechanic: .reminderOnly,
            levelEffectKeys: ["state.stumm.effect"], causeKey: "state.stumm.cause",
            removalKey: "state.stumm.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "ueberrascht", kind: .status, nameKey: "state.ueberrascht.name",
            iconSystemName: "exclamationmark.2", mechanic: .reminderOnly,
            levelEffectKeys: ["state.ueberrascht.effect"], causeKey: "state.ueberrascht.cause",
            removalKey: "state.ueberrascht.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "unsichtbar", kind: .status, nameKey: "state.unsichtbar.name",
            iconSystemName: "eye.trianglebadge.exclamationmark", mechanic: .reminderOnly,
            levelEffectKeys: ["state.unsichtbar.effect"], causeKey: "state.unsichtbar.cause",
            removalKey: "state.unsichtbar.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "vergiftet", kind: .status, nameKey: "state.vergiftet.name",
            iconSystemName: "cross.vial", mechanic: .reminderOnly,
            levelEffectKeys: ["state.vergiftet.effect"], causeKey: "state.vergiftet.cause",
            removalKey: "state.vergiftet.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "krank", kind: .status, nameKey: "state.krank.name",
            iconSystemName: "thermometer.medium", mechanic: .reminderOnly,
            levelEffectKeys: ["state.krank.effect"], causeKey: "state.krank.cause",
            removalKey: "state.krank.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "uebler_geruch", kind: .status, nameKey: "state.uebler_geruch.name",
            iconSystemName: "wind", mechanic: .reminderOnly,
            levelEffectKeys: ["state.uebler_geruch.effect"], causeKey: "state.uebler_geruch.cause",
            removalKey: "state.uebler_geruch.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "bewegungsunfaehig", kind: .status, nameKey: "state.bewegungsunfaehig.name",
            iconSystemName: "figure.stand", mechanic: .reminderOnly,
            levelEffectKeys: ["state.bewegungsunfaehig.effect"], causeKey: "state.bewegungsunfaehig.cause",
            removalKey: "state.bewegungsunfaehig.removal", implies: [], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "handlungsunfaehig", kind: .status, nameKey: "state.handlungsunfaehig.name",
            iconSystemName: "hand.raised.slash", mechanic: .reminderOnly,
            levelEffectKeys: ["state.handlungsunfaehig.effect"], causeKey: "state.handlungsunfaehig.cause",
            removalKey: "state.handlungsunfaehig.removal", implies: ["liegend"], handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "bewusstlos", kind: .status, nameKey: "state.bewusstlos.name",
            iconSystemName: "zzz", mechanic: .reminderOnly,
            levelEffectKeys: ["state.bewusstlos.effect"], causeKey: "state.bewusstlos.cause",
            removalKey: "state.bewusstlos.removal", implies: ["handlungsunfaehig", "liegend"],
            handlungsunfaehigAtLevel: nil),
        StateDefinition(id: "versteinert", kind: .status, nameKey: "state.versteinert.name",
            iconSystemName: "cube", mechanic: .reminderOnly,
            levelEffectKeys: ["state.versteinert.effect"], causeKey: "state.versteinert.cause",
            removalKey: "state.versteinert.removal", implies: ["handlungsunfaehig", "bewegungsunfaehig"],
            handlungsunfaehigAtLevel: nil),
    ]
}
```

**Step 4: Run to verify pass**

Run: `make test 2>&1 | grep StateCatalogTests`
Expected: all `StateCatalogTests` pass.

**Step 5: Commit**

```bash
git add Hesindion/Models/StateCatalog.swift HesindionTests/StateCatalogTests.swift
git commit -m "feat: add StateCatalog of DSA 5 Zustände and Status"
```

---

## Task 1: HeroStateEntry model & Hero integration

**Files:**
- Create: `Hesindion/Models/HeroStateEntry.swift`
- Modify: `Hesindion/Models/Hero.swift` (add relationship + computed helpers)
- Modify: `Hesindion/HesindionApp.swift` (register model in ModelContainer schema — find the `Schema([...])` / `for:` list and add `HeroStateEntry.self`)
- Test: `HesindionTests/HeroStateTests.swift`

**Step 1: Write the failing test** (in-memory SwiftData container)

```swift
import XCTest
import SwiftData
@testable import Hesindion

final class HeroStateTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Hero.self, HeroStateEntry.self, /* …existing models… */
            configurations: config)
        return ModelContext(container)
    }

    func testAddAndReadState() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test")
        ctx.insert(hero)
        hero.setStateLevel("furcht", level: 2)
        XCTAssertEqual(hero.level(of: "furcht"), 2)
        XCTAssertTrue(hero.hasState("furcht"))
    }

    func testSettingLevelZeroRemovesEntry() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("furcht", level: 2)
        hero.setStateLevel("furcht", level: 0)
        XCTAssertFalse(hero.hasState("furcht"))
        XCTAssertEqual(hero.states.count, 0)
    }

    func testZustandLevelClampedToFour() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("furcht", level: 9)
        XCTAssertEqual(hero.level(of: "furcht"), 4)
    }

    func testStatusAlwaysLevelOne() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("liegend", level: 3)   // status: any positive ⇒ 1
        XCTAssertEqual(hero.level(of: "liegend"), 1)
    }

    func testTotalZustandLevelsIncludesSchmerzAndBelastung() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("furcht", level: 2)
        // schmerz/belastung derived = 0 for a bare hero
        XCTAssertEqual(hero.totalZustandLevels, 2)
    }

    func testHandlungsunfaehigAtEightLevels() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("furcht", level: 4)
        hero.setStateLevel("verwirrung", level: 4)
        XCTAssertTrue(hero.isHandlungsunfaehig)
    }

    func testLevelFourZustandImpliesHandlungsunfaehig() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("betaeubung", level: 4)
        XCTAssertTrue(hero.isHandlungsunfaehig)
    }

    func testParalyseFourImpliesBewegungsunfaehig() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("paralyse", level: 4)
        XCTAssertTrue(hero.isBewegungsunfaehig)
    }

    func testImpliedStatusesFromBewusstlos() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("bewusstlos", level: 1)
        let implied = hero.impliedStateIDs
        XCTAssertTrue(implied.contains("handlungsunfaehig"))
        XCTAssertTrue(implied.contains("liegend"))
    }
}
```

**Step 2: Run to verify it fails** — `make test 2>&1 | grep HeroStateTests` → compile failure.

**Step 3: Implement `HeroStateEntry.swift`**

```swift
import Foundation
import SwiftData

@Model
final class HeroStateEntry {
    var stateID: String
    var level: Int

    init(stateID: String, level: Int) {
        self.stateID = stateID
        self.level = level
    }
}
```

**Step 4: Extend `Hero.swift`**

Add the relationship near the other `@Relationship` lines (Hero.swift:32):

```swift
@Relationship(deleteRule: .cascade) var states: [HeroStateEntry] = []
```

Add a `// MARK: - Player States` section (after the Schmerz section, ~Hero.swift:263):

```swift
    /// Current stored level of a catalog state (0 if absent). Schmerz/Belastung are derived.
    func level(of stateID: String) -> Int {
        if stateID == "schmerz" { return effectiveSchmerzLevel }
        if stateID == "belastung" { return effectiveBE }
        return states.first { $0.stateID == stateID }?.level ?? 0
    }

    func hasState(_ stateID: String) -> Bool { level(of: stateID) > 0 }

    /// Set/clear a manually-tracked state. Clamps Zustände to 1–4, statuses to 1; level 0 removes.
    func setStateLevel(_ stateID: String, level rawLevel: Int) {
        guard stateID != "schmerz", stateID != "belastung" else { return }
        let def = StateCatalog.definition(for: stateID)
        let clamped: Int = {
            if rawLevel <= 0 { return 0 }
            return def?.kind == .status ? 1 : min(rawLevel, 4)
        }()
        let existing = states.first { $0.stateID == stateID }
        if clamped == 0 {
            if let e = existing { states.removeAll { $0 === e }; modelContext?.delete(e) }
        } else if let e = existing {
            e.level = clamped
        } else {
            states.append(HeroStateEntry(stateID: stateID, level: clamped))
        }
    }

    /// All active states (stored + derived Schmerz/Belastung when > 0), as (definition, level).
    var activeStates: [(def: StateDefinition, level: Int)] {
        var result: [(StateDefinition, Int)] = []
        if let s = StateCatalog.definition(for: "schmerz"), effectiveSchmerzLevel > 0 {
            result.append((s, effectiveSchmerzLevel))
        }
        if let b = StateCatalog.definition(for: "belastung"), effectiveBE > 0 {
            result.append((b, effectiveBE))
        }
        for entry in states {
            if let def = StateCatalog.definition(for: entry.stateID) {
                result.append((def, entry.level))
            }
        }
        return result
    }

    /// Sum of all Zustand levels (GR: ≥8 ⇒ Handlungsunfähig). Statuses don't count.
    var totalZustandLevels: Int {
        activeStates.filter { $0.def.kind == .zustand }.reduce(0) { $0 + $1.level }
    }

    /// Derived statuses implied by active states (e.g. bewusstlos ⇒ handlungsunfaehig, liegend).
    var impliedStateIDs: Set<String> {
        var out = Set<String>()
        for (def, _) in activeStates { out.formUnion(def.implies) }
        return out
    }

    var isHandlungsunfaehig: Bool {
        if hasState("handlungsunfaehig") || impliedStateIDs.contains("handlungsunfaehig") { return true }
        if totalZustandLevels >= 8 { return true }
        // Any Zustand at its handlungsunfaehig level (most level IV).
        return activeStates.contains { $0.def.handlungsunfaehigAtLevel.map { lvl in $0.level >= lvl } ?? false }
    }

    var isBewegungsunfaehig: Bool {
        if hasState("bewegungsunfaehig") || impliedStateIDs.contains("bewegungsunfaehig") { return true }
        return level(of: "paralyse") >= 4
    }
```

> Note: confirm `modelContext` is available on `Hero` (SwiftData injects it on inserted models). If `modelContext?.delete` causes issues in tests, removing from the array is sufficient for cascade cleanup — verify against the test.

**Step 5: Register model** in `HesindionApp.swift` — add `HeroStateEntry.self` to the `Schema`/`ModelContainer(for:)` list alongside `Hero.self`. Also add it to the in-memory container list in the test helper and any other test that builds a container (grep: `ModelContainer(for:`).

**Step 6: Run to verify pass** — `make test 2>&1 | grep -E "HeroStateTests|StateCatalogTests"` → all pass; full `make test` shows no *new* failures beyond the 3 baseline.

**Step 7: Commit**

```bash
git add Hesindion/Models/HeroStateEntry.swift Hesindion/Models/Hero.swift Hesindion/HesindionApp.swift HesindionTests/HeroStateTests.swift
git commit -m "feat: persist player states on Hero via HeroStateEntry"
```

---

## Task 2: StateModifiers engine group + −5 Zustand cap

**Files:**
- Create: `Hesindion/Engine/StateModifiers.swift`
- Modify: `Hesindion/Engine/SharedModifiers.swift` (remove `pain`; keep `encumbrance`)
- Modify: `Hesindion/Engine/ModifierEngine.swift` (register StateModifiers; apply cap in `evaluate`; tag lines)
- Modify: `Hesindion/Models/CombatManeuver.swift` (add category flag to `ModifierLine`)
- Test: `HesindionTests/StateModifiersTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
import SwiftData
@testable import Hesindion

final class StateModifiersTests: XCTestCase {
    private func makeHero() -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Hero.self, HeroStateEntry.self, configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        return hero
    }

    func testFurchtPenaltyAppliesToTalentChecks() {
        let hero = makeHero(); hero.setStateLevel("furcht", level: 2)
        let lines = ModifierEngine.shared.evaluate(context: ModifierContext(hero: hero, domain: .talentCheck))
        XCTAssertTrue(lines.contains { $0.value == -2 })
    }

    func testZustaendeStackAdditively() {
        let hero = makeHero()
        hero.setStateLevel("furcht", level: 1)
        hero.setStateLevel("verwirrung", level: 2)
        let total = ModifierEngine.shared.totalModifier(context: ModifierContext(hero: hero, domain: .talentCheck))
        XCTAssertEqual(total, -3)
    }

    func testZustandPenaltyCappedAtMinusFive() {
        let hero = makeHero()
        hero.setStateLevel("furcht", level: 4)
        hero.setStateLevel("verwirrung", level: 4)   // raw -8
        let total = ModifierEngine.shared.totalModifier(context: ModifierContext(hero: hero, domain: .talentCheck))
        XCTAssertEqual(total, -5, "Zustand penalties cap at -5")
    }

    func testCapDoesNotClampNonZustandModifiers() {
        // A combat bonus (e.g. schip defense +4) must survive alongside capped zustände.
        let hero = makeHero()
        hero.setStateLevel("furcht", level: 4)
        hero.setStateLevel("verwirrung", level: 4)
        var ctx = ModifierContext(hero: hero, domain: .meleeDodge)
        ctx.schipDefenseBoost = true
        let total = ModifierEngine.shared.totalModifier(context: ctx)
        XCTAssertEqual(total, -5 + 4)
    }

    func testSchipIgnoreZustandRemovesPenalty() {
        let hero = makeHero(); hero.setStateLevel("furcht", level: 3)
        var ctx = ModifierContext(hero: hero, domain: .talentCheck)
        ctx.schipIgnoreZustand = true
        XCTAssertEqual(ModifierEngine.shared.totalModifier(context: ctx), 0)
    }

    func testLiegendOnlyAffectsCombatDomains() {
        let hero = makeHero(); hero.setStateLevel("liegend", level: 1)
        let talent = ModifierEngine.shared.totalModifier(context: ModifierContext(hero: hero, domain: .talentCheck))
        let attack = ModifierEngine.shared.totalModifier(context: ModifierContext(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(talent, 0)
        XCTAssertEqual(attack, -4)
    }

    func testSchmerzStillAppliesViaCatalogPath() {
        let hero = makeHero()
        // Drive Schmerz via LP — set derived values so effectiveSchmerzLevel == 2, then assert -2.
        // (Use existing DerivedValues test helpers; assert hero.schmerzPenalty == -2 first.)
    }
}
```

**Step 2: Run to verify it fails.**

**Step 3: Add category to `ModifierLine`** (`CombatManeuver.swift:120`):

```swift
struct ModifierLine: Identifiable {
    let id = UUID()
    let value: Int
    let source: String
    var isZustand: Bool = false
}
```

**Step 4: Implement `StateModifiers.swift`**

```swift
import Foundation

enum StateModifiers {
    static let all: [ModifierDefinition] = [statePenalties]

    /// Emits one zustand-tagged line per active penalty-mechanic state applicable to the domain.
    /// NOTE: returns a single combined definition is not possible (ModifierDefinition returns one
    /// line); instead we register one definition per catalog penalty-state, built dynamically.
    static let statePenalties = ModifierDefinition(
        id: "statePenaltiesPlaceholder",
        domains: Set(CheckDomain.allCases)
    ) { _ in nil }   // replaced by `definitions` below — see ModifierEngine wiring
}
```

> **Design refinement:** `ModifierDefinition.evaluate` returns a single `ModifierLine?`, so generate one definition per penalty/eingeengt/entrueckung catalog state. Replace the placeholder with a computed array:

```swift
enum StateModifiers {
    static var all: [ModifierDefinition] { penaltyDefinitions + [entrueckungDef] }

    /// One definition per catalog state whose mechanic is `.penalty`.
    static let penaltyDefinitions: [ModifierDefinition] = StateCatalog.all.compactMap { def in
        guard case .penalty(let domains) = def.mechanic else { return nil }
        return ModifierDefinition(id: "state.\(def.id)", domains: domains) { ctx in
            guard !ctx.schipIgnoreZustand else { return nil }
            let level = ctx.hero.level(of: def.id)
            guard level > 0 else { return nil }
            let isZustand = def.kind == .zustand
            // Status (Liegend −4 attack/−2 defense, Fixiert −4 dodge) use fixed values.
            let value = Self.penaltyValue(for: def, level: level, domain: ctx.domain)
            guard value != 0 else { return nil }
            let roman = isZustand ? " " + String(repeating: "I", count: min(level, 4)) : ""
            return ModifierLine(value: value, source: L(def.nameKey) + roman, isZustand: isZustand)
        }
    }

    static func penaltyValue(for def: StateDefinition, level: Int, domain: CheckDomain) -> Int {
        switch def.id {
        case "liegend": return domain == .meleeAttack ? -4 : -2   // parry/dodge -2
        case "fixiert": return -4                                  // dodge only (domain already filtered)
        default: return -level                                     // zustände: -Stufe
        }
    }

    /// Entrückung: gottgefällige Proben + (level−1 with floor), all others −level.
    static let entrueckungDef = ModifierDefinition(
        id: "state.entrueckung", domains: Set(CheckDomain.allCases)
    ) { ctx in
        guard !ctx.schipIgnoreZustand else { return nil }
        let level = ctx.hero.level(of: "entrueckung")
        guard level > 0 else { return nil }
        let value = ctx.gottgefaellig ? max(0, level - 1) : -level
        guard value != 0 else { return nil }
        let roman = " " + String(repeating: "I", count: min(level, 4))
        return ModifierLine(value: value, source: L("state.entrueckung.name") + roman, isZustand: true)
    }
}
```

Add `var gottgefaellig: Bool = false` to `ModifierContext` (ModifierEngine.swift:36).

**Step 5: Migrate Schmerz / wire cap in `ModifierEngine.swift`**

- Remove `pain` from `SharedModifiers.all` (leaving `[encumbrance]`). Schmerz is now covered by `StateModifiers.penaltyDefinitions` because the catalog `schmerz` entry has `.penalty` mechanic and `hero.level(of: "schmerz")` returns `effectiveSchmerzLevel`. Keep the exact same source label & roman numerals (verify `source.schmerz` string unchanged).
- Register `StateModifiers.all` in `ModifierEngine.shared` (ModifierEngine.swift:103):

```swift
defs.append(contentsOf: SharedModifiers.all)
defs.append(contentsOf: StateModifiers.all)
defs.append(contentsOf: MeleeModifiers.all)
// …
```

- Apply the cap in `evaluate`:

```swift
func evaluate(context: ModifierContext) -> [ModifierLine] {
    let lines = modifiers
        .filter { $0.domains.contains(context.domain) }
        .compactMap { $0.evaluate(context) }
    return Self.applyingZustandCap(lines)
}

/// GR: combined Zustand penalty is capped at −5. Encumbrance counts as a Zustand for the cap.
static func applyingZustandCap(_ lines: [ModifierLine]) -> [ModifierLine] {
    let zustandPenalty = lines.filter { $0.isZustand }.reduce(0) { $0 + min(0, $1.value) }
    guard zustandPenalty < -5 else { return lines }
    let correction = -5 - zustandPenalty   // positive
    return lines + [ModifierLine(value: correction, source: L("source.zustandCap"), isZustand: false)]
}
```

> Tag the existing `encumbrance` line as `isZustand: true` (SharedModifiers.swift:12) so it counts toward the cap, per the design.

**Step 6: Run to verify pass** — `make test 2>&1 | grep StateModifiersTests` → pass. Full suite: no new failures.

**Step 7: Commit**

```bash
git add Hesindion/Engine/StateModifiers.swift Hesindion/Engine/SharedModifiers.swift Hesindion/Engine/ModifierEngine.swift Hesindion/Models/CombatManeuver.swift HesindionTests/StateModifiersTests.swift
git commit -m "feat: feed player states into ModifierEngine with -5 Zustand cap"
```

---

## Task 3: Localization strings

**Files:**
- Modify: `Hesindion/Theme/Strings.swift` (add keys to the `DSAStrings.localized` map)
- Test: `HesindionTests/StateLocalizationTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import Hesindion

final class StateLocalizationTests: XCTestCase {
    func testEveryCatalogKeyResolves() {
        for def in StateCatalog.all {
            assertResolves(def.nameKey)
            assertResolves(def.causeKey)
            assertResolves(def.removalKey)
            for k in def.levelEffectKeys { assertResolves(k) }
        }
        assertResolves("source.zustandCap")
        assertResolves("states.section")
        assertResolves("states.add")
        assertResolves("states.remove")
        assertResolves("states.handlungsunfaehig.banner")
        assertResolves("states.bewegungsunfaehig.banner")
        assertResolves("states.gottgefaellig")
    }

    private func assertResolves(_ key: String) {
        XCTAssertNotEqual(L(key), key, "string key not localized: \(key)")
    }
}
```

> This assumes `L(key)` returns the key itself when missing. Verify `DSAStrings.localized` behavior (Strings.swift:940); if it returns something else for missing keys, adjust the assertion accordingly.

**Step 2: Run to verify it fails.**

**Step 3: Add all keys** to the map in `Strings.swift`. Use the verified rules text (German). Examples (fill in all 25 states):

```swift
"states.section":                 "Zustände & Status",
"states.add":                     "Zustand hinzufügen",
"states.remove":                  "Entfernen",
"states.handlungsunfaehig.banner":"Handlungsunfähig",
"states.bewegungsunfaehig.banner":"Bewegungsunfähig",
"states.gottgefaellig":           "Gottgefällige Probe",
"source.zustandCap":              "Zustände max. −5",

"state.furcht.name":  "Furcht",
"state.furcht.I":     "beunruhigt, alle Proben −1",
"state.furcht.II":    "verängstigt, alle Proben −2",
"state.furcht.III":   "in Panik, alle Proben −3",
"state.furcht.IV":    "katatonisch, handlungsunfähig",
"state.furcht.cause": "Grauenerregende Kreaturen, Zauber oder der Nachteil Angst vor …",
"state.furcht.removal":"Solange der Auslöser in der Nähe ist, bleibt die Furcht. Danach 1 Stufe je 5 Minuten.",
// … betaeubung, paralyse, verwirrung, berauscht, entrueckung, schmerz, belastung
// … liegend, fixiert, eingeengt, blutend, brennend, blind, taub, stumm,
//     ueberrascht, unsichtbar, vergiftet, krank, uebler_geruch,
//     bewegungsunfaehig, handlungsunfaehig, bewusstlos, versteinert
```

> Use the verified per-level text from the design doc / research for each state. Liegend effect: "GS 1, eigene Angriffe −4, Verteidigung −2; Aufstehen kostet 1 Aktion (Passierschlag möglich)". Blutend: "1 SP am Ende jeder KR". Brennend: "Feuerschaden je KR; löschen mit Körperbeherrschung-Probe". Etc.

**Step 4: Run to verify pass** — `make test 2>&1 | grep StateLocalizationTests` → pass.

**Step 5: Commit**

```bash
git add Hesindion/Theme/Strings.swift HesindionTests/StateLocalizationTests.swift
git commit -m "feat: localize player state names, effects, causes and removal"
```

---

## Task 4: Hero detail — "Zustände & Status" section + add picker

**Files:**
- Create: `Hesindion/Views/StatesSectionView.swift` (chips + add button)
- Create: `Hesindion/Views/StatePickerSheet.swift` (grouped Zustände/Status picker with search)
- Create: `Hesindion/Views/StateChip.swift` (reusable neo-brutalist chip)
- Modify: `Hesindion/Views/HeroDetailView.swift` (insert section after Derived Values)
- Test: `HesindionTests/Snapshots/StatesSectionSnapshotTests.swift`

**Step 1–2:** Write a snapshot test rendering `StatesSectionView` for a hero with Furcht II + Liegend; run with `SNAPSHOT_TESTING_RECORD=0` to confirm it fails (no reference yet).

**Step 3: Implement views.**
- `StateChip`: icon + name (+ roman level + penalty for penalty-mechanic zustände), `Color.dsaBorder` rect, group color background; tappable + long-press.
- `StatesSectionView`: `FlowLayout`/wrapping `HStack` of chips from `hero.activeStates`, plus a "+" chip opening `StatePickerSheet`. Derived/implied states render visually distinct (e.g. dashed border, not removable).
- `StatePickerSheet`: `List` with two sections (Zustände, Status) from `StateCatalog.manuallyAddable`, searchable; tapping a Zustand opens a level stepper, a Status toggles on. Writes via `hero.setStateLevel`.

**Step 4: Wire into `HeroDetailView`** — add the section in the main `LazyVStack` after Derived Values; match existing section-header pattern.

**Step 5: Record snapshot** — `make test-ui-record 2>&1 | grep StatesSection`, then run `make test-ui` to confirm pass. Visually inspect the recorded PNG before committing.

**Step 6: Commit.**

---

## Task 5: State detail sheet + removal UX

**Files:**
- Create: `Hesindion/Views/StateDetailSheet.swift`
- Modify: `StatesSectionView.swift` (present sheet on chip tap; long-press = decrement/remove)
- Test: `HesindionTests/Snapshots/StateDetailSheetSnapshotTests.swift`

**Spec:**
- Header: icon + name + current level (roman).
- Level stepper I–IV for Zustände (writes `hero.setStateLevel`); Status shows on/off.
- Effect table: all levels listed, **current level highlighted** (group accent).
- Cause text, then **removal/decay rule prominently** (boxed callout — this was an explicit user requirement).
- "Entfernen" button (`hero.setStateLevel(id, level: 0)`), destructive style.
- Long-press chip in section = quick decrement (Zustand) or remove (Status).
- Derived states (Schmerz/Belastung) open a read-only variant explaining they change automatically (no stepper/remove).

TDD: snapshot the sheet for Furcht III and for Schmerz (read-only). Record, verify, commit.

---

## Task 6: Combat root — chips, warning banner, per-round reminders

**Files:**
- Modify: `Hesindion/Views/CombatRootView.swift` (STATUS section ~line 176–214)
- Possibly extract a shared `StatesStrip` view used by both detail and combat.
- Test: update `HesindionTests/Snapshots/CombatRootViewSnapshotTests.swift` (already failing on baseline — re-record intentionally).

**Spec:**
- Replace the single Schmerz badge with the full active-states strip (reuse `StateChip`); states addable mid-combat via the same picker.
- **Warning banner** when `hero.isHandlungsunfaehig` ("Handlungsunfähig") or `hero.isBewegungsunfaehig` ("Bewegungsunfähig") — full-width, high-contrast `Color.groupCombat`.
- Per-round reminder line for states with timed effects (e.g. Blutend "1 SP am Ende jeder KR", Brennend "Feuerschaden je KR").
- **Make the existing Beengte-Umgebung toggle read/write the `eingeengt` status** so it shows in the strip and persists like other states (the toggle becomes a shortcut). Confirm the combat weapon-length penalty still fires (it reads `ctx.beengteUmgebung`; set that from `hero.hasState("eingeengt")` where the context is built — CombatAttackViews.swift:566, DefenseModifiers `beengteUmgebungPA`, CombatRootView.swift:28).

TDD: re-record `testMidCombat` (now intentionally changed) plus a new `testMidCombatHandlungsunfaehig`. Confirm the baseline-failing list does not grow beyond intentional re-records. Commit.

---

## Task 7: Entrückung gottgefällig toggle in spell/liturgy checks

**Files:**
- Modify: `Hesindion/Views/CombatSpellViews.swift` (and `TalentProbeModal.swift` if liturgy/spell talent checks route through it) — set `ctx.gottgefaellig` from a toggle shown only when `hero.hasState("entrueckung")`.
- Test: extend `StateModifiersTests` — `testEntrueckungGottgefaelligFlipsSign`.

**Spec:** When the caster has Entrückung active, show a "Gottgefällige Probe" toggle in the spell/liturgy casting UI. Off → penalty `−level` (default, safe); on → bonus `max(0, level−1)`. Build the `ModifierContext` with `gottgefaellig` from that toggle (CombatSpellViews.swift:129).

TDD first (engine test), then UI toggle. Commit.

---

## Task 8: Docs — CHANGELOG, ADR, design follow-ups

**Files:**
- Modify: `CHANGELOG.md` (`[Unreleased]` → Added: player states feature summary)
- Create: `docs/adr/0003-player-states-catalog.md` (decision: static catalog + generic `HeroStateEntry` over per-state Hero properties; note SwiftData additive migration)
- Update: `AGENTS.md` Architecture section — one line pointing to the states system, mirroring the Combat System bullets.

Use the next free ADR number (verify with `ls docs/adr/`). Follow `docs/adr/0000-template.md`.

Commit.

---

## Task 9: Full verification pass

**Steps:**
1. Run `make test` — confirm all new unit tests pass and only the 3 pre-existing baseline snapshots (minus any intentionally re-recorded) differ. Capture output.
2. `make run` (or `make debug-combat`) — manually add Furcht II + Liegend to a sample hero, open a talent check and an AT roll, confirm the modifier lines and −5 cap display correctly, confirm the Handlungsunfähig banner at level IV. Use the `verify` skill.
3. Review the diff with the `superpowers-extended-cc:requesting-code-review` skill before opening the PR.
4. Confirm `CHANGELOG.md`, ADR, and `AGENTS.md` are current.

Final commit (if review changes), then surface PR option to the user.
