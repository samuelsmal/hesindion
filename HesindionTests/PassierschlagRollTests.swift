import XCTest
import SwiftData
@testable import Hesindion

/// The Passierschlag screen's numbers: the weapon it was announced with, every
/// line the hero's modifiers make for it (the catalog's −4 among them), the
/// total the die is rolled against, and the TP.
@MainActor
final class PassierschlagRollTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
        hero.meleeWeapons.append(MeleeWeapon(name: "Säbel", combatTechniqueId: "CT_12", damage: "1W6+3", at: 14, pa: 8, reach: "Mittel", weight: 1))
        hero.meleeWeapons.append(MeleeWeapon(name: "Dolch", combatTechniqueId: "CT_3", damage: "1W6+1", at: 11, pa: 6, reach: "Mittel", weight: 1))
        hero.selectedWeaponName = "Säbel"
    }

    override func tearDown() { context = nil; hero = nil }

    private func roll(_ name: String? = nil, offHand: Bool = false, dualAttack: Bool = false) -> PassierschlagRoll {
        var round = CombatSituation()
        round.dualAttackActive = dualAttack
        var opponent = OpponentProfile()
        opponent.reach = .mittel   // same reach as both weapons: no GRW_reichweite line
        return PassierschlagRoll(hero: hero, round: round, opponent: opponent, weaponName: name, isOffHand: offHand)
    }

    private func sources(_ r: PassierschlagRoll) -> [String] { r.lines.map(\.source) }

    func testTheMainWeaponByDefault() {
        let r = roll()
        XCTAssertEqual(r.weaponName, "Säbel")
        XCTAssertEqual(r.rawAT, 14)
        XCTAssertEqual(r.lines.first { $0.ruleId == "GRW_passierschlag" }?.value, -4)
        XCTAssertEqual(r.effectiveAT, 10)
        XCTAssertEqual(r.effectiveDamage, "1W6+3")
    }

    func testTheOffHandWeaponWithItsPenalty() {
        let r = roll("Dolch", offHand: true)
        XCTAssertEqual(r.weaponName, "Dolch")
        XCTAssertEqual(r.rawAT, 11)
        XCTAssertTrue(sources(r).contains(L("source.offHand")), "the off-hand penalty belongs in the roll")
        XCTAssertEqual(r.effectiveAT, 11 - 4 + hero.offHandPenalty)
        XCTAssertEqual(r.effectiveDamage, "1W6+1")
    }

    func testTheShield() {
        hero.shields.append(Shield(name: "Holzschild", damage: "1W6", at: 7, pa: 1, paModifier: 1, note: "", reach: "Kurz", structurePoints: 12, weight: 3))
        let r = roll("Holzschild")
        XCTAssertEqual(r.weaponName, "Holzschild")
        XCTAssertEqual(r.rawAT, 7)
        XCTAssertEqual(r.lines.first { $0.ruleId == "GRW_passierschlag" }?.value, -4)
        XCTAssertEqual(r.effectiveDamage, "1W6")
    }

    func testBareHands() {
        hero.selectedWeaponName = "Raufen"
        let r = roll()
        XCTAssertEqual(r.weaponName, "Raufen")
        XCTAssertEqual(r.effectiveDamage, "1W6")
    }

    /// A Passierschlag is not a dual attack: the round's flag must not reach it.
    func testNoDualAttackPenalty() {
        let r = roll(dualAttack: true)
        XCTAssertFalse(sources(r).contains(L("source.dualAttack")))
        XCTAssertEqual(r.effectiveAT, 10)
    }
}
