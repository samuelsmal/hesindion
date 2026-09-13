import XCTest

/// End-to-end cover for "Schaden nehmen", the one combat flow with a branch in
/// it: TP → Trefferzone → Selbstbeherrschung probe → (passed | failed) →
/// Wundeffekt damage → apply.
///
/// Both probe outcomes are reachable because the app is launched with
/// `dice_script`, which feeds `DiceRoller` predetermined results (see
/// `ScriptedDice`). Without it a test can only roll and hope — which is what
/// `TrefferzonenScreenshotTests.test03ReminderCard` does, retrying up to five
/// times for a single outcome.
final class TakeDamageFlowTests: XCTestCase {

    /// The Wundeffekt's own row in the damage calculation.
    static let woundEffectRow = "Wundeffekt"

    /// A probe the hero passes without it being a critical success.
    ///
    /// Deliberately **not** 1: three 1s is a Meisterhaft and routes through
    /// `kritischerErfolg`, a different branch with its own handling. 2 clears
    /// every Selbstbeherrschung attribute outright (the hero's lowest is 13), so
    /// it passes on any hero without spending a point of FW.
    static let passingDie = 2

    /// A probe the hero fails without it being a Patzer.
    ///
    /// Deliberately **not** 20: three 20s is a Patzer and routes through
    /// `kritischerPatzer`. 19 exceeds every attribute by 5–6, so the three
    /// excesses total ~16 — beyond any plausible Selbstbeherrschung FW — and the
    /// check fails as an ordinary failure.
    static let failingDie = 19

