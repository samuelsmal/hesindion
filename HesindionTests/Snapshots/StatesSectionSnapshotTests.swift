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

        // Wrap in a ScrollView so the swipe rows size to their content height (as they do
        // inside HeroDetailView). With a bare `.device` layout the rows' action backgrounds
        // would greedily expand to fill the screen.
        let view = ScrollView {
            StatesSectionView(hero: hero)
                .frame(width: 380)
                .padding()
        }
        .background(Color(UIColor.systemBackground))
        .modelContainer(container)

        assertAllVariants(of: view, named: "states_section")
    }
}
