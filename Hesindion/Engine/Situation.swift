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
    /// This opponent, for as long as they are the one being fought. Lives on
    /// the roster entry.
    case opponent
    /// This attack. Lives on the roster entry too.
    ///
    /// The app holds one profile at a time and `OpponentProfile.reset()` clears
    /// both spans as each announcement opens — the next swing may be at somebody
    /// else — so today the two have the same lifetime in the UI. The distinction
    /// is the catalog's vocabulary and stays: it is what a rule *means* by its
    /// fact, and a named roster of several opponents would keep the `.opponent`
    /// ones per entry.
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
    /// The piece of the loadout this roll is made **with**, where the caller
    /// knows it and `loadoutName` does not say: the shield or the off-hand
    /// weapon on a parry.
    ///
    /// Separate from `loadoutName` on purpose. `loadoutName` also decides the
    /// *reach* the catalog reads, and on a parry that is still the main weapon
    /// (`GRW_beengteUmgebung`'s note says so, until step 3 names the parrying
    /// piece there). Naming the shield through `loadoutName` would change that
    /// rule as a side effect of a Patzer; this field only answers "which thing
    /// is in the hand", which is all a damaged item asks.
    var itemInHand: String? = nil
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

    // MARK: Offers taken

    /// `choice` offers taken, rule id → option index, and tiered offers
    /// announced, rule id → tier. Explicit entries win over the bridge from
    /// the legacy fields (`round.plaenkler…`, `maneuver`) that the views still
    /// set; step 3 writes these directly and the bridge goes.
    var choices: [String: Int] = [:]
    var announced: [String: Int] = [:]

    var effectiveChoices: [String: Int] { round.chosenOptions.merging(choices) { _, explicit in explicit } }
    var effectiveAnnounced: [String: Int] { Self.announced(for: maneuver).merging(announced) { _, explicit in explicit } }

    /// The manoeuvre enum as the catalog names it: rule id → tier.
    static func announced(for maneuver: CombatManeuver) -> [String: Int] {
        switch maneuver {
        case .normal:                  [:]
        case .finte(let tier):         [CombatAbility.finte.rawValue: tier]
        case .wuchtschlag(let tier):   [CombatAbility.wuchtschlag.rawValue: tier]
        case .vorstoss:                [CombatAbility.vorstoss.rawValue: 1]
        case .schildspalter:           [CombatAbility.schildspalter.rawValue: 1]
        case .sturmangriff:            [CombatAbility.berittenerKampf.rawValue: 1]
        }
    }

    // MARK: The loadout piece in the hand

    /// The melee weapon being swung or parried with: the named one, else the
    /// main weapon. `nil` for a shield, a fist, or a name that matches nothing.
    var loadoutWeapon: MeleeWeapon? {
        if let name = loadoutName { return hero.meleeWeapons.first { $0.name == name } }
        return hero.selectedWeapon
    }

    /// The name of the thing this roll uses, for rules that key on the *item*
    /// rather than on its reach — a Patzer-damaged weapon or shield, so far.
    /// A shot uses the slung ranged weapon; everything else uses what the
    /// caller named, and the main weapon when it named nothing.
    var itemInHandName: String? {
        if let itemInHand { return itemInHand }
        if domain == .rangedAttack { return hero.selectedRangedWeaponName }
        if let loadoutName { return loadoutName }
        return hero.selectedWeaponName
    }

    /// Its reach. Bare hands are kurz (GRW, waffenlose Kampftechniken).
    var loadoutReach: WeaponReach {
        if let name = loadoutName { return hero.reach(ofLoadoutNamed: name) }
        if let weapon = hero.selectedWeapon { return WeaponReach(rawValue: weapon.reach) ?? .mittel }
        return .kurz
    }

    init(hero: Hero, domain: RuleDomain) {
        self.hero = hero
        self.domain = domain
    }

    var checkDomain: CheckDomain? { domain.checkDomain }
    var opponent: OpponentProfile { opponents.current }
    /// Defences of this domain's kind already made this round.
    var defencesThisRound: Int { round.defensesSoFar(isAusweichen: domain == .meleeDodge) }
}

extension Situation {
    /// The Selbstbeherrschung check a Wundeffekt demands — `CombatTakeDamageView`
    /// opens `TalentProbeModal` with `isWoundEffectProbe: true` for it. Built in
    /// one place so the wound panel's preview number (`CombatWoundEffectPanel`)
    /// and the modal that actually rolls it read the same catalog lines —
    /// Verweichlicht (DISADV_57) among them — and cannot drift apart.
    static func woundEffectProbe(hero: Hero, talentId: String) -> Situation {
        var situation = Situation(hero: hero, domain: .talentCheck)
        situation.talentId = talentId
        situation.isWoundEffectProbe = true
        return situation
    }
}
