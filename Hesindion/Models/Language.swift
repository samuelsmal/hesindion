import Foundation
import SwiftData

@Model
final class Language {
    var name: String
    var level: String

    init(name: String, level: String) {
        self.name = name
        self.level = level
    }
}
