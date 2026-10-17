import XCTest
import SwiftData
@testable import Hesindion

/// SchemaV7 drops `Pet.purchases` and `Pet.specialSkills` and adds `Pet.disadvantages` and
/// `Pet.importProblems` (issue #49). `Fixtures/StoreV6/StoreV6.store` is a store the build before
/// the change wrote with the app's own container call and an imported 2026-09-24 Boronmir, whose
/// Kupperus had 19 purchases. It cannot be regenerated now that the properties are gone.
@MainActor
final class SchemaV7MigrationTests: XCTestCase {

    private func openableFixtureCopyURL() throws -> URL {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/StoreV6/StoreV6.store")
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaV7MigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let copy = scratch.appendingPathComponent("StoreV6.store")
        try FileManager.default.copyItem(at: fixture, to: copy)
        return copy
    }

    func testAPreSchemaV7StoreOpensAndKeepsTheCompanion() throws {
        let container = try ModelContainer(
            for: Hero.self, HeroStateEntry.self,
            configurations: ModelConfiguration(url: try openableFixtureCopyURL())
        )
        let hero = try XCTUnwrap(try ModelContext(container).fetch(FetchDescriptor<Hero>()).first)
        let pet = try XCTUnwrap(hero.petsInOrder.first)
        XCTAssertEqual(pet.name, "Kupperus")
        XCTAssertEqual(pet.defense, 14)
        XCTAssertEqual(pet.attacks.count, 3)
        XCTAssertEqual(pet.disadvantages, [])
        XCTAssertEqual(pet.importProblems, [])
    }
}
