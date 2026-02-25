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
    let languages: [LanguageDTO]
    let scripts: [String]
    let talents: TalentsContainerDTO
    let combatTechniques: [CombatTechniqueDTO]
    let equipment: [EquipmentItemDTO]
    let money: MoneyDTO
    let mount: MountDTO?
}

struct LanguageDTO: Decodable {
    let language: String
    let level: String
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
    let astralenergie: MutableResourceValue?
    let karmaenergie: MutableResourceValue?
    let seelenkraft: ComputedValue
    let zähigkeit: ComputedValue
    let ausweichen: ComputedValue
    let initiative: ComputedValue
    let geschwindigkeit: ComputedValue
    let wundschwelle: ComputedValue
    let schicksalspunkte: MutableResourceValue

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

struct EquipmentItemDTO: Decodable {
    let name: String
    let type: String
    let value: Int?
    let weight: Double?
    // Weapon / shield fields
    let technique: String?
    let damage: String?
    let at: Int?
    let pa: Int?
    let reach: String?
    // Armor fields
    let protectionValue: Int?
    let armorRating: Int?
    let encumbrance: Int?
}

struct MoneyDTO: Decodable {
    let dukaten: Int
    let silbertaler: Int
    let heller: Int
    let kreuzer: Int
}

struct MountAttributesDTO: Decodable {
    let mu: Int
    let kl: Int
    let inValue: Int
    let ch: Int
    let ff: Int
    let ge: Int
    let ko: Int
    let kk: Int

    enum CodingKeys: String, CodingKey {
        case mu = "MU"
        case kl = "KL"
        case inValue = "IN"
        case ch = "CH"
        case ff = "FF"
        case ge = "GE"
        case ko = "KO"
        case kk = "KK"
    }
}

struct MountDTO: Decodable {
    let name: String
    let size: Double
    let mountType: String
    let attributes: MountAttributesDTO
    let lifeEnergy: Int
    let initiative: Int
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
