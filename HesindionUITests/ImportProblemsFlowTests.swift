import XCTest

/// An export whose pet fields are partly unreadable imports, and says what it could not read
/// (issue #49). The seed is `UITestHero`; `-uitest-reimport UITestHeroProblems` re-imports the
/// same hero with the old unlabelled pet text through the file picker's path.
final class ImportProblemsFlowTests: XCTestCase {

    @MainActor
    func testUnreadablePetTextShowsTheProblemsAndTheSheetKeepsThem() {
        let app = XCUIApplication()
        app.launchArguments = [UITest.seedArgument, "debug", "load_default",
                               "-uitest-reimport", "UITestHeroProblems"]
        app.launch()

        let ok = app.buttons["import.problems.ok"]
        XCTAssertTrue(ok.waitForExistence(timeout: UITest.timeout))
        XCTAssertTrue(app.otherElements["import.problems.modal"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Sonderfertigkeiten")).firstMatch.exists)
        ok.tap()
        XCTAssertFalse(ok.waitForExistence(timeout: UITest.probeTimeout))

        let row = app.staticTexts["pet.problem.Kupperus.0"]
        for _ in 0..<12 where !row.exists { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: UITest.timeout))
    }
}
