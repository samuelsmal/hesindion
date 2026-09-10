import XCTest
import SwiftData
@testable import Hesindion

final class DerivedValueRepairTests: XCTestCase {

    /// Hero with KO 11, GE 13, MU 12 and the OLD truncated values stored.
    private func makeStaleHero() -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self, Attributes.self,
            configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T")
        hero.attributes = Attributes(mu: 12, kl: 10, inValue: 10, ch: 10, ff: 10, ge: 13, ko: 11, kk: 10)
        hero.derivedValues = DerivedValues(
            lebensenergie: LifeEnergyValue(base: 27, bonus: 0, purchased: 0, max: 27, current: 27),
            astralenergie: nil, karmaenergie: nil,
            seelenkraft: ResourceValue(base: 1, bonus: 0, max: 1),
            zaehigkeit: ResourceValue(base: 1, bonus: 0, max: 1),
            ausweichen: ComputedValue(value: 6, bonus: 0, max: 6),      // stale: 13/2 = 6
            initiative: ComputedValue(value: 12, bonus: 0, max: 12),    // stale: 25/2 = 12
            geschwindigkeit: ResourceValue(base: 8, bonus: 0, max: 8),
            wundschwelle: ComputedValue(value: 5, bonus: 0, max: 5),    // stale: 11/2 = 5
            schicksalspunkte: MutableResourceValue(current: 3, bonus: 0, max: 3)
        )
        ctx.insert(hero)
        return hero
    }

    func testRepairCorrectsAllThree() {
        let hero = makeStaleHero()
        XCTAssertTrue(DerivedValueRepair.repair(hero))
        XCTAssertEqual(hero.derivedValues?.wundschwelle.max, 6)
        XCTAssertEqual(hero.derivedValues?.ausweichen.max, 7)
        XCTAssertEqual(hero.derivedValues?.initiative.max, 13)
    }

    func testRepairIsIdempotent() {
        let hero = makeStaleHero()
        XCTAssertTrue(DerivedValueRepair.repair(hero))
        XCTAssertFalse(DerivedValueRepair.repair(hero), "second run must report no change")
        XCTAssertEqual(hero.derivedValues?.wundschwelle.max, 6)
    }

    func testRepairLeavesLifeAndResourcesAlone() {
        let hero = makeStaleHero()
        let lpBefore = hero.derivedValues?.lebensenergie.max
        let skBefore = hero.derivedValues?.seelenkraft.max
        let zkBefore = hero.derivedValues?.zaehigkeit.max
        _ = DerivedValueRepair.repair(hero)
        XCTAssertEqual(hero.derivedValues?.lebensenergie.max, lpBefore)
        XCTAssertEqual(hero.derivedValues?.seelenkraft.max, skBefore)
        XCTAssertEqual(hero.derivedValues?.zaehigkeit.max, zkBefore)
    }

    func testHeroWithoutDerivedValuesIsSkipped() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Hero.self, HeroStateEntry.self, configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        XCTAssertFalse(DerivedValueRepair.repair(hero))
    }
}
