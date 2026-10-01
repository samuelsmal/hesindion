import SwiftUI

/// One line of a calculation: the contribution on the left, where it comes from
/// on the right.
struct BreakdownRow: Identifiable {
    let id = UUID()
    let value: String
    let source: String
    var tint: Color = .primary
    /// A second, smaller line under `source` — the facts a line read and, when it rests on a
    /// ruling, the Auslegung mark (sheet cut-over design §5). `nil` for every combat calculation's
    /// own rows, which show none and render exactly as before.
    var detail: String? = nil
    /// Tapped when `detail` is shown, to toggle an Auslegung mark's answer inline. `nil` when
    /// there is nothing to expand.
    var onTapDetail: (() -> Void)? = nil
    /// Overrides the row's own `combat.breakdown.row.<source>` identifier — `BreakdownSheet` needs
    /// `breakdown.line.<n>` instead, in source order, which a rule name repeated across two lines
    /// (two base terms of one derive) would otherwise collide on.
    var identifierOverride: String? = nil

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
    /// `breakdown.result` for `BreakdownSheet`'s total; every combat caller leaves this nil, as
    /// before.
    var totalIdentifier: String? = nil

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
        sectionLabel: String? = nil,
        totalIdentifier: String? = nil
    ) {
        self.rows = rows
        self.totalValue = totalValue
        self.totalSource = totalSource
        self.sectionLabel = sectionLabel
        self.totalIdentifier = totalIdentifier
    }

    var body: some View {
        VStack(spacing: 0) {
            if let sectionLabel {
                combatSectionLabel(sectionLabel)
            }

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    Self.row(row)
                }

                // The sum, inside the same box rather than welded under it.
                HStack {
                    Text(totalValue)
                        .font(.dsaMono(.body, emphasis: true))
                        .accessibilityIdentifier(totalIdentifier ?? "")
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

    /// A row built straight from its value/source/tint — every combat caller's shape, unchanged.
    static func row(value: String, source: String, tint: Color) -> some View {
        row(BreakdownRow(value: value, source: source, tint: tint))
    }

    static func row(_ row: BreakdownRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(row.value)
                    .font(.dsaMono(.caption, emphasis: true))
                    .foregroundStyle(row.tint)
                Spacer()
                Text(row.source)
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(.secondary)
            }
            if let detail = row.detail {
                Text(detail)
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(.secondary)
                    .onTapGesture { row.onTapDetail?() }
            }
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
        .accessibilityIdentifier(row.identifierOverride ?? "combat.breakdown.row.\(row.source)")
    }
}
