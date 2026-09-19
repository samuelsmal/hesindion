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

    /// The size to keep when this plan is picked: `current` if the plan has a
    /// table for it — compared by table key, so winzig survives wherever klein
    /// is published — otherwise the plan's first published size.
    func size(keeping current: CreatureSize) -> CreatureSize {
        guard let first = publishedSizes.first, !publishedSizes.contains(current.tableSize) else { return current }
        return first
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
///
/// **One interaction, one opponent.** Nothing here outlives the attack or the
/// defence that stated it: the next one may well be with somebody else, and a
/// reach, a body plan or a "das ist ein Dämon" carried over from the last one is
/// a fact about a creature that is no longer in front of the hero. `reset()`
/// clears the lot, and two seams call it: `CombatView` whenever the step becomes
/// `.root`, which is where every interaction ends, and `CombatAnnouncementView`
/// as each announcement opens. The root's own defences need the second-to-last
/// answer gone as much as an attack does — a Parade rolled from the root reads
/// this profile through `OpponentRoster`. Everything that belongs to the *same*
/// swing — the off-hand half of a dual attack, the opponent's defence lines, the
/// Karmale-Objekte multiplier, the hit-zone table — is carried in the
/// `CombatStep` payload from that one announcement, so it still sees the
/// opponent it was announced against.
///
/// `states` and `facts` are what the catalog predicates read
/// (`opponent.state`, `gm.fact`); the named flags below them are the same
/// facts under the names the views bind to. `FactKey.span` still says how long
/// a fact is *meant* to be good for — it is the catalog's vocabulary, and the
/// roster this lives in is where a named second opponent would keep its own
/// answers — but with one profile per interaction the app clears them all
/// together.
struct OpponentProfile: Equatable {

    /// What the GM calls this one ("der Ork links"). Empty for the unnamed
    /// single opponent every fight starts with.
    var label: String = ""

    // MARK: The shape of the opponent

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

    /// Status Liegend, stated for this attack. `STATE_10` turns it into the
    /// opponent line.
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
    /// The attack comes from behind — the hero's, or the one the hero is defending
    /// against; the domain says which side pays (GRW_angriffVonHinten).
    var fromBehind: Bool {
        get { facts[Self.fromBehindKey] == true }
        set { facts[Self.fromBehindKey] = newValue ? true : nil }
    }
    /// A demon of the deity this weapon is sworn against — doubled TP. Stated
    /// beside `isDaemon`, and cleared with it when the next announcement opens.
    var isOfOpposingDeity: Bool {
        get { facts[Self.opposingDeityKey] == true }
        set { facts[Self.opposingDeityKey] = newValue ? true : nil }
    }

    static let advantageousPositionKey = FactKey(id: "advantageousPosition", span: .attack)
    static let fromBehindKey = FactKey(id: "fromBehind", span: .attack)
    static let opposingDeityKey = FactKey(id: "opposingDeity", span: .opponent)

    /// `StateCatalog` ids. The status is the opponent's, but the id is the
    /// catalog's, so a rule can name the same status whoever is in it.
    static let proneStateId = "liegend"
    static let surprisedStateId = "ueberrascht"

    /// The table their hit zones are rolled on.
    var bodyPlan: BodyPlan { bodyPlanKind.plan(size: size) }

    /// Back to "nobody has said anything".
    ///
    /// Everything, not only the posture: the reach, the body plan, the size, the
    /// demon and the opposing deity went too, because the next interaction may
    /// be with somebody else entirely and an unasked question is a better default
    /// than last swing's answer about a different creature (owner report). The
    /// facts the fight really does keep are the *hero's* — the loadout, the
    /// states, the Fokus-Regeln — and none of them live here.
    mutating func reset() {
        self = OpponentProfile()
    }

    /// What the announcement does to the opponent's own defence.
    ///
    /// Nothing is applied — they have no PA to subtract from — so this is the
    /// figure the GM takes off theirs. The Finte line is still made here;
    /// every other opponent line is the catalog's (`Evaluation.opponentLines`).
    func defenseModifiers(maneuver: CombatManeuver) -> [ModifierLine] {
        var lines: [ModifierLine] = []
        if case .finte(let tier) = maneuver {
            lines.append(ModifierLine(value: -tier * 2, source: L("maneuver.finte")))
        }
        return lines
    }
}
