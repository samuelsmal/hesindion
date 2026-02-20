import Foundation
import SwiftData

@Model
final class Attributes {
    var mu: Int
    var kl: Int
    var inValue: Int
    var ch: Int
    var ff: Int
    var ge: Int
    var ko: Int
    var kk: Int

    init(mu: Int, kl: Int, inValue: Int, ch: Int, ff: Int, ge: Int, ko: Int, kk: Int) {
        self.mu = mu
        self.kl = kl
        self.inValue = inValue
        self.ch = ch
        self.ff = ff
        self.ge = ge
        self.ko = ko
        self.kk = kk
    }
}
