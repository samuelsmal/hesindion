import XCTest
@testable import Hesindion

/// The reach mismatch penalty, every combination of it.
///
/// The rule is one-sided — reaching *past* a longer weapon costs AT, having the
/// longer weapon costs nothing — and the announcement screen now prints the value
/// per option, so a wrong sign or a missing pair would be visible at the table as
/// a promise the roll does not keep. There was no cover for it at all.
final class WeaponReachTests: XCTestCase {

    /// The full 3×3 matrix, written out rather than derived, so a change to the
    /// rule has to be made here as well as in the code.
    func testEveryCombination() {
        let expected: [WeaponReach: [WeaponReach: Int]] = [
            .kurz:   [.kurz: 0, .mittel: -2, .lang: -4],
            .mittel: [.kurz: 0, .mittel: 0,  .lang: -2],
            .lang:   [.kurz: 0, .mittel: 0,  .lang: 0],
        ]

        for (hero, row) in expected {
            for (opponent, penalty) in row {
                XCTAssertEqual(
                    hero.atPenaltyAgainst(opponent), penalty,
                    "\(hero.rawValue) against \(opponent.rawValue)"
                )
            }
        }
    }

    func testEqualReachIsNeverPenalised() {
        for reach in WeaponReach.allCases {
            XCTAssertEqual(reach.atPenaltyAgainst(reach), 0, "\(reach.rawValue) against itself")
        }
    }

    /// The longer weapon never gains: the rule penalises the shorter side only.
    func testTheLongerWeaponGetsNoBonus() {
        XCTAssertEqual(WeaponReach.lang.atPenaltyAgainst(.kurz), 0)
        XCTAssertEqual(WeaponReach.lang.atPenaltyAgainst(.mittel), 0)
        XCTAssertEqual(WeaponReach.mittel.atPenaltyAgainst(.kurz), 0)
    }

    /// Two steps of mismatch cost twice one step.
    func testTwoStepsCostTwiceOneStep() {
        XCTAssertEqual(
            WeaponReach.kurz.atPenaltyAgainst(.lang),
            2 * WeaponReach.kurz.atPenaltyAgainst(.mittel)
        )
    }

    func testPenaltiesAreNeverPositive() {
        for hero in WeaponReach.allCases {
            for opponent in WeaponReach.allCases {
                XCTAssertLessThanOrEqual(hero.atPenaltyAgainst(opponent), 0)
            }
        }
    }
}
