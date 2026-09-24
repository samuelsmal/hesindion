import XCTest

/// Re-importing a plain Optolith export over a hero whose companion carries
/// Hesindion companion data asks whether to keep it
/// (docs/plans/2026-09-24-companion-data-design.md §7).
final class CompanionReimportFlowTests: XCTestCase {

    @MainActor
    private func launchReimport() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [UITest.seedArgument, "debug", "load_default",
                               "-uitest-seed-fixture", "UITestHeroCompanions",
                               "-uitest-reimport", "UITestHero"]
        app.launch()
        return app
    }

    @MainActor
    func testKeepPreviousRetainsCompanionData() {
        let app = launchReimport()

        let keep = app.buttons["companion.reimport.keep"]
        XCTAssertTrue(keep.waitForExistence(timeout: UITest.timeout))
        XCTAssertTrue(app.staticTexts["Kupperus: Begleiterdaten fehlen"].exists)
        XCTAssertTrue(app.otherElements["companion.reimport.modal"].exists)
        keep.tap()

        XCTAssertFalse(keep.waitForExistence(timeout: UITest.probeTimeout))
        let defense = app.staticTexts["pet.defense.Kupperus"]
        for _ in 0..<12 where !defense.exists { app.swipeUp() }
        XCTAssertTrue(defense.waitForExistence(timeout: UITest.timeout))
        XCTAssertEqual(defense.label, "14")
    }

    @MainActor
    func testDiscardDropsCompanionData() {
        let app = launchReimport()

        let discard = app.buttons["companion.reimport.discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: UITest.timeout))
        discard.tap()

        XCTAssertFalse(discard.waitForExistence(timeout: UITest.probeTimeout))
        for _ in 0..<12 { app.swipeUp() }
        XCTAssertFalse(app.staticTexts["pet.defense.Kupperus"].exists)
    }
}
