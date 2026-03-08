import Foundation
import SwiftData

@Model
final class Talent {
    var ruleId: String
    var name: String
    var value: Int
    var category: String

    init(ruleId: String, name: String, value: Int, category: String) {
        self.ruleId = ruleId
        self.name = name
        self.value = value
        self.category = category
    }
}
