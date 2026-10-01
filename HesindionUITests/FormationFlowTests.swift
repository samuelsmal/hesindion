import XCTest

/// Issue #44: Formation (SA_862) and Plänkler-Formation (SA_884).
///
/// The seeded Boronmir has Plänkler-Formation and not Formation, so every
/// Formation test here is the ally's case (SA_862.F4): a hero without the SF
/// stands in a companion's formation, and the line says whose it is.
final class FormationFlowTests: XCTestCase {

    /// A hero without Formation is still offered an ally's, on the preparation
    /// screen, with its +2 choice.
    @MainActor
    func testAnAllysFormationIsOfferedOnThePreparationScreen() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", freshCombat: true)
        XCTAssertTrue(app.buttons["combat.setup.continue"].waitForExistence(timeout: UITest.timeout))

        let toggle = app.buttons["combat.formation.formation"]
        XCTAssertTrue(app.scrollUntilHittable(toggle), "No Formation toggle")
        XCTAssertTrue(toggle.label.contains("eines Verbündeten"), "The toggle must say the formation is an ally's: \(toggle.label)")
        toggle.tap()

        let at = app.buttons["combat.formation.formation.at"]
        XCTAssertTrue(at.waitForExistence(timeout: UITest.timeout), "Switching Formation on must ask which half is taken")
        XCTAssertTrue(at.label.contains("+2 AT"), at.label)
        XCTAssertTrue(app.buttons["combat.formation.formation.aw"].exists)
    }

    /// Rulings formation-mounted and plaenkler-mounted: mounting ends the
    /// formation, says so, and the toggles stay off while the hero rides.
    @MainActor
    func testMountingEndsTheFormationAndSaysWhy() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", freshCombat: true)
        XCTAssertTrue(app.buttons["combat.setup.continue"].waitForExistence(timeout: UITest.timeout))

        let toggle = app.buttons["combat.formation.formation"]
        XCTAssertTrue(app.scrollUntilHittable(toggle), "No Formation toggle")
        toggle.tap()
        XCTAssertTrue(app.buttons["combat.formation.formation.at"].waitForExistence(timeout: UITest.timeout))

        let mounted = app.buttons["combat.setup.mounted"]
        XCTAssertTrue(app.scrollUntilHittable(mounted), "No mount toggle")
        mounted.tap()

        XCTAssertTrue(
            app.staticTexts["Formation aufgelöst (beritten)"].waitForExistence(timeout: UITest.timeout),
            "Mounting must say that it ended the formation"
        )
        XCTAssertFalse(app.buttons["combat.formation.formation.at"].exists, "A rider stands in no formation")
        XCTAssertTrue(app.descendants(matching: .any)["combat.formation.mountedReason"].exists, "The reason is not shown")
        XCTAssertFalse(toggle.isEnabled, "The toggle must stay off while mounted")
    }

    /// The formation forms mid-fight, from the root's chip, and reaches the
    /// attack as a named line.
    @MainActor
    func testAFormationFormedMidFightIsNamedInTheAttack() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat")

        let chip = app.buttons["combat.formation.chip"]
        XCTAssertTrue(app.scrollUntilHittable(chip), "No Formation chip on the combat root")
        XCTAssertTrue(chip.label.contains("Keine Formation"), chip.label)
        chip.tap()

        let toggle = app.buttons["combat.formation.formation"]
        XCTAssertTrue(toggle.waitForExistence(timeout: UITest.timeout), "The chip did not open the formation modal")
        toggle.tap()
        XCTAssertTrue(app.buttons["combat.formation.formation.at"].waitForExistence(timeout: UITest.timeout))
        captureScreenshot(app, named: "65-formation-modal")

        app.buttons["modal.close"].tap()
        XCTAssertTrue(chip.waitForExistence(timeout: UITest.timeout))
        XCTAssertTrue(chip.label.contains("Formation +2 AT"), chip.label)

        let attack = app.button(containing: "Angriff")
        XCTAssertTrue(app.scrollUntilHittable(attack), "No attack button")
        attack.tap()
        let oneHanded = app.button(containing: "Einhändig")
        if oneHanded.waitForExistence(timeout: UITest.probeTimeout) { oneHanded.tap() }

        let breakdown = app.descendants(matching: .any)["combat.announcement.atBreakdown"]
        XCTAssertTrue(breakdown.waitForExistence(timeout: UITest.timeout), "No attack calculation")
        XCTAssertTrue(
            breakdown.staticTexts["Formation (Verbündeter)"].exists,
            "An ally's formation must be a named row in the attack it modifies"
        )
    }
}
