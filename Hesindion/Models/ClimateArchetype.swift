import Foundation

/// Climate profile that drives all weather numbers. Regions map onto these.
enum ClimateArchetype: String, Codable, CaseIterable {
    case polar, subarctic, highMountainIce, highMountain,
         coldCoast, coldContinental, temperate, mediterranean,
         semiArid, desert, subtropicalHot, tropicalHumid, tropicalSea

    enum Humidity: String, Codable { case dry, moderate, humid }
    enum Windiness: String, Codable {
        case calm, moderate, windy
        var rollBonus: Int { switch self { case .calm: 0; case .moderate: 0; case .windy: 2 } }
    }

    /// Typical day-high baseline (summer, spring/autumn, winter).
    private var baseTemps: (summer: Int, springAutumn: Int, winter: Int) {
        switch self {
        case .polar:            (-20, -30, -40)
        case .subarctic:        (  5,   0,  -5)
        case .highMountainIce:  (-10, -20, -30)
        case .highMountain:     (  5,   0, -10)
        case .coldCoast:        ( 10,   3,  -5)
        case .coldContinental:  ( 10,   3,  -5)
        case .temperate:        ( 15,  10,   5)
        case .mediterranean:    ( 20,  15,  10)
        case .semiArid:         ( 25,  18,  12)
        case .desert:           ( 40,  35,  30)
        case .subtropicalHot:   ( 30,  25,  18)
        case .tropicalHumid:    ( 30,  25,  20)
        case .tropicalSea:      ( 35,  30,  25)
        }
    }

    /// Diurnal range under clear, calm skies (summer, spring/autumn, winter).
    private var clearSkyRanges: (summer: Int, springAutumn: Int, winter: Int) {
        switch self {
        case .polar:            (10,  9,  7)
        case .subarctic:        (14, 11,  8)
        case .highMountainIce:  (14, 12,  9)
        case .highMountain:     (16, 13, 10)
        case .coldCoast:        ( 9,  8,  7)
        case .coldContinental:  (14, 11,  8)
        case .temperate:        (14, 11,  8)
        case .mediterranean:    (13, 11,  9)
        case .semiArid:         (18, 15, 12)
        case .desert:           (26, 24, 20)
        case .subtropicalHot:   (16, 14, 11)
        case .tropicalHumid:    ( 6,  5,  5)
        case .tropicalSea:      ( 4,  4,  4)
        }
    }

    func baseDayTemp(for season: AventurianSeason) -> Int {
        switch season {
        case .sommer: baseTemps.summer
        case .herbst, .fruehling: baseTemps.springAutumn
        case .winter: baseTemps.winter
        }
    }

    func clearSkyRange(for season: AventurianSeason) -> Int {
        switch season {
        case .sommer: clearSkyRanges.summer
        case .herbst, .fruehling: clearSkyRanges.springAutumn
        case .winter: clearSkyRanges.winter
        }
    }

    var humidity: Humidity {
        switch self {
        case .polar, .subarctic, .highMountainIce, .highMountain, .semiArid, .desert, .subtropicalHot: .dry
        case .coldCoast, .coldContinental, .temperate, .mediterranean: .moderate
        case .tropicalHumid, .tropicalSea: .humid
        }
    }

    var windiness: Windiness {
        switch self {
        case .polar, .subarctic, .highMountainIce, .highMountain, .coldCoast, .semiArid, .desert: .windy
        case .coldContinental, .mediterranean, .subtropicalHot, .tropicalSea: .moderate
        case .temperate, .tropicalHumid: .calm
        }
    }

    var displayName: String { L("climate.\(rawValue)") }
}
