import Foundation

// MARK: - CheckDomain

enum CheckDomain: String, CaseIterable {
    case meleeAttack
    case meleeParry
    case meleeDodge
    case rangedAttack
    case spellCasting
    case liturgyCasting
    case talentCheck
}

// MARK: - SpellModification

enum SpellModification: Hashable {
    case reduceCastingTime
    case increaseCastingTime
    case increaseRange
    case reduceCost
    case force
    case omitGesture
    case omitFormula
}

// MARK: - ModifierDefinition

struct ModifierDefinition: Identifiable {
    let id: String
    let domains: Set<CheckDomain>
    /// The catalog ids this definition stands for, so the migration test can
    /// refuse a rule that is implemented on both sides. Empty only for a rule
    /// with no catalog entry yet.
    ///
    /// A set in all but type: order and duplicates mean nothing, it is only
    /// ever read as a membership test. It is a `var` rather than a `let` so
    /// the synthesized memberwise init keeps the default — a `let` with a
    /// default value is dropped from that init, and every call site without a
    /// `rules:` argument would stop compiling.
    var rules: [String] = []
    let evaluate: (Situation) -> ModifierLine?
}

// MARK: - ModifierEngine

/// The union of the Swift definitions still in migration and the catalog
/// (design §7 step 2). When the Swift list is empty this becomes a thin
/// wrapper around `RuleEvaluator`.
struct ModifierEngine {
    let definitions: [ModifierDefinition]
    let catalog: RuleCatalog

    init(modifiers: [ModifierDefinition], catalog: RuleCatalog = .bundled) {
        self.definitions = modifiers
        self.catalog = catalog
    }

    /// Everything the catalog says about this roll.
    func evaluation(_ situation: Situation) -> Evaluation {
        RuleEvaluator.evaluate(catalog: catalog, situation: situation)
    }

    /// The lines both sides produce, capped once.
    func evaluate(context situation: Situation) -> [ModifierLine] {
        let swift: [ModifierLine] = situation.checkDomain.map { domain in
            definitions.filter { $0.domains.contains(domain) }.compactMap { $0.evaluate(situation) }
        } ?? []
        let catalogLines = evaluation(situation).lines.map(\.modifierLine)
        return Self.applyingZustandCap(swift + catalogLines)
    }

    /// GR: the combined Zustand penalty is capped at −5. Encumbrance and Schmerz count
    /// as Zustände for the cap (they are tagged `isZustand`). Non-Zustand bonuses/penalties
    /// (maneuvers, schip defense +4, …) are never clamped — only the aggregate Zustand
    /// penalty floors at −5 via an explicit correction line.
    static func applyingZustandCap(_ lines: [ModifierLine]) -> [ModifierLine] {
        let zustandPenalty = lines.filter { $0.isZustand }.reduce(0) { $0 + min(0, $1.value) }
        guard zustandPenalty < -5 else { return lines }
        let correction = -5 - zustandPenalty   // positive
        return lines + [ModifierLine(value: correction, source: L("source.zustandCap"), isZustand: false)]
    }

    func totalModifier(context situation: Situation) -> Int {
        evaluate(context: situation).reduce(0) { $0 + $1.value }
    }
}

// MARK: - Shared Instance

extension ModifierEngine {
    static let shared: ModifierEngine = {
        var defs: [ModifierDefinition] = []
        defs.append(contentsOf: SharedModifiers.all)
        defs.append(contentsOf: StateModifiers.all)
        defs.append(contentsOf: MeleeModifiers.all)
        defs.append(contentsOf: DefenseModifiers.all)
        defs.append(contentsOf: RangedModifiers.all)
        defs.append(contentsOf: FumbleModifiers.all)
        defs.append(contentsOf: MagicModifiers.all)
        return ModifierEngine(modifiers: defs)
    }()
}
