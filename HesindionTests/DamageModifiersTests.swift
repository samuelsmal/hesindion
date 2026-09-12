import XCTest
import SwiftData
@testable import Hesindion

/// The TP the app can work out for itself. Each of these used to be folded into
/// a formula string by whichever screen remembered it — the grip by two of them,
/// Golgariten-Stil by none.
@MainActor
final class DamageModifiersTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
    }

    override func tearDown() {
        context = nil
        hero = nil
    }

    private func lines(maneuver: CombatManeuver = .normal, grip: Bool = false, mounted: Bool = false) -> [ModifierLine] {
        DamageModifiers.lines(hero: hero, maneuver: maneuver, twoHandedGrip: grip, mounted: mounted)
    }

    // MARK: - Nothing to add

    func testAPlainAttackAddsNothing() {
        XCTAssertTrue(lines().isEmpty)
        XCTAssertEqual(DamageModifiers.applied(to: "1W6+4", lines: lines()), "1W6+4")
    }

    func testAnActionThatDealsNoDamageStaysNil() {
        XCTAssertNil(DamageModifiers.applied(to: nil, lines: lines(grip: true)))
    }

    // MARK: - Wuchtschlag (SA_67)

    /// "Bei Erfolg werden die Trefferpunkte um 2 pro Stufe der Sonderfertigkeit
    /// erhöht."
    func testWuchtschlagAddsTwoTPPerTier() {
        XCTAssertEqual(DamageModifiers.total(lines(maneuver: .wuchtschlag(tier: 1))), 2)
        XCTAssertEqual(DamageModifiers.total(lines(maneuver: .wuchtschlag(tier: 2))), 4)
        XCTAssertEqual(DamageModifiers.total(lines(maneuver: .wuchtschlag(tier: 3))), 6)
        XCTAssertEqual(DamageModifiers.applied(to: "1W6+4", lines: lines(maneuver: .wuchtschlag(tier: 2))), "1W6+8")
    }

    /// The manoeuvres that cost AT but add no damage must not touch the formula.
    func testFinteAndVorstossAddNoTP() {
        XCTAssertTrue(lines(maneuver: .finte(tier: 2)).isEmpty)
        XCTAssertTrue(lines(maneuver: .vorstoss).isEmpty)
    }

    // MARK: - Two-handed grip

    /// Exactly once. The weapon list used to fold this in and the announcement
    /// screen folded it in again, so the button's "+1 TP" was worth +2.
    func testTheGripIsWorthOnePointOnce() {
        let l = lines(grip: true)
        XCTAssertEqual(l.count, 1)
        XCTAssertEqual(DamageModifiers.total(l), 1)
        XCTAssertEqual(DamageModifiers.applied(to: "1W6+4", lines: l), "1W6+5")
    }

    func testTheGripStacksWithWuchtschlag() {
        XCTAssertEqual(
            DamageModifiers.applied(to: "1W6+4", lines: lines(maneuver: .wuchtschlag(tier: 1), grip: true)),
            "1W6+7")
    }

    // MARK: - Golgariten-Stil (SA_661)

    /// "+1 TP bei Nahkampfangriffen, wenn er sich auf dem Rücken eines Reittiers
    /// befindet." The hero needs the style and the loadout it is written for.
    func testGolgaritenAddsOneTPFromHorseback() throws {
        let hero = try TestData.importBoronmir(into: TestData.makeContainer())
        hero.selectedWeaponName = "Rabenschnabel"
        hero.selectedShieldName = "Großschild"
        XCTAssertTrue(hero.hasGolgaritenStil, "the sample hero is the one with the style")

        let mounted = DamageModifiers.lines(hero: hero, maneuver: .normal, twoHandedGrip: false, mounted: true)
        XCTAssertEqual(DamageModifiers.total(mounted), 1)

        let afoot = DamageModifiers.lines(hero: hero, maneuver: .normal, twoHandedGrip: false, mounted: false)
        XCTAssertTrue(afoot.isEmpty, "on foot the style pays nothing")
    }

    func testGolgaritenNeedsTheStyleNotJustAMount() {
        XCTAssertTrue(lines(mounted: true).isEmpty)
    }

    // MARK: - Sturmangriff

    /// +2 plus half the mount's GS. Only for the charge itself.
    func testSturmangriffAddsTwoPlusHalfTheMountsSpeed() throws {
        let hero = try TestData.importBoronmir(into: TestData.makeContainer())
        let expected = hero.sturmangriffDamageBonus
        XCTAssertEqual(expected, 2 + hero.mountGS / 2)

        let charge = DamageModifiers.lines(hero: hero, maneuver: .sturmangriff, twoHandedGrip: false, mounted: true)
        XCTAssertEqual(charge.first { $0.source == L("source.sturmangriff") }?.value, expected)

        let walk = DamageModifiers.lines(hero: hero, maneuver: .normal, twoHandedGrip: false, mounted: true)
        XCTAssertNil(walk.first { $0.source == L("source.sturmangriff") })
    }
}
