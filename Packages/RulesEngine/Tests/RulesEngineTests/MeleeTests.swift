import XCTest
@testable import RulesEngine

/// Task 31, melee attack and defence, on the fixture book `Fixtures/melee-rules.json` (source:
/// `Tests/FixtureRules/melee`, rebuilt by `make rules-engine-fixture`).
final class MeleeTests: XCTestCase {
    private static let book: RuleBook = {
        let url = Bundle.module.url(forResource: "melee-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    private let engine = Engine(book: MeleeTests.book)

    private func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }

    private func situation(owned: [String: Int] = [:], facts: [String: JSONValue] = [:],
                           base: [String: Int] = [:]) -> Situation {
        Situation(owned: owned.mapValues { OwnedRule(level: $0) },
                  facts: facts.sorted { $0.key < $1.key }.map {
                      Fact(name: $0.key, value: $0.value, owner: Vocabulary.owner(ofFact: $0.key) ?? .sheet)
                  }, base: base)
    }

    private func lines(_ b: Breakdown, from origin: String) -> [Line] {
        b.lines.filter { $0.origin == ref(origin) }
    }

    // MARK: - A limit counts the other choices taken

    func testTheChosenManoeuvreIsStillOfferedUnderItsOwnLimit() throws {
        let s = situation(owned: ["me-finte": 1, "me-wucht": 1], facts: ["choice.finte": true, "hero.gs": 8])
        let finte = try XCTUnwrap(engine.offers(in: s).first { $0.choice == "finte" })
        XCTAssertTrue(finte.legal, "\(finte.reasons)")
        let wucht = try XCTUnwrap(engine.offers(in: s).first { $0.choice == "wuchtschlag" })
        XCTAssertFalse(wucht.legal)
        XCTAssertEqual(wucht.reasons.map(\.origin), [ref("me-core.K3")])
    }

    // MARK: - reach.gap

    func testTheReachGapCountsTheStepsTheOpponentIsLonger() throws {
        let s = situation(facts: ["loadout.reach": "kurz", "opponent.reach": "lang"], base: ["at": 14])
        let b = engine.evaluate(Query("at"), in: s)
        let line = try XCTUnwrap(lines(b, from: "me-core.R3").first)
        XCTAssertEqual(line.value, -4)
        XCTAssertEqual(line.facts.first { $0.name == "reach.gap" }?.value, 2)
        let longer = engine.evaluate(Query("at"), in: situation(facts: ["loadout.reach": "lang", "opponent.reach": "kurz"],
                                                                 base: ["at": 14]))
        XCTAssertEqual(lines(longer, from: "me-core.R3"), [])
        XCTAssertEqual(longer.notApplied.first { $0.origin == ref("me-core.R3") }?.reason, .conditionFalse)
    }

    func testWithoutTheOpponentsReachTheGapAsksForIt() {
        let b = engine.evaluate(Query("at"), in: situation(facts: ["loadout.reach": "kurz"], base: ["at": 14]))
        XCTAssertTrue(b.questions.map(\.fact).contains("opponent.reach"), "\(b.questions.map(\.fact))")
        XCTAssertFalse(b.questions.map(\.fact).contains("reach.gap"))
    }

    // MARK: - The defence an attack or a dodge is

    func testAnAttackAndADodgeAreNoShieldParry() throws {
        let s = situation(facts: ["round.doubleAttack": true], base: ["at": 14, "aw": 7, "pa": 8])
        XCTAssertEqual(lines(engine.evaluate(Query("at(with: mainHand)"), in: s), from: "me-core.Z3").map(\.value), [-2])
        XCTAssertEqual(lines(engine.evaluate(Query("aw"), in: s), from: "me-core.Z3").map(\.value), [-2])
        XCTAssertEqual(lines(engine.evaluate(Query("pa(with: shield)"), in: s), from: "me-core.Z3"), [])
    }

    // MARK: - An enabling require on a rule that applies anyway

    func testAnEnablerGivesItsViaToACoreRule() throws {
        let b = engine.evaluate(Query("at"), in: situation(facts: ["hero.mounted": true], base: ["at": 14]))
        let line = try XCTUnwrap(lines(b, from: "me-position.P1").first)
        XCTAssertEqual(line.via, [ref("me-rider.R2")])
        let onFoot = engine.evaluate(Query("at"), in: situation(facts: ["hero.mounted": false, "gmFact.vorteilhaftePosition": true],
                                                                 base: ["at": 14]))
        XCTAssertEqual(lines(onFoot, from: "me-position.P1").first?.via, [])
    }

    // MARK: - hero.gs

    func testHeroGSIsTheGSQuerysResult() throws {
        let slow = situation(owned: ["me-finte": 1], base: ["gs": 3])
        let offer = try XCTUnwrap(engine.offers(in: slow).first { $0.choice == "finte" })
        XCTAssertFalse(offer.legal)
        XCTAssertEqual(offer.reasons.first?.facts.first { $0.name == "hero.gs" }?.value, 3)
        XCTAssertTrue(try XCTUnwrap(engine.offers(in: situation(owned: ["me-finte": 1], base: ["gs": 8]))
            .first { $0.choice == "finte" }).legal)
    }

    // MARK: - A fact an applying rule provides, or the sheet states as a value

    func testAFactTheOwnedMountsProfileProvidesIsRead() throws {
        let b = engine.evaluate(Query("iniBase"), in: situation(owned: ["me-horse": 1], facts: ["hero.mounted": true]))
        XCTAssertEqual(b.result, 14)
        XCTAssertEqual(b.base?.origin, ref("me-rider.R1"))
        XCTAssertEqual(b.base?.via, [ref("me-horse.H2")])
    }

    /// A table the display reads (`readBy: display`) is no fact (fix round 1).
    func testAProvideForTheDisplayIsNoFact() throws {
        let b = engine.evaluate(Query("gs"), in: situation(owned: ["me-horse": 1], facts: ["hero.mounted": true], base: ["gs": 8]))
        XCTAssertEqual(lines(b, from: "me-rider.R1"), [])
        XCTAssertEqual(b.notApplied.first { $0.origin == ref("me-rider.R1") }?.reason, .unknownFact)
    }

    func testAFactTheSheetStatesAsABaseValueIsRead() throws {
        let b = engine.evaluate(Query("iniBase"), in: situation(facts: ["hero.mounted": true], base: ["mount.iniBase": 12]))
        XCTAssertEqual(b.result, 12)
        XCTAssertEqual(b.base?.facts.first { $0.name == "mount.iniBase" }?.owner, .sheet)
        let tp = engine.evaluate(Query("tp"), in: situation(facts: ["hero.mounted": true], base: ["mount.gs": 11]))
        XCTAssertEqual(lines(tp, from: "me-rider.R1").map(\.value), [6])
    }

    // MARK: - No rulesets stated: none is on

    func testAnUnstatedRulesetsReadsAsNone() throws {
        let s = situation(facts: ["hero.mounted": true, "loadout.weapon": "Rabenschnabel"], base: ["tp": 0])
        let b = engine.evaluate(Query("tp"), in: s)
        XCTAssertEqual(lines(b, from: "me-weapon.W3"), [])
        XCTAssertEqual(b.notApplied.first { $0.origin == ref("me-weapon.W3") }?.reason, .conditionFalse)
        XCTAssertFalse(b.questions.map(\.fact).contains("rulesets"))
    }

    func testTheSheetListsAnActionEffectWhoseWhenIsNo() throws {
        let s = situation(facts: ["loadout.weapon": "Rabenschnabel", "action.attack": "confirmedFumble"])
        let sheet = engine.sheet(in: s)
        XCTAssertEqual(sheet.notApplied.first { $0.origin == ref("me-weapon.W4") }?.reason, .conditionFalse)
        // With the Fokusregel on, it is the action layer's: the sheet does not list it.
        var on = s
        on.facts["rulesets"] = Fact(name: "rulesets", value: .array(["fokus.waffeneigenschaften"]), owner: .player)
        XCTAssertNil(engine.sheet(in: on).notApplied.first { $0.origin == ref("me-weapon.W4") })
    }

    // MARK: - Whether choices combine

    func testATogetherForbidRefusesItsOwnOfferWithTheNamedOne() throws {
        let s = situation(owned: ["me-finte": 1, "me-wucht": 1, "me-charge": 1])
        let refused = engine.legality(ofCombination: ["sturmangriff", "finte"], in: s)
        XCTAssertFalse(refused.allowed)
        XCTAssertEqual(refused.reasons.map(\.origin), [ref("me-charge.C4")])
        XCTAssertTrue(engine.legality(ofCombination: ["sturmangriff", "wuchtschlag"], in: s).allowed)
    }

    func testALimitRefusesMoreThanItsMax() throws {
        let s = situation(owned: ["me-finte": 1, "me-wucht": 1, "me-charge": 1])
        let two = engine.legality(ofCombination: ["finte", "wuchtschlag"], in: s)
        XCTAssertFalse(two.allowed)
        XCTAssertEqual(two.reasons.map(\.origin), [ref("me-core.K3")])
        XCTAssertEqual(two.reasons.first?.because, "nur ein Basismanöver pro Handlung")
    }

    // MARK: - Taking a choice runs what it gates

    func testTakingAChoiceRunsTheItemChangeItGates() throws {
        var s = situation(facts: ["hero.mounted": true, "loadout.mount": "Kaltblut", "loadout.mount.instance": "horse"])
        s.facts["choice.jumpOff"] = Fact(name: "choice.jumpOff", value: .bool(true), owner: .player)
        let r = ActionLayer(engine: engine).perform(.take(choice: "jumpOff"), in: s)
        let changed = try XCTUnwrap(r.events.first { $0.kind == .itemChanged })
        XCTAssertEqual(changed.origin, ref("me-rider.R6"))
        XCTAssertEqual(changed.change?["ridden"], .bool(false))
    }

    func testTakingAChoiceWithAnOptionPaysAndAsksWhatItGates() throws {
        var s = situation(facts: ["hero.mounted": true])
        s.pools[.actions] = PoolState(current: 1, max: 1)
        s.facts["choice.order"] = Fact(name: "choice.order", value: .string("flucht"), owner: .player)
        let r = ActionLayer(engine: engine).perform(.take(choice: "order"), in: s)
        XCTAssertEqual(r.events.filter { $0.kind == .paid }.map(\.origin), [ref("me-rider.R12")])
        XCTAssertEqual(r.checks.map(\.origin), [ref("me-rider.R12")])
        XCTAssertEqual(r.checks.first?.application, "Kampfmanöver")
    }

    // MARK: - R67: the rulings a line or an offer passed through

    func testALineCarriesTheRulingsOfTheOfferOfTheChoiceItRead() throws {
        let s = situation(owned: ["me-charge": 1], facts: ["choice.sturmangriff": true, "choice.zone": "kopf"], base: ["at": 14])
        let line = try XCTUnwrap(lines(engine.evaluate(Query("at"), in: s), from: "me-core.Z5").first)
        XCTAssertEqual(line.rulings, ["me-charge.aim"])
        let plain = situation(owned: ["me-charge": 1], facts: ["choice.zone": "kopf"], base: ["at": 14])
        XCTAssertEqual(lines(engine.evaluate(Query("at"), in: plain), from: "me-core.Z5").first?.rulings, [])
    }

    func testAnOfferCarriesTheRulingsOfTheManoeuvreForbidsItPassed() throws {
        let s = situation(owned: ["me-finte": 1, "me-charge": 1], facts: ["hero.mounted": true, "hero.gs": 8])
        let finte = try XCTUnwrap(engine.offers(in: s).first { $0.choice == "finte" })
        XCTAssertTrue(finte.legal)
        XCTAssertTrue(finte.rulings.contains("me-rider.mounted"), "\(finte.rulings)")
        let charge = try XCTUnwrap(engine.offers(in: s).first { $0.choice == "sturmangriff" })
        XCTAssertFalse(charge.legal)
        XCTAssertFalse(charge.rulings.contains("me-rider.mounted"))
    }

    // MARK: - R68: a suppressed entry carries the suppressor's rulings

    func testASuppressedEntryCarriesTheSuppressorsRulings() throws {
        let s = situation(facts: ["loadout.reach": "kurz", "opponent.reach": "lang", "gmFact.quiet": true], base: ["at": 14])
        let entry = try XCTUnwrap(engine.evaluate(Query("at"), in: s).notApplied.first { $0.origin == ref("me-core.R3") })
        XCTAssertEqual(entry.reason, .suppressed)
        XCTAssertTrue(entry.rulings.contains("me-core.quiet"))
    }
}
