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
        XCTAssertEqual(hero.fokusRules, [])
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
        XCTAssertEqual(hero.fokusRules, ["trefferzonen"])
    }

    /// The Fokus-Regeln are the table's house rules, not a per-fight choice: ending a
    /// combat must leave them exactly as the player set them on the hero settings
    /// screen. (This assertion is deliberately the inverse of the original one, which
    /// wiped them — that was the bug.)
    func testClearCombatSessionKeepsFokusRules() {
        let hero = makeHero()
        hero.setFokusRule(.trefferzonen, active: true)
        hero.activeCombatRound = 3

        hero.clearCombatSession()

        XCTAssertEqual(hero.fokusRules, ["trefferzonen"], "house rules outlive a combat")
        XCTAssertTrue(hero.isFokusRuleActive(.trefferzonen))
        XCTAssertEqual(hero.activeCombatRound, 0, "combat session state is still cleared")
    }

    /// A second combat starts with the rules the group plays with, without the player
    /// re-enabling them on the way in.
    func testRulesSurviveARepeatedCombatCycle() {
        let hero = makeHero()
        hero.setFokusRule(.trefferzonen, active: true)
        for _ in 0..<3 { hero.clearCombatSession() }
        XCTAssertTrue(hero.isFokusRuleActive(.trefferzonen))
    }

    /// Two heroes at the same table may play with different rules — activation is
    /// per hero, so it must not leak between them.
    func testActivationIsPerHero() {
        let hero = makeHero()
        let other = makeHero()
        hero.setFokusRule(.trefferzonen, active: true)
        XCTAssertTrue(hero.isFokusRuleActive(.trefferzonen))
        XCTAssertFalse(other.isFokusRuleActive(.trefferzonen))
    }

    /// C1 premise: the ordinary hero — no Plänkler-Formation, no mount — never reaches
    /// the combat *setup* screen, and the armour-selection step is no place for a
    /// setting either. The toggles now live on the hero settings screen, off the combat
    /// flow entirely; that placement is a view fact and is not unit-testable.
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
