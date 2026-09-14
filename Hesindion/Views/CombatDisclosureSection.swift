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
    @ViewBuilder let content: () -> Content

    @State private var isExpanded: Bool?

    private var expanded: Bool { isExpanded ?? startsExpanded }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DSAAnimation.standard) { isExpanded = !expanded }
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
