import Foundation

/// How deep the hero is standing in water (Regelwerk 239, Kampf im Wasser).
/// A situation of the fight that can change between rounds, like Beengte Umgebung.
enum WaterDepth: String, CaseIterable, Identifiable {
    case none, huefthoch, unterWasser

    var id: String { rawValue }
    var nameKey: String { "water.\(rawValue)" }
}
