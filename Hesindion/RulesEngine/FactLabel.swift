import Foundation
import RulesEngine

/// What `BreakdownSheet` prints for a fact's name (sheet cut-over design §5: "MU 14 · Heldenbogen",
/// not the engine's own "attr.MU 14 · Heldenbogen"). A label lookup only — no rule content.
enum FactLabel {
    /// `book` is nil only when the rules failed to load, which the breakdown never reaches anyway
    /// (`SheetValues.of` is nil first); every case here still degrades to a readable fallback.
    static func label(_ factName: String, book: RuleBook?) -> String {
        if factName.hasPrefix("attr."), !factName.dropFirst(5).isEmpty {
            return String(factName.dropFirst(5))
        }
        if factName.hasPrefix("ktw."), let id = suffix(of: factName, after: "ktw.", startingWith: "CT_") {
            if let table = book?.table("kampfwerte.kampftechnik"), case .object(let names) = table,
               let name = names[id]?.string {
                return name
            }
            return id
        }
        if factName.hasPrefix("fw."), let id = suffix(of: factName, after: "fw.", startingWith: "TAL_") {
            return book?.rules[id]?.name ?? id
        }
        if let key = knownFacts[factName] {
            return L(key)
        }
        return factName
    }

    /// `factName` past `prefix`, only when it starts with `marker` (so an unrelated fact under the
    /// same prefix, e.g. `fw.current`, falls through to the raw-name case instead of being mangled).
    private static func suffix(of factName: String, after prefix: String, startingWith marker: String) -> String? {
        let id = String(factName.dropFirst(prefix.count))
        return id.hasPrefix(marker) ? id : nil
    }

    /// Facts the sheet domain can show that name neither an attribute nor a technique/talent —
    /// each maps to an `L()` key (`fact.<name>`).
    private static let knownFacts: [String: String] = [
        "species.le": "fact.species.le",
        "hero.purchased.le": "fact.hero.purchased.le",
        "level": "fact.level",
        "loadout.weapon": "fact.loadout.weapon",
        "loadout.shield": "fact.loadout.shield",
        "loadout.armour": "fact.loadout.armour",
        "loadout.armour.belastung": "fact.loadout.armour.belastung",
        "loadout.armour.extraPenalty": "fact.loadout.armour.extraPenalty",
    ]
}
