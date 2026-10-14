import XCTest

/// Deleting an adventure from the sidebar, and one day of its weather from the
/// timeline (issue #54). Nothing could delete either before. Both rows swipe
/// like a hero row, and both deletes wait for the app's own confirmation modal.
final class WeatherDeletionFlowTests: XCTestCase {

    /// The newest day of the seeded week (`UITestSeed.seedAdventure`).
    static let newestDay = "18. Rondra 1040 BF"

    @MainActor
    private func swipeAdventureRow(_ app: XCUIApplication) {
        let row = app.button(containing: UITest.adventureName)
        XCTAssertTrue(row.waitForExistence(timeout: UITest.timeout), "Adventure not in the sidebar")
        row.swipeLeft()
    }

    @MainActor
    func testAnAdventureCanBeDeletedFromTheSidebar() {
        continueAfterFailure = false
        let app = UITest.launch()
        swipeAdventureRow(app)

        let confirm = app.buttons["adventureDelete.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: UITest.timeout), "Delete confirmation not shown")
        captureScreenshot(app, named: "71-adventure-delete-confirm")
        confirm.tap()

        XCTAssertTrue(
            app.button(containing: UITest.adventureName).waitForNonExistence(timeout: UITest.timeout),
            "The adventure is still in the sidebar"
        )
    }

    @MainActor
    func testCancelKeepsTheAdventure() {
        continueAfterFailure = false
        let app = UITest.launch()
        swipeAdventureRow(app)

        let cancel = app.buttons["adventureDelete.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: UITest.timeout), "Delete confirmation not shown")
        cancel.tap()

        XCTAssertFalse(cancel.waitForExistence(timeout: UITest.probeTimeout), "Confirmation did not close")
        XCTAssertTrue(app.button(containing: UITest.adventureName).exists, "Cancel deleted the adventure")
    }

    /// The swipe row once took every tap on a hero row (70838a3). A tap on the
    /// adventure row still opens the adventure, and a tap on a day still opens
    /// its edit sheet.
    @MainActor
    func testTapsStillOpenTheAdventureAndTheDay() {
        continueAfterFailure = false
        let app = UITest.launch()
        let adventure = app.button(containing: UITest.adventureName)
        XCTAssertTrue(adventure.waitForExistence(timeout: UITest.timeout), "Adventure not in the sidebar")
        adventure.tap()

        let day = app.button(containing: Self.newestDay)
        XCTAssertTrue(day.waitForExistence(timeout: UITest.timeout), "A tap on the adventure row did not open it")
        day.tap()

        XCTAssertTrue(
            app.buttons["Neu würfeln"].waitForExistence(timeout: UITest.timeout),
            "A tap on the day did not open its edit sheet"
        )
    }

    /// The newest day goes, and the current date moves back to the day after
    /// the newest day left (17 Rondra), so the next stretch has no gap.
    @MainActor
    func testTheNewestWeatherDayCanBeDeleted() {
        continueAfterFailure = false
        let app = UITest.launch()
        let adventure = app.button(containing: UITest.adventureName)
        XCTAssertTrue(adventure.waitForExistence(timeout: UITest.timeout), "Adventure not in the sidebar")
        adventure.tap()

        let day = app.button(containing: Self.newestDay)
        XCTAssertTrue(day.waitForExistence(timeout: UITest.timeout), "The newest day is not in the timeline")
        day.swipeLeft()

        let confirm = app.buttons["weatherDayDelete.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: UITest.timeout), "Delete confirmation not shown")
        captureScreenshot(app, named: "72-weather-day-delete-confirm")
        // A day row once took the end of the swipe as a tap too, and opened
        // its edit sheet over the modal.
        XCTAssertFalse(app.buttons["Neu würfeln"].exists, "The swipe also opened the edit sheet")
        confirm.tap()

        XCTAssertTrue(day.waitForNonExistence(timeout: UITest.timeout), "The day is still in the timeline")
        XCTAssertTrue(
            app.staticTexts[Self.newestDay].waitForExistence(timeout: UITest.timeout),
            "The current date did not move to the day after 17 Rondra"
        )
    }
}
