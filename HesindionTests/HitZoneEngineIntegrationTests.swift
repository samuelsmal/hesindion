import XCTest
import SwiftData
@testable import Hesindion

/// Proves `HitZoneModifiers` is actually registered in `ModifierEngine.shared`, going
/// through the real engine rather than calling `HitZoneModifiers.zonenaufschlag.evaluate`
/// directly (see `HitZoneModifiersTests`). If the registration line were ever removed,
/// this test would fail while the direct-call tests would keep passing.
final class HitZoneEngineIntegrationTests: XCTestCase {
    private func makeHero() -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self,
            configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        return hero
    }

    func testMeleeAttackWithKopfZoneAppliesTenPenaltyViaSharedEngine() {
        let hero = makeHero()
        var context = Situation(hero: hero, domain: .meleeAttack)
        context.targetHitZone = .kopf
        let lines = ModifierEngine.shared.evaluate(context: context)
        XCTAssertTrue(lines.contains { $0.value == -10 }, "expected a -10 Trefferzone line, got \(lines)")
    }

    func testRangedAttackWithKopfZoneAppliesTenPenaltyViaSharedEngine() {
        let hero = makeHero()
        var context = Situation(hero: hero, domain: .rangedAttack)
        context.targetHitZone = .kopf
        let lines = ModifierEngine.shared.evaluate(context: context)
        XCTAssertTrue(lines.contains { $0.value == -10 }, "expected a -10 Trefferzone line, got \(lines)")
    }

    func testNoZoneSelectedProducesNoTrefferzoneLine() {
        let hero = makeHero()
        let context = Situation(hero: hero, domain: .meleeAttack)
        XCTAssertNil(context.targetHitZone)
        let lines = ModifierEngine.shared.evaluate(context: context)
        XCTAssertFalse(lines.contains { $0.source.contains(L("modifier.trefferzone")) })
    }
}
