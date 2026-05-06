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

/// Generates DSA weather using WdE p.156ff tables.
struct WeatherGenerator {
    let region: WeatherRegion
    let desert: Bool
    let windy: Bool

    // MARK: - Public API

    func generate(date: AventurianDate, previousResult: WeatherResult?) -> WeatherResult {
        let season = date.season
        let changeFlags = rollChangeFlags(season: season, hasPrevious: previousResult != nil)

        let clouds = (changeFlags & 0b0001 != 0)
            ? Self.cloudFromRoll(d20(), desert: desert)
            : (previousResult?.clouds ?? Self.cloudFromRoll(d20(), desert: desert))

        let wind = (changeFlags & 0b0010 != 0)
            ? Self.windFromRoll(d20() + (windy ? 2 : 0), autumn: season == .herbst)
            : (previousResult?.wind ?? Self.windFromRoll(d20() + (windy ? 2 : 0), autumn: season == .herbst))

        let base = region.baseTemperature(for: season)
        let dayTemp: Int
        let nightTemp: Int
        if changeFlags & 0b0100 != 0 {
            dayTemp = base + clouds.temperatureModifier + wind.temperatureModifier
            let nightDrop = d20() + 5  // 6..25
            nightTemp = dayTemp - nightDrop
        } else if let prev = previousResult {
            dayTemp = prev.dayTemperature
            nightTemp = prev.nightTemperature
        } else {
            dayTemp = base + clouds.temperatureModifier + wind.temperatureModifier
            let nightDrop = d20() + 5  // 6..25
            nightTemp = dayTemp - nightDrop
        }

        let rain = (changeFlags & 0b1000 != 0)
            ? rollRain(clouds: clouds, wind: wind)
            : (previousResult?.rain ?? rollRain(clouds: clouds, wind: wind))

        return WeatherResult(
            date: date,
            clouds: clouds,
            wind: wind,
            dayTemperature: dayTemp,
            nightTemperature: nightTemp,
            rain: rain
        )
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

    // MARK: - Dice

    private func d20() -> Int {
        Int.random(in: 1...20)
    }

    // MARK: - Step 1: Day-change flags

    private func rollChangeFlags(season: AventurianSeason, hasPrevious: Bool) -> UInt8 {
        guard hasPrevious else { return 0b1111 }
        let roll = d20()
        switch season {
        case .sommer, .winter:
            return stableChangeFlags(roll)
        case .herbst, .fruehling:
            return volatileChangeFlags(roll)
        }
    }

    private func stableChangeFlags(_ roll: Int) -> UInt8 {
        switch roll {
        case 1...9:   0b0000
        case 10...11: 0b0001
        case 12...13: 0b0011
        case 14...15: 0b0101
        case 16...17: 0b0111
        case 18...19: 0b1011
        default:      0b1111
        }
    }

    private func volatileChangeFlags(_ roll: Int) -> UInt8 {
        switch roll {
        case 1...4:   0b0000
        case 5...6:   0b0001
        case 7...8:   0b0011
        case 9...10:  0b0101
        case 11...12: 0b0111
        case 13...14: 0b1001
        case 15...16: 0b1011
        case 17...18: 0b1101
        default:      0b1111
        }
    }

    // MARK: - Step 2: Clouds

    static func cloudFromRoll(_ roll: Int, desert: Bool) -> CloudCover {
        if desert {
            switch roll {
            case ...16:   return .none
            case 17...18: return .few
            case 19:      return .lots
            default:      return .all
            }
        }
        switch roll {
        case ...4:    return .none
        case 5...10:  return .few
        case 11...16: return .lots
        default:      return .all
        }
    }

    // MARK: - Step 3: Wind

    static func windFromRoll(_ roll: Int, autumn: Bool) -> WindStrength {
        if autumn {
            switch roll {
            case ...3:    return .none
            case 4...5:   return .light
            case 6...7:   return .soft
            case 8...10:  return .fresh
            case 11...14: return .cool
            case 15...18: return .strong
            default:      return .storm
            }
        }
        switch roll {
        case ...4:    return .none
        case 5...7:   return .light
        case 8...10:  return .soft
        case 11...13: return .fresh
        case 14...16: return .cool
        case 17...19: return .strong
        default:      return .storm
        }
    }

    // MARK: - Step 5: Rain

    private func rollRain(clouds: CloudCover, wind: WindStrength) -> RainLevel {
        let rainChanceRoll = d20()
        let itRains: Bool
        switch clouds {
        case .none: itRains = false
        case .few:  itRains = rainChanceRoll <= 1
        case .lots: itRains = rainChanceRoll <= 4
        case .all:  itRains = rainChanceRoll <= 10
        }
        guard itRains else { return .none }

        let intensityRoll = d20()
        return rainIntensity(roll: intensityRoll, wind: wind)
    }

    private func rainIntensity(roll: Int, wind: WindStrength) -> RainLevel {
        let (littleMax, lotsMax): (Int, Int) = switch wind {
        case .none:   (12, 19)
        case .light:  (10, 18)
        case .soft:   (8, 17)
        case .fresh:  (6, 15)
        case .cool:   (4, 13)
        case .strong: (2, 11)
        case .storm:  (1, 10)
        }
        if roll <= littleMax { return .little }
        if roll <= lotsMax { return .lots }
        return .all
    }
}
