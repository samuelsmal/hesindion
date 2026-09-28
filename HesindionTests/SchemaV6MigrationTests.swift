import XCTest
import SwiftData
@testable import Hesindion

/// SchemaV6 dropped `DerivedValues.ausweichen`/`.initiative`/`.wundschwelle` (Task 9). Every
/// schema version from V2 onward names the *live* `DerivedValues` class rather than a frozen
/// snapshot, so a "V5-shaped" store carrying those three properties can only be produced by
/// code that still has them — it cannot be regenerated after the deletion. It was produced
/// once and committed as a fixture under `HesindionTests/Fixtures/StoreV5/`. This test opens
/// that fixture and proves a real SwiftData lightweight migration from `SchemaV5` to
/// `SchemaV6` — dropping those three properties — keeps the hero's Lebenspunkte current
/// value intact.
///
/// It does **not** open the fixture through `HesindionMigrationPlan.self`. That plan's
/// `schemas` includes `SchemaV1`, and `Schema(versionedSchema: SchemaV1.self)` alone —
/// nothing to do with Task 9, reproducible on a clean build of this branch before this
/// task touched anything — crashes with `Fatal error: Inverse Relationship does not
/// exist`: `SchemaV1.Hero` duplicates the live `Hero`'s relationships to `PersonalData`,
/// `Talent`, `MeleeWeapon`, … verbatim, and SwiftData resolves a relationship's inverse
/// process-globally, not per `Schema` — two differently-shaped "Hero" entities both
/// relating to the same target type collide. `HesindionMigrationPlan` was never
/// constructed anywhere before this task (`HesindionApp` opens a bare, unversioned
/// `ModelContainer`), so nothing had ever exercised it and caught this. Fixing
/// `SchemaV1`…`SchemaV4` (which have the same shape) is out of scope for the sheet
/// cut-over; see the commit message and the Task 9 report for the full diagnosis.
/// `SchemaV5.Hero` (see `Hesindion/Migration/SchemaV5.swift`) stays deliberately minimal
/// so pinning it for *this* migration does not hit the same bug, and this test's `ShortPlan`
/// below exercises the real `migrateV5toV6` stage — the one this task actually adds to
/// `HesindionMigrationPlan` — without going through the broken earlier stages.
@MainActor
final class SchemaV6MigrationTests: XCTestCase {

    /// `HesindionMigrationPlan.migrateV5toV6` (the stage this task added), scoped to just
    /// the two versions that stage touches. See the type doc comment for why the real
    /// `HesindionMigrationPlan` — which also lists `SchemaV1` — cannot be used here.
    private enum ShortPlan: SchemaMigrationPlan {
        static var schemas: [any VersionedSchema.Type] { [SchemaV5.self, SchemaV6.self] }
        static var stages: [MigrationStage] { [HesindionMigrationPlan.migrateV5toV6] }
    }

    private static var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // SchemaV6MigrationTests.swift → HesindionTests/
            .appendingPathComponent("Fixtures/StoreV5")
    }

    private static let storeFileName = "StoreV5.store"

    /// Copies the committed fixture into a scratch directory SwiftData can write to — opening
    /// it for migration writes a `-wal`/`-shm` beside the store, and the repo copy must stay
    /// byte-for-byte reproducible for the next test run.
    private func openableFixtureCopyURL() throws -> URL {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaV6MigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            let source = Self.fixtureDirectory.appendingPathComponent("\(Self.storeFileName)\(suffix)")
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try FileManager.default.copyItem(
                at: source,
                to: scratch.appendingPathComponent("\(Self.storeFileName)\(suffix)")
            )
        }
        return scratch.appendingPathComponent(Self.storeFileName)
    }

    func testAV5StoreOpensWithSchemaV6AndKeepsLECurrent() throws {
        let storeURL = try openableFixtureCopyURL()
        let config = ModelConfiguration(schema: Schema(versionedSchema: SchemaV6.self), url: storeURL)
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV6.self),
            migrationPlan: ShortPlan.self,
            configurations: config
        )
        let context = ModelContext(container)
        let heroes = try context.fetch(FetchDescriptor<Hero>())
        let hero = try XCTUnwrap(heroes.first)
        XCTAssertTrue(hero.name.hasPrefix("Boronmir Siebenfeld von Greifenfurt"))
        // The value the pre-Task-9 import wrote (`base + purchased` plus the ADV_25
        // LE-bonus variable) — frozen the same run as `SheetValuesTests`' four literals
        // (2026-09-28), since `current` was initialised to that same `leMax`.
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 37)
    }
}
