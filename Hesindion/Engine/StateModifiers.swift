import Foundation

/// Feeds catalog-driven player states (Zustände & Status) into the ModifierEngine.
///
/// One `ModifierDefinition` is generated per catalog state with a `.penalty` mechanic,
/// plus a dedicated Entrückung definition. All Zustand-derived lines are tagged
/// `isZustand: true` so `ModifierEngine` can apply the combined −5 Zustand cap.
enum StateModifiers {
    static var all: [ModifierDefinition] { penaltyDefinitions + [entrueckungDef] }

    /// One definition per catalog state whose mechanic is `.penalty`.
    static let penaltyDefinitions: [ModifierDefinition] = StateCatalog.all.compactMap { def in
        guard case .penalty(let domains, let value) = def.mechanic else { return nil }
        return ModifierDefinition(id: "state.\(def.id)", domains: domains) { ctx in
            guard !ctx.schipIgnoreZustand else { return nil }
            let level = ctx.hero.level(of: def.id)
            guard level > 0 else { return nil }
            let isZustand = def.kind == .zustand
            let penalty: Int
            switch value {
            case .perLevel:        penalty = -level
            case .fixed(let map):  penalty = map[ctx.domain] ?? 0
            }
            guard penalty != 0 else { return nil }
            // Zustände show roman numerals; statuses are binary.
            let roman = isZustand ? StateCatalog.romanSuffix(level) : ""
            return ModifierLine(value: penalty, source: L(def.nameKey) + roman, isZustand: isZustand)
        }
    }

    /// Entrückung: gottgefällige Proben + (level−1 with floor), all others −level.
    static let entrueckungDef = ModifierDefinition(
        id: "state.entrueckung", domains: Set(CheckDomain.allCases)
    ) { ctx in
        guard !ctx.schipIgnoreZustand else { return nil }
        let level = ctx.hero.level(of: "entrueckung")
        guard level > 0 else { return nil }
        let value = ctx.gottgefaellig ? max(0, level - 1) : -level
        guard value != 0 else { return nil }
        let roman = StateCatalog.romanSuffix(level)
        return ModifierLine(value: value, source: L("state.entrueckung.name") + roman, isZustand: true)
    }
}
