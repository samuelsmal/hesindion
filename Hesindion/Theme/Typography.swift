import SwiftUI

/// The type scale (ADR-0007): **exactly two weights** — 700 for headings and
/// emphasis, 500 for body — matching the neobrutalism reference.
///
/// Every face keeps a Dynamic Type text style as its base, so text still scales
/// with the user's accessibility settings. That was the one thing the old inline
/// declarations got right (`docs/neobrutalism-ui-audit.md`, §5) and it survives
/// the move into tokens.
///
/// These are the *only* sanctioned way to set a weight. `.black` (900) and
/// `.semibold` (600) are retired.
enum DSAType {
    static let heading: Font.Weight = .bold      // 700
    static let body: Font.Weight = .medium       // 500
}

extension Font {

    /// Headings and emphasis — 700. Pass the Dynamic Type style that fits the
    /// level: `.largeTitle`, `.title`, `.title3`, `.headline`, or `.body`/`.caption`
    /// when body-sized text needs emphasis.
    static func dsaHeading(_ style: Font.TextStyle = .headline) -> Font {
        .system(style, weight: DSAType.heading)
    }

    /// Body copy — 500.
    static func dsaBody(_ style: Font.TextStyle = .body) -> Font {
        .system(style, weight: DSAType.body)
    }

    /// Monospaced numerics — stat blocks, dice results, modifier breakdowns.
    /// `emphasis: true` gives the 700 face for totals and headline values.
    static func dsaMono(_ style: Font.TextStyle = .caption, emphasis: Bool = true) -> Font {
        .system(style, design: .monospaced, weight: emphasis ? DSAType.heading : DSAType.body)
    }
}
