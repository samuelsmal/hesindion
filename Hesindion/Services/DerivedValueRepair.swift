import Foundation
import SwiftData

/// Repairs stored derived values that were computed by an older, truncating formula.
///
/// `OptolithImportService.computeDerivedValues` runs only at import, so a formula fix
/// does not reach heroes already in the store. This pass corrects Geschwindigkeit in
/// place at launch.
///
/// It deliberately does **not** touch Lebensenergie, Seelenkraft or Zähigkeit: none of
/// them is wrong, all three need the species base that existing heroes cannot supply,
/// and `lebensenergie.current` is live session state.
///
/// Wundschwelle, Ausweichen and Initiative used to be repaired here too; the sheet
/// cut-over (design §4) moved them to `SheetValues`/the rules engine and deleted the
/// stored properties (Task 9), so there is nothing left for this pass to correct there.
///
/// Geschwindigkeit is the one species-keyed value it *does* repair, because that one was
/// wrong: the import wrote a flat `8` for every hero, and GS is a species rule (Zwerge 6).
/// The species base it needs is `PersonalData.speciesId`, which ADR-0006 began persisting
/// for exactly this case. A hero without it — the normal state for anyone imported before
/// that change — is skipped rather than reset to the human value: the pass corrects what
/// it can derive and writes nothing it cannot.
enum DerivedValueRepair {

    /// Recomputes Geschwindigkeit in place.
    /// - Returns: `true` if any value changed. Idempotent — a second call returns `false`.
    @discardableResult
    static func repair(_ hero: Hero) -> Bool {
        guard hero.attributes != nil, let dv = hero.derivedValues else { return false }

        var changed = false

        // Only where the species is known. `nil` means the hero predates
        // `PersonalData.speciesId`, and an unrecognised id means a species outside the
        // pinned Optolith source; in both cases the right answer is "leave it alone",
        // not "assume human" — assuming would write the very value this repair exists
        // to correct, and do it over a number somebody may have fixed by hand.
        // `max` is base + bonus, so a bonus is not dropped from the ceiling.
        if let gs = DerivedValueFormulas.geschwindigkeit(speciesId: hero.personalData?.speciesId) {
            let bonus = dv.geschwindigkeit.bonus
            if dv.geschwindigkeit.base != gs || dv.geschwindigkeit.max != gs + bonus {
                dv.geschwindigkeit = ResourceValue(base: gs, bonus: bonus, max: gs + bonus)
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
