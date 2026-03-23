import Foundation

enum SharedModifiers {
    static let all: [ModifierDefinition] = [encumbrance, pain]

    static let encumbrance = ModifierDefinition(
        id: "encumbrance",
        domains: [.meleeAttack, .meleeParry, .meleeDodge, .rangedAttack, .spellCasting, .liturgyCasting]
    ) { ctx in
        let be = ctx.mounted ? max(0, ctx.hero.effectiveBE - 1) : ctx.hero.effectiveBE
        guard be > 0 else { return nil }
        return ModifierLine(value: -be, source: L("source.belastung"))
    }

    static let pain = ModifierDefinition(
        id: "pain",
        domains: Set(CheckDomain.allCases)
    ) { ctx in
        guard !ctx.schipIgnoreZustand, ctx.hero.schmerzPenalty != 0 else { return nil }
        let level = ctx.hero.effectiveSchmerzLevel
        let roman = level > 0 ? " " + String(repeating: "I", count: min(level, 4)) : ""
        return ModifierLine(value: ctx.hero.schmerzPenalty, source: L("source.schmerz") + roman)
    }
}
