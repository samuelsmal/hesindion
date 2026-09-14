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

    /// Modifier lines for a defence, whichever screen is about to roll it.
    /// `isOffHand` is the second weapon of a dual-wield loadout — it parries at
    /// the same penalty it attacks with.
    func defenseModifiers(hero: Hero, isAusweichen: Bool, isOffHand: Bool = false) -> [ModifierLine] {
        // The round is this value itself; only what belongs to this one defence
        // — which hand it is made with — sits beside it. `twoHandedGrip` rides
        // along on the round: `twoHandedGripPA` is scoped to the parry domain,
        // so it changes nothing for a dodge.
        var situation = Situation(hero: hero, domain: isAusweichen ? .meleeDodge : .meleeParry)
        situation.round = self
        situation.isOffHand = isOffHand

        return ModifierEngine.shared.evaluate(context: situation)
    }

    /// Defences of this kind already made this round.
    func defensesSoFar(isAusweichen: Bool) -> Int {
        isAusweichen ? dodgesThisRound : parriesThisRound
    }

    /// What the *next* defence of this kind will cost, as a signed number, for
    /// the buttons that offer it. `0` while the first is still to come.
    func pendingMultipleDefensePenalty(isAusweichen: Bool) -> Int {
        -(defensesSoFar(isAusweichen: isAusweichen) * 3)
    }

    /// The fight-long choices as the catalog names them: rule id → option.
    /// Plänkler-Formation (SA_884) is the only one until step 3 stores choices
    /// by rule id; its option 0 is AT, option 1 the Verteidigungswert.
    var chosenOptions: [String: Int] {
        guard plaenklerActive else { return [:] }
        return [CombatAbility.plaenklerFormation.rawValue: plaenklerBonus == .at ? 0 : 1]
    }
}
