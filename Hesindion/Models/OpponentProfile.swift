import Foundation

/// Which published Trefferzonentabelle the other side is built on.
///
/// `BodyPlan` already carries the plan *and* its size as one value; this is the
/// plan half on its own, so a picker can offer it.
enum BodyPlanKind: String, CaseIterable, Identifiable {
    case humanoid
    case vierbeinig
    case sechsbeinigMitSchwanz
    case fangarme
    case keineZonen

    var id: String { rawValue }
    var nameKey: String { "bodyPlan.\(rawValue)" }

    /// The sizes this plan has a published table for. The lookup falls back to
    /// the nearest one either way, but there is no reason to offer a size the
    /// rules never printed for this shape.
    var publishedSizes: [CreatureSize] {
        switch self {
        case .humanoid, .vierbeinig:  [.klein, .mittel, .gross]
        case .sechsbeinigMitSchwanz:  [.gross, .riesig]
        case .fangarme:               [.mittel, .gross, .riesig]
        case .keineZonen:             []
        }
    }

    func plan(size: CreatureSize) -> BodyPlan {
        switch self {
        case .humanoid:              .humanoid(size)
        case .vierbeinig:            .vierbeinig(size)
        case .sechsbeinigMitSchwanz: .sechsbeinigMitSchwanz(size)
        case .fangarme:              .fangarme(size)
        case .keineZonen:            .keineZonen
        }
    }
}

/// Everything the app has been *told* about the other side of the fight.
///
/// The opponent is not modelled (ADR-0005): there is no LP, no RS and no sheet.
/// What there is, is a handful of facts the GM states and several rules turn on
/// — the reach of the weapon in their hand, the table their hit zones are rolled
/// on, whether they are a demon — and until now the app had nowhere to keep any
/// of them. The reach was asked for again on every single attack, and the zone
/// table was the *hero's*, which is the wrong table for anything that is not
/// another person.
///
/// Split by how long each fact lasts: the shape of the opponent holds for the
/// fight, their posture holds for this attack.
struct OpponentProfile: Equatable {

    // MARK: The opponent, for as long as the fight lasts

    var reach: WeaponReach = .mittel
    var bodyPlanKind: BodyPlanKind = .humanoid
    var size: CreatureSize = .mittel
    /// A demon. Only a consecrated weapon has anything to say about it
    /// (`KarmalWeapon`), so it is only asked for when the hero carries one.
    var isDaemon: Bool = false
    /// A demon of the deity this weapon is sworn against — doubled TP.
    var isOfOpposingDeity: Bool = false

    // MARK: This attack

    /// The hero is better placed than the opponent: +2 AT (GRW, Vorteilhafte
    /// Position). Relative to *this* opponent, which is why it lives here.
    var advantageousPosition: Bool = false
    /// Eases the Zonenaufschlag by 2 (Trefferzonen Fokusregel).
    var isSurprised: Bool = false
    /// Status Liegend: "Ihre Verteidigung ist um 2 erschwert, ihre Angriffe um
    /// 4." The penalty is the opponent's, so it lands on their defence, not on
    /// the hero's attack.
    var isProne: Bool = false

    /// The table their hit zones are rolled on.
    var bodyPlan: BodyPlan { bodyPlanKind.plan(size: size) }

    /// Everything that changes between one attack and the next, cleared.
    mutating func resetPerAttack() {
        advantageousPosition = false
        isSurprised = false
        isProne = false
    }

    /// What the announcement does to the opponent's own defence.
    ///
    /// Nothing is applied — they have no PA to subtract from — so this is the
    /// figure the GM takes off theirs.
    func defenseModifiers(maneuver: CombatManeuver, isCriticalHit: Bool = false) -> [ModifierLine] {
        var lines: [ModifierLine] = []
        if case .finte(let tier) = maneuver {
            lines.append(ModifierLine(value: -tier * 2, source: L("maneuver.finte")))
        }
        if isProne {
            lines.append(ModifierLine(value: -2, source: L("opponent.prone")))
        }
        return lines
    }
}
