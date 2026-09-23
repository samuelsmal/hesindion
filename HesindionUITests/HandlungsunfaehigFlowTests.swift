import XCTest

/// Status Handlungsunfähig on the combat root (Regelwerk 36).
///
/// > "Eine handlungsunfähige Person kann keine Aktionen oder Verteidigungen
/// > ausführen. Der Meister kann freie Aktionen erlauben."
///
/// So the screen does not simply refuse: the actions read as shut and ask
/// whether the GM allowed this one. Furcht IV is one of the Zustände that carry
/// the status, so the hero reaches it without anything being said about the
/// status itself.
final class HandlungsunfaehigFlowTests: XCTestCase {

    @MainActor
    func testAnActionAsksForTheGMsPermissionAndCanBeCalledOff() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", states: ["furcht:4"])

        let attack = app.buttons["combat.attack"]
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "Combat root not shown")

        // Each shut group says the GM is the way past it.
        let reason = app.descendants(matching: .any)["combat.incapacitated.reason"]
        XCTAssertTrue(reason.waitForExistence(timeout: UITest.timeout),
                      "Nothing says why the actions are shut")

        // Reaching for an action asks instead of acting.
        attack.tap()
        let allow = app.buttons["combat.incapacitated.allow"]
        XCTAssertTrue(allow.waitForExistence(timeout: UITest.timeout),
                      "Angriff went ahead without asking the GM")

        captureScreenshot(app, named: "59-combat-incapacitated-permission")

        // "Abbrechen" costs nothing: the fight is where it was.
        app.buttons["combat.incapacitated.cancel"].tap()
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout),
                      "Cancelling left the combat root")
        XCTAssertFalse(allow.exists, "The question is still up after Abbrechen")

        captureScreenshot(app, named: "58-combat-handlungsunfaehig")

        // A defence asks the same question, from its own button, and with the
        // GM's permission it goes through to the screen it leads to.
        app.buttons["combat.parry"].tap()
        XCTAssertTrue(allow.waitForExistence(timeout: UITest.timeout),
                      "Parieren went ahead without asking the GM")
        allow.tap()
        XCTAssertTrue(app.buttons["combat.defense.continue"].waitForExistence(timeout: UITest.timeout),
                      "The permitted defence did not open its screen")
    }

    /// Bookkeeping is not an action: taking damage has to stay possible, since
    /// that is what the rest of the table is doing to the hero.
    @MainActor
    func testRecordingDamageIsNotGuarded() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", states: ["furcht:4"])

        let takeDamage = app.button(containing: "Schaden nehmen")
        XCTAssertTrue(takeDamage.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        XCTAssertTrue(app.scrollUntilHittable(takeDamage), "Could not reach Schaden nehmen")
        takeDamage.tap()
        XCTAssertFalse(app.buttons["combat.incapacitated.allow"].waitForExistence(timeout: UITest.probeTimeout),
                       "Schaden nehmen asked the GM for permission")
    }

    /// The Schicksalspunkt "Zustand ignorieren" buys the round back: it already
    /// ignores the Zustand's modifiers, and a Stufe IV is what carries the
    /// status here, so the actions are simply live again — no question asked.
    @MainActor
    func testTheSchipLiftsTheStatusForTheRound() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", states: ["furcht:4"])

        let schip = app.button(containing: "Zustand ignorieren")
        XCTAssertTrue(schip.waitForExistence(timeout: UITest.timeout), "No Schip button")
        XCTAssertTrue(app.scrollUntilHittable(schip), "Could not reach the Schip button")
        schip.tap()

        let lifted = app.descendants(matching: .any)["combat.incapacitated.schipLifts"]
        XCTAssertTrue(lifted.waitForExistence(timeout: UITest.timeout),
                      "Nothing says the Schip lifted the status")
        XCTAssertFalse(app.descendants(matching: .any)["combat.incapacitated.reason"].exists,
                       "The actions still say they are shut")

        let attack = app.buttons["combat.attack"]
        XCTAssertTrue(app.scrollUntilHittable(attack), "Could not reach Angriff")
        attack.tap()
        XCTAssertFalse(app.buttons["combat.incapacitated.allow"].waitForExistence(timeout: UITest.probeTimeout),
                       "The action still asked although the Schip was spent")
    }
}
