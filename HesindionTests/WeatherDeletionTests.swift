import Testing
import SwiftData
@testable import Hesindion

/// Deleting a weather day or a whole adventure (issue #54). Nothing in the app
/// could delete either before.
@MainActor
struct WeatherDeletionTests {

    /// An adventure with one day of weather for each of `days` of Praios 1040,
    /// and its current date on the day after the last of them, as a stretch leaves it.
    private func adventure(days: [Int], in context: ModelContext) -> Adventure {
        let adventure = Adventure(name: "Test", region: .mittelreich,
                                  startDate: AventurianDate(day: days[0], month: .praios, year: 1040))
        context.insert(adventure)
        var previous: AventurianDate?
        for day in days {
            let date = AventurianDate(day: day, month: .praios, year: 1040)
            let result = WeatherResult(date: date, clouds: .none, wind: .none,
                                       dayTemperature: 20, nightTemperature: 10, rain: .none)
            let weatherDay = WeatherDay(from: result, region: .mittelreich,
                                        isTimeJump: StretchPlanner.isGap(start: date, after: previous))
            weatherDay.adventure = adventure
            context.insert(weatherDay)
            previous = date
        }
        adventure.currentDate = previous!.next()
        return adventure
    }

    private func day(_ n: Int, of adventure: Adventure) throws -> WeatherDay {
        try #require(adventure.weatherDays.first { $0.day == n })
    }

    @Test func deletingTheNewestDayMovesTheCurrentDateBack() throws {
        let context = ModelContext(try TestData.makeContainer())
        let adventure = adventure(days: [1, 2, 3], in: context)

        adventure.deleteWeatherDay(try day(3, of: adventure))

        #expect(adventure.weatherDays.map(\.day).sorted() == [1, 2])
        #expect(adventure.currentDate == AventurianDate(day: 3, month: .praios, year: 1040))
    }

    @Test func deletingAnOlderDayKeepsTheCurrentDate() throws {
        let context = ModelContext(try TestData.makeContainer())
        let adventure = adventure(days: [1, 2, 3], in: context)

        adventure.deleteWeatherDay(try day(1, of: adventure))

        #expect(adventure.currentDate == AventurianDate(day: 4, month: .praios, year: 1040))
    }

    @Test func deletingTheLastDayKeepsTheCurrentDate() throws {
        let context = ModelContext(try TestData.makeContainer())
        let adventure = adventure(days: [5], in: context)

        adventure.deleteWeatherDay(try day(5, of: adventure))

        #expect(adventure.weatherDays.isEmpty)
        #expect(adventure.currentDate == AventurianDate(day: 6, month: .praios, year: 1040))
    }

    /// The timeline draws a time-jump divider above a day that does not follow
    /// the day before it. A delete in the middle opens such a gap.
    @Test func aDeleteInTheMiddleMarksTheNextDayAsATimeJump() throws {
        let context = ModelContext(try TestData.makeContainer())
        let adventure = adventure(days: [1, 2, 3], in: context)

        adventure.deleteWeatherDay(try day(2, of: adventure))

        #expect(try day(3, of: adventure).isTimeJump)
        #expect(try !day(1, of: adventure).isTimeJump)
    }

    /// A gap that a delete closes is no gap any more: day 3 followed day 1
    /// across a jump, and with day 1 gone it is the first day.
    @Test func theFirstDayLeftIsNoTimeJump() throws {
        let context = ModelContext(try TestData.makeContainer())
        let adventure = adventure(days: [1, 3], in: context)
        #expect(try day(3, of: adventure).isTimeJump)

        adventure.deleteWeatherDay(try day(1, of: adventure))

        #expect(try !day(3, of: adventure).isTimeJump)
    }

    @Test func deletingAnAdventureTakesItsWeatherAndFreesItsHeroes() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        let context = try #require(hero.modelContext)
        let adventure = adventure(days: [1, 2], in: context)
        hero.activeAdventure = adventure
        try context.save()

        context.delete(adventure)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Adventure>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WeatherDay>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Hero>()) == 1)
        #expect(hero.activeAdventure == nil)
    }
}
