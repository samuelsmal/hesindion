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

    /// The swipe row's own tap (it closes a swiped row) once took every tap, so
    /// a tap on a hero row no longer opened the hero.
    @MainActor
    func testATapOnTheHeroRowStillOpensTheHero() {
        continueAfterFailure = false
        let app = UITest.launch()
        let adventure = app.button(containing: UITest.adventureName)
        XCTAssertTrue(adventure.waitForExistence(timeout: UITest.timeout), "Adventure not in the sidebar")
        adventure.tap()

        let row = app.button(containing: Self.heroName)
        XCTAssertTrue(row.waitForExistence(timeout: UITest.timeout), "Hero not in the sidebar")
        XCTAssertFalse(row.isSelected, "The hero is still open after the adventure was tapped")
        row.tap()

        let selected = NSPredicate(format: "isSelected == true")
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation(for: selected, evaluatedWith: row)], timeout: UITest.timeout),
            .completed,
            "A tap on the hero row did not open the hero"
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
