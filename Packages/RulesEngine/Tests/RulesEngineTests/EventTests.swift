import XCTest
@testable import RulesEngine

/// Events (spec §7): their shape and JSON, `gain` → `gained`/`cleared`, `Situation.applying` as
/// the one place state changes, and paying LeP is not damage (probe-magie 20.7).
final class EventTests: XCTestCase {
    private let engine = Engine(book: PoolTests.book)
    private var layer: ActionLayer { ActionLayer(engine: engine) }
    private func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }

    private func situation(owned: [String: Int] = [:], facts: [String: JSONValue] = [:], base: [String: Int] = [:],
                           pools: [Pool: PoolState] = [:]) -> Situation {
        PoolTests.situation(owned: owned, facts: facts, base: base, pools: pools)
    }

    // MARK: - Shape and JSON

    func testAnEventIsCodableAndCarriesItsOriginLikeALine() throws {
        let e = Event(kind: .paid, origin: ref("SA_74.VP1"), pool: .asp, amount: 3, via: [ref("kampfwerte.KW1")],
                      rulings: ["shared.round-up"], facts: [FactUse(name: "check.result", value: "success", owner: .roll)],
                      note: "n")
        let data = try JSONEncoder().encode(e)
        XCTAssertEqual(try JSONDecoder().decode(Event.self, from: data), e)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["kind"] as? String, "paid")
        XCTAssertEqual(object["pool"] as? String, "asp")
        XCTAssertEqual(object["amount"] as? Int, 3)
        XCTAssertEqual((object["origin"] as? [String: String]), ["rule": "SA_74", "clause": "VP1"])
        XCTAssertNil(object["rule"], "absent fields are left out")
        // The smallest event decodes: only its kind.
        let bare = try JSONDecoder().decode(Event.self, from: Data(#"{"kind":"gained","rule":"COND_2","levels":1}"#.utf8))
        XCTAssertEqual(bare, Event(kind: .gained, rule: "COND_2", levels: 1))
        let change = Event(kind: .itemChanged, item: "dolch-1", change: ["held": false])
        XCTAssertEqual(try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(change)), change)
    }

    func testTheSituationKeepsItsJSONShapeAfterEvents() throws {
        // Without `pools` (the compiled situations.json shape) it decodes as before.
        let old = try JSONDecoder().decode(Situation.self, from: Data(#"{"owned":{},"facts":[]}"#.utf8))
        XCTAssertEqual(old.pools, [:])
        let s = situation(owned: ["act-stunned": 2], pools: [.le: PoolState(current: 20, max: 29)])
            .applying([Event(kind: .paid, pool: .le, amount: 3), Event(kind: .gained, rule: "act-stunned", levels: 1)])
        let back = try JSONDecoder().decode(Situation.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
        XCTAssertEqual(back.pools[.le]?.current, 17)
        XCTAssertEqual(back.owned["act-stunned"]?.level, 3)
    }

    // MARK: - gain

    func testAGainGivesGainedAndANegativeLevelGivesCleared() {
        let s = situation(owned: ["act-stunned": 4], facts: ["choice.recover": true])
        let r = layer.perform(.cast(spell: "SPELL_1", modifications: []), in: s)
        XCTAssertEqual(r.events.map(\.kind), [.gained, .cleared])
        XCTAssertEqual(r.events.map(\.rule), ["act-helpless", "act-stunned"])
        XCTAssertEqual(r.events.map(\.levels), [1, 1])
        XCTAssertEqual(r.events.map(\.origin), [ref("act-stunned.S4"), ref("act-stunned.S5")])
        let after = s.applying(r.events)
        XCTAssertEqual(after.owned["act-helpless"], OwnedRule(level: 1))
        XCTAssertEqual(after.owned["act-stunned"]?.level, 3)
    }

    func testApplyingGainsAndClearsChangesTheLevelAndRemovesTheRuleAtZero() {
        let s = situation(owned: ["act-stunned": 1])
        let cleared = s.applying([Event(kind: .cleared, rule: "act-stunned", levels: 1)])
        XCTAssertNil(cleared.owned["act-stunned"])
        XCTAssertNil(s.applying([Event(kind: .cleared, rule: "act-stunned", levels: 3)]).owned["act-stunned"])
        XCTAssertNil(s.applying([Event(kind: .cleared, rule: "act-stunned")]).owned["act-stunned"], "no levels: all")
        XCTAssertEqual(s.applying([Event(kind: .gained, rule: "act-stunned", levels: 2)]).owned["act-stunned"]?.level, 3)
        XCTAssertEqual(situation().applying([Event(kind: .gained, rule: "act-helpless")]).owned["act-helpless"]?.level, 1)
        XCTAssertEqual(s.applying([Event(kind: .gained, rule: "act-stunned", levels: -1)]).owned["act-stunned"], nil,
                       "a negative gain lowers too")
    }

    func testTheStateActionGainsAndClearsWithinTheRulesStufen() {
        let s = situation(owned: ["act-stunned": 3])
        let up = layer.perform(.state(rule: "act-stunned", levels: 2), in: s)
        XCTAssertEqual(up.events, [Event(kind: .gained, rule: "act-stunned", levels: 1, note: "höchstens Stufe 4")])
        XCTAssertEqual(s.applying(up.events).owned["act-stunned"]?.level, 4)
        let down = layer.perform(.state(rule: "act-stunned", levels: -2), in: s)
        XCTAssertEqual(down.events, [Event(kind: .cleared, rule: "act-stunned", levels: 2)])
        XCTAssertEqual(s.applying(down.events).owned["act-stunned"]?.level, 1)
        // A state has no Stufen: owning it once is all.
        let helpless = situation(owned: ["act-helpless": 1])
        let again = layer.perform(.state(rule: "act-helpless", levels: 1), in: helpless)
        XCTAssertEqual(again.events.map(\.levels), [0])
        XCTAssertEqual(helpless.applying(again.events).owned["act-helpless"]?.level, 1)
        // A rule the book does not have is a text, no event.
        let unknown = layer.perform(.state(rule: "act-nothing", levels: 1), in: s)
        XCTAssertEqual(unknown.events, [])
        XCTAssertEqual(unknown.texts.map(\.kind), [.notApplicable])
    }

    func testAGainReadsItsRuleFromATable() {
        let head = layer.perform(.cast(spell: "SPELL_1", modifications: []),
                                 in: situation(facts: ["gmFact.wound": true, "hit.zone": "kopf"]))
        XCTAssertEqual(head.events.filter { $0.origin == ref("act-zones.Z1") }.map(\.rule), ["act-stunned"])
        let open = layer.perform(.cast(spell: "SPELL_1", modifications: []), in: situation(facts: ["gmFact.wound": true]))
        XCTAssertEqual(open.events.filter { $0.origin == ref("act-zones.Z1") }, [])
        XCTAssertTrue(open.questions.contains { $0.fact == "hit.zone" && $0.origins == [ref("act-zones.Z1")] })
    }

    func testTheSchipSuppressStopsAConditionsGain() {
        // schmerz S9: the Schip's `suppress { ruleKind: condition }` stops Schmerz IV's gain.
        let s = situation(owned: ["act-stunned": 4], facts: ["choice.schipZustand": true])
        let r = layer.perform(.cast(spell: "SPELL_1", modifications: []), in: s)
        XCTAssertEqual(r.events.filter { $0.kind == .gained }, [])
        let entry = r.notApplied.first { $0.origin == ref("act-stunned.S4") }
        XCTAssertEqual(entry?.reason, .suppressed)
        XCTAssertEqual(entry?.via, [ref("act-schip.SP1")])
        XCTAssertEqual(entry?.because, "Schip, Zustand ignorieren")
    }

    // MARK: - Paying LeP is not damage (probe-magie 20.7)

    func testPayingLePLowersLEOnlyAndNoDamageFollows() {
        let s = situation(owned: ["act-stunned": 1], facts: ["attr.KO": 12], base: ["at": 12],
                          pools: [.le: PoolState(current: 25, max: 29), .asp: PoolState(current: 3, max: 30)])
        let r = layer.perform(.pay(.le, 8), in: s)
        XCTAssertEqual(r.events, [Event(kind: .paid, pool: .le, amount: 8)])
        // No RS, Wundschwelle or Wundeffekt: no event but the payment, no question about a hit.
        XCTAssertTrue(r.events.allSatisfy { $0.kind == .paid })
        XCTAssertFalse(r.questions.contains { $0.fact.hasPrefix("hit.") })
        let after = s.applying(r.events)
        XCTAssertEqual(after.pools[.le]?.current, 17)
        XCTAssertEqual(after.pools[.asp], s.pools[.asp])
        XCTAssertEqual(after.owned, s.owned)
        XCTAssertEqual(after.facts, s.facts)
        XCTAssertEqual(after.base, s.base)
        XCTAssertFalse(after.facts.keys.contains { $0.hasPrefix("hit.") }, "a payment states no hit")
    }
}
