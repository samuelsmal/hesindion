import XCTest
@testable import Hesindion

/// Issue #41: after the mount's attack, the app states the Mächtiger Schlag
/// follow-up for the defence the opponent made.
final class AttackFollowUpTests: XCTestCase {

    /// MS2: half the KK above 20, rounded up — the page's own examples are
    /// KK 23 → −2 and KK 26 → −3.
    func testTheKraftaktPenaltyIsHalfTheKKAbove20RoundedUp() {
        XCTAssertEqual(AttackFollowUp.mightyBlowPenalty(kk: 18), 0)
        XCTAssertEqual(AttackFollowUp.mightyBlowPenalty(kk: 20), 0)
        XCTAssertEqual(AttackFollowUp.mightyBlowPenalty(kk: 21), -1)
        XCTAssertEqual(AttackFollowUp.mightyBlowPenalty(kk: 23), -2)
        XCTAssertEqual(AttackFollowUp.mightyBlowPenalty(kk: 25), -3)
        XCTAssertEqual(AttackFollowUp.mightyBlowPenalty(kk: 26), -3)
    }

    /// MS3: a parry does not help, only a dodge avoids the check.
    func testOnlyADodgeAvoidsTheCheck() {
        let followUp = AttackFollowUp.mightyBlow(creature: "Kupperus", kk: 25)

        XCTAssertEqual(followUp.resolution(after: .hit), .due)
        XCTAssertEqual(followUp.resolution(after: .parried), .due)
        XCTAssertEqual(followUp.resolution(after: .dodged), .notApplied(reason: L("followUp.dodged")))
    }

    /// The check line carries the penalty, and a second line says where it
    /// comes from: the KK of the creature that has the SF (MS2, ADR-0018).
    func testTheLinesNameThePenaltyAndTheCreatureItComesFrom() {
        let followUp = AttackFollowUp.mightyBlow(creature: "Kupperus", kk: 25)

        XCTAssertEqual(followUp.name, L("mightyBlow.name"))
        XCTAssertEqual(followUp.lines.first, String(format: L("mightyBlow.check"), "−3"))
        XCTAssertTrue(followUp.lines.contains(String(format: L("mightyBlow.penalty"), "Kupperus", 25, 5)))
    }

    func testWithoutPenaltyTheCheckHasNoModifier() {
        let followUp = AttackFollowUp.mightyBlow(creature: "Kupperus", kk: 20)

        XCTAssertEqual(followUp.lines.first, L("mightyBlow.checkNoPenalty"))
        XCTAssertFalse(followUp.lines.contains { $0.contains("KK") })
    }

    /// The toast after a parry states the check; after a dodge, that the rule
    /// did not apply and why.
    func testTheToastFollowsTheResolution() {
        let followUp = AttackFollowUp.mightyBlow(creature: "Kupperus", kk: 25)

        let parried = followUp.toast(after: .parried)
        XCTAssertEqual(parried.title, followUp.name)
        XCTAssertEqual(parried.lines, followUp.lines)

        let dodged = followUp.toast(after: .dodged)
        XCTAssertEqual(dodged.title, String(format: L("followUp.notApplied"), followUp.name))
        XCTAssertEqual(dodged.lines, [L("followUp.dodged")])
    }
}
