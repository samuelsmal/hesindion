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

    func value(for attrId: String) -> Int {
        switch attrId {
        case "ATTR_1": return mu
        case "ATTR_2": return kl
        case "ATTR_3": return inValue
        case "ATTR_4": return ch
        case "ATTR_5": return ff
        case "ATTR_6": return ge
        case "ATTR_7": return ko
        case "ATTR_8": return kk
        default: return 8
        }
    }
}
