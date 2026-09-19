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
    /// Parries already made this round, and dodges already made this round —
    /// **counted apart**. Mehrfache Verteidigung is per defence type: having
    /// parried twice does not make the round's first dodge any harder.
    ///
    /// Each counts the defences *before* the one being set up, so the first of
    /// either kind is unmodified.
    var parriesThisRound: Int = 0
    var dodgesThisRound: Int = 0
    var schipDefenseBoost: Bool = false
    var plaenklerActive: Bool = false
    var plaenklerBonus: PlaenklerBonus = .at
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

    /// Defences of this kind already made this round.
    func defensesSoFar(isAusweichen: Bool) -> Int {
        isAusweichen ? dodgesThisRound : parriesThisRound
    }

    /// The fight-long choices as the catalog names them: rule id → option.
    /// Plänkler-Formation (SA_884) is the only one until step 3 stores choices
    /// by rule id; its option 0 is AT, option 1 the Verteidigungswert.
    var chosenOptions: [String: Int] {
        guard plaenklerActive else { return [:] }
        return [CombatAbility.plaenklerFormation.rawValue: plaenklerBonus == .at ? 0 : 1]
    }
}
