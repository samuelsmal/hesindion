import Foundation

// MARK: - Effects

/// Where an effect sits: a top-level effect by its position in the clause (an int in the JSON),
/// a nested one by its path (`"0.onFailure.1"`: the second `onFailure` effect of effect 0).
public enum EffectIndex: Codable, Hashable, Sendable, CustomStringConvertible {
    case top(Int)
    case nested(String)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { self = .top(i) } else { self = .nested(try c.decode(String.self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .top(let i): try c.encode(i)
        case .nested(let s): try c.encode(s)
        }
    }

    public var description: String {
        switch self {
        case .top(let i): String(i)
        case .nested(let s): s
        }
    }
}

public struct EffectOrigin: Codable, Hashable, Sendable, CustomStringConvertible {
    public var rule: String
    public var clause: String
    public var index: EffectIndex

    public init(rule: String, clause: String, index: EffectIndex) {
        self.rule = rule; self.clause = clause; self.index = index
    }

    public var clauseRef: ClauseRef { ClauseRef(rule: rule, clause: clause) }
    public var description: String { "\(rule).\(clause)[\(index)]" }
}

/// One compiled effect: `{"verb", "payload", "when", "ruling", "because", "phase", "origin"}`.
public struct Effect: Codable, Hashable, Sendable {
    public var payload: Payload
    public var when: Condition?
    /// The qualified ids of the rulings the effect rests on (`RULE.id`, `shared.id`).
    public var ruling: [String]
    public var because: String?
    /// The pipeline phase; nil for data, player and action verbs. An effect's own `phase:`
    /// overrides its verb's.
    public var phase: Phase?
    public var origin: EffectOrigin

    public init(payload: Payload, when: Condition? = nil, ruling: [String] = [], because: String? = nil,
                phase: Phase? = nil, origin: EffectOrigin) {
        self.payload = payload; self.when = when; self.ruling = ruling
        self.because = because; self.phase = phase ?? payload.verb.phase; self.origin = origin
    }

    enum CodingKeys: String, CodingKey { case verb, payload, when, ruling, because, phase, origin }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        payload = try Payload.decode(try c.decode(Verb.self, forKey: .verb), from: c)
        when = try c.decodeIfPresent(Condition.self, forKey: .when)
        ruling = try c.decodeIfPresent([String].self, forKey: .ruling) ?? []
        because = try c.decodeIfPresent(String.self, forKey: .because)
        let layer = try c.decode(String.self, forKey: .phase)
        if let p = Phase(rawValue: layer) {
            phase = p
        } else if layer == payload.verb.layerName {
            phase = nil
        } else {
            throw DecodingError.dataCorruptedError(forKey: .phase, in: c,
                debugDescription: "phase \(layer) for a \(payload.verb.rawValue)")
        }
        origin = try c.decode(EffectOrigin.self, forKey: .origin)
    }

    /// The compiler's shape: every key, `when` and `because` as null when absent.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(payload.verb, forKey: .verb)
        try payload.encode(into: &c)
        if let when { try c.encode(when, forKey: .when) } else { try c.encodeNil(forKey: .when) }
        try c.encode(ruling, forKey: .ruling)
        if let because { try c.encode(because, forKey: .because) } else { try c.encodeNil(forKey: .because) }
        try c.encode(phase?.rawValue ?? payload.verb.layerName, forKey: .phase)
        try c.encode(origin, forKey: .origin)
    }
}

// MARK: - Clauses, rulings, rules

public enum ClauseBody: Hashable, Sendable {
    case effects([Effect])
    /// Not encoded yet: why.
    case unencoded(String)
    /// Nothing to encode: why.
    case none(String)
}

public struct Clause: Decodable, Hashable, Sendable {
    public var id: String
    public var text: String
    public var body: ClauseBody
    public var name: String?
    public var page: JSONValue?

    public var effects: [Effect] {
        if case .effects(let e) = body { e } else { [] }
    }

    enum CodingKeys: String, CodingKey { case id, text, effects, unencoded, none, name, page }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        page = try c.decodeIfPresent(JSONValue.self, forKey: .page)
        let bodies = [CodingKeys.effects, .unencoded, .none].filter(c.contains)
        guard bodies.count == 1 else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath,
                debugDescription: "clause \(id) needs exactly one of effects, unencoded, none"))
        }
        switch bodies[0] {
        case .effects: body = .effects(try c.decode([Effect].self, forKey: .effects))
        case .unencoded: body = .unencoded(try c.decode(String.self, forKey: .unencoded))
        default: body = .none(try c.decode(String.self, forKey: .none))
        }
    }
}

