import XCTest

/// Deleting a hero from the sidebar.
///
/// The sidebar rewrite in 3abe042 dropped the list's `.onDelete`, and nothing
/// else deleted a hero, so an imported hero could never be removed again. The
/// row now swipes like every other deletable row in the app, and the delete
/// waits for the app's own confirmation modal.
final class HeroDeletionFlowTests: XCTestCase {

    static let heroName = "Boronmir Siebenfeld von Greifenfurt"

    @MainActor
    private func swipeHeroRow(_ app: XCUIApplication) {
        let row = app.button(containing: Self.heroName)
        XCTAssertTrue(row.waitForExistence(timeout: UITest.timeout), "Hero not in the sidebar")
        row.swipeLeft()
    }

    @MainActor
    func testAHeroCanBeDeletedFromTheSidebar() {
        continueAfterFailure = false
        let app = UITest.launch()
        swipeHeroRow(app)

        let confirm = app.buttons["heroDelete.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: UITest.timeout), "Delete confirmation not shown")
        captureScreenshot(app, named: "70-hero-delete-confirm")
        confirm.tap()

        XCTAssertTrue(
            app.button(containing: Self.heroName).waitForNonExistence(timeout: UITest.timeout),
            "The hero is still in the sidebar"
        )
    }

    @MainActor
    func testCancelKeepsTheHero() {
        continueAfterFailure = false
        let app = UITest.launch()
        swipeHeroRow(app)

        let cancel = app.buttons["heroDelete.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: UITest.timeout), "Delete confirmation not shown")
        cancel.tap()

        XCTAssertFalse(cancel.waitForExistence(timeout: UITest.probeTimeout), "Confirmation did not close")
        XCTAssertTrue(app.button(containing: Self.heroName).exists, "Cancel deleted the hero")
    }
}
