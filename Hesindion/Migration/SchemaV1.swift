import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Hero.self,
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
}
