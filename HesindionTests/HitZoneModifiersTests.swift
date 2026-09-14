import XCTest
import SwiftData
@testable import Hesindion

final class HitZoneModifiersTests: XCTestCase {

    func testBasePenalties() {
        XCTAssertEqual(HitZoneModifiers.penalty(for: .kopf,  hasSonderfertigkeit: false, targetIsSurprised: false), -10)
        XCTAssertEqual(HitZoneModifiers.penalty(for: .torso, hasSonderfertigkeit: false, targetIsSurprised: false), -4)
        XCTAssertEqual(HitZoneModifiers.penalty(for: .arme,  hasSonderfertigkeit: false, targetIsSurprised: false), -8)
        XCTAssertEqual(HitZoneModifiers.penalty(for: .beine, hasSonderfertigkeit: false, targetIsSurprised: false), -8)
    }

    /// Halving is only safe while every base value is even.
    func testAllBasePenaltiesAreEven() {
        for zone in HitZone.allCases {
            let base = HitZoneModifiers.penalty(for: zone, hasSonderfertigkeit: false, targetIsSurprised: false)
            XCTAssertTrue(base.isMultiple(of: 2), "\(zone) base \(base) is odd — halving needs a rounding rule")
        }
    }

    func testSonderfertigkeitHalves() {
        XCTAssertEqual(HitZoneModifiers.penalty(for: .kopf, hasSonderfertigkeit: true, targetIsSurprised: false), -5)
        XCTAssertEqual(HitZoneModifiers.penalty(for: .arme, hasSonderfertigkeit: true, targetIsSurprised: false), -4)
    }

    func testSurprisedEasesByTwo() {
        XCTAssertEqual(HitZoneModifiers.penalty(for: .kopf,  hasSonderfertigkeit: false, targetIsSurprised: true), -8)
        XCTAssertEqual(HitZoneModifiers.penalty(for: .torso, hasSonderfertigkeit: false, targetIsSurprised: true), -2)
    }

    /// The spec's worked example.
    func testCombinedKopf() {
        XCTAssertEqual(HitZoneModifiers.penalty(for: .kopf, hasSonderfertigkeit: true, targetIsSurprised: true), -3)
    }

    func testNeverBecomesABonus() {
        for zone in HitZone.allCases {
            let p = HitZoneModifiers.penalty(for: zone, hasSonderfertigkeit: true, targetIsSurprised: true)
            XCTAssertLessThanOrEqual(p, 0, "\(zone) produced a bonus")
        }
    }

    /// In-memory hero, mirroring `StateModifiersTests.makeHero`. `TestData` lives in
    /// the Snapshots folder and offers only `makeContainer` / `importBoronmir`.
    private func makeHero() -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self, Attributes.self,
            configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        return hero
    }

    func testNoZoneProducesNoLine() {
        let hero = makeHero()
        var ctx = Situation(hero: hero, domain: .meleeAttack)
        ctx.targetHitZone = nil
        XCTAssertNil(HitZoneModifiers.zonenaufschlag.evaluate(ctx))
    }

    func testMeleeUsesSA160NotSA161() {
        let hero = makeHero()
        hero.combatSpecialAbilities = [HeroTrait(ruleId: "SA_161", name: "Gezielter Schuss", tier: nil, sid: nil)]
        var ctx = Situation(hero: hero, domain: .meleeAttack)
        ctx.targetHitZone = .kopf
        // Ranged SF must not halve a melee attack.
        XCTAssertEqual(HitZoneModifiers.zonenaufschlag.evaluate(ctx)?.value, -10)
    }
}
