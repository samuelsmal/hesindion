import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class CombatViewSnapshotTests: XCTestCase {

    @MainActor
    func testArmorSelection() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)

        let view = CombatView(hero: hero, onDismiss: {})
            .modelContainer(container)

        assertAllVariants(of: view, named: "armorSelection")
    }
}
