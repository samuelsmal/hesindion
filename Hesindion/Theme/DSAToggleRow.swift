import SwiftUI

/// A full-width boolean option, shown active by its **fill**.
///
/// The app had grown two unrelated ways of saying "this option is on". Single-
/// select pickers — Manöver, Trefferzone, Gegner-Reichweite — fill the chosen
/// row with the accent and turn its label white. Boolean toggles instead kept a
/// neutral row and put a `checkmark.square.fill` on the left. Both appear on the
/// *same screen*: on the announcement, "Torso" is red-filled while "Ziel ist
/// überrascht" one row below is a tickbox.
///
/// One treatment now, and it is the fill: the checkbox is a control borrowed
/// from a system list, and it says "on" in a whisper on a screen where
/// everything else says it in a shout.
///
/// `detail` is the modifier the option contributes ("+2"), shown on the right so
/// the row reads as label-then-consequence like the manoeuvre rows do.
struct DSAToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var accent: Color = .groupCombat
    var detail: String? = nil
    var subtitle: String? = nil
    /// Icon shown ahead of the title. Not a state indicator — it does not change
    /// with `isOn`; the fill carries that.
    var icon: String? = nil
    var identifier: String? = nil

    var body: some View {
        Button { isOn.toggle() } label: {
            DSAToggleRowLabel(
                title: title,
                isOn: isOn,
                accent: accent,
                detail: detail,
                subtitle: subtitle,
                icon: icon
            )
        }
        .buttonStyle(.dsaMotion)
        .accessibilityIdentifier(identifier ?? "")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The row's surface without the button, for a caller that owns the tap itself.
///
/// The armour rows on the combat root and the preparation screen are the two:
/// each is a `Button` that toggles `Armor.isEquipped`, so wrapping this row's
/// own button inside theirs would nest one control in another. They draw the
/// surface and keep the gesture.
struct DSAToggleRowLabel: View {
    let title: String
    let isOn: Bool
    var accent: Color = .groupCombat
    var detail: String? = nil
    var subtitle: String? = nil
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.dsaBody(.body))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(isOn ? .dsaHeading(.body) : .dsaBody(.body))
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(.dsaBody(.caption))
                        // Not `.secondary`: on the filled row that would be a
                        // grey on the accent. A single opacity step reads on
                        // both grounds.
                        .opacity(0.75)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(.dsaMono(.caption, emphasis: true))
            }
        }
        .foregroundStyle(isOn ? Color.white : Color.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(isOn ? accent : Color(UIColor.systemBackground))
        .dsaBox(.flush, stroke: isOn ? accent : Color.dsaBorder)
    }
}
