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
            parryButton.label.contains("2. Parade"),
            "The Parieren button did not announce the second parry: \(parryButton.label)"
        )
        // Parries and dodges are counted apart, so the dodge is still on its
        // first and says nothing.
        XCTAssertFalse(
            app.buttons["combat.dodge"].label.contains("Ausweichen \u{00B7}"),
            "A parry made the first dodge of the round more difficult"
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
        XCTAssertTrue(parryButton.label.contains("2. Parade"), "Penalty not pending")

        let nextRound = app.buttons["combat.nextRound"]
        XCTAssertTrue(nextRound.exists, "No next-round control on the combat root")
        nextRound.tap()

        XCTAssertFalse(
            app.buttons["combat.parry"].label.contains("Parade \u{00B7}"),
            "The new round still carries the last round's defences"
        )

        parry(app, expectingWeaponList: true)
        XCTAssertFalse(
            app.staticTexts["Mehrfache Verteidigung"].exists,
            "The first parry of the new round was penalised"
        )
    }

    /// A roll far beyond any plausible PA, so the parry fails outright without
    /// landing on the confirm branch (1 or 20). Mirrors `TakeDamageFlowTests.failingDie`.
    private static let failingRoll = "19"

    /// A failed Parade no longer strands the player at "Neue Aktion" — the blow
    /// got through, so the primary way off the screen goes straight to taking
    /// the damage, with "Neue Aktion" kept underneath, visibly quieter, for the
    /// GM who rules it did nothing (owner report: "upon a failed parade the user
    /// should be prompted to enter the taken TP").
    @MainActor
    func testAFailedParryLeadsToTakingDamage() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.failingRoll, shield: true)

        parry(app, expectingWeaponList: true)

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Defence roll screen not shown")
        diceBox.tap()

        let takeDamage = app.buttons["combat.execution.takeDamage"]
        XCTAssertTrue(
            app.scrollUntilHittable(takeDamage),
            "No primary way to take the damage after a failed parry"
        )
        // The quiet way out is still there, just not the primary one.
        XCTAssertTrue(
            app.buttons["combat.execution.newAction.miss"].exists,
            "\"Neue Aktion\" disappeared instead of stepping back"
        )
        takeDamage.tap()

        XCTAssertTrue(
            app.buttons["combat.takeDamage.increaseTP"].waitForExistence(timeout: UITest.timeout),
            "Take-damage screen did not open"
        )

        let plus = app.buttons["combat.takeDamage.increaseTP"]
        for _ in 0..<5 { plus.tap() }

        let confirm = app.button(containing: "Bestätigen")
        XCTAssertTrue(confirm.waitForExistence(timeout: UITest.timeout), "Confirm missing")
        XCTAssertTrue(app.scrollUntilHittable(confirm), "Could not reach confirm")
        confirm.tap()

        let outcome = app.descendants(matching: .any)["combat.takeDamage.outcome"]
        XCTAssertTrue(outcome.waitForExistence(timeout: UITest.timeout), "The confirm reported nothing back")
        XCTAssertTrue(
            app.staticTexts["LEBENSPUNKTE"].exists,
            "The outcome should name the remaining life points"
        )
    }

    /// Owner report #3: a defence asks who is attacking. "Angriff von hinten"
    /// on the defence screen costs the dodge 4, shows it before the roll, and
    /// the roll screen charges the same line.
    @MainActor
    func testTheDefenceScreenAsksAboutTheAttacker() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.plainRoll)

        let dodge = app.buttons["combat.dodge"]
        XCTAssertTrue(dodge.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        dodge.tap()

        let fromBehind = app.buttons["combat.defense.fromBehind"]
        XCTAssertTrue(fromBehind.waitForExistence(timeout: UITest.timeout), "Defence screen not shown")
        XCTAssertTrue(app.buttons["combat.defense.advantageousPosition"].exists, "No Vorteilhafte Position toggle")
        XCTAssertFalse(app.buttons["combat.defense.onFoot"].exists, "The on-foot question is for a rider only")
        fromBehind.tap()

        let setupBox = app.descendants(matching: .any)["combat.defense.breakdown"]
        XCTAssertTrue(setupBox.waitForExistence(timeout: UITest.timeout), "No defence calculation")
        let setupRow = setupBox.descendants(matching: .any)["combat.breakdown.row.Angriff von hinten"]
        XCTAssertTrue(setupRow.waitForExistence(timeout: UITest.timeout), "Angriff von hinten not on the defence screen")
        XCTAssertTrue(setupRow.staticTexts["-4"].exists, "Angriff von hinten should cost the dodge 4")

        continueDefense(app)

        let rollBox = app.descendants(matching: .any)["combat.execution.breakdown"]
        XCTAssertTrue(rollBox.waitForExistence(timeout: UITest.timeout), "No dodge calculation")
        let rollRow = rollBox.descendants(matching: .any)["combat.breakdown.row.Angriff von hinten"]
        XCTAssertTrue(rollRow.waitForExistence(timeout: UITest.timeout), "The roll lost the defence screen's answer")
        XCTAssertTrue(rollRow.staticTexts["-4"].exists, "The roll does not charge Angriff von hinten")
    }

    // MARK: - Navigation

    @MainActor
    private func parry(_ app: XCUIApplication, expectingWeaponList: Bool) {
        tapParry(app, weapon: "Langschwert", expectingWeaponList: expectingWeaponList)
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
