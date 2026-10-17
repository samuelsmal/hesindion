import XCTest

/// Issue #41: the mount's Mächtiger Schlag is stated after the attack, for
/// the defence the opponent made — not before the roll, and not on a miss.
///
/// The seeded Kupperus has the SF and KK 25, so the Kraftakt is −3.
final class MightyBlowFollowUpFlowTests: XCTestCase {

    /// 5 hits Tritt's AT 15.
    private static let die = 5

    @MainActor
    private func launchToOpponentDefense() -> XCUIApplication {
        let app = UITest.launch(path: "combat", diceScript: "\(Self.die)", mounted: true)
        let attack = app.button(containing: "Angriff")
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        attack.tap()

        let tritt = app.button(containing: "Kupperus: Tritt")
        XCTAssertTrue(tritt.waitForExistence(timeout: UITest.timeout), "No Tritt offered")
        XCTAssertTrue(app.scrollUntilHittable(tritt), "Could not reach Tritt")
        tritt.tap()

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")
        diceBox.tap()

        let toDefense = app.button(containing: "Weiter zur Verteidigung")
        XCTAssertTrue(toDefense.waitForExistence(timeout: UITest.timeout), "The scripted AT did not land")
        toDefense.tap()
        return app
    }

    @MainActor
    func testAHitShowsTheKraftaktCheckBesideTheDamage() {
        continueAfterFailure = false
        let app = launchToOpponentDefense()

        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Nur Ausweichen")).firstMatch
                .waitForExistence(timeout: UITest.timeout),
            "The screen should say before the choice that a parry does not avoid it"
        )
        app.button(containing: "Treffer geht durch").tap()

        let card = app.descendants(matching: .any)["combat.dealDamage.followUp"]
        XCTAssertTrue(app.scrollUntilHittable(card), "No follow-up card after the hit")
        XCTAssertTrue(card.label.contains("Kraftakt −3"), "Expected Kraftakt −3, got \(card.label)")
        XCTAssertTrue(card.label.contains("Kupperus: KK 25"), "The penalty should name the mount's KK, got \(card.label)")
        captureScreenshot(app, named: "64-mighty-blow-follow-up-hit")
    }

    @MainActor
    func testAParryStillAsksForTheCheck() {
        continueAfterFailure = false
        let app = launchToOpponentDefense()

        app.button(containing: "Pariert").tap()

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: UITest.timeout), "No toast after the parry")
        XCTAssertTrue(toast.label.contains("Kraftakt −3"), "Expected the Kraftakt check, got \(toast.label)")
    }

    @MainActor
    func testADodgeSaysTheRuleDidNotApply() {
        continueAfterFailure = false
        let app = launchToOpponentDefense()

        app.button(containing: "Ausgewichen").tap()

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: UITest.timeout), "No toast after the dodge")
        XCTAssertTrue(toast.label.contains("nicht angewandt"), "Expected 'nicht angewandt', got \(toast.label)")
        XCTAssertTrue(toast.label.contains("ausgewichen"), "The reason should be the dodge, got \(toast.label)")
    }
}
