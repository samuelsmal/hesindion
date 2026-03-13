import SwiftUI

enum DSALayout {
    /// Horizontal padding for sections and content areas.
    static let horizontalPadding: CGFloat = 16
    /// Inner content padding (rows, cells).
    static let contentPadding: CGFloat = 12
    /// Vertical padding for headers (combat, modal, section).
    static let headerVerticalPadding: CGFloat = 14
    /// Primary border width — highest emphasis elements.
    static let primaryBorder: CGFloat = 3
    /// Secondary border width — standard elements.
    static let secondaryBorder: CGFloat = 2
    /// Tertiary border width — compact/detail elements.
    static let tertiaryBorder: CGFloat = 1
    /// Maximum content width on iPad.
    static let iPadMaxContentWidth: CGFloat = 700
    /// Proportional content fraction on iPad (1.0 - 2×0.06).
    static let iPadProportionalFraction: CGFloat = 0.88
}
