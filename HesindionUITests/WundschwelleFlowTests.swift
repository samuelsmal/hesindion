import XCTest

/// The Wundschwelle on the take-damage screen, with the Trefferzonen Fokus-Regel
/// **off** (issue #23; reversed by the sheet cut-over, design §4/R8 — see below).
///
/// The comparison used to live only inside the Wundeffekt panel, which needs that
/// focus rule and a rolled zone, so a player not using the rule had to remember
/// their threshold and do the arithmetic in their head. Issue #23 put a
/// stand-alone row on screen for that case. The Wundschwelle base value now
/// comes from the rules engine (`SheetValues.wundschwelle`), and the catalog
/// models Wundschwelle itself as part of the Trefferzonen ruleset
/// (`trefferzonen.TZ8`), so `wundschwelle.result` is `nil` without the Fokusregel, and
/// the take-damage screen hides the row on that `nil` exactly as it already did
/// for a computed `0` (task 7 controller ruling R8). Issue #23's guarantee no
/// longer holds for a hero who does not play with Trefferzonen; the first two
/// tests below now check the row's *absence*. `UITestSeed` turns the rule on
/// for everybody otherwise, so both tests switch it off explicitly.
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

    /// Without the focus rule there are no zone chips at all, and — since the
    /// catalog models Wundschwelle itself as part of the Trefferzonen ruleset
    /// (`trefferzonen.TZ8`) — the engine now has no Wundschwelle to show either
    /// (`SheetValues.wundschwelle.result` is `nil`). The row hides on that
    /// `nil` exactly as it already did for a computed `0` (design R8), so
    /// issue #23's guarantee ("shown whether or not the focus rule is on")
    /// no longer holds for this case.
    @MainActor
    func testWundschwelleIsHiddenWithoutTheFokusRule() {
        continueAfterFailure = false
        let app = launchTakeDamage()

        XCTAssertFalse(
            app.buttons["combat.zone.torso"].exists,
            "Zone chips should not appear with the Trefferzonen rule off"
        )

        XCTAssertFalse(
            app.descendants(matching: .any)["combat.takeDamage.wundschwelle"].exists,
            "Without the Fokusregel the engine has no Wundschwelle, so the row must not appear"
        )
        captureScreenshot(app, named: "28-wundschwelle-below")
    }

    /// Without the focus rule there is nothing to reach either: no row, no
    /// "erreicht" text and no Wundeffekt panel, however much damage is entered.
    @MainActor
    func testNoWundschwelleIsAnnouncedWithoutTheFokusRule() {
        continueAfterFailure = false
        let app = launchTakeDamage()
        enterTP(app, times: Self.damagePastThreshold)

        XCTAssertFalse(
            text(app, containing: "Wundschwelle erreicht").exists,
            "There is nothing to reach without the Fokusregel"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["combat.takeDamage.wundschwelle"].exists,
            "The row stays hidden regardless of how much damage is entered"
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
