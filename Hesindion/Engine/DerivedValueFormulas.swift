import Foundation

/// Single source of truth for the DSA 5 derived values that both the import path
/// (`OptolithImportService`) and the launch repair (`DerivedValueRepair`) compute.
///
/// Project convention (ADR-0006): where a calculation yields a fraction and the rules
/// do not clearly say otherwise, round **up**.
///
/// This file's docstring used to say *attribute-only*. That described its contents, not
/// its contract: what it is for is that the import path and the repair path share one
/// definition and cannot drift, and that property is needed by any value both paths
/// compute, however it is keyed. `geschwindigkeit(speciesId:)` is species-keyed and
/// belongs here for exactly that reason — it gained a second caller the moment the
/// repair learned about it, which is the condition the file exists to serve.
///
/// The species base LP/SK/ZK tables deliberately stay in `OptolithImportService`: each
/// has exactly one caller, because `DerivedValueRepair` does not touch those three
/// (ADR-0006 — none of them is wrong and `lebensenergie.current` is live session state).
/// If the repair ever grows to cover them, they should follow GS into this file.
enum DerivedValueFormulas {

    /// GS (Geschwindigkeit) by species, from the pinned Optolith source's `mov` field
    /// (`Data/univ/Races.yaml`): Menschen 8, Elfen 8, Halbelfen 8, **Zwerge 6**.
    ///
    /// GS is a species rule, not an attribute-derived one, and the app treated it as a
    /// constant 8 for every hero — so every dwarf was two Schritt too fast.
    ///
    /// - Returns: `nil` for a species we have no value for, which is **not** the same as
    ///   "human". A `nil` `speciesId` is the normal case for heroes imported before
    ///   ADR-0006 persisted the field, and an unrecognised id is a species outside the
    ///   pinned source. Returning an optional forces each caller to decide: the import
    ///   falls back to the human value because a hero must have a GS to display and that
    ///   fallback is the documented status quo (ADR-0006's last-but-one consequence);
    ///   the repair declines to write a number it cannot derive.
    static func geschwindigkeit(speciesId: String?) -> Int? {
        guard let speciesId else { return nil }
        return speciesBaseGS[speciesId]
    }

    /// The whole of what the pinned Optolith source knows: `Data/univ/Races.yaml` carries
    /// four races, and `RaceVariants.yaml` overrides `mov` for none of them.
    private static let speciesBaseGS: [String: Int] = [
        "R_1": 8,  // Menschen
        "R_2": 8,  // Elfen
        "R_3": 8,  // Halbelfen
        "R_4": 6,  // Zwerge
    ]

    /// The value a hero gets when their species is unknown. Named rather than spelled `8`
    /// at the call site, so the fallback is greppable and its one justification lives here.
    static let geschwindigkeitFallback = 8

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
