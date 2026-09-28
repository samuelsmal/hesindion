import SwiftUI

/// A section of a combat screen that can be folded away, with what is set inside
/// it readable while it is shut.
///
/// The announcement screen asks about the opponent — their reach, their size,
/// whether they are on the ground, whether they are a demon — and most attacks
/// answer none of it. Laid out flat, six rows of "no" sit between the player and
/// the manoeuvre they came for; hidden behind a rule switch, the answers become
/// invisible. A fold with its state on the lid is the shape that fits: shut by
/// default, and shut it still says what it holds.
struct CombatDisclosureSection<Content: View>: View {
    let title: String
    /// What is set inside, read while the section is shut. `nil` prints nothing.
    var summary: String?
    var identifier: String?
    /// Open on first appearance. Shut is the right default for a section that is
    /// usually empty; a section carrying something is worth opening.
    var startsExpanded: Bool = false
    /// An externally-owned expand/collapse flag, for a caller whose own layout can
    /// remount this section under a structurally different parent — `DSAModal`'s
    /// `scrolls` panel switches between an unscrolled stack and one wrapped in a
    /// `ScrollView` once measured content outgrows its cap, and each branch is its
    /// own instance, so this section's default internal `@State` would reset to
    /// closed the moment expanding it grew the content past the cap and switched
    /// the panel to the other branch. `nil` — every other caller — keeps this
    /// section's own state.
    var expandedOverride: Binding<Bool>? = nil
    @ViewBuilder let content: () -> Content

    @State private var isExpanded: Bool?

    private var expanded: Bool { expandedOverride?.wrappedValue ?? isExpanded ?? startsExpanded }

    private func toggle() {
        if let expandedOverride {
            expandedOverride.wrappedValue.toggle()
        } else {
            isExpanded = !expanded
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DSAAnimation.standard) { toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.dsaHeading(.caption))
                        .foregroundStyle(combatAccent)
                    Spacer(minLength: 8)
                    if let summary, !summary.isEmpty {
                        Text(summary)
                            .font(.dsaMono(.caption2, emphasis: true))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.dsaBody(.caption2))
                        .foregroundStyle(combatAccent)
                }
                .padding(.horizontal, DSALayout.contentPadding)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(.dsaMotion)
            .accessibilityIdentifier(identifier.map { "\($0).toggle" } ?? "")

            if expanded {
                VStack(spacing: 8) {
                    content()
                }
                .padding(.horizontal, DSALayout.contentPadding)
                .padding(.top, 8)
                .padding(.bottom, DSALayout.contentPadding)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
            }
        }
        .dsaBox(.raised)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier ?? "")
    }
}
