import XCTest

/// One Aktion per Kampfrunde (issue #47).
///
/// > "Innerhalb einer Kampfrunde darf jeder Beteiligte eine Aktion,
/// > Verteidigungen (eine oder mehrere) und eine freie Aktion ausführen."
///
/// The attack's roll spends the Aktion. Back at the root the actions read as
/// shut, say why, and ask the GM before they act; the defences stay open; the
/// next round gives the Aktion back.
final class ActionPerRoundFlowTests: XCTestCase {

    @MainActor
    func testASecondAttackInTheSameRoundAsksTheGM() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: "19")

        // --- The round's Aktion: one attack, rolled and missed.
        let attack = app.buttons["combat.attack"]
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        let reason = app.descendants(matching: .any)["combat.action.spentReason"]
        XCTAssertFalse(reason.exists, "A fresh round already reads as spent")
        attack.tap()

        let oneHanded = app.button(containing: "Einhändig")
        if oneHanded.waitForExistence(timeout: UITest.probeTimeout) { oneHanded.tap() }
        let weiter = app.buttons["combat.announcement.continue"]
        XCTAssertTrue(app.scrollUntilHittable(weiter), "Could not reach Weiter")
        weiter.tap()

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "No dice on the attack screen")
        diceBox.tap()
        let newAction = app.buttons["combat.execution.newAction.miss"]
        XCTAssertTrue(newAction.waitForExistence(timeout: UITest.timeout), "The scripted 19 did not settle")
        XCTAssertTrue(app.scrollUntilHittable(newAction), "No way back to the combat root")
        newAction.tap()

        // --- Back at the root the actions say the Aktion is spent.
        XCTAssertTrue(reason.waitForExistence(timeout: UITest.timeout),
                      "Nothing says the round's Aktion is spent")
        captureScreenshot(app, named: "66-combat-action-spent")

        // A second attack asks instead of acting, and "Abbrechen" costs nothing.
        attack.tap()
        let allow = app.buttons["combat.action.spent.allow"]
        XCTAssertTrue(allow.waitForExistence(timeout: UITest.timeout),
                      "A second attack went ahead without asking the GM")
        app.buttons["combat.action.spent.cancel"].tap()
        XCTAssertFalse(allow.exists, "The question is still up after Abbrechen")

        // A defence is not an Aktion: Parieren opens its screen at once.
        app.buttons["combat.parry"].tap()
        XCTAssertTrue(app.buttons["combat.defense.continue"].waitForExistence(timeout: UITest.timeout),
                      "Parieren did not open its screen")
        XCTAssertFalse(allow.exists, "Parieren asked for an Aktion")
        app.buttons["combat.back"].tap()

        // --- The next round has its Aktion again.
        let nextRound = app.buttons["combat.nextRound"]
        XCTAssertTrue(nextRound.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        nextRound.tap()
        XCTAssertTrue(reason.waitForNonExistence(timeout: UITest.timeout),
                      "The next round still reads as spent")
        attack.tap()
        XCTAssertFalse(allow.waitForExistence(timeout: UITest.probeTimeout),
                       "The next round's attack asked the GM")
    }

    /// Issue #48: Kupperus at 5 LeP is handlungsunfähig; the mount's actions say why they are shut.
    @MainActor
    func testAMountAtSchmerzIVShutsItsActions() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", mounted: true, mountLE: 5)

        let attack = app.button(containing: "Angriff")
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        attack.tap()

        let reason = app.descendants(matching: .any)["combat.mount.blockedReason"]
        XCTAssertTrue(reason.waitForExistence(timeout: UITest.timeout),
                      "Nothing says why the mount's actions are shut")
        let tritt = app.button(containing: "Kupperus: Tritt")
        XCTAssertTrue(tritt.exists, "No Tritt offered")
        XCTAssertFalse(tritt.isEnabled, "The mount's Tritt is open at Schmerz IV")
        captureScreenshot(app, named: "67-mount-schmerz-iv")
    }
}
