import Foundation
import SwiftData

/// Repairs a hero's `generalSpecialAbilities` / `combatSpecialAbilities` split so it matches
/// what a fresh import produces today.
///
/// `OptolithImportService.isCombatSpecialAbility` moved from "the rule has a hand-authored
/// effect with `scope: combat`" (9 matches) to "the rule's Optolith group is one of
/// 3, 9, 10, 11, 12" (232 matches) — see ADR-0008. That is a correction, not a stored value,
/// so it does not reach a hero already in the store: `combatSpecialAbilities` is written once
/// at import (`OptolithImportService.swift`) and never touched again. A hero imported before
/// this change keeps `SA_884` (Plänkler-Formation) and `SA_160`/`SA_161` (Trefferzonen
/// halving) in `generalSpecialAbilities` forever, where no combat code looks; the same hero
/// re-imported from the same JSON gets a different split and behaves differently — two
/// players at one table, same character file, different numbers, nothing explains it.
///
/// Re-import was considered as the migration path and rejected by the user: this repair is
/// the migration path instead, matching the precedent `DerivedValueRepair` set for the GS and
/// rounding fixes (ADR-0006).
///
/// This is a *classification* repair — it moves traits between two arrays — not a
/// derived-value one, so it does not live in `DerivedValueRepair`, whose documented contract
/// is the attribute- and species-keyed derived values.
enum SpecialAbilityClassificationRepair {

    /// Re-splits one hero's special-ability traits through
    /// `OptolithImportService.isCombatSpecialAbility`, the same predicate the import uses.
    ///
    /// - Parameter lookupGroupId: the Optolith group lookup, injectable so tests can drive
    ///   the classification without depending on what the bundled `rules.db` happens to
    ///   contain. Production callers pass `RulesDatabase.shared.lookupGroupId`.
    /// - Returns: `true` if either array changed. Idempotent — a second call on the same
    ///   hero (with the same `lookupGroupId`) returns `false`.
    ///
    /// Only traits whose id starts with `SA_` are reclassified; anything else already in
    /// either array (there should not be any, but this repair does not assume that) stays
    /// exactly where it was, in its original relative order, and nothing is dropped or
    /// duplicated — only the boundary between the two arrays moves.
    ///
    /// A rule id the database does not know (a deleted or renamed id, or a hero on a stale
    /// `rules.db`) makes `lookupGroupId` return `nil`, which `isCombatSpecialAbility` treats
    /// as "not combat" — so a trait currently in `combatSpecialAbilities` whose id is unknown
    /// is *demoted* to `generalSpecialAbilities`. That is deliberate: it is exactly what a
    /// fresh import of that hero would produce today, and matching a fresh import is the
    /// whole point of this repair.
    @discardableResult
    static func repair(_ hero: Hero, lookupGroupId: (String) -> Int?) -> Bool {
        func isReclassifiableCombatSA(_ trait: HeroTrait) -> Bool? {
            guard trait.ruleId.hasPrefix("SA_") else { return nil }
            return OptolithImportService.isCombatSpecialAbility(groupId: lookupGroupId(trait.ruleId))
        }

        var generalStays: [HeroTrait] = []
        var generalToCombat: [HeroTrait] = []
        for trait in hero.generalSpecialAbilities {
            if isReclassifiableCombatSA(trait) == true {
                generalToCombat.append(trait)
            } else {
                generalStays.append(trait)
            }
        }

        var combatStays: [HeroTrait] = []
        var combatToGeneral: [HeroTrait] = []
        for trait in hero.combatSpecialAbilities {
            if isReclassifiableCombatSA(trait) == false {
                combatToGeneral.append(trait)
            } else {
                combatStays.append(trait)
            }
        }

        guard !generalToCombat.isEmpty || !combatToGeneral.isEmpty else { return false }

        hero.generalSpecialAbilities = generalStays + combatToGeneral
        hero.combatSpecialAbilities = combatStays + generalToCombat
        return true
    }

    /// Repairs every hero in the context. Saves only if something actually changed, so a
    /// clean launch performs no writes — the same discipline `DerivedValueRepair.repairAll`
    /// uses.
    static func repairAll(in context: ModelContext, lookupGroupId: (String) -> Int?) {
        guard let heroes = try? context.fetch(FetchDescriptor<Hero>()) else { return }
        let repaired = heroes.reduce(into: 0) { count, hero in
            if repair(hero, lookupGroupId: lookupGroupId) { count += 1 }
        }
        guard repaired > 0 else { return }
        try? context.save()
        print("SpecialAbilityClassificationRepair: reclassified \(repaired) hero(es)")
    }
}
