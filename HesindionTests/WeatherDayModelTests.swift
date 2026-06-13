import Testing
import SwiftData
@testable import Hesindion

@MainActor
struct WeatherDayModelTests {
    @Test func regionFallsBackToAdventure() throws {
        let container = try ModelContainer(for: Adventure.self, WeatherDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = ModelContext(container)
        let adv = Adventure(name: "T", region: .khom,
                            startDate: AventurianDate(day: 1, month: .praios, year: 1040))
        ctx.insert(adv)
        let legacyDay = WeatherDay(from: WeatherResult(
            date: AventurianDate(day: 1, month: .praios, year: 1040),
            clouds: .none, wind: .none, dayTemperature: 40, nightTemperature: 20, rain: .none))
        legacyDay.adventure = adv           // regionRaw left empty → inherits
        #expect(legacyDay.region == .khom)
        #expect(legacyDay.diurnalRange == 20)
    }

    @Test func explicitRegionAndOverrides() {
        let day = WeatherDay(from: WeatherResult(
            date: AventurianDate(day: 2, month: .praios, year: 1040),
            clouds: .all, wind: .strong, dayTemperature: 10, nightTemperature: 6, rain: .lots),
            region: .thorwal)
        #expect(day.region == .thorwal)
        day.overrides = [.dayTemp, .rain]
        #expect(day.overrides.contains(.dayTemp))
        #expect(!day.overrides.contains(.clouds))
    }

    @Test func legacyRegionRawNormalizes() {
        let day = WeatherDay(from: WeatherResult(
            date: AventurianDate(day: 1, month: .praios, year: 1040),
            clouds: .none, wind: .none, dayTemperature: 1, nightTemperature: 0, rain: .none))
        day.regionRaw = "weiden"            // legacy
        #expect(day.region == .streitendeKoenigreiche)
    }
}
