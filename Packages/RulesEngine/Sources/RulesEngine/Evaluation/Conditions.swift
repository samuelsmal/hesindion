import Foundation

/// A `when`'s answer. An unknown fact never becomes yes or no (spec §4.6).
public enum Truth: String, Codable, Hashable, Sendable { case yes, no, unknown }

public struct ConditionResult: Hashable, Sendable {
    public var truth: Truth
    /// Every fact the condition read, in the order it read them, each once.
    public var used: [FactUse]
    /// The facts that keep the answer unknown; empty unless `truth` is `.unknown`. A part that
    /// was unknown inside an `all` another part made no (or an `any` another part made yes) does
    /// not count: its answer changes nothing, so nobody is asked.
    public var unknown: [UnknownFact]

    public init(truth: Truth, used: [FactUse] = [], unknown: [UnknownFact] = []) {
        self.truth = truth; self.used = used; self.unknown = unknown
    }
}

public enum Conditions {
    /// Evaluates `condition` against `situation`.
    ///
    /// - `level`: the effective level of the acting rule, which the fact `level` reads;
    /// - `rule`: the acting rule, whose owned level (when no `level` is passed) and `option` the
    ///   facts `level` and `option` read.
    ///
    /// `all` is no if any part is no, else unknown if any part is unknown, else yes; `any` is
    /// the dual; `not(unknown)` is unknown. `hero.has: X` is yes when the hero owns X, no
    /// otherwise, never unknown. Every other fact nobody stated is unknown (`ally.has` and
    /// `opponent.has` included). `is` against a list-valued fact means contains.
    public static func evaluate(_ condition: Condition, in situation: Situation,
                                level: Int? = nil, rule: String? = nil) -> ConditionResult {
        switch condition {
        case .all(let parts):
            return combine(parts.map { evaluate($0, in: situation, level: level, rule: rule) }, all: true)
        case .any(let parts):
            return combine(parts.map { evaluate($0, in: situation, level: level, rule: rule) }, all: false)
        case .not(let inner):
            var r = evaluate(inner, in: situation, level: level, rule: rule)
            r.truth = switch r.truth {
            case .yes: .no
            case .no: .yes
            case .unknown: .unknown
            }
            return r
        case .fact(let name, let comparison):
            if name == "hero.has" { return heroHas(comparison, situation) }
            guard let use = situation.fact(name, level: level, rule: rule) else {
                return ConditionResult(truth: .unknown, unknown: [UnknownFact(name)])
            }
            return ConditionResult(truth: compare(use.value, comparison) ? .yes : .no, used: [use])
        }
    }

    /// `all` (`decisive` = no) or `any` (`decisive` = yes).
    private static func combine(_ parts: [ConditionResult], all: Bool) -> ConditionResult {
        let decisive: Truth = all ? .no : .yes
        let used = parts.flatMap(\.used).uniqued()
        if parts.contains(where: { $0.truth == decisive }) {
            return ConditionResult(truth: decisive, used: used)
        }
        if parts.contains(where: { $0.truth == .unknown }) {
            return ConditionResult(truth: .unknown, used: used, unknown: parts.flatMap(\.unknown).uniqued())
        }
        return ConditionResult(truth: all ? .yes : .no, used: used)
    }

    /// The sheet is complete: an owned rule is listed in `owned`, and one that is not listed is
    /// not owned. The fact records which of the asked-for rules the hero has.
    private static func heroHas(_ comparison: Comparison, _ s: Situation) -> ConditionResult {
        let asked: [JSONValue] = switch comparison {
        case .is(let v): [v]
        case .in(let vs): vs
        default: []
        }
        let owned = asked.filter { $0.string.map { s.owned[$0] != nil } ?? false }
        return ConditionResult(truth: owned.isEmpty ? .no : .yes,
                               used: [FactUse(name: "hero.has", value: .array(owned), owner: .sheet)])
    }

    /// `is` / `in` compare values (a list-valued fact: any of its entries); the others numbers.
    static func compare(_ value: JSONValue, _ comparison: Comparison) -> Bool {
        let entries: [JSONValue] = if case .array(let a) = value { a } else { [value] }
        switch comparison {
        case .is(let x): return entries.contains { same($0, x) }
        case .in(let xs): return entries.contains { e in xs.contains { same(e, $0) } }
        case .atLeast(let n): return value.double.map { $0 >= n } ?? false
        case .atMost(let n): return value.double.map { $0 <= n } ?? false
        case .above(let n): return value.double.map { $0 > n } ?? false
        case .below(let n): return value.double.map { $0 < n } ?? false
        }
    }

    /// Equal values; 2 and 2.0 are one number.
    static func same(_ a: JSONValue, _ b: JSONValue) -> Bool {
        if let x = a.double, let y = b.double { return x == y }
        return a == b
    }
}

extension Array where Element: Hashable {
    /// Each element once, in the order of its first appearance.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
