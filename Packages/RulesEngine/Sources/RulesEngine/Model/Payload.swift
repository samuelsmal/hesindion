import Foundation

// One struct per verb. Each mirrors `specs/rules/vocabulary.json`'s `fields` (non-optional) and
// `optional` (optional, or an empty list for `effects` and `pools`) one to one. A missing field
// fails the decode; `Effect` picks the struct by switching on `verb`.

/// One effect's verb and its typed payload.
public enum Payload: Hashable, Sendable {
    case add(Add), set(SetValue), multiply(Multiply), cap(Cap), floor(Floor), useLevel(UseLevel)
    case replace(Replace), suppress(Suppress), forbid(Forbid), require(Require), limit(Limit)
    case offer(Offer), ask(Ask), tell(Tell), provide(Provide), derive(Derive)
    case check(Check), gain(Gain), cost(Cost), process(Process), item(ItemChange), reroll(Reroll)

    public var verb: Verb {
        switch self {
        case .add: .add
        case .set: .set
        case .multiply: .multiply
        case .cap: .cap
        case .floor: .floor
        case .useLevel: .useLevel
        case .replace: .replace
        case .suppress: .suppress
        case .forbid: .forbid
        case .require: .require
        case .limit: .limit
        case .offer: .offer
        case .ask: .ask
        case .tell: .tell
        case .provide: .provide
        case .derive: .derive
        case .check: .check
        case .gain: .gain
        case .cost: .cost
        case .process: .process
        case .item: .item
        case .reroll: .reroll
        }
    }

    /// The effects this payload runs itself (`check.onSuccess`/`onFailure`, `offer.costs`,
    /// `process.completes`), by field name.
    public var nested: [(field: String, effects: [Effect])] {
        switch self {
        case .check(let c): [("onSuccess", c.onSuccess), ("onFailure", c.onFailure)]
        case .offer(let o): [("costs", o.costs)]
        case .process(let p): [("completes", p.completes)]
        default: []
        }
    }

    // Written by hand, one case per verb, so that each verb's struct decodes its own fields.
    static func decode(_ verb: Verb, from c: KeyedDecodingContainer<Effect.CodingKeys>) throws -> Payload {
        let k = Effect.CodingKeys.payload
        switch verb {
        case .add: return .add(try c.decode(Add.self, forKey: k))
        case .set: return .set(try c.decode(SetValue.self, forKey: k))
        case .multiply: return .multiply(try c.decode(Multiply.self, forKey: k))
        case .cap: return .cap(try c.decode(Cap.self, forKey: k))
        case .floor: return .floor(try c.decode(Floor.self, forKey: k))
        case .useLevel: return .useLevel(try c.decode(UseLevel.self, forKey: k))
        case .replace: return .replace(try c.decode(Replace.self, forKey: k))
        case .suppress: return .suppress(try c.decode(Suppress.self, forKey: k))
        case .forbid: return .forbid(try c.decode(Forbid.self, forKey: k))
        case .require: return .require(try c.decode(Require.self, forKey: k))
        case .limit: return .limit(try c.decode(Limit.self, forKey: k))
        case .offer: return .offer(try c.decode(Offer.self, forKey: k))
        case .ask: return .ask(try c.decode(Ask.self, forKey: k))
        case .tell: return .tell(try c.decode(Tell.self, forKey: k))
        case .provide: return .provide(try c.decode(Provide.self, forKey: k))
        case .derive: return .derive(try c.decode(Derive.self, forKey: k))
        case .check: return .check(try c.decode(Check.self, forKey: k))
        case .gain: return .gain(try c.decode(Gain.self, forKey: k))
        case .cost: return .cost(try c.decode(Cost.self, forKey: k))
        case .process: return .process(try c.decode(Process.self, forKey: k))
        case .item: return .item(try c.decode(ItemChange.self, forKey: k))
        case .reroll: return .reroll(try c.decode(Reroll.self, forKey: k))
        }
    }

