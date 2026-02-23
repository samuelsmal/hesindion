import Foundation
import SwiftData

@Model
final class CombatTechnique {
    var name: String
    var value: Int
    var at: Int
    var pa: Int

    init(name: String, value: Int, at: Int, pa: Int) {
        self.name = name
        self.value = value
        self.at = at
        self.pa = pa
    }
}
