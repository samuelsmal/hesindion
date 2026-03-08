import Foundation
import SwiftData

@Model
final class RangedWeapon {
    var name: String
    var combatTechniqueId: String
    var damage: String
    var at: Int
    var range: String
    var weight: Double

    init(name: String, combatTechniqueId: String, damage: String, at: Int, range: String, weight: Double) {
        self.name = name
        self.combatTechniqueId = combatTechniqueId
        self.damage = damage
        self.at = at
        self.range = range
        self.weight = weight
    }
}
