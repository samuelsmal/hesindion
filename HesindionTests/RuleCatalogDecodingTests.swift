import XCTest
@testable import Hesindion

/// The JSON the Python build writes into `catalog.clauses` is the contract
/// between the two sides; these are the shapes it takes.
final class RuleCatalogDecodingTests: XCTestCase {

    private func predicate(_ json: String) throws -> RulePredicate {
        try JSONDecoder().decode(RulePredicate.self, from: Data(json.utf8))
    }

    private func clauses(_ json: String) throws -> [RuleClause] {
        try JSONDecoder().decode([RuleClause].self, from: Data(json.utf8))
    }

    /// The design's worked example, as `catalog.entry_json` emits it.
    func testTheDesignExampleDecodes() throws {
        let applies = try predicate("""
        {"all": [{"is": "situation.mounted"},
                 {"any": [{"is": "loadout.weapon", "technique": "CT_5", "item": "Rabenschnabel"},
                          {"is": "loadout.shield", "item": "Großschild"}]}]}
        """)
        XCTAssertEqual(applies, .all([
            .situationMounted,
            .any([.loadoutWeapon(technique: ["CT_5"], item: "Rabenschnabel", consecrated: nil),
                  .loadoutShield(item: "Großschild")]),
        ]))
        let decoded = try clauses("""
        [{"kind": "passive", "domains": ["meleeAttack"], "when": {"all": [{"is": "opponent.onFoot"}]},
          "effects": [{"effect": "modifyRule", "id": "GRW_vorteilhaftePosition", "target": "at", "add": 2}]},
         {"kind": "passive", "domains": ["meleeParry"],
          "effects": [{"effect": "add", "target": "pa", "value": 1}]}]
        """)
        XCTAssertEqual(decoded, [
            RuleClause(kind: .passive, domains: [.meleeAttack], when: .all([.opponentOnFoot]),
                       effects: [.modifyRule(id: "GRW_vorteilhaftePosition", target: .at, add: 2, set: nil, multiply: nil)],
                       tiers: nil),
            RuleClause(kind: .passive, domains: [.meleeParry], when: nil,
                       effects: [.add(target: .pa, value: 1, per: nil)], tiers: nil),
        ])
    }

    func testScalarPredicatesAndLists() throws {
        XCTAssertEqual(try predicate(#"{"is": "hero.fokusRule", "value": "trefferzonen"}"#), .heroFokusRule("trefferzonen"))
        XCTAssertEqual(try predicate(#"{"is": "loadout.reach", "value": "Kurz"}"#), .loadoutReach(.kurz))
        XCTAssertEqual(try predicate(#"{"is": "opponent.reach", "value": "Lang"}"#), .opponentReach(.lang))
        XCTAssertEqual(try predicate(#"{"is": "situation.targetZone", "value": ["kopf", "torso"]}"#), .situationTargetZone([.kopf, .torso]))
        XCTAssertEqual(try predicate(#"{"is": "opponent.state", "value": "liegend"}"#), .opponentState("liegend"))
        XCTAssertEqual(try predicate(#"{"is": "opponent.type", "value": "demon"}"#), .opponentType(.demon))
        XCTAssertEqual(try predicate(#"{"is": "loadout.weapon", "technique": ["CT_1", "CT_4"], "consecrated": true}"#),
                       .loadoutWeapon(technique: ["CT_1", "CT_4"], item: nil, consecrated: true))
        XCTAssertEqual(try predicate(#"{"is": "hero.hasRule", "id": "SA_67"}"#), .heroHasRule(id: "SA_67", minTier: 1))
        XCTAssertEqual(try predicate(#"{"is": "hero.state", "id": "liegend", "minLevel": 2}"#), .heroState(id: "liegend", minLevel: 2))
        XCTAssertEqual(try predicate(#"{"is": "situation.defencesThisRound", "min": 1}"#), .situationDefencesThisRound(min: 1))
        XCTAssertEqual(try predicate(#"{"is": "gm.fact", "id": "opposingDeity", "span": "attack"}"#), .gmFact(id: "opposingDeity", span: .attack))
        XCTAssertEqual(try predicate(#"{"not": {"is": "situation.beengt"}}"#), .not(.situationBeengt))
        XCTAssertEqual(try predicate(#"{"is": "situation.woundEffect"}"#), .situationWoundEffect)
    }

    func testEffectsTargetsTiersAndChoices() throws {
        let decoded = try clauses("""
        [{"kind": "offer", "domains": ["meleeAttack", "damage"], "tiers": "owned",
          "effects": [{"effect": "add", "target": "at", "value": -2, "per": "tier"},
                      {"effect": "multiply", "target": "tp", "factor": 2},
                      {"effect": "opponentAdd", "target": "vw", "value": -2},
                      {"effect": "add", "target": "talent", "talentId": "TAL_8", "value": -2}]},
         {"kind": "offer", "domains": ["meleeParry"], "tiers": 3,
          "effects": [{"effect": "choice", "options": [{"effect": "add", "target": "at", "value": 1},
                                                       {"effect": "add", "target": "vw", "value": 1}]}]}]
        """)
        XCTAssertEqual(decoded[0].tiers, .owned)
        XCTAssertEqual(decoded[0].effects, [
            .add(target: .at, value: -2, per: .tier),
            .multiply(target: .tp, factor: 2),
            .opponentAdd(target: .vw, value: -2),
            .add(target: .talent("TAL_8"), value: -2, per: nil),
        ])
        XCTAssertEqual(decoded[1].tiers, .fixed(3))
        XCTAssertEqual(decoded[1].effects, [.choice([.add(target: .at, value: 1, per: nil), .add(target: .vw, value: 1, per: nil)])])
    }

    func testAnUnknownNameIsADecodingError() {
        for bad in [
            #"{"is": "situation.raining"}"#,
            #"{"is": "loadout.reach", "value": "Weit"}"#,
            #"{"is": "situation.targetZone", "value": ["nase"]}"#,
            #"{"is": "gm.fact", "id": "x", "span": "century"}"#,
            #"{"is": "opponent.type", "value": "dragon"}"#,
        ] {
            XCTAssertThrowsError(try predicate(bad), bad) { XCTAssertTrue($0 is DecodingError, "\($0)") }
        }
        XCTAssertThrowsError(try clauses(#"[{"kind": "passive", "domains": ["meleeAttack"], "effects": [{"effect": "sing"}]}]"#))
        XCTAssertThrowsError(try clauses(#"[{"kind": "passive", "domains": ["meleeAttack"], "effects": [{"effect": "add", "target": "luck", "value": 1}]}]"#))
    }

    func testOwnershipIsByPrefix() {
        func rule(_ id: String) -> CatalogRule { CatalogRule(id: id, name: id, reviewed: false, appliesWith: nil, clauses: []) }
        XCTAssertTrue(rule("SA_661").needsOwnership)
        XCTAssertTrue(rule("DISADV_57").needsOwnership)
        XCTAssertFalse(rule("GRW_reichweite").needsOwnership)
        XCTAssertFalse(rule("COND_6").needsOwnership)
        XCTAssertFalse(rule("STATE_10").needsOwnership)
    }

    // MARK: - Against the bundled database

    func testEveryImplementedEntryDecodes() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        let expected = RulesDatabase.shared.catalogStatusCounts()[.implemented] ?? 0
        XCTAssertEqual(RulesDatabase.shared.implementedRules().count, expected)
        XCTAssertEqual(RuleCatalog.bundled.implemented.count, expected)
        XCTAssertEqual(RuleCatalog.bundled.statuses.count, RulesDatabase.shared.allCatalogEntries().count)
    }
}
