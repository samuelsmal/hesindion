import Foundation

/// Pure value type for weather generation output (no SwiftData dependency).
struct WeatherResult {
    let date: AventurianDate
    let clouds: CloudCover
    let wind: WindStrength
    let dayTemperature: Int
    let nightTemperature: Int
    let rain: RainLevel
}

/// Generates DSA weather. Temperature uses a climate-driven diurnal-range model
/// (night = day high − range), grounded in real meteorology; cloud/wind/rain
/// follow the WdE p.156ff tables, keyed on the region's climate archetype.
struct WeatherGenerator {
    let archetype: ClimateArchetype

    init(archetype: ClimateArchetype) { self.archetype = archetype }
    init(region: WeatherRegion) { self.archetype = region.archetype }

    // MARK: - Public API

    func generate(date: AventurianDate, previousResult: WeatherResult?) -> WeatherResult {
        let season = date.season
        let changeFlags = rollChangeFlags(season: season, hasPrevious: previousResult != nil)

        let clouds = (changeFlags & 0b0001 != 0)
            ? Self.cloudFromRoll(d20(), humidity: archetype.humidity)
            : (previousResult?.clouds ?? Self.cloudFromRoll(d20(), humidity: archetype.humidity))

        let wind = (changeFlags & 0b0010 != 0)
            ? Self.windFromRoll(d20() + archetype.windiness.rollBonus, autumn: season == .herbst)
            : (previousResult?.wind ?? Self.windFromRoll(d20() + archetype.windiness.rollBonus, autumn: season == .herbst))

        let dayTemp: Int
        let nightTemp: Int
        if changeFlags & 0b0100 != 0 || previousResult == nil {
            dayTemp = archetype.baseDayTemp(for: season) + clouds.temperatureModifier + wind.temperatureModifier
            nightTemp = dayTemp - nightRange(clouds: clouds, wind: wind, season: season)
        } else {
            dayTemp = previousResult!.dayTemperature
            nightTemp = previousResult!.nightTemperature
        }

        let rain = (changeFlags & 0b1000 != 0)
            ? rollRain(clouds: clouds, wind: wind)
            : (previousResult?.rain ?? rollRain(clouds: clouds, wind: wind))

        return WeatherResult(date: date, clouds: clouds, wind: wind,
                             dayTemperature: dayTemp, nightTemperature: nightTemp, rain: rain)
    }

    func generateBatch(startDate: AventurianDate, count: Int) -> [WeatherResult] {
        var results: [WeatherResult] = []
        var date = startDate
        var previous: WeatherResult? = nil
        for _ in 0..<count {
            let result = generate(date: date, previousResult: previous)
            results.append(result)
            previous = result
            date = date.next()
        }
        return results
    }

    // MARK: - Diurnal range (night temperature)

    /// Day→night drop: climate clear-sky range, shrunk by clouds, reduced by wind,
    /// with small jitter and a 2° floor. This replaces the old flat d20+5 drop.
    func nightRange(clouds: CloudCover, wind: WindStrength, season: AventurianSeason) -> Int {
        let base = Double(archetype.clearSkyRange(for: season))
        var range = Int((base * clouds.cloudFactor).rounded())
        range -= wind.nightWindReduction
        range += Int.random(in: -1...2)
        return max(range, 2)
    }

    // MARK: - Dice
    private func d20() -> Int { Int.random(in: 1...20) }

    // MARK: - Step 1: Day-change flags
    private func rollChangeFlags(season: AventurianSeason, hasPrevious: Bool) -> UInt8 {
        guard hasPrevious else { return 0b1111 }
        let roll = d20()
        switch season {
        case .sommer, .winter: return stableChangeFlags(roll)
        case .herbst, .fruehling: return volatileChangeFlags(roll)
        }
    }
    private func stableChangeFlags(_ roll: Int) -> UInt8 {
        switch roll {
        case 1...9: 0b0000; case 10...11: 0b0001; case 12...13: 0b0011
        case 14...15: 0b0101; case 16...17: 0b0111; case 18...19: 0b1011
        default: 0b1111
        }
    }
    private func volatileChangeFlags(_ roll: Int) -> UInt8 {
        switch roll {
        case 1...4: 0b0000; case 5...6: 0b0001; case 7...8: 0b0011
        case 9...10: 0b0101; case 11...12: 0b0111; case 13...14: 0b1001
        case 15...16: 0b1011; case 17...18: 0b1101; default: 0b1111
        }
    }

    // MARK: - Step 2: Clouds (by humidity)
    static func cloudFromRoll(_ roll: Int, humidity: ClimateArchetype.Humidity) -> CloudCover {
        switch humidity {
        case .dry:
            switch roll { case ...16: .none; case 17...18: .few; case 19: .lots; default: .all }
        case .moderate:
            switch roll { case ...4: .none; case 5...10: .few; case 11...16: .lots; default: .all }
        case .humid:
            switch roll { case ...2: .none; case 3...6: .few; case 7...12: .lots; default: .all }
        }
    }

    // MARK: - Step 3: Wind
    static func windFromRoll(_ roll: Int, autumn: Bool) -> WindStrength {
        if autumn {
            switch roll {
            case ...3: .none; case 4...5: .light; case 6...7: .soft; case 8...10: .fresh
            case 11...14: .cool; case 15...18: .strong; default: .storm
            }
        } else {
            switch roll {
            case ...4: .none; case 5...7: .light; case 8...10: .soft; case 11...13: .fresh
            case 14...16: .cool; case 17...19: .strong; default: .storm
            }
        }
    }

    // MARK: - Step 5: Rain
    private func rollRain(clouds: CloudCover, wind: WindStrength) -> RainLevel {
        let chance = d20()
        let itRains: Bool
        switch clouds {
        case .none: itRains = false
        case .few:  itRains = chance <= 1
        case .lots: itRains = chance <= 4
        case .all:  itRains = chance <= 10
        }
        guard itRains else { return .none }
        return rainIntensity(roll: d20(), wind: wind)
    }
    private func rainIntensity(roll: Int, wind: WindStrength) -> RainLevel {
        let (littleMax, lotsMax): (Int, Int) = switch wind {
        case .none: (12, 19); case .light: (10, 18); case .soft: (8, 17); case .fresh: (6, 15)
        case .cool: (4, 13); case .strong: (2, 11); case .storm: (1, 10)
        }
        if roll <= littleMax { return .little }
        if roll <= lotsMax { return .lots }
        return .all
    }
}
