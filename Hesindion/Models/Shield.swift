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
