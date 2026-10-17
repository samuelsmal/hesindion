import SwiftUI

/// The rule between the two branches of an either/or: `[ A ]  —— ODER ——  [ B ]`.
///
/// Several screens ask the player to pick one of two routes to the same answer —
/// take the basic rule or roll the table, name the Trefferzone or roll 1W20, roll
/// the Wundeffekt damage or enter what was rolled at the table. Each was drawn as
/// two controls stacked in a box, which reads as two independent actions: nothing
/// said "one *or* the other", and where the two carried different fills (dark and
/// red) the colour said "secondary, primary" — a recommendation the rules do not
/// make.
///
/// Same shape as `combatSectionLabel`, one step quieter: the section label says
/// what a group is, this says how its parts relate.
struct DSAOrDivider: View {
    var label: String = L("or")

    var body: some View {
        HStack(spacing: 8) {
            rule
            Text(label)
                .font(.dsaHeading(.caption2))
                .foregroundStyle(.secondary)
                .fixedSize()
            rule
        }
        .padding(.vertical, 2)
        .accessibilityHidden(true)
    }

    private var rule: some View {
        Rectangle()
            .frame(height: DSALayout.divider)
            .foregroundStyle(Color.dsaBorder.opacity(0.4))
    }
}
