import Foundation

/// Single source of truth for the attribute-only DSA 5 derived values.
///
/// Project convention (ADR-0006): where a calculation yields a fraction and the rules
/// do not clearly say otherwise, round **up**. Both the import path
/// (`OptolithImportService`) and the launch repair (`DerivedValueRepair`) call these,
/// so the two can never drift apart.
enum DerivedValueFormulas {

    /// Wundschwelle = ceil(KO / 2), modified by Eisern (ADV_54, +1) and Gläsern (DISADV_56, −1).
    ///
    /// Both traits are `max: 1` and untiered in the ruleset, so they apply once regardless
    /// of how often they appear on the hero.
    static func wundschwelle(
        ko: Int,
        advantages: [HeroTrait],
        disadvantages: [HeroTrait]
    ) -> (base: Int, bonus: Int) {
        let base = Int(ceil(Double(ko) / 2.0))
        var bonus = 0
        if advantages.contains(where: { $0.ruleId == "ADV_54" }) { bonus += 1 }
        if disadvantages.contains(where: { $0.ruleId == "DISADV_56" }) { bonus -= 1 }
        return (base, bonus)
    }

    /// Ausweichen = ceil(GE / 2).
    static func ausweichen(ge: Int) -> Int {
        Int(ceil(Double(ge) / 2.0))
    }

    /// Initiative = ceil((MU + GE) / 2).
    static func initiative(mu: Int, ge: Int) -> Int {
        Int(ceil(Double(mu + ge) / 2.0))
    }
}
