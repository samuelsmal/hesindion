import Foundation

enum MeleeModifiers {
    static let all: [ModifierDefinition] = [
        plaenklerAT,
        maneuverAT, dualAttackPenalty,
        offHandPenalty,
    ]

    /// Plänkler formation AT bonus (+1).
    static let plaenklerAT = ModifierDefinition(
        id: "plaenklerAT",
        domains: [.meleeAttack],
        rules: [CombatAbility.plaenklerFormation.rawValue]
    ) { ctx in
        guard ctx.round.plaenklerActive, ctx.round.plaenklerBonus == .at else { return nil }
        return ModifierLine(value: 1, source: L("source.plaenkler"))
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
}
