import Foundation
import SwiftData

@Model
final class Armor {
    var name: String
    var protectionValue: Int
    var encumbrance: Int
    var weight: Double
    var isEquipped: Bool = false
    var iniModifier: Int = 0
    var gsModifier: Int = 0

    init(
        name: String,
        protectionValue: Int,
        encumbrance: Int,
        weight: Double,
        isEquipped: Bool = false,
        iniModifier: Int = 0,
        gsModifier: Int = 0
    ) {
        self.name = name
        self.protectionValue = protectionValue
        self.encumbrance = encumbrance
        self.weight = weight
        self.isEquipped = isEquipped
        self.iniModifier = iniModifier
        self.gsModifier = gsModifier
    }
}
