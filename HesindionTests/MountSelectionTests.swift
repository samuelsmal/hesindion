import XCTest
import SwiftData
@testable import Hesindion

/// Which animal the hero rides.
///
/// This used to be `hero.pets.first` — a SwiftData to-many relationship, whose
/// order is whatever the store hands over and changes between launches. With two
/// animals the app could put the hero on the horse in one fight and on the mule
/// in the next, and the mount's LP bar, its GS in the Sturmangriff damage and its
/// attacks all followed that coin toss.
@MainActor
final class MountSelectionTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Hero.self, HeroStateEntry.self, Adventure.self, WeatherDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func pet(_ name: String, initiative: String, speed: Int) -> Pet {
        Pet(
            petId: "PET_\(name)", name: name, size: 1, type: "Reittier",
            attributes: PetAttributes(mu: 10, kl: 10, inValue: 10, ch: 10, ff: 10, ge: 10, ko: 10, kk: 10),
            lifeEnergy: 30, spirit: 0, toughness: 0, initiative: initiative, speed: speed,
            attack: "Biss", damage: "1W6", reach: "kurz", actions: 1,
            talents: "", skills: "", notes: ""
        )
    }

    func testTheMountIsTheSameAnimalWhicheverOrderThePetsComeBackIn() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        let brummel = pet("Brummel", initiative: "10+1W6", speed: 8)
        let alrik = pet("Alrik", initiative: "12+1W6", speed: 7)

        hero.pets = [brummel, alrik]
        XCTAssertEqual(hero.mount?.name, "Alrik", "by name, so the answer does not depend on the store")
        XCTAssertEqual(hero.mountGS, 7)

        // The same two animals handed back the other way round.
        hero.pets = [alrik, brummel]
        XCTAssertEqual(hero.mount?.name, "Alrik")
        XCTAssertEqual(hero.mountGS, 7)
    }

    /// A pet with no initiative is not a mount — `hasMount` always said so. It no
    /// longer hides a mount standing behind it in the list either.
    func testAPetWithoutInitiativeIsSkippedRatherThanHidingTheMount() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        let cat = pet("Aaron", initiative: "", speed: 6)        // sorts first, cannot be ridden
        let horse = pet("Kupperus", initiative: "11+1W6", speed: 9)
        hero.pets = [cat, horse]

        XCTAssertTrue(hero.hasMount)
        XCTAssertEqual(hero.mount?.name, "Kupperus")
        XCTAssertEqual(hero.mountGS, 9)
    }

    func testAHeroWithNoRideableAnimalHasNoMount() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.pets = [pet("Aaron", initiative: "", speed: 6)]

        XCTAssertFalse(hero.hasMount)
        XCTAssertNil(hero.mount)
        XCTAssertEqual(hero.mountGS, 0)
    }
}
