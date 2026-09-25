import Foundation

// The normalized forms rulec emits (scripts/rulec/forms.py): targets, operands, values,
// conditions, selectors. Each decodes exactly the JSON shape the compiler writes and encodes
// back to it.

private func corrupt(_ path: [CodingKey], _ message: String) -> DecodingError {
    .dataCorrupted(.init(codingPath: path, debugDescription: message))
}

// MARK: - Targets

/// A target with its context: `pa(with: shield)` is `{"name": "pa", "with": "shield"}`.
public struct TargetRef: Codable, Hashable, Sendable, CustomStringConvertible {
    public var name: String
    /// `with`, `zone`, `index`, `talent`, `spell`, `rule`: the vocabulary's `contexts`.
    public var context: [String: String]

    public init(name: String, context: [String: String] = [:]) {
        self.name = name
        self.context = context
    }

    /// Parses `pa` or `pa(with: shield)`.
    public init(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard let open = t.firstIndex(of: "("), t.hasSuffix(")") else {
            self.init(name: t)
            return
        }
        var context: [String: String] = [:]
        for part in t[t.index(after: open)..<t.index(before: t.endIndex)].split(separator: ",") {
            guard let colon = part.firstIndex(of: ":") else { continue }
            context[part[..<colon].trimmingCharacters(in: .whitespaces)] =
                part[part.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        self.init(name: String(t[..<open]).trimmingCharacters(in: .whitespaces), context: context)
    }

    /// `pa(with: shield)`, or `pa` without a context.
    public var description: String {
        guard !context.isEmpty else { return name }
        return "\(name)(\(context.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: ", ")))"
    }

    /// An effect target with no context reaches every context; one with a context reaches only it.
    public func matches(_ query: TargetRef) -> Bool {
        name == query.name && context.allSatisfy { query.context[$0.key] == $0.value }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        name = try c.decode(String.self, forKey: AnyKey("name"))
        var context: [String: String] = [:]
        for k in c.allKeys where k.stringValue != "name" {
            context[k.stringValue] = try c.decode(String.self, forKey: k)
        }
        self.context = context
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encode(name, forKey: AnyKey("name"))
        for (k, v) in context { try c.encode(v, forKey: AnyKey(k)) }
    }
}

// MARK: - Operands, bounds, values

/// What a proportion reads: `{number}`, `{fact}`, `{target}`, or `{sum: [operands]}`, the sum
/// taken before the proportion's `per` (`(MU + GE) / 2`).
public indirect enum Operand: Codable, Hashable, Sendable {
    case number(Double), fact(String), target(TargetRef), sum([Operand])

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        let key = try c.onlyKey("an operand")
        switch key {
        case "number": self = .number(try c.decode(Double.self, forKey: AnyKey(key)))
        case "fact": self = .fact(try c.decode(String.self, forKey: AnyKey(key)))
        case "target": self = .target(try c.decode(TargetRef.self, forKey: AnyKey(key)))
        case "sum": self = .sum(try c.decode([Operand].self, forKey: AnyKey(key)))
        default: throw corrupt(c.codingPath, "unknown operand \(key)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        switch self {
        case .number(let n): try c.encode(n, forKey: AnyKey("number"))
        case .fact(let f): try c.encode(f, forKey: AnyKey("fact"))
        case .target(let t): try c.encode(t, forKey: AnyKey("target"))
        case .sum(let s): try c.encode(s, forKey: AnyKey("sum"))
        }
    }
}

/// A proportion's `min` or `max`: a plain number (raw in the JSON), an operand, or a list of
/// operands that all hold (`{"each": [...]}`: `max: [10, gsNatural]` is at most 10 and at most
/// the natural GS).
public enum Bound: Codable, Hashable, Sendable {
    case number(Double), operand(Operand), each([Operand])

    public init(from decoder: Decoder) throws {
        if let n = try? decoder.singleValueContainer().decode(Double.self) {
            self = .number(n)
            return
        }
        let c = try decoder.container(keyedBy: AnyKey.self)
        if c.contains(AnyKey("each")) {
            _ = try c.onlyKey("a list of bounds")
            self = .each(try c.decode([Operand].self, forKey: AnyKey("each")))
        } else {
            self = .operand(try Operand(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .number(let n):
            var c = encoder.singleValueContainer()
            try c.encode(n)
        case .operand(let o): try o.encode(to: encoder)
        case .each(let os):
            var c = encoder.container(keyedBy: AnyKey.self)
            try c.encode(os, forKey: AnyKey("each"))
        }
    }
}

/// `max(0, of − above) × times / per`, rounded, then clamped by `min` and `max` (spec §4.4).
public struct Proportion: Codable, Hashable, Sendable {
    public var of: Operand
    public var per: Operand
    public var times: Double
    /// A plain number is raw in the JSON (`"above": 8`); a fact or target is an operand.
    public var above: Operand
    public var round: Rounding
    public var min: Bound?
    public var max: Bound?

    public init(of: Operand, per: Operand = .number(1), times: Double = 1, above: Operand = .number(0),
                round: Rounding = .up, min: Bound? = nil, max: Bound? = nil) {
        self.of = of; self.per = per; self.times = times; self.above = above
        self.round = round; self.min = min; self.max = max
    }

    enum CodingKeys: String, CodingKey { case of, per, times, above, round, min, max }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        of = try c.decode(Operand.self, forKey: .of)
        per = try c.decode(Operand.self, forKey: .per)
        times = try c.decode(Double.self, forKey: .times)
        if let n = try? c.decode(Double.self, forKey: .above) {
            above = .number(n)
        } else {
            above = try c.decode(Operand.self, forKey: .above)
        }
        round = try c.decode(Rounding.self, forKey: .round)
        min = try c.decodeIfPresent(Bound.self, forKey: .min)
        max = try c.decodeIfPresent(Bound.self, forKey: .max)
    }

    /// rulec writes every key, `min` and `max` as null when absent.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(of, forKey: .of)
        try c.encode(per, forKey: .per)
        try c.encode(times, forKey: .times)
        if case .number(let n) = above { try c.encode(n, forKey: .above) } else { try c.encode(above, forKey: .above) }
        try c.encode(round, forKey: .round)
        if let min { try c.encode(min, forKey: .min) } else { try c.encodeNil(forKey: .min) }
        if let max { try c.encode(max, forKey: .max) } else { try c.encodeNil(forKey: .max) }
    }
}

/// The four value forms (spec §4.4).
public enum ValueExpr: Codable, Hashable, Sendable {
    case number(Double)
    /// `times × level + plus`: `level - 1` is `level(times: 1, plus: -1)`.
    case level(times: Int, plus: Int)
    case proportion(Proportion)
    /// The provided table `name`'s entry for the value of the fact `key`.
    case table(name: String, key: String)

    /// The vocabulary's `valueForms`, in its order.
    public static let forms = ["number", "level", "proportion", "table"]

    private struct Level: Codable { var times: Int, plus: Int }
    private struct Table: Codable { var name: String, key: String }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        let key = try c.onlyKey("a value")
        switch key {
        case "number": self = .number(try c.decode(Double.self, forKey: AnyKey(key)))
        case "level":
            let l = try c.decode(Level.self, forKey: AnyKey(key))
            self = .level(times: l.times, plus: l.plus)
        case "proportion": self = .proportion(try c.decode(Proportion.self, forKey: AnyKey(key)))
        case "table":
            let t = try c.decode(Table.self, forKey: AnyKey(key))
            self = .table(name: t.name, key: t.key)
        default: throw corrupt(c.codingPath, "value outside the four forms: \(key)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        switch self {
        case .number(let n): try c.encode(n, forKey: AnyKey("number"))
        case .level(let times, let plus): try c.encode(Level(times: times, plus: plus), forKey: AnyKey("level"))
        case .proportion(let p): try c.encode(p, forKey: AnyKey("proportion"))
        case .table(let name, let key): try c.encode(Table(name: name, key: key), forKey: AnyKey("table"))
        }
    }
}

// MARK: - Conditions

/// A `when` (spec §4.6): `{all}`, `{any}`, `{not}`, or `{fact, <comparison>: arg}`.
public indirect enum Condition: Codable, Hashable, Sendable {
    case all([Condition]), any([Condition]), not(Condition)
    case fact(name: String, comparison: Comparison)

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        if c.contains(AnyKey("fact")) {
            let name = try c.decode(String.self, forKey: AnyKey("fact"))
            let ops = c.allKeys.filter { $0.stringValue != "fact" }
            guard ops.count == 1, let op = ops.first else {
                throw corrupt(c.codingPath, "\(name) needs exactly one comparison")
            }
            self = .fact(name: name, comparison: try Comparison(op.stringValue, c, op))
            return
        }
        let key = try c.onlyKey("a condition")
        switch key {
        case "all": self = .all(try c.decode([Condition].self, forKey: AnyKey(key)))
        case "any": self = .any(try c.decode([Condition].self, forKey: AnyKey(key)))
        case "not": self = .not(try c.decode(Condition.self, forKey: AnyKey(key)))
        default: throw corrupt(c.codingPath, "unknown condition \(key)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        switch self {
        case .all(let cs): try c.encode(cs, forKey: AnyKey("all"))
        case .any(let cs): try c.encode(cs, forKey: AnyKey("any"))
        case .not(let n): try c.encode(n, forKey: AnyKey("not"))
        case .fact(let name, let comparison):
            try c.encode(name, forKey: AnyKey("fact"))
            try comparison.encode(into: &c)
        }
    }
}

/// How a fact is compared: the vocabulary's `comparisons`.
public enum Comparison: Hashable, Sendable {
    case `is`(JSONValue), `in`([JSONValue]), atLeast(Double), atMost(Double), above(Double), below(Double)

    /// The vocabulary's `comparisons`, in its order.
    public static let names = ["is", "in", "atLeast", "atMost", "above", "below"]

    public var name: String {
        switch self {
        case .is: "is"
        case .in: "in"
        case .atLeast: "atLeast"
        case .atMost: "atMost"
        case .above: "above"
        case .below: "below"
        }
    }

    init(_ op: String, _ c: KeyedDecodingContainer<AnyKey>, _ key: AnyKey) throws {
        switch op {
        case "is": self = .is(try c.decode(JSONValue.self, forKey: key))
        case "in": self = .in(try c.decode([JSONValue].self, forKey: key))
        case "atLeast": self = .atLeast(try c.decode(Double.self, forKey: key))
        case "atMost": self = .atMost(try c.decode(Double.self, forKey: key))
        case "above": self = .above(try c.decode(Double.self, forKey: key))
        case "below": self = .below(try c.decode(Double.self, forKey: key))
        default: throw corrupt(c.codingPath, "unknown comparison \(op)")
        }
    }

    func encode(into c: inout KeyedEncodingContainer<AnyKey>) throws {
        let key = AnyKey(name)
        switch self {
        case .is(let v): try c.encode(v, forKey: key)
        case .in(let vs): try c.encode(vs, forKey: key)
        case .atLeast(let n), .atMost(let n), .above(let n), .below(let n): try c.encode(n, forKey: key)
        }
    }
}

// MARK: - Selectors and references

/// One id a selector names: a name (`pa`, `RULE.CLAUSE`, `opponent.weaponParry`), or a match on
/// a rule's properties (`manoeuvre: { kind: spezialmanoever, mountedCombat: false }` picks the
/// manoeuvres whose rule has that `manoeuvre` map).
public enum SelectorID: Codable, Hashable, Sendable {
    case id(String)
    case match([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .id(s) } else { self = .match(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .id(let s): try c.encode(s)
        case .match(let m): try c.encode(m)
        }
    }

    public var id: String? { if case .id(let s) = self { s } else { nil } }
}

/// `{ defence: [pa, aw] }` is `{"kind": "defence", "ids": ["pa", "aw"]}`.
public struct RuleSelector: Codable, Hashable, Sendable {
    public var kind: SelectorKind
    public var ids: [SelectorID]
    /// A check's attributes or a narrowing (`{ talent: X, with: [MU, KL] }`). The JSON holds one
    /// string or a list; one entry is written back as a string.
    public var with: [String]? = nil

    enum CodingKeys: String, CodingKey { case kind, ids, with }

    public init(kind: SelectorKind, ids: [SelectorID], with: [String]? = nil) {
        self.kind = kind; self.ids = ids; self.with = with
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(SelectorKind.self, forKey: .kind)
        ids = try c.decode([SelectorID].self, forKey: .ids)
        if !c.contains(.with) {
            with = nil
        } else if let one = try? c.decode(String.self, forKey: .with) {
            with = [one]
        } else {
            with = try c.decode([String].self, forKey: .with)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encode(ids, forKey: .ids)
        if let with {
            if with.count == 1 { try c.encode(with[0], forKey: .with) } else { try c.encode(with, forKey: .with) }
        }
    }
}

/// A clause by its qualified name, `RULE.CLAUSE` (a line selector's id).
public struct ClauseRef: Codable, Hashable, Sendable, CustomStringConvertible {
    public var rule: String
    public var clause: String

    public init(rule: String, clause: String) { self.rule = rule; self.clause = clause }

    /// Splits `RULE.CLAUSE` at its last dot; nil without one.
    public init?(_ text: String) {
        guard let dot = text.lastIndex(of: "."), dot != text.startIndex, text.index(after: dot) != text.endIndex else { return nil }
        self.init(rule: String(text[..<dot]), clause: String(text[text.index(after: dot)...]))
    }

    public var description: String { "\(rule).\(clause)" }
}

/// A `rule` field: a rule id, or `table(name, key)`, the rule a provided table names for the
/// value of the fact `key` (the Wundeffekt by hit zone).
public enum RuleRef: Codable, Hashable, Sendable {
    case id(String)
    case table(name: String, key: String)

    private struct Table: Codable { var name: String, key: String }
    private enum CodingKeys: String, CodingKey { case table }

    public init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            self = .id(s)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let t = try c.decode(Table.self, forKey: .table)
        self = .table(name: t.name, key: t.key)
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .id(let s):
            var c = encoder.singleValueContainer()
            try c.encode(s)
        case .table(let name, let key):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(Table(name: name, key: key), forKey: .table)
        }
    }
}
