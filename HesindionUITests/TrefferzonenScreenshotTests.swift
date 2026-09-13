import XCTest

/// Drives the four Trefferzonen surfaces and attaches a screenshot of each.
///
/// Every test starts from the seeded store (`-uitest-seed-hero`), which imports the
/// Boronmir sample hero, switches the Trefferzonen Fokus-Regel on and leaves a combat
/// session open so the combat screens resume at the combat root.
final class TrefferzonenScreenshotTests: XCTestCase {

    // MARK: - 01 Fokus-Regeln in the hero settings

    @MainActor
    func test01FokusSettings() {
        continueAfterFailure = false
        let app = UITest.launch()

        let field = app.openCommandPalette()
        XCTAssertTrue(field.waitForExistence(timeout: UITest.timeout), "Command palette did not open")
        field.typeText("Einstellungen")

        let command = app.button(containing: "Einstellungen für")
        XCTAssertTrue(command.waitForExistence(timeout: UITest.timeout), "Settings command not offered")
        command.tap()

        // The Fokus-Regeln section sits below ~20 colour-scheme rows.
        let section = app.staticTexts["heroSettings.fokusRules"]
        XCTAssertTrue(section.waitForExistence(timeout: UITest.timeout), "Hero settings did not open")
        XCTAssertTrue(app.scrollUntilHittable(section), "Could not scroll the Fokus-Regeln section into view")

        captureScreenshot(app, named: "04-hero-settings-fokus")
    }

    // MARK: - 02 Trefferzone picker on the melee announcement

    @MainActor
    func test02ZonePicker() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat")
        goToMeleeAnnouncement(app)

        let torso = app.buttons["combat.zone.torso"]
        XCTAssertTrue(torso.waitForExistence(timeout: UITest.timeout), "Zone picker not shown on the announcement")
        XCTAssertTrue(app.scrollUntilHittable(torso), "Could not scroll the zone picker into view")
        torso.tap()

