import SwiftUI

/// The one primary action at the foot of a combat screen.
///
/// "Weiter", "Bestätigen" and "Neue Aktion" all do the same job — settle this
/// screen and move to the next — but were three different buttons. Two sat in the
/// content column with the app's raised box; "Weiter" was pinned edge to edge
/// below the scroll view, flush with the screen's sides and with no shadow, which
/// reads as a tab bar rather than as the next step of the flow. Nothing about it
/// was special, so nothing about it looks special now.
///
/// In the flow, not pinned: the screen ends with its action the way a page ends
/// with its full stop, and the eye that just read the calculation is already
/// there.
struct CombatActionButton: View {
    let title: String
    var icon: String? = nil
    /// The accent by default. `Color.dsaDark` for a secondary route offered
    /// beside a primary one.
    var fill: Color = combatAccent
    var identifier: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    /// The gap this button keeps from whatever is above it.
    ///
    /// A raised box draws its shadow *outside* its bounds and reserves no layout
    /// space for it (ADR-0008), so a nominal 8pt gap comes out as 3 and the
    /// action reads as the last row of the calculation it follows. The button
    /// carries the clearance itself rather than leaving every screen to
    /// remember it.
    static let topGap: CGFloat = DSALayout.shadowOffset + 12

    @ViewBuilder
    var body: some View {
        if let identifier {
            button.accessibilityIdentifier(identifier)
        } else {
            button
        }
    }

    private var button: some View {
        content.padding(.top, Self.topGap)
    }

    private var content: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.dsaHeading(.title3))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? fill : Color.dsaDisabled)
            .dsaBox(.raised)
        }
        .buttonStyle(.dsaMotion)
        .disabled(!isEnabled)
    }
}
