import Foundation
import SwiftData

@Model
final class EquipmentItem {
    var name: String
    var value: Int
    var weight: Double

    init(name: String, value: Int, weight: Double) {
        self.name = name
        self.value = value
        self.weight = weight
    }
}
