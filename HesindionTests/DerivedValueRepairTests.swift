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

    // MARK: - Geschwindigkeit (species rule, not a constant)
    //
    // The import wrote `base: 8` for every hero with the comment "GS = 8 (Mensch base)".
    // GS is keyed on species: the pinned Optolith source's `Data/univ/Races.yaml` carries
    // `mov` per race, and Zwerge are 6. The values below come from that file, not from the
    // code under test.

    private func makeHero(speciesId: String?, storedGS: Int) -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self, Attributes.self,
            PersonalData.self,
            configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T")
        hero.attributes = Attributes(mu: 12, kl: 10, inValue: 10, ch: 10, ff: 10, ge: 12, ko: 12, kk: 10)
        hero.personalData = PersonalData(
            name: "T", family: "", birthplace: "", birthdate: "", age: 30, gender: "m",
            species: "irrelevant", speciesId: speciesId,
            height: 170, weight: 70, hairColor: "", eyeColor: "",
            culture: "", socialStatus: "", profession: "", title: "", characteristics: ""
        )
        hero.derivedValues = DerivedValues(
            lebensenergie: LifeEnergyValue(base: 29, bonus: 0, purchased: 0, max: 29, current: 29),
            astralenergie: nil, karmaenergie: nil,
            seelenkraft: ResourceValue(base: 1, bonus: 0, max: 1),
            zaehigkeit: ResourceValue(base: 1, bonus: 0, max: 1),
            ausweichen: ComputedValue(value: 6, bonus: 0, max: 6),
            initiative: ComputedValue(value: 12, bonus: 0, max: 12),
            geschwindigkeit: ResourceValue(base: storedGS, bonus: 0, max: storedGS),
            wundschwelle: ComputedValue(value: 6, bonus: 0, max: 6),
            schicksalspunkte: MutableResourceValue(current: 3, bonus: 0, max: 3)
        )
        ctx.insert(hero)
        return hero
    }

    func testSpeciesGeschwindigkeitMatchesTheSource() {
        // Races.yaml `mov`: R_1 Menschen 8, R_2 Elfen 8, R_3 Halbelfen 8, R_4 Zwerge 6.
        XCTAssertEqual(DerivedValueFormulas.geschwindigkeit(speciesId: "R_1"), 8)
        XCTAssertEqual(DerivedValueFormulas.geschwindigkeit(speciesId: "R_2"), 8)
        XCTAssertEqual(DerivedValueFormulas.geschwindigkeit(speciesId: "R_3"), 8)
        XCTAssertEqual(DerivedValueFormulas.geschwindigkeit(speciesId: "R_4"), 6)
    }

    func testUnknownSpeciesHasNoValueRatherThanTheHumanOne() {
        // `nil` is not "8". The distinction is what lets the repair decline to write a
        // number it cannot derive, while the import still shows something.
        XCTAssertNil(DerivedValueFormulas.geschwindigkeit(speciesId: nil))
        XCTAssertNil(DerivedValueFormulas.geschwindigkeit(speciesId: "R_99"))
        XCTAssertEqual(DerivedValueFormulas.geschwindigkeitFallback, 8)
    }

    func testRepairCorrectsADwarfsGeschwindigkeit() {
        let hero = makeHero(speciesId: "R_4", storedGS: 8)
        XCTAssertTrue(DerivedValueRepair.repair(hero))
        XCTAssertEqual(hero.derivedValues?.geschwindigkeit.base, 6)
        XCTAssertEqual(hero.derivedValues?.geschwindigkeit.max, 6)
    }

    func testRepairLeavesAHumanGeschwindigkeitAlone() {
        let hero = makeHero(speciesId: "R_1", storedGS: 8)
        XCTAssertFalse(DerivedValueRepair.repair(hero))
        XCTAssertEqual(hero.derivedValues?.geschwindigkeit.max, 8)
    }

    func testRepairSkipsAHeroWithNoSpeciesId() {
        // The normal state for anyone imported before ADR-0006 persisted the field. The
        // pass must not assume human -- that would write the exact value it exists to
        // correct, over a number somebody may have fixed by hand.
        let hero = makeHero(speciesId: nil, storedGS: 6)
        XCTAssertFalse(DerivedValueRepair.repair(hero))
        XCTAssertEqual(hero.derivedValues?.geschwindigkeit.max, 6)
    }

    func testRepairSkipsAnUnrecognisedSpeciesId() {
        let hero = makeHero(speciesId: "R_99", storedGS: 7)
        XCTAssertFalse(DerivedValueRepair.repair(hero))
        XCTAssertEqual(hero.derivedValues?.geschwindigkeit.max, 7)
    }

    func testGeschwindigkeitRepairIsIdempotent() {
        let hero = makeHero(speciesId: "R_4", storedGS: 8)
        XCTAssertTrue(DerivedValueRepair.repair(hero))
        XCTAssertFalse(DerivedValueRepair.repair(hero), "second run must report no change")
        XCTAssertEqual(hero.derivedValues?.geschwindigkeit.max, 6)
    }
}
