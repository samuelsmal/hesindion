import Foundation

enum MeleeModifiers {
    static let all: [ModifierDefinition] = [
        vorteilhaftePosition, golgariten, plaenklerAT,
        weaponReach, maneuverAT, dualAttackPenalty,
        offHandPenalty, beengteUmgebungAT,
    ]

    /// Reiterkampf chapter rule (`CHAP_Reiterkampf`, clause 2): a mounted hero counts as being
    /// in a vorteilhafte Position against a fighter on foot, +2 AT. It binds *every* rider —
    /// no Sonderfertigkeit, no particular weapon and no particular shield. The opponent's
    /// stance is a GM flag, because the opponent is not modelled (ADR-0005).
    static let vorteilhaftePosition = ModifierDefinition(
        id: "vorteilhaftePosition",
        domains: [.meleeAttack]
    ) { ctx in
        guard emitsVorteilhaftePosition(mounted: ctx.mounted, opponentOnFoot: ctx.opponentOnFoot) else { return nil }
        return ModifierLine(value: 2, source: L("source.vorteilhaft"))
    }

    /// Whether `vorteilhaftePosition` will emit its line for this situation — i.e. whether the
    /// engine already supplies the +2. A screen that also offers a *manual* vorteilhafte
    /// Position toggle must ask this first and suppress its own line, or the hero gets the
    /// ease twice. Lives next to the definition, and is used by it, so the two cannot drift.
    static func emitsVorteilhaftePosition(mounted: Bool, opponentOnFoot: Bool) -> Bool {
        mounted && opponentOnFoot
    }

    /// Golgariten-Stil (`SA_661`, clause 1): *raises* the ease that the advantageous position
    /// already grants by a further +2 AT, for a total of +4 — it is not an independent bonus,
    /// so it needs the same mounted-against-foot situation that `vorteilhaftePosition` needs,
    /// on top of the style's own loadout requirement.
    static let golgariten = ModifierDefinition(
        id: "golgariten",
        domains: [.meleeAttack]
    ) { ctx in
        guard ctx.hero.golgaritenActive(mounted: ctx.mounted), ctx.opponentOnFoot else { return nil }
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
