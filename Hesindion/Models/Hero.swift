import Foundation
import SwiftData

@Model
final class Hero {
    var name: String
    var avatar: Data?
    var advantages: [HeroTrait]
    var disadvantages: [HeroTrait]
    var generalSpecialAbilities: [HeroTrait]
    var combatSpecialAbilities: [HeroTrait]
    var cantrips: [HeroTrait]
    var blessings: [HeroTrait]
    var scripts: [String]

    @Relationship(deleteRule: .cascade) var personalData: PersonalData?
    @Relationship(deleteRule: .cascade) var experience: Experience?
    @Relationship(deleteRule: .cascade) var attributes: Attributes?
    @Relationship(deleteRule: .cascade) var derivedValues: DerivedValues?
    @Relationship(deleteRule: .cascade) var talents: [Talent]
    @Relationship(deleteRule: .cascade) var combatTechniques: [CombatTechnique]
    @Relationship(deleteRule: .cascade) var meleeWeapons: [MeleeWeapon]
    @Relationship(deleteRule: .cascade) var rangedWeapons: [RangedWeapon]
    @Relationship(deleteRule: .cascade) var armors: [Armor]
    @Relationship(deleteRule: .cascade) var shields: [Shield]
    @Relationship(deleteRule: .cascade) var equipment: [EquipmentItem]
    @Relationship(deleteRule: .cascade) var money: Money?
    @Relationship(deleteRule: .cascade) var pets: [Pet]
    @Relationship(deleteRule: .cascade) var languages: [Language]
    @Relationship(deleteRule: .cascade) var spells: [HeroSpell]
    @Relationship(deleteRule: .cascade) var liturgies: [HeroSpell]
    @Relationship(deleteRule: .cascade, inverse: \LogEntry.hero) var logEntries: [LogEntry] = []
    @Relationship(deleteRule: .cascade) var states: [HeroStateEntry] = []

    var activeAdventure: Adventure?

    // MARK: - Notes

    var notes: String = ""
    var colorSchemeId: String?

    // MARK: - Loadout persistence

    var selectedWeaponName: String?
    var selectedShieldName: String?
    var selectedOffHandName: String?
    var selectedRangedWeaponName: String?

    // MARK: - Combat session state

    var activeCombatId: UUID?
    var activeCombatRound: Int = 0
    var activeCombatInitiative: Int?
    var activeCombatPlaenkler: Bool = false
    var activeCombatPlaenklerBonus: String?   // "at" or "aw"
    var activeCombatMounted: Bool = false
    // Deprecated: replaced by the eingeengt status (HeroStateEntry); retained to avoid a SwiftData migration.
    var activeCombatBeengt: Bool = false

    init(
        name: String,
        avatar: Data? = nil,
        advantages: [HeroTrait] = [],
        disadvantages: [HeroTrait] = [],
        generalSpecialAbilities: [HeroTrait] = [],
        combatSpecialAbilities: [HeroTrait] = [],
        cantrips: [HeroTrait] = [],
        blessings: [HeroTrait] = [],
        scripts: [String] = []
    ) {
        self.name = name
        self.avatar = avatar
        self.advantages = advantages
        self.disadvantages = disadvantages
        self.generalSpecialAbilities = generalSpecialAbilities
        self.combatSpecialAbilities = combatSpecialAbilities
        self.cantrips = cantrips
        self.blessings = blessings
        self.scripts = scripts
        self.talents = []
        self.combatTechniques = []
        self.meleeWeapons = []
        self.rangedWeapons = []
        self.armors = []
        self.shields = []
        self.equipment = []
        self.pets = []
        self.languages = []
        self.spells = []
        self.liturgies = []

        // Combat session defaults
        self.activeCombatId = nil
        self.activeCombatRound = 0
        self.activeCombatInitiative = nil
        self.activeCombatPlaenkler = false
        self.activeCombatPlaenklerBonus = nil
        self.activeCombatMounted = false
    }

    var totalEquipmentWeight: Double {
        let equipmentWeight = equipment.reduce(0.0) { $0 + $1.weight }
        let weaponWeight    = meleeWeapons.reduce(0.0) { $0 + $1.weight }
        let rangedWeight    = rangedWeapons.reduce(0.0) { $0 + $1.weight }
        let armorWeight     = armors.reduce(0.0) { $0 + $1.weight }
        let shieldWeight    = shields.reduce(0.0) { $0 + $1.weight }
        return equipmentWeight + weaponWeight + rangedWeight + armorWeight + shieldWeight
    }

