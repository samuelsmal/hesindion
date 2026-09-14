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
        domains: [.meleeAttack],
        rules: ["GRW_vorteilhaftePosition"]
    ) { ctx in
        guard ctx.hero.golgaritenActive(mounted: ctx.round.mounted) else { return nil }
        return ModifierLine(value: 2, source: L("source.vorteilhaft"))
    }

    /// Golgariten style bonus (+2 AT).
    static let golgariten = ModifierDefinition(
        id: "golgariten",
        domains: [.meleeAttack],
        rules: [CombatAbility.golgaritenStil.rawValue]
    ) { ctx in
        guard ctx.hero.golgaritenActive(mounted: ctx.round.mounted) else { return nil }
        return ModifierLine(value: 2, source: L("source.golgariten"))
    }

    /// Plänkler formation AT bonus (+1).
    static let plaenklerAT = ModifierDefinition(
        id: "plaenklerAT",
        domains: [.meleeAttack],
        rules: [CombatAbility.plaenklerFormation.rawValue]
    ) { ctx in
        guard ctx.round.plaenklerActive, ctx.round.plaenklerBonus == .at else { return nil }
        return ModifierLine(value: 1, source: L("source.plaenkler"))
    }

    /// The reach of the thing being swung: the announced loadout piece where the
    /// screen says which, the main weapon otherwise.
    static func attackerReach(_ ctx: Situation) -> WeaponReach {
        if let name = ctx.loadoutName { return ctx.hero.reach(ofLoadoutNamed: name) }
        return WeaponReach(rawValue: ctx.hero.selectedWeapon?.reach ?? "Mittel") ?? .mittel
    }

    /// Weapon reach mismatch penalty.
    static let weaponReach = ModifierDefinition(
        id: "weaponReach",
        domains: [.meleeAttack],
        rules: ["GRW_reichweite"]
    ) { ctx in
        let penalty = attackerReach(ctx).atPenaltyAgainst(ctx.opponent.reach)
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("source.reach"))
    }

    /// Combat maneuver AT modifier.
    static let maneuverAT = ModifierDefinition(
        id: "maneuverAT",
        domains: [.meleeAttack],
        rules: [CombatAbility.finte.rawValue, CombatAbility.wuchtschlag.rawValue,
                CombatAbility.vorstoss.rawValue]
    ) { ctx in
        guard ctx.maneuver.atModifier != 0 else { return nil }
        return ModifierLine(value: ctx.maneuver.atModifier, source: ctx.maneuver.sourceLabel)
    }

    /// Dual-attack penalty (reduced by Beidhändiger Kampf level).
    static let dualAttackPenalty = ModifierDefinition(
        id: "dualAttackPenaltyAT",
        domains: [.meleeAttack],
        rules: [CombatAbility.beidhaendigerKampf.rawValue]
    ) { ctx in
        guard ctx.round.dualAttackActive else { return nil }
        let penalty = ctx.hero.dualAttackPenalty
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("source.dualAttack"))
    }

    /// Off-hand penalty (-4 unless hero has Beidhändig advantage).
    static let offHandPenalty = ModifierDefinition(
        id: "offHandPenalty",
        domains: [.meleeAttack],
        rules: ["ADV_5"]
    ) { ctx in
        guard ctx.isOffHand, ctx.hero.offHandPenalty != 0 else { return nil }
        return ModifierLine(value: ctx.hero.offHandPenalty, source: L("source.offHand"))
    }

    /// Beengte Umgebung AT penalty (based on weapon reach).
    static let beengteUmgebungAT = ModifierDefinition(
        id: "beengteUmgebungAT",
        domains: [.meleeAttack],
        rules: ["GRW_beengteUmgebung", "STATE_6"]
    ) { ctx in
        guard ctx.round.beengteUmgebung else { return nil }
        let penalty = attackerReach(ctx).beengteUmgebungPenalty
        guard penalty != 0 else { return nil }
        return ModifierLine(value: penalty, source: L("beengteUmgebung"))
    }
}
