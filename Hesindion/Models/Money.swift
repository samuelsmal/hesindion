import Foundation
import SwiftData

@Model
final class Money {
    var dukaten: Int
    var silbertaler: Int
    var heller: Int
    var kreuzer: Int

    init(dukaten: Int, silbertaler: Int, heller: Int, kreuzer: Int) {
        self.dukaten = dukaten
        self.silbertaler = silbertaler
        self.heller = heller
        self.kreuzer = kreuzer
    }
}
