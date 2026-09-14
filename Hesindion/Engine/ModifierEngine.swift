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
    let evaluate: (Situation) -> ModifierLine?
}

// MARK: - ModifierEngine

struct ModifierEngine {
    private let modifiers: [ModifierDefinition]

    init(modifiers: [ModifierDefinition]) {
        self.modifiers = modifiers
    }

    func evaluate(context situation: Situation) -> [ModifierLine] {
        guard let domain = situation.checkDomain else { return [] }
        let lines = modifiers
            .filter { $0.domains.contains(domain) }
            .compactMap { $0.evaluate(situation) }
        return Self.applyingZustandCap(lines)
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
        defs.append(contentsOf: MagicModifiers.all)
        defs.append(contentsOf: HitZoneModifiers.all)
        return ModifierEngine(modifiers: defs)
    }()
}
