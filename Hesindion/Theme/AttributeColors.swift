import SwiftUI
import UIKit

extension Color {
    // Group divider colours (neo-brutalist, fixed — no dark mode adaptation)
    static let groupPersonalData = Color(red: 0xf5 / 255, green: 0xc4 / 255, blue: 0x00 / 255)
    static let groupTalents      = Color(red: 0x1d / 255, green: 0x4e / 255, blue: 0xd8 / 255)
    static let groupCombat       = Color(red: 0xdc / 255, green: 0x26 / 255, blue: 0x26 / 255)
    static let groupEquipment    = Color(red: 0x16 / 255, green: 0xa3 / 255, blue: 0x4a / 255)
    static let groupRulebook     = Color(red: 0x7c / 255, green: 0x3a / 255, blue: 0xed / 255)

    // Panel toggle button colours — warm trio, adaptive for dark mode
    static let panelNotes = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.85, green: 0.65, blue: 0.30, alpha: 1)   // warm amber
        : UIColor(red: 0.76, green: 0.55, blue: 0.08, alpha: 1)
    })
    static let panelLogs = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.30, green: 0.60, blue: 0.70, alpha: 1)   // muted teal
        : UIColor(red: 0.15, green: 0.45, blue: 0.55, alpha: 1)
    })
    static let panelRules = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.60, green: 0.40, blue: 0.78, alpha: 1)   // soft purple
        : UIColor(red: 0.45, green: 0.25, blue: 0.65, alpha: 1)
    })

    /// Adaptive border for neo-brutalist strokes — black in light mode, white in dark mode.
    static let dsaBorder = Color(UIColor.label)

    /// Dark accent background used for stat badges and INI boxes.
    static let dsaDark = Color(white: 0.18)

    static let attrMU = Color(red: 0xc5 / 255, green: 0x47 / 255, blue: 0x47 / 255)
    static let attrKL = Color(red: 0xa8 / 255, green: 0x5b / 255, blue: 0xd4 / 255)
    static let attrIN = Color(red: 0x33 / 255, green: 0x9b / 255, blue: 0x5b / 255)
    static let attrCH = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.22, alpha: 1) : .black })
    static let attrFF = Color(red: 0xca / 255, green: 0xc1 / 255, blue: 0x58 / 255)
    static let attrGE = Color(red: 0x53 / 255, green: 0x98 / 255, blue: 0xbb / 255)
    static let attrKO = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.82, alpha: 1) : .white })
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

    /// Returns a lightened version of the color suitable for text on dark backgrounds.
    /// Ensures minimum brightness so dark section colors remain visible in dark mode.
    func adaptedForDarkBackground() -> Color {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let minBrightness: CGFloat = 0.55
        let adjustedBrightness = max(b, minBrightness)
        let adjustedSaturation = min(s, 0.8) // slightly desaturate for readability
        return Color(hue: Double(h), saturation: Double(adjustedSaturation), brightness: Double(adjustedBrightness))
    }
}
