import XCTest

/// The combat result screens did not scroll (owner report from manual testing:
/// "can't scroll in the apply damage view (when attacking), I usually have my
/// iPad in landscape mode"). Every one of them — the opponent-defence/damage
/// screen among them — sat in a plain `VStack` with a trailing `Spacer()`, so in
/// landscape, where the header eats a larger share of the shorter screen height,
/// the lower part of the screen ran off the bottom edge with nothing to reach it.
final class LandscapeScrollFlowTests: XCTestCase {

    /// A plain roll: 5 for the AT and 5 again for the 1W6 of damage, never 1 or
    /// 20, so there is no confirmation or critical branch to navigate
    /// (`DamageBreakdownFlowTests.plainRoll`).
    private static let plainRoll = "5"

    override func tearDownWithError() throws {
        // However the device was left, the next test starts in portrait —
        // simulator orientation persists across app launches within a run.
        XCUIDevice.shared.orientation = .portrait
        try super.tearDownWithError()
    }

    @MainActor
    func testNeueAktionIsReachableInLandscapeOnTheDamageScreen() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft

        let app = UITest.launch(path: "combat", diceScript: Self.plainRoll)

        // --- Drive a plain attack through to the opponent-defence/damage
        // screen, the same route `DamageBreakdownFlowTests` uses.
        app.button(containing: "Angriff").tap()
        let oneHanded = app.button(containing: "Einhändig")
        if oneHanded.waitForExistence(timeout: UITest.probeTimeout) { oneHanded.tap() }

        let announcementContinue = app.button(containing: "Weiter")
        XCTAssertTrue(announcementContinue.waitForExistence(timeout: UITest.timeout), "Announcement screen not shown")
        announcementContinue.tap()

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")
        diceBox.tap()

        app.button(containing: "Weiter zur Verteidigung").tap()

        let hit = app.button(containing: "Treffer geht durch")
        XCTAssertTrue(hit.waitForExistence(timeout: UITest.timeout), "Opponent defence screen not shown")
        hit.tap()

        // The damage dice have to be tapped like every other roll in the app.
        let tapToRoll = app.staticTexts["Antippen zum Würfeln"]
        XCTAssertTrue(tapToRoll.waitForExistence(timeout: UITest.timeout), "Damage dice not shown")
        tapToRoll.tap()

        captureScreenshot(app, named: "landscape-damage-screen")

        // --- The bug: in landscape, "Neue Aktion" sits below the fold and the
        // screen did not scroll to reach it.
        let newAction = app.buttons["combat.dealDamage.newAction"]
        XCTAssertTrue(newAction.waitForExistence(timeout: UITest.timeout), "\"Neue Aktion\" never appeared")
        XCTAssertTrue(
            app.scrollUntilHittable(newAction),
            "\"Neue Aktion\" is not reachable in landscape — the damage screen does not scroll"
        )
        newAction.tap()

        XCTAssertTrue(
            app.buttons["combat.parry"].waitForExistence(timeout: UITest.timeout),
            "Tapping \"Neue Aktion\" did not return to the combat root"
        )
    }
}
