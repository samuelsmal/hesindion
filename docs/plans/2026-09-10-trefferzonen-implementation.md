# Trefferzonen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the DSA 5 Fokus-Trefferzonenregeln in the SwiftUI app, and fix the three derived-value rounding bugs the spec work uncovered.

**Architecture:** Three pure-value rules files (`HitZone`, `HitZoneTable`, `WoundEffect`) with no SwiftUI or SwiftData, following the `FumbleTable` pattern. Offence wires a zone picker into the existing `ModifierEngine` as one more `ModifierDefinition`; defence extends `CombatTakeDamageView` to compare damage against the hero's Wundschwelle and apply wound effects through `Hero.setStateLevel`. Everything sits behind a per-combat toggle that is off by default. Prerequisite tasks fix and repair the derived values the defence side reads.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData, XCTest, swift-snapshot-testing, `make test` / `make test-ui`.

**Spec:** `specs/011_trefferzonen/requirement.md`
**Audit:** `docs/plans/2026-09-10-derived-value-rounding-audit.md`

**User decisions (already made):**
- Target the SwiftUI app on `main`, not the Flutter rewrite. "SwiftUI (main)"
- Automation is asymmetric: "full on defence, modifier + reminder on offence" — no opponent is modelled.
- Ship all eight zone tables: "All tables incl. exotic forms".
- Zone on defence is determined "Both — roll or tap".
- Rounding convention: "in general: round up / ceil ... if not otherwise clearly specified".
- "on the raceId persistence: let's persist it from now on, so the next import gets it."
- Fix stale stored values with a recompute-on-launch pass, not a schema migration.

**Note on native tasks:** `TaskCreate`/`TaskList` are unavailable in this environment. Task state lives in `docs/plans/2026-09-10-trefferzonen-implementation.md.tasks.json` beside this file.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `Hesindion/Engine/DerivedValueFormulas.swift` | **new** — the only definition of WS/AW/INI. Shared by import and repair |
| `Hesindion/Services/DerivedValueRepair.swift` | **new** — idempotent launch-time repair of stored derived values |
| `Hesindion/Models/HitZone.swift` | **new** — `HitZone`, `BodySide`, `HitZoneHit` |
| `Hesindion/Models/HitZoneTable.swift` | **new** — `BodyPlan`, `CreatureSize`, the ten 1W20 tables, `lookup` |
| `Hesindion/Models/WoundEffect.swift` | **new** — per-zone effect kind + resistance keys |
| `Hesindion/Engine/HitZoneModifiers.swift` | **new** — Zonenaufschlag as a `ModifierDefinition` |
| `Hesindion/Views/CombatZonePicker.swift` | **new** — the zone-chip row, shared by melee, ranged and damage screens |
| `Hesindion/Services/OptolithImportService.swift` | modify — use the shared formulas; persist `speciesId` |
| `Hesindion/Models/PersonalData.swift` | modify — add `speciesId` |
| `Hesindion/Models/FokusRule.swift` | **new** — the catalog of optional Fokus-Regeln |
| `Hesindion/Models/Hero.swift` | modify — add `activeCombatFokusRules` + helpers, clear it in `clearCombatSession` |
| `Hesindion/ContentView.swift` | modify — run the repair pass once at launch |
| `Hesindion/Views/CombatSetupViews.swift` | modify — the activation toggle |
| `Hesindion/Views/CombatAttackViews.swift` | modify — zone picker in `announcement` |
| `Hesindion/Views/CombatFernkampfViews.swift` | modify — zone picker in `fernkampfSetup` |
| `Hesindion/Views/CombatDamageViews.swift` | modify — zone row, Wundeffekt panel, reminder card |
| `Hesindion/Theme/Strings.swift` | modify — all new `L()` keys, de + en |

`CombatDamageViews.swift` is already 709 lines. Task 11 extracts the Wundeffekt panel into its own view struct inside that file rather than growing the existing one further; if it passes ~900 lines after Task 11, split `CombatWoundEffectViews.swift` out.

---

## Task 0: Shared derived-value formulas with round-up

**Goal:** One definition of Wundschwelle, Ausweichen and Initiative that rounds up and applies Eisern/Gläsern, used by the import path.

**Files:**
- Create: `Hesindion/Engine/DerivedValueFormulas.swift`
- Modify: `Hesindion/Services/OptolithImportService.swift:876-889`
- Test: `HesindionTests/DerivedValueFormulasTests.swift`

**Acceptance Criteria:**
- [ ] `wundschwelle(ko: 11, ...)` returns base `6`, matching the Regelwiki example
- [ ] Eisern gives `+1`, Gläsern `-1`, both together `0`
- [ ] `ausweichen(ge: 13)` is `7`; `initiative(mu: 12, ge: 13)` is `13`
- [ ] `computeDerivedValues` calls the shared formulas and no longer contains `/ 2` for these three

**Verify:** `make test` → `DerivedValueFormulasTests` all pass

**Steps:**

- [ ] **Step 1: Write the failing tests**

```swift
// HesindionTests/DerivedValueFormulasTests.swift
import XCTest
@testable import Hesindion

final class DerivedValueFormulasTests: XCTestCase {

    private func trait(_ id: String) -> HeroTrait { HeroTrait(ruleId: id, name: id, tier: nil, sid: nil) }

    // The Regelwiki's own worked example: KO 11 → Wundschwelle 6.
    func testWundschwelleRoundsUp() {
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 11, advantages: [], disadvantages: []).base, 6)
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 12, advantages: [], disadvantages: []).base, 6)
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 13, advantages: [], disadvantages: []).base, 7)
    }

    func testEisernAndGlaesern() {
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 12, advantages: [trait("ADV_54")], disadvantages: []).bonus, 1)
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 12, advantages: [], disadvantages: [trait("DISADV_56")]).bonus, -1)
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 12, advantages: [trait("ADV_54")], disadvantages: [trait("DISADV_56")]).bonus, 0)
    }

    // Untiered in rules.db (max: 1) — duplicates must not stack.
    func testEisernDoesNotStack() {
        let two = [trait("ADV_54"), trait("ADV_54")]
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 12, advantages: two, disadvantages: []).bonus, 1)
    }

    func testAusweichenRoundsUp() {
        XCTAssertEqual(DerivedValueFormulas.ausweichen(ge: 12), 6)
        XCTAssertEqual(DerivedValueFormulas.ausweichen(ge: 13), 7)
    }

    func testInitiativeRoundsUp() {
        XCTAssertEqual(DerivedValueFormulas.initiative(mu: 12, ge: 12), 12)
        XCTAssertEqual(DerivedValueFormulas.initiative(mu: 12, ge: 13), 13)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test`
Expected: FAIL — "cannot find 'DerivedValueFormulas' in scope"

- [ ] **Step 3: Write the implementation**

```swift
// Hesindion/Engine/DerivedValueFormulas.swift
import Foundation

/// Single source of truth for the attribute-only DSA 5 derived values.
///
/// Project convention (ADR-0006): where a calculation yields a fraction and the rules
/// do not clearly say otherwise, round **up**. Both the import path
/// (`OptolithImportService`) and the launch repair (`DerivedValueRepair`) call these,
/// so the two can never drift apart.
enum DerivedValueFormulas {

    /// Wundschwelle = ceil(KO / 2), modified by Eisern (ADV_54, +1) and Gläsern (DISADV_56, −1).
    ///
    /// Both traits are `max: 1` and untiered in the ruleset, so they apply once regardless
    /// of how often they appear on the hero.
    static func wundschwelle(
        ko: Int,
        advantages: [HeroTrait],
        disadvantages: [HeroTrait]
    ) -> (base: Int, bonus: Int) {
        let base = Int(ceil(Double(ko) / 2.0))
        var bonus = 0
        if advantages.contains(where: { $0.ruleId == "ADV_54" }) { bonus += 1 }
        if disadvantages.contains(where: { $0.ruleId == "DISADV_56" }) { bonus -= 1 }
        return (base, bonus)
    }

    /// Ausweichen = ceil(GE / 2).
    static func ausweichen(ge: Int) -> Int {
        Int(ceil(Double(ge) / 2.0))
    }

    /// Initiative = ceil((MU + GE) / 2).
    static func initiative(mu: Int, ge: Int) -> Int {
        Int(ceil(Double(mu + ge) / 2.0))
    }
}
```

- [ ] **Step 4: Rewire the import path**

