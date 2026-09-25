import Foundation

// The four value forms (spec §4.5): a number, `times × level + plus`, a proportion, a table
// lookup. Each evaluation reports the facts it read, the facts it needed and nobody stated, and
// the clauses behind every target it read (ruling R26).

// MARK: - Targets an operand reads

/// A target an operand reads (`wundschwelle`, `spell.cost`, `check.fp`), as the evaluator
/// computed it.
///
/// Why this shape: a value that reads a target does not own that target's breakdown, but its
/// line has to name the rules behind it. Ruling R26 puts the rules whose lines changed the
/// operand's breakdown into the reading line's `via`, and the line's facts include the facts the
/// operand read. So the resolver hands back, besides the number, exactly what a line needs:
/// - `value`: the target's result, nil when it cannot be computed;
/// - `contributors`: the origins of the lines that make up the target's breakdown, which join
///   `via`: the clauses that set its base (the base's parts), then the origin of every line after
///   the base, each once, in that order;
/// - `used` / `unknown`: the facts the target's evaluation read, and the ones it lacked. An
///   unknown here makes the reading value nil and asks the same question;
/// - `depthExceeded`: the target's evaluation hit the depth guard somewhere below.
public struct ResolvedTarget: Hashable, Sendable {
    public var value: Int?
    public var contributors: [ClauseRef]
    public var used: [FactUse]
    public var unknown: [UnknownFact]
    public var depthExceeded: Bool

    public init(value: Int?, contributors: [ClauseRef] = [], used: [FactUse] = [], unknown: [UnknownFact] = [],
                depthExceeded: Bool = false) {
        self.value = value; self.contributors = contributors; self.used = used
        self.unknown = unknown; self.depthExceeded = depthExceeded
    }
}

/// Evaluates a target an operand or a table key reads. `depth` is the nesting of the evaluation
/// being asked for (1 for a target the top-level value reads); the resolver passes it on as the
/// `depth` of the `Values.evaluate` calls it makes, so a target that reads itself stops at
/// `Values.maxDepth` instead of recursing forever. The evaluator (Task 22) implements it by
/// running the target's own query.
public typealias TargetResolver = (_ target: TargetRef, _ depth: Int) -> ResolvedTarget

public struct ValueResult: Hashable, Sendable {
    /// nil when a fact is unknown, a target cannot be computed, a table has no entry for the key,
    /// or the depth guard stopped a target.
    public var value: Int?
    public var used: [FactUse]
    public var unknown: [UnknownFact]
    /// The contributors of every target read (R26), each once, in reading order.
    public var via: [ClauseRef]
    public var depthExceeded: Bool

    public init(value: Int?, used: [FactUse] = [], unknown: [UnknownFact] = [], via: [ClauseRef] = [],
                depthExceeded: Bool = false) {
        self.value = value; self.used = used; self.unknown = unknown; self.via = via; self.depthExceeded = depthExceeded
    }
}

public enum Values {
    /// How deep targets may nest: a target read at depth 9 gives nil.
    public static let maxDepth = 8

    /// Evaluates `value` in `situation`.
    ///
    /// - `level`: the effective level of the acting rule (`level - 1`); without one, the acting
    ///   `rule`'s owned level; without either, the fact `level` is unknown.
    /// - A proportion is `max(0, of − above) × times / per`, rounded as stated, then clamped by
    ///   `min` and `max` (each bound of a list clamps). The rounding rounds the magnitude: a
    ///   rounded multiply by −1 gives −1 for −1.75 rounded down.
    /// - `table(name, key)` is `Tables.lookup`, which must give a number.
    ///
    /// Everything is computed in `Double` and rounded once, at the end.
    public static func evaluate(_ value: ValueExpr, level: Int?, in situation: Situation, book: RuleBook,
                                rule: String? = nil, depth: Int = 0, resolve: TargetResolver) -> ValueResult {
        var t = Trace(situation: situation, level: level, rule: rule, depth: depth)
        let v: Double?
        switch value {
        case .number(let n):
            v = n
        case .level(let times, let plus):
            v = t.fact("level")?.double.map { Double(times) * $0 + Double(plus) }
        case .proportion(let p):
            v = proportion(p, &t, resolve)
        case .table(let name, let key):
            v = Tables.entry(name, key: key, book: book, &t, resolve)?.double
        }
        return t.result(v.map { Int(round($0, .up)) })
    }

