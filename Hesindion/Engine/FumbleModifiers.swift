import Foundation

/// The Patzertabellen's *temporary* modifiers, as modifier lines.
///
/// The four fumble tables are the app's own data (`FumbleTable`) and have no
/// catalog id — the Kodex prints them as tables, not as rules with ids — so
/// `rules: []` here is the honest answer, the same one `RangedModifiers` gives
/// for the eight ranged categories. Both definitions read flags the hero holds,
/// the way `StateModifiers` reads their Zustände, so every screen that asks the
/// engine for lines gets them without a second reader of the same fact.
enum FumbleModifiers {
    static let all: [ModifierDefinition] = [stolpern, beschaedigt]

    /// Every roll the hero makes with a weapon in hand. Stolpern says "nächste
    /// Handlung", not "nächster Angriff": a parry and a dodge are handlungen too.
    static let combatDomains: Set<CheckDomain> = [
        .meleeAttack, .meleeParry, .meleeDodge, .rangedAttack,
    ]

    /// Stolpern (8): the next combat roll of any kind is 2 harder.
    ///
    /// Not a Zustand — it is a stumble, not a condition — so it is outside the
    /// −5 Zustand cap, which is where a one-roll penalty belongs.
    static let stolpern = ModifierDefinition(
        id: "patzerStolpern",
        domains: combatDomains,
        rules: []
    ) { ctx in
        guard ctx.hero.activeCombatStumble else { return nil }
        return ModifierLine(value: -2, source: L("fumble.modifier.stumble"))
    }

    /// Beschädigte Waffe / beschädigter Schild (4): −2 on AT and PA with the
    /// damaged thing, −4 on FK — but only for the piece actually in the hand.
    /// A dented shield does not make the sword harder to swing.
    static let beschaedigt = ModifierDefinition(
        id: "patzerBeschaedigt",
        domains: [.meleeAttack, .meleeParry, .rangedAttack],
        rules: []
    ) { ctx in
        guard let name = ctx.itemInHandName, ctx.hero.isItemDamaged(name) else { return nil }
        let value = ctx.domain == .rangedAttack ? -4 : -2
        return ModifierLine(value: value, source: String(format: L("fumble.modifier.damaged"), name))
    }
}
