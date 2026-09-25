import Foundation

/// The evaluator: `(Query, Situation) → Breakdown` (spec §5). Pure: it holds only the book and
/// keeps nothing between calls. Each call builds its own `Evaluation`, whose memos (which rules
/// apply, the rules' levels before any useLevel) are shared by the nested evaluations of that call
/// only.
public struct Engine: Sendable {
    public let book: RuleBook

    public init(book: RuleBook) { self.book = book }

    /// Runs the phases on the effects that reach `query`. Every line carries its origin, `via`,
    /// the decided rulings it rests on and the facts it read with their owners (§5.5).
    public func evaluate(_ query: Query, in situation: Situation) -> Breakdown {
        Evaluation(book: book, situation: situation).breakdown(query, depth: 0)
    }
}
