import Foundation
import SwiftData

@Model
final class MeleeWeapon {
    var name: String
    var combatTechniqueId: String
    var damage: String
    var at: Int
    var pa: Int
    var reach: String
    var weight: Double

    init(name: String, combatTechniqueId: String, damage: String, at: Int, pa: Int, reach: String, weight: Double) {
        self.name = name
        self.combatTechniqueId = combatTechniqueId
        self.damage = damage
        self.at = at
        self.pa = pa
        self.reach = reach
        self.weight = weight
    }
}
