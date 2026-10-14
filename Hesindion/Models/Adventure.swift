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

    /// Deletes one day of weather (issue #54).
    ///
    /// When the day was the newest, the current date moves back to the day after
    /// the newest day left, so the next stretch continues without a gap. When no
    /// day is left, the current date stays. The day after the deleted one is a
    /// time jump exactly when it no longer follows the day before it.
    func deleteWeatherDay(_ weatherDay: WeatherDay) {
        let wasNewest = weatherDays.allSatisfy { $0.date.ordinal() <= weatherDay.date.ordinal() }
        // Out of the array first: the context's delete reaches the inverse only on save.
        weatherDays.removeAll { $0.persistentModelID == weatherDay.persistentModelID }
        modelContext?.delete(weatherDay)

        let remaining = weatherDays.sorted { $0.date.ordinal() < $1.date.ordinal() }
        if wasNewest, let newest = remaining.last {
            currentDate = newest.date.next()
        }
        if let successor = remaining.first(where: { $0.date.ordinal() > weatherDay.date.ordinal() }) {
            let predecessor = remaining.last { $0.date.ordinal() < successor.date.ordinal() }
            successor.isTimeJump = StretchPlanner.isGap(start: successor.date, after: predecessor?.date)
        }
    }
}
