import SwiftUI

extension Color {
    // Group divider colours (neo-brutalist, fixed — no dark mode adaptation)
    static let groupPersonalData = Color(red: 0xf5 / 255, green: 0xc4 / 255, blue: 0x00 / 255)
    static let groupTalents      = Color(red: 0x1d / 255, green: 0x4e / 255, blue: 0xd8 / 255)
    static let groupCombat       = Color(red: 0xdc / 255, green: 0x26 / 255, blue: 0x26 / 255)
    static let groupEquipment    = Color(red: 0x16 / 255, green: 0xa3 / 255, blue: 0x4a / 255)

    static let attrMU = Color(red: 0xc5 / 255, green: 0x47 / 255, blue: 0x47 / 255)
    static let attrKL = Color(red: 0xa8 / 255, green: 0x5b / 255, blue: 0xd4 / 255)
    static let attrIN = Color(red: 0x33 / 255, green: 0x9b / 255, blue: 0x5b / 255)
    static let attrCH = Color(red: 0x00 / 255, green: 0x00 / 255, blue: 0x00 / 255)
    static let attrFF = Color(red: 0xca / 255, green: 0xc1 / 255, blue: 0x58 / 255)
    static let attrGE = Color(red: 0x53 / 255, green: 0x98 / 255, blue: 0xbb / 255)
    static let attrKO = Color(red: 0xff / 255, green: 0xff / 255, blue: 0xff / 255)
    static let attrKK = Color(red: 0xc2 / 255, green: 0x8e / 255, blue: 0x46 / 255)

    static func attributeBackground(for label: String) -> Color {
        switch label {
        case "MU": .attrMU
        case "KL": .attrKL
        case "IN": .attrIN
        case "CH": .attrCH
        case "FF": .attrFF
        case "GE": .attrGE
        case "KO": .attrKO
        case "KK": .attrKK
        default:   .yellow
        }
    }

    static func attributeForeground(for label: String) -> Color {
        switch label {
        case "FF", "KO", "KK": .black
        default:                .white
        }
    }
}
