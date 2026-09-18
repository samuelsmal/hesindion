import XCTest

/// Deleting from the combat log (issue #13).
///
/// A finished fight could not be removed at all: the header only collapsed its rows,
/// and a collapsed combat leaves nothing to swipe. The single-entry swipe existed but
/// was the only way in, which in a narrow side panel is easy to miss — so the visible
/// trash on the header and the one on an entry row are both covered here, along with
/// the confirmation, which is the app's own modal rather than a system dialog.
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

        app.buttons["log.deleteConfirm"].tap()

        XCTAssertTrue(
            header(app).waitForNonExistence(timeout: UITest.timeout),
            "The combat group should be gone once deleted"
        )
    }

    /// One action inside a fight, from the row's own trash — the half that only had
    /// a swipe.
    @MainActor
    func testASingleActionCanBeDeletedFromItsRow() {
        continueAfterFailure = false
        let app = launchWithALoggedCombat()

        let entry = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Schaden erhalten"))
            .firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: UITest.timeout), "The damage entry is not in the log")

        let trash = app.buttons["log.deleteEntry"].firstMatch
        XCTAssertTrue(trash.waitForExistence(timeout: UITest.timeout), "Entry delete button missing")
        trash.tap()

        let dialogTitle = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Eintrag löschen?"))
            .firstMatch
        XCTAssertTrue(dialogTitle.waitForExistence(timeout: UITest.timeout), "Delete confirmation not shown")
        app.buttons["log.deleteConfirm"].tap()

        XCTAssertTrue(
            entry.waitForNonExistence(timeout: UITest.timeout),
            "The entry should be gone once deleted"
        )
    }

    /// Cancelling leaves the log alone — the modal is insistent, so this is the only
    /// way out besides deleting.
    @MainActor
    func testCancellingKeepsTheCombat() {
        continueAfterFailure = false
        let app = launchWithALoggedCombat()

        let trash = app.buttons["log.deleteCombat"]
        XCTAssertTrue(trash.waitForExistence(timeout: UITest.timeout), "Combat delete button missing")
        trash.tap()

        let cancel = app.buttons["log.deleteCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: UITest.timeout), "Cancel missing")
        cancel.tap()

        XCTAssertTrue(
            header(app).waitForExistence(timeout: UITest.timeout),
            "Cancelling must leave the combat in the log"
        )
    }
}