    /// Derived from KK attribute per DSA rules.
    var carryingCapacity: Int { (attributes?.kk ?? 0) * 2 }

    var totalCarryingCapacity: Int {
        carryingCapacity + pets.reduce(0) { $0 + $1.carryingCapacity }
    }

    var carryingThreshold: Double {
        Double(totalCarryingCapacity)
    }

    var isOverloaded: Bool {
        totalEquipmentWeight > carryingThreshold
    }

    /// +1 if the hero has "Verbesserte Regeneration (Lebensenergie)", +2 if it's level II.
    var verbessertRegenerationLEBonus: Int {
        guard let adv = advantages.first(where: { $0.ruleId == "ADV_44" }) else { return 0 }
        return (adv.tier ?? 1) >= 2 ? 2 : 1
    }

    /// Sum of RS from all equipped armor pieces.
    var totalRS: Int {
        armors.filter(\.isEquipped).reduce(0) { $0 + $1.protectionValue }
    }

    /// Sum of BE from all equipped armor pieces.
    var totalEquippedBE: Int {
        armors.filter(\.isEquipped).reduce(0) { $0 + $1.encumbrance }
    }

    /// Level of Belastungsgewöhnung combat SA (SA_41). Each level reduces effective BE by 2.
    var belastungsgewoehnungLevel: Int {
        combatSpecialAbilities.first(where: { $0.ruleId == "SA_41" })?.tier ?? 0
    }

    /// Effective BE after Belastungsgewöhnung reduction.
    var effectiveBE: Int {
        max(0, totalEquippedBE - 2 * belastungsgewoehnungLevel)
    }

    /// Belastung penalty applied to AT, PA, AW, INI, GS. Equals negative effectiveBE.
    var belastungPenalty: Int {
        -effectiveBE
    }

    /// Sum of direct INI modifiers from equipped armor (independent of BE).
    var armorIniModifier: Int {
        armors.filter(\.isEquipped).reduce(0) { $0 + $1.iniModifier }
    }

    /// Sum of direct GS modifiers from equipped armor (independent of BE).
    var armorGsModifier: Int {
        armors.filter(\.isEquipped).reduce(0) { $0 + $1.gsModifier }
    }

    /// Total INI penalty: Belastung + direct armor modifiers.
    var totalIniPenalty: Int {
        belastungPenalty + armorIniModifier
    }

    /// Total GS penalty: Belastung + direct armor modifiers.
    var totalGsPenalty: Int {
        belastungPenalty + armorGsModifier
    }

    // MARK: - Loadout computed helpers

    var selectedRangedWeapon: RangedWeapon? {
        guard let name = selectedRangedWeaponName else { return nil }
        return rangedWeapons.first { $0.name == name }
    }

    var selectedWeapon: MeleeWeapon? {
        guard let name = selectedWeaponName else { return nil }
        return meleeWeapons.first { $0.name == name }
    }

    var selectedShield: Shield? {
        if let name = selectedOffHandName, let shield = shields.first(where: { $0.name == name }) {
            return shield
        }
        guard let name = selectedShieldName else { return nil }
        return shields.first { $0.name == name }
    }

    /// Passive shield PA bonus applied to main weapon parade.
    var passiveShieldPABonus: Int {
        selectedShield?.paModifier ?? 0
    }

    /// Off-hand weapon (only if off-hand is a melee weapon, not a shield).
    var selectedOffHandWeapon: MeleeWeapon? {
        guard let name = selectedOffHandName else { return nil }
        return meleeWeapons.first { $0.name == name }
    }

    /// True if hero has the Beidhändig advantage (ADV_5), removing the -4 off-hand penalty.
    var hasBeidhaendig: Bool {
        advantages.contains { $0.ruleId == "ADV_5" }
    }

