import Foundation

enum MagicModifiers {
    static let all: [ModifierDefinition] = [
        maintainedSpells, foreignTradition, omitGesture,
        omitFormula, ironBan, distraction, spellMods,
    ]

    /// Penalty per maintained spell (-1 each).
    static let maintainedSpells = ModifierDefinition(
        id: "maintainedSpells",
        domains: [.spellCasting, .liturgyCasting]
    ) { ctx in
        guard ctx.maintainedSpellCount > 0 else { return nil }
        return ModifierLine(value: -ctx.maintainedSpellCount, source: L("source.maintainedSpells"))
    }

    /// Foreign tradition penalty (-2).
    static let foreignTradition = ModifierDefinition(
        id: "foreignTradition",
        domains: [.spellCasting, .liturgyCasting]
    ) { ctx in
        guard ctx.foreignTradition else { return nil }
        return ModifierLine(value: -2, source: L("source.foreignTradition"))
    }

    /// Omit gesture penalty (-2).
    static let omitGesture = ModifierDefinition(
        id: "omitGesture",
        domains: [.spellCasting, .liturgyCasting]
    ) { ctx in
        guard ctx.omitGesture else { return nil }
        return ModifierLine(value: -2, source: L("source.omitGesture"))
    }

    /// Omit formula/incantation penalty (-2).
    static let omitFormula = ModifierDefinition(
        id: "omitFormula",
        domains: [.spellCasting, .liturgyCasting]
    ) { ctx in
        guard ctx.omitFormula else { return nil }
        return ModifierLine(value: -2, source: L("source.omitFormula"))
    }

    /// Bann des Eisens — iron carried penalty (-1 per 2 Stein).
    /// Only affects arcane magic, not liturgies.
    static let ironBan = ModifierDefinition(
        id: "ironBan",
        domains: [.spellCasting]
    ) { ctx in
        let penalty = ctx.ironSteinCarried / 2
        guard penalty > 0 else { return nil }
        return ModifierLine(value: -penalty, source: L("source.bannDesEisens"))
    }

    /// Distraction modifier (0=none, 1=minor +3, 2=ship ±0, 3=freefall -3).
    static let distraction = ModifierDefinition(
        id: "distraction",
        domains: [.spellCasting, .liturgyCasting]
    ) { ctx in
        let mods = [0, 3, 0, -3]
        guard ctx.distractionLevel > 0, ctx.distractionLevel < mods.count else { return nil }
        let val = mods[ctx.distractionLevel]
        guard val != 0 else { return nil }
        return ModifierLine(value: val, source: L("source.distraction"))
    }

    /// Spell modification sum (reduce cast time -1, increase cast time +1, etc.).
    static let spellMods = ModifierDefinition(
        id: "spellModifications",
        domains: [.spellCasting, .liturgyCasting]
    ) { ctx in
        guard !ctx.spellModifications.isEmpty else { return nil }
        var total = 0
        for mod in ctx.spellModifications {
            switch mod {
            case .reduceCastingTime, .increaseRange, .reduceCost:
                total -= 1
            case .increaseCastingTime, .force:
                total += 1
            case .omitGesture, .omitFormula:
                break // handled by dedicated modifiers above
            }
        }
        guard total != 0 else { return nil }
        return ModifierLine(value: total, source: L("source.spellModifications"))
    }
}
