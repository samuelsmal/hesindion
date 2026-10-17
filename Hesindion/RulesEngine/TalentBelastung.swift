import Foundation
import RulesEngine

/// The talent check's Belastung (sheet cut-over design §6): the engine's `COND_1` lines of
/// `check.modifier`, and the player's choices for this one check. The rest of the check stays in
/// Swift until domain 5, so only `COND_1`'s lines are taken — a "maybe" talent's SA_9-style
/// modifiers and everything else about the roll are untouched.
enum TalentBelastung {
    /// What the player answers "Vor der Probe", for this check only — nothing here is written
    /// to the stored loadout.
    struct Choices: Equatable {
        /// Items the player put down for this check (by the app's names): an equipped armour, or
        /// the selected shield.
        var putDown: Set<String> = []
        /// "Belastung nicht anwenden": the lines stay, struck through, and add nothing. An app
        /// decision, not a rule — the rule files do not change.
        var ignoreBelastung = false
        /// "Belastung zählt", for the talents `checks.yaml` flags `maybe` (ruling
        /// belastung-talents-maybe). Off unless the player turns it on.
        var belastungZaehlt = false

        init(putDown: Set<String> = [], ignoreBelastung: Bool = false, belastungZaehlt: Bool = false) {
            self.putDown = putDown
            self.ignoreBelastung = ignoreBelastung
            self.belastungZaehlt = belastungZaehlt
        }
    }

    struct Result {
        var lines: [ModifierLine]
        var struck: Bool
        /// The Stufe of Belastung (`level(rule: COND_1)`) the check sees, after SA_41 and the
        /// choices above.
        var level: Int
        /// What is still in the loadout for this check (armour, shield), after `putDown` —
        /// what the summary row names as the cause.
        var pieces: [String]
        var breakdown: Breakdown?

        /// What the check adds: nothing when struck.
        var effectiveLines: [ModifierLine] { struck ? [] : lines }
    }

    /// The `COND_1` lines of `check.modifier` for `talentId`, with `choices` applied. Empty when
    /// the rules engine is unavailable, the talent is not flagged (`checks.yaml`'s
    /// `hinderedByBelastung`), or nothing hinders it.
    @MainActor
    static func lines(hero: Hero, talentId: String, choices: Choices) -> Result {
        guard let store = RulesEngineStore.shared else {
            return Result(lines: [], struck: false, level: 0, pieces: [], breakdown: nil)
        }
        var sheet = HeroSheetMapping.sheet(for: hero, book: store.engine.book)

        let worn = hero.armorsInOrder.filter { $0.isEquipped && !choices.putDown.contains($0.name) }
        sheet = sheet.with(armour: worn.first?.name,
                           belastung: worn.reduce(0) { $0 + $1.encumbrance },
                           extraPenalty: worn.reduce(0) { $0 + $1.iniModifier })

        var pieces = worn.map(\.name)
        if let shieldName = hero.selectedShieldName {
            if choices.putDown.contains(shieldName) {
                sheet = sheet.with(shield: nil)
            } else {
                pieces.append(shieldName)
            }
        }

        var situation = RulesEngine.Situation(sheet: sheet)
        situation.state(Fact(name: "check.kind", value: .string("talent"), owner: .player))
        situation.state(Fact(name: "check.talent", value: .string(talentId), owner: .player))
        if let flag = store.checks.hinderedByBelastung[talentId] {
            situation.state(Fact(name: "check.hinderedByBelastung", value: flag, owner: .derived))
        }
        if choices.belastungZaehlt {
            situation.state(Fact(name: "choice.belastungZaehlt", value: .bool(true), owner: .player))
        }

        let b = store.engine.evaluate(Query("check.modifier"), in: situation)
        let ruleName = store.engine.book.rules["COND_1"]?.name ?? "COND_1"
        let lines = b.lines.filter { $0.origin?.rule == "COND_1" }.map {
            ModifierLine(value: $0.value, source: ruleName, isZustand: true, ruleId: "COND_1")
        }
        let level = store.engine.evaluate(Query("level(rule: COND_1)"), in: situation).result ?? 0

        return Result(lines: lines, struck: choices.ignoreBelastung && !lines.isEmpty,
                     level: level, pieces: pieces, breakdown: b)
    }

    /// Whether the hero's loadout could hinder `talentId` at all: something worn or held, and the
    /// talent is not flagged `false` (`checks.yaml`). The row (§6) shows only then; a talent
    /// flagged `false` never has a Belastung line to offer choices about.
    @MainActor
    static func isRelevant(hero: Hero, talentId: String) -> Bool {
        let carriesLoad = hero.armorsInOrder.contains(where: \.isEquipped) || hero.selectedShieldName != nil
        guard carriesLoad, let store = RulesEngineStore.shared else { return false }
        return store.checks.hinderedByBelastung[talentId] != .bool(false)
    }

    /// Whether `talentId` is one of the seven talents `checks.yaml` flags `maybe` — the row then
    /// offers "Belastung zählt" (ruling belastung-talents-maybe).
    @MainActor
    static func isMaybe(talentId: String) -> Bool {
        RulesEngineStore.shared?.checks.hinderedByBelastung[talentId] == .string("maybe")
    }

    /// `base` (the Swift `ModifierEngine`'s own lines for this check, cap already applied once by
    /// `ModifierEngine.evaluate`) combined with `belastung`'s effective lines, capped exactly once
    /// over the union. `ModifierEngine.evaluate` may have appended its own `−5` correction line
    /// (`source.zustandCap`) if the Swift-only Zustände already exceeded the cap on their own —
    /// that line is dropped first, or reapplying the cap over `base + belastung.effectiveLines`
    /// would correct twice (the old line stays, non-Zustand, and a second correction is appended
    /// on top of it). `TalentBelastungTests.testTheCapAppliesOnceOverTheCombinedZustandLines`
    /// holds this to that exact scenario.
    static func combinedModifierLines(base: [ModifierLine], belastung: Result) -> [ModifierLine] {
        guard !belastung.effectiveLines.isEmpty else { return base }
        let withoutCap = base.filter { $0.source != L("source.zustandCap") }
        return ModifierEngine.applyingZustandCap(withoutCap + belastung.effectiveLines)
    }
}
