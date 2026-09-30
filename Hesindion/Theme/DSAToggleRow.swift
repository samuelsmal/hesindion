import SwiftUI

/// A full-width on/off option, shown by a **switch** on the right (ADR-0019).
///
/// The row itself stays neutral whether the option is on or off. A filled row
/// means "this one of several is picked" — Manöver, Trefferzone, Gegner-
/// Reichweite — and an on/off option is not a pick: it was the same fill until
/// issue #37, so "Ziel ist überrascht" read as a fifth Trefferzone under
/// "Torso". The switch is the neobrutalism reference's own control for it.
///
/// The whole row is the tap target, not only the switch.
///
/// `detail` is the modifier the option contributes ("+2"), shown before the
/// switch so the row reads as label, consequence, state.
struct DSAToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var accent: Color = .groupCombat
    var detail: String? = nil
    var subtitle: String? = nil
    /// Icon shown ahead of the title. Not a state indicator — it does not change
    /// with `isOn`; the switch carries that.
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
        .dsaToggleAccessibility(isOn: isOn)
    }
}

extension View {
    /// What VoiceOver and the UI tests read from an on/off control: a switch
    /// (`.isToggle`, so XCUITest lists it under `switches`), "An" or "Aus", and
    /// `.isSelected` when on. For a caller that owns the tap around a
    /// `DSAToggleRowLabel`, as `DSAToggleRow` and `DSASwitch` do themselves.
    func dsaToggleAccessibility(isOn: Bool) -> some View {
        self
            .accessibilityValue(L(isOn ? "switch.on" : "switch.off"))
            .accessibilityAddTraits(isOn ? [.isToggle, .isSelected] : .isToggle)
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
                    .font(.dsaBody(.body))
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(.dsaMono(.caption, emphasis: true))
            }
            DSASwitchTrack(isOn: isOn, accent: accent)
        }
        .foregroundStyle(Color.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
        .dsaBox(.flush)
    }
}
