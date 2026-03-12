import Foundation
import SwiftData

@Model
final class CombatTechnique {
    var ruleId: String
    var name: String
    var value: Int
    var at: Int
    var pa: Int

    init(ruleId: String, name: String, value: Int, at: Int, pa: Int) {
        self.ruleId = ruleId
        self.name = name
        self.value = value
        self.at = at
        self.pa = pa
    }
}