    func encode(into c: inout KeyedEncodingContainer<Effect.CodingKeys>) throws {
        let k = Effect.CodingKeys.payload
        switch self {
        case .add(let p): try c.encode(p, forKey: k)
        case .set(let p): try c.encode(p, forKey: k)
        case .multiply(let p): try c.encode(p, forKey: k)
        case .cap(let p): try c.encode(p, forKey: k)
        case .floor(let p): try c.encode(p, forKey: k)
        case .useLevel(let p): try c.encode(p, forKey: k)
        case .replace(let p): try c.encode(p, forKey: k)
        case .suppress(let p): try c.encode(p, forKey: k)
        case .forbid(let p): try c.encode(p, forKey: k)
        case .require(let p): try c.encode(p, forKey: k)
        case .limit(let p): try c.encode(p, forKey: k)
        case .offer(let p): try c.encode(p, forKey: k)
        case .ask(let p): try c.encode(p, forKey: k)
        case .tell(let p): try c.encode(p, forKey: k)
        case .provide(let p): try c.encode(p, forKey: k)
        case .derive(let p): try c.encode(p, forKey: k)
        case .check(let p): try c.encode(p, forKey: k)
        case .gain(let p): try c.encode(p, forKey: k)
        case .cost(let p): try c.encode(p, forKey: k)
        case .process(let p): try c.encode(p, forKey: k)
        case .item(let p): try c.encode(p, forKey: k)
        case .reroll(let p): try c.encode(p, forKey: k)
        }
    }
}

// MARK: - Value verbs

public struct Add: Codable, Hashable, Sendable {
    public var to: [TargetRef]
    public var value: ValueExpr
    /// A fact: the value is added once per unit of it.
    public var per: String? = nil
    /// A provided scale: the value is a number of steps along it (the spell parameters).
    public var scale: String? = nil
}

/// `set` (named so, not to shadow `Swift.Set`).
public struct SetValue: Codable, Hashable, Sendable {
    public var to: [TargetRef]
    public var value: ValueExpr
}

public struct Multiply: Codable, Hashable, Sendable {
    public var to: [TargetRef]
    public var by: Double
    public var line: Selector? = nil
    public var round: Rounding? = nil
}

public struct Cap: Codable, Hashable, Sendable {
    public var to: [TargetRef]
    public var max: ValueExpr? = nil
    public var min: ValueExpr? = nil
    public var over: Selector? = nil
}

public struct Floor: Codable, Hashable, Sendable {
    public var to: [TargetRef]
    public var min: ValueExpr
}

/// Another rule's level takes part in this one's (spec §5.2, phase `level`). Exactly one of
/// `as` and `lowerBy` is present.
public struct UseLevel: Codable, Hashable, Sendable {
    public var rule: String
    /// `as` binds `level` to the target's effective level after earlier useLevels (R28).
    public var `as`: ValueExpr? = nil
    /// `lowerBy` binds `level` to the acting rule's level.
    public var lowerBy: ValueExpr? = nil
    public var min: Int? = nil
}

/// The replaced effect's `value` is swapped before `per`, and its targets and `when` are kept
/// (plan Appendix A.3).
public struct Replace: Codable, Hashable, Sendable {
    public var line: Selector
    public var with: ValueExpr
}

public struct Suppress: Codable, Hashable, Sendable {
    public var line: Selector
}

public struct Derive: Codable, Hashable, Sendable {
    public var to: TargetRef
    public var sum: [ValueExpr]
}

// MARK: - Legality verbs

public struct Forbid: Codable, Hashable, Sendable {
    public var what: Selector
    public var together: Bool? = nil
}

public struct Require: Codable, Hashable, Sendable {
    public var that: Condition
    public var enables: Bool? = nil
    public var `for`: Selector? = nil
}

public struct Limit: Codable, Hashable, Sendable {
    public var what: Selector
    public var max: ValueExpr
    public var per: Span
}

// MARK: - Player and data verbs

public struct Offer: Codable, Hashable, Sendable {
    public var choice: String
    /// Paid when the offer is taken; absent is none.
    public var costs: [Effect] = []
    public var `default`: JSONValue? = nil
    public var options: [JSONValue]? = nil
    public var span: Span? = nil

    enum CodingKeys: String, CodingKey { case choice, costs, `default`, options, span }

    public init(choice: String, costs: [Effect] = [], default: JSONValue? = nil, options: [JSONValue]? = nil, span: Span? = nil) {
        self.choice = choice; self.costs = costs; self.default = `default`; self.options = options; self.span = span
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        choice = try c.decode(String.self, forKey: .choice)
        costs = try c.decodeIfPresent([Effect].self, forKey: .costs) ?? []
        `default` = try c.decodeIfPresent(JSONValue.self, forKey: .default)
        options = try c.decodeIfPresent([JSONValue].self, forKey: .options)
        span = try c.decodeIfPresent(Span.self, forKey: .span)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(choice, forKey: .choice)
        if !costs.isEmpty { try c.encode(costs, forKey: .costs) }
        try c.encodeIfPresent(`default`, forKey: .default)
        try c.encodeIfPresent(options, forKey: .options)
        try c.encodeIfPresent(span, forKey: .span)
    }
}

