import Foundation
import RulesEngine

/// The words `BreakdownSheet` prints under each line and in the result bar (issue #51): a
/// threshold says which Stufe it is, its value and whether it is reached; a `levelAs` line says
/// which Stufe acts as which; a Stufe's result is a Stufe, not a bare number. A label lookup
/// only — the numbers are the engine's.
enum BreakdownText {
    /// Facts a line reads only to gate a rule (`subject: creature`), which say nothing to a player.
    private static let hiddenFacts: Set<String> = ["subject"]

    /// One detail per shown line, in `shownLines` order (nil: the row has none).
    static func details(for breakdown: Breakdown, book: RuleBook, openRuling: String?) -> [String?] {
        let isLevel = breakdown.query.name == "level"
        var step = 0
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
                parts += facts(of: line).map { fact in
                    let label = "\(FactLabel.label(fact.name, book: book)) \(display(fact.value))"
                    return fact.owner == .derived ? label : "\(label) · \(L("owner.\(fact.owner.rawValue)"))"
                }
            }
            if let ruling = line.ruling {
                let answer = openRuling == ruling ? (book.rulingAnswer(ruling) ?? ruling) : nil
                parts.append(answer.map { String(format: L("breakdown.auslegung.open"), $0) } ?? L("breakdown.auslegung"))
            }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
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