    /// Level of Beidhändiger Kampf SA. Each level reduces the -2 dual-attack penalty by 1.
    /// TODO: Confirm correct SA ruleId for "Beidhändiger Kampf" once identified in Optolith data.
    var beidhaendigerKampfLevel: Int {
        let sa = combatSpecialAbilities.first { $0.name.contains("Beidhändiger Kampf") }
        return sa?.tier ?? 0
    }

    /// Dual-attack penalty: base -2, reduced by Beidhändiger Kampf level.
    var dualAttackPenalty: Int {
        max(0, 2 - beidhaendigerKampfLevel) * -1
    }

    /// Off-hand penalty: -4 unless hero has Beidhändig (ADV_5).
    var offHandPenalty: Int {
        hasBeidhaendig ? 0 : -4
    }

    /// True if the current loadout is dual-wielding (two weapons, no shield in off-hand).
    var isDualWielding: Bool {
        selectedWeaponName != nil && selectedOffHandWeapon != nil
    }

    // MARK: - Schmerz (Pain)

    /// Raw Schmerz level from LP thresholds (0–4+).
    var schmerzLevel: Int {
        guard let dv = derivedValues else { return 0 }
        let current = dv.lebensenergie.current
        let maxLP = dv.lebensenergie.max
        guard maxLP > 0 else { return 0 }
        var level = 0
        if current <= (maxLP * 3) / 4 { level = 1 }
        if current <= maxLP / 2 { level = 2 }
        if current <= maxLP / 4 { level = 3 }
        if current <= 5 { level += 1 }
        return level
    }

    /// True if hero has Zäher Hund (ADV_49).
    var hasZaeherHund: Bool {
        advantages.contains { $0.ruleId == "ADV_49" }
    }

    /// Effective Schmerz after Zäher Hund reduction.
    var effectiveSchmerzLevel: Int {
        let raw = schmerzLevel
        if raw >= 4 { return 4 }
        return hasZaeherHund ? max(0, raw - 1) : raw
    }

    /// Penalty from Schmerz, applied to all checks.
    var schmerzPenalty: Int { -effectiveSchmerzLevel }

    // MARK: - Player States

    /// Current stored level of a catalog state (0 if absent). Schmerz/Belastung are derived.
    func level(of stateID: String) -> Int {
        if stateID == "schmerz" { return effectiveSchmerzLevel }
        if stateID == "belastung" { return min(effectiveBE, 4) }
        return states.first { $0.stateID == stateID }?.level ?? 0
    }

    func hasState(_ stateID: String) -> Bool { level(of: stateID) > 0 }

    /// Set/clear a manually-tracked state. Clamps Zustände to 1–4, statuses to 1; level 0 removes.
    func setStateLevel(_ stateID: String, level rawLevel: Int) {
        guard !StateCatalog.derivedIDs.contains(stateID) else { return }
        let def = StateCatalog.definition(for: stateID)
        let clamped: Int = {
            if rawLevel <= 0 { return 0 }
            return def?.kind == .status ? 1 : min(rawLevel, 4)
        }()
        let existing = states.first { $0.stateID == stateID }
        if clamped == 0 {
            if let e = existing {
                states.removeAll { $0 === e }
                modelContext?.delete(e)
            }
        } else if let e = existing {
            e.level = clamped
        } else {
            states.append(HeroStateEntry(stateID: stateID, level: clamped))
        }
    }

    /// All active states (stored + derived Schmerz/Belastung when > 0), as (definition, level).
    var activeStates: [(def: StateDefinition, level: Int)] {
        var result: [(StateDefinition, Int)] = []
        if let s = StateCatalog.definition(for: "schmerz"), effectiveSchmerzLevel > 0 {
            result.append((s, effectiveSchmerzLevel))
        }
        if let b = StateCatalog.definition(for: "belastung"), effectiveBE > 0 {
            result.append((b, min(effectiveBE, 4)))
        }
        for entry in states {
            if let def = StateCatalog.definition(for: entry.stateID) {
                result.append((def, entry.level))
            }
        }
        return result
    }

    /// True if any active Zustand penalty is suppressible by the "Zustand ignorieren" Schip.
    /// Covers Furcht, Betäubung, Paralyse, Verwirrung, Entrückung, Schmerz, etc. Belastung is
    /// intentionally excluded — `SharedModifiers.encumbrance` does not honour schipIgnoreZustand.
    var hasIgnorableZustand: Bool {
        activeStates.contains { $0.def.kind == .zustand && $0.def.id != "belastung" }
    }

