import Foundation
import SwiftData

@Model
final class Shield {
    var name: String
    var structure: Int
    var breakingFactor: Int
    var atMod: Int
    var paMod: Int
    var weight: Double

    init(name: String, structure: Int, breakingFactor: Int, atMod: Int, paMod: Int, weight: Double) {
        self.name = name
        self.structure = structure
        self.breakingFactor = breakingFactor
        self.atMod = atMod
        self.paMod = paMod
        self.weight = weight
    }
}
