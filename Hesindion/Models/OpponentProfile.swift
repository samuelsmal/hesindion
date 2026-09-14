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

/// Everything the app has been *told* about one opponent.
///
/// The opponent is not modelled (ADR-0005): there is no LP, no RS and no sheet.
/// What there is, is a handful of facts the GM states and several rules turn on.
/// Split by how long each fact lasts: the shape of the opponent holds for the
/// fight, their posture and the GM's calls about this swing hold for the attack.
///
/// `states` and `facts` are what the catalog predicates read
/// (`opponent.state`, `gm.fact`); the named flags below them are the same
/// facts under the names the views bind to.
struct OpponentProfile: Equatable {

    /// What the GM calls this one ("der Ork links"). Empty for the unnamed
    /// single opponent every fight starts with.
    var label: String = ""

    // MARK: The opponent, for as long as the fight lasts

    var reach: WeaponReach = .mittel
    var bodyPlanKind: BodyPlanKind = .humanoid
    var size: CreatureSize = .mittel
    /// A demon. Only a consecrated weapon has anything to say about it.
    var isDaemon: Bool = false
    /// Fights on foot. `nil` means nobody has said; a mounted hero's
    /// Vorteilhafte Position turns on it, so the evaluator asks.
    var isOnFoot: Bool? = nil

    // MARK: This attack

    /// Statuses the GM has stated for this attack, by `StateCatalog` id.
    var states: Set<String> = []
    /// GM answers about this opponent. A missing key is "not stated", which is
    /// how a rule becomes a question rather than being silently off.
    var facts: [FactKey: Bool] = [:]

    // MARK: The same facts under the names the views bind to

    /// Status Liegend: −2 on *their* defence. The penalty is theirs.
    var isProne: Bool {
        get { states.contains(Self.proneStateId) }
        set { if newValue { states.insert(Self.proneStateId) } else { states.remove(Self.proneStateId) } }
    }
    /// Eases the Zonenaufschlag by 2 (Trefferzonen Fokusregel).
    var isSurprised: Bool {
        get { states.contains(Self.surprisedStateId) }
        set { if newValue { states.insert(Self.surprisedStateId) } else { states.remove(Self.surprisedStateId) } }
    }
    /// The hero is better placed than this opponent: Vorteilhafte Position.
    var advantageousPosition: Bool {
        get { facts[Self.advantageousPositionKey] == true }
        set { facts[Self.advantageousPositionKey] = newValue ? true : nil }
    }
    /// A demon of the deity this weapon is sworn against — doubled TP. Lasts
    /// the fight, like `isDaemon`: the same demon stays the same demon.
    var isOfOpposingDeity: Bool {
        get { facts[Self.opposingDeityKey] == true }
        set { facts[Self.opposingDeityKey] = newValue ? true : nil }
    }

    static let advantageousPositionKey = FactKey(id: "advantageousPosition", span: .attack)
    static let opposingDeityKey = FactKey(id: "opposingDeity", span: .opponent)

    /// `StateCatalog` ids. The status is the opponent's, but the id is the
    /// catalog's, so a rule can name the same status whoever is in it.
    static let proneStateId = "liegend"
    static let surprisedStateId = "ueberrascht"

    /// The table their hit zones are rolled on.
    var bodyPlan: BodyPlan { bodyPlanKind.plan(size: size) }

    /// Everything that changes between one attack and the next, cleared.
    mutating func resetPerAttack() {
        states = []
        facts = facts.filter { $0.key.span != .attack }
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
