import XCTest

/// The TP calculation end to end (issue #19).
///
/// A Wuchtschlag's +2 used to be folded into the damage string at the
/// announcement screen, so by the time the dice were rolled there was no way to
/// tell a manoeuvre's bonus from the weapon's own — the screen printed one
/// pre-computed number. Every part is now a row of the calculation.
final class DamageBreakdownFlowTests: XCTestCase {

    /// 5 for the AT (a plain success against AT 12 − 2 for the Wuchtschlag), and
    /// 5 again for the 1W6 of damage. `ScriptedDice` repeats its queue.
    private static let plainRoll = "5"

    @MainActor
    func testEveryPartOfTheDamageIsNamed() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.plainRoll)

        // --- Announce a Wuchtschlag, which is the bonus under test.
        app.button(containing: "Angriff").tap()
        let oneHanded = app.button(containing: "Einhändig")
        if oneHanded.waitForExistence(timeout: UITest.probeTimeout) { oneHanded.tap() }

        let wuchtschlag = app.button(containing: "Wuchtschlag")
        XCTAssertTrue(wuchtschlag.waitForExistence(timeout: UITest.timeout), "Announcement screen not shown")
        wuchtschlag.tap()

        // The announcement already shows what it will do to the damage, before
        // any dice are rolled.
        XCTAssertTrue(
            app.staticTexts["1W6+4"].exists,
            "The weapon's own damage was not shown as the base of the calculation"
        )
        XCTAssertTrue(app.staticTexts["1W6+6"].exists, "The resulting formula was not shown")
        captureScreenshot(app, named: "26-damage-announced")

        app.button(containing: "Weiter").tap()

        // --- Roll the attack through to the damage.
        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")
        diceBox.tap()

        app.button(containing: "Weiter zur Verteidigung").tap()

        let hit = app.button(containing: "Treffer geht durch")
        XCTAssertTrue(hit.waitForExistence(timeout: UITest.timeout), "Opponent defence screen not shown")
        hit.tap()

        // The damage dice have to be tapped like every other roll in the app.
        app.staticTexts["Antippen zum Würfeln"].tap()

        XCTAssertTrue(
            app.staticTexts["Waffe"].waitForExistence(timeout: UITest.timeout),
            "The damage was reported without a calculation"
        )
        XCTAssertTrue(app.staticTexts["1W6"].exists, "The dice are not named in the calculation")
        XCTAssertTrue(app.staticTexts["Wuchtschlag"].exists, "The manoeuvre's bonus is not named")
        XCTAssertTrue(app.staticTexts["+2"].exists, "The manoeuvre's bonus is named but not priced")
        // 5 rolled + 4 weapon + 2 Wuchtschlag.
        XCTAssertTrue(app.staticTexts["11 TP"].exists, "The parts do not add up to the reported total")

        captureScreenshot(app, named: "27-damage-breakdown")
    }
}
