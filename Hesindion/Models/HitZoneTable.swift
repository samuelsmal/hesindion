import Foundation

enum CreatureSize { case klein, mittel, gross, riesig }

/// Body plans with a published Trefferzonen table.
enum BodyPlan: Equatable {
    case humanoid(CreatureSize)              // klein, mittel, gross
    case vierbeinig(CreatureSize)            // klein, mittel, gross
    case sechsbeinigMitSchwanz(CreatureSize) // gross, riesig
    case fangarme(CreatureSize)              // mittel bis riesig
    /// Nicht humanoid, keine unterschiedlichen Zonen (e.g. Riesenamöbe). Only one
    /// published table, so — unlike every other case — there is no size parameter.
    case keineZonen
}

/// The DSA 5 Trefferzonen tables (Fokus-Regeln).
///
/// Static in-code tables, following `FumbleTable`. Odd rolls hit the left side,
/// even rolls the right; unpaired zones report no side.
enum HitZoneTable {

    /// One contiguous 1W20 range mapped to a zone.
    private struct ZoneRange {
        let lower: Int
        let upper: Int
        let zone: HitZone
    }

    /// Resolve a 1W20 roll against a body plan. Rolls outside 1...20 are clamped.
    static func lookup(_ roll: Int, plan: BodyPlan) -> HitZoneHit {
        let clamped = min(max(roll, 1), 20)
        let table = ranges(for: plan)
        let zone = table.first { clamped >= $0.lower && clamped <= $0.upper }?.zone ?? {
            assertionFailure("HitZoneTable: no range covers roll \(clamped) for plan \(plan) — falling back to .torso")
            return .torso
        }()
        let side: BodySide? = zone.isPaired ? (clamped.isMultiple(of: 2) ? .rechts : .links) : nil
        return HitZoneHit(zone: zone, side: side)
    }

    /// Unlisted size combinations fall back to the nearest published table
    /// (`.gross` for six-limbed, `.mittel` for the rest) rather than trapping.
    private static func ranges(for plan: BodyPlan) -> [ZoneRange] {
        switch plan {
        case .humanoid(.klein):   humanoidKlein
        case .humanoid(.gross), .humanoid(.riesig): humanoidGross
        case .humanoid:           humanoidMittel

        case .vierbeinig(.klein): vierbeinigKlein
        case .vierbeinig(.gross), .vierbeinig(.riesig): vierbeinigGross
        case .vierbeinig:         vierbeinigMittel

        case .sechsbeinigMitSchwanz(.riesig): sechsbeinigRiesig
        case .sechsbeinigMitSchwanz:          sechsbeinigGross

        case .fangarme:  fangarme
        case .keineZonen: keineZonen
        }
    }

    // MARK: - Humanoid (Fokus-Regeln: Trefferzonen)

    private static let humanoidKlein: [ZoneRange] = [
        ZoneRange(lower: 1, upper: 6, zone: .kopf),
        ZoneRange(lower: 7, upper: 10, zone: .torso),
        ZoneRange(lower: 11, upper: 18, zone: .arme),
        ZoneRange(lower: 19, upper: 20, zone: .beine),
    ]

    private static let humanoidMittel: [ZoneRange] = [
        ZoneRange(lower: 1, upper: 2, zone: .kopf),
        ZoneRange(lower: 3, upper: 12, zone: .torso),
        ZoneRange(lower: 13, upper: 16, zone: .arme),
        ZoneRange(lower: 17, upper: 20, zone: .beine),
    ]

    private static let humanoidGross: [ZoneRange] = [
        ZoneRange(lower: 1, upper: 2, zone: .kopf),
        ZoneRange(lower: 3, upper: 6, zone: .torso),
        ZoneRange(lower: 7, upper: 16, zone: .arme),
        ZoneRange(lower: 17, upper: 20, zone: .beine),
    ]

    // MARK: - Vierbeinig

    private static let vierbeinigKlein: [ZoneRange] = [
        ZoneRange(lower: 1, upper: 4, zone: .kopf),
        ZoneRange(lower: 5, upper: 12, zone: .torso),
        ZoneRange(lower: 13, upper: 16, zone: .vordereBeine),
        ZoneRange(lower: 17, upper: 20, zone: .hintereBeine),
    ]

    private static let vierbeinigMittel: [ZoneRange] = [
        ZoneRange(lower: 1, upper: 4, zone: .kopf),
        ZoneRange(lower: 5, upper: 10, zone: .torso),
        ZoneRange(lower: 11, upper: 16, zone: .vordereBeine),
        ZoneRange(lower: 17, upper: 20, zone: .hintereBeine),
    ]

    private static let vierbeinigGross: [ZoneRange] = [
        ZoneRange(lower: 1, upper: 5, zone: .kopf),
        ZoneRange(lower: 6, upper: 11, zone: .torso),
        ZoneRange(lower: 12, upper: 16, zone: .vordereBeine),
        ZoneRange(lower: 17, upper: 20, zone: .hintereBeine),
    ]

    // MARK: - Sechsbeinig mit Schwanz

    private static let sechsbeinigGross: [ZoneRange] = [
        ZoneRange(lower: 1, upper: 4, zone: .kopf),
        ZoneRange(lower: 5, upper: 12, zone: .torso),
        ZoneRange(lower: 13, upper: 14, zone: .vordereBeine),
        ZoneRange(lower: 15, upper: 16, zone: .mittlereGliedmassen),
        ZoneRange(lower: 17, upper: 18, zone: .hintereBeine),
        ZoneRange(lower: 19, upper: 20, zone: .schwanz),
    ]

    private static let sechsbeinigRiesig: [ZoneRange] = [
        ZoneRange(lower: 1, upper: 2, zone: .kopf),
        ZoneRange(lower: 3, upper: 10, zone: .torso),
        ZoneRange(lower: 11, upper: 14, zone: .vordereBeine),
        ZoneRange(lower: 15, upper: 16, zone: .mittlereGliedmassen),
        ZoneRange(lower: 17, upper: 18, zone: .hintereBeine),
        ZoneRange(lower: 19, upper: 20, zone: .schwanz),
    ]

    // MARK: - Nicht humanoid, Fangarme

    /// Torso comes *before* Kopf here — this is the one published table with that
    /// order, not a typo. The rules split 7-20 evenly across the creature's tentacles
    /// with overspill going to the torso; per-creature tentacle counts are GM
    /// adjudication, so the whole 7-20 band resolves to a single `.fangarme` zone here.
    private static let fangarme: [ZoneRange] = [
        ZoneRange(lower: 1, upper: 2, zone: .torso),
        ZoneRange(lower: 3, upper: 6, zone: .kopf),
        ZoneRange(lower: 7, upper: 20, zone: .fangarme),
    ]

    // MARK: - Nicht humanoid, keine unterschiedlichen Zonen

    private static let keineZonen: [ZoneRange] = [
        ZoneRange(lower: 1, upper: 20, zone: .koerper),
    ]
}
