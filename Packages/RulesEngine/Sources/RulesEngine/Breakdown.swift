import Foundation

// What `Engine.evaluate` returns (spec §5.3): the lines that make up one target's value, each
// with its provenance (§5.5), and what did not apply, what is offered, asked and shown.

/// One target in one context: `at`, `pa(with: shield)`, `level(rule: COND_6)`.
public struct Query: Hashable, Sendable, CustomStringConvertible {
    public var target: TargetRef

    public init(_ target: TargetRef) { self.target = target }
    /// Parses `pa` or `pa(with: shield)`.
    public init(_ text: String) { self.init(TargetRef(text)) }

    public var name: String { target.name }
    /// `pa(with: shield)`: the key of `Situation.base` and of a situation's `expect`.
    public var description: String { target.description }
}

/// One step of a value, with where it comes from.
///
/// `value` is always what the line adds to the total (the step), so `Breakdown.total` is the sum
/// of the lines' values, the shown lines sum to `result`, and no number changes without a line.
/// A line that states a value rather than a step also carries `was` and `now`:
/// - `set`, a scale step, `.multiplied` (no `line`), `.capped` (no `over`), `.floored`: the
///   query's running value before and after it;
/// - `.multiplied` with a `line`, `.capped` with an `over`: the sum of the lines it scaled or
///   bounded, before and after;
/// - `.levelAs`: the rule's level before and after the useLevel (not the query's value);
/// - `.replaced`: the value the line would have had (nil when that could not be computed) and
///   the one it has. It keeps its origin; the replacing clause is in `via`.
public struct Line: Hashable, Sendable {
    public var value: Int
    public var kind: LineKind
    /// The clause that gave the line; nil for a value the sheet states.
    public var origin: ClauseRef?
    /// The clauses the line rests on besides its origin, each once, in this order: the require that
    /// enabled the rule, the useLevels that acted on the rule (R28), the contributors of every
    /// target operand read (R26), and the clause providing a table or scale read.
    public var via: [ClauseRef]
    /// The decided rulings the line rests on (→ *Auslegung*), qualified (`RULE.id`, `shared.id`).
    public var rulings: [String]
    /// Every fact the line read, with its value and who stated it.
    public var facts: [FactUse]
    /// Who stated the line's number when it is no rule's: `sheet` for a base from the sheet,
    /// `player` for a modifier typed in (`.free`), `gm` for the GM's. nil for a rule's line.
    public var owner: Owner?
    public var note: String?
    public var was: Int?
    public var now: Int?
    /// The name of the option a line belongs to when one clause gives several lines (MIGRATION
    /// "term"); not filled in yet.
    public var term: String?
    /// A base's terms: one line per `sum` term of each `derive` that made it (KW1's KtW and its
    /// MU bonus). Empty for any other line. A `suppress` of a derive drops its parts; a `replace`
    /// of one gives a single `.replaced` part (R35).
    public var parts: [Line]

    public init(value: Int, kind: LineKind, origin: ClauseRef? = nil, via: [ClauseRef] = [], rulings: [String] = [],
                facts: [FactUse] = [], owner: Owner? = nil, note: String? = nil, was: Int? = nil, now: Int? = nil,
                term: String? = nil, parts: [Line] = []) {
        self.value = value; self.kind = kind; self.origin = origin; self.via = via; self.rulings = rulings
        self.facts = facts; self.owner = owner; self.note = note; self.was = was; self.now = now
        self.term = term; self.parts = parts
    }

    /// The first decided ruling the line rests on.
    public var ruling: String? { rulings.first }
}

/// An effect of a rule that reaches the query and did not fire, and why.
public struct NotApplied: Hashable, Sendable {
    public var origin: ClauseRef
    public var reason: ReasonCode
    /// The effect's own `because`, or what overrode it (`overridden`: the winning clause).
    public var because: String?
    public var rulings: [String]
    /// The facts its `when` read.
    public var facts: [FactUse]
    /// The clauses that acted on its rule (enabling require, useLevels), as a line of it would carry.
    public var via: [ClauseRef]
    /// The value it would have given (`replaced`, and a suppressed `add`); nil when it was never
    /// computed.
    public var value: Int?

    public init(origin: ClauseRef, reason: ReasonCode, because: String? = nil, rulings: [String] = [],
                facts: [FactUse] = [], via: [ClauseRef] = [], value: Int? = nil) {
        self.origin = origin; self.reason = reason; self.because = because; self.rulings = rulings
        self.facts = facts; self.via = via; self.value = value
    }

    public var rule: String { origin.rule }
    public var clause: String { origin.clause }
}

/// A fact nobody stated whose answer would change the result, and who is asked for it.
public struct Question: Hashable, Sendable {
    public var fact: String
    public var owner: Owner?
    /// The clauses that need it, each once.
    public var origins: [ClauseRef]
    /// The answers an `ask` offers.
    public var options: [JSONValue]?

    public init(fact: String, owner: Owner?, origins: [ClauseRef] = [], options: [JSONValue]? = nil) {
        self.fact = fact; self.owner = owner; self.origins = origins; self.options = options
    }
}

