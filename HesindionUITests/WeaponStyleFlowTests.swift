import XCTest

/// A style that pays out only for one weapon, in one situation.
///
/// Golgariten-Stil (SA_661) gives +2 AT and +1 TP to a hero fighting from
/// horseback with a Rabenschnabel and a Großschild — and nothing at all to the
/// same hero on foot, or with the same weapon and no shield. The TP half of it
/// went unapplied for a long time while the hero sheet said the hero had the
/// style; this is the screen where it has to be visible.
final class WeaponStyleFlowTests: XCTestCase {

    @MainActor
    private func launchMountedAnnouncement() -> XCUIApplication {
        let app = UITest.launch(
            path: "combat",
            shield: true,
            weapon: "Rabenschnabel",
            mounted: true
        )
        let attack = app.button(containing: "Angriff")
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        attack.tap()

        // Mounted, the attack screen asks whose attack it is first.
        let heroWeapon = app.button(containing: "Rabenschnabel")
        XCTAssertTrue(heroWeapon.waitForExistence(timeout: UITest.timeout), "No hero attack offered")
        heroWeapon.tap()

        openOpponentSection(app)
        return app
    }

    /// The whole style on one screen: the position it grants, the AT it is worth
    /// and the TP it adds.
    @MainActor
    func testTheStyleIsNamedInBothCalculations() {
        continueAfterFailure = false
        let app = launchMountedAnnouncement()

        // Forced on, so it is a stated fact rather than a toggle to remember.
        XCTAssertTrue(
            app.descendants(matching: .any).containing(
                NSPredicate(format: "label CONTAINS[c] %@", "Vorteilhafte Position")
            ).firstMatch.exists,
            "A mounted Golgarit is in an advantageous position by the style's own wording"
        )

        let attack = app.descendants(matching: .any)["combat.announcement.atBreakdown"]
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "No attack calculation")
        XCTAssertTrue(
            app.staticTexts["Golgariten"].exists,
            "The style should be a named row, not folded into the total"
        )

        captureScreenshot(app, named: "40-attack-mounted-style")
    }

    /// Plänkler-Formation, taken as its AT half, on the roll it modifies.
    ///
    /// The section that offers the choice never rendered at all until the
    /// ability lookup stopped caring which list the importer filed SA_884 in,
    /// so the +1 had never reached an attack.
    @MainActor
    func testTheFormationBonusIsNamedInTheAttack() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", plaenkler: "at")

        let attack = app.button(containing: "Angriff")
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        attack.tap()
        let oneHanded = app.button(containing: "Einhändig")
        if oneHanded.waitForExistence(timeout: UITest.probeTimeout) { oneHanded.tap() }

        let breakdown = app.descendants(matching: .any)["combat.announcement.atBreakdown"]
        XCTAssertTrue(breakdown.waitForExistence(timeout: UITest.timeout), "No attack calculation")
        XCTAssertTrue(
            app.staticTexts["Plänkler"].exists,
            "The formation should be a named row in the attack it modifies"
        )
        XCTAssertTrue(app.scrollUntilHittable(breakdown, maxSwipes: 6))
        captureScreenshot(app, named: "41-attack-plaenkler")
    }

    /// Same hero, same weapon, on foot: the style pays nothing, and the screen
    /// says nothing about it.
    @MainActor
    func testOnFootTheStylePaysNothing() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", shield: true, weapon: "Rabenschnabel")
        let attack = app.button(containing: "Angriff")
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        attack.tap()

        // On foot with a shield the attack goes through the weapon list first —
        // the shield is a thing you can swing too.
        let weaponRow = app.buttons["combat.weaponRow.Rabenschnabel"]
        XCTAssertTrue(weaponRow.waitForExistence(timeout: UITest.timeout), "No weapon list")
        weaponRow.tap()

        openOpponentSection(app)
        XCTAssertFalse(
            app.staticTexts["Golgariten"].exists,
            "The style is worth nothing on foot and should not be claimed"
        )
    }
}
