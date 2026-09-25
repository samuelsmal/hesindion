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

    /// The hero sheet (Task 30): the breakdown of no target, which only the effects every query
    /// sees reach (the reach index's `"*"`): the tells the player is shown whatever is asked, the
    /// offers, the questions, the unencoded clauses, and the entries of those that do not apply
    /// (ADV_75.SW1's "nur durch Alkohol verursacht"). It has no base and no lines.
    public func sheet(in situation: Situation) -> Breakdown {
        evaluation(situation).breakdown(Query(Self.sheetQuery), depth: 0)
    }

    /// Whether the pieces `ids` name may be carried (Task 30, the loadout screen): every top-level
    /// `forbid` of kind `loadout` naming one of them (`secondArmour`, `other`) whose rule applies
    /// and whose `when` is yes refuses it (`forbidden`), as does a `require` for one whose `that`
    /// is no (`requirementNotMet`). An unknown `when` or `that` refuses nothing and is not asked.
    public func legality(ofLoadout ids: [String], in situation: Situation) -> Legality {
        evaluation(situation).loadoutLegality(Set(ids))
    }

    /// The name of the sheet's query: no target, so every `"*"` effect and nothing else reaches it.
    public static let sheetQuery = "sheet"

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
    func evaluation(_ situation: Situation) -> Evaluation {
        let raw = Evaluation(book: book, situation: situation)
        guard situation.facts.keys.contains(where: { $0.hasPrefix("choice.") }),
              let taken = raw.withoutRefusedChoices() else { return raw }
        return Evaluation(book: book, situation: taken)
    }
}
