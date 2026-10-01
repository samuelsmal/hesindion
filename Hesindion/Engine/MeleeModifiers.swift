import Foundation

enum MeleeModifiers {
    static let all: [ModifierDefinition] = [
        maneuverAT, dualAttackPenalty,
        offHandPenalty,
    ]

    /// Finte and Vorstoß. Wuchtschlag's AT half is the catalog's (SA_67).
    static let maneuverAT = ModifierDefinition(
        id: "maneuverAT",
        domains: [.meleeAttack],
        rules: [CombatAbility.finte.rawValue, CombatAbility.vorstoss.rawValue]
    ) { ctx in
        if case .wuchtschlag = ctx.maneuver { return nil }
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
