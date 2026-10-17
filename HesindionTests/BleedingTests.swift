import XCTest
import SwiftData
@testable import Hesindion

@MainActor
final class BleedingTests: XCTestCase {
    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
        hero.derivedValues = TestData.derivedValues(lp: 30)   // use the existing TestData helper for a hero with LP; add one if missing
    }

    func testDuration() {
        XCTAssertEqual(BleedingRules.duration(qualityLevel: 0, succeeded: false, critical: false, fumble: false), 7)
        XCTAssertEqual(BleedingRules.duration(qualityLevel: 3, succeeded: true, critical: false, fumble: false), 4)
        XCTAssertEqual(BleedingRules.duration(qualityLevel: 0, succeeded: false, critical: false, fumble: true), 14)
        XCTAssertEqual(BleedingRules.duration(qualityLevel: 6, succeeded: true, critical: true, fumble: false), 0)
    }

    func testTreatmentRoundsUp() {
        XCTAssertEqual(BleedingRules.treatmentReduction(qs: 1), 1)
        XCTAssertEqual(BleedingRules.treatmentReduction(qs: 2), 1)
        XCTAssertEqual(BleedingRules.treatmentReduction(qs: 3), 2)
    }

    func testEachRoundCostsOneSPAndTheClockEndsIt() {
        hero.startBleeding(rounds: 2)
        XCTAssertEqual(hero.endOfRoundBleeding(), 1)
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 29)
        XCTAssertTrue(hero.hasState("blutend"))
        XCTAssertEqual(hero.endOfRoundBleeding(), 1)
        XCTAssertFalse(hero.hasState("blutend"))
        XCTAssertEqual(hero.endOfRoundBleeding(), 0)
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 28)
    }

    func testTheLongerBleedingWins() {
        hero.startBleeding(rounds: 5)
        hero.startBleeding(rounds: 3)
        XCTAssertEqual(hero.bleedingRoundsLeft, 5)
    }

    func testACriticalSelbstbeherrschungStopsIt() {
        hero.setStateLevel("blutend", level: 1)
        hero.startBleeding(rounds: 0)
        XCTAssertFalse(hero.hasState("blutend"))
    }

    func testUnrolledBleedingStillCosts() {
        hero.setStateLevel("blutend", level: 1)
        XCTAssertEqual(hero.endOfRoundBleeding(), 1)
        XCTAssertNil(hero.bleedingRoundsLeft)
    }

    func testTreatment() {
        hero.startBleeding(rounds: 3)
        hero.treatBleeding(qs: 3)
        XCTAssertEqual(hero.bleedingRoundsLeft, 1)
        hero.treatBleeding(qs: 1)
        XCTAssertFalse(hero.hasState("blutend"))
    }

    func testRemovingTheStatusDropsTheClock() {
        hero.startBleeding(rounds: 4)
        hero.setStateLevel("blutend", level: 0)
        XCTAssertNil(hero.bleedingRoundsLeft)
    }
}
