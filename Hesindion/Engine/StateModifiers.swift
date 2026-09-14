import Foundation

/// Feeds catalog-driven player states (Zustände & Status) into the ModifierEngine.
///
/// One `ModifierDefinition` is generated per catalog state with a `.penalty` mechanic,
/// plus a dedicated Entrückung definition. All Zustand-derived lines are tagged
/// `isZustand: true` so `ModifierEngine` can apply the combined −5 Zustand cap.
enum StateModifiers {
    static var all: [ModifierDefinition] { penaltyDefinitions + [entrueckungDef] }

    /// `StateCatalog` id → catalog rule id, for the migration test and the
    /// not-applied list. Every state the catalog knows is here.
    static let ruleIds: [String: String] = [
        "belastung": "COND_1", "betaeubung": "COND_2", "entrueckung": "COND_3", "furcht": "COND_4",
        "paralyse": "COND_5", "schmerz": "COND_6", "verwirrung": "COND_7", "berauscht": "COND_9",
        "bewegungsunfaehig": "STATE_1", "bewusstlos": "STATE_2", "blind": "STATE_3", "brennend": "STATE_5",
        "eingeengt": "STATE_6", "fixiert": "STATE_7", "handlungsunfaehig": "STATE_8", "krank": "STATE_9",
        "liegend": "STATE_10", "stumm": "STATE_11", "taub": "STATE_12", "ueberrascht": "STATE_13",
        "unsichtbar": "STATE_14", "vergiftet": "STATE_15", "uebler_geruch": "STATE_19",
        "versteinert": "STATE_20", "blutend": "STATE_21",
    ]

    /// One definition per catalog state whose mechanic is `.penalty`.
    static let penaltyDefinitions: [ModifierDefinition] = StateCatalog.all.compactMap { def in
        guard case .penalty(let domains, let value) = def.mechanic else { return nil }
        return ModifierDefinition(id: "state.\(def.id)", domains: domains,
                                  rules: [StateModifiers.ruleIds[def.id]].compactMap { $0 }) { ctx in
            guard !ctx.round.schipIgnoreZustand else { return nil }
            let level = ctx.hero.level(of: def.id)
            guard level > 0 else { return nil }
            let isZustand = def.kind == .zustand
            let penalty: Int
            switch value {
            case .perLevel:        penalty = -level
            case .fixed(let map):  penalty = ctx.checkDomain.flatMap { map[$0] } ?? 0
            }
            guard penalty != 0 else { return nil }
            // Zustände show roman numerals; statuses are binary.
            let roman = isZustand ? StateCatalog.romanSuffix(level) : ""
            return ModifierLine(value: penalty, source: L(def.nameKey) + roman, isZustand: isZustand)
        }
    }

    /// Entrückung: gottgefällige Proben + (level−1 with floor), all others −level.
    static let entrueckungDef = ModifierDefinition(
        id: "state.entrueckung", domains: Set(CheckDomain.allCases), rules: ["COND_3"]
    ) { ctx in
        guard !ctx.round.schipIgnoreZustand else { return nil }
        let level = ctx.hero.level(of: "entrueckung")
        guard level > 0 else { return nil }
        let value = ctx.gottgefaellig ? max(0, level - 1) : -level
        guard value != 0 else { return nil }
        let roman = StateCatalog.romanSuffix(level)
        return ModifierLine(value: value, source: L("state.entrueckung.name") + roman, isZustand: true)
    }
}
