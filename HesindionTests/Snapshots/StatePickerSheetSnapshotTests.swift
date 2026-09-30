import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class StatePickerSheetSnapshotTests: XCTestCase {

    /// "Zustand hinzufügen" as the app's own modal (#33): scrim, raised panel, accent
    /// header with a close button, the search field and the Zustände section with
    /// Furcht II set.
    @MainActor
    func testPickerWithFurchtTwo() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        hero.setStateLevel("furcht", level: 2)

        let view = StatePickerSheet(hero: hero) {}
            .modelContainer(container)

        assertAllVariants(of: view, named: "state_picker_furcht_II")
    }
}
