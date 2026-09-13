import XCTest

/// The screen that gets a hero ready for a fight.
///
/// There was no such screen. The armour was chosen on one step, three situation
/// toggles on a second that was skipped entirely for a hero with neither
/// Plänkler-Formation nor a horse, the initiative rolled on a third, and the
/// *weapon* on a fourth — after the initiative. At no point before the first
/// attack did the app show what the hero was about to fight with.
final class CombatPreparationFlowTests: XCTestCase {

    @MainActor
    private func launchFresh() -> XCUIApplication {
        let app = UITest.launch(path: "combat", freshCombat: true)
        XCTAssertTrue(
            app.buttons["combat.armorSelection.continue"].waitForExistence(timeout: UITest.timeout),
            "Combat did not open on the armour screen"
        )
        return app
    }

    @MainActor
    private func toPreparation(_ app: XCUIApplication) {
        app.buttons["combat.armorSelection.continue"].tap()
        XCTAssertTrue(
            app.buttons["combat.setup.continue"].waitForExistence(timeout: UITest.timeout),
            "The preparation screen did not open"
        )
    }

    /// The whole point: the loadout is settled here, before the initiative.
    @MainActor
    func testThePreparationScreenAsksForTheWeapon() {
        continueAfterFailure = false
        let app = launchFresh()
        toPreparation(app)

        XCTAssertTrue(app.buttons["combat.loadout.Langschwert"].exists, "No weapon rows")
        XCTAssertTrue(app.buttons["combat.loadout.Großschild"].exists, "No shield rows")
        XCTAssertTrue(app.buttons["combat.loadout.Raufen"].exists, "Raufen is always an option")
    }

    /// The armour is chosen a step earlier and restated here, because the RS is a
    /// number the rest of the fight leans on.
    @MainActor
    func testItRestatesTheArmour() {
        continueAfterFailure = false
        let app = launchFresh()
        toPreparation(app)

        let armour = app.buttons["combat.setup.armor"]
        XCTAssertTrue(armour.exists, "The armour is not restated")
        XCTAssertTrue(armour.label.contains("RS"), "The armour row does not name the RS: \(armour.label)")
    }

    /// Screenshot: the preparation screen with everything on it.
    @MainActor
    func testPreparationScreenshot() {
        continueAfterFailure = false
        let app = launchFresh()
        captureScreenshot(app, named: "37-combat-armor")
        toPreparation(app)
        captureScreenshot(app, named: "38-combat-preparation")
    }

    /// The initiative comes after the preparation, and goes straight into the
    /// fight — the loadout screen used to sit between them.
    @MainActor
    func testTheInitiativeLeadsStraightIntoTheFight() {
        continueAfterFailure = false
        let app = launchFresh()
        toPreparation(app)

        app.buttons["combat.setup.continue"].tap()
        XCTAssertTrue(
            app.staticTexts["Neue Initiative"].waitForExistence(timeout: UITest.timeout),
            "No initiative screen"
        )
        XCTAssertFalse(
            app.buttons["combat.loadout.continue"].exists,
            "The loadout screen must not follow the initiative any more"
        )
    }

    /// Going back walks the same order in reverse.
    @MainActor
    func testBackFromPreparationReturnsToTheArmour() {
        continueAfterFailure = false
        let app = launchFresh()
        toPreparation(app)

        app.buttons["combat.back"].firstMatch.tap()
        XCTAssertTrue(
            app.buttons["combat.armorSelection.continue"].waitForExistence(timeout: UITest.timeout),
            "Back did not return to the armour screen"
        )
    }
}
