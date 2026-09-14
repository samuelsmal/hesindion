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
        var context = ModifierContext(
            hero: hero,
            domain: isAusweichen ? .meleeDodge : .meleeParry
        )
        context.mounted = mounted
        context.schipIgnoreZustand = schipIgnoreZustand
        context.dualAttackActive = dualAttackActive
        context.beengteUmgebung = beengteUmgebung
        context.defenseCount = defensesSoFar(isAusweichen: isAusweichen)
        context.schipDefenseBoost = schipDefenseBoost
        context.plaenklerActive = plaenklerActive
        context.plaenklerBonus = plaenklerBonus
        context.isOffHand = isOffHand
        // Only a parry can be made with a two-handed grip; `twoHandedGripPA` is
        // scoped to that domain, so passing it for a dodge changes nothing.
        context.twoHandedGrip = twoHandedGrip

        return ModifierEngine.shared.evaluate(context: context)
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
}
