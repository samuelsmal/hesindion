import XCTest

/// A tap on a sheet value opens its breakdown (sheet cut-over design §5): the result, at least
/// one line, and the folded "Nicht angewandt" list. Task 6b: both this and the weapon info open
/// as the app's own in-app modal (`DSAModal`) — sharp corners, the raised box — not a system
/// sheet, which rounds its corners.
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
        // The modal's own close button (`DSAModal`'s `onClose`), not a system sheet's
        // grabber or swipe-to-dismiss.
        XCTAssertTrue(app.buttons["modal.close"].exists, "The breakdown modal has no close button")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "60-sheet-le-breakdown"
        shot.lifetime = .keepAlways
        add(shot)

        app.buttons["modal.close"].tap()
        XCTAssertFalse(
            app.staticTexts["breakdown.result"].waitForExistence(timeout: UITest.probeTimeout),
            "The close button did not dismiss the breakdown modal"
        )
    }

    /// The ⓘ on a melee weapon row opens `WeaponInfoSheet` as the same in-app modal.
    @MainActor
    func testTappingWeaponInfoOpensItsModal() throws {
        continueAfterFailure = false
        let app = UITest.launch()

        let info = app.buttons["weapon.info.Langschwert"]
        XCTAssertTrue(app.scrollUntilHittable(info), "The Langschwert's ⓘ is not on the hero sheet")
        info.tap()

        XCTAssertTrue(
            app.buttons["modal.close"].waitForExistence(timeout: UITest.timeout),
            "The weapon info modal did not open"
        )
        XCTAssertTrue(app.staticTexts["Langschwert"].exists, "The weapon info modal has no title")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "61-weapon-info-modal"
        shot.lifetime = .keepAlways
        add(shot)

        app.buttons["modal.close"].tap()
        XCTAssertFalse(
            app.buttons["modal.close"].waitForExistence(timeout: UITest.probeTimeout),
            "The close button did not dismiss the weapon info modal"
        )
    }
}
