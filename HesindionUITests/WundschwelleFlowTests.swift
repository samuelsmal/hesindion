import XCTest

/// The Wundschwelle on the take-damage screen, with the Trefferzonen Fokus-Regel
/// **off** (issue #23).
///
/// The comparison used to live only inside the Wundeffekt panel, which needs that
/// focus rule and a rolled zone, so a player not using the rule had to remember
/// their threshold and do the arithmetic in their head. Both tests launch with the
/// rule switched off — `UITestSeed` turns it on for everybody otherwise — because
/// that is the configuration where the screen said nothing.
final class WundschwelleFlowTests: XCTestCase {

    /// Comfortably past any starting hero's Wundschwelle (ceil(KO / 2)).
    static let damagePastThreshold = 12

    @MainActor
    private func launchTakeDamage() -> XCUIApplication {
        let app = UITest.launch(path: "combat", fokusRulesOff: ["trefferzonen"])
        let takeDamage = app.button(containing: "Schaden nehmen")
        XCTAssertTrue(takeDamage.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        takeDamage.tap()
        XCTAssertTrue(
            app.buttons["combat.takeDamage.increaseTP"].waitForExistence(timeout: UITest.timeout),
            "Take-damage screen did not open"
        )
        return app
    }

    @MainActor
    private func enterTP(_ app: XCUIApplication, times: Int) {
        let plus = app.buttons["combat.takeDamage.increaseTP"]
        for _ in 0..<times { plus.tap() }
    }

    /// The row is a container element (`children: .contain`), so its own labels are
    /// reachable as descendants rather than through `staticTexts`.
    @MainActor
    private func text(_ app: XCUIApplication, containing needle: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", needle))
            .firstMatch
    }

    /// Without the focus rule there are no zone chips at all — and that used to take
    /// the Wundschwelle with it.
    @MainActor
    func testWundschwelleIsShownWithoutTheFokusRule() {
        continueAfterFailure = false
        let app = launchTakeDamage()

        XCTAssertFalse(
            app.buttons["combat.zone.torso"].exists,
            "Zone chips should not appear with the Trefferzonen rule off"
        )

        let row = app.descendants(matching: .any)["combat.takeDamage.wundschwelle"]
        XCTAssertTrue(
            row.waitForExistence(timeout: UITest.timeout),
            "The Wundschwelle row must be on screen whether or not the focus rule is on"
        )

        // At 0 TP it states where the hit stands, which is the whole point: the
        // threshold is a number the player should not have to remember.
        XCTAssertTrue(
            text(app, containing: "Wundschwelle").exists,
            "The row should name the Wundschwelle"
        )
        captureScreenshot(app, named: "28-wundschwelle-below")
    }

    /// Past the threshold the row says so, and says what is missing before a
    /// Wundeffekt — rather than implying an effect the rule is not providing.
    @MainActor
    func testWundschwelleReachedIsAnnouncedAndZoneEffectsAreExplained() {
        continueAfterFailure = false
        let app = launchTakeDamage()
        enterTP(app, times: Self.damagePastThreshold)

        XCTAssertTrue(
            text(app, containing: "Wundschwelle erreicht").waitForExistence(timeout: UITest.timeout),
            "Reaching the Wundschwelle must be stated on screen"
        )
        XCTAssertTrue(
            text(app, containing: "Fokusregel Trefferzonen").exists,
            "With the rule off, the row should say why no Wundeffekt follows"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["combat.woundEffectPanel"].exists,
            "The Wundeffekt panel still belongs to the focus rule"
        )
        captureScreenshot(app, named: "29-wundschwelle-reached")
    }

    /// With the rule on and a zone chosen, the full panel prints the same
    /// comparison — so the standalone row stands down instead of stating it twice.
    @MainActor
    func testTheRowStandsDownOnceTheWoundEffectPanelShowsTheSameLine() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat")
        let takeDamage = app.button(containing: "Schaden nehmen")
        XCTAssertTrue(takeDamage.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        takeDamage.tap()

        let plus = app.buttons["combat.takeDamage.increaseTP"]
        XCTAssertTrue(plus.waitForExistence(timeout: UITest.timeout), "Take-damage screen did not open")
        for _ in 0..<Self.damagePastThreshold { plus.tap() }

        let zone = app.buttons["combat.zone.torso"]
        XCTAssertTrue(zone.waitForExistence(timeout: UITest.timeout), "Zone chips missing")
        zone.tap()

        let panel = app.descendants(matching: .any)["combat.woundEffectPanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: UITest.timeout), "Wundeffekt panel did not appear")
        XCTAssertFalse(
            app.descendants(matching: .any)["combat.takeDamage.wundschwelle"].exists,
            "The panel already prints the comparison — the row must not repeat it"
        )
    }
}
