import Foundation
import SwiftData

// MARK: - Value types (Codable, shared with DTO layer)

struct MountAttack: Codable {
    var name: String
    var at: Int
    var damage: String
    var reach: String
}

struct MountTalent: Codable {
    var name: String
    var value: Int
}

struct MountAttributes: Codable {
    var mu: Int
    var kl: Int
    var inValue: Int
    var ch: Int
    var ff: Int
    var ge: Int
    var ko: Int
    var kk: Int
}

// MARK: - Model

@Model
final class Mount {
    var name: String
    var size: Double
    var mountType: String
    var attributes: MountAttributes
    var lifeEnergy: Int
    var initiative: String
    var speed: Int
    var attacks: [MountAttack]
    var talents: [MountTalent]
    var specialAbilities: [String]

    /// Derived from KK attribute per DSA rules.
    var carryingCapacity: Int { attributes.kk * 2 }

    init(
        name: String,
        size: Double,
        mountType: String,
        attributes: MountAttributes,
        lifeEnergy: Int,
        initiative: String,
        speed: Int,
        attacks: [MountAttack],
        talents: [MountTalent],
        specialAbilities: [String]
    ) {
        self.name = name
        self.size = size
        self.mountType = mountType
        self.attributes = attributes
        self.lifeEnergy = lifeEnergy
        self.initiative = initiative
        self.speed = speed
        self.attacks = attacks
        self.talents = talents
        self.specialAbilities = specialAbilities
    }
}
