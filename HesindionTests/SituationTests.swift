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

    func testAnOutOfRangeIndexStillNamesAnOpponent() {
        var roster = OpponentRoster([OpponentProfile(label: "Ork"), OpponentProfile(label: "Goblin")])
        roster.currentIndex = 7
        XCTAssertEqual(roster.current.label, "Goblin")
        roster.entries = [OpponentProfile(label: "Wolf")]
        XCTAssertEqual(roster.current.label, "Wolf")
    }

    func testEveryCheckDomainIsARuleDomain() {
        for check in CheckDomain.allCases {
            XCTAssertNotNil(RuleDomain(rawValue: check.rawValue), "\(check)")
        }
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

    /// The next announcement may be at somebody else, so nothing survives it —
    /// not the posture and not the shape. The reach was the fact that made this
    /// obvious: a hero who fought a spear-carrier in round one kept attacking at
    /// −2 for the rest of the fight, whoever they turned to.
    func testResetLeavesNothingOfTheLastOpponent() {
        var o = OpponentProfile()
        o.label = "der Ork links"
        o.reach = .lang
        o.bodyPlanKind = .vierbeinig
        o.size = .gross
        o.isDaemon = true
        o.isOnFoot = true
        o.facts[FactKey(id: "knownLocation", span: .opponent)] = true
        o.isOfOpposingDeity = true
        o.isProne = true
        o.advantageousPosition = true

        o.reset()

        XCTAssertEqual(o, OpponentProfile(), "a reset opponent is an unasked question")
        XCTAssertEqual(o.reach, .mittel)
        XCTAssertEqual(o.bodyPlanKind, .humanoid)
        XCTAssertEqual(o.size, .mittel)
        XCTAssertFalse(o.isDaemon)
        XCTAssertNil(o.isOnFoot)
        XCTAssertFalse(o.isOfOpposingDeity)
        XCTAssertTrue(o.facts.isEmpty, "an .opponent-span fact goes with the opponent")
        XCTAssertTrue(o.states.isEmpty)
        XCTAssertFalse(o.advantageousPosition)
        XCTAssertEqual(o.label, "")
    }

    /// The span vocabulary is the catalog's and stays, whatever the app does
    /// with it: a rule says what its fact is a fact *about*.
    func testTheFactSpansAreStillTheCatalogsVocabulary() {
        XCTAssertEqual(OpponentProfile.advantageousPositionKey.span, .attack)
        XCTAssertEqual(OpponentProfile.opposingDeityKey.span, .opponent)
        XCTAssertEqual(Set(FactSpan.allCases), [.hero, .opponent, .attack, .round])
    }

    func testTheOpponentStateIdsAreStateCatalogIds() {
        for id in [OpponentProfile.proneStateId, OpponentProfile.surprisedStateId] {
            XCTAssertTrue(StateCatalog.all.contains { $0.id == id }, id)
        }
    }

    func testAModifierLineCarriesNoRuleIdUnlessGivenOne() {
        XCTAssertNil(ModifierLine(value: 1, source: "x").ruleId)
        XCTAssertEqual(ModifierLine(value: 1, source: "x", ruleId: "SA_1").ruleId, "SA_1")
    }
}
