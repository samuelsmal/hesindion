import Foundation

enum SharedModifiers {
    static let all: [ModifierDefinition] = [encumbrance]

    /// The domains the mounted Belastung relief reaches. `CHAP_Reiterkampf`'s clause eases
    /// *Kampfproben*, and Kampf and Zaubern are neither the same nor related — so a
    /// Zauber-, Liturgie- or Talentprobe keeps the hero's full Belastung while mounted.
    /// This is the whole of the `scope: combat` the authored chapter rule carries; the
    /// *unmounted* penalty is unaffected and still applies in every domain below.
    ///
    /// This is one of two Swift readings of that authored `scope: combat` token.
    /// `RuleEffectModifiers.domainsForScope("combat")` (RuleEffectModifiers.swift:53) reads
    /// the same token differently. `RuleEffectModifiers` has no callers today, so this
    /// definition is the one the authored row is actually implemented by — see ADR-0008's
    /// Consequences (whole-branch review finding 4) before wiring the other one up.
    static let mountedReliefDomains: Set<CheckDomain> = [
        .meleeAttack, .meleeParry, .meleeDodge, .rangedAttack,
    ]

    /// Belastung (encumbrance). Tagged `isZustand` so it counts toward the −5 Zustand cap.
    /// Schmerz now flows through `StateModifiers` via the catalog `schmerz` entry.
    /// Deliberately does NOT early-return on `ctx.schipIgnoreZustand`: a "Zustand ignorieren"
    /// Schip cannot will away gear-derived Belastung. It still counts toward the cap, but is
    /// never suppressed by the Schip — preserving prior behavior (only the old `pain` checked the flag).
    static let encumbrance = ModifierDefinition(
        id: "encumbrance",
        domains: [.meleeAttack, .meleeParry, .meleeDodge, .rangedAttack, .spellCasting, .liturgyCasting]
    ) { ctx in
        let relief = (ctx.mounted && mountedReliefDomains.contains(ctx.domain)) ? 1 : 0
        let be = max(0, ctx.hero.effectiveBE - relief)
        guard be > 0 else { return nil }
        return ModifierLine(value: -be, source: L("source.belastung"), isZustand: true)
    }
}
