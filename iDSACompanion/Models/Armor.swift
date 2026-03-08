import Foundation
import SwiftData

@Model
final class Armor {
    var name: String
    var protectionValue: Int
    var encumbrance: Int
    var weight: Double

    init(name: String, protectionValue: Int, encumbrance: Int, weight: Double) {
        self.name = name
        self.protectionValue = protectionValue
        self.encumbrance = encumbrance
        self.weight = weight
    }
}
