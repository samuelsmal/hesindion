import Foundation

// MARK: - Macro Region (grouping for the picker, north → south)

enum MacroRegion: String, Codable, CaseIterable, Identifiable {
    case hoherNorden, hochgebirge, nordaventurien, zentralaventurien,
         tulamidenlande, suedaventurien, tieferSueden
    var id: String { rawValue }
    var displayName: String { L("macro.\(rawValue)") }
}

// MARK: - Weather Region (named, player-facing)

enum WeatherRegion: String, Codable, CaseIterable, Identifiable {
    case ewigesEis, nivesenland, gjalskerland
    case ehernesSchwert, raschtulswall
    case thorwal, bornland, svelltland, orkland
    case mittelreich, streitendeKoenigreiche, elfenlande
    case aranien, khom, mhanadiTal
    case almada, horasreich, ersteSonne, zyklopeninseln
    case meridiana, echsensuempfe, maraskan, suedmeer

    var id: String { rawValue }

    var displayName: String { L("region.\(rawValue)") }

    var macroRegion: MacroRegion {
        switch self {
        case .ewigesEis, .nivesenland, .gjalskerland: .hoherNorden
        case .ehernesSchwert, .raschtulswall: .hochgebirge
        case .thorwal, .bornland, .svelltland, .orkland: .nordaventurien
        case .mittelreich, .streitendeKoenigreiche, .elfenlande: .zentralaventurien
        case .aranien, .khom, .mhanadiTal: .tulamidenlande
        case .almada, .horasreich, .ersteSonne, .zyklopeninseln: .suedaventurien
        case .meridiana, .echsensuempfe, .maraskan, .suedmeer: .tieferSueden
        }
    }

    var archetype: ClimateArchetype {
        switch self {
        case .ewigesEis: .polar
        case .nivesenland, .gjalskerland, .orkland: .subarctic
        case .ehernesSchwert: .highMountainIce
        case .raschtulswall: .highMountain
        case .thorwal: .coldCoast
        case .bornland, .svelltland: .coldContinental
        case .mittelreich, .streitendeKoenigreiche, .elfenlande: .temperate
        case .aranien: .semiArid
        case .khom: .desert
        case .mhanadiTal, .ersteSonne: .subtropicalHot
        case .almada, .horasreich, .zyklopeninseln: .mediterranean
        case .meridiana, .echsensuempfe, .maraskan: .tropicalHumid
        case .suedmeer: .tropicalSea
        }
    }

    /// All regions of a macro-region, in declaration order (for grouped pickers).
    static func inMacro(_ macro: MacroRegion) -> [WeatherRegion] {
        allCases.filter { $0.macroRegion == macro }
    }

    /// Resolve a persisted raw value, mapping retired legacy zone names.
    static func resolve(persisted raw: String) -> WeatherRegion {
        if let direct = WeatherRegion(rawValue: raw) { return direct }
        return legacyMap[raw] ?? .mittelreich
    }

    /// Old (pre-redesign) raw values that no longer exist as cases.
    private static let legacyMap: [String: WeatherRegion] = [
        "hoherNorden": .nivesenland,
        "tundra": .nivesenland,
        "weiden": .streitendeKoenigreiche,
        "horasreichSued": .ersteSonne,
        // ewigesEis, ehernesSchwert, thorwal, mittelreich, almada,
        // raschtulswall, khom, echsensuempfe, suedmeer keep their raw values.
    ]
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
