import Foundation
import SwiftData

@Model
final class HeroSpell {
    var ruleId: String
    var name: String
    var value: Int

    init(ruleId: String, name: String, value: Int) {
        self.ruleId = ruleId
        self.name = name
        self.value = value
    }
}
