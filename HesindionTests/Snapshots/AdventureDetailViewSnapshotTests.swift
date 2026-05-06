import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class AdventureDetailViewSnapshotTests: XCTestCase {

    @MainActor
    func testWithWeatherDays() throws {
        let container = try TestData.makeContainer()
        let context = ModelContext(container)
        let adventure = TestData.makeSampleAdventure(in: context)

        let view = AdventureDetailView(adventure: adventure)
            .modelContainer(container)

        assertAllVariants(of: view, named: "withWeather")
    }
}
