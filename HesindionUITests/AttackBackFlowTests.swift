import XCTest

/// Issue #40: the back button in the attack flow goes back one step.
///
/// It used to name one fixed screen per step: back from the AT roll skipped the
/// announcement, so a wrong manoeuvre or a wrong opponent fact meant starting
/// the attack again from the root.
final class AttackBackFlowTests: XCTestCase {

    /// The seeded Langschwert takes a two-handed grip, so the attack opens the
    /// grip choice first: root → Griff → Ansage → AT-Wurf, and back the same way.
    @MainActor
    func testBackFromTheRollReturnsToTheAnnouncementAndThenToTheGripChoice() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat")

        let angriff = app.button(containing: "Angriff")
        XCTAssertTrue(angriff.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        angriff.tap()

        let oneHanded = app.button(containing: "Einhändig")
        XCTAssertTrue(oneHanded.waitForExistence(timeout: UITest.timeout), "No grip choice offered")
        oneHanded.tap()

        let announcement = app.descendants(matching: .any)["combat.announcement.atBreakdown"]
        XCTAssertTrue(announcement.waitForExistence(timeout: UITest.timeout), "Announcement screen not shown")
        let weiter = app.button(containing: "Weiter")
        XCTAssertTrue(app.scrollUntilHittable(weiter), "Could not reach Weiter")
        weiter.tap()

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")

        // Back from the roll: the announcement, not the start of the attack.
        app.buttons["combat.back"].tap()
        XCTAssertTrue(
            announcement.waitForExistence(timeout: UITest.timeout),
            "Back from the AT roll should land on the announcement"
        )

        // Back from the announcement: the grip choice the player came from.
        app.buttons["combat.back"].tap()
        XCTAssertTrue(
            oneHanded.waitForExistence(timeout: UITest.timeout),
            "Back from the announcement should land on the grip choice"
        )

        app.buttons["combat.back"].tap()
        XCTAssertTrue(
            app.buttons["combat.parry"].waitForExistence(timeout: UITest.timeout),
            "Back from the grip choice should land on the combat root"
        )
    }
}
