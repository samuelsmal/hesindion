import XCTest

/// A tap on a sheet value opens its breakdown (sheet cut-over design §5): the result, at least
/// one line, and the folded "Nicht angewandt" list.
final class SheetBreakdownTests: XCTestCase {

    @MainActor
    func testTappingLEOpensItsBreakdown() throws {
        continueAfterFailure = false
        let app = UITest.launch()

        let le = app.buttons["sheet.value.leMax"]
        XCTAssertTrue(app.scrollUntilHittable(le), "LE max is not on the hero sheet")
        le.tap()

        XCTAssertTrue(
            app.staticTexts["breakdown.result"].waitForExistence(timeout: UITest.timeout),
            "The breakdown sheet did not open"
        )
        XCTAssertTrue(
            app.otherElements["breakdown.line.0"].exists
                || app.staticTexts.matching(identifier: "breakdown.line.0").firstMatch.exists,
            "The breakdown has no lines"
        )
        // `CombatDisclosureSection`'s own convention: the fold's tap target carries
        // "<identifier>.toggle", the container the bare identifier.
        XCTAssertTrue(app.buttons["breakdown.notApplied.toggle"].exists, "The Nicht-angewandt fold is missing")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "60-sheet-le-breakdown"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
