import XCTest
import SwiftData
@testable import Hesindion

/// What the next-round button changes on the hero by itself, and what the
/// toast says about it (issue #35, ADR-0018): every change with its amount
/// and its cause, and nothing when nothing changed.
@MainActor
final class RoundStartChangesTests: XCTestCase {
    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
        hero.derivedValues = TestData.derivedValues(lp: 30)
        hero.activeCombatId = UUID()
        hero.activeCombatRound = 2
    }

    /// The step `CombatView.onChange(of: roundNumber)` takes, from round 2 to 3.
    private func nextRound() -> [RoundStartChange] {
        let before = RoundStartSnapshot(hero: hero, round: 2)
        hero.endOfRoundBleeding()
        hero.beginCombatRound()
        return RoundStartChange.between(before, RoundStartSnapshot(hero: hero, round: 3))
    }

    func testNothingChangedGivesNoLines() {
        XCTAssertEqual(nextRound(), [])
    }

    func testBleedingReportsTheLePLost() {
        hero.startBleeding(rounds: 3)
        XCTAssertEqual(nextRound(), [.bleedingLoss(lep: 1)])
    }

    func testAtZeroLePBleedingTakesNothingAndSaysNothingAboutLeP() {
        hero.startBleeding(rounds: 3)
        hero.derivedValues?.lebensenergie.current = 0
        XCTAssertEqual(nextRound(), [])
    }

    func testTheLastBleedingRoundReportsTheLossAndTheEnd() {
        hero.startBleeding(rounds: 1)
        XCTAssertEqual(nextRound(), [.bleedingLoss(lep: 1), .bleedingEnded])
    }

    /// 23 → 22 of 30 crosses the ¾ threshold: the LeP loss is the cause.
    func testBleedingOverAThresholdReportsTheSchmerzItCauses() {
        hero.derivedValues?.lebensenergie.current = 23
        hero.startBleeding(rounds: 3)
        XCTAssertEqual(nextRound(), [.bleedingLoss(lep: 1), .lebenspunkteSchmerz(levels: 1)])
    }

    func testZuKonzentriertEnds() {
        hero.activeCombatNoDefense = true
        XCTAssertEqual(nextRound(), [.noDefenseEnded])
    }

    /// A Zerrung rolled in round 0 runs to the end of round 2.
    func testThePatzerSchmerzEndsAfterItsLastRound() {
        hero.temporarySchmerzLevels = 2
        hero.temporarySchmerzLastRound = 2
        XCTAssertEqual(nextRound(), [.temporarySchmerzEnded(levels: 2)])
    }

    func testThePatzerSchmerzStillRunningSaysNothing() {
        hero.temporarySchmerzLevels = 1
        hero.temporarySchmerzLastRound = 3
        XCTAssertEqual(nextRound(), [])
    }

    func testTheJamEndsAfterItsLastRound() {
        hero.activeCombatJamUntilRound = 2
        XCTAssertEqual(nextRound(), [.jamEnded])
    }

    func testEveryLineNamesItsAmountAndCause() {
        XCTAssertEqual(RoundStartChange.bleedingLoss(lep: 1).text, "LeP −1 (Blutend)")
        XCTAssertEqual(RoundStartChange.lebenspunkteSchmerz(levels: 1).text, "Schmerz +1 (Lebenspunkte)")
        XCTAssertEqual(RoundStartChange.bleedingEnded.text, "Blutend endet")
        XCTAssertEqual(RoundStartChange.temporarySchmerzEnded(levels: 2).text, "Schmerz −2 (Patzer vorbei)")
        XCTAssertEqual(RoundStartChange.jamEnded.text, "Ladehemmung vorbei")
        XCTAssertEqual(RoundStartChange.noDefenseEnded.text, "Zu konzentriert vorbei — Verteidigung wieder möglich")
    }

    func testTheToastKeysAreLocalized() {
        for key in ["roundStart.title", "roundStart.bleedingLoss", "roundStart.lebenspunkteSchmerz",
                    "roundStart.bleedingEnded", "roundStart.temporarySchmerzEnded",
                    "roundStart.jamEnded", "roundStart.noDefenseEnded"] {
            XCTAssertTrue(DSAStrings.isInBothTables(key), "missing translation for \(key)")
        }
    }
}
