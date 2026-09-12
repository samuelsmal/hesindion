import SwiftUI

/// The "how this number came to be" box: the base on top, one row per modifier,
/// the result in a dark bar inside the same border.
///
/// One box, dividers within. Each row used to stroke its own rectangle, so every
/// boundary was a doubled 2pt border — and the total was a bare dark bar with no
/// border at all, the only unbordered surface on the screen.
///
/// Shared by the AT/PA/AW roll and by the damage the announcement screen is
/// about to hand to the dice. The damage half had no such box: a Wuchtschlag's
/// +4 TP and the two-handed grip's +1 were folded into the formula in silence,
/// which is what made the total impossible to check at the table.
struct CombatBreakdownBox: View {
    /// Left-hand side of the first row — "AT 12", or a damage formula.
    let baseValue: String
    let baseSource: String
    let lines: [ModifierLine]
    let totalValue: String
    let totalSource: String
    /// Section heading above the box. `nil` places the box bare, for a caller
    /// that has already labelled the section.
    var sectionLabel: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let sectionLabel {
                combatSectionLabel(sectionLabel)
            }

            VStack(spacing: 0) {
                Self.row(value: baseValue, source: baseSource, tint: .primary)

                ForEach(lines) { line in
                    Self.row(
                        value: line.value > 0 ? "+\(line.value)" : "\(line.value)",
                        source: line.source,
                        tint: line.value > 0 ? Color.dsaPositive : Color.groupCombat
                    )
                }

                // The sum, inside the same box rather than welded under it.
                HStack {
                    Text(totalValue)
                        .font(.dsaMono(.body, emphasis: true))
                    Spacer()
                    Text(totalSource)
                        .font(.dsaBody(.caption2))
                        .opacity(0.75)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.dsaDark)
            }
            .dsaBox(.raised, fill: Color(UIColor.systemBackground))
        }
    }

    /// One line of the calculation: the contribution on the left, where it comes
    /// from on the right, a divider beneath.
    static func row(value: String, source: String, tint: Color) -> some View {
        HStack {
            Text(value)
                .font(.dsaMono(.caption, emphasis: true))
                .foregroundStyle(tint)
            Spacer()
            Text(source)
                .font(.dsaBody(.caption2))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .dsaRowDivider()
    }
}
