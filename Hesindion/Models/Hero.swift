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

    // MARK: - Loadout persistence

    var selectedWeaponName: String?
    var selectedShieldName: String?

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

    var selectedWeapon: MeleeWeapon? {
        guard let name = selectedWeaponName else { return nil }
        return meleeWeapons.first { $0.name == name }
    }

    var selectedShield: Shield? {
        guard let name = selectedShieldName else { return nil }
        return shields.first { $0.name == name }
    }

    /// Passive shield PA bonus applied to main weapon parade.
    var passiveShieldPABonus: Int {
        selectedShield?.paModifier ?? 0
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
                        label: "Aktuell",
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
            }

            if dv.schicksalspunkte.max > 0 {
                commands.append(AppCommand(
                    id: UUID(),
                    name: "schicksalspunkte",
                    subparameter: nil,
                    input: .integerAmount(
                        label: "Aktuell",
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
                        label: "Aktuell",
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
                        label: "Aktuell",
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

        commands.append(AppCommand(
            id: UUID(),
            name: "Kampf",
            subparameter: nil,
            input: nil,
            execute: { _ in }
        ))

        return commands
    }
}
