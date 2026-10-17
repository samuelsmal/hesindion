import XCTest

/// Issue #34, trefferzonen.TZ2: an attack either aims at a zone (and pays the
/// Zonenaufschlag) or names none, and then the zone is rolled with 1W20 *after*
/// the hit lands — not before the attack, where the rolled zone used to be
/// charged as an aimed one.
final class RolledHitZoneFlowTests: XCTestCase {

    /// 5 hits the AT, and on the mittel humanoid table (3–12) it is Torso.
    private static let die = 5

    @MainActor
    func testAnUnaimedAttackRollsItsZoneAfterTheHit() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: "\(Self.die)")
        goToMeleeAnnouncement(app)

        let random = app.buttons["combat.zone.random"]
        XCTAssertTrue(random.waitForExistence(timeout: UITest.timeout), "No \"Zufällige Zone\" choice on the announcement")
        XCTAssertTrue(app.scrollUntilHittable(random), "Could not reach the zone picker")
        XCTAssertFalse(
            app.buttons["combat.zone.roll"].exists,
            "The zone must not be rolled before the attack"
        )
        random.tap()
        captureScreenshot(app, named: "14-attack-zone-random")

        app.button(containing: "Weiter").tap()
        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")
        diceBox.tap()

        let toDefense = app.button(containing: "Weiter zur Verteidigung")
        XCTAssertTrue(toDefense.waitForExistence(timeout: UITest.timeout), "The scripted AT did not land")
        toDefense.tap()
        app.button(containing: "Treffer geht durch").tap()

        // The hit landed without a zone: the screen asks for the 1W20 and holds
        // the way on until it is rolled.
        let rollZone = app.buttons["combat.hitZone.roll"]
        XCTAssertTrue(rollZone.waitForExistence(timeout: UITest.timeout), "The landed hit does not ask for its zone")
        XCTAssertFalse(
            app.otherElements["combat.woundEffectReminder"].exists,
            "No wound effect before the zone is known"
        )
        XCTAssertFalse(
            app.buttons["combat.dealDamage.newAction"].exists,
            "The screen must not offer to leave while the zone is open"
        )
        XCTAssertTrue(app.scrollUntilHittable(rollZone), "Could not reach the zone roll")
        rollZone.tap()
        app.confirmDiceReveal()

        let rolled = app.staticTexts["combat.hitZone.rolled"]
        XCTAssertTrue(rolled.waitForExistence(timeout: UITest.timeout), "The rolled zone is not stated")
        XCTAssertTrue(rolled.label.contains("Torso"), "Expected Torso for a 5, got \(rolled.label)")
        XCTAssertTrue(rolled.label.contains("5"), "The raw roll should stay on screen, got \(rolled.label)")
        XCTAssertTrue(
            app.otherElements["combat.woundEffectReminder"].waitForExistence(timeout: UITest.timeout),
            "The rolled zone's wound effect is not shown"
        )
        captureScreenshot(app, named: "15-attack-zone-rolled-after-hit")
    }

    /// An aimed attack already knows its zone: nothing is rolled after the hit.
    @MainActor
    func testAnAimedAttackDoesNotRollAfterTheHit() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: "\(Self.die)")
        goToMeleeAnnouncement(app)

        let torso = app.buttons["combat.zone.torso"]
        XCTAssertTrue(torso.waitForExistence(timeout: UITest.timeout), "Zone picker not shown")
        XCTAssertTrue(app.scrollUntilHittable(torso), "Could not reach the zone picker")
        torso.tap()

        app.button(containing: "Weiter").tap()
        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")
        diceBox.tap()
        let toDefense = app.button(containing: "Weiter zur Verteidigung")
        XCTAssertTrue(toDefense.waitForExistence(timeout: UITest.timeout), "The scripted AT did not land")
        toDefense.tap()
        app.button(containing: "Treffer geht durch").tap()

        XCTAssertTrue(
            app.otherElements["combat.woundEffectReminder"].waitForExistence(timeout: UITest.timeout),
            "The aimed zone's wound effect is not shown"
        )
        XCTAssertFalse(app.buttons["combat.hitZone.roll"].exists, "An aimed hit must not ask for a zone roll")
    }

    @MainActor
    private func goToMeleeAnnouncement(_ app: XCUIApplication) {
        let angriff = app.button(containing: "Angriff")
        XCTAssertTrue(angriff.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        angriff.tap()

        let oneHanded = app.button(containing: "Einhändig")
        if oneHanded.waitForExistence(timeout: UITest.probeTimeout) {
            oneHanded.tap()
        }
    }
}
