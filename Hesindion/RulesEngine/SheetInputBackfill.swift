import Foundation
import SwiftData

/// Fills the inputs SchemaV5 added (`atModifier`, `paModifier`, `speciesLE`) for heroes imported
/// before them, from the folded values the import stored: a weapon's AT/PA minus its technique's,
/// a shield's AT minus the Schilde technique's, LE base minus twice KO. Writes nothing it cannot
/// derive. Runs at launch until SchemaV6 drops the folded values (sheet cut-over plan, Task 11).
enum SheetInputBackfill {
    /// - Returns: `true` if anything changed. Idempotent.
    @discardableResult
    static func fill(_ hero: Hero) -> Bool {
        var changed = false
        let techniques = Dictionary(hero.combatTechniques.map { ($0.ruleId, $0) },
                                    uniquingKeysWith: { a, _ in a })
        for w in hero.meleeWeapons {
            guard let ct = techniques[w.combatTechniqueId] else { continue }
            if w.atModifier == nil { w.atModifier = w.at - ct.at; changed = true }
            // ct.pa == 0 is the import's no-parry marker (parseCombatTechniques), not a real
            // technique PA the fold used — deriving against it would read a stale weapon.pa.
            if w.paModifier == nil && ct.pa != 0 { w.paModifier = w.pa - ct.pa; changed = true }
        }
        if let ct = techniques["CT_10"] {
            for s in hero.shields where s.atModifier == nil {
                s.atModifier = s.at - ct.at
                changed = true
            }
        }
        if let dv = hero.derivedValues, dv.speciesLE == nil, let ko = hero.attributes?.ko {
            dv.speciesLE = dv.lebensenergie.base - 2 * ko
            changed = true
        }
        return changed
    }

    static func fillAll(in context: ModelContext) {
        let heroes = (try? context.fetch(FetchDescriptor<Hero>())) ?? []
        if heroes.map(fill).contains(true) { try? context.save() }
    }
}
