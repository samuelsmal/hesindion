import SwiftUI

/// The neo-brutalist surface: a flat fill, a hard 2pt stroke, square corners and —
/// for surfaces that carry emphasis — the signature hard offset shadow
/// (ADR-0008: offset 4, **radius 0**, colour = the border colour).
///
/// This exists because the idiom it replaces was written out longhand 202 times
/// (`docs/neobrutalism-ui-audit.md`, finding S1). Geometry now lives here and only
/// here: call sites choose a *role*, never a `lineWidth`.
enum DSABoxRole {
    /// A surface that sits above its background: cards, modals, buttons, section
    /// containers. Carries the shadow.
    case raised
    /// A surface flush with its background: rows, cells, inline badges, anything
    /// inside a `raised` container. No shadow.
    ///
    /// Shadows draw outside the view bounds without reserving layout space, so a
    /// shadow on every element of a dense stack overlaps its neighbour. Group-level
    /// surfaces carry it; their contents do not (ADR-0008).
    case flush
}

struct DSABoxModifier: ViewModifier {
    let role: DSABoxRole
    let fill: Color?
    /// Defaults to `dsaBorder`; pass an accent to mark selection.
    let stroke: Color?
    /// Set by `DSAPressStyle` while the element is held down.
    let isPressed: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var strokeColor: Color { stroke ?? .dsaBorder }

    /// The reference uses `var(--border)` for the shadow too, and `dsaBorder` is
    /// already brightness-adaptive — black on light, white on the app's near-black
    /// dark surface, where a black shadow would be invisible.
    private var shadowColor: Color {
        guard role == .raised, !isPressed else { return .clear }
        return .dsaBorder
    }

    /// Pressed elements move by the shadow's own offset, so they land flush in the
    /// space the shadow occupied.
    private var pressOffset: CGFloat {
        role == .raised && isPressed ? DSALayout.shadowOffset : 0
    }

    func body(content: Content) -> some View {
        content
            // `fill == nil` means "leave the caller's own .background() alone" —
            // most call sites already set one, so imposing a fill here would
            // silently override them.
            .background(fill)
            .overlay(Rectangle().stroke(strokeColor, lineWidth: DSALayout.border))
            .shadow(
                color: shadowColor,
                radius: 0,
                x: shadowColor == .clear ? 0 : DSALayout.shadowOffset,
                y: shadowColor == .clear ? 0 : DSALayout.shadowOffset
            )
            .offset(x: pressOffset, y: pressOffset)
            .animation(DSAAnimation.press, value: isPressed)
    }
}

extension View {
    /// The neo-brutalist surface. See `DSABoxRole`.
    ///
    ///     Text("Wuchtschlag").padding().dsaBox(.raised)
    ///     Text("+2").padding().dsaBox(.flush, stroke: .groupCombat)
    func dsaBox(
        _ role: DSABoxRole = .raised,
        fill: Color? = nil,
        stroke: Color? = nil,
        isPressed: Bool = false
    ) -> some View {
        modifier(DSABoxModifier(role: role, fill: fill, stroke: stroke, isPressed: isPressed))
    }

    /// A divider between rows inside a single `.dsaBox` — the replacement for the
    /// retired 1pt border tier (ADR-0007). Rows no longer stroke their own
    /// rectangle, so adjacent borders can no longer double up.
    func dsaRowDivider() -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.dsaBorder.opacity(DSALayout.dividerOpacity))
                .frame(height: DSALayout.divider)
        }
    }
}

// MARK: - Press

/// The reference press interaction (ADR-0008): the element moves into its own
/// shadow and the shadow disappears, so it lands flush.
///
/// Replaces `.buttonStyle(.plain)`, which removed SwiftUI's press treatment
/// without putting anything back — 192 of the app's 211 buttons were inert
/// (audit finding S3, spec 010).
struct DSAPressStyle: ButtonStyle {
    var role: DSABoxRole = .raised
    var fill: Color?
    var stroke: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsaBox(role, fill: fill, stroke: stroke, isPressed: configuration.isPressed)
    }
}

/// For pressable items that already draw their own surface and only need the
/// press *motion* — no second border or fill.
struct DSAPressMotionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let offset = configuration.isPressed ? DSALayout.shadowOffset : 0
        return configuration.label
            .offset(x: offset, y: offset)
            .animation(DSAAnimation.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DSAPressStyle {
    /// `.buttonStyle(.dsa)` — the default pressable surface.
    static var dsa: DSAPressStyle { DSAPressStyle() }
}

extension ButtonStyle where Self == DSAPressMotionStyle {
    /// `.buttonStyle(.dsaMotion)` — press motion only, for labels that draw
    /// their own surface.
    static var dsaMotion: DSAPressMotionStyle { DSAPressMotionStyle() }
}
