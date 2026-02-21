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
    var carryingCapacity: Int

    @Relationship(deleteRule: .cascade) var personalData: PersonalData?
    @Relationship(deleteRule: .cascade) var experience: Experience?
    @Relationship(deleteRule: .cascade) var attributes: Attributes?
    @Relationship(deleteRule: .cascade) var derivedValues: DerivedValues?
    @Relationship(deleteRule: .cascade) var talents: [Talent]
    @Relationship(deleteRule: .cascade) var combatTechniques: [CombatTechnique]
    @Relationship(deleteRule: .cascade) var meleeWeapons: [MeleeWeapon]
    @Relationship(deleteRule: .cascade) var armor: Armor?
    @Relationship(deleteRule: .cascade) var shield: Shield?
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
        scripts: [String] = [],
        carryingCapacity: Int = 0
    ) {
        self.name = name
        self.advantages = advantages
        self.disadvantages = disadvantages
        self.generalSpecialAbilities = generalSpecialAbilities
        self.combatSpecialAbilities = combatSpecialAbilities
        self.scripts = scripts
        self.carryingCapacity = carryingCapacity
        self.talents = []
        self.combatTechniques = []
        self.meleeWeapons = []
        self.equipment = []
        self.languages = []
    }

    var totalEquipmentWeight: Double {
        let equipmentWeight = equipment.reduce(0.0) { $0 + $1.weight }
        let weaponWeight    = meleeWeapons.reduce(0.0) { $0 + $1.weight }
        let armorWeight     = armor?.weight ?? 0.0
        let shieldWeight    = shield?.weight ?? 0.0
        return equipmentWeight + weaponWeight + armorWeight + shieldWeight
    }

    var carryingThreshold: Double {
        let mountBonus = Double((mount?.attributes.kk ?? 0) * 2)
        return Double(carryingCapacity) + mountBonus
    }

    var isOverloaded: Bool {
        totalEquipmentWeight > carryingThreshold
    }
}
