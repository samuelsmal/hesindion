import Foundation
import SwiftData

@Model
final class Shield {
    var name: String
    var damage: String
    var at: Int
    var pa: Int
    var reach: String
    var structurePoints: Int
    var weight: Double

    init(name: String, damage: String, at: Int, pa: Int, reach: String, structurePoints: Int, weight: Double) {
        self.name = name
        self.damage = damage
        self.at = at
        self.pa = pa
        self.reach = reach
        self.structurePoints = structurePoints
        self.weight = weight
    }
}
