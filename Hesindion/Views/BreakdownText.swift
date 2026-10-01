import Foundation
import RulesEngine

/// The words `BreakdownSheet` prints under each line and in the result bar (issue #51): a
/// threshold says which Stufe it is, its value and whether it is reached; a `levelAs` line says
/// which Stufe acts as which; a Stufe's result is a Stufe, not a bare number. A label lookup
/// only — the numbers are the engine's.
enum BreakdownText {
    /// Facts a line reads only to gate a rule (`subject: creature`), which say nothing to a player.
    private static let hiddenFacts: Set<String> = ["subject"]

    /// One detail per shown line, in `shownLines` order (nil: the row has none). A fact or an
    /// Auslegung mark the line above already showed is not repeated.
    static func details(for breakdown: Breakdown, book: RuleBook, openRuling: String?) -> [String?] {
        let isLevel = breakdown.query.name == "level"
        var step = 0
        var shownFacts: [FactUse] = []
        var shownRuling: String?
        return breakdown.shownLines.map { line in
            var parts: [String] = []
            if let threshold = line.threshold {
                step += 1
                let what = facts(of: line).first.map { FactLabel.label($0.name, book: book) } ?? L("breakdown.step.value")
                let reached = L(line.value > 0 ? "breakdown.step.reached" : "breakdown.step.notReached")
                parts.append(String(format: L("breakdown.step"), isLevel ? StateCatalog.roman(step) : "\(step)",
                                    what, threshold, reached))
            }
            if line.kind == .levelAs, let was = line.was, let now = line.now {
                parts.append(String(format: L("breakdown.levelAs"), stufe(was), stufe(now)))
            } else {
                let new = facts(of: line).filter { !shownFacts.contains($0) }
                shownFacts = facts(of: line)
                parts += new.map { fact in
                    let label = "\(FactLabel.label(fact.name, book: book)) \(display(fact.value))"
                    return fact.owner == .derived ? label : "\(label) · \(L("owner.\(fact.owner.rawValue)"))"
                }
            }
            defer { shownRuling = line.ruling }
            if let ruling = line.ruling, ruling != shownRuling {
                let answer = openRuling == ruling ? (book.rulingAnswer(ruling) ?? ruling) : nil
                parts.append(answer.map { String(format: L("breakdown.auslegung.open"), $0) } ?? L("breakdown.auslegung"))
            }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
    }

    /// One source per shown line: the rule's name (or, for a value no rule gave, who stated it),
    /// "" when the line above has the same one. The clause ids are in `references`.
    static func sources(for breakdown: Breakdown, book: RuleBook) -> [String] {
        var previous: String?
        return breakdown.shownLines.map { line in
            let name = line.origin.map { ruleName($0.rule, book) } ?? L("owner.\((line.owner ?? .sheet).rawValue)")
            defer { previous = name }
            return name == previous ? "" : name
        }
    }

    /// "Mehr Infos": every clause the lines come from and rest on (`Rule · clause`), then every
    /// ruling they rest on, each once, in line order (design §5: each line's origin stays shown).
    static func references(for breakdown: Breakdown, book: RuleBook) -> [String] {
        var clauses: [String] = [], rulings: [String] = []
        for line in breakdown.shownLines {
            for ref in (line.origin.map { [$0] } ?? []) + line.via {
                let text = "\(ruleName(ref.rule, book)) · \(ref.clause)"
                if !clauses.contains(text) { clauses.append(text) }
            }
            for id in line.rulings {
                let text = String(format: L("breakdown.reference.ruling"), id)
                if !rulings.contains(text) { rulings.append(text) }
            }
        }
        return clauses + rulings
    }

    /// The result bar's value: for `level(rule:)` the Stufe acted at, and the Stufe had when a
    /// `levelAs` line moved it; else the number.
    static func total(of breakdown: Breakdown) -> String {
        guard let result = breakdown.result else { return "–" }
        guard breakdown.query.name == "level" else { return "\(result)" }
        if let had = breakdown.base?.value, had != result {
            return String(format: L("breakdown.level.totalHas"), stufe(result), stufe(had))
        }
        return String(format: L("breakdown.level.total"), stufe(result))
    }

    private static func ruleName(_ id: String, _ book: RuleBook) -> String { book.rules[id]?.name ?? id }

    private static func facts(of line: Line) -> [FactUse] {
        line.facts.filter { !hiddenFacts.contains($0.name) }
    }

    private static func stufe(_ level: Int) -> String {
        level > 0 ? StateCatalog.roman(level) : L("breakdown.level.none")
    }

    private static func display(_ value: JSONValue) -> String {
        switch value {
        case .int(let i): "\(i)"
        case .double(let d): "\(d)"
        case .string(let s): s
        case .bool(let b): L(b ? "yes" : "no")
        case .null: "–"
        default: "…"
        }
    }
}
