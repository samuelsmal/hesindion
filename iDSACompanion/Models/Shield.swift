import Foundation
import SwiftData

@Model
final class Shield {
    var name: String
    var structure: Int
    var breakingFactor: Int
    var at: Int
    var pa: Int
    var weight: Double

    init(name: String, structure: Int, breakingFactor: Int, at: Int, pa: Int, weight: Double) {
        self.name = name
        self.structure = structure
        self.breakingFactor = breakingFactor
        self.at = at
        self.pa = pa
        self.weight = weight
    }
}