    /// Sum of all Zustand levels (GR: ≥8 ⇒ Handlungsunfähig). Statuses don't count.
    var totalZustandLevels: Int {
        activeStates.filter { $0.def.kind == .zustand }.reduce(0) { $0 + $1.level }
    }

    /// Derived statuses implied by active states (e.g. bewusstlos ⇒ handlungsunfaehig, liegend).
    var impliedStateIDs: Set<String> {
        var out = Set<String>()
        for (def, _) in activeStates { out.formUnion(def.implies) }
        return out
    }

    var isHandlungsunfaehig: Bool {
        if hasState("handlungsunfaehig") || impliedStateIDs.contains("handlungsunfaehig") { return true }
        if totalZustandLevels >= 8 { return true }
        // Any Zustand at its handlungsunfaehig level (most level IV).
        return activeStates.contains { entry in
            entry.def.handlungsunfaehigAtLevel.map { entry.level >= $0 } ?? false
        }
    }

    var isBewegungsunfaehig: Bool {
        if hasState("bewegungsunfaehig") || impliedStateIDs.contains("bewegungsunfaehig") { return true }
        return level(of: "paralyse") >= 4
    }

    // MARK: - Combat Ability Detection

    var hasAufmerksamkeit: Bool {
        combatSpecialAbilities.contains { $0.ruleId == "SA_40" }
    }

    var hasGolgaritenStil: Bool {
        combatSpecialAbilities.contains { $0.ruleId == "SA_661" }
    }

    var hasBerittenerKampf: Bool {
        combatSpecialAbilities.contains { $0.ruleId == "SA_43" }
    }

    /// Finte tier (0 if not owned). SA_48.
    var finteTier: Int {
        combatSpecialAbilities.first { $0.ruleId == "SA_48" }?.tier ?? 0
    }

    /// Wuchtschlag tier (0 if not owned). SA_67.
    var wuchtschlagTier: Int {
        combatSpecialAbilities.first { $0.ruleId == "SA_67" }?.tier ?? 0
    }

    /// True if hero has Vorstoß (SA_66).
    var hasVorstoss: Bool {
        combatSpecialAbilities.contains { $0.ruleId == "SA_66" }
    }

    /// True if hero has Schildspalter (SA_59).
    var hasSchildspalter: Bool {
        combatSpecialAbilities.contains { $0.ruleId == "SA_59" }
    }

    /// True if hero has Plänkler-Formation (SA_884).
    var hasPlaenklerFormation: Bool {
        combatSpecialAbilities.contains { $0.ruleId == "SA_884" }
    }

    /// Whether Golgariten-Stil conditions are met (mounted + Rabenschnabel + Großschild).
    func golgaritenActive(mounted: Bool) -> Bool {
        guard mounted, hasGolgaritenStil else { return false }
        let hasRabenschnabel = selectedWeapon?.name == "Rabenschnabel"
        let hasGrossschild = selectedShield?.name == "Großschild"
        return hasRabenschnabel && hasGrossschild
    }

    /// Horse GS for Sturmangriff damage.
    var mountGS: Int {
        pets.first?.speed ?? 0
    }

    /// Sturmangriff bonus damage: +2 + (horse GS / 2).
    var sturmangriffDamageBonus: Int {
        2 + (mountGS / 2)
    }

    /// True if hero has a mount (pet with initiative).
    var hasMount: Bool {
        pets.first.map { !$0.initiative.isEmpty } ?? false
    }

    /// Whether combat setup screen is needed.
    var needsCombatSetup: Bool {
        hasPlaenklerFormation || hasMount
    }

    /// Clears persisted combat session so re-entering starts fresh.
    func clearCombatSession() {
        activeCombatId = nil
        activeCombatRound = 0
        activeCombatInitiative = nil
        activeCombatPlaenkler = false
        activeCombatPlaenklerBonus = nil
        activeCombatMounted = false
    }
}

// MARK: - AppCommand

struct AppCommand: Identifiable {
    let id: UUID
    let name: String
    let subparameter: String?
    let input: CommandInput?
    let execute: (CommandInput.Result?) -> Void

