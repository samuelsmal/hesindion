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
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.dsaOverlay
                .ignoresSafeArea()
                .onTapGesture { onScrimTap?() }

            VStack(spacing: 0) {
                Text(title)
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accent)
                    .dsaBox(.flush)

                VStack(spacing: 12) {
                    content
                }
                .padding(16)
            }
            .frame(maxWidth: 420)
            .background(Color(UIColor.systemBackground))
            .dsaBox(.raised)
            .padding(24)
        }
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
