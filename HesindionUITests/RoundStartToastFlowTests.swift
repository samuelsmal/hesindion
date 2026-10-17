import XCTest

/// The round-start toast end to end (issue #35, ADR-0018): Blutend takes its
/// 1 SP when the next-round button is pressed, and the player is told so —
/// with the amount and the cause — on a toast that then closes by itself.
final class RoundStartToastFlowTests: XCTestCase {

    @MainActor
    func testBleedingIsAnnouncedAtTheNextRoundAndTheToastCloses() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", states: ["blutend:1"])

        let nextRound = app.buttons["combat.nextRound"]
        XCTAssertTrue(nextRound.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        let toast = app.descendants(matching: .any).matching(identifier: "toast").firstMatch
        XCTAssertFalse(toast.exists, "A toast before any round passed")

        nextRound.tap()

        XCTAssertTrue(toast.waitForExistence(timeout: UITest.timeout), "No toast at the start of the round")
        XCTAssertTrue(toast.label.contains("LeP −1 (Blutend)"),
                      "The toast does not name the amount and the cause: \(toast.label)")

        // Four seconds on screen, then gone without a tap.
        XCTAssertTrue(toast.waitForNonExistence(timeout: 8), "The toast did not close by itself")
    }
}
