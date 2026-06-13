import Foundation

enum SharedModifiers {
    static let all: [ModifierDefinition] = [encumbrance]

    /// Belastung (encumbrance). Tagged `isZustand` so it counts toward the −5 Zustand cap.
    /// Schmerz now flows through `StateModifiers` via the catalog `schmerz` entry.
    static let encumbrance = ModifierDefinition(
        id: "encumbrance",
        domains: [.meleeAttack, .meleeParry, .meleeDodge, .rangedAttack, .spellCasting, .liturgyCasting]
    ) { ctx in
        let be = ctx.mounted ? max(0, ctx.hero.effectiveBE - 1) : ctx.hero.effectiveBE
        guard be > 0 else { return nil }
        return ModifierLine(value: -be, source: L("source.belastung"), isZustand: true)
    }
}
