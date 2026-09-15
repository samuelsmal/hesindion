import XCTest
import SwiftData
@testable import Hesindion

/// Design §6: hero, loadout, Situation, answers → lines, opponent lines,
/// offers, questions, not-applied. Every reviewed exemplar the catalog gains
/// gets a row here. These run against the bundled `rules.db`, so they also
/// hold the compiled clauses to what the YAML says.
@MainActor
final class RuleFixtureTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
    }

    override func tearDown() { context = nil; hero = nil }

    // MARK: - Helpers

    private func own(_ id: String, _ name: String, tier: Int? = nil, list: WritableKeyPath<Hero, [HeroTrait]> = \.combatSpecialAbilities) {
        hero[keyPath: list].append(HeroTrait(ruleId: id, name: name, tier: tier, sid: nil))
    }

    @discardableResult
    private func arm(_ name: String, technique: String, reach: String, select: Bool = true) -> MeleeWeapon {
        let weapon = MeleeWeapon(name: name, combatTechniqueId: technique, damage: "1W6+3", at: 12, pa: 8, reach: reach, weight: 1.5)
        hero.meleeWeapons.append(weapon)
        if select { hero.selectedWeaponName = name }
        return weapon
    }

    private func lines(_ s: Situation) -> [ModifierLine] { ModifierEngine.shared.evaluate(context: s) }
    private func evaluation(_ s: Situation) -> Evaluation { ModifierEngine.shared.evaluation(s) }
    private func value(_ ruleId: String, in lines: [ModifierLine]) -> Int? { lines.first { $0.ruleId == ruleId }?.value }
    private func reason(_ ruleId: String, in e: Evaluation) -> NotApplied.Reason? { e.notApplied.first { $0.ruleId == ruleId }?.reason }

    private func defence(_ domain: RuleDomain, parries: Int = 0, dodges: Int = 0) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.round.parriesThisRound = parries
        s.round.dodgesThisRound = dodges
        return s
    }

    // MARK: - Mehrfache Verteidigung (GRW)

    func testMehrfacheVerteidigungIsMinusThreePerDefenceOfTheSameKind() {
        XCTAssertNil(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry))))
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 1))), -3)
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 3))), -9)
        XCTAssertNil(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeDodge, parries: 2))), "the first dodge is free however often the hero parried")
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeDodge, dodges: 1))), -3)
    }

    // MARK: - Vinsalt-Stil (SA_923)

    func testVinsaltStilSetsTheStepToTwoWithAFechtwaffeInHand() {
        own("SA_923", "Vinsalt-Stil")
        arm("Rapier", technique: "CT_4", reach: "Mittel")
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 1))), -2)
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 2))), -4)
        XCTAssertTrue(evaluation(defence(.meleeParry, parries: 1)).applied.contains("SA_923"))
    }

    func testVinsaltStilNeedsItsWeaponAndSomethingToModify() {
        own("SA_923", "Vinsalt-Stil")
        arm("Langschwert", technique: "CT_12", reach: "Lang")
        let sword = evaluation(defence(.meleeParry, parries: 1))
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 1))), -3)
        XCTAssertEqual(reason("SA_923", in: sword), .conditionFalse)
        arm("Rapier", technique: "CT_4", reach: "Mittel")
        XCTAssertEqual(reason("SA_923", in: evaluation(defence(.meleeParry))), .modifiedRuleNotInEffect, "no second defence yet")
    }

    // MARK: - Reichweite (GRW)

    func testTheShorterWeaponPaysForReach() {
        arm("Dolch", technique: "CT_3", reach: "Kurz")
        arm("Säbel", technique: "CT_12", reach: "Mittel", select: false)
        arm("Speer", technique: "CT_13", reach: "Lang", select: false)
        let expected: [String: [WeaponReach: Int?]] = [
            "Dolch": [.kurz: nil, .mittel: -2, .lang: -4],
            "Säbel": [.kurz: nil, .mittel: nil, .lang: -2],
            "Speer": [.kurz: nil, .mittel: nil, .lang: nil],
        ]
        for (weapon, row) in expected {
            for (opponent, penalty) in row {
                var s = Situation(hero: hero, domain: .meleeAttack)
                s.loadoutName = weapon
                s.opponents.current.reach = opponent
                XCTAssertEqual(value("GRW_reichweite", in: lines(s)), penalty, "\(weapon) against \(opponent.rawValue)")
            }
        }
    }

    // MARK: - Beengte Umgebung (GRW)

    func testBeengteUmgebungFollowsTheReachOfThePieceInHandOnAttackAndParry() {
        arm("Speer", technique: "CT_13", reach: "Lang")
        arm("Säbel", technique: "CT_12", reach: "Mittel", select: false)
        arm("Dolch", technique: "CT_3", reach: "Kurz", select: false)
        func penalty(_ domain: RuleDomain, _ loadout: String?) -> Int? {
            var s = Situation(hero: hero, domain: domain)
            s.round.beengteUmgebung = true
            s.loadoutName = loadout
            return value("GRW_beengteUmgebung", in: lines(s))
        }
        XCTAssertEqual(penalty(.meleeAttack, "Speer"), -8)
        XCTAssertEqual(penalty(.meleeParry, "Speer"), -8)
        XCTAssertEqual(penalty(.meleeAttack, "Säbel"), -4)
        XCTAssertEqual(penalty(.meleeParry, nil), -8, "nothing named: the main weapon, the Speer")
        XCTAssertNil(penalty(.meleeAttack, "Dolch"))
        XCTAssertNil(penalty(.meleeAttack, "Raufen"), "bare hands are kurz")
        XCTAssertNil(penalty(.meleeDodge, "Speer"), "a dodge is not a parry")
        var calm = Situation(hero: hero, domain: .meleeAttack)
        calm.loadoutName = "Speer"
        XCTAssertNil(value("GRW_beengteUmgebung", in: lines(calm)))
    }
}
