import Foundation

enum DefenseModifiers {
    static let all: [ModifierDefinition] = [
        multipleDefense, schipDefenseBoost, golgaritenPA,
        plaenklerAW, mountedDodgePenalty, dualAttackDefense,
        beengteUmgebungPA,
    ]

    /// Multiple defense penalty (-3 per additional defense this round).
    static let multipleDefense = ModifierDefinition(
        id: "multipleDefense",
        domains: [.meleeParry, .meleeDodge]
    ) { ctx in
        guard ctx.defenseCount > 0 else { return nil }
        return ModifierLine(value: -(ctx.defenseCount * 3), source: L("source.multipleDefense"))
    }

    /// Schicksalspunkt defense boost (+4).
    static let schipDefenseBoost = ModifierDefinition(
        id: "schipDefenseBoost",
        domains: [.meleeParry, .meleeDodge]
    ) { ctx in
        guard ctx.schipDefenseBoost else { return nil }
        return ModifierLine(value: 4, source: L("source.schipDefense"))
    }

    /// Golgariten PA bonus (parry only, +1).
    static let golgaritenPA = ModifierDefinition(
        id: "golgaritenPA",
        domains: [.meleeParry]
    ) { ctx in
        guard ctx.hero.golgaritenActive(mounted: ctx.mounted) else { return nil }
        return ModifierLine(value: 1, source: L("source.golgariten"))
    }

    /// Plänkler AW bonus (dodge only, +1).
    static let plaenklerAW = ModifierDefinition(
        id: "plaenklerAW",
        domains: [.meleeDodge]
    ) { ctx in
        guard ctx.plaenklerActive, ctx.plaenklerBonus == .aw else { return nil }
        return ModifierLine(value: 1, source: L("source.plaenkler"))
    }

    /// Mounted dodge penalty (-2 AW).
    static let mountedDodgePenalty = ModifierDefinition(
        id: "mountedDodgePenalty",
        domains: [.meleeDodge]
    ) { ctx in
        guard ctx.mounted else { return nil }
        return ModifierLine(value: -2, source: L("source.mounted"))
    }

    /// Dual-attack defense penalty.
    static let dualAttackDefense = ModifierDefinition(
        id: "dualAttackDefense",
        domains: [.meleeParry, .meleeDodge]
    ) { ctx in
        guard ctx.dualAttackActive else { return nil }
        let penalty = ctx.hero.dualAttackPenalty
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("source.dualAttack"))
    }

    /// Beengte Umgebung PA penalty (parry only, based on weapon reach).
    static let beengteUmgebungPA = ModifierDefinition(
        id: "beengteUmgebungPA",
        domains: [.meleeParry]
    ) { ctx in
        guard ctx.beengteUmgebung else { return nil }
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
