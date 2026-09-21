import Foundation
import SwiftData

/// Repairs stored derived values that were computed by an older, truncating formula.
///
/// `OptolithImportService.computeDerivedValues` runs only at import, so a formula fix
/// does not reach heroes already in the store. This pass corrects the three
/// attribute-only values in place at launch.
///
/// It deliberately does **not** touch Lebensenergie, Seelenkraft or Zähigkeit: none of
/// them is wrong, all three need the species base that existing heroes cannot supply,
/// and `lebensenergie.current` is live session state.
///
/// Geschwindigkeit is the one species-keyed value it *does* repair, because that one was
/// wrong: the import wrote a flat `8` for every hero, and GS is a species rule (Zwerge 6).
/// The species base it needs is `PersonalData.speciesId`, which ADR-0006 began persisting
/// for exactly this case. A hero without it — the normal state for anyone imported before
/// that change — is skipped rather than reset to the human value: the pass corrects what
/// it can derive and writes nothing it cannot.
enum DerivedValueRepair {

    /// Recomputes Wundschwelle, Ausweichen, Initiative and Geschwindigkeit in place.
    /// - Returns: `true` if any value changed. Idempotent — a second call returns `false`.
    @discardableResult
    static func repair(_ hero: Hero) -> Bool {
        guard let attributes = hero.attributes, let dv = hero.derivedValues else { return false }

        var changed = false

        let ws = DerivedValueFormulas.wundschwelle(
            ko: attributes.ko,
            advantages: hero.advantages,
            disadvantages: hero.disadvantages
        )
        let wsExpected = ComputedValue(value: ws.base, bonus: ws.bonus, max: ws.base + ws.bonus)
        if dv.wundschwelle.value != wsExpected.value
            || dv.wundschwelle.bonus != wsExpected.bonus
            || dv.wundschwelle.max != wsExpected.max {
            dv.wundschwelle = wsExpected
            changed = true
        }

        // NOTE on `max` convention: this file is inconsistent about what `max` means, and
        // that inconsistency is deliberate to leave alone here. Wundschwelle (above) and
        // Geschwindigkeit (below) treat `max` as `base + bonus` — the ceiling a bonus trait
        // or piece of equipment can push the value to. Ausweichen and Initiative (here)
        // treat `max` as the bare computed value, with `bonus` preserved but not folded in.
        // The pair's own convention is pre-existing and out of scope for this repair — it
        // is not "fixed" to match Wundschwelle/GS because doing so would change numbers at
        // the table for any hero with a nonzero ausweichen/initiative bonus, which nobody
        // has authorised (finding 9, whole-branch review).
        let aw = DerivedValueFormulas.ausweichen(ge: attributes.ge)
        if dv.ausweichen.value != aw || dv.ausweichen.max != aw {
            dv.ausweichen = ComputedValue(value: aw, bonus: dv.ausweichen.bonus, max: aw)
            changed = true
        }

        let ini = DerivedValueFormulas.initiative(mu: attributes.mu, ge: attributes.ge)
        if dv.initiative.value != ini || dv.initiative.max != ini {
            dv.initiative = ComputedValue(value: ini, bonus: dv.initiative.bonus, max: ini)
            changed = true
        }

        // Only where the species is known. `nil` means the hero predates
        // `PersonalData.speciesId`, and an unrecognised id means a species outside the
        // pinned Optolith source; in both cases the right answer is "leave it alone",
        // not "assume human" — assuming would write the very value this repair exists
        // to correct, and do it over a number somebody may have fixed by hand.
        //
        // `max` is `base + bonus`, matching wundschwelle, not the bare `gs` — the GS repair
        // originally set `max: gs`, silently dropping any bonus out of the ceiling (a hero
        // with base 8, bonus 2, max 10 would be rewritten to max 8). The guard below compares
        // against the corrected `max` too, so a hero with a bonus does not get rewritten on
        // every launch (whole-branch review finding 9). Latent today: nothing writes a
        // nonzero `geschwindigkeit.bonus`, so this changes no number at the table yet.
        if let gs = DerivedValueFormulas.geschwindigkeit(speciesId: hero.personalData?.speciesId) {
            let gsBonus = dv.geschwindigkeit.bonus
            let gsExpected = ResourceValue(base: gs, bonus: gsBonus, max: gs + gsBonus)
            if dv.geschwindigkeit.base != gsExpected.base || dv.geschwindigkeit.max != gsExpected.max {
                dv.geschwindigkeit = gsExpected
                changed = true
            }
        }

        return changed
    }

    /// Repairs every hero in the context. Saves only if something actually changed,
    /// so a clean launch performs no writes.
    static func repairAll(in context: ModelContext) {
        guard let heroes = try? context.fetch(FetchDescriptor<Hero>()) else { return }
        let repaired = heroes.reduce(into: 0) { count, hero in
            if repair(hero) { count += 1 }
        }
        guard repaired > 0 else { return }
        try? context.save()
        print("DerivedValueRepair: corrected \(repaired) hero(es)")
    }
}
