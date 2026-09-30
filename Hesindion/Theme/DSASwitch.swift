import SwiftUI

/// The neobrutalism Switch (neobrutalism.dev/docs/switch, issue #37): the one
/// way an on/off option shows its state (ADR-0019).
///
/// A pill track with the border weight, the surface when off and the accent
/// when on; a white round thumb with the same border, which moves to the right
/// when the switch is on. No shadow, as in the reference.
///
/// Round, although every other control is square (ADR-0009): the issue asks for
/// this component, and the pill is what makes it read as a switch and not as a
/// second kind of button.
///
/// The reference's `default` size is 48 × 24 with a 16 thumb and a 4 inset; the
/// track height scales with Dynamic Type and the rest keeps those proportions.
struct DSASwitch: View {
    @Binding var isOn: Bool
    /// What the switch turns on, for VoiceOver. A switch beside its own text
    /// uses `DSAToggleRow`, which reads the title.
    let label: String
    var accent: Color = .groupCombat
    var identifier: String? = nil

    var body: some View {
        Button { isOn.toggle() } label: {
            DSASwitchTrack(isOn: isOn, accent: accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .dsaToggleAccessibility(isOn: isOn)
        .accessibilityIdentifier(identifier ?? "")
    }
}

/// The switch's drawing without the button, for a row that owns the tap —
/// `DSAToggleRowLabel`, whose whole row is the control.
struct DSASwitchTrack: View {
    let isOn: Bool
    var accent: Color = .groupCombat

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 24

    private var width: CGFloat { height * 2 }
    private var thumb: CGFloat { height * 2 / 3 }
    /// The reference's `translate-x-1`: the thumb's gap to the track's inner edge.
    private var inset: CGFloat { height / 6 }

    var body: some View {
        // `.circular`: the default continuous curve drew a flat edge at each
        // end of so short a track.
        Capsule(style: .circular)
            .fill(isOn ? accent : Color(UIColor.systemBackground))
            .overlay(Capsule(style: .circular).strokeBorder(Color.dsaBorder, lineWidth: DSALayout.border))
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(Color.dsaBorder, lineWidth: DSALayout.border))
                    .frame(width: thumb, height: thumb)
                    .padding(.horizontal, DSALayout.border + inset)
            }
            .frame(width: width, height: height)
            .animation(DSAAnimation.standard, value: isOn)
            .accessibilityHidden(true)
    }
}
