import Foundation
import RulesEngine

/// One base value: the engine's breakdown, its result, and the result without the Belastung lines
/// (`COND_1`), which is what a roll screen starts from until domain 2 moves Belastung to the engine
/// (sheet cut-over design §4).
struct SheetValue {
    let breakdown: Breakdown
    var result: Int? { breakdown.result }
    var withoutBelastung: Int? {
        result.map { r in r - breakdown.lines.filter { $0.origin?.rule == "COND_1" }.reduce(0) { $0 + $1.value } }
    }
}

/// Every base value of one hero, from one `HeroSheet` (design §2, §3). `of(_:)` returns the same
/// instance while the hero's sheet is unchanged, so a redraw does not run the engine; each value
/// is evaluated on first read and kept.
@MainActor
final class SheetValues {
    let sheet: HeroSheet
    private let engine: Engine
    private var memo: [MemoKey: SheetValue] = [:]

    private struct MemoKey: Hashable {
        let query: String
        let sheet: HeroSheet
    }

    private init(sheet: HeroSheet, engine: Engine) {
        self.sheet = sheet
        self.engine = engine
    }

    private static var cache: [ObjectIdentifier: SheetValues] = [:]

    /// nil when the rules are not loaded (`RulesEngineStore.shared` is nil).
    static func of(_ hero: Hero) -> SheetValues? {
        guard let store = RulesEngineStore.shared else { return nil }
        let sheet = HeroSheetMapping.sheet(for: hero, book: store.engine.book)
        let key = ObjectIdentifier(hero)
        if let hit = cache[key], hit.sheet == sheet { return hit }
        let values = SheetValues(sheet: sheet, engine: store.engine)
        cache[key] = values
        return values
    }

    private func value(_ query: String, in sheet: HeroSheet? = nil) -> SheetValue {
        let key = MemoKey(query: query, sheet: sheet ?? self.sheet)
        if let hit = memo[key] { return hit }
        let v = SheetValue(breakdown: engine.evaluate(Query(query), in: RulesEngine.Situation(sheet: key.sheet)))
        memo[key] = v
        return v
    }

    var leMax: SheetValue { value("leMax") }
    var wundschwelle: SheetValue { value("wundschwelle") }
    var iniBase: SheetValue { value("iniBase") }
    var aw: SheetValue { value("aw") }
    var gs: SheetValue { value("gs") }

    struct Pair {
        let at: SheetValue
        let pa: SheetValue
    }

    /// A technique with no item (`at(with: CT_5)`).
    func technique(_ ruleId: String) -> Pair {
        Pair(at: value("at(with: \(ruleId))"), pa: value("pa(with: \(ruleId))"))
    }

    /// A weapon's values with that weapon in hand and the current shield, queried by slot
    /// (`at(with: weapon)`): the rules that read the main weapon match the slot, not a name.
    func weapon(_ w: MeleeWeapon) -> Pair {
        let s = sheet.with(weapon: HeroSheetMapping.engineName(w.name, template: w.templateId, book: engine.book))
        return Pair(at: value("at(with: weapon)", in: s), pa: value("pa(with: weapon)", in: s))
    }

    /// A shield's own AT and its shield parry, with that shield carried, queried by slot.
    ///
    /// kampfwerte.KW1's MU term is guarded on the *weapon slot's* technique
    /// (`loadout.weapon.technique`), not on the piece the query is `with:` — confirmed
    /// correct by kampfwerte 16.8 (a passing situation), whose loadout keeps a real
    /// weapon in the slot even while attacking with the shield. Before the player has
    /// chosen a loadout there may be no weapon selected at all (the preparation
    /// screen, task 7 fix round 1): an empty slot leaves that guard unresolved and
    /// drops the MU term from the shield's own AT. The shield is always a known,
    /// non-Peitschen technique — filling the slot with it when it is otherwise empty
    /// resolves the guard without changing what "with: shield" itself means to any
    /// other clause (`action.with` stays `shield`).
    func shield(_ sh: Shield) -> Pair {
        let name = HeroSheetMapping.engineName(sh.name, template: sh.templateId, book: engine.book)
        var s = sheet.with(shield: name)
        if s.loadout.weapon == nil { s = s.with(weapon: name) }
        return Pair(at: value("at(with: shield)", in: s), pa: value("pa(with: shield)", in: s))
    }
}