/// Text the screen shows: a `tell`, an unencoded clause, an open ruling, or a rule that could not
/// be applied.
public struct TextLine: Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable, CaseIterable {
        /// A `tell`, to its audience.
        case tell
        /// An unencoded clause of an applicable rule that reaches the query.
        case unencoded
        /// An effect resting on an open ruling: its clause text, and the ruling's question.
        case openRuling
        /// "Regel konnte nicht angewandt werden: RULE.CLAUSE – reason" (spec §11).
        case notApplicable
    }

    public var kind: Kind
    public var audience: Audience
    public var text: String
    public var origin: ClauseRef?
    /// The open ruling (`openRuling`).
    public var ruling: String?
    /// The open ruling's question (`openRuling`).
    public var question: String?

    public init(kind: Kind, audience: Audience = .player, text: String, origin: ClauseRef? = nil,
                ruling: String? = nil, question: String? = nil) {
        self.kind = kind; self.audience = audience; self.text = text; self.origin = origin
        self.ruling = ruling; self.question = question
    }
}

/// A choice the query could take (`offer`). Named so, not to shadow the `Offer` payload.
public struct OfferedChoice: Hashable, Sendable {
    public var choice: String
    public var origin: ClauseRef
    public var options: [JSONValue]?
    public var `default`: JSONValue?
    public var span: Span?
    /// Paid when the offer is taken (ruling R23); the action layer charges them.
    public var costs: [Effect]
    public var rulings: [String]
    /// The clauses the offering rule rests on (its enabling require, the useLevels on it).
    public var via: [ClauseRef]
    /// false when a `forbid` on the choice (or on the offering rule's manoeuvre kind) fires, a
    /// `require` for it (or the offering rule's own `require`) is not met, or a `limit` on it is
    /// reached. Every such entry is in `reasons`.
    public var legal: Bool
    /// The first reason's `because`, else its clause (`RULE.CLAUSE`).
    public var because: String?
    public var reasons: [NotApplied]
    /// How many of `options` may be taken: the `max` of the `limit` naming the most of them
    /// (zaubermodifikationen.ZM1: FW 9 → 2); for a `split.<pool>` choice, the offering rule's split
    /// cost less the other pools' minimums (SA_74.VP1: 8 − 1 AsP = 7). nil without either.
    public var max: Int?
    /// The options that may not be taken (another one), each with the entries refusing it.
    public var refused: [RefusedOption]

    public init(choice: String, origin: ClauseRef, options: [JSONValue]? = nil, default: JSONValue? = nil,
                span: Span? = nil, costs: [Effect] = [], rulings: [String] = [], via: [ClauseRef] = [],
                reasons: [NotApplied] = [], max: Int? = nil, refused: [RefusedOption] = []) {
        self.choice = choice; self.origin = origin; self.options = options; self.default = `default`
        self.span = span; self.costs = costs; self.rulings = rulings; self.via = via
        self.legal = reasons.isEmpty; self.because = reasons.first.map { $0.because ?? $0.origin.description }
        self.reasons = reasons; self.max = max; self.refused = refused
    }
}

/// An option of an offered choice that may not be taken, and why (a `forbid` of `choice.option`,
/// a `limit` whose count is reached).
public struct RefusedOption: Hashable, Sendable {
    public var option: JSONValue
    public var reasons: [NotApplied]

    public init(option: JSONValue, reasons: [NotApplied]) { self.option = option; self.reasons = reasons }
}

/// Whether the action the query stands for is allowed, and every entry that forbids it: each
/// firing `forbid` (`forbidden`), unmet `require` (`requirementNotMet`) and reached `limit`
/// (`forbidden`), in rule-id and clause order. Several may fire at once (reiterkampf.RK13 and
/// groessenkategorie.GK4 on one parry); all are kept.
public struct Legality: Hashable, Sendable {
    public var allowed: Bool
    public var reasons: [NotApplied]

    public init(allowed: Bool = true, reasons: [NotApplied] = []) { self.allowed = allowed; self.reasons = reasons }

    /// Each reason's `because`, else its clause (`RULE.CLAUSE`).
    public var because: [String] { reasons.map { $0.because ?? $0.origin.description } }
}

public struct Breakdown: Hashable, Sendable {
    public var query: Query
    /// The value the rest builds on: the sheet's, or the sum of the base-phase `derive`s (their
    /// terms in `parts`). nil when neither gives one.
    public var base: Line?
    /// Every line after the base, in phase order.
    public var lines: [Line]
    public var notApplied: [NotApplied]
    public var offers: [OfferedChoice]
    public var questions: [Question]
    public var texts: [TextLine]
    public var legal: Legality
    /// Some operand of this breakdown hit the depth guard (`Values.maxDepth`).
    public var depthExceeded: Bool

    public init(query: Query, base: Line? = nil, lines: [Line] = [], notApplied: [NotApplied] = [],
                offers: [OfferedChoice] = [], questions: [Question] = [], texts: [TextLine] = [],
                legal: Legality = Legality(), depthExceeded: Bool = false) {
        self.query = query; self.base = base; self.lines = lines; self.notApplied = notApplied
        self.offers = offers; self.questions = questions; self.texts = texts; self.legal = legal
        self.depthExceeded = depthExceeded
    }

    /// The sum of `lines`, without the base.
    public var total: Int { lines.reduce(0) { $0 + $1.value } }
    /// `base + total`; nil without a base.
    public var result: Int? { base.map { $0.value + total } }

    /// Every line a screen lists, in order: the base's parts (or the base itself when it has
    /// none), then `lines`.
    public var shownLines: [Line] {
        guard let base else { return lines }
        return (base.parts.isEmpty ? [base] : base.parts) + lines
    }
}
