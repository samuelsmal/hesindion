import Foundation
import SwiftData

@Model
final class Armor {
    var name: String
    var protectionValue: Int
    var armorRating: Int
    var encumbrance: Int
    var weight: Double

    init(name: String, protectionValue: Int, armorRating: Int, encumbrance: Int, weight: Double) {
        self.name = name
        self.protectionValue = protectionValue
        self.armorRating = armorRating
        self.encumbrance = encumbrance
        self.weight = weight
    }
}
