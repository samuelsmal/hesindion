import Foundation

enum MeleeModifiers {
    static let all: [ModifierDefinition] = [
        vorteilhaftePosition, golgariten, plaenklerAT,
        weaponReach, maneuverAT, dualAttackPenalty,
        offHandPenalty, beengteUmgebungAT,
    ]

    /// Golgariten-forced vorteilhafte Position (+2 AT when mounted with correct loadout).
    static let vorteilhaftePosition = ModifierDefinition(
        id: "vorteilhaftePosition",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.hero.golgaritenActive(mounted: ctx.mounted) else { return nil }
        return ModifierLine(value: 2, source: L("source.vorteilhaft"))
    }

    /// Golgariten style bonus (+2 AT).
    static let golgariten = ModifierDefinition(
        id: "golgariten",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.hero.golgaritenActive(mounted: ctx.mounted) else { return nil }
        return ModifierLine(value: 2, source: L("source.golgariten"))
    }

    /// Plänkler formation AT bonus (+1).
    static let plaenklerAT = ModifierDefinition(
        id: "plaenklerAT",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.plaenklerActive, ctx.plaenklerBonus == .at else { return nil }
        return ModifierLine(value: 1, source: L("source.plaenkler"))
    }

    /// Weapon reach mismatch penalty.
    static let weaponReach = ModifierDefinition(
        id: "weaponReach",
        domains: [.meleeAttack]
    ) { ctx in
        guard let opponentReach = ctx.opponentReach else { return nil }
        let heroReach = WeaponReach(rawValue: ctx.hero.selectedWeapon?.reach ?? "Mittel") ?? .mittel
        let penalty = heroReach.atPenaltyAgainst(opponentReach)
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("source.reach"))
    }

    /// Combat maneuver AT modifier.
    static let maneuverAT = ModifierDefinition(
        id: "maneuverAT",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.maneuver.atModifier != 0 else { return nil }
        return ModifierLine(value: ctx.maneuver.atModifier, source: ctx.maneuver.sourceLabel)
    }

    /// Dual-attack penalty (reduced by Beidhändiger Kampf level).
    static let dualAttackPenalty = ModifierDefinition(
        id: "dualAttackPenaltyAT",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.dualAttackActive else { return nil }
        let penalty = ctx.hero.dualAttackPenalty
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("source.dualAttack"))
    }

    /// Off-hand penalty (-4 unless hero has Beidhändig advantage).
    static let offHandPenalty = ModifierDefinition(
        id: "offHandPenalty",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.isOffHand, ctx.hero.offHandPenalty != 0 else { return nil }
        return ModifierLine(value: ctx.hero.offHandPenalty, source: L("source.offHand"))
    }

    /// Beengte Umgebung AT penalty (based on weapon reach).
    static let beengteUmgebungAT = ModifierDefinition(
        id: "beengteUmgebungAT",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.beengteUmgebung else { return nil }
        let heroReach = WeaponReach(rawValue: ctx.hero.selectedWeapon?.reach ?? "Mittel") ?? .mittel
        let penalty = heroReach.beengteUmgebungPenalty
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("beengteUmgebung"))
    }
}
