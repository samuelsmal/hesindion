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
}
