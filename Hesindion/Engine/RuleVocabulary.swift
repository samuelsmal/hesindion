import Foundation

/// The closed vocabulary a catalog clause is written in (design §4).
///
/// Every item has one interpreter in `RuleEvaluator` and one test; adding one
/// is a code change and a human decision. `exportJSON()` writes the same
/// vocabulary for the Python build, which refuses a clause outside it, and for
/// the Flutter rewrite, which interprets the same file.
///
/// Only what the first nine fixtures and the `GRW_*` entries need is here.
/// The rest of design §4 arrives with the authoring batch that needs it.
enum RuleVocabulary {
    static let version = 1

    enum Combinator: String, CaseIterable { case all, any, not }

    enum Predicate: String, CaseIterable {
        case heroHasRule = "hero.hasRule"
        case heroState = "hero.state"
        case heroFokusRule = "hero.fokusRule"
        case loadoutWeapon = "loadout.weapon"
        case loadoutShield = "loadout.shield"
        case loadoutReach = "loadout.reach"
        case situationMounted = "situation.mounted"
        case situationBeengt = "situation.beengt"
        case situationDefencesThisRound = "situation.defencesThisRound"
        case situationTargetZone = "situation.targetZone"
        case situationWater = "situation.water"
        case situationWoundEffect = "situation.woundEffect"
        case opponentReach = "opponent.reach"
        case opponentOnFoot = "opponent.onFoot"
        case opponentState = "opponent.state"
        case opponentType = "opponent.type"
        case gmFact = "gm.fact"
    }

    enum Effect: String, CaseIterable { case add, multiply, opponentAdd, modifyRule, choice }

    /// `vw` is the Verteidigungswert — parry and dodge both. `talent` carries
    /// a `talentId`.
    enum Target: String, CaseIterable { case at, pa, aw, vw, fk, tp, talent }

    /// What an `add` value is multiplied by.
    enum Per: String, CaseIterable, Codable { case tier, defencesThisRound }

    enum ClauseKind: String, CaseIterable, Codable { case passive, offer }

    enum OpponentType: String, CaseIterable, Codable { case demon }

    // MARK: - Signatures

    /// Argument types: `string`, `strings` (one or a list), `int`, `number`,
    /// `bool`, `enum:<name>`, `list:<enum name>`. `list:effect` (used by
    /// `choice`) refers to the `effects` table itself, the one `list:` token
    /// with no entry under `enums`.
    struct Signature {
        var args: [String: String] = [:]
        var required: [String] = []
        /// For items written as `{ name: scalar }` rather than `{ name: {…} }`.
        var value: String? = nil

        var json: [String: Any] {
            var d: [String: Any] = ["args": args, "required": required]
            if let value { d["value"] = value }
            return d
        }
    }

    static let predicateSignatures: [Predicate: Signature] = [
        .heroHasRule: Signature(args: ["id": "string", "minTier": "int"], required: ["id"]),
        .heroState: Signature(args: ["id": "string", "minLevel": "int"], required: ["id"]),
        .heroFokusRule: Signature(value: "string"),
        .loadoutWeapon: Signature(args: ["technique": "strings", "item": "string", "consecrated": "bool"]),
        .loadoutShield: Signature(args: ["item": "string"]),
        .loadoutReach: Signature(value: "enum:reach"),
        .situationMounted: Signature(),
        .situationBeengt: Signature(),
        .situationDefencesThisRound: Signature(args: ["min": "int"], required: ["min"]),
        .situationTargetZone: Signature(value: "list:zone"),
        .situationWater: Signature(value: "list:water"),
        .situationWoundEffect: Signature(),
        .opponentReach: Signature(value: "enum:reach"),
        .opponentOnFoot: Signature(),
        .opponentState: Signature(value: "string"),
        .opponentType: Signature(value: "enum:opponentType"),
        .gmFact: Signature(args: ["id": "string", "span": "enum:span"], required: ["id", "span"]),
    ]

    static let effectSignatures: [Effect: Signature] = [
        .add: Signature(args: ["target": "enum:target", "talentId": "string", "value": "int", "per": "enum:per"],
                        required: ["target", "value"]),
        .multiply: Signature(args: ["target": "enum:target", "talentId": "string", "factor": "number"],
                             required: ["target", "factor"]),
        .opponentAdd: Signature(args: ["target": "enum:target", "value": "int"], required: ["target", "value"]),
        .modifyRule: Signature(args: ["id": "string", "target": "enum:target", "talentId": "string",
                                      "add": "int", "set": "int", "multiply": "number"],
                               required: ["id", "target"]),
        .choice: Signature(value: "list:effect"),
    ]

    // MARK: - Export

    static func exportJSON() -> String {
        let root: [String: Any] = [
            "version": version,
            "combinators": Combinator.allCases.map(\.rawValue),
            "predicates": Dictionary(uniqueKeysWithValues: predicateSignatures.map { ($0.key.rawValue, $0.value.json) }),
            "effects": Dictionary(uniqueKeysWithValues: effectSignatures.map { ($0.key.rawValue, $0.value.json) }),
            "enums": [
                "target": Target.allCases.map(\.rawValue),
                "domain": RuleDomain.allCases.map(\.rawValue),
                "span": FactSpan.allCases.map(\.rawValue),
                "per": Per.allCases.map(\.rawValue),
                "reach": WeaponReach.allCases.map(\.rawValue),
                "zone": HitZone.allCases.map(\.rawValue),
                "water": WaterDepth.allCases.filter { $0 != .none }.map(\.rawValue),
                "opponentType": OpponentType.allCases.map(\.rawValue),
                "kind": ClauseKind.allCases.map(\.rawValue),
                "tiers": ["owned"],
            ],
        ]
        let data = try! JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}
