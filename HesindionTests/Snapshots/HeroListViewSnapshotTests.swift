import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class HeroListViewSnapshotTests: XCTestCase {

    /// The footer renders the app version, so without pinning it every build
    /// bump invalidates these two baselines for a reason unrelated to the change
    /// being reviewed — and re-recording for an unrelated reason is how a real
    /// regression gets waved through.
    override func setUp() {
        super.setUp()
        AppVersion.overrideForTesting = "v0.0.0 (0)"
    }

    override func tearDown() {
        AppVersion.overrideForTesting = nil
        super.tearDown()
    }

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
