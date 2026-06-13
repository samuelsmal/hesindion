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

        // This is the only snapshot that renders a real decoded-bitmap avatar.
        // Bitmap resampling/anti-aliasing produces tiny color deltas spread across
        // many pixels between runs — `precision` alone (which demands exact matches
        // on the kept fraction of pixels) flags these as failures, especially under
        // full-suite memory pressure. `perceptualPrecision` tolerates small per-pixel
        // color differences, which is the correct knob for bitmap rendering.
        assertAllVariants(of: view, named: "boronmir", precision: 0.99, perceptualPrecision: 0.98)
    }
}
