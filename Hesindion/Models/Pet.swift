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

    // Companion data from Optolith's pet fields (issue #49, PetTextFormat): PA is VW, RS is
    // RS, the Sonderfertigkeiten and Notizen labels give the rest. nil / empty when absent.
    var defense: Int?
    var armor: Int?
    var encumbrance: Int?
    var advantages: [String] = []
    var disadvantages: [String] = []
    var abilities: [String] = []
    var training: [String] = []
    var tricks: [String] = []
    var apTotal: Int?
    var apSpent: Int?
    /// What the last import could not read; a clean re-import clears it.
    var importProblems: [PetImportProblem] = []

    /// An ability item counts by its name, without its note.
    var hasMightyBlow: Bool {
        abilities.contains { PetTextFormat.itemName($0) == "Mächtiger Schlag" }
    }

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
        attacks: [PetAttack] = []
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
    }
}
