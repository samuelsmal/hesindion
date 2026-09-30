import XCTest
import SwiftData
@testable import Hesindion

/// Issue #43: a check shows the value each die must meet after the modifiers (ADR-0018 §1), and
/// the GM-decided +2 of Aufmerksamkeit is an explicit choice, never silently in or out (§4).
final class SkillCheckTargetTests: XCTestCase {

    func testTheTargetIsTheAttributePlusItsStepperPlusEveryModifierLine() {
        let targets = SkillCheckModal.targetValues(
            attributes: [13, 14, 12],
            steppers: [0, 1, -2],
            lines: [ModifierLine(value: 2, source: "Aufmerksamkeit"), ModifierLine(value: -1, source: "Belastung")]
        )
        XCTAssertEqual(targets, [14, 16, 11])
    }

    func testWithNoModifiersTheTargetIsTheAttribute() {
        XCTAssertEqual(
            SkillCheckModal.targetValues(attributes: [13, 14, 12], steppers: [0, 0, 0], lines: []),
            [13, 14, 12]
        )
    }

    @MainActor
    func testAufmerksamkeitOffersPlusTwoOnSinnesschaerfe() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)  // has SA_40
        XCTAssertTrue(hero.hasAufmerksamkeit)
        let talent = Talent(ruleId: Talent.sinnesschaerfeRuleId, name: "Sinnesschärfe", value: 5, category: "")

        let bonus = TalentProbeModal.gmBonus(hero: hero, talent: talent)

        XCTAssertEqual(bonus?.value, 2)
        XCTAssertEqual(bonus?.ruleId, CombatAbility.aufmerksamkeit.rawValue)
    }

    @MainActor
    func testAufmerksamkeitOffersNothingOnAnotherTalent() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        let talent = Talent(ruleId: "TAL_8", name: "Selbstbeherrschung", value: 5, category: "")

        XCTAssertNil(TalentProbeModal.gmBonus(hero: hero, talent: talent))
    }

    @MainActor
    func testWithoutAufmerksamkeitSinnesschaerfeOffersNothing() throws {
        let container = try TestData.makeContainer()
        let hero = Hero(name: "T")
        container.mainContext.insert(hero)
        let talent = Talent(ruleId: Talent.sinnesschaerfeRuleId, name: "Sinnesschärfe", value: 5, category: "")

        XCTAssertNil(TalentProbeModal.gmBonus(hero: hero, talent: talent))
    }
}
