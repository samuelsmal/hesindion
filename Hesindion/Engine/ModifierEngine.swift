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

// MARK: - ModifierContext

struct ModifierContext {
    let hero: Hero
    let domain: CheckDomain

    // Combat shared
    var mounted: Bool = false
    var schipIgnoreZustand: Bool = false
    var dualAttackActive: Bool = false
    var beengteUmgebung: Bool = false
    var gottgefaellig: Bool = false

    // Melee specific
    var opponentReach: WeaponReach? = nil
    var maneuver: CombatManeuver = .normal
    var isOffHand: Bool = false
    var twoHandedGrip: Bool = false
    var defenseCount: Int = 0
    var schipDefenseBoost: Bool = false

    // Ranged specific
    var distanz: Int = 1
    var groesse: Int = 2
    var bewegungZiel: Int = 1
    var bewegungSchuetze: Int = 0
    var sicht: Int = 0
    var kampfgetuemmel: Bool = false
    var zielen: Int = 0
    var vomPferd: Int = 0

    // Magic specific
    var maintainedSpellCount: Int = 0
    var foreignTradition: Bool = false
    var omitGesture: Bool = false
    var omitFormula: Bool = false
    var ironSteinCarried: Int = 0
    var distractionLevel: Int = 0
    var spellModifications: [SpellModification] = []

    // Plaenkler
    var plaenklerActive: Bool = false
    var plaenklerBonus: PlaenklerBonus = .at
}

// MARK: - ModifierDefinition

struct ModifierDefinition: Identifiable {
    let id: String
    let domains: Set<CheckDomain>
    let evaluate: (ModifierContext) -> ModifierLine?
}

// MARK: - ModifierEngine

struct ModifierEngine {
    private let modifiers: [ModifierDefinition]

    init(modifiers: [ModifierDefinition]) {
        self.modifiers = modifiers
    }

    func evaluate(context: ModifierContext) -> [ModifierLine] {
        let lines = modifiers
            .filter { $0.domains.contains(context.domain) }
            .compactMap { $0.evaluate(context) }
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

    func totalModifier(context: ModifierContext) -> Int {
        evaluate(context: context).reduce(0) { $0 + $1.value }
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
        return ModifierEngine(modifiers: defs)
    }()
}
