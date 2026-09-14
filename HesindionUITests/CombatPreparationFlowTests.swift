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
            app.buttons["combat.setup.continue"].waitForExistence(timeout: UITest.timeout),
            "Combat did not open on the preparation screen"
        )
        return app
    }

    /// The whole point: the loadout is settled here, before the initiative.
    @MainActor
    func testThePreparationScreenAsksForTheWeapon() {
        continueAfterFailure = false
        let app = launchFresh()

        XCTAssertTrue(app.buttons["combat.loadout.Langschwert"].exists, "No weapon rows")
        XCTAssertTrue(app.buttons["combat.loadout.Großschild"].exists, "No shield rows")
        XCTAssertTrue(app.buttons["combat.loadout.Raufen"].exists, "Raufen is always an option")
    }

    /// The armour is chosen here too. It used to be a screen of its own ahead of
    /// this one — the same kind of question, split across two steps for no
    /// reason, and the only one of them that could not go back.
    @MainActor
    func testTheArmourIsChosenOnTheSameScreen() {
        continueAfterFailure = false
        let app = launchFresh()

        let armour = app.buttons["combat.armor.Plattenrüstung"]
        XCTAssertTrue(armour.exists, "The armour is not on the preparation screen")

        XCTAssertTrue(app.staticTexts["RS 0"].exists, "Nothing is worn yet")

        armour.tap()
        XCTAssertTrue(
            app.staticTexts["RS 6"].waitForExistence(timeout: UITest.timeout),
            "Putting the armour on did not change the RS total"
        )
    }

    /// Screenshot: the preparation screen with everything on it.
    @MainActor
    func testPreparationScreenshot() {
        continueAfterFailure = false
        let app = launchFresh()
        app.buttons["combat.armor.Plattenrüstung"].tap()
        // Wait for the total to catch up, or the capture lands mid-press and the
        // row it was taken for is halfway through its animation.
        XCTAssertTrue(app.staticTexts["RS 6"].waitForExistence(timeout: UITest.timeout))

        // Switched on, so the shot shows the *choice* the formation is: +1 AT or
        // +1 VW, one or the other, made once per fight.
        let formation = app.buttons["combat.setup.plaenkler"]
        XCTAssertTrue(app.scrollUntilHittable(formation), "No Plänkler-Formation section")
        formation.tap()
        XCTAssertTrue(app.buttons["combat.setup.plaenkler.at"].waitForExistence(timeout: UITest.timeout))

        captureScreenshot(app, named: "37-combat-preparation")
    }

    /// The initiative comes after the preparation, and goes straight into the
    /// fight — the loadout screen used to sit between them.
    @MainActor
    func testTheInitiativeLeadsStraightIntoTheFight() {
        continueAfterFailure = false
        let app = launchFresh()

        XCTAssertTrue(app.scrollUntilHittable(app.buttons["combat.setup.continue"]))
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

    /// The Plänkler-Formation section, for a hero who has the formation.
    ///
    /// It never appeared: the importer files a Sonderfertigkeit by whether
    /// `rules.db` has a combat-scoped effect for it, SA_884 has no effects row at
    /// all, so it landed in the *general* list and `hasPlaenklerFormation` — which
    /// searched only the combat list — was false for a hero holding the ability.
    @MainActor
    func testTheFormationChoiceIsOffered() {
        continueAfterFailure = false
        let app = launchFresh()

        let toggle = app.buttons["combat.setup.plaenkler"]
        XCTAssertTrue(app.scrollUntilHittable(toggle), "No Plänkler-Formation section")
        toggle.tap()

        XCTAssertTrue(
            app.buttons["combat.setup.plaenkler.at"].waitForExistence(timeout: UITest.timeout),
            "Switching the formation on must ask which half of it is taken"
        )
        XCTAssertTrue(app.buttons["combat.setup.plaenkler.aw"].exists)
    }
}