public struct Ask: Codable, Hashable, Sendable {
    public var fact: String
    public var who: Owner
    public var options: [JSONValue]? = nil
}

public struct Tell: Codable, Hashable, Sendable {
    public var text: String
    public var to: Audience
}

public struct Provide: Codable, Hashable, Sendable {
    public var name: String
    /// The vocabulary types this `data`: a table, a list, a number or a row.
    public var value: JSONValue
    public var readBy: Reader? = nil
}

// MARK: - Action verbs

public struct Check: Codable, Hashable, Sendable {
    public var of: Selector
    public var modifier: ValueExpr? = nil
    public var onSuccess: [Effect] = []
    public var onFailure: [Effect] = []

    enum CodingKeys: String, CodingKey { case of, modifier, onSuccess, onFailure }

    public init(of: Selector, modifier: ValueExpr? = nil, onSuccess: [Effect] = [], onFailure: [Effect] = []) {
        self.of = of; self.modifier = modifier; self.onSuccess = onSuccess; self.onFailure = onFailure
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        of = try c.decode(Selector.self, forKey: .of)
        modifier = try c.decodeIfPresent(ValueExpr.self, forKey: .modifier)
        onSuccess = try c.decodeIfPresent([Effect].self, forKey: .onSuccess) ?? []
        onFailure = try c.decodeIfPresent([Effect].self, forKey: .onFailure) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(of, forKey: .of)
        try c.encodeIfPresent(modifier, forKey: .modifier)
        if !onSuccess.isEmpty { try c.encode(onSuccess, forKey: .onSuccess) }
        if !onFailure.isEmpty { try c.encode(onFailure, forKey: .onFailure) }
    }
}

public struct Gain: Codable, Hashable, Sendable {
    public var rule: RuleRef
    public var levels: Int? = nil
    public var span: Span? = nil
}

public struct Cost: Codable, Hashable, Sendable {
    public var pool: Pool
    public var amount: ValueExpr
    public var split: Split? = nil
    /// Pools paid from, in order, when `pool` runs short; absent is none.
    public var fallThrough: [Pool] = []
    /// The share paid when the action fails (`0.5`: half).
    public var onFailure: Double? = nil
    public var every: Duration? = nil

    enum CodingKeys: String, CodingKey { case pool, amount, split, fallThrough, onFailure, every }

    public init(pool: Pool, amount: ValueExpr, split: Split? = nil, fallThrough: [Pool] = [],
                onFailure: Double? = nil, every: Duration? = nil) {
        self.pool = pool; self.amount = amount; self.split = split
        self.fallThrough = fallThrough; self.onFailure = onFailure; self.every = every
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pool = try c.decode(Pool.self, forKey: .pool)
        amount = try c.decode(ValueExpr.self, forKey: .amount)
        split = try c.decodeIfPresent(Split.self, forKey: .split)
        fallThrough = try c.decodeIfPresent([Pool].self, forKey: .fallThrough) ?? []
        onFailure = try c.decodeIfPresent(Double.self, forKey: .onFailure)
        every = try c.decodeIfPresent(Duration.self, forKey: .every)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pool, forKey: .pool)
        try c.encode(amount, forKey: .amount)
        try c.encodeIfPresent(split, forKey: .split)
        if !fallThrough.isEmpty { try c.encode(fallThrough, forKey: .fallThrough) }
        try c.encodeIfPresent(onFailure, forKey: .onFailure)
        try c.encodeIfPresent(every, forKey: .every)
    }
}

/// A cost shared between pools, with a least amount from some of them.
public struct Split: Codable, Hashable, Sendable {
    public var pools: [Pool]
    public var min: [Pool: Int] = [:]

    enum CodingKeys: String, CodingKey { case pools, min }

    public init(pools: [Pool], min: [Pool: Int] = [:]) { self.pools = pools; self.min = min }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pools = try c.decode([Pool].self, forKey: .pools)
        var min: [Pool: Int] = [:]
        for (k, v) in try c.decodeIfPresent([String: Int].self, forKey: .min) ?? [:] {
            guard let pool = Pool(rawValue: k) else {
                throw DecodingError.dataCorruptedError(forKey: .min, in: c, debugDescription: "unknown pool \(k)")
            }
            min[pool] = v
        }
        self.min = min
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pools, forKey: .pools)
        try c.encode(Dictionary(uniqueKeysWithValues: min.map { ($0.key.rawValue, $0.value) }), forKey: .min)
    }
}