In `Hesindion/Services/OptolithImportService.swift`, `computeDerivedValues` takes `advantages: [HeroTrait]` but not disadvantages. Add the parameter to the signature at line 817 and pass `disadvantages` at the call sites (lines 138, 186, 249 pass the hero's parsed trait arrays — mirror how `advantages` is already threaded).

Replace lines 876-889:

```swift
        // INI = ceil((MU + GE) / 2)
        let iniValue = DerivedValueFormulas.initiative(mu: mu, ge: ge)
        let initiative = ComputedValue(value: iniValue, bonus: 0, max: iniValue)

        // AW = ceil(GE / 2)
        let awValue = DerivedValueFormulas.ausweichen(ge: ge)
        let ausweichen = ComputedValue(value: awValue, bonus: 0, max: awValue)

        // GS = 8 (Mensch base)
        let geschwindigkeit = ResourceValue(base: 8, bonus: 0, max: 8)

        // WS = ceil(KO / 2), ± Eisern / Gläsern
        let ws = DerivedValueFormulas.wundschwelle(ko: ko, advantages: advantages, disadvantages: disadvantages)
        let wundschwelle = ComputedValue(value: ws.base, bonus: ws.bonus, max: ws.base + ws.bonus)
```

- [ ] **Step 5: Run tests**

Run: `make test`
Expected: PASS — all `DerivedValueFormulasTests`, and no existing test regresses

- [ ] **Step 6: Commit**

```bash
git add Hesindion/Engine/DerivedValueFormulas.swift Hesindion/Services/OptolithImportService.swift HesindionTests/DerivedValueFormulasTests.swift
git commit -m "fix(rules): round Wundschwelle, Ausweichen and Initiative up

All three truncated via integer division while SK and ZK in the same
function already used ceil. DSA 5 rounds derived values up — the
Regelwiki's Trefferzonen example (KO 11 → Wundschwelle 6) yielded 5.

Also applies Eisern (ADV_54) and Gläsern (DISADV_56), which were never
looked up; wundschwelle's bonus was hardcoded to 0."
```

---

## Task 1: Persist the Optolith raceId

**Goal:** Stop discarding `raceId` at import so species-dependent values become recomputable later.

**Files:**
- Modify: `Hesindion/Models/PersonalData.swift:12`
- Modify: `Hesindion/Services/OptolithImportService.swift:328-353`
- Test: `HesindionTests/OptolithImportTests.swift` (extend; create if absent)

**Acceptance Criteria:**
- [ ] `PersonalData.speciesId` is `String?`, defaults to `nil`, and needs no migration stage
- [ ] A hero imported from a fixture with `"r": "R_2"` has `speciesId == "R_2"` and `species == "Elfen"`
- [ ] An existing hero constructed without the field reads `nil` rather than crashing

**Verify:** `make test` → import tests pass

**Steps:**

- [ ] **Step 1: Write the failing test**

```swift
func testImportPersistsRaceId() throws {
    let hero = try importFixture(named: "sample_hero")   // fixture has "r": "R_1"
    XCTAssertEqual(hero.personalData?.speciesId, "R_1")
    XCTAssertEqual(hero.personalData?.species, "Menschen")
}

func testSpeciesIdDefaultsToNil() {
    let pd = PersonalData(
        name: "T", family: "", birthplace: "", birthdate: "", age: 0, gender: "",
        species: "Menschen", height: 0, weight: 0, hairColor: "", eyeColor: "",
        culture: "", socialStatus: "", profession: "", title: "", characteristics: ""
    )
    XCTAssertNil(pd.speciesId)
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test`
Expected: FAIL — "value of type 'PersonalData' has no member 'speciesId'"

- [ ] **Step 3: Add the property**

In `Hesindion/Models/PersonalData.swift`, beside `var species: String`:

```swift
    var species: String
    /// Optolith race id (`R_1` = Menschen, `R_2` = Elfen, …). Optional because heroes
    /// imported before this field existed never captured it; `nil` is the normal case
    /// for them, not an error.
    var speciesId: String?
```

Add it to the initialiser with a default so existing call sites keep compiling:

```swift
    init(
        name: String,
        ...
        species: String,
        speciesId: String? = nil,
        ...
    )
```

- [ ] **Step 4: Populate it at import**

In `parsePersonalData` (`OptolithImportService.swift:328`), which already receives `raceId: String`, pass it through at the `PersonalData(...)` construction near line 353:

```swift
            species: species,
            speciesId: raceId.isEmpty ? nil : raceId,
```

- [ ] **Step 5: Run tests**

Run: `make test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Hesindion/Models/PersonalData.swift Hesindion/Services/OptolithImportService.swift HesindionTests/OptolithImportTests.swift
git commit -m "feat(import): persist the Optolith raceId as PersonalData.speciesId

raceId was parsed and used to look up species base values, then dropped
in favour of the display name. Keeping it makes species-dependent
derived values recomputable, and makes the R_1-R_4-only species tables
(everything else silently falls back to human) detectable."
```

---

## Task 2: DerivedValueRepair + launch hook

**Goal:** Correct stored WS/AW/INI on already-imported heroes, once per launch, idempotently.

**Files:**
- Create: `Hesindion/Services/DerivedValueRepair.swift`
- Modify: `Hesindion/ContentView.swift:11-15`
- Test: `HesindionTests/DerivedValueRepairTests.swift`

**Acceptance Criteria:**
- [ ] A hero stored with truncated values has all three corrected and `repair` returns `true`
- [ ] An already-correct hero is untouched and `repair` returns `false`
- [ ] A second run is a no-op (idempotent)
- [ ] `lebensenergie`, `seelenkraft` and `zaehigkeit` are never written
- [ ] A hero with `speciesId == nil` repairs normally

**Verify:** `make test` → `DerivedValueRepairTests` all pass

**Steps:**

- [ ] **Step 1: Write the failing tests**

```swift
// HesindionTests/DerivedValueRepairTests.swift
import XCTest
import SwiftData
@testable import Hesindion

final class DerivedValueRepairTests: XCTestCase {

    /// Hero with KO 11, GE 13, MU 12 and the OLD truncated values stored.
    private func makeStaleHero() -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self, Attributes.self,
            configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T")
        hero.attributes = Attributes(mu: 12, kl: 10, inValue: 10, ch: 10, ff: 10, ge: 13, ko: 11, kk: 10)
        hero.derivedValues = DerivedValues(
            lebensenergie: LifeEnergyValue(base: 27, bonus: 0, purchased: 0, max: 27, current: 27),
            astralenergie: nil, karmaenergie: nil,
            seelenkraft: ResourceValue(base: 1, bonus: 0, max: 1),
            zaehigkeit: ResourceValue(base: 1, bonus: 0, max: 1),
            ausweichen: ComputedValue(value: 6, bonus: 0, max: 6),      // stale: 13/2 = 6
            initiative: ComputedValue(value: 12, bonus: 0, max: 12),    // stale: 25/2 = 12
            geschwindigkeit: ResourceValue(base: 8, bonus: 0, max: 8),
            wundschwelle: ComputedValue(value: 5, bonus: 0, max: 5),    // stale: 11/2 = 5
            schicksalspunkte: MutableResourceValue(current: 3, bonus: 0, max: 3)
        )
        ctx.insert(hero)
        return hero
    }

    func testRepairCorrectsAllThree() {
        let hero = makeStaleHero()
        XCTAssertTrue(DerivedValueRepair.repair(hero))
        XCTAssertEqual(hero.derivedValues?.wundschwelle.max, 6)
        XCTAssertEqual(hero.derivedValues?.ausweichen.max, 7)
        XCTAssertEqual(hero.derivedValues?.initiative.max, 13)
    }

    func testRepairIsIdempotent() {
        let hero = makeStaleHero()
        XCTAssertTrue(DerivedValueRepair.repair(hero))
        XCTAssertFalse(DerivedValueRepair.repair(hero), "second run must report no change")
        XCTAssertEqual(hero.derivedValues?.wundschwelle.max, 6)
    }

    func testRepairLeavesLifeAndResourcesAlone() {
        let hero = makeStaleHero()
        let lpBefore = hero.derivedValues?.lebensenergie.max
        let skBefore = hero.derivedValues?.seelenkraft.max
        let zkBefore = hero.derivedValues?.zaehigkeit.max
        _ = DerivedValueRepair.repair(hero)
        XCTAssertEqual(hero.derivedValues?.lebensenergie.max, lpBefore)
        XCTAssertEqual(hero.derivedValues?.seelenkraft.max, skBefore)
        XCTAssertEqual(hero.derivedValues?.zaehigkeit.max, zkBefore)
    }

    func testHeroWithoutDerivedValuesIsSkipped() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Hero.self, HeroStateEntry.self, configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        XCTAssertFalse(DerivedValueRepair.repair(hero))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test`
Expected: FAIL — "cannot find 'DerivedValueRepair' in scope"

- [ ] **Step 3: Write the implementation**

```swift
// Hesindion/Services/DerivedValueRepair.swift
import Foundation
import SwiftData

/// Repairs stored derived values that were computed by an older, truncating formula.
///
/// `OptolithImportService.computeDerivedValues` runs only at import, so a formula fix
/// does not reach heroes already in the store. This pass corrects the three
/// attribute-only values in place at launch.
///
/// It deliberately does **not** touch Lebensenergie, Seelenkraft or Zähigkeit: none of
/// them is wrong, all three need the species base that existing heroes cannot supply,
/// and `lebensenergie.current` is live session state.
enum DerivedValueRepair {

    /// Recomputes Wundschwelle, Ausweichen and Initiative in place.
    /// - Returns: `true` if any value changed. Idempotent — a second call returns `false`.
    @discardableResult
    static func repair(_ hero: Hero) -> Bool {
        guard let attributes = hero.attributes, let dv = hero.derivedValues else { return false }

        var changed = false

        let ws = DerivedValueFormulas.wundschwelle(
            ko: attributes.ko,
            advantages: hero.advantages,
            disadvantages: hero.disadvantages
        )
        let wsExpected = ComputedValue(value: ws.base, bonus: ws.bonus, max: ws.base + ws.bonus)
        if dv.wundschwelle.value != wsExpected.value
            || dv.wundschwelle.bonus != wsExpected.bonus
            || dv.wundschwelle.max != wsExpected.max {
            dv.wundschwelle = wsExpected
            changed = true
        }

        let aw = DerivedValueFormulas.ausweichen(ge: attributes.ge)
        if dv.ausweichen.value != aw || dv.ausweichen.max != aw {
            dv.ausweichen = ComputedValue(value: aw, bonus: dv.ausweichen.bonus, max: aw)
            changed = true
        }

        let ini = DerivedValueFormulas.initiative(mu: attributes.mu, ge: attributes.ge)
        if dv.initiative.value != ini || dv.initiative.max != ini {
            dv.initiative = ComputedValue(value: ini, bonus: dv.initiative.bonus, max: ini)
            changed = true
        }

        return changed
    }

    /// Repairs every hero in the context. Saves only if something actually changed,
    /// so a clean launch performs no writes.
    static func repairAll(in context: ModelContext) {
        guard let heroes = try? context.fetch(FetchDescriptor<Hero>()) else { return }
        let repaired = heroes.reduce(into: 0) { count, hero in
            if repair(hero) { count += 1 }
        }
        guard repaired > 0 else { return }
        try? context.save()
        print("DerivedValueRepair: corrected \(repaired) hero(es)")
    }
}
```

- [ ] **Step 4: Hook it into launch**

Replace `Hesindion/ContentView.swift:11-15`:

```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var didRepair = false

    var body: some View {
        HeroListView()
            .task {
                guard !didRepair else { return }
                didRepair = true
                DerivedValueRepair.repairAll(in: modelContext)
            }
    }
}
```

- [ ] **Step 5: Run tests**

Run: `make test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Hesindion/Services/DerivedValueRepair.swift Hesindion/ContentView.swift HesindionTests/DerivedValueRepairTests.swift
git commit -m "feat: repair stale derived values at launch

computeDerivedValues runs only at import, so the rounding fix did not
reach heroes already in the store. Idempotent launch pass corrects
Wundschwelle, Ausweichen and Initiative, saving only when something
changed. LP/SK/ZK are left alone — none is wrong, and all three need a
species base existing heroes cannot supply."
```

---

## Task 3: HitZone and HitZoneTable

**Goal:** The ten 1W20 zone tables as pure values, with exhaustive coverage tests.

> **Amended after review.** Task 3 originally shipped eight tables; the source publishes ten. The
> Fangarme and `keineZonen` tables, plus two review findings (a silent `?? .torso` fallback and a
> `Range` struct shadowing `Swift.Range`), landed as a follow-up commit. The acceptance criteria
> below apply to all ten.

**Files:**
- Create: `Hesindion/Models/HitZone.swift`
- Create: `Hesindion/Models/HitZoneTable.swift`
- Test: `HesindionTests/HitZoneTableTests.swift`

**Acceptance Criteria:**
- [ ] For every `BodyPlan`, rolls 1…20 cover `Set(1...20)` exactly — no gaps, no overlaps
- [ ] Odd rolls yield `.links`, even `.rechts`, for paired zones; `nil` for Kopf/Torso/Schwanz
- [ ] `lookup(0, …)` and `lookup(21, …)` clamp instead of trapping
- [ ] `.sechsbeinigMitSchwanz(.klein)` falls back to the `.gross` table

**Verify:** `make test` → `HitZoneTableTests` all pass

**Steps:**

- [ ] **Step 1: Write the failing tests**

```swift
// HesindionTests/HitZoneTableTests.swift
import XCTest
@testable import Hesindion

final class HitZoneTableTests: XCTestCase {

    private static let allPlans: [BodyPlan] = [
        .humanoid(.klein), .humanoid(.mittel), .humanoid(.gross),
        .vierbeinig(.klein), .vierbeinig(.mittel), .vierbeinig(.gross),
        .sechsbeinigMitSchwanz(.gross), .sechsbeinigMitSchwanz(.riesig),
    ]

    /// The property that matters: every table is total over 1...20.
    func testEveryPlanCoversEveryRollExactlyOnce() {
        for plan in Self.allPlans {
            var covered = Set<Int>()
            for roll in 1...20 {
                _ = HitZoneTable.lookup(roll, plan: plan)   // must not trap
                covered.insert(roll)
            }
            XCTAssertEqual(covered, Set(1...20), "plan \(plan) has a gap")
        }
    }

    func testHumanoidMittelBoundaries() {
        let plan = BodyPlan.humanoid(.mittel)
        XCTAssertEqual(HitZoneTable.lookup(1, plan: plan).zone, .kopf)
        XCTAssertEqual(HitZoneTable.lookup(2, plan: plan).zone, .kopf)
        XCTAssertEqual(HitZoneTable.lookup(3, plan: plan).zone, .torso)
        XCTAssertEqual(HitZoneTable.lookup(12, plan: plan).zone, .torso)
        XCTAssertEqual(HitZoneTable.lookup(13, plan: plan).zone, .arme)
        XCTAssertEqual(HitZoneTable.lookup(16, plan: plan).zone, .arme)
        XCTAssertEqual(HitZoneTable.lookup(17, plan: plan).zone, .beine)
        XCTAssertEqual(HitZoneTable.lookup(20, plan: plan).zone, .beine)
    }

    func testSideParity() {
        let plan = BodyPlan.humanoid(.mittel)
        XCTAssertEqual(HitZoneTable.lookup(13, plan: plan).side, .links)   // odd
        XCTAssertEqual(HitZoneTable.lookup(16, plan: plan).side, .rechts)  // even
    }

    func testUnpairedZonesHaveNoSide() {
        let plan = BodyPlan.humanoid(.mittel)
        XCTAssertNil(HitZoneTable.lookup(1, plan: plan).side)   // Kopf
        XCTAssertNil(HitZoneTable.lookup(5, plan: plan).side)   // Torso
        XCTAssertNil(HitZoneTable.lookup(19, plan: .sechsbeinigMitSchwanz(.gross)).side)  // Schwanz
    }

    func testOutOfRangeRollsClamp() {
        let plan = BodyPlan.humanoid(.mittel)
        XCTAssertEqual(HitZoneTable.lookup(0, plan: plan).zone, HitZoneTable.lookup(1, plan: plan).zone)
        XCTAssertEqual(HitZoneTable.lookup(21, plan: plan).zone, HitZoneTable.lookup(20, plan: plan).zone)
    }

    func testUnlistedSizeFallsBackToNearest() {
        XCTAssertEqual(
            HitZoneTable.lookup(1, plan: .sechsbeinigMitSchwanz(.klein)).zone,
            HitZoneTable.lookup(1, plan: .sechsbeinigMitSchwanz(.gross)).zone
        )
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test`
Expected: FAIL — "cannot find 'HitZoneTable' in scope"

- [ ] **Step 3: Write HitZone.swift**

```swift
// Hesindion/Models/HitZone.swift
import Foundation

/// A body zone a hit can land in (DSA 5 Fokus-Trefferzonenregeln).
enum HitZone: String, CaseIterable, Identifiable {
    case kopf, torso, arme, beine
    case vordereBeine, mittlereGliedmassen, hintereBeine, schwanz

    var id: String { rawValue }

    /// L() key for the display name.
    var nameKey: String { "hitZone.\(rawValue)" }

    /// Zones that exist as a left/right pair, and therefore carry a `BodySide`.
    var isPaired: Bool {
        switch self {
        case .kopf, .torso, .schwanz: false
        default: true
        }
    }
}

enum BodySide: String {
    case links, rechts

    var nameKey: String { "bodySide.\(rawValue)" }
}

/// A resolved hit: the zone, plus the side for paired zones.
struct HitZoneHit: Equatable {
    let zone: HitZone
    /// `nil` for unpaired zones (Kopf, Torso, Schwanz).
    let side: BodySide?
}
```

- [ ] **Step 4: Write HitZoneTable.swift**

```swift
// Hesindion/Models/HitZoneTable.swift
import Foundation

enum CreatureSize { case klein, mittel, gross, riesig }

/// Body plans with a published Trefferzonen table.
enum BodyPlan: Equatable {
    case humanoid(CreatureSize)              // klein, mittel, gross
    case vierbeinig(CreatureSize)            // klein, mittel, gross
    case sechsbeinigMitSchwanz(CreatureSize) // gross, riesig
}

/// The DSA 5 Trefferzonen tables (Fokus-Regeln).
///
/// Static in-code tables, following `FumbleTable`. Odd rolls hit the left side,
/// even rolls the right; unpaired zones report no side.
enum HitZoneTable {

    /// One contiguous 1W20 range mapped to a zone.
    private struct Range {
        let lower: Int
        let upper: Int
        let zone: HitZone
    }

    /// Resolve a 1W20 roll against a body plan. Rolls outside 1...20 are clamped.
    static func lookup(_ roll: Int, plan: BodyPlan) -> HitZoneHit {
        let clamped = min(max(roll, 1), 20)
        let table = ranges(for: plan)
        let zone = table.first { clamped >= $0.lower && clamped <= $0.upper }?.zone ?? .torso
        let side: BodySide? = zone.isPaired ? (clamped.isMultiple(of: 2) ? .rechts : .links) : nil
        return HitZoneHit(zone: zone, side: side)
    }

    /// Unlisted size combinations fall back to the nearest published table
    /// (`.gross` for six-limbed, `.mittel` for the rest) rather than trapping.
    private static func ranges(for plan: BodyPlan) -> [Range] {
        switch plan {
        case .humanoid(.klein):   humanoidKlein
        case .humanoid(.gross), .humanoid(.riesig): humanoidGross
        case .humanoid:           humanoidMittel

        case .vierbeinig(.klein): vierbeinigKlein
        case .vierbeinig(.gross), .vierbeinig(.riesig): vierbeinigGross
        case .vierbeinig:         vierbeinigMittel

        case .sechsbeinigMitSchwanz(.riesig): sechsbeinigRiesig
        case .sechsbeinigMitSchwanz:          sechsbeinigGross
        }
    }

    // MARK: - Humanoid (Fokus-Regeln: Trefferzonen)

    private static let humanoidKlein: [Range] = [
        Range(lower: 1, upper: 6, zone: .kopf),
        Range(lower: 7, upper: 10, zone: .torso),
        Range(lower: 11, upper: 18, zone: .arme),
        Range(lower: 19, upper: 20, zone: .beine),
    ]

    private static let humanoidMittel: [Range] = [
        Range(lower: 1, upper: 2, zone: .kopf),
        Range(lower: 3, upper: 12, zone: .torso),
        Range(lower: 13, upper: 16, zone: .arme),
        Range(lower: 17, upper: 20, zone: .beine),
    ]

    private static let humanoidGross: [Range] = [
        Range(lower: 1, upper: 2, zone: .kopf),
        Range(lower: 3, upper: 6, zone: .torso),
        Range(lower: 7, upper: 16, zone: .arme),
        Range(lower: 17, upper: 20, zone: .beine),
    ]

    // MARK: - Vierbeinig

    private static let vierbeinigKlein: [Range] = [
        Range(lower: 1, upper: 4, zone: .kopf),
        Range(lower: 5, upper: 12, zone: .torso),
        Range(lower: 13, upper: 16, zone: .vordereBeine),
        Range(lower: 17, upper: 20, zone: .hintereBeine),
    ]

    private static let vierbeinigMittel: [Range] = [
        Range(lower: 1, upper: 4, zone: .kopf),
        Range(lower: 5, upper: 10, zone: .torso),
        Range(lower: 11, upper: 16, zone: .vordereBeine),
        Range(lower: 17, upper: 20, zone: .hintereBeine),
    ]

    private static let vierbeinigGross: [Range] = [
        Range(lower: 1, upper: 5, zone: .kopf),
        Range(lower: 6, upper: 11, zone: .torso),
        Range(lower: 12, upper: 16, zone: .vordereBeine),
        Range(lower: 17, upper: 20, zone: .hintereBeine),
    ]

    // MARK: - Sechsbeinig mit Schwanz

    private static let sechsbeinigGross: [Range] = [
        Range(lower: 1, upper: 4, zone: .kopf),
        Range(lower: 5, upper: 12, zone: .torso),
        Range(lower: 13, upper: 14, zone: .vordereBeine),
        Range(lower: 15, upper: 16, zone: .mittlereGliedmassen),
        Range(lower: 17, upper: 18, zone: .hintereBeine),
        Range(lower: 19, upper: 20, zone: .schwanz),
    ]

    private static let sechsbeinigRiesig: [Range] = [
        Range(lower: 1, upper: 2, zone: .kopf),
        Range(lower: 3, upper: 10, zone: .torso),
        Range(lower: 11, upper: 14, zone: .vordereBeine),
        Range(lower: 15, upper: 16, zone: .mittlereGliedmassen),
        Range(lower: 17, upper: 18, zone: .hintereBeine),
        Range(lower: 19, upper: 20, zone: .schwanz),
    ]
}
```

- [ ] **Step 5: Run tests**

Run: `make test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Hesindion/Models/HitZone.swift Hesindion/Models/HitZoneTable.swift HesindionTests/HitZoneTableTests.swift
git commit -m "feat(rules): DSA 5 Trefferzonen tables

Eight 1W20 tables (humanoid, vierbeinig and sechsbeinig mit Schwanz),
odd/even resolving left/right. Pure value types with no SwiftUI or
SwiftData, following the FumbleTable pattern."
```

---

## Task 4: WoundEffect catalog

**Goal:** Per-zone wound effect: what it does, and which Selbstbeherrschung application resists it.

**Files:**
- Create: `Hesindion/Models/WoundEffect.swift`
- Test: `HesindionTests/WoundEffectCatalogTests.swift`

**Acceptance Criteria:**
- [ ] Kopf raises `betaeubung`; Beine sets `liegend`; Torso is `1W3+1`; Arme is a reminder
- [ ] `vordereBeine` and `hintereBeine` behave as Beine; `mittlereGliedmassen` as Arme; `schwanz` is a reminder
- [ ] Every `HitZone` case returns an effect — no crash, no `nil`
- [ ] The state ids used exist in `StateCatalog`

**Verify:** `make test` → `WoundEffectCatalogTests` all pass

**Steps:**

- [ ] **Step 1: Write the failing tests**

```swift
// HesindionTests/WoundEffectCatalogTests.swift
import XCTest
@testable import Hesindion

final class WoundEffectCatalogTests: XCTestCase {

    func testEveryZoneHasAnEffect() {
        for zone in HitZone.allCases {
            XCTAssertEqual(WoundEffectCatalog.effect(for: zone).zone, zone)
        }
    }

    func testZoneEffects() {
        XCTAssertEqual(WoundEffectCatalog.effect(for: .kopf).kind, .raiseState(id: "betaeubung"))
        XCTAssertEqual(WoundEffectCatalog.effect(for: .beine).kind, .setStatus(id: "liegend"))
        XCTAssertEqual(WoundEffectCatalog.effect(for: .torso).kind, .extraDamage(count: 1, sides: 3, flat: 1))
        XCTAssertEqual(WoundEffectCatalog.effect(for: .arme).kind, .reminder)
    }

    func testLimbZonesMapToTheirAnalogue() {
        XCTAssertEqual(WoundEffectCatalog.effect(for: .vordereBeine).kind, .setStatus(id: "liegend"))
        XCTAssertEqual(WoundEffectCatalog.effect(for: .hintereBeine).kind, .setStatus(id: "liegend"))
        XCTAssertEqual(WoundEffectCatalog.effect(for: .mittlereGliedmassen).kind, .reminder)
        XCTAssertEqual(WoundEffectCatalog.effect(for: .schwanz).kind, .reminder)
    }

    /// The catalog must not name a state that StateCatalog does not define.
    func testReferencedStatesExist() {
        for zone in HitZone.allCases {
            switch WoundEffectCatalog.effect(for: zone).kind {
            case .raiseState(let id), .setStatus(let id):
                XCTAssertNotNil(StateCatalog.definition(for: id), "unknown state \(id)")
            case .extraDamage, .reminder:
                break
            }
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test`
Expected: FAIL — "cannot find 'WoundEffectCatalog' in scope"

- [ ] **Step 3: Write the implementation**

```swift
// Hesindion/Models/WoundEffect.swift
import Foundation

/// What a zone does when damage meets the Wundschwelle.
enum WoundEffectKind: Equatable {
    /// Raise a leveled Zustand by one step (Kopf → Betäubung).
    case raiseState(id: String)
    /// Set a binary Status (Beine → Liegend).
    case setStatus(id: String)
    /// Additional dice damage on top of the hit (Torso → 1W3+1 SP).
    case extraDamage(count: Int, sides: Int, flat: Int)
    /// No automatic math — show the text and offer an explicit action.
    case reminder
}

struct WoundEffect: Equatable {
    let zone: HitZone
    let kind: WoundEffectKind
    /// L() key for the effect description.
    let effectKey: String
    /// L() key naming the Selbstbeherrschung Anwendungsgebiet that resists it.
    let resistanceKey: String
}

/// Wundeffekte per zone (DSA 5 Fokus-Trefferzonenregeln).
///
/// The rules table names Kopf, Torso, Arme and Beine only. The extra limb zones on
/// non-humanoid plans reuse the closest analogue — front/rear legs behave as Beine,
/// mid-limbs as Arme (a manipulator, not a leg) — and Schwanz has no published effect.
enum WoundEffectCatalog {

    static func effect(for zone: HitZone) -> WoundEffect {
        switch zone {
        case .kopf:
            WoundEffect(zone: zone, kind: .raiseState(id: "betaeubung"),
                        effectKey: "woundEffect.kopf.effect",
                        resistanceKey: "woundEffect.resistance.handlungsfaehigkeit")
        case .torso:
            WoundEffect(zone: zone, kind: .extraDamage(count: 1, sides: 3, flat: 1),
                        effectKey: "woundEffect.torso.effect",
                        resistanceKey: "woundEffect.resistance.handlungsfaehigkeit")
        case .arme, .mittlereGliedmassen:
            WoundEffect(zone: zone, kind: .reminder,
                        effectKey: "woundEffect.arme.effect",
                        resistanceKey: "woundEffect.resistance.stoerungen")
        case .beine, .vordereBeine, .hintereBeine:
            WoundEffect(zone: zone, kind: .setStatus(id: "liegend"),
                        effectKey: "woundEffect.beine.effect",
                        resistanceKey: "woundEffect.resistance.stoerungen")
        case .schwanz:
            WoundEffect(zone: zone, kind: .reminder,
                        effectKey: "woundEffect.schwanz.effect",
                        resistanceKey: "woundEffect.resistance.stoerungen")
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run: `make test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Hesindion/Models/WoundEffect.swift HesindionTests/WoundEffectCatalogTests.swift
git commit -m "feat(rules): Wundeffekt catalog per Trefferzone

Kopf raises Betäubung, Torso adds 1W3+1 SP, Beine sets Liegend, Arme is
a reminder. Non-humanoid limb zones reuse the closest published
analogue; Schwanz has no defined effect."
```

---

## Task 5: Localization keys

**Goal:** All new user-facing strings in `Strings.swift`, German and English, before any view needs them.

**Files:**
- Modify: `Hesindion/Theme/Strings.swift` (both `englishFallback` and `translations`)
- Test: `HesindionTests/StringsCoverageTests.swift`

**Acceptance Criteria:**
- [ ] Every `HitZone.nameKey`, `BodySide.nameKey`, `WoundEffect.effectKey` and `resistanceKey` resolves to a non-key string in German
- [ ] The screen keys below all resolve
- [ ] No key resolves to itself (the `L()` fallback for a missing key)

**Verify:** `make test` → `StringsCoverageTests` passes

**Steps:**

- [ ] **Step 1: Write the failing test**

```swift
// HesindionTests/StringsCoverageTests.swift
import XCTest
@testable import Hesindion

final class StringsCoverageTests: XCTestCase {

    private func assertLocalized(_ key: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotEqual(L(key), key, "missing translation for \(key)", file: file, line: line)
    }

    func testHitZoneNamesAreLocalized() {
        for zone in HitZone.allCases { assertLocalized(zone.nameKey) }
        assertLocalized(BodySide.links.nameKey)
        assertLocalized(BodySide.rechts.nameKey)
    }

    func testWoundEffectTextsAreLocalized() {
        for zone in HitZone.allCases {
            let effect = WoundEffectCatalog.effect(for: zone)
            assertLocalized(effect.effectKey)
            assertLocalized(effect.resistanceKey)
        }
    }

    func testScreenKeysAreLocalized() {
        for key in [
            "fokus.section", "fokus.trefferzonen.name", "fokus.trefferzonen.subtitle",
            "trefferzone.section", "trefferzone.none", "trefferzone.roll",
            "trefferzone.targetSurprised", "trefferzone.sfHalves",
            "trefferzone.woundEffect", "trefferzone.threshold",
            "trefferzone.probe", "trefferzone.noTalent", "trefferzone.dropWeapon",
            "trefferzone.reminderTitle", "modifier.trefferzone",
        ] { assertLocalized(key) }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test`
Expected: FAIL — "missing translation for hitZone.kopf"

- [ ] **Step 3: Add the German entries**

Append to the `translations` dictionary in `Hesindion/Theme/Strings.swift`:

```swift
        // MARK: - Trefferzonen (Fokus-Regeln)
        "hitZone.kopf":                 "Kopf",
        "hitZone.torso":                "Torso",
        "hitZone.arme":                 "Arme",
        "hitZone.beine":                "Beine",
        "hitZone.vordereBeine":         "Vordere Beine",
        "hitZone.mittlereGliedmassen":  "Mittlere Gliedmaßen",
        "hitZone.hintereBeine":         "Hintere Beine",
        "hitZone.schwanz":              "Schwanz",
        "bodySide.links":               "links",
        "bodySide.rechts":              "rechts",

        "woundEffect.kopf.effect":      "Eine Stufe Betäubung.",
        "woundEffect.torso.effect":     "Zusätzlich 1W3+1 SP.",
        "woundEffect.arme.effect":      "Einhändig geführte Gegenstände fallen zu Boden.",
        "woundEffect.beine.effect":     "Der Getroffene stürzt zu Boden.",
        "woundEffect.schwanz.effect":   "Kein Regeleffekt.",
        "woundEffect.resistance.handlungsfaehigkeit": "Selbstbeherrschung (Handlungsfähigkeit bewahren)",
        "woundEffect.resistance.stoerungen":          "Selbstbeherrschung (Störungen ignorieren)",

        "fokus.section":                "Fokus-Regeln",
        "fokus.trefferzonen.name":      "Trefferzonen",
        "fokus.trefferzonen.subtitle":  "Treffer werden einer Trefferzone zugeordnet.",
        "trefferzone.section":          "Trefferzone",
        "trefferzone.none":             "Keine Zone",
        "trefferzone.roll":             "1W20",
        "trefferzone.targetSurprised":  "Ziel ist überrascht",
        "trefferzone.sfHalves":         "Gezielter Angriff halbiert die Aufschläge.",
        "trefferzone.woundEffect":      "Wundeffekt",
        "trefferzone.threshold":        "Schaden %d ≥ Wundschwelle %d (×%d)",
        "trefferzone.probe":            "Probe: %@ %d",
        "trefferzone.noTalent":         "Kein Talent Selbstbeherrschung — Effekt tritt ein.",
        "trefferzone.dropWeapon":       "Waffe ablegen",
        "trefferzone.reminderTitle":    "Trefferzone: %@",
        "modifier.trefferzone":         "Trefferzone",
```

- [ ] **Step 4: Add the English fallbacks**

Append the same keys to `englishFallback` with English values ("Head", "Torso", "Arms", "Legs", "Front Legs", "Mid Limbs", "Hind Legs", "Tail", "left", "right", "One level of Stunned.", "An additional 1W3+1 damage.", "One-handed items are dropped.", "The target falls prone.", "No rules effect.", "Self-Control (Retain Composure)", "Self-Control (Ignore Disruptions)", "Hit Zones", "Focus rule: hits are assigned to a body zone.", "Hit Zone", "No zone", "1d20", "Target is surprised", "Aimed Shot halves the penalties.", "Wound Effect", "Damage %d ≥ Wound Threshold %d (×%d)", "Check: %@ %d", "No Self-Control skill — the effect applies.", "Drop weapon", "Hit zone: %@", "Hit Zone").

- [ ] **Step 5: Run tests**

Run: `make test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Hesindion/Theme/Strings.swift HesindionTests/StringsCoverageTests.swift
git commit -m "feat(i18n): Trefferzonen strings, de + en

Adds a coverage test asserting every zone name, wound-effect text and
screen key resolves rather than falling through to the raw key."
```

---

## Task 6: HitZoneModifiers

**Goal:** Zonenaufschlag as a `ModifierDefinition`, halved by the Sonderfertigkeit and eased by 2 against a surprised target.

**Files:**
- Create: `Hesindion/Engine/HitZoneModifiers.swift`
- Modify: `Hesindion/Engine/ModifierEngine.swift:29-54` (add context fields), `:115-122` (register)
- Test: `HesindionTests/HitZoneModifiersTests.swift`

**Acceptance Criteria:**
- [ ] Base penalties: Kopf −10, Torso −4, Arme −8, Beine −8
- [ ] `SA_160` halves in melee, `SA_161` in ranged; the wrong SF does not
- [ ] Überrascht moves the penalty 2 toward zero
- [ ] Combined: Kopf + SF + Überrascht = −3
- [ ] Never returns a positive value
- [ ] Every base value is even (guards the halving from a future odd table edit)
- [ ] No zone selected → no `ModifierLine`

**Verify:** `make test` → `HitZoneModifiersTests` all pass

**Steps:**

- [ ] **Step 1: Write the failing tests**

```swift
// HesindionTests/HitZoneModifiersTests.swift
import XCTest
@testable import Hesindion

final class HitZoneModifiersTests: XCTestCase {

    func testBasePenalties() {
        XCTAssertEqual(HitZoneModifiers.penalty(for: .kopf,  hasSonderfertigkeit: false, targetIsSurprised: false), -10)
        XCTAssertEqual(HitZoneModifiers.penalty(for: .torso, hasSonderfertigkeit: false, targetIsSurprised: false), -4)
        XCTAssertEqual(HitZoneModifiers.penalty(for: .arme,  hasSonderfertigkeit: false, targetIsSurprised: false), -8)
        XCTAssertEqual(HitZoneModifiers.penalty(for: .beine, hasSonderfertigkeit: false, targetIsSurprised: false), -8)
    }

    /// Halving is only safe while every base value is even.
    func testAllBasePenaltiesAreEven() {
        for zone in HitZone.allCases {
            let base = HitZoneModifiers.penalty(for: zone, hasSonderfertigkeit: false, targetIsSurprised: false)
            XCTAssertTrue(base.isMultiple(of: 2), "\(zone) base \(base) is odd — halving needs a rounding rule")
        }
    }

    func testSonderfertigkeitHalves() {
        XCTAssertEqual(HitZoneModifiers.penalty(for: .kopf, hasSonderfertigkeit: true, targetIsSurprised: false), -5)
        XCTAssertEqual(HitZoneModifiers.penalty(for: .arme, hasSonderfertigkeit: true, targetIsSurprised: false), -4)
    }

    func testSurprisedEasesByTwo() {
        XCTAssertEqual(HitZoneModifiers.penalty(for: .kopf,  hasSonderfertigkeit: false, targetIsSurprised: true), -8)
        XCTAssertEqual(HitZoneModifiers.penalty(for: .torso, hasSonderfertigkeit: false, targetIsSurprised: true), -2)
    }

    /// The spec's worked example.
    func testCombinedKopf() {
        XCTAssertEqual(HitZoneModifiers.penalty(for: .kopf, hasSonderfertigkeit: true, targetIsSurprised: true), -3)
    }

    func testNeverBecomesABonus() {
        for zone in HitZone.allCases {
            let p = HitZoneModifiers.penalty(for: zone, hasSonderfertigkeit: true, targetIsSurprised: true)
            XCTAssertLessThanOrEqual(p, 0, "\(zone) produced a bonus")
        }
    }

    /// In-memory hero, mirroring `StateModifiersTests.makeHero`. `TestData` lives in
    /// the Snapshots folder and offers only `makeContainer` / `importBoronmir`.
    private func makeHero() -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self, Attributes.self,
            configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        return hero
    }

    func testNoZoneProducesNoLine() {
        let hero = makeHero()
        var ctx = ModifierContext(hero: hero, domain: .meleeAttack)
        ctx.targetHitZone = nil
        XCTAssertNil(HitZoneModifiers.zonenaufschlag.evaluate(ctx))
    }

    func testMeleeUsesSA160NotSA161() {
        let hero = makeHero()
        hero.combatSpecialAbilities = [HeroTrait(ruleId: "SA_161", name: "Gezielter Schuss", tier: nil, sid: nil)]
        var ctx = ModifierContext(hero: hero, domain: .meleeAttack)
        ctx.targetHitZone = .kopf
        // Ranged SF must not halve a melee attack.
        XCTAssertEqual(HitZoneModifiers.zonenaufschlag.evaluate(ctx)?.value, -10)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test`
Expected: FAIL — "cannot find 'HitZoneModifiers' in scope"

- [ ] **Step 3: Extend ModifierContext**

In `Hesindion/Engine/ModifierEngine.swift`, add to `struct ModifierContext` beside the other combat-shared fields (around line 38):

```swift
    // Trefferzonen (Fokus-Regeln)
    var targetHitZone: HitZone? = nil
    /// GM-driven. The opponent is not modelled, so this cannot come from hero states.
    var targetIsSurprised: Bool = false
```

- [ ] **Step 4: Write the implementation**

```swift
// Hesindion/Engine/HitZoneModifiers.swift
import Foundation

/// Zonenaufschlag for targeted attacks (DSA 5 Fokus-Trefferzonenregeln).
enum HitZoneModifiers {

    static let all: [ModifierDefinition] = [zonenaufschlag]

    /// Base Zonenaufschlag per zone.
    ///
    /// The rules table names Kopf, Torso, Arme and Beine only; the extra limb zones on
    /// non-humanoid plans reuse the limb value of −8 by analogy.
    private static func basePenalty(for zone: HitZone) -> Int {
        switch zone {
        case .kopf:  -10
        case .torso: -4
        default:     -8
        }
    }

    /// - Parameters:
    ///   - hasSonderfertigkeit: hero owns SA_160 (melee) or SA_161 (ranged)
    ///   - targetIsSurprised: GM-driven; the opponent is not modelled
    static func penalty(for zone: HitZone, hasSonderfertigkeit: Bool, targetIsSurprised: Bool) -> Int {
        var value = basePenalty(for: zone)
        if hasSonderfertigkeit { value /= 2 }        // every base is even; asserted in tests
        if targetIsSurprised { value += 2 }          // 2 toward zero
        return min(value, 0)                         // never a bonus
    }

    static let zonenaufschlag = ModifierDefinition(
        id: "zonenaufschlag",
        domains: [.meleeAttack, .rangedAttack]
    ) { ctx in
        guard let zone = ctx.targetHitZone else { return nil }
        let ruleId = ctx.domain == .rangedAttack ? "SA_161" : "SA_160"
        let hasSF = ctx.hero.combatSpecialAbilities.contains { $0.ruleId == ruleId }
        let value = penalty(for: zone, hasSonderfertigkeit: hasSF, targetIsSurprised: ctx.targetIsSurprised)
        guard value != 0 else { return nil }
        return ModifierLine(value: value, source: "\(L("modifier.trefferzone")): \(L(zone.nameKey))")
    }
}
```

- [ ] **Step 5: Register it**

In `ModifierEngine.swift` around line 122, beside the other registrations:

```swift
        defs.append(contentsOf: HitZoneModifiers.all)
```

- [ ] **Step 6: Run tests**

Run: `make test`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add Hesindion/Engine/HitZoneModifiers.swift Hesindion/Engine/ModifierEngine.swift HesindionTests/HitZoneModifiersTests.swift
git commit -m "feat(combat): Zonenaufschlag modifier for targeted attacks

Kopf -10, Torso -4, limbs -8; halved by Gezielter Angriff (SA_160) in
melee and Gezielter Schuss (SA_161) at range, eased by 2 against a
surprised target, clamped so it can never become a bonus.

Überrascht is a context flag, not a hero state: it describes the
opponent, which the app does not model."
```

---

## Task 7: Per-rule Fokus-Regeln toggles

**Goal:** A per-rule activation mechanism — each Fokus-Regel independently switchable per combat, all off by default.

**Files:**
- Create: `Hesindion/Models/FokusRule.swift`
- Modify: `Hesindion/Models/Hero.swift:50` (field + helpers), `:415` (clear)
- Modify: `Hesindion/Views/CombatSetupViews.swift`
- Test: `HesindionTests/FokusRuleTests.swift`

**Acceptance Criteria:**
- [ ] `activeCombatFokusRules` defaults to `[]`; `isFokusRuleActive(.trefferzonen)` is false
- [ ] `setFokusRule(.trefferzonen, active: true)` then `false` round-trips cleanly
- [ ] Enabling twice does not duplicate the id
- [ ] `clearCombatSession()` resets it to `[]`
- [ ] `combatSetup` shows one toggle per `FokusRule.allCases`, driven by a single `ForEach`

**Verify:** `make test` → `FokusRuleTests` pass; `make run` → a "Fokus-Regeln" section with a Trefferzonen toggle

**Steps:**

- [ ] **Step 1: Write the failing test**

```swift
// HesindionTests/FokusRuleTests.swift
import XCTest
import SwiftData
@testable import Hesindion

final class FokusRuleTests: XCTestCase {

    private func makeHero() -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Hero.self, HeroStateEntry.self, configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        return hero
    }

    func testDefaultsToNoRulesActive() {
        let hero = makeHero()
        XCTAssertEqual(hero.activeCombatFokusRules, [])
        XCTAssertFalse(hero.isFokusRuleActive(.trefferzonen))
    }

    func testToggleRoundTrips() {
        let hero = makeHero()
        hero.setFokusRule(.trefferzonen, active: true)
        XCTAssertTrue(hero.isFokusRuleActive(.trefferzonen))
        hero.setFokusRule(.trefferzonen, active: false)
        XCTAssertFalse(hero.isFokusRuleActive(.trefferzonen))
    }

    func testEnablingTwiceDoesNotDuplicate() {
        let hero = makeHero()
        hero.setFokusRule(.trefferzonen, active: true)
        hero.setFokusRule(.trefferzonen, active: true)
        XCTAssertEqual(hero.activeCombatFokusRules, ["trefferzonen"])
    }

    func testClearCombatSessionResetsRules() {
        let hero = makeHero()
        hero.setFokusRule(.trefferzonen, active: true)
        hero.clearCombatSession()
        XCTAssertEqual(hero.activeCombatFokusRules, [])
    }

    /// Every case must carry resolvable strings, so adding a rule cannot silently
    /// ship an untranslated toggle.
    func testEveryRuleIsLocalized() {
        for rule in FokusRule.allCases {
            XCTAssertNotEqual(L(rule.nameKey), rule.nameKey)
            XCTAssertNotEqual(L(rule.subtitleKey), rule.subtitleKey)
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test`
Expected: FAIL — "cannot find type 'FokusRule' in scope"

- [ ] **Step 3: Write FokusRule.swift**

```swift
// Hesindion/Models/FokusRule.swift
import Foundation

/// Optional DSA 5 Fokus-Regeln. Each is independently switchable per combat, because
/// a group may want hit zones without, say, zone armour.
///
/// Adding a rule: one case here, two `L()` keys, and whatever the rule itself needs.
enum FokusRule: String, CaseIterable, Identifiable {
    case trefferzonen

    var id: String { rawValue }
    var nameKey: String { "fokus.\(rawValue).name" }
    var subtitleKey: String { "fokus.\(rawValue).subtitle" }
}
```

- [ ] **Step 4: Add storage and helpers to Hero**

In the *Combat session state* block after `activeCombatMounted`:

```swift
    /// Ids of the Fokus-Regeln active for this combat (see `FokusRule`). Empty by
    /// default — with no rule active, combat behaves exactly as it did before.
    /// Stored as raw ids rather than one Bool per rule so that adding or retiring a
    /// rule does not change the schema.
    var activeCombatFokusRules: [String] = []
```

And as methods on `Hero`:

```swift
    func isFokusRuleActive(_ rule: FokusRule) -> Bool {
        activeCombatFokusRules.contains(rule.rawValue)
    }

    func setFokusRule(_ rule: FokusRule, active: Bool) {
        if active {
            guard !isFokusRuleActive(rule) else { return }
            activeCombatFokusRules.append(rule.rawValue)
        } else {
            activeCombatFokusRules.removeAll { $0 == rule.rawValue }
        }
    }
```

In `clearCombatSession()`:

```swift
        activeCombatFokusRules = []
```

- [ ] **Step 5: Add the section to CombatSetupViews**

Beside the other optional-rule switches, following the file's existing toggle styling:

```swift
                combatSectionLabel(L("fokus.section"))

                ForEach(FokusRule.allCases) { rule in
                    Toggle(isOn: Binding(
                        get: { hero.isFokusRuleActive(rule) },
                        set: { hero.setFokusRule(rule, active: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L(rule.nameKey))
                                .font(.system(.body, weight: .black))
                            Text(L(rule.subtitleKey))
                                .font(.system(.caption))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
```

- [ ] **Step 6: Run tests**

Run: `make test`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add Hesindion/Models/FokusRule.swift Hesindion/Models/Hero.swift Hesindion/Views/CombatSetupViews.swift HesindionTests/FokusRuleTests.swift
git commit -m "feat(combat): per-rule Fokus-Regeln toggles

Groups play with different subsets of the optional rules, so each is
switchable on its own rather than behind one Fokus-Regeln switch.
Stored as raw ids on the combat session, driven in the UI by a single
ForEach over FokusRule.allCases, so a future rule costs one enum case
and two strings."
```

---

## Task 8: Shared zone picker view

**Goal:** One reusable chip row for choosing a zone, used by all three screens.

**Files:**
- Create: `Hesindion/Views/CombatZonePicker.swift`

**Acceptance Criteria:**
- [ ] Renders a chip per zone plus a "Keine Zone" default
- [ ] Each chip shows its live penalty when `showsPenalty` is true
- [ ] Optional "Ziel ist überrascht" toggle, and an SF hint shown only when the hero owns it
- [ ] Selecting a chip writes through the binding; selecting the active chip clears to `nil`

**Verify:** `make run` → picker renders in combat setup preview

**Steps:**

- [ ] **Step 1: Write the view**

```swift
// Hesindion/Views/CombatZonePicker.swift
import SwiftUI

/// Single-select Trefferzone chips. Shared by the melee announcement, the ranged
/// setup and the take-damage screen.
struct CombatZonePicker: View {
    @Binding var selection: HitZone?
    @Binding var targetIsSurprised: Bool

    /// Zones offered. Defaults to the humanoid set; pass the full set for other plans.
    var zones: [HitZone] = [.kopf, .torso, .arme, .beine]
    /// Show the live Zonenaufschlag on each chip (offence only).
    var showsPenalty: Bool = false
    /// Show the Überrascht toggle (offence only).
    var showsSurprisedToggle: Bool = false
    /// Hero owns SA_160 / SA_161 for the current domain.
    var hasSonderfertigkeit: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            combatSectionLabel(L("trefferzone.section"))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                ForEach(zones) { zone in
                    Button {
                        selection = (selection == zone) ? nil : zone
                    } label: {
                        VStack(spacing: 2) {
                            Text(L(zone.nameKey))
                                .font(.system(.caption, weight: .black))
                            if showsPenalty {
                                Text("\(HitZoneModifiers.penalty(for: zone, hasSonderfertigkeit: hasSonderfertigkeit, targetIsSurprised: targetIsSurprised))")
                                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection == zone ? Color.groupCombat.opacity(0.35) : Color.clear)
                        .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                selection = nil
            } label: {
                Text(L("trefferzone.none"))
                    .font(.system(.caption, weight: .black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selection == nil ? Color.groupCombat.opacity(0.35) : Color.clear)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .buttonStyle(.plain)

            if showsSurprisedToggle {
                Toggle(L("trefferzone.targetSurprised"), isOn: $targetIsSurprised)
                    .font(.system(.caption, weight: .bold))
            }

            if showsPenalty && hasSonderfertigkeit {
                Text(L("trefferzone.sfHalves"))
                    .font(.system(.caption2))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `make run`
Expected: builds and launches; no visual change yet (nothing renders it)

- [ ] **Step 3: Commit**

```bash
git add Hesindion/Views/CombatZonePicker.swift
git commit -m "feat(combat): shared Trefferzone picker view"
```

---

## Task 9: Wire the picker into melee and ranged

**Goal:** Announced zone flows into the AT/FK modifier breakdown on both attack paths.

**Files:**
- Modify: `Hesindion/Views/CombatAttackViews.swift` (announcement step)
- Modify: `Hesindion/Views/CombatFernkampfViews.swift` (fernkampfSetup step)

**Acceptance Criteria:**
- [ ] Picker appears in both screens only when `hero.isFokusRuleActive(.trefferzonen)`
- [ ] Selecting a zone adds a `ModifierLine` labelled "Trefferzone: Kopf" to the breakdown
- [ ] Default is no zone, and the breakdown is then byte-identical to before
- [ ] The melee screen reads `SA_160`, the ranged screen `SA_161`

**Verify:** `make run` → select Kopf in a melee announcement, confirm a −10 line appears in the modifier list and the effective AT drops by 10

**Steps:**

- [ ] **Step 1: Add state to the announcement view**

In `CombatAttackViews.swift`, in the announcement view struct:

```swift
    @State private var targetZone: HitZone? = nil
    @State private var targetIsSurprised = false
```

- [ ] **Step 2: Render the picker**

Inside the modifier section, before the existing modifier rows:

```swift
                if hero.isFokusRuleActive(.trefferzonen) {
                    CombatZonePicker(
                        selection: $targetZone,
                        targetIsSurprised: $targetIsSurprised,
                        showsPenalty: true,
                        showsSurprisedToggle: true,
                        hasSonderfertigkeit: hero.combatSpecialAbilities.contains { $0.ruleId == "SA_160" }
                    )
                }
```

- [ ] **Step 3: Thread it into the context**

`CombatAttackViews.swift:566` builds the context as `var context = ModifierContext(hero: hero, domain: .meleeAttack)`. Add directly beneath that line, before the context is passed to the engine:

```swift
        context.targetHitZone = targetZone
        context.targetIsSurprised = targetIsSurprised
```

- [ ] **Step 4: Repeat for ranged**

Same three changes in `CombatFernkampfViews.swift`, whose context is built at line 26 as
`var context = ModifierContext(hero: hero, domain: .rangedAttack)`. Use `"SA_161"` for the picker's
`hasSonderfertigkeit`. `HitZoneModifiers` reads the domain off the context, so the ranged SF is
selected automatically — do not special-case it in the view.

- [ ] **Step 5: Verify by hand**

Run: `make run`
Expected: with Trefferzonen on, choosing Kopf shows a "Trefferzone: Kopf −10" line; toggling Überrascht changes it to −8; with the toggle off, no line appears

- [ ] **Step 6: Commit**

```bash
git add Hesindion/Views/CombatAttackViews.swift Hesindion/Views/CombatFernkampfViews.swift
git commit -m "feat(combat): zone picker in melee announcement and ranged setup"
```

---

## Task 10: Reminder card after a landed hit

**Goal:** Hand the GM the wound effect for the announced zone, since the opponent is not modelled.

**Files:**
- Modify: `Hesindion/Views/CombatDamageViews.swift` (the post-hit damage screen)

**Acceptance Criteria:**
- [ ] Card appears only when Trefferzonen is on and a zone was announced
- [ ] Shows the zone name, its effect text, and the resisting Selbstbeherrschung application
- [ ] Read-only — no buttons, no state writes

**Verify:** `make run` → land a targeted melee hit, confirm the card renders and nothing is applied

**Steps:**

- [ ] **Step 1: Write the view**

Add to `CombatDamageViews.swift`:

```swift
/// Read-only GM prompt shown after a landed targeted attack.
///
/// Nothing is applied: the opponent has no LP, no KO and no states, so the app can
/// only state the rule and let the GM adjudicate.
struct WoundEffectReminderCard: View {
    let zone: HitZone

    var body: some View {
        let effect = WoundEffectCatalog.effect(for: zone)
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: L("trefferzone.reminderTitle"), L(zone.nameKey)))
                .font(.system(.caption, weight: .black))
            Text(L(effect.effectKey))
                .font(.system(.caption))
            Text(L(effect.resistanceKey))
                .font(.system(.caption2))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.groupCombat.opacity(0.1))
        .overlay(Rectangle().stroke(Color.groupCombat, lineWidth: 2))
    }
}
```

- [ ] **Step 2: Render it**

In the damage view reached after a hit, pass the announced zone down through the `CombatStep` payload and render:

```swift
                if hero.isFokusRuleActive(.trefferzonen), let zone = announcedZone {
                    WoundEffectReminderCard(zone: zone)
                }
```

- [ ] **Step 3: Verify by hand**

Run: `make run`
Expected: card renders after a targeted hit; hero state is unchanged

- [ ] **Step 4: Commit**

```bash
git add Hesindion/Views/CombatDamageViews.swift
git commit -m "feat(combat): wound-effect reminder card after a targeted hit"
```

---

## Task 11: Defence — zone row, Wundschwelle and wound effects

**Goal:** The real automation: roll or tap a zone, compare damage to the Wundschwelle, resist, apply.

**Files:**
- Modify: `Hesindion/Views/CombatDamageViews.swift:6-170` (`CombatTakeDamageView`)
- Test: `HesindionTests/WoundEffectApplicationTests.swift`

**Acceptance Criteria:**
- [ ] `multiple = effectiveDamage / wundschwelle.max`; `0` hides the panel entirely
- [ ] The rules' worked example holds: `ws = 6` → `−1` at 6 damage, `−2` at 12, `−3` at 18
- [ ] `ws == 0` never triggers an effect
- [ ] Failed probe: Kopf raises Betäubung (clamped at 4), Beine sets Liegend, Torso folds 1W3+1 into the single LP write
- [ ] Successful probe applies nothing
- [ ] Missing Selbstbeherrschung talent counts as a failure and shows `trefferzone.noTalent`
- [ ] LP is written exactly once on confirm
- [ ] One `LogEntry` per resolved wound effect

**Verify:** `make test` → `WoundEffectApplicationTests` all pass

**Steps:**

- [ ] **Step 1: Write the failing tests**

```swift
// HesindionTests/WoundEffectApplicationTests.swift
import XCTest
import SwiftData
@testable import Hesindion

final class WoundEffectApplicationTests: XCTestCase {

    /// In-memory hero with a given Wundschwelle. `TestData` is snapshot-only, so this
    /// mirrors `StateModifiersTests.makeHero`.
    private func hero(ws: Int) -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self, Attributes.self,
            configurations: config)
        let ctx = ModelContext(container)
        let h = Hero(name: "T"); ctx.insert(h)
        h.derivedValues?.wundschwelle = ComputedValue(value: ws, bonus: 0, max: ws)
        return h
    }

    func testMultipleBoundaries() {
        XCTAssertEqual(WoundEffectResolver.multiple(damage: 5, wundschwelle: 6), 0)
        XCTAssertEqual(WoundEffectResolver.multiple(damage: 6, wundschwelle: 6), 1)
        XCTAssertEqual(WoundEffectResolver.multiple(damage: 11, wundschwelle: 6), 1)
        XCTAssertEqual(WoundEffectResolver.multiple(damage: 12, wundschwelle: 6), 2)
    }

    /// The Regelwiki's worked example, verbatim.
    func testRulesWorkedExample() {
        XCTAssertEqual(WoundEffectResolver.probeModifier(damage: 6,  wundschwelle: 6), -1)
        XCTAssertEqual(WoundEffectResolver.probeModifier(damage: 12, wundschwelle: 6), -2)
        XCTAssertEqual(WoundEffectResolver.probeModifier(damage: 18, wundschwelle: 6), -3)
    }

    func testZeroWundschwelleNeverTriggers() {
        XCTAssertEqual(WoundEffectResolver.multiple(damage: 99, wundschwelle: 0), 0)
    }

    func testKopfRaisesBetaeubungAndClamps() {
        let h = hero(ws: 6)
        var extra: Int? = nil
        for _ in 0..<6 { WoundEffectResolver.apply(.kopf, to: h, extraDamage: &extra) }
        XCTAssertEqual(h.level(of: "betaeubung"), 4, "setStateLevel clamps Zustände at 4")
    }

    func testBeineSetsLiegend() {
        let h = hero(ws: 6)
        var extra: Int? = nil
        WoundEffectResolver.apply(.beine, to: h, extraDamage: &extra)
        XCTAssertTrue(h.hasState("liegend"))
    }

    func testTorsoExtraDamageIsSeeded() {
        var rng = SplitMix64(seed: 42)   // defined in DiceRollerTests.swift:271
        let extra = WoundEffectResolver.rollExtraDamage(count: 1, sides: 3, flat: 1, using: &rng)
        XCTAssertTrue((2...4).contains(extra), "1W3+1 must land in 2...4, got \(extra)")
    }

    func testSuccessfulProbeAppliesNothing() {
        let h = hero(ws: 6)
        WoundEffectResolver.resolve(zone: .beine, probeSucceeded: true, hero: h)
        XCTAssertFalse(h.hasState("liegend"))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `make test`
Expected: FAIL — "cannot find 'WoundEffectResolver' in scope"

- [ ] **Step 3: Write the resolver**

Add to `Hesindion/Models/WoundEffect.swift`:

```swift
/// Pure decision logic for wound effects, kept out of the view so it is testable.
enum WoundEffectResolver {

    /// How many times the damage covers the Wundschwelle. `0` means no wound effect.
    static func multiple(damage: Int, wundschwelle: Int) -> Int {
        guard wundschwelle > 0 else { return 0 }
        return damage / wundschwelle
    }

    /// The Selbstbeherrschung probe is harder by 1 per multiple of the Wundschwelle.
    /// Rules example: Wundschwelle 6 → −1 at 6 SP, −2 at 12, −3 at 18.
    static func probeModifier(damage: Int, wundschwelle: Int) -> Int {
        -multiple(damage: damage, wundschwelle: wundschwelle)
    }

    static func rollExtraDamage<G: RandomNumberGenerator>(
        count: Int, sides: Int, flat: Int, using generator: inout G
    ) -> Int {
        DiceRoller.roll(count: count, sides: sides, using: &generator).reduce(0, +) + flat
    }

    /// Apply a zone's effect to the hero. `extraDamage` is folded into the caller's
    /// single LP write rather than applied here.
    static func apply(_ zone: HitZone, to hero: Hero, extraDamage: inout Int?) {
        switch WoundEffectCatalog.effect(for: zone).kind {
        case .raiseState(let id):
            hero.setStateLevel(id, level: hero.level(of: id) + 1)
        case .setStatus(let id):
            hero.setStateLevel(id, level: 1)
        case .extraDamage(let count, let sides, let flat):
            var rng = SystemRandomNumberGenerator()
            extraDamage = rollExtraDamage(count: count, sides: sides, flat: flat, using: &rng)
        case .reminder:
            break
        }
    }

    /// Convenience for the success path and for tests.
    static func resolve(zone: HitZone, probeSucceeded: Bool, hero: Hero) {
        guard !probeSucceeded else { return }
        var ignored: Int? = nil
        apply(zone, to: hero, extraDamage: &ignored)
    }
}
```

- [ ] **Step 4: Extend CombatTakeDamageView**

Add state:

```swift
    @State private var zoneHit: HitZoneHit? = nil
    @State private var lastRoll: Int? = nil
    @State private var bodyPlan: BodyPlan = .humanoid(.mittel)
    @State private var probeResolved = false
    @State private var probeSucceeded = false
    @State private var extraDamage: Int? = nil
```

Add a computed Wundschwelle and the zone row below the existing damage display (the view already
computes `rs` and `effectiveDamage` at lines 17-18):

```swift
    private var ws: Int { hero.derivedValues?.wundschwelle.max ?? 0 }
    private var multiple: Int { WoundEffectResolver.multiple(damage: effectiveDamage, wundschwelle: ws) }

    @ViewBuilder
    private var zoneRow: some View {
        if hero.isFokusRuleActive(.trefferzonen) {
            CombatZonePicker(
                selection: Binding(get: { zoneHit?.zone }, set: { newZone in
                    lastRoll = nil
                    zoneHit = newZone.map { HitZoneHit(zone: $0, side: nil) }
                }),
                targetIsSurprised: .constant(false),
                zones: [.kopf, .torso, .arme, .beine]
            )

            Button {
                let roll = DiceRoller.roll(sides: 20)
                lastRoll = roll
                zoneHit = HitZoneTable.lookup(roll, plan: bodyPlan)
            } label: {
                Text(L("trefferzone.roll"))
                    .font(.system(.caption, weight: .black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(combatAccent)
                    .foregroundStyle(.white)
                    .overlay(Rectangle().stroke(Color.dsaBorder, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .disabled(confirmed)

            if let hit = zoneHit {
                Text(zoneSummary(hit))
                    .font(.system(.caption, design: .monospaced, weight: .bold))
            }
        }
    }

    private func zoneSummary(_ hit: HitZoneHit) -> String {
        let name = L(hit.zone.nameKey)
        let sided = hit.side.map { "\(name) (\(L($0.nameKey)))" } ?? name
        return lastRoll.map { "\($0): \(sided)" } ?? sided
    }
```

Then the Wundeffekt panel, shown only when `multiple >= 1`:

```swift
    @ViewBuilder
    private var woundEffectPanel: some View {
        if hero.isFokusRuleActive(.trefferzonen), let hit = zoneHit, multiple >= 1 {
            let effect = WoundEffectCatalog.effect(for: hit.zone)
            VStack(alignment: .leading, spacing: 6) {
                combatSectionLabel(L("trefferzone.woundEffect"))
                Text(String(format: L("trefferzone.threshold"), effectiveDamage, ws, multiple))
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                Text(L(effect.effectKey)).font(.system(.caption))

                if let talent = selbstbeherrschung {
                    Button {
                        // Existing skill-check flow, pre-filled with the Wundschwellen modifier.
                        presentProbe(
                            talent: talent,
                            modifier: WoundEffectResolver.probeModifier(damage: effectiveDamage, wundschwelle: ws),
                            label: L(effect.resistanceKey)
                        )
                    } label: {
                        Text(String(
                            format: L("trefferzone.probe"),
                            L(effect.resistanceKey),
                            WoundEffectResolver.probeModifier(damage: effectiveDamage, wundschwelle: ws)
                        ))
                    }
                    .buttonStyle(.plain)
                    .disabled(probeResolved || confirmed)
                } else {
                    Text(L("trefferzone.noTalent"))
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                        .onAppear { probeResolved = true; probeSucceeded = false }
                }

                if probeResolved, !probeSucceeded, case .reminder = effect.kind {
                    Button(L("trefferzone.dropWeapon")) { hero.selectedWeaponName = nil }
                        .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(Color.groupCombat, lineWidth: 2))
        }
    }

    private var selbstbeherrschung: Talent? {
        hero.talents.first { $0.name == "Selbstbeherrschung" }
    }
```

`presentProbe` routes into the app's existing skill-check modal (the same one
`SkillCheckModal` drives elsewhere) and writes back `probeResolved = true` plus
`probeSucceeded`. A hero without the talent is treated as a failure, per the spec.

On **Bestätigen**, in this order:

```swift
        if let hit = zoneHit, probeResolved, !probeSucceeded {
            WoundEffectResolver.apply(hit.zone, to: hero, extraDamage: &extraDamage)
        }
        let total = effectiveDamage + (extraDamage ?? 0)
        hero.derivedValues?.lebensenergie.current = max(0, (hero.derivedValues?.lebensenergie.current ?? 0) - total)
```

so LP is written exactly once.

- [ ] **Step 5: Log it**

After confirm, one entry:

```swift
        modelContext.insert(LogEntry.create(
            kind: "woundEffect",
            payload: WoundEffectLogPayload(
                zone: zoneHit?.zone.rawValue,
                side: zoneHit?.side?.rawValue,
                roll: lastRoll,
                damage: effectiveDamage,
                wundschwelle: ws,
                multiple: WoundEffectResolver.multiple(damage: effectiveDamage, wundschwelle: ws),
                probeSucceeded: probeSucceeded,
                extraDamage: extraDamage
            ),
            hero: hero
        ))
```

with a matching `Codable` payload struct beside it.

- [ ] **Step 6: Run tests**

Run: `make test`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add Hesindion/Models/WoundEffect.swift Hesindion/Views/CombatDamageViews.swift HesindionTests/WoundEffectApplicationTests.swift
git commit -m "feat(combat): Wundschwelle wound effects on taking damage

Roll or tap a zone, compare damage against the hero's Wundschwelle, and
on a failed Selbstbeherrschung probe apply the effect: Betäubung for
Kopf, Liegend for Beine, 1W3+1 folded into the single LP write for
Torso. One effect at -multiple, per the rules' worked example."
```

---

## Task 12: Snapshot test

**Goal:** Lock the Wundeffekt panel's layout.

**Files:**
- Modify: `HesindionTests/SnapshotTests.swift` (or the existing UI snapshot suite file)

**Acceptance Criteria:**
- [ ] One variant covering `CombatTakeDamageView` with the panel open
- [ ] Reference recorded and committed

**Verify:** `make test-ui` → passes against the committed reference

**Steps:**

- [ ] **Step 1: Add the case**

Create `HesindionTests/Snapshots/WoundEffectSnapshotTests.swift`, following
`CombatViewSnapshotTests` and using the shared `assertAllVariants` helper
(`SnapshotTestHelpers.swift:84`):

```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class WoundEffectSnapshotTests: XCTestCase {

    @MainActor
    func testWoundEffectPanel() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        hero.setFokusRule(.trefferzonen, active: true)
        hero.derivedValues?.wundschwelle = ComputedValue(value: 6, bonus: 0, max: 6)

        let view = CombatTakeDamageView(
            hero: hero,
            step: .constant(.takeDamage),
            onDismiss: {},
            combatId: UUID(),
            roundNumber: 1
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "woundEffectPanel")
    }
}
```

The panel only renders once TP is entered and a zone chosen, so give
`CombatTakeDamageView` internal `init` defaults for `tpInput` and `zoneHit` (or expose a
test-only seed) so the snapshot can start in the damage-8, Arme state rather than an
empty form. Do not add production-only affordances for this — a default-valued
initialiser parameter is enough.

- [ ] **Step 2: Record the reference**

Run: `make test-ui-record`

`test-ui-record` writes only **missing** references. If you are re-recording after a layout change, delete the reference file first or nothing happens.

- [ ] **Step 3: Verify**

Run: `make test-ui`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add HesindionTests/
git commit -m "test(ui): snapshot the Wundeffekt panel"
```

---

## Task 13: Documentation

**Goal:** Record the decisions where they will be found later.

**Files:**
- Create: `docs/adr/0005-trefferzonen-offence-defence-asymmetry.md`
- Create: `docs/adr/0006-derived-value-rounding-and-repair.md`
- Modify: `CHANGELOG.md`, `AGENTS.md`

**Acceptance Criteria:**
- [ ] ADR-0005 records why wound effects apply on defence only
- [ ] ADR-0006 records the round-up convention and repair-not-migration
- [ ] CHANGELOG `[Unreleased] → Added` covers Trefferzonen; `→ Fixed` covers all three rounding corrections
- [ ] AGENTS.md gains a Trefferzonen bullet under *Combat System* and the round-up rule under *Code Creation Guidance*

**Verify:** `git diff --stat` shows all four files; both ADRs follow `docs/adr/0000-template.md`

**Steps:**

- [ ] **Step 1: Write ADR-0005** following `docs/adr/0000-template.md`. Decision: wound effects are applied on the defence side only, because no opponent is modelled; the offence side emits a `ModifierLine` and a read-only reminder card. Consequences: full symmetry needs an opponent model, which is a much larger change.

- [ ] **Step 2: Write ADR-0006.** Decision: where DSA 5 yields a fraction and the rules do not clearly say otherwise, round up; carve-outs are "je volle N Punkte" wordings (floor by construction) and penalties (direction is ambiguous, read the rule). Stored values are repaired by a launch-time pass rather than a schema stage, because `HesindionApp` builds its container without a `migrationPlan:` and this is data repair, not a shape change.

- [ ] **Step 3: Update CHANGELOG.md** under `[Unreleased]`:

```markdown
### Added

- Trefferzonen (DSA 5 Fokus-Regeln) — optional per-combat rules assigning hits to a body zone: a zone picker feeding the Zonenaufschlag into attack rolls, and on taking damage a zone roll, Wundschwelle comparison and Selbstbeherrschung probe that applies Betäubung, Liegend or extra damage
- The Optolith `raceId` is now persisted as `PersonalData.speciesId`

### Fixed

- Wundschwelle, Ausweichen and Initiative rounded **down** instead of up. A hero with an odd KO had a Wundschwelle one point too low; odd GE cost a point of Ausweichen, and odd MU+GE a point of Initiative. Existing heroes are corrected automatically at next launch
- The Wundschwelle modifiers Eisern (`ADV_54`, +1) and Gläsern (`DISADV_56`, −1) were never applied
```

- [ ] **Step 4: Update AGENTS.md** — a Trefferzonen bullet under *Combat System*, and under *Code Creation Guidance*: "DSA rounding: where a calculation yields a fraction and the rules do not clearly say otherwise, round up (`Int(ceil(...))`). Exceptions: 'je volle N Punkte' wordings are floor; for penalties, read the rule — 'up' is ambiguous. See ADR-0006."

- [ ] **Step 5: Commit**

```bash
git add docs/adr/0005-trefferzonen-offence-defence-asymmetry.md docs/adr/0006-derived-value-rounding-and-repair.md CHANGELOG.md AGENTS.md
git commit -m "docs: ADRs, CHANGELOG and AGENTS for Trefferzonen + rounding"
```

---

## Verification

Full suite, single simulator (the Makefile already pins `-parallel-testing-enabled NO`):

```bash
make test
make test-ui
```

Manual pass, `make run`:

1. Combat setup shows the Trefferzonen toggle, off by default.
2. With it off, attack and damage screens are unchanged.
3. With it on: announce Kopf → a `−10` line appears; toggle Überrascht → `−8`; on a hero with SA_160 → `−5` and `−3`.
4. Take 8 damage on a hero with Wundschwelle 6 → panel appears at ×1; roll the die → a zone and side resolve; fail the probe on Beine → Liegend appears in the states strip; LP drops by 8 exactly once.
5. Take 5 damage → no panel.