    var displayName: String {
        subparameter.map { "\(name): \($0)" } ?? name
    }
}

enum CommandInput {
    case integerAmount(label: String, min: Int, max: Int?, initial: Int)

    enum Result {
        case integerAmount(Int)
    }
}

// MARK: - Hero Command Registry

extension Hero {
    var commandRegistry: [AppCommand] {
        var commands: [AppCommand] = []

        if let dv = derivedValues {
            if dv.lebensenergie.max > 0 {
                commands.append(AppCommand(
                    id: UUID(),
                    name: "lebensenergie",
                    subparameter: nil,
                    input: .integerAmount(
                        label: L("current"),
                        min: 0,
                        max: dv.lebensenergie.max,
                        initial: dv.lebensenergie.current
                    ),
                    execute: { result in
                        if case .integerAmount(let v) = result {
                            dv.lebensenergie.current = v
                        }
                    }
                ))
                commands.append(AppCommand(
                    id: UUID(),
                    name: "Regenerieren",
                    subparameter: nil,
                    input: nil,
                    execute: { _ in }
                ))
                commands.append(AppCommand(
                    id: UUID(),
                    name: "Heilung",
                    subparameter: nil,
                    input: nil,
                    execute: { _ in }
                ))
            }

            if dv.schicksalspunkte.max > 0 {
                commands.append(AppCommand(
                    id: UUID(),
                    name: "schicksalspunkte",
                    subparameter: nil,
                    input: .integerAmount(
                        label: L("current"),
                        min: 0,
                        max: dv.schicksalspunkte.max,
                        initial: dv.schicksalspunkte.current
                    ),
                    execute: { result in
                        if case .integerAmount(let v) = result {
                            dv.schicksalspunkte.current = v
                        }
                    }
                ))
            }

            if let ae = dv.astralenergie, ae.max > 0 {
                commands.append(AppCommand(
                    id: UUID(),
                    name: "astralenergie",
                    subparameter: nil,
                    input: .integerAmount(
                        label: L("current"),
                        min: 0,
                        max: ae.max,
                        initial: ae.current
                    ),
                    execute: { result in
                        if case .integerAmount(let v) = result {
                            dv.astralenergie?.current = v
                        }
                    }
                ))
            }

            if let ke = dv.karmaenergie, ke.max > 0 {
                commands.append(AppCommand(
                    id: UUID(),
                    name: "karmaenergie",
                    subparameter: nil,
                    input: .integerAmount(
                        label: L("current"),
                        min: 0,
                        max: ke.max,
                        initial: ke.current
                    ),
                    execute: { result in
                        if case .integerAmount(let v) = result {
                            dv.karmaenergie?.current = v
                        }
                    }
                ))
            }
        }

        if let exp = experience {
            commands.append(AppCommand(
                id: UUID(),
                name: "AP hinzufügen",
                subparameter: nil,
                input: .integerAmount(
                    label: "AP",
                    min: 1,
                    max: nil,
                    initial: 1
                ),
                execute: { result in
                    if case .integerAmount(let v) = result {
                        exp.totalAP += v
                        exp.availableAP += v
                    }
                }
            ))
        }

        for talent in talents {
            commands.append(AppCommand(
                id: UUID(),
                name: "Probe",
                subparameter: talent.name,
                input: nil,
                execute: { _ in }
            ))
        }

        if hasMount {
            commands.append(AppCommand(
                id: UUID(),
                name: "Reittier: Schaden",
                subparameter: nil,
                input: nil,
                execute: { _ in }
            ))
            commands.append(AppCommand(
                id: UUID(),
                name: "Reittier: Heilung",
                subparameter: nil,
                input: nil,
                execute: { _ in }
            ))
        }

        commands.append(AppCommand(
            id: UUID(),
            name: "Würfeln",
            subparameter: nil,
            input: nil,
            execute: { _ in }
        ))

        commands.append(AppCommand(
            id: UUID(),
            name: "Kampf",
            subparameter: nil,
            input: nil,
            execute: { _ in }
        ))

        commands.append(AppCommand(
            id: UUID(),
            name: "Einstellungen für \(name)",
            subparameter: nil,
            input: nil,
            execute: { _ in }
        ))

        return commands
    }
}
