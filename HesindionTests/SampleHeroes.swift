import Foundation
import SwiftData
@testable import Hesindion

/// Imports one of the sample heroes in `specs/heroes/` into a fresh in-memory container,
/// the same way `TestData.importBoronmir` imports Boronmir. A thin wrapper so tests outside
/// `SampleHeroImportTests` (which keeps its own private helper) do not each grow their own copy.
///
/// SwiftData models detach from their store once the `ModelContainer` that backs them is
/// deallocated, so every container this creates is kept alive for the test process in
/// `containers` below.
@MainActor
enum SampleHeroes {
    private static var containers: [ModelContainer] = []

    static func importHero(named name: String) throws -> Hero {
        let container = try TestData.makeContainer()
        containers.append(container)
        let context = ModelContext(container)
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // HesindionTests/
            .deletingLastPathComponent()    // project root
            .appendingPathComponent("specs/heroes/\(name).json")
        try OptolithImportService().importHero(from: url, context: context)
        let heroes = try context.fetch(FetchDescriptor<Hero>())
        return heroes.first!
    }
}
