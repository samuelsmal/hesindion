import XCTest

/// A style that pays out only for one weapon, in one situation.
///
/// Golgariten-Stil (SA_661) is +2 AT on the Vorteilhafte Position against a foot
/// fighter, +1 PA mounted, and no TP at all — with a Rabenschnabel *or* a
/// Großschild, from horseback. It gives the same hero nothing on foot. The app
/// used to demand both pieces, grant the position itself and add a +1 TP the
/// page does not give; the catalog entry (SA_661) is the record of all three.
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

    /// Both halves of the style, each on the roll it belongs to: the raised
    /// Vorteilhafte Position in the attack, the +1 PA in the parry.
    ///
    /// The style no longer grants the position — it raises the one the rules
    /// already give a rider against a foot fighter — so the announcement has to
    /// be told what the opponent is standing on before there is anything to
    /// raise. Two launches, because a parry is a different way into the fight.
    @MainActor
    func testTheStyleIsNamedInBothCalculations() {
        continueAfterFailure = false
        let app = launchMountedAnnouncement()

        // Mounted, so the question is asked; it is the rider's half of the rule.
        let onFoot = app.buttons["combat.opponent.onFoot"]
        XCTAssertTrue(
            onFoot.waitForExistence(timeout: UITest.timeout),
            "A mounted hero must be asked whether the opponent fights on foot"
        )
        XCTAssertTrue(app.scrollUntilHittable(onFoot), "Could not reach the on-foot toggle")
        onFoot.tap()

        let attack = app.descendants(matching: .any)["combat.announcement.atBreakdown"]
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "No attack calculation")
        XCTAssertTrue(
            attack.staticTexts["Vorteilhafte Position"].exists,
            "The position the style raises should be a named row, not folded into the total"
        )
        XCTAssertTrue(
            attack.staticTexts["+4"].exists,
            "+2 for the position and +2 more for the style is one +4 line"
        )

        captureScreenshot(app, named: "41-attack-mounted-style")

        // The parry half. Nothing about the opponent is needed for it: from the
        // saddle with the style's weapon it is +1 PA, whoever is being parried.
        //
        // Scoped to the calculation, like the attack above: the hero sheet under
        // the combat cover lists the style by name, so an app-wide search for it
        // would pass whether or not the roll ever saw the rule.
        let parrying = launchMountedParry()
        let parry = parrying.descendants(matching: .any)["combat.execution.breakdown"]
        XCTAssertTrue(parry.waitForExistence(timeout: UITest.timeout), "No parry calculation")
        XCTAssertTrue(
            parry.staticTexts["Golgariten-Stil"].exists,
            "The style should name itself in the parry it pays for"
        )
        XCTAssertTrue(parry.staticTexts["+1"].exists, "Golgariten-Stil is worth +1 PA")
        captureScreenshot(parrying, named: "42-parry-mounted-style")
    }

    /// A mounted parry with the style's weapon, at the roll screen.
    @MainActor
    private func launchMountedParry() -> XCUIApplication {
        let app = UITest.launch(
            path: "combat",
            shield: true,
            weapon: "Rabenschnabel",
            mounted: true
        )
        tapParry(app, weapon: "Rabenschnabel", expectingWeaponList: true)

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Parry roll screen not shown")
        return app
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
            breakdown.staticTexts["Plänkler-Formation"].exists,
            "The formation should be a named row in the attack it modifies"
        )
        XCTAssertTrue(app.scrollUntilHittable(breakdown, maxSwipes: 6))
        captureScreenshot(app, named: "43-attack-plaenkler")
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
        // In the calculation, not in the app: the hero sheet under the combat
        // cover names the style whether or not this roll pays for it.
        let breakdown = app.descendants(matching: .any)["combat.announcement.atBreakdown"]
        XCTAssertTrue(breakdown.waitForExistence(timeout: UITest.timeout), "No attack calculation")
        XCTAssertFalse(
            breakdown.staticTexts["Golgariten-Stil"].exists,
            "The style is worth nothing on foot and should not be claimed"
        )
    }

    /// The defence after an attack is a defence against a fresh opponent.
    ///
    /// "Gegner kämpft zu Fuß" is stated on the announcement, and the parry that
    /// comes next is rolled from the combat root, which reads the very same
    /// `OpponentProfile` — so the fact used to follow the hero out of the
    /// announcement and go on paying +2 Vorteilhafte Position against whoever
    /// swung at them next. Every interaction may be with somebody else, so the
    /// profile is cleared on the way back to the root as well.
    ///
    /// The mounted rider is the case where the difference is visible: nothing
    /// else on the parry screen would say who the +2 was about.
    @MainActor
    func testTheDefenceAfterAnAttackDoesNotInheritTheAnnouncedOpponent() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", shield: true, weapon: "Rabenschnabel", mounted: true)

        // --- Announce an attack and state that the opponent is on foot.
        let attack = app.button(containing: "Angriff")
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        attack.tap()
        let heroWeapon = app.button(containing: "Rabenschnabel")
        XCTAssertTrue(heroWeapon.waitForExistence(timeout: UITest.timeout), "No hero attack offered")
        heroWeapon.tap()

        openOpponentSection(app)
        let onFoot = app.buttons["combat.opponent.onFoot"]
        XCTAssertTrue(onFoot.waitForExistence(timeout: UITest.timeout), "No on-foot toggle")
        XCTAssertTrue(app.scrollUntilHittable(onFoot), "Could not reach the on-foot toggle")
        onFoot.tap()

        let announced = app.descendants(matching: .any)["combat.announcement.atBreakdown"]
        XCTAssertTrue(announced.waitForExistence(timeout: UITest.timeout), "No attack calculation")
        XCTAssertTrue(
            announced.staticTexts["Vorteilhafte Position"].exists,
            "The stated fact should reach the attack it was stated for"
        )

        // --- Back to the root: the announcement, and with it the opponent, is over.
        app.buttons["combat.back"].tap()
        let weaponRow = app.buttons["combat.weaponRow.Rabenschnabel"]
        XCTAssertTrue(weaponRow.waitForExistence(timeout: UITest.timeout), "The back button did not reach the weapon list")
        app.buttons["combat.back"].tap()

        // --- Parry. Nobody has said anything about the one swinging now.
        tapParry(app, weapon: "Rabenschnabel", expectingWeaponList: true)
        let parry = app.descendants(matching: .any)["combat.execution.breakdown"]
        XCTAssertTrue(parry.waitForExistence(timeout: UITest.timeout), "No parry calculation")
        XCTAssertTrue(
            parry.staticTexts["Golgariten-Stil"].exists,
            "This should still be the mounted parry the style pays for"
        )
        XCTAssertFalse(
            parry.staticTexts["Vorteilhafte Position"].exists,
            "The last announcement's \"Gegner kämpft zu Fuß\" followed the hero into the next defence"
        )
        captureScreenshot(app, named: "45-parry-fresh-opponent")
    }
}
