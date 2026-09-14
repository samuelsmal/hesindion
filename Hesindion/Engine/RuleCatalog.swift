import Foundation

/// Where a line lands. `talent(id)` matches exactly one talent check.
enum RuleTarget: Equatable, Hashable {
    case at, pa, aw, vw, fk, tp
    case talent(String)

    /// Whether a line with this target belongs to the domain being evaluated.
    /// An effect on another target is simply not this domain's business: a
    /// Wuchtschlag clause names `at` and `tp`, and each screen takes its own.
    func applies(in domain: RuleDomain, talentId: String?) -> Bool {
        switch self {
        case .at:              domain == .meleeAttack
        case .pa:              domain == .meleeParry
        case .aw:              domain == .meleeDodge
        case .vw:              domain == .meleeParry || domain == .meleeDodge
        case .fk:              domain == .rangedAttack
        case .tp:              domain == .damage
        case .talent(let id):  domain == .talentCheck && talentId == id
        }
    }
}

/// A condition on the hero, the loadout, the round, the opponent, or the GM.
indirect enum RulePredicate: Equatable {
    case all([RulePredicate])
    case any([RulePredicate])
    case not(RulePredicate)
    case heroHasRule(id: String, minTier: Int)
    case heroState(id: String, minLevel: Int)
    case heroFokusRule(String)
    case loadoutWeapon(technique: [String]?, item: String?, consecrated: Bool?)
    case loadoutShield(item: String?)
    case loadoutReach(WeaponReach)
    case situationMounted
    case situationBeengt
    case situationDefencesThisRound(min: Int)
    case situationTargetZone([HitZone])
    case situationWoundEffect
    case opponentReach(WeaponReach)
    case opponentOnFoot
    case opponentState(String)
    case opponentType(RuleVocabulary.OpponentType)
    case gmFact(id: String, span: FactSpan)
}

enum RuleEffect: Equatable {
    case add(target: RuleTarget, value: Int, per: RuleVocabulary.Per?)
    case multiply(target: RuleTarget, factor: Double)
    case opponentAdd(target: RuleTarget, value: Int)
    case modifyRule(id: String, target: RuleTarget, add: Int?, set: Int?, multiply: Double?)
    case choice([RuleEffect])
}

/// How many tiers an offer has: the hero's own tier of the ability, or a number.
enum OfferTiers: Equatable {
    case owned
    case fixed(Int)
}

struct RuleClause: Equatable, Decodable {
    let kind: RuleVocabulary.ClauseKind
    let domains: [RuleDomain]
    let when: RulePredicate?
    let effects: [RuleEffect]
    let tiers: OfferTiers?
}

/// One `implemented` catalog entry, decoded.
struct CatalogRule: Equatable {
    let id: String
    let name: String
    /// `reviewed` in the catalog is non-null: a person checked the clauses
    /// against the text. Unreviewed rules run and are marked "ungeprüft".
    let reviewed: Bool
    let appliesWith: RulePredicate?
    let clauses: [RuleClause]

    /// Sonderfertigkeiten, Vorteile and Nachteile apply only when the hero
    /// carries the id (design decision 6). Core rules, Zustände and Status
    /// apply to everyone; their `when` gates them.
    var needsOwnership: Bool {
        !(id.hasPrefix("GRW_") || id.hasPrefix("COND_") || id.hasPrefix("STATE_"))
    }
}

/// The catalog as the evaluator sees it: the implemented rules, and the
/// status of every entry for the not-applied list.
struct RuleCatalog {
    let rules: [String: CatalogRule]
    let statuses: [String: CatalogEntry]

    init(rules: [CatalogRule], statuses: [CatalogEntry] = []) {
        self.rules = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0) })
        self.statuses = Dictionary(uniqueKeysWithValues: statuses.map { ($0.id, $0) })
    }

    /// Sorted by id, so evaluation order is fixed.
    var implemented: [CatalogRule] { rules.values.sorted { $0.id < $1.id } }

    static let bundled = RuleCatalog(
        rules: RulesDatabase.shared.implementedRules(),
        statuses: RulesDatabase.shared.allCatalogEntries()
    )
}

// MARK: - Decoding

/// Dynamic keys: the JSON names the predicate or effect in `is` / `effect`
/// and puts its arguments beside it.
struct RuleKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

private extension KeyedDecodingContainer where K == RuleKey {
    func string(_ key: String) throws -> String { try decode(String.self, forKey: RuleKey(key)) }
    func stringIfPresent(_ key: String) throws -> String? { try decodeIfPresent(String.self, forKey: RuleKey(key)) }
    func intIfPresent(_ key: String) throws -> Int? { try decodeIfPresent(Int.self, forKey: RuleKey(key)) }
    func doubleIfPresent(_ key: String) throws -> Double? { try decodeIfPresent(Double.self, forKey: RuleKey(key)) }
    /// One string or a list of them.
    func strings(_ key: String) throws -> [String]? {
        if let one = try? decodeIfPresent(String.self, forKey: RuleKey(key)) { return [one] }
        return try decodeIfPresent([String].self, forKey: RuleKey(key))
    }
    func named<T: RawRepresentable>(_ type: T.Type, _ key: String, _ what: String) throws -> T where T.RawValue == String {
        let raw = try string(key)
        guard let value = T(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(forKey: RuleKey(key), in: self, debugDescription: "unknown \(what) \(raw)")
        }
        return value
    }
}

