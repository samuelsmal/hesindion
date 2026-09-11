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
enum DerivedValueRepair {

    /// Recomputes Wundschwelle, Ausweichen and Initiative in place.
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
