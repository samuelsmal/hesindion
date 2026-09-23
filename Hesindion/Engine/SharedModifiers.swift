import Foundation

enum SharedModifiers {
    static let all: [ModifierDefinition] = [encumbrance]

    /// The mounted Belastung relief eases Kampfproben only (Reiterkampf chapter); a Zauber-,
    /// Liturgie- or Talentprobe keeps the hero's full Belastung while mounted.
    static let mountedReliefDomains: Set<RuleDomain> = [
        .meleeAttack, .meleeParry, .meleeDodge, .rangedAttack,
    ]

    /// Belastung (encumbrance). Tagged `isZustand` so it counts toward the −5 Zustand cap.
    /// Schmerz now flows through `StateModifiers` via the catalog `schmerz` entry.
    /// Deliberately does NOT early-return on `ctx.round.schipIgnoreZustand`: a "Zustand ignorieren"
    /// Schip cannot will away gear-derived Belastung. It still counts toward the cap, but is
    /// never suppressed by the Schip — preserving prior behavior (only the old `pain` checked the flag).
    static let encumbrance = ModifierDefinition(
        id: "encumbrance",
        domains: [.meleeAttack, .meleeParry, .meleeDodge, .rangedAttack, .spellCasting, .liturgyCasting],
        // SA_41 too: the line reads `Hero.effectiveBE`, which is where
        // Belastungsgewöhnung has already taken its points off.
        rules: ["COND_1", CombatAbility.belastungsgewoehnung.rawValue]
    ) { ctx in
        let relief = (ctx.round.mounted && mountedReliefDomains.contains(ctx.domain)) ? 1 : 0
        let be = max(0, ctx.hero.effectiveBE - relief)
        guard be > 0 else { return nil }
        return ModifierLine(value: -be, source: L("source.belastung"), isZustand: true)
    }
}
