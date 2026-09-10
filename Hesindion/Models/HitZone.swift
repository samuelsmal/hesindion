import Foundation

/// A body zone a hit can land in (DSA 5 Fokus-Trefferzonenregeln).
enum HitZone: String, CaseIterable, Identifiable {
    case kopf, torso, arme, beine
    case vordereBeine, mittlereGliedmassen, hintereBeine, schwanz

    var id: String { rawValue }

    /// L() key for the display name.
    var nameKey: String { "hitZone.\(rawValue)" }

    /// Zones that exist as a left/right pair, and therefore carry a `BodySide`.
    var isPaired: Bool {
        switch self {
        case .kopf, .torso, .schwanz: false
        default: true
        }
    }
}

enum BodySide: String {
    case links, rechts

    var nameKey: String { "bodySide.\(rawValue)" }
}

/// A resolved hit: the zone, plus the side for paired zones.
struct HitZoneHit: Equatable {
    let zone: HitZone
    /// `nil` for unpaired zones (Kopf, Torso, Schwanz).
    let side: BodySide?
}
