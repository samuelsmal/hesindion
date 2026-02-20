import Foundation

// Top-level hero document
struct HeroDTO: Decodable {
    let personalData: PersonalDataDTO
    let experience: ExperienceDTO
    let attributes: AttributesDTO
    let derivedValues: DerivedValuesDTO
    let advantages: [String]
    let disadvantages: [String]
    let specialAbilities: SpecialAbilitiesDTO
    let languages: [String: String]
    let scripts: [String]
    let talents: TalentsContainerDTO
    let combatTechniques: [CombatTechniqueDTO]
    let meleeWeapons: [MeleeWeaponDTO]
    let armor: ArmorDTO
    let shield: ShieldDTO?
    let equipment: [EquipmentItemDTO]
    let money: MoneyDTO
    let carryingCapacity: Int
    let mount: MountDTO?
}

struct PersonalDataDTO: Decodable {
    let name: String
    let family: String
    let birthplace: String
    let birthdate: String
    let age: Int
    let gender: String
    let species: String
    let height: Int
    let weight: Int
    let hairColor: String
    let eyeColor: String
    let culture: String
    let socialStatus: String
    let profession: String
    let title: String
    let characteristics: String
}

struct ExperienceDTO: Decodable {
    let level: String
    let totalAP: Int
    let availableAP: Int
    let spentAP: Int
}

struct AttributesDTO: Decodable {
    let MU: Int
    let KL: Int
    let IN: Int
    let CH: Int
    let FF: Int
    let GE: Int
    let KO: Int
    let KK: Int
}

// Derived value shapes — reuse the model value types for decoding
struct DerivedValuesDTO: Decodable {
    let lebensenergie: LifeEnergyValue
    let astralenergie: LifeEnergyValue?
    let karmaenergie: LifeEnergyValue?
    let seelenkraft: ResourceValue
    let zähigkeit: ResourceValue
    let ausweichen: ComputedValue
    let initiative: ComputedValue
    let geschwindigkeit: ResourceValue
    let wundschwelle: ComputedValue
    let schicksalspunkte: ComputedValue

    enum CodingKeys: String, CodingKey {
        case lebensenergie
        case astralenergie
        case karmaenergie
        case seelenkraft
        case zähigkeit = "zähigkeit"
        case ausweichen
        case initiative
        case geschwindigkeit
        case wundschwelle
        case schicksalspunkte
    }
}

struct SpecialAbilitiesDTO: Decodable {
    let general: [String]
    let combat: [String]
}

struct TalentDTO: Decodable {
    let name: String
    let value: Int
}

struct TalentsContainerDTO: Decodable {
    let körpertalente: [TalentDTO]
    let gesellschaftstalente: [TalentDTO]
    let naturtalente: [TalentDTO]
    let wissenstalente: [TalentDTO]
    let handwerkstalente: [TalentDTO]

    enum CodingKeys: String, CodingKey {
        case körpertalente = "körpertalente"
        case gesellschaftstalente
        case naturtalente
        case wissenstalente
        case handwerkstalente
    }
}

struct CombatTechniqueDTO: Decodable {
    let name: String
    let value: Int
    let at: Int
    let pa: Int?
}

struct MeleeWeaponDTO: Decodable {
    let name: String
    let technique: String
    let damage: String
    let at: Int
    let pa: Int
    let reach: String
    let weight: Double
}

struct ArmorDTO: Decodable {
    let name: String
    let protectionValue: Int
    let armorRating: Int
    let encumbrance: Int
    let weight: Double
}

struct ShieldDTO: Decodable {
    let name: String
    let structure: Int
    let breakingFactor: Int
    let atMod: Int
    let paMod: Int
    let weight: Double
}

struct EquipmentItemDTO: Decodable {
    let name: String
    let value: Int
    let weight: Double
}

struct MoneyDTO: Decodable {
    let dukaten: Int
    let silbertaler: Int
    let heller: Int
    let kreuzer: Int
}

struct MountDTO: Decodable {
    let name: String
    let size: Double
    let mountType: String
    let attributes: MountAttributes
    let lifeEnergy: Int
    let initiative: String
    let speed: Int
    let attacks: [MountAttack]
    let talents: [MountTalent]
    let specialAbilities: [String]

    enum CodingKeys: String, CodingKey {
        case name, size
        case mountType = "type"
        case attributes, lifeEnergy, initiative, speed, attacks, talents, specialAbilities
    }
}
