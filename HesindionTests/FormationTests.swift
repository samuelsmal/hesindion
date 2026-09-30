import XCTest
import SwiftData
@testable import Hesindion

/// Issue #44: Formation (SA_862) beside Plänkler-Formation (SA_884). Rulings
/// SA_862.formation-mounted and SA_884.plaenkler-mounted: no formation while
/// mounted, and mounting mid-fight ends it — which the app says (ADR-0018).
final class FormationTests: XCTestCase {

    func testEachKindNamesItsRuleAndItsBonus() {
        XCTAssertEqual(FormationKind.formation.ruleId, "SA_862")
        XCTAssertEqual(FormationKind.plaenkler.ruleId, "SA_884")
        XCTAssertEqual(FormationKind.formation.bonusValue, 2)
        XCTAssertEqual(FormationKind.plaenkler.bonusValue, 1)
    }

    func testTheSummaryNamesEveryStandingFormationWithItsBonus() {
        XCTAssertNil(FormationKind.summary([:]))
        XCTAssertEqual(
            FormationKind.summary([.plaenkler: .aw, .formation: .at]),
            "\(L("formation")) +2 AT · \(L("plaenkler")) +1 VW",
            "Formation first, whatever the dictionary's order"
        )
    }

    func testMountingEndsEveryFormationAndSaysSo() {
        let toast = FormationKind.dissolvedByMounting([.formation: .at, .plaenkler: .aw])
        XCTAssertEqual(toast?.title, L("formation.dissolved"))
        XCTAssertEqual(toast?.lines, [
            "\(L("formation")) +2 AT",
            "\(L("plaenkler")) +1 VW",
            L("formation.onFootOnly"),
        ])
    }

    func testMountingWithoutAFormationSaysNothing() {
        XCTAssertNil(FormationKind.dissolvedByMounting([:]))
    }

    /// A resumed fight comes back with the formations it had, and a cleared
    /// session with none.
    @MainActor
    func testTheHeroKeepsTheFormationsOfTheFight() throws {
        let context = ModelContext(try TestData.makeContainer())
        let hero = Hero(name: "Test")
        context.insert(hero)
        XCTAssertEqual(hero.activeCombatFormations, [:])

        hero.activeCombatFormations = [.formation: .aw, .plaenkler: .at]
        XCTAssertEqual(hero.activeCombatFormations, [.formation: .aw, .plaenkler: .at])

        hero.clearCombatSession()
        XCTAssertEqual(hero.activeCombatFormations, [:])
    }
}
