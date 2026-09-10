import Foundation

enum CreatureSize { case klein, mittel, gross, riesig }

/// Body plans with a published Trefferzonen table.
enum BodyPlan: Equatable {
    case humanoid(CreatureSize)              // klein, mittel, gross
    case vierbeinig(CreatureSize)            // klein, mittel, gross
    case sechsbeinigMitSchwanz(CreatureSize) // gross, riesig
}

/// The DSA 5 Trefferzonen tables (Fokus-Regeln).
///
/// Static in-code tables, following `FumbleTable`. Odd rolls hit the left side,
/// even rolls the right; unpaired zones report no side.
enum HitZoneTable {

    /// One contiguous 1W20 range mapped to a zone.
    private struct Range {
        let lower: Int
        let upper: Int
        let zone: HitZone
    }

    /// Resolve a 1W20 roll against a body plan. Rolls outside 1...20 are clamped.
    static func lookup(_ roll: Int, plan: BodyPlan) -> HitZoneHit {
        let clamped = min(max(roll, 1), 20)
        let table = ranges(for: plan)
        let zone = table.first { clamped >= $0.lower && clamped <= $0.upper }?.zone ?? .torso
        let side: BodySide? = zone.isPaired ? (clamped.isMultiple(of: 2) ? .rechts : .links) : nil
        return HitZoneHit(zone: zone, side: side)
    }

    /// Unlisted size combinations fall back to the nearest published table
    /// (`.gross` for six-limbed, `.mittel` for the rest) rather than trapping.
    private static func ranges(for plan: BodyPlan) -> [Range] {
        switch plan {
        case .humanoid(.klein):   humanoidKlein
        case .humanoid(.gross), .humanoid(.riesig): humanoidGross
        case .humanoid:           humanoidMittel

        case .vierbeinig(.klein): vierbeinigKlein
        case .vierbeinig(.gross), .vierbeinig(.riesig): vierbeinigGross
        case .vierbeinig:         vierbeinigMittel

        case .sechsbeinigMitSchwanz(.riesig): sechsbeinigRiesig
        case .sechsbeinigMitSchwanz:          sechsbeinigGross
        }
    }

    // MARK: - Humanoid (Fokus-Regeln: Trefferzonen)

    private static let humanoidKlein: [Range] = [
        Range(lower: 1, upper: 6, zone: .kopf),
        Range(lower: 7, upper: 10, zone: .torso),
        Range(lower: 11, upper: 18, zone: .arme),
        Range(lower: 19, upper: 20, zone: .beine),
    ]

    private static let humanoidMittel: [Range] = [
        Range(lower: 1, upper: 2, zone: .kopf),
        Range(lower: 3, upper: 12, zone: .torso),
        Range(lower: 13, upper: 16, zone: .arme),
        Range(lower: 17, upper: 20, zone: .beine),
    ]

    private static let humanoidGross: [Range] = [
        Range(lower: 1, upper: 2, zone: .kopf),
        Range(lower: 3, upper: 6, zone: .torso),
        Range(lower: 7, upper: 16, zone: .arme),
        Range(lower: 17, upper: 20, zone: .beine),
    ]

    // MARK: - Vierbeinig

    private static let vierbeinigKlein: [Range] = [
        Range(lower: 1, upper: 4, zone: .kopf),
        Range(lower: 5, upper: 12, zone: .torso),
        Range(lower: 13, upper: 16, zone: .vordereBeine),
        Range(lower: 17, upper: 20, zone: .hintereBeine),
    ]

    private static let vierbeinigMittel: [Range] = [
        Range(lower: 1, upper: 4, zone: .kopf),
        Range(lower: 5, upper: 10, zone: .torso),
        Range(lower: 11, upper: 16, zone: .vordereBeine),
        Range(lower: 17, upper: 20, zone: .hintereBeine),
    ]

    private static let vierbeinigGross: [Range] = [
        Range(lower: 1, upper: 5, zone: .kopf),
        Range(lower: 6, upper: 11, zone: .torso),
        Range(lower: 12, upper: 16, zone: .vordereBeine),
        Range(lower: 17, upper: 20, zone: .hintereBeine),
    ]

    // MARK: - Sechsbeinig mit Schwanz

    private static let sechsbeinigGross: [Range] = [
        Range(lower: 1, upper: 4, zone: .kopf),
        Range(lower: 5, upper: 12, zone: .torso),
        Range(lower: 13, upper: 14, zone: .vordereBeine),
        Range(lower: 15, upper: 16, zone: .mittlereGliedmassen),
        Range(lower: 17, upper: 18, zone: .hintereBeine),
        Range(lower: 19, upper: 20, zone: .schwanz),
    ]

    private static let sechsbeinigRiesig: [Range] = [
        Range(lower: 1, upper: 2, zone: .kopf),
        Range(lower: 3, upper: 10, zone: .torso),
        Range(lower: 11, upper: 14, zone: .vordereBeine),
        Range(lower: 15, upper: 16, zone: .mittlereGliedmassen),
        Range(lower: 17, upper: 18, zone: .hintereBeine),
        Range(lower: 19, upper: 20, zone: .schwanz),
    ]
}
