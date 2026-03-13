import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SchemaV1.Hero.self,
            PersonalData.self,
            Experience.self,
            Attributes.self,
            DerivedValues.self,
            Talent.self,
            CombatTechnique.self,
            MeleeWeapon.self,
            RangedWeapon.self,
            Armor.self,
            Shield.self,
            EquipmentItem.self,
            Money.self,
            Pet.self,
            Language.self,
            HeroSpell.self,
        ]
    }

    /// V1 Hero: identical to current Hero but without the `notes` property.
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

        var selectedWeaponName: String?
        var selectedShieldName: String?
        var selectedOffHandName: String?

        init(name: String) {
            self.name = name
            self.advantages = []
            self.disadvantages = []
            self.generalSpecialAbilities = []
            self.combatSpecialAbilities = []
            self.cantrips = []
            self.blessings = []
            self.scripts = []
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
    }
}
