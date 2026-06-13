import Foundation
import SwiftData

/// Which fields the GM hand-edited (preserved across re-rolls of other fields).
struct WeatherField: OptionSet {
    let rawValue: Int
    static let clouds    = WeatherField(rawValue: 1 << 0)
    static let wind      = WeatherField(rawValue: 1 << 1)
    static let dayTemp   = WeatherField(rawValue: 1 << 2)
    static let nightTemp = WeatherField(rawValue: 1 << 3)
    static let rain      = WeatherField(rawValue: 1 << 4)
}

@Model
final class WeatherDay {
    var id: UUID = UUID()
    var adventure: Adventure?
    var day: Int = 1
    var monthRaw: Int = AventurianMonth.praios.rawValue
    var year: Int = 1040
    var cloudsRaw: String = CloudCover.none.rawValue
    var windRaw: String = WindStrength.none.rawValue
    var dayTemperature: Int = 0
    var nightTemperature: Int = 0
    var rainRaw: String = RainLevel.none.rawValue
    var isTimeJump: Bool = false
    var generatedAt: Date = Date()
    var regionRaw: String = ""          // empty → inherit adventure's region (legacy days)
    var overridesRaw: Int = 0

    var month: AventurianMonth {
        get { AventurianMonth(rawValue: monthRaw) ?? .praios }
        set { monthRaw = newValue.rawValue }
    }
    var clouds: CloudCover {
        get { CloudCover(rawValue: cloudsRaw) ?? .none }
        set { cloudsRaw = newValue.rawValue }
    }
    var wind: WindStrength {
        get { WindStrength(rawValue: windRaw) ?? .none }
        set { windRaw = newValue.rawValue }
    }
    var rain: RainLevel {
        get { RainLevel(rawValue: rainRaw) ?? .none }
        set { rainRaw = newValue.rawValue }
    }
    var region: WeatherRegion {
        get {
            if regionRaw.isEmpty { return adventure?.region ?? .mittelreich }
            return WeatherRegion.resolve(persisted: regionRaw)
        }
        set { regionRaw = newValue.rawValue }
    }
    var overrides: WeatherField {
        get { WeatherField(rawValue: overridesRaw) }
        set { overridesRaw = newValue.rawValue }
    }
    var date: AventurianDate { AventurianDate(day: day, month: month, year: year) }
    var diurnalRange: Int { dayTemperature - nightTemperature }

    init(from result: WeatherResult, region: WeatherRegion? = nil, isTimeJump: Bool = false) {
        self.day = result.date.day
        self.monthRaw = result.date.month.rawValue
        self.year = result.date.year
        self.cloudsRaw = result.clouds.rawValue
        self.windRaw = result.wind.rawValue
        self.dayTemperature = result.dayTemperature
        self.nightTemperature = result.nightTemperature
        self.rainRaw = result.rain.rawValue
        self.isTimeJump = isTimeJump
        self.regionRaw = region?.rawValue ?? ""
    }
}