    private static func proportion(_ p: Proportion, _ t: inout Trace, _ resolve: TargetResolver) -> Double? {
        // Every operand is read, so every unknown fact is reported at once.
        let of = t.operand(p.of, resolve)
        let per = t.operand(p.per, resolve)
        let above = t.operand(p.above, resolve)
        let mins = p.min.map { t.bound($0, resolve) }
        let maxes = p.max.map { t.bound($0, resolve) }
        guard let of, let per, let above, per != 0 else { return nil }
        var x = round(Swift.max(0, of - above) * p.times / per, p.round)
        if let mins {
            guard let mins else { return nil }
            for m in mins { x = Swift.max(x, m) }
        }
        if let maxes {
            guard let maxes else { return nil }
            for m in maxes { x = Swift.min(x, m) }
        }
        return round(x, p.round)
    }

    /// Rounds the magnitude, keeping the sign. A whole number (to 1e-9) stays as it is, so
    /// binary noise (2.0000000001) never rounds up.
    static func round(_ x: Double, _ rounding: Rounding) -> Double {
        let magnitude = (abs(x) * 1e9).rounded() / 1e9
        let r = rounding == .up ? magnitude.rounded(.up) : magnitude.rounded(.down)
        return x < 0 ? -r : r
    }
}

// MARK: - Tables

public struct TableResult: Hashable, Sendable {
    /// The entry: a number, or a rule id, zone or label for a table of names.
    public var value: JSONValue?
    public var used: [FactUse]
    public var unknown: [UnknownFact]
    /// The key target's contributors, then the providing clause.
    public var via: [ClauseRef]
    public var depthExceeded: Bool
    /// The `provide` the table was read from; nil when no row was found.
    public var provider: EffectOrigin?
}

public struct RowResult: Hashable, Sendable {
    public var row: JSONValue?
    public var used: [FactUse]
    public var unknown: [UnknownFact]
}

public enum Tables {
    /// `table(name, key)`: the entry of the provided table `name` for the value of `key`.
    ///
    /// `key` names a fact, or a target (`check.fp`, `armourScore`), which `resolve` computes.
    /// An exact key wins; a number otherwise matches a range key, `"0-3"` or `"16+"`. An
    /// unknown key fact gives nil and that fact; a key the table does not list gives nil and no
    /// question.
    public static func lookup(_ name: String, key: String, level: Int?, in situation: Situation, book: RuleBook,
                              rule: String? = nil, depth: Int = 0, resolve: TargetResolver) -> TableResult {
        var t = Trace(situation: situation, level: level, rule: rule, depth: depth)
        let v = entry(name, key: key, book: book, &t, resolve)
        return TableResult(value: v, used: t.used, unknown: t.unknown, via: t.via, depthExceeded: t.depthExceeded,
                           provider: t.provider)
    }

    /// The table `name` as `situation` reads it.
    ///
    /// One non-equipment rule providing it: its value. An equipment rule providing it (each
    /// weapon its `loadout.weapon` row): the row of the equipped item, never the first. The
    /// item is the one the loadout fact above `name` names (`loadout.weapon` for
    /// `loadout.weapon`, `loadout.shield` for `loadout.shield.size`), and its template is the
    /// fact `item.<item>.template`: the rule with that id gives the row. Either fact unknown:
    /// nil and that fact. An empty hand (`null`), or a template no rule provides the name for:
    /// nil. A `provide`'s value `provides` is the rule's own `provides` row.
    public static func row(_ name: String, in situation: Situation, book: RuleBook) -> RowResult {
        var t = Trace(situation: situation, level: nil, rule: nil, depth: 0)
        let row = row(name, book: book, &t)?.value
        return RowResult(row: row, used: t.used, unknown: t.unknown)
    }

    /// The entry, with the providing clause joining `via` (table provenance).
    static func entry(_ name: String, key: String, book: RuleBook, _ t: inout Trace,
                      _ resolve: TargetResolver) -> JSONValue? {
        let target = TargetRef(key)
        let keyValue: JSONValue? = Vocabulary.targets.contains(target.name)
            ? t.target(target, resolve).map { .int($0) }
            : t.fact(key)
        let found = row(name, book: book, &t)
        if let origin = found?.origin {
            t.provider = origin
            if !t.via.contains(origin.clauseRef) { t.via.append(origin.clauseRef) }
        }
        guard let keyValue, case .object(let entries)? = found?.value else { return nil }
        if let exact = text(keyValue), let v = entries[exact] { return v }
        guard let n = keyValue.double else { return nil }
        return entries.keys.sorted().first { range($0)?.contains(n) ?? false }.flatMap { entries[$0] }
    }