extension RulePredicate: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: RuleKey.self)
        if c.contains(RuleKey("all")) { self = .all(try c.decode([RulePredicate].self, forKey: RuleKey("all"))); return }
        if c.contains(RuleKey("any")) { self = .any(try c.decode([RulePredicate].self, forKey: RuleKey("any"))); return }
        if c.contains(RuleKey("not")) { self = .not(try c.decode(RulePredicate.self, forKey: RuleKey("not"))); return }
        switch try c.named(RuleVocabulary.Predicate.self, "is", "predicate") {
        case .heroHasRule:
            self = .heroHasRule(id: try c.string("id"), minTier: try c.intIfPresent("minTier") ?? 1)
        case .heroState:
            self = .heroState(id: try c.string("id"), minLevel: try c.intIfPresent("minLevel") ?? 1)
        case .heroFokusRule:
            self = .heroFokusRule(try c.string("value"))
        case .loadoutWeapon:
            self = .loadoutWeapon(technique: try c.strings("technique"), item: try c.stringIfPresent("item"),
                                  consecrated: try c.decodeIfPresent(Bool.self, forKey: RuleKey("consecrated")))
        case .loadoutShield:
            self = .loadoutShield(item: try c.stringIfPresent("item"))
        case .loadoutReach:
            self = .loadoutReach(try c.named(WeaponReach.self, "value", "reach"))
        case .situationMounted:
            self = .situationMounted
        case .situationBeengt:
            self = .situationBeengt
        case .situationDefencesThisRound:
            self = .situationDefencesThisRound(min: try c.decode(Int.self, forKey: RuleKey("min")))
        case .situationTargetZone:
            let raws = try c.decode([String].self, forKey: RuleKey("value"))
            self = .situationTargetZone(try raws.map { raw in
                guard let zone = HitZone(rawValue: raw) else {
                    throw DecodingError.dataCorruptedError(forKey: RuleKey("value"), in: c, debugDescription: "unknown zone \(raw)")
                }
                return zone
            })
        case .situationWoundEffect:
            self = .situationWoundEffect
        case .opponentReach:
            self = .opponentReach(try c.named(WeaponReach.self, "value", "reach"))
        case .opponentOnFoot:
            self = .opponentOnFoot
        case .opponentState:
            self = .opponentState(try c.string("value"))
        case .opponentType:
            self = .opponentType(try c.named(RuleVocabulary.OpponentType.self, "value", "opponent type"))
        case .gmFact:
            self = .gmFact(id: try c.string("id"), span: try c.named(FactSpan.self, "span", "span"))
        }
    }
}

extension RuleTarget {
    static func decode(from c: KeyedDecodingContainer<RuleKey>) throws -> RuleTarget {
        switch try c.named(RuleVocabulary.Target.self, "target", "target") {
        case .at: .at
        case .pa: .pa
        case .aw: .aw
        case .vw: .vw
        case .fk: .fk
        case .tp: .tp
        case .talent: .talent(try c.string("talentId"))
        }
    }
}

extension RuleEffect: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: RuleKey.self)
        switch try c.named(RuleVocabulary.Effect.self, "effect", "effect") {
        case .add:
            self = .add(target: try RuleTarget.decode(from: c), value: try c.decode(Int.self, forKey: RuleKey("value")),
                        per: try c.decodeIfPresent(RuleVocabulary.Per.self, forKey: RuleKey("per")))
        case .multiply:
            self = .multiply(target: try RuleTarget.decode(from: c), factor: try c.decode(Double.self, forKey: RuleKey("factor")))
        case .opponentAdd:
            self = .opponentAdd(target: try RuleTarget.decode(from: c), value: try c.decode(Int.self, forKey: RuleKey("value")))
        case .modifyRule:
            self = .modifyRule(id: try c.string("id"), target: try RuleTarget.decode(from: c),
                               add: try c.intIfPresent("add"), set: try c.intIfPresent("set"),
                               multiply: try c.doubleIfPresent("multiply"))
        case .choice:
            self = .choice(try c.decode([RuleEffect].self, forKey: RuleKey("options")))
        }
    }
}

extension OfferTiers: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let n = try? c.decode(Int.self) { self = .fixed(n); return }
        let raw = try c.decode(String.self)
        guard raw == "owned" else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "tiers is \(raw), expected 'owned' or a number")
        }
        self = .owned
    }
}
