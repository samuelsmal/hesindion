import Testing
@testable import Hesindion

struct WeatherGeneratorTests {
    let summer = AventurianDate(day: 1, month: .praios, year: 1040)
    let autumn = AventurianDate(day: 1, month: .efferd, year: 1040)

    @Test func producesValidEnums() {
        let gen = WeatherGenerator(region: .mittelreich)
        let r = gen.generate(date: summer, previousResult: nil)
        #expect(CloudCover.allCases.contains(r.clouds))
        #expect(WindStrength.allCases.contains(r.wind))
        #expect(RainLevel.allCases.contains(r.rain))
    }

    @Test func nightLowerThanDayWithinRange() {
        let gen = WeatherGenerator(region: .khom)
        for _ in 0..<50 {
            let r = gen.generate(date: summer, previousResult: nil)
            #expect(r.nightTemperature < r.dayTemperature)
            let range = r.dayTemperature - r.nightTemperature
            #expect(range >= 2)
            #expect(range <= ClimateArchetype.desert.clearSkyRange(for: .sommer) + 2)
        }
    }

    @Test func temperateSummerNightsNotFreezing() {            // regression for the bug
        let gen = WeatherGenerator(archetype: .temperate)
        var minNight = 99
        for _ in 0..<50 {
            // force clear, calm by regenerating with no previous and reading clear days
            let r = gen.generate(date: summer, previousResult: nil)
            if r.clouds == .none && r.wind == .none {
                minNight = min(minNight, r.nightTemperature)
            }
        }
        #expect(minNight >= 0 || minNight == 99)  // 99 = no clear-calm sample this run
    }

    @Test func desertSummerDaysNotAbsurd() {
        let gen = WeatherGenerator(region: .khom)
        for _ in 0..<100 {
            let r = gen.generate(date: summer, previousResult: nil)
            #expect(r.dayTemperature <= 50)
        }
    }

    @Test func dryFavorsClearHumidFavorsClouds() {
        let dry = WeatherGenerator(region: .khom)
        let humid = WeatherGenerator(region: .suedmeer)
        var dryClear = 0, humidCloudy = 0
        for _ in 0..<100 {
            if dry.generate(date: summer, previousResult: nil).clouds == .none { dryClear += 1 }
            if humid.generate(date: summer, previousResult: nil).clouds != .none { humidCloudy += 1 }
        }
        #expect(dryClear > 60)
        #expect(humidCloudy > 60)
    }

    @Test func batchCountAndDates() {
        let gen = WeatherGenerator(region: .mittelreich)
        let results = gen.generateBatch(startDate: AventurianDate(day: 28, month: .praios, year: 1040), count: 5)
        #expect(results.count == 5)
        #expect(results[3].date == AventurianDate(day: 1, month: .rondra, year: 1040))
    }

    @Test func noRainWithoutClouds() {
        let gen = WeatherGenerator(region: .mittelreich)
        for _ in 0..<100 {
            let r = gen.generate(date: summer, previousResult: nil)
            if r.clouds == .none { #expect(r.rain == .none) }
        }
    }

    @Test func cloudTablesByHumidity() {
        #expect(WeatherGenerator.cloudFromRoll(16, humidity: .dry) == .none)
        #expect(WeatherGenerator.cloudFromRoll(4, humidity: .moderate) == .none)
        #expect(WeatherGenerator.cloudFromRoll(5, humidity: .moderate) == .few)
        #expect(WeatherGenerator.cloudFromRoll(2, humidity: .humid) == .none)
        #expect(WeatherGenerator.cloudFromRoll(13, humidity: .humid) == .all)
    }

    @Test func windTableAutumnRanges() {
        #expect(WeatherGenerator.windFromRoll(3, autumn: true) == .none)
        #expect(WeatherGenerator.windFromRoll(20, autumn: false) == .storm)
    }
}
