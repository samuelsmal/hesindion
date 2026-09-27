import SwiftUI
import RulesEngine

/// One value's breakdown (sheet cut-over design §5): the result, each line with its origin, the
/// facts it read and who stated them, its Auslegung marks, and the rules that did not apply. Built
/// on the app's own calculation grammar — `CombatBreakdownBox`/`BreakdownRow`, `CombatDisclosureSection`
/// — and the header/`ScrollView` shape of the app's other sheets (`WeaponInfoSheet`, `HeilungSheet`),
/// not system `List`/`DisclosureGroup` chrome.
struct BreakdownSheet: View {
    let title: String
    let value: SheetValue
    let book: RuleBook
    @Environment(\.dismiss) private var dismiss
    /// The one Auslegung mark currently expanded to its answer, at most one at a time (a ruling's
    /// qualified id).
    @State private var openRuling: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    CombatBreakdownBox(
                        rows: rows,
                        totalValue: value.result.map(String.init) ?? "–",
                        totalSource: title,
                        totalIdentifier: "breakdown.result"
                    )
                    notAppliedSection
                }
                .padding(16)
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.dsaHeading(.headline))
                .foregroundStyle(.white)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.dsaBody(.body))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.dsaMotion)
            .accessibilityLabel(L("close"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.groupRulebook)
        .dsaBox(.raised)
    }

    /// One `BreakdownRow` per shown line, in order: the value signed (the base parts too), the
    /// source `Rule name · clause`, the facts it read and its Auslegung mark (if any) as the
    /// row's `detail`, tappable to expand the ruling's answer.
    private var rows: [BreakdownRow] {
        value.breakdown.shownLines.enumerated().map { i, line in
            var row = BreakdownRow.signed(line.value, origin(line))
            row.detail = detail(for: line)
            row.identifierOverride = "breakdown.line.\(i)"
            if let ruling = line.ruling {
                row.onTapDetail = { openRuling = (openRuling == ruling ? nil : ruling) }
            }
            return row
        }
    }

    /// The facts a line read (`KO 13 · Heldenbogen`) and, when it rests on a ruling, the Auslegung
    /// mark — expanded to the ruling's decided answer while it is the open one.
    private func detail(for line: Line) -> String? {
        var parts = line.facts.map {
            "\(FactLabel.label($0.name, book: book)) \($0.value.display) · \(L("owner.\($0.owner.rawValue)"))"
        }
        if let ruling = line.ruling {
            var mark = String(format: L("breakdown.auslegung"), ruling)
            if openRuling == ruling, let answer = book.rulingAnswer(ruling) {
                mark += ": \(answer)"
            }
            parts.append(mark)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// A line's origin, its clause id, and the rules it rests `via` (a useLevel, a replace); a
    /// value the sheet or the player stated instead names its `owner` (design §5).
    private func origin(_ line: Line) -> String {
        guard let o = line.origin else { return L("owner.\((line.owner ?? .sheet).rawValue)") }
        let via = line.via.map { ruleName($0.rule) }
        return "\(ruleName(o.rule)) · \(o.clause)" + (via.isEmpty ? "" : " (\(via.joined(separator: ", ")))")
    }

    private func ruleName(_ id: String) -> String { book.rules[id]?.name ?? id }

    /// The folded "Nicht angewandt (n)" list, in the app's own disclosure styling (shut by
    /// default, like the announcement's opponent section) rather than a system `DisclosureGroup`.
    private var notAppliedSection: some View {
        CombatDisclosureSection(
            title: String(format: L("breakdown.notApplied"), value.breakdown.notApplied.count),
            identifier: "breakdown.notApplied"
        ) {
            VStack(spacing: 0) {
                ForEach(Array(value.breakdown.notApplied.enumerated()), id: \.offset) { _, n in
                    notAppliedRow(n)
                }
            }
        }
    }

    private func notAppliedRow(_ n: RulesEngine.NotApplied) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(ruleName(n.origin.rule)) · \(n.origin.clause)").font(.dsaBody(.body))
            Text(L("reason.\(n.reason.rawValue)")).font(.dsaBody(.caption2)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .dsaRowDivider()
    }
}

private extension JSONValue {
    var display: String {
        switch self {
        case .int(let i): "\(i)"
        case .double(let d): "\(d)"
        case .string(let s): s
        case .bool(let b): L(b ? "yes" : "no")
        case .null: "–"
        default: "…"
        }
    }
}
