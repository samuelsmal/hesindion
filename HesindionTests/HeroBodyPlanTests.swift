import SwiftData
import XCTest
@testable import Hesindion

/// Which Trefferzonentabelle applies when the hero is hit.
///
/// The screen used the medium humanoid table for every hero, which is the wrong
/// table for a Zwerg: the 1W20 ranges differ, so the same roll picks a different
/// zone. The Fokusregel keys the table to the *species*, so that is what the app
/// looks up — a short human is still `mittel` — with the player's own setting on
/// top, because no species list can cover every table a group might use.
final class HeroBodyPlanTests: XCTestCase {

    private func hero(species: String, height: Int = 188) -> Hero {
        let hero = Hero(name: "Testheld")
        hero.personalData = PersonalData(
            name: "Testheld", family: "—", birthplace: "—", birthdate: "—", age: 20,
            gender: "—", species: species, height: height, weight: 80,
            hairColor: "—", eyeColor: "—", culture: "—", socialStatus: "—",
            profession: "—", title: "—", characteristics: "—"
        )
        return hero
    }

    // MARK: - The published list

    func testHumansAndElvesAreMedium() {
        for species in ["Mensch", "Menschen", "Elf", "Elfen", "Halbelf", "Halbelfen"] {
            XCTAssertEqual(hero(species: species).sizeCategory, .mittel, species)
        }
    }

    func testDwarvesAreSmall() {
        for species in ["Zwerg", "Zwerge"] {
            XCTAssertEqual(hero(species: species).sizeCategory, .klein, species)
        }
    }

    /// The whole point of not guessing: a 210 cm human and a 130 cm human are both
    /// `mittel`, and a Zwerg of any height is `klein`.
    func testHeightIsNeverConsulted() {
        XCTAssertEqual(hero(species: "Menschen", height: 130).sizeCategory, .mittel)
        XCTAssertEqual(hero(species: "Menschen", height: 210).sizeCategory, .mittel)
        XCTAssertEqual(hero(species: "Zwerge", height: 210).sizeCategory, .klein)
    }

    // MARK: - When the list has no answer

    func testAnUnlistedSpeciesIsUnanswered() {
        let stranger = hero(species: "Achaz-Mischling")
        XCTAssertTrue(stranger.needsHitZoneSize, "The settings screen has to ask about this hero")
        XCTAssertEqual(stranger.sizeCategory, .mittel, "Falls back to the table used before")
    }

    func testAListedSpeciesIsNotAskedAbout() {
        XCTAssertFalse(hero(species: "Zwerge").needsHitZoneSize)
    }

    func testAHeroWithoutPersonalDataIsAskedAbout() {
        let bare = Hero(name: "Ohne Daten")
        XCTAssertTrue(bare.needsHitZoneSize)
        XCTAssertFalse(HitZoneTable.rows(for: bare.bodyPlan).isEmpty)
    }

    // MARK: - The player's own answer

    func testTheStoredSizeWinsOverTheSpecies() {
        let dwarf = hero(species: "Zwerge")
        dwarf.hitZoneSize = CreatureSize.gross.rawValue
        XCTAssertEqual(dwarf.sizeCategory, .gross)
        XCTAssertFalse(dwarf.needsHitZoneSize)
    }

    func testAnUnreadableStoredSizeFallsBackToTheSpecies() {
        let dwarf = hero(species: "Zwerge")
        dwarf.hitZoneSize = "gigantisch"
        XCTAssertEqual(dwarf.sizeCategory, .klein)
    }

    // MARK: - It actually changes the table

    func testSizeChangesWhereARollLands() {
        let person = HitZoneTable.lookup(3, plan: hero(species: "Menschen").bodyPlan)
        let dwarf = HitZoneTable.lookup(3, plan: hero(species: "Zwerge").bodyPlan)
        XCTAssertNotEqual(person.zone, dwarf.zone, "The two tables must not agree on 3")
    }

    func testEveryHeroPlanIsHumanoid() {
        for species in ["Menschen", "Zwerge", "Unbekannt"] {
            guard case .humanoid = hero(species: species).bodyPlan else {
                return XCTFail("A hero is a humanoid, \(species) too")
            }
        }
    }
}