/// `{ minutes: 5 }`, `{ rounds: 1 }`, or a count read from a fact (`{ minutes: spell.interval }`).
public struct Duration: Codable, Hashable, Sendable {
    public enum Unit: String, Codable, CaseIterable, Sendable { case minutes, rounds }
    public enum Count: Hashable, Sendable { case number(Int), fact(String) }
    public var unit: Unit
    public var count: Count

    public init(unit: Unit, count: Count) { self.unit = unit; self.count = count }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        let key = try c.onlyKey("a duration")
        guard let unit = Unit(rawValue: key) else {
            throw DecodingError.dataCorruptedError(forKey: AnyKey(key), in: c, debugDescription: "unknown duration unit \(key)")
        }
        self.unit = unit
        if let n = try? c.decode(Int.self, forKey: AnyKey(key)) {
            count = .number(n)
        } else {
            count = .fact(try c.decode(String.self, forKey: AnyKey(key)))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        switch count {
        case .number(let n): try c.encode(n, forKey: AnyKey(unit.rawValue))
        case .fact(let f): try c.encode(f, forKey: AnyKey(unit.rawValue))
        }
    }
}

public struct Process: Codable, Hashable, Sendable {
    public var id: String
    public var steps: ValueExpr
    public var advancedBy: Selector
    public var breaksOff: Condition? = nil
    /// Run when the last step is done; absent is none.
    public var completes: [Effect] = []
    public var exclusive: Bool? = nil
    public var span: Span? = nil

    enum CodingKeys: String, CodingKey { case id, steps, advancedBy, breaksOff, completes, exclusive, span }

    public init(id: String, steps: ValueExpr, advancedBy: Selector, breaksOff: Condition? = nil,
                completes: [Effect] = [], exclusive: Bool? = nil, span: Span? = nil) {
        self.id = id; self.steps = steps; self.advancedBy = advancedBy; self.breaksOff = breaksOff
        self.completes = completes; self.exclusive = exclusive; self.span = span
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        steps = try c.decode(ValueExpr.self, forKey: .steps)
        advancedBy = try c.decode(Selector.self, forKey: .advancedBy)
        breaksOff = try c.decodeIfPresent(Condition.self, forKey: .breaksOff)
        completes = try c.decodeIfPresent([Effect].self, forKey: .completes) ?? []
        exclusive = try c.decodeIfPresent(Bool.self, forKey: .exclusive)
        span = try c.decodeIfPresent(Span.self, forKey: .span)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(steps, forKey: .steps)
        try c.encode(advancedBy, forKey: .advancedBy)
        try c.encodeIfPresent(breaksOff, forKey: .breaksOff)
        if !completes.isEmpty { try c.encode(completes, forKey: .completes) }
        try c.encodeIfPresent(exclusive, forKey: .exclusive)
        try c.encodeIfPresent(span, forKey: .span)
    }
}

/// The `item` verb: a change to an item instance.
public struct ItemChange: Codable, Hashable, Sendable {
    public var instance: Selector
    public var change: ItemDelta
}

/// What an `item` effect changes: the vocabulary's `itemFields`, each optional.
public struct ItemDelta: Codable, Hashable, Sendable {
    public var loaded: Bool? = nil
    public var strung: Bool? = nil
    public var structurePoints: ItemAmount? = nil
    public var damaged: Bool? = nil
    public var destroyed: Bool? = nil
    public var ridden: Bool? = nil
    public var held: Bool? = nil

    /// The vocabulary's `itemFields`, in its order.
    public static let fields = ["loaded", "strung", "structurePoints", "damaged", "destroyed", "ridden", "held"]
}

/// A change to an item's count: a number, or a fact's value times a factor
/// (`{ of: hit.tp, times: -1 }`: the shield loses the hit's TP).
public enum ItemAmount: Codable, Hashable, Sendable {
    case number(Double)
    case scaled(of: String, times: Double)

    private struct Scaled: Codable { var of: String, times: Double }

    public init(from decoder: Decoder) throws {
        if let n = try? decoder.singleValueContainer().decode(Double.self) {
            self = .number(n)
        } else {
            let s = try Scaled(from: decoder)
            self = .scaled(of: s.of, times: s.times)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .number(let n):
            var c = encoder.singleValueContainer()
            try c.encode(n)
        case .scaled(let of, let times): try Scaled(of: of, times: times).encode(to: encoder)
        }
    }
}

public struct Reroll: Codable, Hashable, Sendable {
    public var die: Selector
    /// Which result stands: `better`, `second`, …
    public var keep: String
    public var max: Int? = nil
    public var per: Span? = nil
}