    /// Every die comes back as `value`.
    @MainActor
    private func launchTakeDamage(dice value: Int) -> XCUIApplication {
        let app = UITest.launch(path: "combat", diceScript: "\(value)")
        let takeDamage = app.button(containing: "Schaden nehmen")
        XCTAssertTrue(takeDamage.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        takeDamage.tap()
        XCTAssertTrue(
            app.buttons["combat.takeDamage.increaseTP"].waitForExistence(timeout: UITest.timeout),
            "Take-damage screen did not open"
        )
        return app
    }

    /// Raises TP past the hero's Wundschwelle so the Wundeffekt is in play.
    @MainActor
    private func enterTP(_ app: XCUIApplication, times: Int) {
        let plus = app.buttons["combat.takeDamage.increaseTP"]
        for _ in 0..<times { plus.tap() }
    }

    /// The Wundeffekt panel is an `.accessibilityElement(children: .contain)`, so
    /// its labels do not surface through the `staticTexts` query — they have to be
    /// looked up across every element type.
    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func chooseZone(_ app: XCUIApplication, _ zone: String) {
        let chip = app.buttons["combat.zone.\(zone)"]
        XCTAssertTrue(chip.waitForExistence(timeout: UITest.timeout), "Zone chip \(zone) missing")
        chip.tap()
    }

    /// Opens the Selbstbeherrschung probe from the Wundeffekt panel and rolls it.
    @MainActor
    private func rollProbe(_ app: XCUIApplication) {
        let panel = app.otherElements["combat.woundEffectPanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: UITest.timeout), "Wundeffekt panel did not appear")

        let probe = app.button(containing: "Selbstbeherrschung")
        XCTAssertTrue(probe.waitForExistence(timeout: UITest.timeout), "Probe button missing")
        XCTAssertTrue(app.scrollUntilHittable(probe), "Could not reach the probe button")
        probe.tap()

        let die = app.otherElements["skillCheck.die.0"]
        let dieButton = die.exists ? die : app.descendants(matching: .any)["skillCheck.die.0"]
        XCTAssertTrue(dieButton.waitForExistence(timeout: UITest.timeout), "Probe dice not shown")
        dieButton.tap()

        // The check itself, fully rendered: dice, breakdown, result and the
        // controls that sit on the panel. It is the one modal built before
        // `DSAModal` existed, so it is worth a capture of its own.
        captureScreenshot(app, named: "15-take-damage-probe-modal")

        // The check is closed deliberately, not automatically — the result is
        // worth reading and a Schip reroll is still available until it is
        // dismissed. Leaving it open would make every later assertion
        // meaningless: the controls beneath still *exist*, so taps land on the
        // scrim and absence checks pass because the modal covers the screen
        // rather than because the app decided anything.
        let confirmProbe = app.buttons["skillCheck.confirm"]
        XCTAssertTrue(confirmProbe.waitForExistence(timeout: UITest.timeout), "Probe confirm missing")
        confirmProbe.tap()
        XCTAssertTrue(
            dieButton.waitForNonExistence(timeout: UITest.timeout),
            "Probe modal did not close"
        )
    }

    // MARK: - The zone is named, not optional

    /// With the Fokus-Regel on, a hit landed somewhere: the GM names the zone or
    /// it is rolled. "Keine Zone" is an offence-side choice and must not appear.
    @MainActor
    func testNoZoneChipIsNotOfferedWhenTakingDamage() {
        continueAfterFailure = false
        let app = launchTakeDamage(dice: Self.passingDie)
        XCTAssertTrue(
            app.buttons["combat.zone.torso"].waitForExistence(timeout: UITest.timeout),
            "Zone chips missing"
        )
        XCTAssertFalse(
            app.buttons["combat.zone.none"].exists,
            #""Keine Zone" must not be offered when the hero takes a hit"#
        )
    }

    /// The rolled zone is shown against the table it was rolled on; a tapped zone
    /// says nothing beyond its own highlighted chip.
    @MainActor
    func testZoneRollShowsTheTableButATapDoesNot() {
        continueAfterFailure = false
        let app = launchTakeDamage(dice: 7)
        let table = element(app, "trefferzone.table")

        chooseZone(app, "torso")
        XCTAssertFalse(table.exists, "A tapped zone should not open the reveal")

        let rollZone = app.buttons["combat.zone.roll"]
        XCTAssertTrue(rollZone.waitForExistence(timeout: UITest.timeout), "Zone roll button missing")
        rollZone.tap()

        // The published table, with the row the die landed on lit — the reveal
        // used to state "7: Torso" and leave the rule off screen.
        XCTAssertTrue(table.waitForExistence(timeout: UITest.timeout), "The zone table was not shown")
        XCTAssertTrue(
            app.staticTexts["3–12"].exists,
            "The table should print its ranges, so a 7 can be seen landing in 3-12"
        )
        captureScreenshot(app, named: "13-take-damage-zone-rolled")

        // The reveal holds the number until it is dismissed, for the same reason
        // the probe does: a modal that closes itself takes the result away
        // before it has been read.
        let confirmRoll = app.buttons["dice.reveal.confirm"]
        XCTAssertTrue(confirmRoll.waitForExistence(timeout: UITest.timeout), "Reveal confirm missing")
        confirmRoll.tap()
        XCTAssertTrue(
            app.buttons["combat.zone.torso"].waitForExistence(timeout: UITest.timeout),
            "Reveal did not close"
        )
    }

    // MARK: - Both probe branches

    /// A passed probe averts the Wundeffekt, so no extra damage is offered.
    @MainActor
    func testPassedProbeAvertsTheWoundEffect() {
        continueAfterFailure = false
        let app = launchTakeDamage(dice: Self.passingDie)
        enterTP(app, times: 12)
        chooseZone(app, "torso")
        rollProbe(app)

        // Assert against a control that *is* present, so this cannot pass merely
        // because the screen is covered or has scrolled: confirm is reachable,
        // and the Wundeffekt roll is not offered beside it.
        let confirm = app.button(containing: "Bestätigen")
        XCTAssertTrue(confirm.waitForExistence(timeout: UITest.timeout), "Confirm missing")
        XCTAssertFalse(
            app.buttons["combat.takeDamage.rollExtraDamage"].exists,
            "A passed probe should not offer Wundeffekt damage"
        )
    }

    /// A failed probe applies it, and the damage is rolled explicitly rather than
    /// silently on confirm.
    @MainActor
    func testFailedProbeRollsWoundEffectDamageThenApplies() {
        continueAfterFailure = false
        let app = launchTakeDamage(dice: Self.failingDie)
        enterTP(app, times: 12)
        chooseZone(app, "torso")
        rollProbe(app)

        let rollExtra = app.buttons["combat.takeDamage.rollExtraDamage"]
        XCTAssertTrue(
            rollExtra.waitForExistence(timeout: UITest.timeout),
            "A failed probe must offer the Wundeffekt damage roll"
        )
        captureScreenshot(app, named: "16-take-damage-probe-failed")

        // The panel sits below the fold once the wound effect expands.
        XCTAssertTrue(app.scrollUntilHittable(rollExtra), "Could not reach the damage roll button")
        rollExtra.tap()

        // Choosing "roll" settles the number at once, and only that route's result
        // stays on screen.
        let rolledValue = element(app, "combat.takeDamage.extraDamage")
        XCTAssertTrue(rolledValue.waitForExistence(timeout: UITest.timeout), "Damage figure missing")
        XCTAssertNotEqual(rolledValue.label, "+0", "Wundeffekt damage was not rolled")

        // The calculation carries the Wundeffekt as its own row as soon as it
        // contributes: it used to stop at `TP - RS`, showing 12 where the confirm
        // wrote 16.
        let calculation = element(app, "combat.takeDamage.formula")
        XCTAssertTrue(calculation.waitForExistence(timeout: UITest.timeout), "Damage calculation missing")
        XCTAssertTrue(
            app.staticTexts[Self.woundEffectRow].exists,
            "The calculation should carry a Wundeffekt row"
        )

        captureScreenshot(app, named: "17-take-damage-extra-damage")

        let confirm = app.button(containing: "Bestätigen")
        XCTAssertTrue(confirm.waitForExistence(timeout: UITest.timeout), "Confirm missing")
        XCTAssertTrue(app.scrollUntilHittable(confirm), "Could not reach confirm")
        confirm.tap()

        XCTAssertTrue(
            app.button(containing: "Neue Aktion").waitForExistence(timeout: UITest.timeout),
            "Damage was not applied"
        )
        captureScreenshot(app, named: "18-take-damage-applied")
    }

    // MARK: - What the confirm did

    /// The screen used to end at "16 LP verloren". The two questions that follow
    /// at the table — how much is left, and what applies now — went unanswered,
    /// and one of the answers is not written by any step of the flow: Schmerz is
    /// derived from the LP total and moves on its own.
    @MainActor
    func testTheOutcomeNamesTheRemainingLifePointsAndAnyNewState() {
        continueAfterFailure = false
        let app = launchTakeDamage(dice: Self.passingDie)
        enterTP(app, times: 20)

        let outcome = element(app, "combat.takeDamage.outcome")
        XCTAssertFalse(outcome.exists, "Nothing is reported before the entry is confirmed")

        let confirm = app.button(containing: "Bestätigen")
        XCTAssertTrue(confirm.waitForExistence(timeout: UITest.timeout), "Confirm missing")
        XCTAssertTrue(app.scrollUntilHittable(confirm), "Could not reach confirm")
        confirm.tap()

        XCTAssertTrue(
            outcome.waitForExistence(timeout: UITest.timeout),
            "The confirm reported nothing back"
        )
        XCTAssertTrue(
            app.staticTexts["LEBENSPUNKTE"].exists,
            "The outcome should name what the life points are now"
        )
        // 20 TP against RS 5 is 15 through, which takes this hero past the first
        // Schmerz threshold — a change nothing on the screen sets.
        XCTAssertTrue(
            app.staticTexts["Schmerz"].exists,
            "A state the damage brought on should be named"
        )
    }

    /// Taking the entry back takes the report with it.
    @MainActor
    func testUndoClearsTheOutcome() {
        continueAfterFailure = false
        let app = launchTakeDamage(dice: Self.passingDie)
        enterTP(app, times: 6)
        app.button(containing: "Bestätigen").tap()

        let outcome = element(app, "combat.takeDamage.outcome")
        XCTAssertTrue(outcome.waitForExistence(timeout: UITest.timeout), "No outcome")

        app.otherElements["combat.takeDamage.overwriteCatcher"].tap()
        app.buttons["combat.takeDamage.overwriteConfirm"].tap()

        XCTAssertTrue(
            outcome.waitForNonExistence(timeout: UITest.timeout),
            "The report should go with the entry it reports on"
        )
    }

    // MARK: - Correcting a wrong press

    /// After confirming, the inputs read as disabled but stay reachable: tapping
    /// them offers to take the entry back, so a mis-press does not force a new
    /// action and leave wrong damage on the sheet.
    @MainActor
    func testConfirmedEntryCanBeOverwritten() {
        continueAfterFailure = false
        let app = launchTakeDamage(dice: Self.passingDie)
        enterTP(app, times: 3)

        let confirm = app.button(containing: "Bestätigen")
        XCTAssertTrue(confirm.waitForExistence(timeout: UITest.timeout), "Confirm missing")
        confirm.tap()

        let newAction = app.button(containing: "Neue Aktion")
        XCTAssertTrue(newAction.waitForExistence(timeout: UITest.timeout), "Damage was not applied")

        app.otherElements["combat.takeDamage.overwriteCatcher"].tap()

        let overwrite = app.buttons["combat.takeDamage.overwriteConfirm"]
        XCTAssertTrue(overwrite.waitForExistence(timeout: UITest.timeout), "Overwrite prompt not shown")
        captureScreenshot(app, named: "19-take-damage-overwrite")
        overwrite.tap()

        XCTAssertTrue(
            confirm.waitForExistence(timeout: UITest.timeout),
            "Overwriting should return the screen to its editable state"
        )
    }
}
