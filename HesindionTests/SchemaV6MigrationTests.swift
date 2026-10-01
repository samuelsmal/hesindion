import XCTest
import SwiftData
@testable import Hesindion

/// SchemaV6 dropped `DerivedValues.ausweichen`/`.initiative`/`.wundschwelle` (Task 9). The fixture
/// under `HesindionTests/Fixtures/StoreV5/` is a store the pre-deletion build wrote (a2e9aaa's
/// model, import and container call) with an imported Boronmir — it cannot be regenerated now
/// that the properties are gone. It is a single checkpointed `.store` file (no `-wal`/`-shm`).
///
/// The test opens it the way the app opens its store: `HesindionApp` calls
/// `ModelContainer(for: Hero.self, HeroStateEntry.self)` with no migration plan, so this uses the
/// same call with only the URL added. `HesindionMigrationPlan` is not the app's migration path.
@MainActor
final class SchemaV6MigrationTests: XCTestCase {

    private static var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // SchemaV6MigrationTests.swift → HesindionTests/
            .appendingPathComponent("Fixtures/StoreV5/StoreV5.store")
    }

    /// Opening the store migrates it and writes `-wal`/`-shm` beside it; the repo copy stays
    /// untouched.
    private func openableFixtureCopyURL() throws -> URL {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaV6MigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let copy = scratch.appendingPathComponent("StoreV5.store")
        try FileManager.default.copyItem(at: Self.fixtureURL, to: copy)
        return copy
    }

    func testAPreSchemaV6StoreOpensWithTheAppsContainerAndKeepsTheHero() throws {
        let container = try ModelContainer(
            for: Hero.self, HeroStateEntry.self,
            configurations: ModelConfiguration(url: try openableFixtureCopyURL())
        )
        let context = ModelContext(container)
        let hero = try XCTUnwrap(try context.fetch(FetchDescriptor<Hero>()).first)
        XCTAssertTrue(hero.name.hasPrefix("Boronmir Siebenfeld von Greifenfurt"))
        // The pre-deletion import stored base 35 + Hohe Lebenskraft II (+2) as max and current.
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 37)
        // A relationship survives the migration.
        let attributes = try XCTUnwrap(hero.attributes)
        XCTAssertEqual(attributes.ko, 15)
    }
}
