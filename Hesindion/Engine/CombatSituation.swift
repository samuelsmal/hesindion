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
    /// Defences already **rolled** this round. The penalty is for the ones
    /// before this one, so the count must not include the defence being set up.
    var defensesThisRound: Int = 0
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
        context.defenseCount = defensesThisRound
        context.schipDefenseBoost = schipDefenseBoost
        context.plaenklerActive = plaenklerActive
        context.plaenklerBonus = plaenklerBonus
        context.isOffHand = isOffHand
        // Only a parry can be made with a two-handed grip; `twoHandedGripPA` is
        // scoped to that domain, so passing it for a dodge changes nothing.
        context.twoHandedGrip = twoHandedGrip

        return ModifierEngine.shared.evaluate(context: context)
    }

    /// What the *next* defence this round will cost, as a signed number, for the
    /// buttons that offer it. `0` while the first defence is still to come.
    var pendingMultipleDefensePenalty: Int {
        -(defensesThisRound * 3)
    }
}