public struct Ruling: Codable, Hashable, Sendable {
    public enum Status: String, Codable, Sendable { case open, decided }
    /// Qualified: `RULE.id`, or `shared.id` for `rules/rulings.yaml`.
    public var id: String
    public var status: Status
    public var question: String?
    public var answer: String?

    public init(id: String, status: Status, question: String? = nil, answer: String? = nil) {
        self.id = id; self.status = status; self.question = question; self.answer = answer
    }
}

/// Who read a rule against its page, and when.
public struct Review: Codable, Hashable, Sendable {
    public var by: String
    public var date: String
}

public struct Rule: Decodable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var kind: RuleKind
    public var ruleset: String?
    public var levels: Int?
    /// What the hero file chooses for the rule (`sid`: a Schlechte Eigenschaft).
    public var options: String?
    /// The rule's own data (an equipment row, a list of reach names).
    public var provides: [String: JSONValue]
    public var clauses: [Clause]
    /// The qualified ids of the rule's own rulings; the rulings are `RuleBook.rulings`.
    public var rulings: [String]
    public var group: String?
    public var passive: Bool
    /// A manoeuvre's properties (`kind`, `mountedCombat`), which a manoeuvre selector matches.
    public var manoeuvre: [String: JSONValue]?
    public var techniques: [String]?
    public var catalogId: String?
    /// nil until a person has read the clauses against the page.
    public var reviewed: Review?
    public var source: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case id, name, kind, ruleset, levels, options, provides, clauses, rulings
        case group, passive, manoeuvre, techniques, catalogId, reviewed, source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(RuleKind.self, forKey: .kind)
        ruleset = try c.decodeIfPresent(String.self, forKey: .ruleset)
        levels = try c.decodeIfPresent(Int.self, forKey: .levels)
        options = try c.decodeIfPresent(String.self, forKey: .options)
        provides = try c.decodeIfPresent([String: JSONValue].self, forKey: .provides) ?? [:]
        clauses = try c.decode([Clause].self, forKey: .clauses)
        rulings = (try c.decodeIfPresent([Ruling].self, forKey: .rulings) ?? []).map(\.id)
        group = try c.decodeIfPresent(String.self, forKey: .group)
        passive = try c.decodeIfPresent(Bool.self, forKey: .passive) ?? false
        manoeuvre = try c.decodeIfPresent([String: JSONValue].self, forKey: .manoeuvre)
        techniques = try c.decodeIfPresent([String].self, forKey: .techniques)
        catalogId = try c.decodeIfPresent(String.self, forKey: .catalogId)
        reviewed = try c.decodeIfPresent(Review.self, forKey: .reviewed)
        source = try c.decodeIfPresent([String: JSONValue].self, forKey: .source) ?? [:]
    }
}

// MARK: - The book

public enum RuleBookError: Error, Equatable {
    case vocabularyMismatch(found: Int, expected: Int)
    /// Two rules with one id.
    case duplicateRule(String)
    /// Two rulings with one qualified id.
    case duplicateRuling(String)
}

/// `build/rules/rules.json`, decoded: every rule, ruling and the reach index.
public struct RuleBook: Sendable {
    public let rules: [String: Rule]
    public let rulings: [String: Ruling]
    /// Target name → the top-level effects that can change it; `"*"` → those every query
    /// evaluates. Each list is in the compiler's sort key (rule id, then clause id as a string,
    /// then index): not the order the clauses appear in the rule. An origin can be listed under
    /// a target and under `"*"` at once (a useLevel, replace or suppress inherits every key of
    /// what it names). Chaining (R28) goes by `Rule.clauses` order, not by this one.
    public let reach: [String: [EffectOrigin]]
    /// The SHA-256 of the rules.json bytes (hex), for a log entry's `rulesSha256`.
    public let sha256: String
    public let vocabularyVersion: Int
    public let vocabularySha256: String

    private let byOrigin: [EffectOrigin: Effect]
    private let tables: [String: JSONValue]