        captureScreenshot(app, named: "09-attack-zone-picker")
    }

    // MARK: - 02b The attack execution screen

    /// The AT roll screen, before rolling: the `Mod` stepper and the calculation
    /// breakdown that ends in the effective value. Both were reported as
    /// out-of-style — the caption sat under the stepper's shadow, and the total
    /// was the one unbordered surface in the app.
    @MainActor
    func test02bExecution() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat")
        goToMeleeAnnouncement(app)

        let torso = app.buttons["combat.zone.torso"]
        XCTAssertTrue(torso.waitForExistence(timeout: UITest.timeout), "Zone picker not shown")
        XCTAssertTrue(app.scrollUntilHittable(torso), "Could not reach the zone picker")
        torso.tap()

        app.button(containing: "Weiter").tap()

        // A modifier the player might actually dial in, so the breakdown shows
        // its "Zusätzlich" line rather than only the rule-derived ones.
        let plus = app.buttons["combat.execution.increaseModifier"]
        XCTAssertTrue(plus.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")
        for _ in 0..<3 { plus.tap() }

        captureScreenshot(app, named: "10-attack-execution")
    }

    // MARK: - 03 wound-effect reminder after a landed targeted attack

    @MainActor
    func test03ReminderCard() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat")

        // The AT roll is a real 1W20, so a miss is possible even with the modifier
        // pushed above 20 (a 20 always misses). Re-announce and swing again.
        var reminder = app.otherElements["combat.woundEffectReminder"]
        for attempt in 1...5 {
            goToMeleeAnnouncement(app)

            let torso = app.buttons["combat.zone.torso"]
            XCTAssertTrue(torso.waitForExistence(timeout: UITest.timeout), "Zone picker not shown")
            XCTAssertTrue(app.scrollUntilHittable(torso), "Could not reach the zone picker")
            torso.tap()

            app.button(containing: "Weiter").tap()

            // Push AT above 20 so all but a rolled 20 land.
            let plus = app.buttons["combat.execution.increaseModifier"]
            XCTAssertTrue(plus.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")
            for _ in 0..<20 { plus.tap() }

            app.otherElements["combat.execution.diceBox"].tap()

            let toDefense = app.button(containing: "Weiter zur Verteidigung")
            if toDefense.waitForExistence(timeout: UITest.probeTimeout) {
                toDefense.tap()
                app.button(containing: "Treffer geht durch").tap()
                reminder = app.otherElements["combat.woundEffectReminder"]
                if reminder.waitForExistence(timeout: UITest.timeout) { break }
                XCTFail("Attack landed but no wound-effect reminder appeared")
            }

            XCTAssertLessThan(attempt, 5, "Five attack rolls in a row failed to land")
            app.button(containing: "Neue Aktion").tap()
        }

        XCTAssertTrue(reminder.exists, "Wound-effect reminder card not shown")

        // Roll the weapon's damage first — the calculation only exists once the
        // dice have settled.
        let damageBox = app.staticTexts["Antippen zum Würfeln"].firstMatch
        if damageBox.waitForExistence(timeout: UITest.probeTimeout) {
            damageBox.tap()
        }

        // The Wundeffekt is not automatic: the opponent rolls Selbstbeherrschung
        // at the table and the player enters how it went. Nothing is offered
        // until they do.
        let passed = app.buttons["combat.opponentProbe.passed"]
        XCTAssertTrue(passed.waitForExistence(timeout: UITest.timeout), "Opponent probe not asked")
        XCTAssertFalse(
            app.buttons["combat.takeDamage.rollExtraDamage"].exists,
            "The Wundeffekt damage must not be offered before the check is answered"
        )
        app.scrollUntilHittable(passed, maxSwipes: 4)
        captureScreenshot(app, named: "11-attack-wound-effect-reminder")

        // Passed: the effect is averted and nothing is added.
        passed.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["combat.opponentProbe.outcome"]
                .waitForExistence(timeout: UITest.timeout),
            "The outcome of the opponent's check is not stated"
        )
        XCTAssertFalse(
            app.buttons["combat.takeDamage.rollExtraDamage"].exists,
            "A passed check must not offer Wundeffekt damage"
        )
        captureScreenshot(app, named: "32-attack-opponent-probe-passed")

        // Failed: the effect applies and its damage can be settled — rolled here,
        // or entered after being told.
        app.buttons["combat.opponentProbe.change"].tap()
        let failed = app.buttons["combat.opponentProbe.failed"]
        XCTAssertTrue(failed.waitForExistence(timeout: UITest.timeout), "Cannot re-answer the check")
        failed.tap()

        let rollExtra = app.buttons["combat.takeDamage.rollExtraDamage"]
        XCTAssertTrue(
            rollExtra.waitForExistence(timeout: UITest.timeout),
            "A failed check must offer the Wundeffekt damage"
        )
        XCTAssertTrue(app.scrollUntilHittable(rollExtra), "Could not reach the Wundeffekt roll")
        rollExtra.tap()

        // One calculation, with the Wundeffekt inside it.
        let breakdown = app.descendants(matching: .any)["combat.dealDamage.breakdown"]
        XCTAssertTrue(
            breakdown.waitForExistence(timeout: UITest.timeout),
            "The damage calculation is missing"
        )
        app.scrollUntilHittable(breakdown, maxSwipes: 4)
        captureScreenshot(app, named: "33-attack-opponent-probe-failed")
    }

    // MARK: - 04 Wundeffekt panel on the take-damage screen

    @MainActor
    func test04WoundEffectPanel() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat")

        let takeDamage = app.button(containing: "Schaden nehmen")
        XCTAssertTrue(takeDamage.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        takeDamage.tap()

        // Well above the hero's Wundschwelle so the Wundeffekt panel is in play.
        let plus = app.buttons["combat.takeDamage.increaseTP"]
        XCTAssertTrue(plus.waitForExistence(timeout: UITest.timeout), "Take-damage screen not shown")
        for _ in 0..<30 { plus.tap() }

        let torso = app.buttons["combat.zone.torso"]
        XCTAssertTrue(torso.waitForExistence(timeout: UITest.timeout), "Hit-zone row not shown")
        torso.tap()

        let panel = app.otherElements["combat.woundEffectPanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: UITest.timeout), "Wundeffekt panel not shown")

        captureScreenshot(app, named: "14-take-damage-effect-threatened")
    }

    // MARK: - Navigation helpers

    /// Combat root → Angriff → (grip choice) → melee announcement.
    @MainActor
    private func goToMeleeAnnouncement(_ app: XCUIApplication) {
        let angriff = app.button(containing: "Angriff")
        XCTAssertTrue(angriff.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        angriff.tap()

        // A one-handed weapon with no shield offers the grip choice first.
        let oneHanded = app.button(containing: "Einhändig")
        if oneHanded.waitForExistence(timeout: UITest.probeTimeout) {
            oneHanded.tap()
        }
    }
}
