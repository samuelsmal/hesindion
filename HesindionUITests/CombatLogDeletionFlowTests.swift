import XCTest

/// Deleting from the combat log (issue #13).
///
/// A finished fight could not be removed at all: the header only collapsed its rows,
/// and a collapsed combat leaves nothing to swipe. The single-entry swipe existed but
/// was the only way in, which in a narrow side panel is easy to miss — so both a
/// visible trash on the header and a long-press on an entry are covered here.
final class CombatLogDeletionFlowTests: XCTestCase {

    static let combatHeader = "Kampf —"

    /// Fights one action — damage taken, which writes a `combatAction` entry — and
    /// returns to the hero sheet with the log panel open.
    @MainActor
    private func launchWithALoggedCombat() -> XCUIApplication {
        let app = UITest.launch(path: "combat")

        let takeDamage = app.button(containing: "Schaden nehmen")
        XCTAssertTrue(takeDamage.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        takeDamage.tap()

        let plus = app.buttons["combat.takeDamage.increaseTP"]
        XCTAssertTrue(plus.waitForExistence(timeout: UITest.timeout), "Take-damage screen did not open")
        for _ in 0..<4 { plus.tap() }

        let confirm = app.button(containing: "Bestätigen")
        XCTAssertTrue(confirm.waitForExistence(timeout: UITest.timeout), "Confirm missing")
        confirm.tap()
        XCTAssertTrue(
            app.button(containing: "Neue Aktion").waitForExistence(timeout: UITest.timeout),
            "Damage was not applied"
        )

        // Back to the combat root, then out of the fight entirely — the log is a
        // panel on the hero sheet, not part of the combat cover.
        app.button(containing: "Neue Aktion").tap()
        let close = app.buttons["combat.close"]
        XCTAssertTrue(close.waitForExistence(timeout: UITest.timeout), "Combat close button missing")
        close.tap()

        let logs = app.buttons["panel.logs"]
        XCTAssertTrue(logs.waitForExistence(timeout: UITest.timeout), "Log panel button missing")
        logs.tap()
        return app
    }

    @MainActor
    private func header(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", Self.combatHeader))
            .firstMatch
    }

    /// The whole fight, from the header's own trash.
    @MainActor
    func testAWholeCombatCanBeDeletedFromItsHeader() {
        continueAfterFailure = false
        let app = launchWithALoggedCombat()

        XCTAssertTrue(
            header(app).waitForExistence(timeout: UITest.timeout),
            "The combat should be grouped under a header in the log"
        )
        captureScreenshot(app, named: "30-log-combat-group")

        let trash = app.buttons["log.deleteCombat"]
        XCTAssertTrue(trash.waitForExistence(timeout: UITest.timeout), "Combat delete button missing")
        trash.tap()

        // The dialog names the size of what is about to go, so deleting a fight is
        // not a blind press.
        let dialogTitle = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Kampf löschen?"))
            .firstMatch
        XCTAssertTrue(dialogTitle.waitForExistence(timeout: UITest.timeout), "Delete dialog not shown")
        captureScreenshot(app, named: "31-log-delete-combat")

        app.buttons["Löschen"].tap()

        XCTAssertTrue(
            header(app).waitForNonExistence(timeout: UITest.timeout),
            "The combat group should be gone once deleted"
        )
    }

    /// One action inside a fight, via long-press — the half that only had a swipe.
    @MainActor
    func testASingleActionCanBeDeletedByLongPress() {
        continueAfterFailure = false
        let app = launchWithALoggedCombat()

        let entry = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Schaden erhalten"))
            .firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: UITest.timeout), "The damage entry is not in the log")

        entry.press(forDuration: 1.2)

        let delete = app.buttons["Löschen"]
        XCTAssertTrue(delete.waitForExistence(timeout: UITest.timeout), "Long press did not offer Löschen")
        delete.tap()

        // The context menu leads to the same confirmation as the swipe. Waiting on
        // the dialog's own title first, because its button carries the same label
        // as the menu item just tapped.
        let dialogTitle = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Eintrag löschen?"))
            .firstMatch
        XCTAssertTrue(dialogTitle.waitForExistence(timeout: UITest.timeout), "Delete confirmation not shown")
        app.buttons["Löschen"].tap()

        XCTAssertTrue(
            entry.waitForNonExistence(timeout: UITest.timeout),
            "The entry should be gone once deleted"
        )
    }
}
