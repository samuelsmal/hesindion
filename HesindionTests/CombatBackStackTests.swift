import XCTest
@testable import Hesindion

/// Issue #40: the attack flow's back button returns to the screen the player
/// came from, not to a fixed screen that may be one the player never saw.
final class CombatBackStackTests: XCTestCase {

    private let announcement = CombatStep.announcement(
        .angriff, name: "Langschwert", baseAT: 14, damageFormula: "1W6+4",
        isOffHand: false, secondAttack: nil, isMountCharge: false
    )
    private let execution = CombatStep.execution(
        .angriff, name: "Langschwert", attributeValue: 12, damageFormula: "1W6+4", note: nil
    )

    func testBackReturnsTheStepsInReverseOrder() {
        var stack = CombatBackStack()
        stack.advance(from: .root, vorstossActiveThisRound: false)
        stack.advance(from: .attackChoice, vorstossActiveThisRound: false)
        stack.advance(from: announcement, vorstossActiveThisRound: false)

        XCTAssertEqual(stack.back()?.step.persistenceKey, "announcement")
        XCTAssertEqual(stack.back()?.step.persistenceKey, "attackChoice")
        XCTAssertEqual(stack.back()?.step.persistenceKey, "root")
        XCTAssertNil(stack.back())
    }

    /// A step reached straight from the root goes back to the root: there is no
    /// weapon list in between that the player never saw.
    func testTheAnnouncementReachedFromTheRootGoesBackToTheRoot() {
        var stack = CombatBackStack()
        stack.advance(from: .root, vorstossActiveThisRound: false)
        stack.advance(from: announcement, vorstossActiveThisRound: false)

        XCTAssertEqual(stack.back()?.step.persistenceKey, "announcement")
        XCTAssertEqual(stack.back()?.step.persistenceKey, "root")
    }

    /// The Reiten check before a charge is rolled once. Back from the charge's
    /// announcement goes to the attack choice, not to a second roll of the check.
    func testTheMountCheckIsNotReturnedTo() {
        var stack = CombatBackStack()
        stack.advance(from: .root, vorstossActiveThisRound: false)
        stack.advance(from: .attackChoice, vorstossActiveThisRound: false)
        stack.advance(from: .mountPreCheck(onSuccess: announcement), vorstossActiveThisRound: false)

        XCTAssertEqual(stack.back()?.step.persistenceKey, "attackChoice")
    }

    /// The announcement sets Vorstoß before it moves on. Back from the AT roll
    /// restores the flag as it was when the announcement opened, so a Vorstoß
    /// the player takes back does not keep the round's defences blocked.
    func testBackRestoresVorstossAsItWasWhenTheStepOpened() {
        var stack = CombatBackStack()
        stack.advance(from: .root, vorstossActiveThisRound: false)
        // The announcement sets Vorstoß, then moves on to the roll.
        stack.advance(from: announcement, vorstossActiveThisRound: true)

        let entry = stack.back()
        XCTAssertEqual(entry?.step.persistenceKey, "announcement")
        XCTAssertEqual(entry?.vorstossActiveThisRound, false)
    }

    /// A Vorstoß from an earlier attack in the same round stays.
    func testBackKeepsAVorstossSetBeforeTheStepOpened() {
        var stack = CombatBackStack()
        stack.advance(from: .root, vorstossActiveThisRound: true)
        stack.advance(from: announcement, vorstossActiveThisRound: true)

        XCTAssertEqual(stack.back()?.vorstossActiveThisRound, true)
    }

    /// After a back, the flag of the step returned to is the entry flag again.
    func testAdvanceAfterBackRecordsTheRestoredFlag() {
        var stack = CombatBackStack()
        stack.advance(from: .root, vorstossActiveThisRound: false)
        stack.advance(from: announcement, vorstossActiveThisRound: true)
        _ = stack.back()
        // The player picks Normal this time and moves on to the roll again.
        stack.advance(from: announcement, vorstossActiveThisRound: false)
        stack.advance(from: execution, vorstossActiveThisRound: false)

        XCTAssertEqual(stack.back()?.step.persistenceKey, "execution")
        XCTAssertEqual(stack.back()?.vorstossActiveThisRound, false)
    }

    func testClearForgetsEverything() {
        var stack = CombatBackStack()
        stack.advance(from: .root, vorstossActiveThisRound: true)
        stack.advance(from: announcement, vorstossActiveThisRound: true)
        stack.clear(vorstossActiveThisRound: false)

        XCTAssertNil(stack.back())
        stack.advance(from: .root, vorstossActiveThisRound: false)
        XCTAssertEqual(stack.back()?.vorstossActiveThisRound, false)
    }
}
