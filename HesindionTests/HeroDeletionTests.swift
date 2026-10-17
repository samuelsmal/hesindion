import XCTest
import SwiftData
@testable import Hesindion

/// Deleting a hero from the sidebar takes everything that belongs to the hero
/// with it. Every relationship on `Hero` is a cascade, so a delete that left a
/// talent, a weapon or a log entry behind would be data nothing can reach again.
@MainActor
final class HeroDeletionTests: XCTestCase {

    func testDeletingAHeroLeavesNothingOfTheHeroBehind() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        let context = hero.modelContext!
        context.insert(TestData.makeDiceRollLogEntry(for: hero))
        try context.save()
        XCTAssertFalse(try context.fetch(FetchDescriptor<Talent>()).isEmpty, "Import gave the hero no talents")

        context.delete(hero)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Hero>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PersonalData>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Attributes>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DerivedValues>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Talent>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CombatTechnique>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MeleeWeapon>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<EquipmentItem>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Pet>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HeroSpell>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LogEntry>()), 0)
    }
}
