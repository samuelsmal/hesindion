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
}
