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

    /// The Regelwiki gives the style +1 PA and nothing on TP; the +1 TP the
    /// app used to add came from Optolith's stale prose (catalog note, SA_661).
    func testGolgaritenAddsNoTP() {
        let golgarit = golgaritenHero()
        XCTAssertTrue(DamageModifiers.lines(hero: golgarit, maneuver: .normal, twoHandedGrip: false, mounted: true).isEmpty)
    }

    /// A mounted hero carrying the style's weapons, and nothing else switched on.
    private func golgaritenHero() -> Hero {
        let golgarit = Hero(name: "Golgarit")
        context.insert(golgarit)
        golgarit.combatSpecialAbilities = [HeroTrait(ruleId: "SA_661", name: "Golgariten-Stil")]
        golgarit.meleeWeapons = [
            MeleeWeapon(name: "Rabenschnabel", combatTechniqueId: "CT_5", damage: "1W6+4",
                        at: 12, pa: 8, reach: "Mittel", weight: 2),
        ]
        golgarit.shields = [
            Shield(name: "Großschild", damage: "1W6+1", at: 6, pa: 11,
                   reach: "Kurz", structurePoints: 30, weight: 6),
        ]
        golgarit.selectedWeaponName = "Rabenschnabel"
        golgarit.selectedShieldName = "Großschild"
        return golgarit
    }

    func testGolgaritenNeedsTheStyleNotJustAMount() {
        XCTAssertTrue(lines(mounted: true).isEmpty)
    }

    // MARK: - Sturmangriff

    /// +2 plus half the mount's GS. Only for the charge itself.
    func testSturmangriffAddsTwoPlusHalfTheMountsSpeed() {
        let rider = Hero(name: "Rider")
        context.insert(rider)
        rider.pets = [
            Pet(
                petId: "PET_1", name: "Kupperus", size: 1.9, type: "Pferd",
                attributes: PetAttributes(mu: 12, kl: 10, inValue: 12, ch: 12, ff: 8, ge: 15, ko: 24, kk: 25),
                lifeEnergy: 75, spirit: 0, toughness: 0,
                initiative: "14+1W6", speed: 12,
                attack: "Niederreiten", damage: "2W6+6", reach: "Mittel",
                actions: 1, talents: "", skills: "", notes: ""
            )
        ]
        XCTAssertEqual(rider.sturmangriffDamageBonus, 2 + 12 / 2)

        let charge = DamageModifiers.lines(hero: rider, maneuver: .sturmangriff, twoHandedGrip: false, mounted: true)
        XCTAssertEqual(charge.first { $0.source == L("source.sturmangriff") }?.value, 8)

        let walk = DamageModifiers.lines(hero: rider, maneuver: .normal, twoHandedGrip: false, mounted: true)
        XCTAssertNil(walk.first { $0.source == L("source.sturmangriff") })
    }
}
