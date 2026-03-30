import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class HeroListViewSnapshotTests: XCTestCase {

    @MainActor
    func testEmptyState() throws {
        let container = try TestData.makeContainer()
        let view = HeroListView()
            .modelContainer(container)

        assertAllVariants(of: view, named: "empty")
    }

    @MainActor
    func testPopulated() throws {
        let container = try TestData.makeContainer()
        _ = try TestData.importBoronmir(into: container)

        let view = HeroListView()
            .modelContainer(container)

        assertAllVariants(of: view, named: "populated")
    }
}
