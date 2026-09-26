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

/// One entry of a companion's build, as `scripts/companions/amend_export.py`
/// writes it (docs/plans/2026-09-24-companion-data-design.md §4).
struct PetPurchase: Codable, Hashable {
    var kind: String
    var name: String?
    var target: String?
    var ap: Int
    var from: Int?
    var to: Int?
    var count: Int?
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

    // Companion data from the export's `hesindion` block. Optolith has no place
    // for it; nil / empty when the export was not amended.
    var defense: Int?
    var armor: Int?
    var encumbrance: Int?
    var advantages: [String] = []
    var abilities: [String] = []
    var training: [String] = []
    var tricks: [String] = []
    var purchases: [PetPurchase] = []
    var apTotal: Int?
    var apSpent: Int?

    var hasCompanionData: Bool { apTotal != nil }

    /// The block's ability list when there is one, the free-text `skills` otherwise.
    var hasMightyBlow: Bool {
        abilities.contains("Mächtiger Schlag") || specialSkills.contains("Mächtiger Schlag")
    }

    /// Re-import without the block, and the player chose to keep the last one:
    /// only what the block adds comes over, the export's own fields stay new.
    func adoptCompanionData(from old: Pet) {
        defense = old.defense
        armor = old.armor
        encumbrance = old.encumbrance
        advantages = old.advantages
        abilities = old.abilities
        training = old.training
        tricks = old.tricks
        purchases = old.purchases
        apTotal = old.apTotal
        apSpent = old.apSpent
        attacks = old.attacks
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
