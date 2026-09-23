import XCTest
import SwiftData
@testable import Hesindion

/// Proves the `GRW_zonenaufschlag` catalog entry is bundled in `rules.db` and reachable
/// through `ModifierEngine.shared`, going through the real engine rather than exercising
/// the compiled clause in isolation (see `HitZoneModifiersTests` for the pure `penalty`
/// table the zone picker's chips use). Skips, rather than fails, when the database is
/// unavailable.
final class HitZoneEngineIntegrationTests: XCTestCase {
    private func makeHero() -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self,
            configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        hero.setFokusRule(.trefferzonen, active: true)
        return hero
    }

    func testMeleeAttackWithKopfZoneAppliesTenPenaltyViaSharedEngine() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        let hero = makeHero()
        var context = Situation(hero: hero, domain: .meleeAttack)
        context.targetHitZone = .kopf
        let lines = ModifierEngine.shared.evaluate(context: context)
        XCTAssertTrue(lines.first { $0.ruleId == "GRW_zonenaufschlag" }?.value == -10, "expected a -10 Trefferzone line, got \(lines)")
    }

    func testRangedAttackWithKopfZoneAppliesTenPenaltyViaSharedEngine() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        let hero = makeHero()
        var context = Situation(hero: hero, domain: .rangedAttack)
        context.targetHitZone = .kopf
        let lines = ModifierEngine.shared.evaluate(context: context)
        XCTAssertTrue(lines.first { $0.ruleId == "GRW_zonenaufschlag" }?.value == -10, "expected a -10 Trefferzone line, got \(lines)")
    }

    func testNoZoneSelectedProducesNoTrefferzoneLine() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        let hero = makeHero()
        let context = Situation(hero: hero, domain: .meleeAttack)
        XCTAssertNil(context.targetHitZone)
        let lines = ModifierEngine.shared.evaluate(context: context)
        XCTAssertFalse(lines.contains { $0.ruleId == "GRW_zonenaufschlag" })
    }
}
