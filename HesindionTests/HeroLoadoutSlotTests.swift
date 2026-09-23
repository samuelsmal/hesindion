import XCTest
import SwiftData
@testable import Hesindion

/// Taking a thing out of the loadout and putting it back, and the Geschwindigkeit
/// a prone hero actually moves at.
///
/// Both exist for the Patzertabelle: a fumble that drops or jams the weapon has
/// only its *name* to go on, and a Sturz has to make the third of Liegend's three
/// effects real — the app already charged the AT −4 and the PA/AW −2 through the
/// catalog, and offered the hero their full GS while lying in the mud.
final class HeroLoadoutSlotTests: XCTestCase {

    // MARK: - Which hand

    func testTheSlotIsFoundByNameInEverySlot() {
        let hero = makeHero()
        hero.selectedWeaponName = "Langschwert"
        hero.selectedOffHandName = "Dolch"
        hero.selectedShieldName = "Holzschild"
        hero.selectedRangedWeaponName = "Kurzbogen"

        XCTAssertEqual(hero.loadoutSlot(ofNamed: "Langschwert"), .mainHand)
        XCTAssertEqual(hero.loadoutSlot(ofNamed: "Dolch"), .offHand)
        XCTAssertEqual(hero.loadoutSlot(ofNamed: "Holzschild"), .shield)
        XCTAssertEqual(hero.loadoutSlot(ofNamed: "Kurzbogen"), .ranged)
        XCTAssertNil(hero.loadoutSlot(ofNamed: "Raufen"))
        XCTAssertNil(hero.loadoutSlot(ofNamed: "Streitkolben"))
    }

    /// The regression the helper is here to prevent: an off-hand fumble must not
    /// disarm the main hand.
    func testUnequippingClearsOnlyTheSlotTheThingWasIn() {
        let hero = makeHero()
        hero.selectedWeaponName = "Langschwert"
        hero.selectedOffHandName = "Dolch"

        XCTAssertEqual(hero.unequipFromLoadout(named: "Dolch"), .offHand)
        XCTAssertNil(hero.selectedOffHandName)
        XCTAssertEqual(hero.selectedWeaponName, "Langschwert")
    }

    func testUnequippingSomethingNotInTheLoadoutChangesNothing() {
        let hero = makeHero()
        hero.selectedWeaponName = "Langschwert"

        XCTAssertNil(hero.unequipFromLoadout(named: "Raufen"))
        XCTAssertEqual(hero.selectedWeaponName, "Langschwert")
    }

    /// A freed weapon goes back where it came from, which is the whole reason
    /// `unequipFromLoadout` returns the slot.
    func testTheStuckWeaponGoesBackIntoItsOwnSlot() {
        let hero = makeHero()
        hero.selectedOffHandName = "Dolch"

        guard let slot = hero.unequipFromLoadout(named: "Dolch") else {
            return XCTFail("the dagger was not in the loadout")
        }
        hero.equipInLoadout(named: "Dolch", slot: slot)

        XCTAssertEqual(hero.selectedOffHandName, "Dolch")
        XCTAssertNil(hero.selectedWeaponName)
    }

    // MARK: - Geschwindigkeit

    func testAProneHeroMovesAtGSOne() {
        let hero = makeHero(gs: 8)
        XCTAssertEqual(hero.effectiveGeschwindigkeit, 8)

        hero.setStateLevel("liegend", level: 1)
        XCTAssertTrue(hero.isLiegend)
        XCTAssertEqual(hero.effectiveGeschwindigkeit, 1)

        hero.setStateLevel("liegend", level: 0)
        XCTAssertEqual(hero.effectiveGeschwindigkeit, 8)
    }

    /// Bewusstlos implies Liegend (`StateCatalog`), and an implied Liegend is as
    /// prone as a stated one.
    func testAnImpliedLiegendCountsToo() {
        let hero = makeHero(gs: 8)
        hero.setStateLevel("bewusstlos", level: 1)

        XCTAssertFalse(hero.hasState("liegend"))
        XCTAssertTrue(hero.impliedStateIDs.contains("liegend"))
        XCTAssertTrue(hero.isLiegend)
        XCTAssertEqual(hero.effectiveGeschwindigkeit, 1)
    }

    // MARK: - Helpers

    private func makeHero(gs: Int? = nil) -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self, Attributes.self,
            configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T")
        ctx.insert(hero)
        if let gs {
            hero.derivedValues = DerivedValues(
                lebensenergie: LifeEnergyValue(base: 30, bonus: 0, purchased: 0, max: 30, current: 30),
                astralenergie: nil, karmaenergie: nil,
                seelenkraft: ResourceValue(base: 0, bonus: 0, max: 0),
                zaehigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
                ausweichen: ComputedValue(value: 0, bonus: 0, max: 0),
                initiative: ComputedValue(value: 0, bonus: 0, max: 0),
                geschwindigkeit: ResourceValue(base: gs, bonus: 0, max: gs),
                wundschwelle: ComputedValue(value: 6, bonus: 0, max: 6),
                schicksalspunkte: MutableResourceValue(current: 0, bonus: 0, max: 0))
        }
        return hero
    }
}
