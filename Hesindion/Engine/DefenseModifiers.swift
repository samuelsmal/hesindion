import Foundation

enum DefenseModifiers {
    static let all: [ModifierDefinition] = [
        schipDefenseBoost,
        mountedDodgePenalty, dualAttackDefense,
        offHandParry, twoHandedGripPA,
    ]

    /// Schicksalspunkt defense boost (+4).
    static let schipDefenseBoost = ModifierDefinition(
        id: "schipDefenseBoost",
        domains: [.meleeParry, .meleeDodge],
        rules: []
    ) { ctx in
        guard ctx.round.schipDefenseBoost else { return nil }
        return ModifierLine(value: 4, source: L("source.schipDefense"))
    }

    /// Mounted dodge penalty (-2 AW).
    static let mountedDodgePenalty = ModifierDefinition(
        id: "mountedDodgePenalty",
        domains: [.meleeDodge],
        rules: []
    ) { ctx in
        guard ctx.round.mounted else { return nil }
        return ModifierLine(value: -2, source: L("source.mounted"))
    }

    /// Dual-attack defense penalty.
    static let dualAttackDefense = ModifierDefinition(
        id: "dualAttackDefense",
        domains: [.meleeParry, .meleeDodge],
        rules: [CombatAbility.beidhaendigerKampf.rawValue]
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
        domains: [.meleeParry],
        rules: ["ADV_5"]
    ) { ctx in
        guard ctx.isOffHand, ctx.hero.offHandPenalty != 0 else { return nil }
        return ModifierLine(value: ctx.hero.offHandPenalty, source: L("source.offHand"))
    }

    /// Parrying with a weapon held in both hands: -1 PA, the other half of the
    /// "+1 TP, -1 PA" the grip button promises.
    static let twoHandedGripPA = ModifierDefinition(
        id: "twoHandedGripPA",
        domains: [.meleeParry],
        rules: []
    ) { ctx in
        guard ctx.round.twoHandedGrip else { return nil }
        return ModifierLine(value: -1, source: L("source.twoHandedGrip"))
    }
}
