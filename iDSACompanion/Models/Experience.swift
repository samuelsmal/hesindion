import Foundation
import SwiftData

@Model
final class Experience {
    var level: String
    var totalAP: Int
    var availableAP: Int
    var spentAP: Int

    init(level: String, totalAP: Int, availableAP: Int, spentAP: Int) {
        self.level = level
        self.totalAP = totalAP
        self.availableAP = availableAP
        self.spentAP = spentAP
    }
}
