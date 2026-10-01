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

    /// Fix rounds 1 and 2: `DSAModal`'s `scrolls` panel is exactly as tall as its content
    /// while that fits — its bottom edge sits right under the collapsed "Nicht angewandt"
    /// fold, the last thing in it, like the dice modal — and once expanding the fold grows
    /// the content past the cap, the panel stops at the cap (the close button stays
    /// reachable) and the fold's last row can be scrolled to, without the switch to a
    /// scrolling layout losing the fold's own open/closed state.
    @MainActor
    func testThePanelHugsShortContentAndCapsAndScrollsLongContent() throws {
        continueAfterFailure = false
        let app = UITest.launch()

        let le = app.buttons["sheet.value.leMax"]
        XCTAssertTrue(app.scrollUntilHittable(le), "LE max is not on the hero sheet")
        le.tap()

        let toggle = app.buttons["breakdown.notApplied.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: UITest.timeout), "The Nicht-angewandt fold is missing")
        let panel = app.otherElements["modal.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: UITest.timeout), "The modal panel has no identifier")

        // Hug: the collapsed "Mehr Infos" fold, under "Nicht angewandt", is the content's last
        // row; below it only the content's own 16pt padding (and the box's border) may remain,
        // not the rest of the cap.
        let last = app.buttons["breakdown.moreInfo.toggle"]
        XCTAssertTrue(last.exists, "The Mehr-Infos fold is missing")
        let gap = panel.frame.maxY - last.frame.maxY
        XCTAssertLessThanOrEqual(
            gap, 40,
            "The panel does not hug its content: its bottom is \(gap)pt below the last row "
                + "(panel \(panel.frame), fold \(last.frame))"
        )

        toggle.tap()

        let close = app.buttons["modal.close"]
        XCTAssertTrue(close.waitForExistence(timeout: UITest.timeout), "Close button missing after expanding")
        // The fold's expand/collapse is animated (`DSAAnimation.standard`, 0.2s), so an
        // immediate `isHittable` can catch mid-transition geometry; poll instead of
        // asserting on the very first check.
        var closeReachable = false
        for _ in 0..<20 {
            if close.isHittable { closeReachable = true; break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertTrue(closeReachable, "The close button is not reachable once the fold is expanded")

        // Cap: `DSAModal` caps the content at 60% of the screen; the header (≈50pt) and
        // the box's border come on top of that.
        let cap = app.windows.firstMatch.frame.height * 0.6
        let headerAllowance: CGFloat = 70
        XCTAssertLessThanOrEqual(
            panel.frame.height, cap + headerAllowance,
            "The expanded panel exceeds its cap: \(panel.frame.height)pt > \(cap) + \(headerAllowance)"
        )

        // The fold's own content, not the hero sheet behind it — `scrollUntilHittable`
        // would find that one instead, since it is the wider scroll view on screen.
        let section = app.otherElements["breakdown.notApplied"]
        let lastRow = app.otherElements["breakdown.notApplied.lastRow"]
        let lastRowText = app.staticTexts.matching(identifier: "breakdown.notApplied.lastRow").firstMatch
        var reachedLastRow = false
        for _ in 0..<15 {
            if (lastRow.exists && lastRow.isHittable) || (lastRowText.exists && lastRowText.isHittable) {
                reachedLastRow = true
                break
            }
            guard section.exists else { break }
            section.swipeUp()
        }
        XCTAssertTrue(reachedLastRow, "The fold's last not-applied row could not be scrolled to")
        XCTAssertTrue(close.isHittable, "The close button is no longer reachable after scrolling")

        close.tap()
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

    /// Issue #51: Kupperus at 30 LeP has Schmerz II (of 75 or 137). A tap on the line under its name at
    /// the combat root opens the Stufe's breakdown, not the GS one.
    @MainActor
    func testTappingTheMountsSchmerzAtTheRootOpensItsBreakdown() throws {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", mounted: true, mountLE: 30)

        let line = app.buttons["combat.mount.schmerz"]
        XCTAssertTrue(line.waitForExistence(timeout: UITest.timeout), "The mount's Schmerz line is not a button")
        line.tap()

        XCTAssertTrue(
            app.staticTexts["breakdown.result"].waitForExistence(timeout: UITest.timeout),
            "The breakdown sheet did not open"
        )
        XCTAssertTrue(app.staticTexts["Schmerz Kupperus"].exists, "The breakdown is not the mount's Schmerz")
        XCTAssertTrue(app.staticTexts["breakdown.intro"].exists, "Nothing says how the thresholds count")
        XCTAssertEqual(app.staticTexts["breakdown.result"].label, "Stufe II", "The result is not the Stufe")
        XCTAssertTrue(app.buttons["breakdown.moreInfo.toggle"].exists, "The clause ids have no Mehr-Infos fold")
        XCTAssertTrue(
            app.descendants(matching: .any)["breakdown.line.0"].exists,
            "The breakdown has no lines"
        )
        captureScreenshot(app, named: "68-mount-schmerz-breakdown")
    }

    /// Issue #51: the same breakdown from the companion sheet's status line.
    @MainActor
    func testTappingTheMountsSchmerzOnTheSheetOpensItsBreakdown() throws {
        continueAfterFailure = false
        let app = UITest.launch(mountLE: 30)

        let line = app.buttons["pet.schmerz.Kupperus"]
        XCTAssertTrue(app.scrollUntilHittable(line), "The mount's Schmerz line is not on the hero sheet")
        line.tap()

        XCTAssertTrue(
            app.staticTexts["breakdown.result"].waitForExistence(timeout: UITest.timeout),
            "The breakdown sheet did not open"
        )
        XCTAssertTrue(app.staticTexts["Schmerz Kupperus"].exists, "The breakdown is not the mount's Schmerz")
    }

    /// "Vor der Probe" (sheet cut-over design §6): with the seeded hero's armour equipped, a
    /// hindered talent's check shows the reminder row, and "Belastung nicht anwenden" strikes
    /// the line without removing it.
    @MainActor
    func testVorDerProbeShowsTheBelastungReminderAndTheOffSwitchStrikesTheLine() throws {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", freshCombat: true)

        // Equip the Plattenrüstung on the preparation screen — the same toggle
        // `CombatPreparationFlowTests` uses — then leave combat: the write is to the
        // hero, not the session, so it holds once we are back on the sheet.
        let armour = app.buttons["combat.armor.Plattenrüstung"]
        XCTAssertTrue(armour.waitForExistence(timeout: UITest.timeout), "The armour is not on the preparation screen")
        armour.tap()
        XCTAssertTrue(app.staticTexts["RS 6"].waitForExistence(timeout: UITest.timeout), "The armour did not equip")

        app.buttons["combat.close"].tap()

        let field = app.openCommandPalette()
        XCTAssertTrue(field.waitForExistence(timeout: UITest.timeout), "Command palette did not open")
        field.typeText("Kraftakt")
        let probe = app.button(containing: "Kraftakt")
        XCTAssertTrue(probe.waitForExistence(timeout: UITest.timeout), "Kraftakt's Probe command is not offered")
        probe.tap()

        let row = app.otherElements["vorDerProbe.row"]
        XCTAssertTrue(row.waitForExistence(timeout: UITest.timeout), "The Vor-der-Probe row did not show")

        let ignore = app.buttons["vorDerProbe.ignore"]
        XCTAssertTrue(ignore.exists, "No \"Belastung nicht anwenden\" toggle")
        ignore.tap()

        XCTAssertTrue(
            app.staticTexts["vom Spieler abgeschaltet"].waitForExistence(timeout: UITest.timeout),
            "The struck line's caption did not show"
        )

        captureScreenshot(app, named: "62-vor-der-probe-row")
    }
}
