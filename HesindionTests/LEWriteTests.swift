import XCTest
import SwiftData
@testable import Hesindion

/// Final whole-branch review item 1: every write path that changes current LE clamped against
/// an assumed 0 whenever `SheetValues.of(hero)?.leMax.result` was `nil` — the rules engine not
/// loaded, or (as here) a hero whose sheet the engine cannot resolve a maximum for at all. Each
/// wrote LE down to 0 instead of doing nothing. `LEWrite` is the injectable seam these tests
/// exercise directly (the task's sanctioned alternative to swapping `RulesEngineStore.shared`,
/// a `static let` no in-process test can touch); the `Reversible.reverse` tests below also hit
/// the real, un-mocked `SheetValues.of(hero)` through a hero with no attributes, which leaves
/// `leMax` genuinely unresolvable (`kampfwerte`'s `sum` is nil when any of its parts is).
@MainActor
final class LEWriteTests: XCTestCase {

    // MARK: - Pure helper: heal / regenerate confirm

    func testHealedIsNilWhenLeMaxIsUnknown() {
        XCTAssertNil(LEWrite.healed(current: 10, amount: 5, leMax: nil))
    }

    /// The guard every confirm button now runs (`HeilungSheet`, `RegenerierenSheet`): a `nil`
    /// result means nothing is assigned, so current LE is exactly what it was.
    func testHealConfirmLeavesCurrentLEUnchangedWhenLeMaxIsUnknown() {
        var currentLE = 10
        if let newLE = LEWrite.healed(current: currentLE, amount: 5, leMax: nil) {
            currentLE = newLE
        }
        XCTAssertEqual(currentLE, 10)
    }

    func testHealedClampsToLeMaxWhenKnown() {
        XCTAssertEqual(LEWrite.healed(current: 10, amount: 5, leMax: 12), 12)
        XCTAssertEqual(LEWrite.healed(current: 10, amount: 1, leMax: 12), 11)
    }

    // MARK: - Pure helper: the LP-bar ±1 step

    func testSteppedIsNilForBothDirectionsWhenLeMaxIsUnknown() {
        // Before the fix, the decrement's own guard (`current > 0`) had nothing to do with
        // `leMax`, so it kept firing while the increment (`current < max`) read the unknown
        // maximum as 0 and blocked — "blocks + but allows −" (final review item 1).
        XCTAssertNil(LEWrite.stepped(current: 10, by: -1, leMax: nil))
        XCTAssertNil(LEWrite.stepped(current: 10, by: 1, leMax: nil))
    }

    /// The guard `CombatRootView.lpBar`'s `onDecrement`/`onIncrement` now run: a `nil` step
    /// means nothing is assigned, so current LE is exactly what it was — both buttons, not
    /// only the one that used to compare against the unknown maximum read as 0.
    func testLPBarStepLeavesCurrentLEUnchangedWhenLeMaxIsUnknown() {
        var currentLE = 10
        if let next = LEWrite.stepped(current: currentLE, by: -1, leMax: nil) { currentLE = next }
        if let next = LEWrite.stepped(current: currentLE, by: 1, leMax: nil) { currentLE = next }
        XCTAssertEqual(currentLE, 10)
    }

    func testSteppedStaysWithinRangeWhenKnown() {
        XCTAssertEqual(LEWrite.stepped(current: 5, by: 1, leMax: 10), 6)
        XCTAssertEqual(LEWrite.stepped(current: 5, by: -1, leMax: 10), 4)
        XCTAssertNil(LEWrite.stepped(current: 10, by: 1, leMax: 10), "at the maximum already")
        XCTAssertNil(LEWrite.stepped(current: 0, by: -1, leMax: 10), "at zero already")
    }

    // MARK: - Pure helper: undo

    func testUndoneRestoresTheLoggedValueUnclampedWhenLeMaxIsUnknown() {
        // A damage entry of 20 (`lpChange: -20`) undone from current 5: the hero was at 25
        // before it landed. The old code's `min(max(reversed, 0), SheetValues... ?? 0)` forced
        // this to 0; the fix only clamps the lower bound (LE cannot go negative).
        XCTAssertEqual(LEWrite.undone(current: 5, lpChange: -20, leMax: nil), 25)
    }

