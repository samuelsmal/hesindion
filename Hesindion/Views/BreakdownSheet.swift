import SwiftUI
import RulesEngine

/// One value's breakdown (sheet cut-over design §5): the result, each line with its origin, the
/// facts it read and who stated them, its Auslegung marks, and the rules that did not apply. Built
/// on the app's own calculation grammar — `CombatBreakdownBox`/`BreakdownRow`, `CombatDisclosureSection`
/// — inside the app's own in-app modal (`DSAModal`, task 6b), not a system sheet: a system sheet
/// rounds its corners, and the dice modal (`SkillCheckModal`) does not.
struct BreakdownSheet: View {
    let title: String
    let value: SheetValue
    let book: RuleBook
    /// A sentence above the lines that says what the value is about (issue #51: the mount's LeP
    /// and how its thresholds count). nil for none.
    var intro: String? = nil
    var onDismiss: () -> Void
    /// The one Auslegung mark currently expanded to its answer, at most one at a time (a ruling's
    /// qualified id).
    @State private var openRuling: String?
    /// Owned here, not by `notAppliedSection`'s `CombatDisclosureSection`, so expanding the fold
    /// survives `DSAModal` remounting it under a different parent once the content grows past
    /// the scroll cap (see `CombatDisclosureSection.expandedOverride`).
    @State private var notAppliedExpanded = false
    /// The "Mehr Infos" fold's state, held here for the same reason.
    @State private var moreInfoExpanded = false

    var body: some View {
        DSAModal(
            title: title,
            accent: .groupRulebook,
            onScrimTap: onDismiss,
            onClose: onDismiss,
            scrolls: true
        ) {
            if let intro {
                Text(intro)
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("breakdown.intro")
            }
            CombatBreakdownBox(
                rows: rows,
                totalValue: BreakdownText.total(of: value.breakdown),
                totalSource: title,
                totalIdentifier: "breakdown.result"
            )
            notAppliedSection
            moreInfoSection
        }
    }

    /// One `BreakdownRow` per shown line, in order: the value signed (the base parts too), the
    /// rule's name once per run of its lines, and as the row's `detail` what `BreakdownText` says
    /// of it — a threshold, the facts it read, its Auslegung mark (tappable to expand the ruling's
    /// answer). Clause and ruling ids are under "Mehr Infos".
    private var rows: [BreakdownRow] {
        let details = BreakdownText.details(for: value.breakdown, book: book, openRuling: openRuling)
        let sources = BreakdownText.sources(for: value.breakdown, book: book)
        return value.breakdown.shownLines.enumerated().map { i, line in
            var row = BreakdownRow.signed(line.value, sources[i])
            row.detail = details[i]
            row.identifierOverride = "breakdown.line.\(i)"
            if let ruling = line.ruling {
                row.onTapDetail = { openRuling = (openRuling == ruling ? nil : ruling) }
            }
            return row
        }
    }

    private func ruleName(_ id: String) -> String { book.rules[id]?.name ?? id }

    /// The folded "Mehr Infos" list: the clause and ruling ids the lines rest on (issue #51), kept
    /// out of the rows so that a row does not repeat them.
    @ViewBuilder
    private var moreInfoSection: some View {
        let references = BreakdownText.references(for: value.breakdown, book: book)
        if !references.isEmpty {
            CombatDisclosureSection(
                title: L("breakdown.moreInfo"),
                identifier: "breakdown.moreInfo",
                expandedOverride: $moreInfoExpanded
            ) {
                VStack(spacing: 0) {
                    ForEach(references, id: \.self) { reference in
                        Text(reference)
                            .font(.dsaBody(.caption))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .dsaRowDivider()
                    }
                }
            }
        }
    }

    /// The folded "Nicht angewandt (n)" list, in the app's own disclosure styling (shut by
    /// default, like the announcement's opponent section) rather than a system `DisclosureGroup`.
    private var notAppliedSection: some View {
        let items = Array(value.breakdown.notApplied.enumerated())
        return CombatDisclosureSection(
            title: String(format: L("breakdown.notApplied"), value.breakdown.notApplied.count),
            identifier: "breakdown.notApplied",
            expandedOverride: $notAppliedExpanded
        ) {
            VStack(spacing: 0) {
                ForEach(items, id: \.offset) { i, n in
                    notAppliedRow(n, isLast: i == items.count - 1)
                }
            }
        }
    }

    /// `isLast` tags the fold's final row `breakdown.notApplied.lastRow`, whatever the
    /// count — a UI test scrolling the fold open needs a fixed target to scroll to
    /// without knowing how many rules did not apply.
    private func notAppliedRow(_ n: RulesEngine.NotApplied, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(ruleName(n.origin.rule)) · \(n.origin.clause)").font(.dsaBody(.body))
            Text(L("reason.\(n.reason.rawValue)")).font(.dsaBody(.caption2)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .dsaRowDivider()
        .accessibilityIdentifier(isLast ? "breakdown.notApplied.lastRow" : "")
    }
}