    /// The value read and the `provide` it came from.
    static func row(_ name: String, book: RuleBook, _ t: inout Trace) -> (value: JSONValue, origin: EffectOrigin)? {
        let providers = book.providers(of: name)
        func value(_ p: Provision) -> (value: JSONValue, origin: EffectOrigin)? {
            if p.value == .string("provides") { return book.rules[p.rule].map { (.object($0.provides), p.origin) } }
            return (p.value, p.origin)
        }
        guard providers.contains(where: { book.rules[$0.rule]?.kind == .equipment }) else {
            // Several non-equipment rules under one name: nothing says whose to read.
            return providers.count == 1 ? value(providers[0]) : nil
        }
        let parts = name.split(separator: ".")
        let naming = (1...parts.count).lazy.map { parts.prefix($0).joined(separator: ".") }
            .first { Vocabulary.facts[$0] == .loadout }
        guard let naming, let item = t.fact(naming) else { return nil }
        guard let itemName = item.string else { return nil }             // nothing in that slot
        guard let template = t.fact("item.\(itemName).template")?.string else { return nil }
        return providers.first { $0.rule == template }.flatMap(value)
    }

    /// A key's text: `klein`, `3`, `true`.
    private static func text(_ v: JSONValue) -> String? {
        switch v {
        case .string(let s): s
        case .int(let i): String(i)
        case .double(let d): v.int.map(String.init) ?? String(d)
        case .bool(let b): String(b)
        default: nil
        }
    }

    /// `"0-3"` → 0...3, `"16+"` → 16...; a plain number (`"-1"`) is no range.
    private static func range(_ key: String) -> ClosedRange<Double>? {
        if key.hasSuffix("+"), let low = Int(key.dropLast()) { return Double(low)...Double.infinity }
        guard let dash = key.dropFirst().firstIndex(of: "-"),
              let low = Int(key[..<dash]), let high = Int(key[key.index(after: dash)...]), low <= high else { return nil }
        return Double(low)...Double(high)
    }
}

// MARK: - What an evaluation read

/// The facts, unknowns and contributors one evaluation collects.
struct Trace {
    let situation: Situation
    let level: Int?
    let rule: String?
    let depth: Int
    var used: [FactUse] = []
    var unknown: [UnknownFact] = []
    var via: [ClauseRef] = []
    var depthExceeded = false
    /// The `provide` the last table read came from.
    var provider: EffectOrigin?

    init(situation: Situation, level: Int?, rule: String?, depth: Int) {
        self.situation = situation; self.level = level; self.rule = rule; self.depth = depth
    }

    /// A fact's value, recorded as used; nil and recorded as unknown when nobody stated it.
    mutating func fact(_ name: String) -> JSONValue? {
        guard let use = situation.fact(name, level: level, rule: rule) else {
            add(unknown: [UnknownFact(name)])
            return nil
        }
        if !used.contains(use) { used.append(use) }
        return use.value
    }

    /// A target through the resolver, one level deeper; nil beyond `Values.maxDepth`.
    mutating func target(_ target: TargetRef, _ resolve: TargetResolver) -> Int? {
        guard depth < Values.maxDepth else {
            depthExceeded = true
            return nil
        }
        let r = resolve(target, depth + 1)
        for u in r.used where !used.contains(u) { used.append(u) }
        add(unknown: r.unknown)
        for c in r.contributors where !via.contains(c) { via.append(c) }
        depthExceeded = depthExceeded || r.depthExceeded
        return r.value
    }

    mutating func operand(_ o: Operand, _ resolve: TargetResolver) -> Double? {
        switch o {
        case .number(let n): return n
        case .fact(let name): return fact(name)?.double
        case .target(let ref): return target(ref, resolve).map(Double.init)
        case .sum(let parts):
            let values = parts.map { operand($0, resolve) }
            return values.contains(where: { $0 == nil }) ? nil : values.reduce(0) { $0 + $1! }
        }
    }

    /// A bound's values, all of which clamp; nil when one of them is unknown.
    mutating func bound(_ b: Bound, _ resolve: TargetResolver) -> [Double]? {
        switch b {
        case .number(let n): return [n]
        case .operand(let o): return operand(o, resolve).map { [$0] }
        case .each(let os):
            let values = os.map { operand($0, resolve) }
            return values.contains(where: { $0 == nil }) ? nil : values.map { $0! }
        }
    }

    mutating func add(unknown more: [UnknownFact]) {
        for u in more where !unknown.contains(u) { unknown.append(u) }
    }

    func result(_ value: Int?) -> ValueResult {
        ValueResult(value: value, used: used, unknown: unknown, via: via, depthExceeded: depthExceeded)
    }
}
