import Foundation
import SwiftData

@Model
final class Hero {
    var name: String
    var advantages: [String]
    var disadvantages: [String]
    var generalSpecialAbilities: [String]
    var combatSpecialAbilities: [String]
    var scripts: [String]

    @Relationship(deleteRule: .cascade) var personalData: PersonalData?
    @Relationship(deleteRule: .cascade) var experience: Experience?
    @Relationship(deleteRule: .cascade) var attributes: Attributes?
    @Relationship(deleteRule: .cascade) var derivedValues: DerivedValues?
    @Relationship(deleteRule: .cascade) var talents: [Talent]
    @Relationship(deleteRule: .cascade) var combatTechniques: [CombatTechnique]
    @Relationship(deleteRule: .cascade) var meleeWeapons: [MeleeWeapon]
    @Relationship(deleteRule: .cascade) var armors: [Armor]
    @Relationship(deleteRule: .cascade) var shields: [Shield]
    @Relationship(deleteRule: .cascade) var equipment: [EquipmentItem]
    @Relationship(deleteRule: .cascade) var money: Money?
    @Relationship(deleteRule: .cascade) var mount: Mount?
    @Relationship(deleteRule: .cascade) var languages: [Language]

    init(
        name: String,
        advantages: [String] = [],
        disadvantages: [String] = [],
        generalSpecialAbilities: [String] = [],
        combatSpecialAbilities: [String] = [],
        scripts: [String] = []
    ) {
        self.name = name
        self.advantages = advantages
        self.disadvantages = disadvantages
        self.generalSpecialAbilities = generalSpecialAbilities
        self.combatSpecialAbilities = combatSpecialAbilities
        self.scripts = scripts
        self.talents = []
        self.combatTechniques = []
        self.meleeWeapons = []
        self.armors = []
        self.shields = []
        self.equipment = []
        self.languages = []
    }

    var totalEquipmentWeight: Double {
        let equipmentWeight = equipment.reduce(0.0) { $0 + $1.weight }
        let weaponWeight    = meleeWeapons.reduce(0.0) { $0 + $1.weight }
        let armorWeight     = armors.reduce(0.0) { $0 + $1.weight }
        let shieldWeight    = shields.reduce(0.0) { $0 + $1.weight }
        return equipmentWeight + weaponWeight + armorWeight + shieldWeight
    }

    /// Derived from KK attribute per DSA rules.
    var carryingCapacity: Int { (attributes?.kk ?? 0) * 2 }

    var totalCarryingCapacity: Int {
        carryingCapacity + (mount?.carryingCapacity ?? 0)
    }

    var carryingThreshold: Double {
        Double(totalCarryingCapacity)
    }

    var isOverloaded: Bool {
        totalEquipmentWeight > carryingThreshold
    }

    /// +1 if the hero has "Verbesserte Regeneration (Lebensenergie)", +2 if it's level II.
    var verbessertRegenerationLEBonus: Int {
        guard let adv = advantages.first(where: { $0.contains("Verbesserte Regeneration (Lebensenergie)") }) else { return 0 }
        return adv.contains("II") ? 2 : 1
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
