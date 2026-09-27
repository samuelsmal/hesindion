import SwiftUI
import RulesEngine

/// One value's breakdown (sheet cut-over design §5): the result, each line with its origin, the
/// facts it read and who stated them, its Auslegung marks, and the rules that did not apply.
struct BreakdownSheet: View {
    let title: String
    let value: SheetValue
    let book: RuleBook
    @State private var showNotApplied = false
    @State private var openRuling: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(title).font(.headline)
                        Spacer()
                        Text(value.result.map(String.init) ?? "–")
                            .font(.dsaMono(.title3, emphasis: true))
                            .accessibilityIdentifier("breakdown.result")
                    }
                }
                Section {
                    ForEach(Array(value.breakdown.shownLines.enumerated()), id: \.offset) { i, line in
                        lineRow(line, index: i)
                    }
                }
                Section {
                    DisclosureGroup(isExpanded: $showNotApplied) {
                        ForEach(Array(value.breakdown.notApplied.enumerated()), id: \.offset) { _, n in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(ruleName(n.origin.rule)) · \(n.origin.clause)").font(.subheadline)
                                Text(L("reason.\(n.reason.rawValue)")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } label: {
                        Text(String(format: L("breakdown.notApplied"), value.breakdown.notApplied.count))
                    }
                    .accessibilityIdentifier("breakdown.notApplied")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private func lineRow(_ line: Line, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(line.value >= 0 ? "+\(line.value)" : "\(line.value)")
                    .font(.dsaMono(.body, emphasis: true))
                    .frame(minWidth: 36, alignment: .trailing)
                Text(origin(line)).font(.subheadline)
            }
            ForEach(Array(line.facts.enumerated()), id: \.offset) { _, f in
                Text("\(f.name) \(f.value.display) · \(L("owner.\(f.owner.rawValue)"))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(line.rulings, id: \.self) { r in
                Button(String(format: L("breakdown.auslegung"), r)) {
                    openRuling = (openRuling == r ? nil : r)
                }
                .font(.caption)
                if openRuling == r, let answer = rulingAnswer(r) {
                    Text(answer).font(.caption)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("breakdown.line.\(index)")
    }

    /// A line's origin, its clause id, and the rules it rests `via` (a useLevel, a replace); a
    /// value the sheet or the player stated instead names its `owner` (design §5).
    private func origin(_ line: Line) -> String {
        guard let o = line.origin else { return L("owner.\((line.owner ?? .sheet).rawValue)") }
        let via = line.via.map { ruleName($0.rule) }
        return "\(ruleName(o.rule)) · \(o.clause)" + (via.isEmpty ? "" : " (\(via.joined(separator: ", ")))")
    }

    private func ruleName(_ id: String) -> String { book.rules[id]?.name ?? id }

    /// The decided answer of a ruling, `RULE.id` or `shared.id`, from the book.
    private func rulingAnswer(_ qualified: String) -> String? {
        book.rulingAnswer(qualified)
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
