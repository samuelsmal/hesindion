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
        // +1 VW, one or the other, for as long as the formation stands.
        let formation = app.buttons["combat.formation.plaenkler"]
        XCTAssertTrue(app.scrollUntilHittable(formation), "No Plänkler-Formation section")
        formation.tap()
        XCTAssertTrue(app.buttons["combat.formation.plaenkler.at"].waitForExistence(timeout: UITest.timeout))

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

    /// `weapon.info.<name>` is not a unique identifier while combat's `fullScreenCover` is up:
    /// the hero sheet it was presented over still carries the same button, off-screen but
    /// still in the accessibility tree, so a bare `app.buttons["weapon.info.Langschwert"]`
    /// resolves to two matches and `.tap()` refuses to pick one. This scrolls the combat
    /// setup screen's own scroll view until the on-screen copy — the only one `isHittable`,
    /// since the sheet's copy is covered — can be picked out of the two by index.
    @MainActor
    private func hittableCombatWeaponInfo(_ app: XCUIApplication, named name: String, maxSwipes: Int = 12) -> XCUIElement? {
        let matches = app.buttons.matching(identifier: "weapon.info.\(name)")
        for _ in 0...maxSwipes {
            if let hit = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) { return hit }
            let scrollView = app.widestScrollView
            guard scrollView.exists else { return nil }
            scrollView.swipeUp()
        }
        return matches.allElementsBoundByIndex.first(where: { $0.isHittable })
    }

    /// Final whole-branch review item 2: `WeaponInfoSheet` used to open inside
    /// `CombatLoadoutPicker`'s own `ZStack`, which sits inside this screen's
    /// `ScrollView`/`VStack` — the scrim covered only the picker's own laid-out height and the
    /// panel scrolled with the page instead of covering the window. The state now lives on
    /// this screen's root `ZStack` (as `HeroDetailView` already does for the hero sheet's own
    /// weapon info), so the close button stays hittable and the panel's frame sits fully
    /// inside the window regardless of where the picker scrolled to.
    @MainActor
    func testWeaponInfoModalIsFullScreenOnCombatSetup() {
        continueAfterFailure = false
        let app = launchFresh()

        guard let info = hittableCombatWeaponInfo(app, named: "Langschwert") else {
            return XCTFail("The Langschwert's ⓘ is not on the preparation screen")
        }
        info.tap()

        let close = app.buttons["modal.close"]
        XCTAssertTrue(close.waitForExistence(timeout: UITest.timeout), "The weapon info modal did not open")
        XCTAssertTrue(close.isHittable, "modal.close is not hittable — the scrim/panel is not covering the screen")

        let panel = app.otherElements["modal.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: UITest.timeout), "The modal panel has no identifier")
        let windowFrame = app.windows.firstMatch.frame
        XCTAssertTrue(
            windowFrame.contains(panel.frame),
            "The panel \(panel.frame) is not fully inside the window \(windowFrame) — clipped by the scroll view"
        )

        captureScreenshot(app, named: "63-combat-setup-weapon-info-modal")

        close.tap()
        XCTAssertFalse(
            app.buttons["modal.close"].waitForExistence(timeout: UITest.probeTimeout),
            "The close button did not dismiss the weapon info modal"
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

        let toggle = app.buttons["combat.formation.plaenkler"]
        XCTAssertTrue(app.scrollUntilHittable(toggle), "No Plänkler-Formation section")
        toggle.tap()

        XCTAssertTrue(
            app.buttons["combat.formation.plaenkler.at"].waitForExistence(timeout: UITest.timeout),
            "Switching the formation on must ask which half of it is taken"
        )
        XCTAssertTrue(app.buttons["combat.formation.plaenkler.aw"].exists)
    }
}
