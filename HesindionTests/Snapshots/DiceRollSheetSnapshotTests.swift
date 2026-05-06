import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class DiceRollSheetSnapshotTests: XCTestCase {

    @MainActor
    func testInitialState() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)

        let view = DiceRollSheet(hero: hero)
            .modelContainer(container)

        // Dice display value is randomized on init, allow minor pixel differences
        assertAllVariants(of: view, named: "initial", precision: 0.98)
    }
}
