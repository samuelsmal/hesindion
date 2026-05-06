import Foundation
import SwiftData

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

    var date: AventurianDate {
        AventurianDate(day: day, month: month, year: year)
    }

    init(from result: WeatherResult, isTimeJump: Bool = false) {
        self.day = result.date.day
        self.monthRaw = result.date.month.rawValue
        self.year = result.date.year
        self.cloudsRaw = result.clouds.rawValue
        self.windRaw = result.wind.rawValue
        self.dayTemperature = result.dayTemperature
        self.nightTemperature = result.nightTemperature
        self.rainRaw = result.rain.rawValue
        self.isTimeJump = isTimeJump
    }
}