    func testUndoneStillClampsBelowZeroWhenLeMaxIsUnknown() {
        // A heal of 10 undone from current 2 would go to -8; that clamp is real (LE cannot be
        // negative) and has nothing to do with the maximum being unknown.
        XCTAssertEqual(LEWrite.undone(current: 2, lpChange: 10, leMax: nil), 0)
    }

    func testUndoneClampsToLeMaxWhenKnown() {
        XCTAssertEqual(LEWrite.undone(current: 5, lpChange: -20, leMax: 22), 22)
    }

    // MARK: - The real, un-mocked seam: a hero the engine cannot compute leMax for

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Hero.self, HeroStateEntry.self, PersonalData.self, Experience.self,
            Attributes.self, DerivedValues.self, Talent.self, CombatTechnique.self,
            MeleeWeapon.self, RangedWeapon.self, Armor.self, Shield.self,
            EquipmentItem.self, Money.self, Pet.self, Language.self,
            HeroSpell.self, LogEntry.self, Adventure.self, WeatherDay.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    /// A hero with no `Attributes` and no species LE: `kampfwerte`'s `leMax` formula sums
    /// `attr.KO` and `species.le`, both missing facts, so the engine's `sum` — nil when any
    /// part is unknown (`Values.operand`) — leaves `leMax.result` nil exactly the way the
    /// rules-not-loaded case does. `CommandRegistryStatesTests` already relies on the same
    /// bare-hero shape (`SheetValues.of(hero)?.leMax.result ?? 0`).
    private func heroWithUnresolvableLeMax(current: Int, ctx: ModelContext) -> Hero {
        let hero = Hero(name: "Nobody"); ctx.insert(hero)
        let dv = DerivedValues(
            lebensenergie: LifeEnergyValue(base: 0, bonus: 0, purchased: 0, max: 0, current: current),
            astralenergie: nil, karmaenergie: nil,
            seelenkraft: ResourceValue(base: 0, bonus: 0, max: 0),
            zaehigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            geschwindigkeit: ResourceValue(base: 8, bonus: 0, max: 8),
            schicksalspunkte: MutableResourceValue(current: 0, bonus: 0, max: 0)
        )
        ctx.insert(dv)
        hero.derivedValues = dv
        return hero
    }

    func testTheBareHeroReallyHasNoResolvableLeMax() throws {
        let ctx = try makeContext()
        let hero = heroWithUnresolvableLeMax(current: 5, ctx: ctx)
        XCTAssertNil(SheetValues.of(hero)?.leMax.result)
    }

    func testHealingPayloadUndoRestoresWithoutClampingToZero() throws {
        let ctx = try makeContext()
        let hero = heroWithUnresolvableLeMax(current: 5, ctx: ctx)
        // 20 LP were healed to reach 5 from an original -15? No — reverse subtracts the change:
        // current 5, lpRestored 20 → the hero was at -15 before, clamped to 0 below. Use a
        // damage-shaped reversal instead so the interesting (non-zero) branch is exercised.
        let payload = HealingPayload(source: "Test", lpRestored: -20)
        payload.reverse(on: hero)
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 25, "reversed to 5 - (-20) = 25, unclamped")
    }

    func testRestPayloadUndoRestoresWithoutClampingToZero() throws {
        let ctx = try makeContext()
        let hero = heroWithUnresolvableLeMax(current: 5, ctx: ctx)
        let payload = RestPayload(lpRestored: -20, duration: nil)
        payload.reverse(on: hero)
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 25)
    }

    func testCombatActionPayloadUndoRestoresWithoutClampingToZero() throws {
        let ctx = try makeContext()
        let hero = heroWithUnresolvableLeMax(current: 5, ctx: ctx)
        let payload = CombatActionPayload(
            combatId: UUID(), round: 1, action: .damageTaken,
            weaponName: nil, rollValue: nil, damageDealt: nil, damageTaken: nil,
            lpChange: -20
        )
        payload.reverse(on: hero)
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 25)
    }

    func testUndoStillClampsBelowZeroOnTheRealSeam() throws {
        let ctx = try makeContext()
        let hero = heroWithUnresolvableLeMax(current: 2, ctx: ctx)
        let payload = HealingPayload(source: "Test", lpRestored: 10)
        payload.reverse(on: hero)
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 0)
    }
}
