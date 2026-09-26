import Foundation
@testable import RulesEngine

// One entry of `build/rules/situations.json`, as `scripts/rulec/situations.py` writes it:
// `{id, file, name, owned, facts, base, rolls, sequence, expect: [{query, …}], expectSituation, pending}`.
// The engine reads the hero and the facts (`Situation`); the harness reads the rest.

/// The compiled situations file: `{vocabularyVersion, situations: [...]}`.
struct CompiledSituations: Decodable {
    var vocabularyVersion: Int
    var situations: [CompiledSituation]
}

struct CompiledSituation: Decodable {
    var id: String
    /// The situations file, relative to the situations directory (`kampfwerte.yaml`).
    var file: String
    var name: String?
    /// The hero, its facts, the sheet's base values and the dice: what the engine reads.
    var situation: Situation
    /// The dice, in order (a `rolls` list); roll facts (`rolls: {check.result: …}`) are facts.
    var rolls: [Int]
    /// The action layer's steps, not validated before Task 28.
    var sequence: [JSONValue]
    /// One entry per expected query, in the file's order.
    var expect: [QueryExpectation]
    /// The situation-level expectations (`offered`, `notOffered`, `notApplied`, `questions`,
    /// `texts`, `legal`, and the action layer's `events`, `fp`, `qs`, `spent`, `success`, `result`).
    var expectSituation: [String: JSONValue]
    /// rulec's static pending list (§10.2): the open rulings on the situation's path. An upper
    /// bound: the harness counts a mismatch as pending only when the run hit one of them (R32).
    var pending: [String]

    private enum CodingKeys: String, CodingKey { case id, file, name, rolls, sequence, expect, expectSituation, pending }

    /// The situation the engine runs on. Situations state the current LE and AsP as `base`
    /// values (`leCurrent`, `aspCurrent`), not as `pools`; the pools are filled from them, the
    /// max from `leMax` / `aspMax` when stated (else the current value), so that
    /// `hero.leCurrent` and payments read them (R39). A pool the situation states is kept.
    ///
    /// A talent check (`check.talent` stated) gets its talent's Belastung flag,
    /// `check.hinderedByBelastung`, from the Probe table as the app hands it in (`CheckAttributes`), unless
    /// the situation states it (Task 30).
    var engineSituation: Situation {
        var out = situation
        if let talent = situation.facts["check.talent"]?.value.string, situation.facts["check.hinderedByBelastung"] == nil,
           let flag = CheckAttributes.hinderedByBelastung[talent] {
            out.facts["check.hinderedByBelastung"] = Fact(name: "check.hinderedByBelastung", value: flag, owner: .derived)
        }
        for pool in Pool.allCases where out.pools[pool] == nil {
            guard let target = pool.currentTarget, let current = situation.base[target] else { continue }
            let max = situation.base[target.replacingOccurrences(of: "Current", with: "Max")] ?? current
            out.pools[pool] = PoolState(current: current, max: max)
        }
        return out
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        file = try c.decode(String.self, forKey: .file)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        situation = try Situation(from: decoder)
        rolls = try c.decodeIfPresent([Int].self, forKey: .rolls) ?? []
        sequence = try c.decodeIfPresent([JSONValue].self, forKey: .sequence) ?? []
        expect = try c.decodeIfPresent([QueryExpectation].self, forKey: .expect) ?? []
        expectSituation = try c.decodeIfPresent([String: JSONValue].self, forKey: .expectSituation) ?? [:]
        pending = try c.decodeIfPresent([String].self, forKey: .pending) ?? []
    }
}

/// What one query should give (`expectQueryKeys`: total, result, values, lines, notApplied,
/// legal, base).
struct QueryExpectation: Decodable {
    /// Every key the decoder reads; `VocabularyDriftTests` holds it to `expectQueryKeys`.
    enum CodingKeys: String, CodingKey, CaseIterable { case query, total, result, lines, notApplied, legal, base, values }

    var query: String
    var total: Int?
    var result: Int?
    var lines: [ExpectedLine]?
    var notApplied: [ExpectedNotApplied]?
    /// `true` / `false`, or `{allowed, because, ruling, span, via}`.
    var legal: JSONValue?
    /// `{from, value, ruling, …}`: the base line.
    var base: JSONValue?
    /// A check's attribute stage values (`[12, 14, 14]`), Task 26's.
    var values: JSONValue?
}

/// An expected line (`lineKeys`: value, from, via, ruling, source, kind, was, term). rulec has
/// qualified `ruling` already.
struct ExpectedLine: Decodable {
    /// Every key the decoder reads; `VocabularyDriftTests` holds it to `lineKeys`.
    enum CodingKeys: String, CodingKey, CaseIterable { case from, value, via, ruling, source, kind, was, term }

    var from: String?
    var value: Int?
    var via: [String]?
    var ruling: [String]?
    var source: String?
    var kind: String?
    var was: Int?
    var term: String?

    /// A `via` or `ruling` may be one string: rulec passes a `sequence` step's lines through as
    /// written (Task 30).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func list(_ key: CodingKeys) throws -> [String]? {
            if let one = try? c.decode(String.self, forKey: key) { return [one] }
            return try c.decodeIfPresent([String].self, forKey: key)
        }
        from = try c.decodeIfPresent(String.self, forKey: .from)
        value = try c.decodeIfPresent(Int.self, forKey: .value)
        via = try list(.via)
        ruling = try list(.ruling)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        was = try c.decodeIfPresent(Int.self, forKey: .was)
        term = try c.decodeIfPresent(String.self, forKey: .term)
    }
}

/// An expected `notApplied` entry: `rule`, and when given `clause`, `reason` (a reason code, a
/// clause ref, or prose), `because`, `ruling` (qualified by rulec) and `value`.
struct ExpectedNotApplied: Decodable {
    /// Every key the decoder reads; the vocabulary's `notAppliedKeys` (a test holds the two equal).
    /// rulec rejects any other key in a query's or the situation's entries; a `sequence` step's
    /// entries, passed through, are malformed with one (`init?(_:)`).
    enum CodingKeys: String, CodingKey, CaseIterable { case rule, clause, reason, because, ruling, value }

    var rule: String
    var clause: String?
    var reason: String?
    var because: String?
    var ruling: [String]?
    var value: Int?

    init(rule: String, clause: String? = nil, reason: String? = nil, because: String? = nil,
         ruling: [String]? = nil, value: Int? = nil) {
        self.rule = rule; self.clause = clause; self.reason = reason; self.because = because
        self.ruling = ruling; self.value = value
    }

    /// From a situation-level entry, which rulec passes through unqualified: a `ruling` may be
    /// a string or a list. nil without a `rule` or with a key outside `notAppliedKeys`.
    init?(_ json: JSONValue) {
        guard case .object(let o) = json, let rule = o["rule"]?.string,
              o.keys.allSatisfy({ CodingKeys(rawValue: $0) != nil }) else { return nil }
        self.init(rule: rule, clause: o["clause"]?.string, reason: o["reason"]?.string, because: o["because"]?.string,
                  ruling: o["ruling"].map(strings), value: o["value"]?.int)
    }
}

/// A string or a list of strings as a list.
func strings(_ json: JSONValue) -> [String] {
    switch json {
    case .string(let s): [s]
    case .array(let a): a.compactMap(\.string)
    default: []
    }
}

extension CompiledSituations {
    /// `build/rules/situations.json`, or nil when it has not been built.
    static func load(from url: URL) throws -> CompiledSituations? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(CompiledSituations.self, from: Data(contentsOf: url))
    }
}
