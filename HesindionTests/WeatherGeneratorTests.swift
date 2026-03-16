import Testing
@testable import Hesindion

struct WeatherGeneratorTests {

    @Test func generateProducesValidCloudCover() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let date = AventurianDate(day: 1, month: .praios, year: 1040)
        let result = gen.generate(date: date, previousResult: nil)
        #expect(CloudCover.allCases.contains(result.clouds))
    }

    @Test func generateProducesValidWind() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let date = AventurianDate(day: 1, month: .praios, year: 1040)
        let result = gen.generate(date: date, previousResult: nil)
        #expect(WindStrength.allCases.contains(result.wind))
    }

    @Test func generateProducesValidRain() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let date = AventurianDate(day: 1, month: .praios, year: 1040)
        let result = gen.generate(date: date, previousResult: nil)
        #expect(RainLevel.allCases.contains(result.rain))
    }

    @Test func nightTempIsLowerThanDay() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let date = AventurianDate(day: 1, month: .praios, year: 1040)
        for _ in 0..<20 {
            let result = gen.generate(date: date, previousResult: nil)
            #expect(result.nightTemperature < result.dayTemperature)
        }
    }

    @Test func desertFavorsClearSkies() {
        let gen = WeatherGenerator(region: .khom, desert: true, windy: false)
        let date = AventurianDate(day: 1, month: .praios, year: 1040)
        var clearCount = 0
        for _ in 0..<100 {
            let result = gen.generate(date: date, previousResult: nil)
            if result.clouds == .none { clearCount += 1 }
        }
        #expect(clearCount > 60)
    }

    @Test func batchGeneratesCorrectCount() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let start = AventurianDate(day: 1, month: .praios, year: 1040)
        let results = gen.generateBatch(startDate: start, count: 5)
        #expect(results.count == 5)
    }

    @Test func batchAdvancesDates() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let start = AventurianDate(day: 28, month: .praios, year: 1040)
        let results = gen.generateBatch(startDate: start, count: 5)
        #expect(results[0].date == AventurianDate(day: 28, month: .praios, year: 1040))
        #expect(results[2].date == AventurianDate(day: 30, month: .praios, year: 1040))
        #expect(results[3].date == AventurianDate(day: 1, month: .rondra, year: 1040))
    }

    @Test func noRainWithoutClouds() {
        let gen = WeatherGenerator(region: .mittelreich, desert: false, windy: false)
        let date = AventurianDate(day: 1, month: .praios, year: 1040)
        for _ in 0..<100 {
            let result = gen.generate(date: date, previousResult: nil)
            if result.clouds == .none {
                #expect(result.rain == .none)
            }
        }
    }

    @Test func cloudTableNormalRanges() {
        #expect(WeatherGenerator.cloudFromRoll(4, desert: false) == .none)
        #expect(WeatherGenerator.cloudFromRoll(5, desert: false) == .few)
        #expect(WeatherGenerator.cloudFromRoll(10, desert: false) == .few)
        #expect(WeatherGenerator.cloudFromRoll(11, desert: false) == .lots)
        #expect(WeatherGenerator.cloudFromRoll(16, desert: false) == .lots)
        #expect(WeatherGenerator.cloudFromRoll(17, desert: false) == .all)
    }

    @Test func cloudTableDesertRanges() {
        #expect(WeatherGenerator.cloudFromRoll(16, desert: true) == .none)
        #expect(WeatherGenerator.cloudFromRoll(17, desert: true) == .few)
        #expect(WeatherGenerator.cloudFromRoll(19, desert: true) == .lots)
        #expect(WeatherGenerator.cloudFromRoll(20, desert: true) == .all)
    }

    @Test func windTableNonAutumnRanges() {
        #expect(WeatherGenerator.windFromRoll(4, autumn: false) == .none)
        #expect(WeatherGenerator.windFromRoll(5, autumn: false) == .light)
        #expect(WeatherGenerator.windFromRoll(11, autumn: false) == .fresh)
        #expect(WeatherGenerator.windFromRoll(17, autumn: false) == .strong)
        #expect(WeatherGenerator.windFromRoll(20, autumn: false) == .storm)
    }

    @Test func windTableAutumnRanges() {
        #expect(WeatherGenerator.windFromRoll(3, autumn: true) == .none)
        #expect(WeatherGenerator.windFromRoll(4, autumn: true) == .light)
        #expect(WeatherGenerator.windFromRoll(8, autumn: true) == .fresh)
        #expect(WeatherGenerator.windFromRoll(15, autumn: true) == .strong)
        #expect(WeatherGenerator.windFromRoll(19, autumn: true) == .storm)
    }
}
