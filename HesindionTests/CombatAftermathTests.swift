import XCTest
import SwiftData
@testable import Hesindion

/// What the screen after "Kampf beenden" is about.
///
/// The list is the whole decision — whether the screen appears at all, which
/// rows offer a control and which only report — so it is a value the view reads
/// rather than three computed properties on the view itself.
@MainActor
final class CombatAftermathTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Nach dem Kampf")
        context.insert(hero)
        hero.activeCombatId = UUID()
        hero.activeCombatRound = 3
    }

    override func tearDown() { context = nil; hero = nil }

    /// A fight that left nothing behind ends the way it always did: no screen,
    /// no confirmation, straight out.
    func testAFightThatLeftNothingBehindShowsNoScreen() {
        XCTAssertTrue(CombatAftermath(hero: hero).isEmpty)
        XCTAssertTrue(CombatAftermath(hero: hero).clearable.isEmpty)
        XCTAssertTrue(CombatAftermath(hero: hero).damagedItems.isEmpty)
    }

    /// Everything `setStateLevel` can change is offered, with the level the
    /// fight ended on.
    func testEveryManuallyTrackedStateIsOffered() {
        hero.setStateLevel("liegend", level: 1)
        hero.setStateLevel("betaeubung", level: 2)

        let aftermath = CombatAftermath(hero: hero)
        XCTAssertFalse(aftermath.isEmpty)
        XCTAssertEqual(Set(aftermath.clearable.map(\.id)), ["liegend", "betaeubung"])
        XCTAssertEqual(aftermath.clearable.first { $0.id == "betaeubung" }?.level, 2)
        XCTAssertEqual(aftermath.clearable.first { $0.id == "liegend" }?.level, 1)
    }

    /// `eingeengt` is the Beengte-Umgebung toggle's storage, and nothing in the
    /// combat flow ever turns it off again — the one state most likely to be
    /// still on when a fight ends. It is a Status like any other here.
    func testTheBeengteUmgebungStatusIsOnTheList() {
        hero.setStateLevel("eingeengt", level: 1)
        let aftermath = CombatAftermath(hero: hero)
        XCTAssertEqual(aftermath.clearable.map(\.id), ["eingeengt"])
        XCTAssertFalse(aftermath.isEmpty)
    }

    /// Schmerz and Belastung are derived, `setStateLevel` refuses them, and a
    /// control on them here would promise something it could not do. They are
    /// shown — and, on their own, are not a reason to show the screen at all.
    func testTheDerivedStatesAreShownButNeverOffered() throws {
        hero.derivedValues = DerivedValues(
            lebensenergie: LifeEnergyValue(base: 20, bonus: 0, purchased: 0, max: 20, current: 10),
            astralenergie: nil, karmaenergie: nil,
            seelenkraft: ResourceValue(base: 0, bonus: 0, max: 0),
            zaehigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            ausweichen: ComputedValue(value: 0, bonus: 0, max: 0),
            initiative: ComputedValue(value: 0, bonus: 0, max: 0),
            geschwindigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            wundschwelle: ComputedValue(value: 0, bonus: 0, max: 0),
            schicksalspunkte: MutableResourceValue(current: 0, bonus: 0, max: 0))
        XCTAssertEqual(hero.effectiveSchmerzLevel, 2, "precondition: half the LP gone")

        let aftermath = CombatAftermath(hero: hero)
        XCTAssertEqual(aftermath.derived.map(\.id), ["schmerz"])
        XCTAssertEqual(aftermath.derived.first?.level, 2)
        XCTAssertTrue(aftermath.clearable.isEmpty)
        XCTAssertTrue(
            aftermath.isEmpty,
            "a screen whose every row is read-only only asks the player to press Fertig")
    }

    /// A Patzer's dent outlives the fight and is repaired on the settings screen,
    /// not here — but it is worth saying while the player is taking stock, and it
    /// is reason enough to stop.
    func testADamagedItemIsReportedAndIsReasonEnoughToStop() {
        hero.setItemDamaged("Langschwert", true)
        let aftermath = CombatAftermath(hero: hero)
        XCTAssertEqual(aftermath.damagedItems, ["Langschwert"])
        XCTAssertTrue(aftermath.clearable.isEmpty)
        XCTAssertFalse(aftermath.isEmpty)
    }

    /// The screen's own writes are `setStateLevel`'s, so what it can undo is
    /// exactly what it did: clearing and restoring a row leaves the hero where
    /// the fight left them.
    func testClearingAndRestoringARowIsReversible() {
        hero.setStateLevel("betaeubung", level: 3)
        let row = CombatAftermath(hero: hero).clearable.first { $0.id == "betaeubung" }
        XCTAssertEqual(row?.level, 3)

        hero.setStateLevel("betaeubung", level: 0)
        XCTAssertEqual(hero.level(of: "betaeubung"), 0)

        hero.setStateLevel("betaeubung", level: row?.level ?? 0)
        XCTAssertEqual(hero.level(of: "betaeubung"), 3, "the row remembers what the fight ended on")
    }

    // MARK: - Where the Schmerz comes from

    /// Life points, out of `max`, with `current` left.
    private func giveLifePoints(current: Int, max: Int) {
        hero.derivedValues = DerivedValues(
            lebensenergie: LifeEnergyValue(base: max, bonus: 0, purchased: 0, max: max, current: current),
            astralenergie: nil, karmaenergie: nil,
            seelenkraft: ResourceValue(base: 0, bonus: 0, max: 0),
            zaehigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            ausweichen: ComputedValue(value: 0, bonus: 0, max: 0),
            initiative: ComputedValue(value: 0, bonus: 0, max: 0),
            geschwindigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            wundschwelle: ComputedValue(value: 0, bonus: 0, max: 0),
            schicksalspunkte: MutableResourceValue(current: 0, bonus: 0, max: 0))
    }

    /// Nothing but the LP thresholds: one row, and healing is what ends it.
    func testSchmerzFromTheLifePointsAloneIsOneOriginThatHealingEnds() {
        giveLifePoints(current: 14, max: 31)
        let breakdown = hero.schmerzBreakdown

        XCTAssertEqual(breakdown.parts.map(\.origin), [.lebenspunkte])
        XCTAssertEqual(breakdown.parts.first?.level, 2, "half the LP gone is Schmerz II")
        XCTAssertEqual(breakdown.currentLP, 14)
        XCTAssertEqual(breakdown.maxLP, 31)
        XCTAssertFalse(breakdown.parts[0].origin.endsWithTheFight, "healing ends it, not the fight")
        XCTAssertEqual(breakdown.raw, 2)
        XCTAssertEqual(breakdown.effective, hero.effectiveSchmerzLevel)
        XCTAssertFalse(breakdown.needsCorrectionNote, "the row adds up to the chip on its own")
    }

    /// The Patzertabelle's level is the second origin, and it is the one this
    /// very screen ends: "Fertig" clears the session it hangs off.
    func testThePatzerLevelIsItsOwnOriginAndEndsWithTheFight() {
        giveLifePoints(current: 14, max: 31)
        hero.addTemporarySchmerz(rolledInRound: hero.activeCombatRound)

        let breakdown = hero.schmerzBreakdown
        XCTAssertEqual(breakdown.parts.map(\.origin), [.lebenspunkte, .patzer])
        XCTAssertEqual(breakdown.parts.map(\.level), [2, 1])
        XCTAssertTrue(breakdown.parts[1].origin.endsWithTheFight)
        XCTAssertEqual(breakdown.levelAfterTheFight(for: .patzer), 0, "the session takes it with it")
        XCTAssertEqual(breakdown.levelAfterTheFight(for: .lebenspunkte), 2)
        XCTAssertEqual(breakdown.raw, 3)
        XCTAssertEqual(breakdown.effective, hero.effectiveSchmerzLevel)
        XCTAssertEqual(breakdown.effective, 3)
        XCTAssertFalse(breakdown.needsCorrectionNote)

        hero.clearCombatSession()
        XCTAssertEqual(hero.schmerzBreakdown.parts.map(\.origin), [.lebenspunkte],
                       "\"Fertig\" is what the struck-through row promised")
    }

    /// Zäher Hund takes a level off the *sum*, so the rows stop adding up to the
    /// chip and the screen owes the reader the reason.
    func testZaeherHundIsACorrectionOnTheSumAndNotAThirdOrigin() {
        giveLifePoints(current: 14, max: 31)
        hero.advantages = [HeroTrait(ruleId: "ADV_49", name: "Zäher Hund", tier: nil, sid: nil)]

        let breakdown = hero.schmerzBreakdown
        XCTAssertEqual(breakdown.parts.map(\.origin), [.lebenspunkte], "the advantage is not an origin")
        XCTAssertEqual(breakdown.raw, 2)
        XCTAssertEqual(breakdown.effective, 1)
        XCTAssertEqual(breakdown.effective, hero.effectiveSchmerzLevel)
        XCTAssertTrue(breakdown.zaeherHundApplied)
        XCTAssertFalse(breakdown.cappedAtFour)
        XCTAssertTrue(breakdown.needsCorrectionNote)
    }

    /// And the cap at IV is the other one. Past it Zäher Hund does not apply at
    /// all, which is what `effectiveSchmerzLevel` does and what the rows must say.
    func testTheCapAtFourIsTheOtherCorrection() {
        giveLifePoints(current: 3, max: 31)   // ¼ and ≤5 LP: four levels from the LP alone
        hero.addTemporarySchmerz(rolledInRound: hero.activeCombatRound)
        hero.advantages = [HeroTrait(ruleId: "ADV_49", name: "Zäher Hund", tier: nil, sid: nil)]

        let breakdown = hero.schmerzBreakdown
        XCTAssertEqual(breakdown.parts.map(\.level), [4, 1])
        XCTAssertEqual(breakdown.raw, 5)
        XCTAssertEqual(breakdown.effective, 4)
        XCTAssertEqual(breakdown.effective, hero.effectiveSchmerzLevel)
        XCTAssertTrue(breakdown.cappedAtFour)
        XCTAssertFalse(breakdown.zaeherHundApplied, "past the cap the advantage buys nothing")
        XCTAssertTrue(breakdown.needsCorrectionNote)
    }

    /// No Schmerz at all is no rows and no correction note — the screen has
    /// nothing to say, and says nothing.
    func testAHeroWithoutSchmerzHasNoOrigins() {
        giveLifePoints(current: 31, max: 31)
        let breakdown = hero.schmerzBreakdown
        XCTAssertTrue(breakdown.parts.isEmpty)
        XCTAssertEqual(breakdown.raw, 0)
        XCTAssertEqual(breakdown.effective, 0)
        XCTAssertFalse(breakdown.needsCorrectionNote)
    }
}
