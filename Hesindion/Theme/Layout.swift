import SwiftUI

enum DSALayout {
    /// Horizontal padding for sections and content areas.
    static let horizontalPadding: CGFloat = 16
    /// Inner content padding (rows, cells).
    static let contentPadding: CGFloat = 12
    /// Vertical padding for headers (combat, modal, section).
    static let headerVerticalPadding: CGFloat = 14
    /// The one border width. Emphasis is carried by the shadow, not by a heavier
    /// stroke, so there is a single weight — ADR-0008.
    static let border: CGFloat = 2

    /// The signature hard offset shadow: offset `(4, 4)`, radius 0, colour =
    /// `dsaBorder`. Pressed elements move by exactly this amount so they land
    /// flush in the space the shadow occupied (ADR-0008).
    static let shadowOffset: CGFloat = 4

    /// Divider between rows *inside* a `.dsaBox` — the replacement for the retired
    /// 1pt border tier (ADR-0007). A divider, not a border: it never surrounds.
    static let divider: CGFloat = 1
    static let dividerOpacity: Double = 0.15

    /// Maximum content width on iPad.
    static let iPadMaxContentWidth: CGFloat = 700
    /// Proportional content fraction on iPad (1.0 - 2×0.06).
    static let iPadProportionalFraction: CGFloat = 0.88
}
