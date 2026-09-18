import SwiftUI

/// One line of a calculation: the contribution on the left, where it comes from
/// on the right.
struct BreakdownRow: Identifiable {
    let id = UUID()
    let value: String
    let source: String
    var tint: Color = .primary

    /// A signed contribution, tinted by its sign the way the AT breakdown does.
    ///
    /// Zero is neither: an RS of 0 is worth stating on the take-damage screen —
    /// the armour did nothing — but it is not a penalty, and printing it in the
    /// penalty colour said it was.
    static func signed(_ value: Int, _ source: String) -> BreakdownRow {
        BreakdownRow(
            value: value > 0 ? "+\(value)" : "\(value)",
            source: source,
            tint: value == 0 ? .secondary : (value > 0 ? Color.dsaPositive : Color.groupCombat)
        )
    }

    static func line(_ line: ModifierLine) -> BreakdownRow {
        signed(line.value, line.source)
    }
}

/// The "how this number came to be" box: the parts on top, one per row, and the
/// result in a dark bar inside the same border.
///
/// One box, dividers within. Each row used to stroke its own rectangle, so every
/// boundary was a doubled 2pt border — and the total was a bare dark bar with no
/// border at all, the only unbordered surface on the screen.
///
/// Shared by the AT/PA/AW roll and by the damage. The damage half had no such
/// box: the dice were shown, and everything else — the weapon's own bonus, a
/// Wuchtschlag, the grip, a critical's multiplier — arrived inside a single
/// pre-computed string, which is what made the total impossible to check at the
/// table and let the same bonus be added twice unnoticed.
struct CombatBreakdownBox: View {
    let rows: [BreakdownRow]
    let totalValue: String
    let totalSource: String
    /// Section heading above the box. `nil` places the box bare, for a caller
    /// that has already labelled the section.
    var sectionLabel: String? = nil

    /// The common shape: a base value, a modifier line each, a total.
    init(
        baseValue: String,
        baseSource: String,
        lines: [ModifierLine],
        totalValue: String,
        totalSource: String,
        sectionLabel: String? = nil
    ) {
        self.rows = [BreakdownRow(value: baseValue, source: baseSource)] + lines.map(BreakdownRow.line)
        self.totalValue = totalValue
        self.totalSource = totalSource
        self.sectionLabel = sectionLabel
    }

    /// Rows built by the caller, for a calculation whose parts are not all
    /// signed integers — the damage, where a critical multiplies.
    init(
        rows: [BreakdownRow],
        totalValue: String,
        totalSource: String,
        sectionLabel: String? = nil
    ) {
        self.rows = rows
        self.totalValue = totalValue
        self.totalSource = totalSource
        self.sectionLabel = sectionLabel
    }

    var body: some View {
        VStack(spacing: 0) {
            if let sectionLabel {
                combatSectionLabel(sectionLabel)
            }

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    Self.row(value: row.value, source: row.source, tint: row.tint)
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
        // The row is a container, named after what it says. A bare
        // `staticTexts["-2"]` in a test is satisfied by *any* −2 in the
        // calculation, so a penalty that moved to a different line — or one that
        // vanished while another appeared — still passed. `children: .contain`
        // keeps both texts individually queryable, so nothing that already
        // asserts on them breaks.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combat.breakdown.row.\(source)")
    }
}
