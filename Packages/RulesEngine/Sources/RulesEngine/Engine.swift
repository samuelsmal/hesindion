import Foundation

/// The evaluator: `(Query, Situation) → Breakdown` (spec §5). Pure: it holds only the book and
/// keeps nothing between calls. Each call builds its own `Evaluation`, whose memos (which rules
/// apply, the rules' levels before any useLevel) are shared by the nested evaluations of that call
/// only.
public struct Engine: Sendable {
    public let book: RuleBook

    public init(book: RuleBook) { self.book = book }

    /// Runs the phases on the effects that reach `query`. Every line carries its origin, `via`,
    /// the decided rulings it rests on and the facts it read with their owners (§5.5). The
    /// breakdown also holds the offers that reach the query, its questions and texts, and
    /// whether its action is legal. Never throws: what cannot be computed is a question or a
    /// text (§11).
    public func evaluate(_ query: Query, in situation: Situation) -> Breakdown {
        evaluation(situation).breakdown(query, depth: 0)
    }

    /// Every offer in the book whose rule applies and whose `when` is not no (read without a
    /// query: `query.target` is unknown), in rule-id and clause order. Each says whether it is
    /// legal (and every entry refusing it), its bound (`max`), its refused options, its `span`
    /// and its `costs`.
    public func offers(in situation: Situation) -> [OfferedChoice] {
        evaluation(situation).allOffers()
    }

    /// One call's evaluation of the situation as the rules read it: a choice it takes that is
    /// not legal (forbidden, a requirement unmet, beyond a limit) is not taken (MIGRATION
    /// probe-magie 20.4). When it takes none such, the evaluation that checked is the one used.
    private func evaluation(_ situation: Situation) -> Evaluation {
        let raw = Evaluation(book: book, situation: situation)
        guard situation.facts.keys.contains(where: { $0.hasPrefix("choice.") }),
              let taken = raw.withoutRefusedChoices() else { return raw }
        return Evaluation(book: book, situation: taken)
    }
}
