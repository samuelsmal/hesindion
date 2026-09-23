import Foundation

/// A body zone a hit can land in (DSA 5 Fokus-Trefferzonenregeln).
enum HitZone: String, CaseIterable, Identifiable {
    case kopf, torso, arme, beine
    case vordereBeine, mittlereGliedmassen, hintereBeine, schwanz
    case fangarme, koerper

    var id: String { rawValue }

    /// L() key for the display name.
    var nameKey: String { "hitZone.\(rawValue)" }

    /// Zones that exist as a left/right pair, and therefore carry a `BodySide`.
    var isPaired: Bool {
        switch self {
        case .kopf, .torso, .schwanz, .fangarme, .koerper: false
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

// MARK: - The hero's own body plan

extension Hero {
    /// Which Trefferzonentabelle applies when *this* hero is hit.
    ///
    /// The Fokusregel keys its tables to a body plan and a size category, and the
    /// size is a property of the species, not of the individual — a short human is
    /// still `mittel`. So this is looked up, never derived from the hero's height.
    ///
    /// Species that ship with the rules are defaulted (`HitZoneSizes`); anything
    /// else is unknown until the player says, which the settings screen asks for
    /// when the rule is switched on. An unanswered hero falls back to `mittel`,
    /// the table the app used for everybody before — the wrong answer for a Zwerg,
    /// but the same wrong answer as before rather than a new one.
    var bodyPlan: BodyPlan { .humanoid(sizeCategory) }

    var sizeCategory: CreatureSize {
        if let stored = hitZoneSize, let size = CreatureSize(rawValue: stored) { return size }
        return HitZoneSizes.size(forSpecies: personalData?.species) ?? .mittel
    }

    /// True when neither the player nor the published list has answered, so the
    /// settings screen has something to ask about.
    var needsHitZoneSize: Bool {
        hitZoneSize == nil && HitZoneSizes.size(forSpecies: personalData?.species) == nil
    }
}

/// Size category per species, from the Trefferzonen Fokusregel's own list.
///
/// Kept as a table rather than inferred from a hero's height: the rule assigns the
/// category to the species. Matching is on the species name as Optolith writes it,
/// singular or plural, because that is the only species field every export carries
/// (`rules.db` ships abilities and talents, no species).
enum HitZoneSizes {
    static let klein = ["Zwerg", "Zwerge", "Gnom", "Gnome", "Halbling", "Halblinge"]
    static let mittel = ["Mensch", "Menschen", "Elf", "Elfen", "Halbelf", "Halbelfen",
                         "Orks", "Ork", "Goblin", "Goblins", "Achaz"]

    static func size(forSpecies species: String?) -> CreatureSize? {
        guard let species, !species.isEmpty else { return nil }
        if klein.contains(species) { return .klein }
        if mittel.contains(species) { return .mittel }
        return nil
    }
}
