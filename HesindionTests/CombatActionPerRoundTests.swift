import XCTest
import SwiftData
@testable import Hesindion

/// One Aktion per Kampfrunde (issue #47): "Innerhalb einer Kampfrunde darf jeder
/// Beteiligte eine Aktion, Verteidigungen (eine oder mehrere) und eine freie
/// Aktion ausführen." An attack, a shot, a spell and a Flucht each spend it; a
/// defence does not. The hero records the round the Aktion went to, so the
/// root can shut the other actions until the next round.
@MainActor
final class CombatActionPerRoundTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Aktion")
        context.insert(hero)
        hero.activeCombatId = UUID()
        hero.activeCombatRound = 1
    }

    override func tearDown() { context = nil; hero = nil }

    func testAFreshFightHasItsActionLeft() {
        XCTAssertFalse(hero.hasSpentAction(inRound: 1))
    }

    func testTheOwnActionSpendsTheRoundsAktion() {
        hero.beginOwnAction(inRound: 1)
        XCTAssertTrue(hero.hasSpentAction(inRound: 1))
    }

    func testTheNextRoundHasANewAktion() {
        hero.beginOwnAction(inRound: 1)
        XCTAssertFalse(hero.hasSpentAction(inRound: 2))
    }

    /// "Neu" rolls initiative again and counts from 1: a new order of the
    /// fight, so an Aktion spent in round 1 of the old count is not spent in
    /// round 1 of the new one.
    func testNewInitiativeGivesTheActionBack() {
        hero.beginOwnAction(inRound: 1)
        hero.rebaseCombatClocks(fromRound: 1, toRound: 1)
        XCTAssertFalse(hero.hasSpentAction(inRound: 1))
    }

    func testTheEndOfTheFightClearsIt() {
        hero.beginOwnAction(inRound: 3)
        hero.clearCombatSession()
        XCTAssertEqual(hero.activeCombatActionRound, 0)
        XCTAssertFalse(hero.hasSpentAction(inRound: 3))
    }

    /// The Schip reroll calls the hook a second time for the same roll; that
    /// is still the one Aktion and must not write the model again.
    func testASecondCallInTheSameRoundChangesNothing() {
        hero.beginOwnAction(inRound: 2)
        hero.beginOwnAction(inRound: 2)
        XCTAssertEqual(hero.activeCombatActionRound, 2)
    }
}
