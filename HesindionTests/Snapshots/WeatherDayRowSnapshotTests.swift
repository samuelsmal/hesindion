import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class WeatherDayRowSnapshotTests: XCTestCase {

    @MainActor
    func testWeatherDay() throws {
        let container = try TestData.makeContainer()
        let context = ModelContext(container)

        let result = WeatherResult(
            date: AventurianDate(day: 15, month: .praios, year: 1040),
            clouds: .none,
            wind: .none,
            dayTemperature: 22,
            nightTemperature: 14,
            rain: .none
        )
        let weather = WeatherDay(from: result)
        context.insert(weather)

        let view = WeatherDayRow(weatherDay: weather)
            .frame(width: 700)
            .modelContainer(container)

        assertAllVariants(of: view, named: "sunny")
    }
}
