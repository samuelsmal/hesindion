import XCTest

/// A consecrated weapon against a demon, end to end.
///
/// > "Angriffe mit geweihten Waffen bewirken bei Dämonen regulären Schaden.
/// > Angriffe mit geweihten Waffen der Gegengottheit erzeugen doppelte
/// > Trefferpunkte." — Fokusregel *Karmale Objekte*
///
/// The hero carries a Rabenschnabel, Boron's own weapon, and the seed marks it
/// consecrated the way the hero settings screen would.
final class KarmalWeaponFlowTests: XCTestCase {

    /// The Rabenschnabel is 1W6+4, so a scripted 5 gives 9 TP before anything
    /// else — and 18 doubled.
    private static let die = 5

    @MainActor
    private func launchAnnouncement(consecrated: Bool, rule: Bool = true) -> XCUIApplication {
        let app = UITest.launch(
            path: "combat",
            diceScript: "\(Self.die)",
            fokusRules: rule ? ["karmaleObjekte"] : [],
            weapon: "Rabenschnabel",
            consecrate: consecrated ? ["Rabenschnabel"] : []
        )
        let attack = app.button(containing: "Angriff")
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        attack.tap()

        let oneHanded = app.button(containing: "Einhändig")
        if oneHanded.waitForExistence(timeout: UITest.probeTimeout) { oneHanded.tap() }

        XCTAssertTrue(
            app.buttons["combat.reach.Mittel"].waitForExistence(timeout: UITest.timeout),
            "The announcement screen did not open"
        )
        return app
    }

    // MARK: - When the question is asked at all

    /// Only for a weapon the player has marked. Every other weapon would get a
    /// question the rule has no answer for.
    @MainActor
    func testAnOrdinaryWeaponIsNotAskedAboutDemons() {
        continueAfterFailure = false
        let app = launchAnnouncement(consecrated: false)
        XCTAssertFalse(app.buttons["combat.attack.daemon"].exists)
    }

    /// And only when the table plays with the rule.
    @MainActor
    func testTheQuestionNeedsTheRule() {
        continueAfterFailure = false
        let app = launchAnnouncement(consecrated: true, rule: false)
        XCTAssertFalse(app.buttons["combat.attack.daemon"].exists)
    }

    @MainActor
    func testAConsecratedWeaponIsAskedAboutDemons() {
        continueAfterFailure = false
        let app = launchAnnouncement(consecrated: true)
        XCTAssertTrue(app.buttons["combat.attack.daemon"].exists)
        XCTAssertFalse(
            app.buttons["combat.attack.opposingDeity"].exists,
            "The follow-up only matters once the target is a demon"
        )
    }

    // MARK: - What it does to the damage

    /// A demon, but not one this weapon is sworn against: regular damage. The
    /// rule still says something — reaching a demon at all is the exception —
    /// but it multiplies nothing.
    @MainActor
    func testAnOrdinaryDemonDoesNotDoubleTheDamage() {
        continueAfterFailure = false
        let app = launchAnnouncement(consecrated: true)
        app.buttons["combat.attack.daemon"].tap()

        XCTAssertFalse(
            app.staticTexts["×2"].exists,
            "Nothing should double against a demon of another god"
        )
    }

    @MainActor
    func testTheOpposingDeityDoublesTheDamage() {
        continueAfterFailure = false
        let app = launchAnnouncement(consecrated: true)
        app.buttons["combat.attack.daemon"].tap()
        let opposing = app.buttons["combat.attack.opposingDeity"]
        XCTAssertTrue(opposing.waitForExistence(timeout: UITest.timeout), "No opposing-deity row")
        opposing.tap()

        captureScreenshot(app, named: "39-attack-karmal-announcement")

        XCTAssertTrue(
            app.staticTexts["×2"].waitForExistence(timeout: UITest.timeout),
            "The announcement does not show the doubling"
        )
    }

    /// The whole way through: the doubling announced before the roll and applied
    /// after it. 1W6+4 with a scripted 5 is 9 TP; doubled, 18.
    @MainActor
    func testTheDoublingReachesTheReportedTotal() {
        continueAfterFailure = false
        let app = launchAnnouncement(consecrated: true)
        app.buttons["combat.attack.daemon"].tap()
        app.buttons["combat.attack.opposingDeity"].tap()

        let weiter = app.buttons["combat.announcement.continue"]
        XCTAssertTrue(app.scrollUntilHittable(weiter), "Could not reach Weiter")
        weiter.tap()

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")
        diceBox.tap()

        let proceed = app.button(containing: "Weiter zur Verteidigung")
        XCTAssertTrue(proceed.waitForExistence(timeout: UITest.timeout), "No way through to the damage")
        XCTAssertTrue(app.scrollUntilHittable(proceed), "Could not reach the defence button")
        proceed.tap()

        let hit = app.button(containing: "Treffer geht durch")
        XCTAssertTrue(hit.waitForExistence(timeout: UITest.timeout), "No damage step")
        hit.tap()

        let damageBox = app.staticTexts["Antippen zum Würfeln"].firstMatch
        if damageBox.waitForExistence(timeout: UITest.probeTimeout) { damageBox.tap() }

        let breakdown = app.descendants(matching: .any)["combat.dealDamage.breakdown"]
        XCTAssertTrue(breakdown.waitForExistence(timeout: UITest.timeout), "No damage calculation")
        captureScreenshot(app, named: "40-damage-karmal")

        // 5 on the W6 + 4 from the weapon is 9, doubled by the Weihe: 18.
        XCTAssertTrue(app.staticTexts["×2"].exists, "The doubling should be a row of its own")
        XCTAssertTrue(app.staticTexts["18 TP"].exists, "9 TP doubled is 18 TP")
    }
}
