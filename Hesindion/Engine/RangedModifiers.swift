import Foundation

enum RangedModifiers {
    static let all: [ModifierDefinition] = [
        distanz, groesse, bewegungZiel, bewegungSchuetze,
        sicht, kampfgetuemmel, zielen, vomPferd,
    ]

    /// Distance modifier (+2 nah, 0 mittel, -2 weit).
    static let distanz = ModifierDefinition(
        id: "distanz",
        domains: [.rangedAttack]
    ) { ctx in
        let mods = [2, 0, -2]
        let val = mods[ctx.distanz]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.distanz"))
    }

    /// Target size modifier (-8 winzig to +8 riesig).
    static let groesse = ModifierDefinition(
        id: "groesse",
        domains: [.rangedAttack]
    ) { ctx in
        let mods = [-8, -4, 0, 4, 8]
        let val = mods[ctx.groesse]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.groesse"))
    }

    /// Target movement modifier.
    static let bewegungZiel = ModifierDefinition(
        id: "bewegungZiel",
        domains: [.rangedAttack]
    ) { ctx in
        let mods = [2, 0, -2, -4]
        let val = mods[ctx.bewegungZiel]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.bewegungZiel"))
    }

    /// Shooter movement modifier.
    static let bewegungSchuetze = ModifierDefinition(
        id: "bewegungSchuetze",
        domains: [.rangedAttack]
    ) { ctx in
        let mods = [0, -2, -4]
        let val = mods[ctx.bewegungSchuetze]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.bewegungSchuetze"))
    }

    /// Visibility modifier.
    static let sicht = ModifierDefinition(
        id: "sicht",
        domains: [.rangedAttack]
    ) { ctx in
        let mods = [0, -2, -4, -6]
        let val = mods[ctx.sicht]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.sicht"))
    }

    /// Melee combat penalty (-2).
    static let kampfgetuemmel = ModifierDefinition(
        id: "kampfgetuemmel",
        domains: [.rangedAttack]
    ) { ctx in
        guard ctx.kampfgetuemmel else { return nil }
        return ModifierLine(value: -2, source: L("source.kampfgetuemmel"))
    }

    /// Aiming bonus (0/+2/+4).
    static let zielen = ModifierDefinition(
        id: "zielen",
        domains: [.rangedAttack]
    ) { ctx in
        let mods = [0, 2, 4]
        let val = mods[ctx.zielen]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.zielen"))
    }

    /// Mounted shooting penalty (0/-4/-8).
    static let vomPferd = ModifierDefinition(
        id: "vomPferd",
        domains: [.rangedAttack]
    ) { ctx in
        guard ctx.mounted else { return nil }
        let mods = [0, -4, -8]
        let val = mods[ctx.vomPferd]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.vomPferd"))
    }
}
