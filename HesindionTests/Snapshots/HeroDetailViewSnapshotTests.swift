import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class HeroDetailViewSnapshotTests: XCTestCase {

    @MainActor
    func testFullHero() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)

        let view = HeroDetailView(
            hero: hero,
            sidebarSelection: .constant(.hero(hero.persistentModelID))
        )
        .modelContainer(container)

        // Avatar image loading may cause minor pixel differences between runs
        assertAllVariants(of: view, named: "boronmir", precision: 0.99)
    }
}
