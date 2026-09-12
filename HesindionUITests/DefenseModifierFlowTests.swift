import XCTest

/// Mehrfache Verteidigung end to end (issue #20).
///
/// The hero is seeded **with a shield**, which is the part that mattered: a
/// loadout with a shield sends Parieren through the weapon list, and that screen
/// rolled a bare PA — no Mehrfache Verteidigung, no Schicksalspunkt boost, no
/// Belastung. The root's own shortcut applied the penalty, but to the wrong
/// defence: the count was incremented as the button was tapped and then read
/// back for the very defence that incremented it, so the *first* parry of a round
/// came out at -3.
final class DefenseModifierFlowTests: XCTestCase {

    /// A plain roll: never 1 or 20, so no confirmation, no Patzer, no critical
    /// branch to navigate. `ScriptedDice` repeats its queue.
    private static let plainRoll = "10"

    @MainActor
    func testFirstParryIsUnpenalisedAndTheSecondIsAtMinusThree() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.plainRoll, shield: true)

        // --- First parry of the round.
        parry(app, expectingWeaponList: true)

        let penalty = app.staticTexts["Mehrfache Verteidigung"]
        XCTAssertFalse(
            penalty.exists,
            "The first defence of a round is unmodified — nothing has been defended yet"
        )
        captureScreenshot(app, named: "23-defense-first-parry")

        rollAndReturnToRoot(app)

        // --- The root now says what defending again will cost, before it is paid.
        let parryButton = app.buttons["combat.parry"]
        XCTAssertTrue(parryButton.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        XCTAssertTrue(
            parryButton.label.contains("2. Verteidigung"),
            "The Parieren button did not announce the second defence: \(parryButton.label)"
        )
        captureScreenshot(app, named: "24-defense-second-costs")

        // --- Second parry: -3, and it reaches the roll through the weapon list.
        parry(app, expectingWeaponList: true)

        XCTAssertTrue(
            penalty.waitForExistence(timeout: UITest.timeout),
            "The second defence of the round was not penalised"
        )
        XCTAssertTrue(
            app.staticTexts["-3"].exists,
            "Mehrfache Verteidigung was named but not priced"
        )
        captureScreenshot(app, named: "25-defense-multiple-penalty")
    }

    /// The penalty is per round, so the next round starts clean.
    @MainActor
    func testANewRoundClearsThePenalty() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.plainRoll, shield: true)

        parry(app, expectingWeaponList: true)
        rollAndReturnToRoot(app)

        let parryButton = app.buttons["combat.parry"]
        XCTAssertTrue(parryButton.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        XCTAssertTrue(parryButton.label.contains("2. Verteidigung"), "Penalty not pending")

        let nextRound = app.buttons["combat.nextRound"]
        XCTAssertTrue(nextRound.exists, "No next-round control on the combat root")
        nextRound.tap()

        XCTAssertFalse(
            app.buttons["combat.parry"].label.contains("Verteidigung"),
            "The new round still carries the last round's defences"
        )

        parry(app, expectingWeaponList: true)
        XCTAssertFalse(
            app.staticTexts["Mehrfache Verteidigung"].exists,
            "The first parry of the new round was penalised"
        )
    }

    // MARK: - Navigation

    @MainActor
    private func parry(_ app: XCUIApplication, expectingWeaponList: Bool) {
        let parryButton = app.buttons["combat.parry"]
        XCTAssertTrue(parryButton.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        parryButton.tap()

        let weaponRow = app.buttons["combat.weaponRow.Langschwert"]
        if expectingWeaponList {
            XCTAssertTrue(
                weaponRow.waitForExistence(timeout: UITest.timeout),
                "A shield in the loadout should offer a choice of parrying weapon"
            )
            weaponRow.tap()
        }
    }

    @MainActor
    private func rollAndReturnToRoot(_ app: XCUIApplication) {
        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Defence roll screen not shown")
        diceBox.tap()

        let newAction = app.button(containing: "Neue Aktion")
        XCTAssertTrue(newAction.waitForExistence(timeout: UITest.timeout), "No way back to the combat root")
        newAction.tap()
    }
}
