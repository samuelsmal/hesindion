import Foundation
import SwiftData

@Model
final class Talent {
    var name: String
    var value: Int
    var category: String

    init(name: String, value: Int, category: String) {
        self.name = name
        self.value = value
        self.category = category
    }
}
