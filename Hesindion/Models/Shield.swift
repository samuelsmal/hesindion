import Foundation
import SwiftData

@Model
final class Shield {
    var name: String
    var damage: String
    var at: Int
    var pa: Int
    var paModifier: Int
    var note: String
    var reach: String
    var structurePoints: Int
    var weight: Double
    /// Optolith's inventory template ("ITEMTPL_19"), which names do not identify:
    /// two Rabenschnäbel share one. Nil for heroes imported before it was kept;
    /// `Hero.equipmentEntry(forLoadoutNamed:)` then falls back to the name.
    var templateId: String? = nil

    init(name: String, damage: String, at: Int, pa: Int, paModifier: Int = 0, note: String = "", reach: String, structurePoints: Int, weight: Double) {
        self.name = name
        self.damage = damage
        self.at = at
        self.pa = pa
        self.paModifier = paModifier
        self.note = note
        self.reach = reach
        self.structurePoints = structurePoints
        self.weight = weight
    }
}
