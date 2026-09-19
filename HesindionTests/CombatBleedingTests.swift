import XCTest
import SwiftData
@testable import Hesindion

/// Blutend in the fight (Task 10): the two probes the panel opens, applied once
/// with the final result, and the SP the next-round button takes.
@MainActor
final class CombatBleedingTests: XCTestCase {
    private var context: ModelContext!
    private var hero: Hero!
    private let combat = UUID()

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
        hero.derivedValues = TestData.derivedValues(lp: 30)
    }

    private func result(qs: Int, succeeded: Bool, critical: Bool = false, fumble: Bool = false) -> SkillCheckResult {
        SkillCheckResult(rolls: [10, 10, 10], qualityLevel: qs, succeeded: succeeded,
                         isCriticalSuccess: critical, isCriticalFailure: fumble,
                         remainingSkillPoints: 0)
    }

    // MARK: - Selbstbeherrschung

    func testSelbstbeherrschungStartsTheClockAtSevenMinusQS() {
        hero.setStateLevel(BleedingRules.stateId, level: 1)
        var session = BleedingProbeSession(probe: .selbstbeherrschung)
        session.record(result(qs: 3, succeeded: true))
        session.finish(on: hero)
        XCTAssertEqual(hero.bleedingRoundsLeft, 4)
        XCTAssertTrue(hero.hasState(BleedingRules.stateId))
    }

    func testSelbstbeherrschungCriticalEndsTheStatus() {
        hero.setStateLevel(BleedingRules.stateId, level: 1)
        var session = BleedingProbeSession(probe: .selbstbeherrschung)
        session.record(result(qs: 6, succeeded: true, critical: true))
        session.finish(on: hero)
        XCTAssertFalse(hero.hasState(BleedingRules.stateId))
        XCTAssertNil(hero.bleedingRoundsLeft)
    }

    /// A Schip reroll fires `onResult` a second time: only the final result
    /// counts, and closing applies it once.
    func testOnlyTheFinalResultIsAppliedAndOnlyOnce() {
        hero.setStateLevel(BleedingRules.stateId, level: 1)
        var session = BleedingProbeSession(probe: .selbstbeherrschung)
        session.record(result(qs: 0, succeeded: false))
        session.record(result(qs: 2, succeeded: true))
        session.finish(on: hero)
        XCTAssertEqual(hero.bleedingRoundsLeft, 5)
        hero.bleedingRoundsLeft = 5
        session.finish(on: hero)
        XCTAssertEqual(hero.bleedingRoundsLeft, 5, "a second close must not apply again")
    }

    func testClosingWithoutRollingChangesNothing() {
        hero.setStateLevel(BleedingRules.stateId, level: 1)
        var session = BleedingProbeSession(probe: .selbstbeherrschung)
        session.finish(on: hero)
        XCTAssertNil(hero.bleedingRoundsLeft)
        XCTAssertTrue(hero.hasState(BleedingRules.stateId))
    }

    // MARK: - Heilkunde Wunden

    func testHeilkundeSuccessShortensByHalfQSRoundedUp() {
        hero.startBleeding(rounds: 5)
        var session = BleedingProbeSession(probe: .heilkunde)
        session.record(result(qs: 3, succeeded: true))
        session.finish(on: hero)
        XCTAssertEqual(hero.bleedingRoundsLeft, 3)
    }

    func testHeilkundeFailureLeavesTheClock() {
        hero.startBleeding(rounds: 5)
        var session = BleedingProbeSession(probe: .heilkunde)
        session.record(result(qs: 0, succeeded: false))
        session.finish(on: hero)
        XCTAssertEqual(hero.bleedingRoundsLeft, 5)
    }

    // MARK: - Next round

    func testNextRoundBleedsAndLogsAReversibleEntry() throws {
        hero.startBleeding(rounds: 3)
        let entry = try XCTUnwrap(CombatView.roundBleedingEntry(hero: hero, from: 2, to: 3, combatId: combat))
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 29)
        XCTAssertEqual(hero.bleedingRoundsLeft, 2)
        XCTAssertEqual(entry.kind, "combatAction")
        let payload = try XCTUnwrap(entry.decodePayload(CombatActionPayload.self))
        XCTAssertEqual(payload.action, .bleeding)
        XCTAssertEqual(payload.lpChange, -1)
        XCTAssertEqual(payload.round, 2)
        XCTAssertEqual(payload.combatId, combat)

        try XCTUnwrap(entry.reversible()).reverse(on: hero)
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 30)
    }

    func testNewInitiativeDoesNotBleed() {
        hero.startBleeding(rounds: 3)
        XCTAssertNil(CombatView.roundBleedingEntry(hero: hero, from: 5, to: 1, combatId: combat))
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 30)
        XCTAssertEqual(hero.bleedingRoundsLeft, 3)
    }

    /// Reopening a saved fight sets the count from 1 to the persisted round —
    /// not the end of a round.
    func testRestoringASavedSessionDoesNotBleed() {
        hero.startBleeding(rounds: 3)
        hero.activeCombatRound = 4
        XCTAssertNil(CombatView.roundBleedingEntry(hero: hero, from: 1, to: 4, combatId: combat))
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 30)
    }

    func testAtZeroLPTheEntryGivesNothingBack() throws {
        hero.startBleeding(rounds: 3)
        hero.derivedValues?.lebensenergie.current = 0
        let entry = try XCTUnwrap(CombatView.roundBleedingEntry(hero: hero, from: 1, to: 2, combatId: combat))
        XCTAssertEqual(entry.decodePayload(CombatActionPayload.self)?.lpChange, 0)
    }

    func testNotBleedingWritesNothing() {
        XCTAssertNil(CombatView.roundBleedingEntry(hero: hero, from: 1, to: 2, combatId: combat))
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 30)
    }

    func testPanelKeysAreLocalized() {
        for key in ["bleeding.rollDuration", "bleeding.roundsLeft", "bleeding.unknownDuration",
                    "bleeding.heilkunde", "bleeding.heilkunde.effect", "bleeding.log",
                    "state.blutend.removal"] {
            XCTAssertNotEqual(L(key), key, "missing translation for \(key)")
        }
    }
}
