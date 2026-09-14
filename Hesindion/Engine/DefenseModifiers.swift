import Foundation

enum DefenseModifiers {
    static let all: [ModifierDefinition] = [
        multipleDefense, schipDefenseBoost, golgaritenPA,
        plaenklerVW, mountedDodgePenalty, dualAttackDefense,
        beengteUmgebungPA, offHandParry, twoHandedGripPA,
    ]

    /// Multiple defense penalty (-3 per defense already made this round).
    ///
    /// `defencesThisRound` counts the defences *before* this one, so the first
    /// defence of a round is unmodified and the second is at -3. It used to be
    /// incremented as the button was tapped and then read back for the very
    /// defence that incremented it, which put every first parry of a round at
    /// -3.
    static let multipleDefense = ModifierDefinition(
        id: "multipleDefense",
        domains: [.meleeParry, .meleeDodge]
    ) { ctx in
        guard ctx.defencesThisRound > 0 else { return nil }
        return ModifierLine(value: -(ctx.defencesThisRound * 3), source: L("source.multipleDefense"))
    }

    /// Schicksalspunkt defense boost (+4).
    static let schipDefenseBoost = ModifierDefinition(
        id: "schipDefenseBoost",
        domains: [.meleeParry, .meleeDodge]
    ) { ctx in
        guard ctx.round.schipDefenseBoost else { return nil }
        return ModifierLine(value: 4, source: L("source.schipDefense"))
    }

    /// Golgariten PA bonus (parry only, +1).
    static let golgaritenPA = ModifierDefinition(
        id: "golgaritenPA",
        domains: [.meleeParry]
    ) { ctx in
        guard ctx.hero.golgaritenActive(mounted: ctx.round.mounted) else { return nil }
        return ModifierLine(value: 1, source: L("source.golgariten"))
    }

    /// Plänkler-Formation (SA_884): the formation agrees on "+1 AT **oder** +1 VW".
    ///
    /// VW is the Verteidigungswert — parry and dodge both. The bonus used to be
    /// scoped to `.meleeDodge` alone, so a hero who took the defensive half of an
    /// ability they had paid for got nothing for it while parrying.
    static let plaenklerVW = ModifierDefinition(
        id: "plaenklerVW",
        domains: [.meleeParry, .meleeDodge]
    ) { ctx in
        guard ctx.round.plaenklerActive, ctx.round.plaenklerBonus == .aw else { return nil }
        return ModifierLine(value: 1, source: L("source.plaenkler"))
    }

    /// Mounted dodge penalty (-2 AW).
    static let mountedDodgePenalty = ModifierDefinition(
        id: "mountedDodgePenalty",
        domains: [.meleeDodge]
    ) { ctx in
        guard ctx.round.mounted else { return nil }
        return ModifierLine(value: -2, source: L("source.mounted"))
    }

    /// Dual-attack defense penalty.
    static let dualAttackDefense = ModifierDefinition(
        id: "dualAttackDefense",
        domains: [.meleeParry, .meleeDodge]
    ) { ctx in
        guard ctx.round.dualAttackActive else { return nil }
        let penalty = ctx.hero.dualAttackPenalty
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("source.dualAttack"))
    }

    /// Off-hand weapon parry penalty (-4 unless the hero has Beidhändig), the
    /// defensive half of `MeleeModifiers.offHandPenalty`. The weapon list used
    /// to add this to the row's own number, which is why it never reached the
    /// calculation the player can read.
    static let offHandParry = ModifierDefinition(
        id: "offHandParry",
        domains: [.meleeParry]
    ) { ctx in
        guard ctx.isOffHand, ctx.hero.offHandPenalty != 0 else { return nil }
        return ModifierLine(value: ctx.hero.offHandPenalty, source: L("source.offHand"))
    }

    /// Parrying with a weapon held in both hands: -1 PA, the other half of the
    /// "+1 TP, -1 PA" the grip button promises.
    static let twoHandedGripPA = ModifierDefinition(
        id: "twoHandedGripPA",
        domains: [.meleeParry]
    ) { ctx in
        guard ctx.round.twoHandedGrip else { return nil }
        return ModifierLine(value: -1, source: L("source.twoHandedGrip"))
    }

    /// Beengte Umgebung PA penalty (parry only, based on weapon reach).
    static let beengteUmgebungPA = ModifierDefinition(
        id: "beengteUmgebungPA",
        domains: [.meleeParry]
    ) { ctx in
        guard ctx.round.beengteUmgebung else { return nil }
        let heroReach: WeaponReach
        if let w = ctx.hero.selectedWeapon {
            heroReach = WeaponReach(rawValue: w.reach) ?? .mittel
        } else {
            heroReach = .kurz
        }
        let penalty = heroReach.beengteUmgebungPenalty
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("beengteUmgebung"))
    }
}