    public static func load(from url: URL) throws -> RuleBook {
        try decode(Data(contentsOf: url))
    }

    /// Refuses a book compiled for another vocabulary before reading anything else.
    public static func decode(_ data: Data) throws -> RuleBook {
        struct Header: Decodable { var vocabularyVersion: Int }
        struct Raw: Decodable {
            var vocabularyVersion: Int
            var vocabularySha256: String
            var rules: [Rule]
            var rulings: [Ruling]
            var reach: [String: [EffectOrigin]]
        }
        let decoder = JSONDecoder()
        let found = try decoder.decode(Header.self, from: data).vocabularyVersion
        guard found == Vocabulary.version else {
            throw RuleBookError.vocabularyMismatch(found: found, expected: Vocabulary.version)
        }
        let raw = try decoder.decode(Raw.self, from: data)
        if let id = firstDuplicate(raw.rules.map(\.id)) { throw RuleBookError.duplicateRule(id) }
        if let id = firstDuplicate(raw.rulings.map(\.id)) { throw RuleBookError.duplicateRuling(id) }
        return RuleBook(raw.rules, raw.rulings, raw.reach, SHA256.hex(data), raw.vocabularyVersion, raw.vocabularySha256)
    }

    private init(_ rules: [Rule], _ rulings: [Ruling], _ reach: [String: [EffectOrigin]], _ sha256: String,
                 _ vocabularyVersion: Int, _ vocabularySha256: String) {
        var byOrigin: [EffectOrigin: Effect] = [:], tables: [String: JSONValue] = [:]
        func index(_ e: Effect) {
            byOrigin[e.origin] = e
            if case .provide(let p) = e.payload, tables[p.name] == nil { tables[p.name] = p.value }
            for (_, nested) in e.payload.nested { nested.forEach(index) }
        }
        for rule in rules {                            // rules.json lists them sorted by id
            for clause in rule.clauses { clause.effects.forEach(index) }
        }
        self.rules = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0) })
        self.rulings = Dictionary(uniqueKeysWithValues: rulings.map { ($0.id, $0) })
        self.reach = reach
        self.sha256 = sha256
        self.vocabularyVersion = vocabularyVersion
        self.vocabularySha256 = vocabularySha256
        self.byOrigin = byOrigin
        self.tables = tables
    }

    /// The effect at `origin`, top-level or nested.
    public func effect(at origin: EffectOrigin) -> Effect? { byOrigin[origin] }

    /// The effects the reach index lists under `target` or under `"*"`, each once, merged in
    /// the compiler's sort key (`compile._ref_key`: rule id, clause id, then int indices before
    /// string ones). That is not clause order within a rule; chaining (R28) uses `Rule.clauses`.
    public func effects(reaching target: String) -> [Effect] {
        var seen = Set<EffectOrigin>()
        let origins = ((reach[target] ?? []) + (target == "*" ? [] : reach["*"] ?? []))
            .filter { seen.insert($0).inserted }
            .sorted(by: EffectOrigin.compilerOrder)
        return origins.compactMap { byOrigin[$0] }
    }

    /// The value a `provide` gives under `name`. Several rules may provide one name (each
    /// weapon its `loadout.weapon` row); this is the first, in rule-id and clause order.
    public func table(_ name: String) -> JSONValue? { tables[name] }
}

private func firstDuplicate(_ ids: [String]) -> String? {
    var seen = Set<String>()
    return ids.first { !seen.insert($0).inserted }
}

extension EffectOrigin {
    /// rulec's `_ref_key`: rule, clause, then an int index (by value) before a string one (by
    /// text). Strings compare by Unicode scalars, as Python compares them.
    static func compilerOrder(_ a: EffectOrigin, _ b: EffectOrigin) -> Bool {
        func less(_ x: String, _ y: String) -> Bool { x.unicodeScalars.lexicographicallyPrecedes(y.unicodeScalars) }
        if a.rule != b.rule { return less(a.rule, b.rule) }
        if a.clause != b.clause { return less(a.clause, b.clause) }
        switch (a.index, b.index) {
        case (.top(let x), .top(let y)): return x < y
        case (.top, .nested): return true
        case (.nested, .top): return false
        case (.nested(let x), .nested(let y)): return less(x, y)
        }
    }
}
