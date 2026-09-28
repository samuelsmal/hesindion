import SwiftUI

/// The in-app modal: a scrim with one raised panel on it.
///
/// Extracted so that confirmations stop falling back to `.alert`. A system alert
/// brings its own rounded corners, its own blurred material and its own tinted
/// text — three things the design language rules out — and it does so on top of
/// a screen built entirely without them. `SkillCheckModal` already drew its own
/// panel; this is that idiom made shareable.
///
/// The panel is `.raised`: a modal floating on a scrim is exactly the "floating
/// container" case ADR-0009 reserved the shadow for.
struct DSAModal<Content: View>: View {
    let title: String
    var accent: Color = .groupCombat
    /// Tapping the scrim. `nil` makes the modal insistent — it can only be left
    /// through one of its own buttons.
    var onScrimTap: (() -> Void)? = nil
    /// A close button (white xmark, `modal.close`) on the header's trailing
    /// edge. `nil` — the default, and what every confirmation caller leaves it
    /// at — draws the header exactly as before: a bare centred title with
    /// nothing overlaid on it (task 6b: `BreakdownSheet`/`WeaponInfoSheet` are
    /// the first callers to pass one, since a full-content panel needs a way
    /// out beyond the scrim).
    var onClose: (() -> Void)? = nil
    /// `true` puts `content` in a leading-aligned `VStack` that hugs it when it fits and
    /// scrolls, capped so the panel never exceeds the screen, when it doesn't
    /// (`BreakdownSheet`'s rows, `WeaponInfoSheet`'s Vorteil/Nachteil/Hinweis can run
    /// long). `false` — the default — keeps the fixed, centred `VStack` every
    /// confirmation caller already renders.
    var scrolls: Bool = false
    @ViewBuilder var content: Content

    /// The `scrolls` content's own measured height, via `onGeometryChange` (iOS 17+ —
    /// the classic `GeometryReader` + `PreferenceKey` + `onPreferenceChange` dance never
    /// fired at all here, leaving this stuck at its initial value no matter what content
    /// actually measured). Starts at 0 — "assume it fits" — so the first paint is the
    /// plain, hugging layout; content long enough to matter is reached only by a later
    /// state change (expanding the not-applied fold), by which point the real height is
    /// already known.
    @State private var scrollableContentHeight: CGFloat = 0

    /// The one live copy of `content`, wrapped and measured the same way regardless of
    /// which branch below renders it.
    private var measuredContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { newHeight in
            scrollableContentHeight = newHeight
        }
    }

    var body: some View {
        ZStack {
            Color.dsaOverlay
                .ignoresSafeArea()
                .onTapGesture { onScrimTap?() }

            VStack(spacing: 0) {
                header

                if scrolls {
                    let cap = UIScreen.main.bounds.height * 0.6
                    if scrollableContentHeight > cap {
                        ScrollView { measuredContent }
                            .frame(height: cap)
                    } else {
                        // The safety cap here is a no-op once `scrollableContentHeight`
                        // has settled (it's already `<= cap`, by the branch condition);
                        // it only clips the rare single frame right after content has
                        // just grown past the cap but the measurement above hasn't
                        // caught up yet, so the panel never visibly overshoots the
                        // screen even for that one frame. `alignment: .top` matters:
                        // `.frame(maxHeight:)` centres oversized content by default, so
                        // without it that one frame shows a clipped *middle* slice
                        // instead of the top.
                        measuredContent
                            .frame(maxHeight: cap, alignment: .top)
                            .clipped()
                    }
                } else {
                    VStack(spacing: 12) {
                        content
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: 420)
            .background(Color(UIColor.systemBackground))
            .dsaBox(.raised)
            .padding(24)
        }
    }

    private var header: some View {
        ZStack {
            Text(title)
                .font(.dsaHeading(.headline))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            if let onClose {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.dsaBody(.body))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.dsaMotion)
                    .accessibilityLabel(L("close"))
                    .accessibilityIdentifier("modal.close")
                }
                .padding(.trailing, 16)
            }
        }
        .padding(.vertical, 14)
        .background(accent)
        .dsaBox(.flush)
    }
}

/// A modal's own action button. Filled is the affirmative one.
struct DSAModalButton: View {
    let title: String
    var accent: Color = .groupCombat
    var filled: Bool = true
    var identifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.dsaHeading(.body))
                .foregroundStyle(filled ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(filled ? accent : Color(UIColor.systemBackground))
                .dsaBox(.flush, stroke: filled ? accent : Color.dsaBorder)
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier(identifier ?? "")
    }
}
