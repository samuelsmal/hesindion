import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class StatesSectionSnapshotTests: XCTestCase {

    @MainActor
    func testStatesSection() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)

        hero.setStateLevel("furcht", level: 2)
        hero.setStateLevel("liegend", level: 1)

        let view = StatesSectionView(hero: hero)
            .frame(width: 380)
            .padding()
            .background(Color(UIColor.systemBackground))
            .modelContainer(container)

        assertAllVariants(of: view, named: "states_section")
    }
}
