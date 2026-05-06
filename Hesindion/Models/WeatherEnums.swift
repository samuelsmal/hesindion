import Foundation

// MARK: - Weather Region

enum WeatherRegion: String, Codable, CaseIterable, Identifiable {
    case ewigesEis
    case ehernesSchwert
    case hoherNorden
    case tundra
    case thorwal
    case weiden
    case mittelreich
    case almada
    case raschtulswall
    case horasreichSued
    case khom
    case echsensuempfe
    case suedmeer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ewigesEis: "Ewiges Eis"
        case .ehernesSchwert: "Höhen des Ehernen Schwerts"
        case .hoherNorden: "Hoher Norden"
        case .tundra: "Tundra und Taiga"
        case .thorwal: "Bornland, Thorwal"
        case .weiden: "Streitende Königreiche bis Weiden"
        case .mittelreich: "Zentrales Mittelreich"
        case .almada: "Nördliches Horasreich, Almada, Aranien"
        case .raschtulswall: "Höhen des Raschtulswalls"
        case .horasreichSued: "Südliches Horasreich, Reich der Ersten Sonne"
        case .khom: "Khom"
        case .echsensuempfe: "Echsensümpfe, Meridiana"
        case .suedmeer: "Altoum, Gewürzinseln, Südmeer"
        }
    }

    /// Base temperature tuple: (summer, spring/autumn, winter)
    private var baseTemps: (summer: Int, springAutumn: Int, winter: Int) {
        switch self {
        case .ewigesEis:       (-20, -30, -40)
        case .ehernesSchwert:  (-10, -20, -30)
        case .hoherNorden:     (  0, -10, -20)
        case .tundra:          (  5,   0,  -5)
        case .thorwal:         ( 10,   3,  -5)
        case .weiden:          ( 10,   5,   0)
        case .mittelreich:     ( 15,  10,   5)
        case .almada:          ( 20,  15,  10)
        case .raschtulswall:   (  5,   0, -10)
        case .horasreichSued:  ( 25,  20,  15)
        case .khom:            ( 40,  35,  30)
        case .echsensuempfe:   ( 30,  25,  20)
        case .suedmeer:        ( 35,  30,  25)
        }
    }

    func baseTemperature(for season: AventurianSeason) -> Int {
        switch season {
        case .sommer: baseTemps.summer
        case .herbst, .fruehling: baseTemps.springAutumn
        case .winter: baseTemps.winter
        }
    }
}

// MARK: - Cloud Cover

enum CloudCover: String, Codable, CaseIterable {
    case none, few, lots, all

    var temperatureModifier: Int {
        switch self {
        case .none: 10
        case .few: 5
        case .lots: 0
        case .all: -5
        }
    }

    var displayName: String {
        switch self {
        case .none: L("weather.clouds.none")
        case .few: L("weather.clouds.few")
        case .lots: L("weather.clouds.lots")
        case .all: L("weather.clouds.all")
        }
    }
}

// MARK: - Wind Strength

enum WindStrength: String, Codable, CaseIterable {
    case none, light, soft, fresh, cool, strong, storm

    var temperatureModifier: Int {
        switch self {
        case .none: 4
        case .light: 2
        case .soft, .fresh: 0
        case .cool: -2
        case .strong: -4
        case .storm: -6
        }
    }

    var displayName: String {
        switch self {
        case .none: L("weather.wind.none")
        case .light: L("weather.wind.light")
        case .soft: L("weather.wind.soft")
        case .fresh: L("weather.wind.fresh")
        case .cool: L("weather.wind.cool")
        case .strong: L("weather.wind.strong")
        case .storm: L("weather.wind.storm")
        }
    }
}

// MARK: - Rain Level

enum RainLevel: String, Codable, CaseIterable {
    case none, little, lots, all

    var displayName: String {
        switch self {
        case .none: L("weather.rain.none")
        case .little: L("weather.rain.little")
        case .lots: L("weather.rain.lots")
        case .all: L("weather.rain.all")
        }
    }
}
