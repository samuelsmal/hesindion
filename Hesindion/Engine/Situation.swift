import Foundation

/// The domains a catalog clause can name: every check the app rolls, plus the
/// damage roll. `CheckDomain` stays the key the Swift definitions and the
/// state catalog use; `damage` has no Swift definitions, only catalog ones.
enum RuleDomain: String, CaseIterable, Codable {
    case meleeAttack, meleeParry, meleeDodge, rangedAttack
    case spellCasting, liturgyCasting, talentCheck
    case damage

    var checkDomain: CheckDomain? { CheckDomain(rawValue: rawValue) }
}

/// How long an answer the GM gives is good for (design §3).
enum FactSpan: String, CaseIterable, Codable {
    /// Until changed in settings. Lives on `Hero`.
    case hero
    /// The fight. Lives on the roster entry.
    case opponent
    /// This attack. Lives on the roster entry, cleared by `resetPerAttack`.
    case attack
    /// The round. Lives on `CombatSituation`.
    case round
}

/// A GM fact, named and scoped. The subject is whichever entry holds it.
struct FactKey: Hashable {
    let id: String
    let span: FactSpan
}

/// The opponents the GM has described, and which one the hero is facing.
///
/// Never empty: a fight with nobody described still has one unnamed opponent
/// with default facts, which is what `OpponentProfile()` has always meant.
struct OpponentRoster: Equatable {
    var entries: [OpponentProfile]
    var currentIndex: Int

    init(_ entries: [OpponentProfile] = [OpponentProfile()], currentIndex: Int = 0) {
        precondition(!entries.isEmpty, "a roster has at least one opponent")
        self.entries = entries
        self.currentIndex = min(max(currentIndex, 0), entries.count - 1)
    }

    /// The entry the hero is facing. The index is clamped here as well as in
    /// `init`, because both stored properties are assigned directly by the
    /// views and the tests; an empty roster is the one thing that stays fatal.
    private var safeIndex: Int {
        precondition(!entries.isEmpty, "a roster has at least one opponent")
        return min(max(currentIndex, 0), entries.count - 1)
    }

    var current: OpponentProfile {
        get { entries[safeIndex] }
        set { entries[safeIndex] = newValue }
    }
}

/// Everything a roll is evaluated against, as one plain value the view
/// assembles (design §3). It replaces `ModifierContext`, whose 33 flat fields
/// mixed what the hero is, what the round is, and what the GM said about the
/// other side. The round is `CombatSituation`; the other side is the roster;
/// what belongs to this one attack or check sits beside them.
///
/// The ranged and magic inputs are still flat: their Swift definitions have
/// not moved to the catalog yet, and they move with them.
struct Situation {
    let hero: Hero
    let domain: RuleDomain

    var round = CombatSituation()
    var opponents = OpponentRoster()

    // MARK: This attack

    /// The loadout piece in the hand — a weapon, a shield, or "Raufen". `nil`
    /// means the main weapon.
    var loadoutName: String? = nil
    var maneuver: CombatManeuver = .normal
    var isOffHand = false
    var targetHitZone: HitZone? = nil

    // MARK: This check

    /// The talent under check, for `talentCheck`.
    var talentId: String? = nil
    /// The Selbstbeherrschung check a Wundeffekt demands, not a free-standing one.
    var isWoundEffectProbe = false
    var gottgefaellig = false

    // MARK: Ranged (moves with RangedModifiers)

    var distanz: Int = 1
    var groesse: Int = 2
    var bewegungZiel: Int = 1
    var bewegungSchuetze: Int = 0
    var sicht: Int = 0
    var kampfgetuemmel: Bool = false
    var zielen: Int = 0
    var vomPferd: Int = 0

    // MARK: Magic (moves with MagicModifiers)

    var maintainedSpellCount: Int = 0
    var foreignTradition: Bool = false
    var omitGesture: Bool = false
    var omitFormula: Bool = false
    var ironSteinCarried: Int = 0
    var distractionLevel: Int = 0
    var spellModifications: [SpellModification] = []

    init(hero: Hero, domain: RuleDomain) {
        self.hero = hero
        self.domain = domain
    }

    var checkDomain: CheckDomain? { domain.checkDomain }
    var opponent: OpponentProfile { opponents.current }
    /// Defences of this domain's kind already made this round.
    var defencesThisRound: Int { round.defensesSoFar(isAusweichen: domain == .meleeDodge) }
}
