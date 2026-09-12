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

    /// The shadow is drawn in `dsaBorder`: the reference uses `var(--border)` for
    /// both, and `dsaBorder` is already brightness-adaptive — black on light,
    /// white on the app's near-black dark surface, where a black shadow would be
    /// invisible.
    ///
    /// A pressed element has moved *into* its shadow, so it no longer casts one.
    private var showsShadow: Bool { role == .raised && !isPressed }

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
            // The shadow is an offset *rectangle drawn behind the box*, not
            // SwiftUI's `.shadow()`. `.shadow()` is a layer effect: it applies to
            // everything the view draws, including its text, so every label would
            // cast its own hard shadow and render doubled. CSS `box-shadow` — what
            // the reference specifies — affects only the box, and this is its
            // SwiftUI equivalent.
            // An opaque backing under the shadow. Call sites often tint a surface
            // with `accent.opacity(0.1)`, and a translucent fill would composite
            // against the black shadow rectangle behind it rather than against the
            // page — turning a pale tint nearly black. A surface that casts a
            // shadow is by definition opaque, so it gets a real background.
            .background(showsShadow ? Color(UIColor.systemBackground) : Color.clear)
            .background(alignment: .topLeading) {
                if showsShadow {
                    Rectangle()
                        .fill(Color.dsaBorder)
                        .offset(x: DSALayout.shadowOffset, y: DSALayout.shadowOffset)
                }
            }
            .overlay(Rectangle().stroke(strokeColor, lineWidth: DSALayout.border))
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

// MARK: - Option groups

extension View {
    /// Wraps a group of options — segmented chips, a list of manoeuvres, a zone
    /// picker — in one raised panel.
    ///
    /// This is the other half of ADR-0009's scope decision. Making option rows
    /// `.flush` calmed the lists, but on a screen built entirely of options it
    /// left nothing casting at all, so the screen read as though it had never
    /// been refactored. The group carries the depth its members gave up: the
    /// shadow marks the *group* as a thing on the page, while the options inside
    /// stay flat against it.
    func dsaOptionGroup() -> some View {
        padding(10)
            .frame(maxWidth: .infinity)
            .dsaBox(.raised, fill: Color(UIColor.systemBackground))
    }
}

// MARK: - Sidebar rows

extension View {
    /// A selectable row in the sidebar list.
    ///
    /// The sidebar was the last surface still rendering as stock `List` rows —
    /// selection shown by a tinted `listRowBackground`, rows separated by system
    /// hairlines — while the two call-to-action buttons beside it were fully
    /// styled. That mismatch is what made the sidebar read as a different app.
    ///
    /// Rows are option surfaces, so they are `.flush` and take the accent as a
    /// stroke when selected, exactly like the manoeuvre and zone rows.
    func sidebarRow(accent: Color, isSelected: Bool) -> some View {
        self
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? accent.opacity(0.35) : Color(UIColor.systemBackground))
            .dsaBox(.flush, stroke: isSelected ? accent : Color.dsaBorder)
            .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 16))
            .listRowBackground(Color(UIColor.systemBackground))
            // The system hairline is the "subtle grey" the design language rules
            // out, and it would double up against the row's own border.
            .listRowSeparator(.hidden)
    }
}
