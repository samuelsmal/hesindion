import SwiftUI

/// The modifier-plus-display control: `[−] [ value ] [+]` as **one** object.
///
/// Six screens had each grown their own version of this — the TP field, the
/// dice roller, the defence and ranged modifier rows, the execution modifier
/// and the command palette — differing in icon, fill, and visibly in whether
/// the value segment expanded. `DiceRollSheet` gave its value an intrinsic
/// `minWidth: 48` while its buttons filled, so the thirds came out unequal.
///
/// Two design rules, both from ADR-0009:
///
/// - **Equal thirds.** All three segments expand equally, so the control reads
///   as one object rather than two buttons with something wedged between them.
/// - **The control casts, the segments do not.** A shadow belongs to the whole
///   control; three adjacent shadows inside a joined `HStack` would overlap.
///   Segments are divided by a stroke of the same weight as the border.
///
/// Because the segments have no shadow to press into, they take spec 010's
/// background/text colour flip instead — see `DSASegmentPressStyle`.
struct DSAStepper<Value: View>: View {
    var decrementIcon: String = "minus"
    var incrementIcon: String = "plus"
    /// Fill for the two buttons. The value segment always sits on the surface.
    var tint: Color
    var iconColor: Color = .white
    var decrementDisabled: Bool = false
    var incrementDisabled: Bool = false
    var decrementIdentifier: String?
    var incrementIdentifier: String?
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    @ViewBuilder var value: Value

    var body: some View {
        HStack(spacing: 0) {
            segment(
                icon: decrementIcon,
                disabled: decrementDisabled,
                identifier: decrementIdentifier,
                action: onDecrement
            )

            rule

            value
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemBackground))

            rule

            segment(
                icon: incrementIcon,
                disabled: incrementDisabled,
                identifier: incrementIdentifier,
                action: onIncrement
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .dsaBox(.raised)
    }

    private var rule: some View {
        Rectangle()
            .fill(Color.dsaBorder)
            .frame(width: DSALayout.border)
    }

    @ViewBuilder
    private func segment(
        icon: String,
        disabled: Bool,
        identifier: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.dsaHeading(.body))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(
            DSASegmentPressStyle(
                tint: disabled ? Color.dsaDisabled : tint,
                foreground: iconColor
            )
        )
        .disabled(disabled)
        .accessibilityIdentifier(identifier ?? "")
    }
}

/// Spec 010's press feedback — background and text colour flip — for segments
/// inside a control that owns the shadow.
///
/// The move-into-shadow press (`DSAPressStyle`) needs a shadow to move into.
/// Segments do not have one, so without this they would be inert, which is the
/// state the whole refactor set out to fix.
struct DSASegmentPressStyle: ButtonStyle {
    let tint: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? tint : foreground)
            .background(configuration.isPressed ? foreground : tint)
            .animation(DSAAnimation.press, value: configuration.isPressed)
    }
}
