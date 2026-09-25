import XCTest
@testable import RulesEngine

/// The action layer's costs (plan Task 25): `cost` → `paid` events, the pools, `split`,
/// `fallThrough`, `onFailure`, offer costs (R23), the suppress of a cost (SA_74.VP1 over ZM12), and
/// the current LE/AsP read from the pools (R39). Fixture book `Fixtures/actions-rules.json` (source:
/// `Tests/FixtureRules/actions`, rebuilt by `make rules-engine-fixture`).
final class PoolTests: XCTestCase {
    static let book: RuleBook = {
        let url = Bundle.module.url(forResource: "actions-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    private let engine = Engine(book: PoolTests.book)
    private var layer: ActionLayer { ActionLayer(engine: engine) }

    static func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }
    private func ref(_ text: String) -> ClauseRef { Self.ref(text) }

    static func situation(owned: [String: Int] = [:], facts: [String: JSONValue] = [:], base: [String: Int] = [:],
                          pools: [Pool: PoolState] = [:]) -> Situation {
        Situation(owned: owned.mapValues { OwnedRule(level: $0) },
                  facts: facts.sorted { $0.key < $1.key }.map {
                      Fact(name: $0.key, value: $0.value, owner: Vocabulary.owner(ofFact: $0.key) ?? .sheet)
                  },
                  base: base, pools: pools)
    }

    private func situation(owned: [String: Int] = [:], facts: [String: JSONValue] = [:], base: [String: Int] = [:],
                           pools: [Pool: PoolState] = [:]) -> Situation {
        Self.situation(owned: owned, facts: facts, base: base, pools: pools)
    }

    private let magic: [Pool: PoolState] = [.asp: PoolState(current: 5, max: 30), .le: PoolState(current: 29, max: 29)]

    private func paid(_ r: ActionResult) -> [Event] { r.events.filter { $0.kind == .paid } }

    // MARK: - fallThrough

    func testTheProbeMagieCaseFallsThroughFromAsPToLeP() {
        // Plan Task 25: 8 AsP asked, AsP 5 → paid(asp, 5), paid(le, 3).
        let s = situation(owned: ["act-fall": 1], facts: ["choice.fall": true], base: ["spell.cost": 8], pools: magic)
        let r = layer.perform(.cast(spell: "SPELL_1", modifications: []), in: s)
        XCTAssertEqual(r.events.map(\.kind), [.paid, .paid])
        XCTAssertEqual(r.events.map(\.pool), [.asp, .le])
        XCTAssertEqual(r.events.map(\.amount), [5, 3])
        XCTAssertEqual(r.events.map(\.origin), [ref("act-fall.F1"), ref("act-fall.F1")])
        let after = s.applying(r.events)
        XCTAssertEqual(after.pools[.asp], PoolState(current: 0, max: 30))
        XCTAssertEqual(after.pools[.le], PoolState(current: 26, max: 29))
        // The cast states its own facts; the ordinary cost's `when` (check.result) stays open and asks.
        XCTAssertTrue(r.questions.contains { $0.fact == "check.result" })
    }

    func testAPoolThatCanPayAloneDoesNotFallThrough() {
        let s = situation(owned: ["act-fall": 1], facts: ["choice.fall": true], base: ["spell.cost": 4], pools: magic)
        let r = layer.perform(.cast(spell: "SPELL_1", modifications: []), in: s)
        XCTAssertEqual(r.events.map(\.pool), [.asp])
        XCTAssertEqual(r.events.map(\.amount), [4])
    }

    func testTheCastPaysItsSpellCostAndItsBreakdownComesAlong() {
        let s = situation(facts: ["check.result": "success"], base: ["spell.cost": 6], pools: magic)
        let r = layer.perform(.cast(spell: "SPELL_1", modifications: []), in: s)
        // AsP 5 and no fallThrough: the cast cannot be paid.
        XCTAssertEqual(r.events, [])
        XCTAssertEqual(r.texts.map(\.text),
                       ["Regel konnte nicht angewandt werden: act-magie.M1 – 6 asp gefordert, 5 vorhanden"])
        var rich = situation(facts: ["check.result": "success"], base: ["spell.cost": 6])
        rich.pools = [.asp: PoolState(current: 30, max: 30)]
        let ok = layer.perform(.cast(spell: "SPELL_1", modifications: []), in: rich)
        XCTAssertEqual(ok.events.map(\.amount), [6])
        XCTAssertEqual(ok.events.first?.origin, ref("act-magie.M1"))
        XCTAssertEqual(ok.events.first?.facts.map(\.name), ["check.kind", "check.result"])
        XCTAssertEqual(ok.breakdowns.map(\.query.description), ["spell.cost"])
        XCTAssertEqual(ok.breakdowns.first?.result, 6)
    }

    func testACastStatesItsSpellAndModifications() {
        let s = situation()
        let stated = ActionLayer.stated(.cast(spell: "SPELL_1", modifications: ["erzwingen"]), in: s)
        XCTAssertEqual(stated.facts["check.kind"]?.value, "spell")
        XCTAssertEqual(stated.facts["check.spell"]?.value, "SPELL_1")
        XCTAssertEqual(stated.facts["choice.spellModification.erzwingen"]?.value, true)
        XCTAssertEqual(stated.facts["check.kind"]?.owner, .player)
    }

    // MARK: - Shortfalls and absent pools

    func testAShortPoolWithoutFallThroughPaysNothingAndSaysSo() {
        let r = layer.perform(.pay(.asp, 10), in: situation(pools: magic))
        XCTAssertEqual(r.events, [])
        XCTAssertEqual(r.texts.map(\.kind), [.notApplicable])
        XCTAssertEqual(r.texts.first?.text, "Kosten konnten nicht bezahlt werden: 10 asp gefordert, 5 vorhanden")
    }

    func testLePMayBePaidBelowZero() {
        let r = layer.perform(.pay(.le, 40), in: situation(pools: magic))
        XCTAssertEqual(r.events, [Event(kind: .paid, pool: .le, amount: 40)])
        XCTAssertEqual(situation(pools: magic).applying(r.events).pools[.le]?.current, -11)
    }

    func testAnAbsentPoolIsPaidWithoutACheckAndStaysAbsent() {
        let s = situation()
        let r = layer.perform(.take(choice: "doppel"), in: s)
        XCTAssertEqual(r.events, [Event(kind: .paid, origin: ref("act-moves.A1"), pool: .actions, amount: 1)])
        XCTAssertEqual(s.applying(r.events).pools, [:])
    }

    // MARK: - Offer costs (R23)

    func testTakingAnOfferPaysItsActionCostFromTheActionsPool() {
        let s = situation(pools: [.actions: PoolState(current: 1, max: 1), .freeActions: PoolState(current: 1, max: 1)])
        let r = layer.perform(.take(choice: "doppel"), in: s)
        XCTAssertEqual(r.events, [Event(kind: .paid, origin: ref("act-moves.A1"), pool: .actions, amount: 1)])
        let after = s.applying(r.events)
        XCTAssertEqual(after.pools[.actions]?.current, 0)
        XCTAssertEqual(after.pools[.freeActions]?.current, 1)
        // No action left: nothing is paid, and the screen says why.
        let again = layer.perform(.take(choice: "doppel"), in: after)
        XCTAssertEqual(again.events, [])
        XCTAssertEqual(again.texts.map(\.kind), [.notApplicable])
    }

    func testAnOfferWithoutCostsPaysNothing() {
        // passierschlag.PS2 (kampfsituationen 17.7): `events: []`.
        let r = layer.perform(.take(choice: "passierschlag"), in: situation(pools: [.actions: PoolState(current: 1, max: 1)]))
        XCTAssertEqual(r.events, [])
        XCTAssertEqual(r.texts, [])
    }

    func testAnIllegalOfferIsNotPaidAndItsReasonsAreRecorded() {
        let r = layer.perform(.take(choice: "doppel"), in: situation(facts: ["gmFact.noDouble": true]))
        XCTAssertEqual(r.events, [])
        XCTAssertEqual(r.notApplied.map(\.origin), [ref("act-moves.A3")])
        XCTAssertEqual(r.notApplied.map(\.reason), [.forbidden])
    }

    func testAChoiceNobodyOffersIsATextAndNoPayment() {
        let r = layer.perform(.take(choice: "nirgends"), in: situation())
        XCTAssertEqual(r.events, [])
        XCTAssertEqual(r.texts.map(\.kind), [.notApplicable])
    }

    // MARK: - split

    func testASplitTakesThePlayersShareAndChecksEachMinimum() {
        let pools: [Pool: PoolState] = [.asp: PoolState(current: 10, max: 30), .kap: PoolState(current: 10, max: 20)]
        let unknown = layer.perform(.cast(spell: "SPELL_1", modifications: []),
                                    in: situation(owned: ["act-fall": 1], facts: ["choice.share": true], pools: pools))
        XCTAssertEqual(unknown.events, [])
        let q = unknown.questions.first { $0.fact == "choice.split.kap" }
        XCTAssertEqual(q?.owner, .player)
        XCTAssertEqual(q?.origins, [ref("act-fall.F2")])
        XCTAssertTrue(unknown.notApplied.contains { $0.origin == ref("act-fall.F2") && $0.reason == .unknownFact })

        let below = layer.perform(.cast(spell: "SPELL_1", modifications: []),
                                  in: situation(owned: ["act-fall": 1], facts: ["choice.share": true, "choice.split.kap": 5],
                                                pools: pools))
        XCTAssertEqual(below.events, [])
        XCTAssertEqual(below.texts.map(\.text),
                       ["Regel konnte nicht angewandt werden: act-fall.F2 – mindestens 2 asp, gewählt 1"])

        let ok = layer.perform(.cast(spell: "SPELL_1", modifications: []),
                               in: situation(owned: ["act-fall": 1], facts: ["choice.share": true, "choice.split.kap": 4],
                                             pools: pools))
        XCTAssertEqual(ok.events.map(\.pool), [.asp, .kap])
        XCTAssertEqual(ok.events.map(\.amount), [2, 4])
    }

    // MARK: - SA_74 shapes: split.le, the suppressed ordinary cost, onFailure

    func testVerbotenePfortenSplitsTheCostAndTheOrdinaryCostIsSuppressed() {
        // probe-magie 20.7: cost 8, 5 LeP chosen, AsP 3 → paid(asp, 3), paid(le, 5); ZM12 suppressed.
        let s = situation(owned: ["act-pforten": 1],
                          facts: ["choice.split.le": 5, "check.result": "success"], base: ["spell.cost": 8],
                          pools: [.asp: PoolState(current: 3, max: 30), .le: PoolState(current: 29, max: 29)])
        let r = layer.perform(.cast(spell: "SPELL_1", modifications: []), in: s)
        XCTAssertEqual(r.events.map(\.pool), [.asp, .le])
        XCTAssertEqual(r.events.map(\.amount), [3, 5])
        XCTAssertEqual(r.events.map(\.origin), [ref("act-pforten.P1"), ref("act-pforten.P1")])
        let suppressed = r.notApplied.filter { $0.origin == ref("act-magie.M1") && $0.reason == .suppressed }
        // Both of M1's costs are stopped; their entries are equal, so `record` keeps one.
        XCTAssertEqual(suppressed.count, 1)
        XCTAssertFalse(r.events.contains { $0.origin == ref("act-magie.M1") })
        XCTAssertEqual(suppressed.first?.via, [ref("act-pforten.P1")])
        XCTAssertEqual(suppressed.first?.because, "Pforten: die Kosten werden geteilt")
        let after = s.applying(r.events)
        XCTAssertEqual(after.pools[.asp]?.current, 0)
        XCTAssertEqual(after.pools[.le]?.current, 24)
    }

    func testWithoutTheSplitTheOrdinaryCostIsPaid() {
        let s = situation(owned: ["act-pforten": 1], facts: ["choice.split.le": 0, "check.result": "success"],
                          base: ["spell.cost": 8], pools: [.asp: PoolState(current: 10, max: 30)])
        let r = layer.perform(.cast(spell: "SPELL_1", modifications: []), in: s)
        XCTAssertEqual(r.events, [Event(kind: .paid, origin: ref("act-magie.M1"), pool: .asp, amount: 8)].map {
            var e = $0; e.facts = r.events.first?.facts ?? []; e.via = r.events.first?.via ?? []; return e
        })
        XCTAssertFalse(r.notApplied.contains { $0.reason == .suppressed })
    }

    func testOnFailureHalvesRoundedUpThenFallsThrough() {
        // probe-magie 20.8's shape: cost 7 → 4 on a failure (3.5 up), AsP 3 → paid(asp, 3), paid(le, 1).
        let s = situation(owned: ["act-pforten": 1], facts: ["choice.split.le": 5, "check.result": "failure"],
                          base: ["spell.cost": 7],
                          pools: [.asp: PoolState(current: 3, max: 30), .le: PoolState(current: 29, max: 29)])
        let r = layer.perform(.cast(spell: "SPELL_1", modifications: []), in: s)
        XCTAssertEqual(r.events.map(\.pool), [.asp, .le])
        XCTAssertEqual(r.events.map(\.amount), [3, 1])
        XCTAssertEqual(r.events.map(\.origin), [ref("act-pforten.P3"), ref("act-pforten.P3")])
        XCTAssertTrue(r.notApplied.contains { $0.origin == ref("act-magie.M1") && $0.reason == .suppressed })
        let plain = layer.perform(.cast(spell: "SPELL_1", modifications: []),
                                  in: situation(facts: ["check.result": "failure"], base: ["spell.cost": 7],
                                                pools: [.asp: PoolState(current: 30, max: 30)]))
        XCTAssertEqual(plain.events.map(\.amount), [4])
        XCTAssertEqual(plain.events.map(\.origin), [ref("act-magie.M1")])
    }

    func testTheSplitOfferIsBoundByTheCostLessTheOtherPoolsMinimum() {
        // probe-magie 20.7: `offered: [{ choice: split.le, max: 7 }]` for a cost of 8, at least 1 AsP.
        let s = situation(owned: ["act-pforten": 1], facts: ["check.kind": "spell"], base: ["spell.cost": 8],
                          pools: [.asp: PoolState(current: 3, max: 30)])
        let offer = engine.offers(in: s).first { $0.choice == "split.le" }
        XCTAssertEqual(offer?.max, 7)
        XCTAssertEqual(offer?.legal, true)
        // No AsP left: the split may not be chosen (SA_74.VP1's forbid reads hero.aspCurrent).
        var empty = s
        empty.pools[.asp] = PoolState(current: 0, max: 30)
        XCTAssertEqual(engine.offers(in: empty).first { $0.choice == "split.le" }?.legal, false)
    }

    // MARK: - The current pools as facts and targets (R39)

    func testHeroLeCurrentAndAspCurrentComeFromThePools() {
        let s = situation(pools: magic)
        XCTAssertEqual(s.fact("hero.leCurrent"), FactUse(name: "hero.leCurrent", value: .int(29), owner: .derived))
        XCTAssertEqual(s.fact("hero.aspCurrent"), FactUse(name: "hero.aspCurrent", value: .int(5), owner: .derived))
        XCTAssertNil(situation().fact("hero.leCurrent"), "no pool: unknown")
        XCTAssertNil(situation().fact("hero.aspCurrent"))
    }

    func testTheCurrentPoolIsTheBaseOfItsTarget() throws {
        let s = situation(base: ["leCurrent": 12], pools: magic)
        let b = engine.evaluate(Query("leCurrent"), in: s)
        let base = try XCTUnwrap(b.base)
        XCTAssertEqual(base.value, 29)
        XCTAssertEqual(base.facts.map(\.name), ["hero.leCurrent"])
        XCTAssertEqual(engine.evaluate(Query("aspCurrent"), in: s).result, 5)
        // Without the pool the sheet's base stands.
        XCTAssertEqual(engine.evaluate(Query("leCurrent"), in: situation(base: ["leCurrent": 12])).result, 12)
    }

    func testARuleReadingTheCurrentLESeesTheLoweredValueOnTheNextQuery() {
        // The brief's test, per R39: `when: { hero.leCurrent: { below: 20 } }`.
        let s = situation(base: ["at": 12], pools: [.le: PoolState(current: 25, max: 29)])
        let before = engine.evaluate(Query("at"), in: s)
        XCTAssertFalse(before.lines.contains { $0.origin == ref("act-low.L1") })
        XCTAssertEqual(before.notApplied.first { $0.origin == ref("act-low.L1") }?.reason, .conditionFalse)
        let r = layer.perform(.pay(.le, 6), in: s)
        let after = engine.evaluate(Query("at"), in: s.applying(r.events))
        XCTAssertEqual(after.lines.filter { $0.origin == ref("act-low.L1") }.map(\.value), [-2])
        XCTAssertEqual(after.result, 10)
        XCTAssertEqual(engine.evaluate(Query("leCurrent"), in: s.applying(r.events)).result, 19)
        // No pool: the fact is unknown, and asked.
        let unknown = engine.evaluate(Query("at"), in: situation(base: ["at": 12]))
        XCTAssertEqual(unknown.notApplied.first { $0.origin == ref("act-low.L1") }?.reason, .unknownFact)
    }

    // MARK: - Real data (build/rules/rules.json): SA_74 over ZM12

    func testVerbotenePfortenOnTheRealRules() throws {
        let url = Repo.url("build/rules/rules.json")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("run make rules-json") }
        let real = ActionLayer(engine: Engine(book: try RuleBook.load(from: url)))
        let pools: [Pool: PoolState] = [.asp: PoolState(current: 3, max: 30), .le: PoolState(current: 29, max: 29)]
        let facts: [String: JSONValue] = ["choice.split.le": 5, "fw.SPELL_21": 9, "fw.TAL_8": 6, "attr.MU": 13,
                                          "attr.KL": 14, "attr.IN": 13, "attr.CH": 12, "attr.KO": 12]
        // 20.7: a success.
        var f = facts
        f["check.result"] = "success"
        let s = situation(owned: ["SA_74": 1], facts: f, base: ["spell.cost": 8], pools: pools)
        let r = real.perform(.cast(spell: "SPELL_21", modifications: []), in: s)
        XCTAssertEqual(paid(r).map(\.pool), [.asp, .le])
        XCTAssertEqual(paid(r).map(\.amount), [3, 5])
        XCTAssertEqual(paid(r).map(\.origin), [ClauseRef("SA_74.VP1"), ClauseRef("SA_74.VP1")])
        XCTAssertTrue(r.notApplied.contains { $0.origin == ClauseRef("zaubermodifikationen.ZM12")! && $0.reason == .suppressed })
        let after = s.applying(r.events)
        XCTAssertEqual(after.pools[.asp]?.current, 0)
        XCTAssertEqual(after.pools[.le]?.current, 24)
        // 20.8: a failure. VP3 rests on the open ruling SA_74.vp-sequence, so it applies nothing
        // and shows its clause and the question; ZM12 stays suppressed: nothing is paid (pending).
        f["check.result"] = "failure"
        let failed = real.perform(.cast(spell: "SPELL_21", modifications: []),
                                  in: situation(owned: ["SA_74": 1], facts: f, base: ["spell.cost": 8], pools: pools))
        XCTAssertEqual(paid(failed), [])
        XCTAssertTrue(failed.notApplied.contains { $0.origin == ClauseRef("SA_74.VP3")! && $0.reason == .openRuling })
        XCTAssertTrue(failed.texts.contains { $0.kind == .openRuling && $0.ruling == "SA_74.vp-sequence" })
        // 20.7's offer of split.le rests on the same open ruling: not offered on the real rules
        // (the fixture test above shows its max, 7).
        let offers = real.engine.offers(in: situation(owned: ["SA_74": 1], facts: ["check.kind": "spell"],
                                                      base: ["spell.cost": 8], pools: pools))
        XCTAssertNil(offers.first { $0.choice == "split.le" })
    }
}
