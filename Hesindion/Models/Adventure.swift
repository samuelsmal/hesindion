import Foundation
import SwiftData

@Model
final class Adventure {
    var id: UUID = UUID()
    var name: String = ""
    var regionRaw: String = WeatherRegion.mittelreich.rawValue   // default region for new stretches
    var currentDay: Int = 1
    var currentMonthRaw: Int = AventurianMonth.praios.rawValue
    var currentYear: Int = 1040
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \WeatherDay.adventure)
    var weatherDays: [WeatherDay] = []

    @Relationship(inverse: \Hero.activeAdventure)
    var heroes: [Hero] = []

    var region: WeatherRegion {
        get { WeatherRegion.resolve(persisted: regionRaw) }
        set { regionRaw = newValue.rawValue }
    }
    var currentMonth: AventurianMonth {
        get { AventurianMonth(rawValue: currentMonthRaw) ?? .praios }
        set { currentMonthRaw = newValue.rawValue }
    }
    var currentDate: AventurianDate {
        get { AventurianDate(day: currentDay, month: currentMonth, year: currentYear) }
        set { currentDay = newValue.day; currentMonth = newValue.month; currentYear = newValue.year }
    }

    init(name: String, region: WeatherRegion, startDate: AventurianDate) {
        self.name = name
        self.regionRaw = region.rawValue
        self.currentDay = startDate.day
        self.currentMonthRaw = startDate.month.rawValue
        self.currentYear = startDate.year
    }
}
