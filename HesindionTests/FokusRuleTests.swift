import XCTest
import SwiftData
@testable import Hesindion

final class FokusRuleTests: XCTestCase {

    private func makeHero() -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Hero.self, HeroStateEntry.self, configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        return hero
    }

    func testDefaultsToNoRulesActive() {
        let hero = makeHero()
        XCTAssertEqual(hero.activeCombatFokusRules, [])
        XCTAssertFalse(hero.isFokusRuleActive(.trefferzonen))
    }

    func testToggleRoundTrips() {
        let hero = makeHero()
        hero.setFokusRule(.trefferzonen, active: true)
        XCTAssertTrue(hero.isFokusRuleActive(.trefferzonen))
        hero.setFokusRule(.trefferzonen, active: false)
        XCTAssertFalse(hero.isFokusRuleActive(.trefferzonen))
    }

    func testEnablingTwiceDoesNotDuplicate() {
        let hero = makeHero()
        hero.setFokusRule(.trefferzonen, active: true)
        hero.setFokusRule(.trefferzonen, active: true)
        XCTAssertEqual(hero.activeCombatFokusRules, ["trefferzonen"])
    }

    func testClearCombatSessionResetsRules() {
        let hero = makeHero()
        hero.setFokusRule(.trefferzonen, active: true)
        hero.clearCombatSession()
        XCTAssertEqual(hero.activeCombatFokusRules, [])
    }

    /// C1 premise: the ordinary hero — no Plänkler-Formation, no mount — never reaches
    /// the combat *setup* screen, which is why the Fokus-Regeln toggles cannot live
    /// there. They now sit on the armour-selection step, the unconditional first step of
    /// every combat; that placement is a view fact and is not unit-testable.
    func testOrdinaryHeroNeverSeesTheCombatSetupScreen() {
        let hero = makeHero()
        XCTAssertFalse(hero.hasPlaenklerFormation)
        XCTAssertFalse(hero.hasMount)
        XCTAssertFalse(hero.needsCombatSetup)
    }

    /// Every case must carry resolvable strings, so adding a rule cannot silently
    /// ship an untranslated toggle.
    func testEveryRuleIsLocalized() {
        for rule in FokusRule.allCases {
            XCTAssertNotEqual(L(rule.nameKey), rule.nameKey)
            XCTAssertNotEqual(L(rule.subtitleKey), rule.subtitleKey)
        }
    }
}
