import XCTest
import SwiftData
@testable import Hesindion

/// The value a roll is evaluated against, and the two parts it is made of.
@MainActor
final class SituationTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
    }

    override func tearDown() { context = nil; hero = nil }

    func testTheDefaultSituationHasOneOpponentWhoIsTheTarget() {
        let s = Situation(hero: hero, domain: .meleeAttack)
        XCTAssertEqual(s.opponents.entries.count, 1)
        XCTAssertEqual(s.opponent, OpponentProfile())
        XCTAssertEqual(s.checkDomain, .meleeAttack)
        XCTAssertNil(Situation(hero: hero, domain: .damage).checkDomain, "damage has no Swift definitions")
    }

    func testTheCurrentOpponentIsWrittenInPlace() {
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.opponents.entries = [OpponentProfile(label: "Ork"), OpponentProfile(label: "Goblin")]
        s.opponents.currentIndex = 1
        s.opponents.current.isProne = true
        XCTAssertEqual(s.opponents.entries[1].label, "Goblin")
        XCTAssertTrue(s.opponents.entries[1].isProne)
        XCTAssertFalse(s.opponents.entries[0].isProne)
    }

    func testDefencesThisRoundFollowTheDomain() {
        var s = Situation(hero: hero, domain: .meleeParry)
        s.round.parriesThisRound = 2
        s.round.dodgesThisRound = 1
        XCTAssertEqual(s.defencesThisRound, 2)
        var dodge = Situation(hero: hero, domain: .meleeDodge)
        dodge.round = s.round
        XCTAssertEqual(dodge.defencesThisRound, 1)
    }

    // MARK: - OpponentProfile: the old flags are the new facts

    func testProneAndSurprisedAreStates() {
        var o = OpponentProfile()
        o.isProne = true
        o.isSurprised = true
        XCTAssertEqual(o.states, ["liegend", "ueberrascht"])
        o.isProne = false
        XCTAssertEqual(o.states, ["ueberrascht"])
    }

    func testAdvantageousPositionIsAnAttackFactAndOpposingDeityAFightFact() {
        var o = OpponentProfile()
        o.advantageousPosition = true
        o.isOfOpposingDeity = true
        XCTAssertEqual(o.facts[FactKey(id: "advantageousPosition", span: .attack)], true)
        XCTAssertEqual(o.facts[FactKey(id: "opposingDeity", span: .opponent)], true, "the same demon stays the same demon")
        o.advantageousPosition = false
        XCTAssertNil(o.facts[FactKey(id: "advantageousPosition", span: .attack)], "false is not stated, it is withdrawn")
    }

    func testResetPerAttackKeepsWhatLastsTheFight() {
        var o = OpponentProfile()
        o.reach = .lang
        o.isDaemon = true
        o.isOnFoot = true
        o.facts[FactKey(id: "knownLocation", span: .opponent)] = true
        o.isOfOpposingDeity = true
        o.isProne = true
        o.advantageousPosition = true
        o.resetPerAttack()
        XCTAssertEqual(o.reach, .lang)
        XCTAssertTrue(o.isDaemon)
        XCTAssertEqual(o.isOnFoot, true)
        XCTAssertTrue(o.isOfOpposingDeity)
        XCTAssertEqual(o.facts, [FactKey(id: "knownLocation", span: .opponent): true,
                                 OpponentProfile.opposingDeityKey: true])
        XCTAssertTrue(o.states.isEmpty)
        XCTAssertFalse(o.advantageousPosition)
    }

    func testAModifierLineCarriesNoRuleIdUnlessGivenOne() {
        XCTAssertNil(ModifierLine(value: 1, source: "x").ruleId)
        XCTAssertEqual(ModifierLine(value: 1, source: "x", ruleId: "SA_1").ruleId, "SA_1")
    }
}
