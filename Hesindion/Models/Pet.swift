import Foundation
import SwiftData

struct PetAttributes: Codable, Hashable {
    var mu: Int
    var kl: Int
    var inValue: Int
    var ch: Int
    var ff: Int
    var ge: Int
    var ko: Int
    var kk: Int
}

struct PetAttack: Codable, Hashable {
    var name: String
    var at: Int
    var damage: String
    var reach: String
}

@Model
final class Pet {
    var petId: String
    var name: String
    var avatar: Data?
    var size: Double
    var type: String
    var attributes: PetAttributes
    var lifeEnergy: Int
    var currentLifeEnergy: Int = 0
    var spirit: Int
    var toughness: Int
    var initiative: String
    var speed: Int
    var attack: String
    var damage: String
    var reach: String
    var actions: Int
    var talents: String
    var skills: String
    var notes: String
    var attacks: [PetAttack] = []
    var specialSkills: String = ""

    var carryingCapacity: Int { attributes.kk * 2 }

    init(
        petId: String,
        name: String,
        avatar: Data? = nil,
        size: Double,
        type: String,
        attributes: PetAttributes,
        lifeEnergy: Int,
        currentLifeEnergy: Int? = nil,
        spirit: Int,
        toughness: Int,
        initiative: String,
        speed: Int,
        attack: String,
        damage: String,
        reach: String,
        actions: Int,
        talents: String,
        skills: String,
        notes: String,
        attacks: [PetAttack] = [],
        specialSkills: String = ""
    ) {
        self.petId = petId
        self.name = name
        self.avatar = avatar
        self.size = size
        self.type = type
        self.attributes = attributes
        self.lifeEnergy = lifeEnergy
        self.currentLifeEnergy = currentLifeEnergy ?? lifeEnergy
        self.spirit = spirit
        self.toughness = toughness
        self.initiative = initiative
        self.speed = speed
        self.attack = attack
        self.damage = damage
        self.reach = reach
        self.actions = actions
        self.talents = talents
        self.skills = skills
        self.notes = notes
        self.attacks = attacks
        self.specialSkills = specialSkills
    }
}
