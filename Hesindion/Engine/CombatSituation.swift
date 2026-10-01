import Foundation

/// The round-and-session flags every combat check needs, in one value.
///
/// It exists because the combat root and the weapon list are two different ways
/// into the *same* defence, and only the root was building modifier lines: a
/// hero with a shield or a second weapon picked the parrying weapon first, and
/// that screen rolled a bare PA — no Mehrfache Verteidigung, no Schmerz, no
/// Belastung, no Schicksalspunkt boost. Whoever needs the lines now asks the
/// same value for them.
///
/// Pure, no SwiftUI: the views own the state, this owns the arithmetic.
struct CombatSituation: Equatable {
    var mounted: Bool = false
    var schipIgnoreZustand: Bool = false
    var dualAttackActive: Bool = false
    var beengteUmgebung: Bool = false
    var twoHandedGrip: Bool = false
    /// Defences already made this round, parries and dodges **together**:
    /// "Die Erschwernisse von vorherigen Verteidigungen in einer Kampfrunde
    /// übertragen sich auf alle Verteidigungsarten" (mehrfache-verteidigung.MV4,
    /// issue #45). A dodge after a parry is the second defence.
    ///
    /// It counts the defences *before* the one being set up, so the round's
    /// first defence is unmodified.
    var defensesThisRound: Int = 0
    var schipDefenseBoost: Bool = false
    /// The formations the hero stands in, each with its agreed bonus (issue #44).
    var formations: [FormationKind: FormationBonus] = [:]
    /// Regelwerk 239, Kampf im Wasser: hüfthoch is AT/PA −2, unter Wasser −6.
    var water: WaterDepth = .none

    /// Modifier lines for a defence, whichever screen is about to roll it.
    /// `isOffHand` is the second weapon of a dual-wield loadout — it parries at
    /// the same penalty it attacks with.
    ///
    /// `opponents` is the other side as the GM has described it. A defence is
    /// made against somebody, and rules say so: a mounted hero parrying a foot
    /// fighter is in a vorteilhafte Position for that parry too. Defaulted, so
    /// a caller with nothing to say about the opponent still gets the round's
    /// own modifiers — which is all this took until the catalog had a rule that
    /// asks.
    /// `itemInHand` is the piece the parry is actually made with, where the
    /// caller knows it (the weapon list does; the root's own parry is the main
    /// weapon and says nothing). Only rules that key on the *item* read it — a
    /// Patzer-damaged shield — not the reach rules, which still read the main
    /// weapon on a parry.
    func defenseModifiers(
        hero: Hero,
        isAusweichen: Bool,
        isOffHand: Bool = false,
        opponents: OpponentRoster = OpponentRoster(),
        itemInHand: String? = nil
    ) -> [ModifierLine] {
        // The round is this value itself; only what belongs to this one defence
        // — which hand it is made with — sits beside it. `twoHandedGrip` rides
        // along on the round: `twoHandedGripPA` is scoped to the parry domain,
        // so it changes nothing for a dodge.
        var situation = Situation(hero: hero, domain: isAusweichen ? .meleeDodge : .meleeParry)
        situation.round = self
        situation.isOffHand = isOffHand
        situation.opponents = opponents
        situation.itemInHand = itemInHand

        return ModifierEngine.shared.evaluate(context: situation)
    }

    /// The fight-long choices as the catalog names them: rule id → option.
    /// The formations are the only ones until step 3 stores choices by rule
    /// id; option 0 is AT, option 1 the Verteidigungswert.
    var chosenOptions: [String: Int] {
        Dictionary(uniqueKeysWithValues: formations.map { ($0.key.ruleId, $0.value.optionIndex) })
    }

    /// Rules the hero need not own: a formation stands whether the SF is the
    /// hero's or an ally's (SA_862.F4, SA_884.P4).
    var alliedRuleIds: Set<String> { Set(formations.keys.map(\.ruleId)) }
}
