import XCTest

/// The Rabenschnabel's Dornenspitze, end to end: a weapon offer (catalog
/// ITEMTPL_19) shown as a toggle on the announcement.
///
/// > "Rüstungen mit RS 6 oder mehr erleiden dadurch einen Malus von -2 auf RS."
///
/// The app has no opponent RS (ADR-0005), so the −2 is a note the GM applies —
/// under the damage, never in the opponent's defence total — and it travels to
/// the execution screen's note.
final class RabenschnabelFlowTests: XCTestCase {

    @MainActor
    func testTheDornenspitzeIsANoteForTheGMNotADefenceModifier() {
        continueAfterFailure = false
        // AT 5: a hit, so the execution screen shows its note.
        let app = UITest.launch(path: "combat", diceScript: "5", weapon: "Rabenschnabel")
        let attack = app.button(containing: "Angriff")
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        attack.tap()
        let oneHanded = app.button(containing: "Einhändig")
        if oneHanded.waitForExistence(timeout: UITest.probeTimeout) { oneHanded.tap() }

        let spike = app.buttons["combat.attack.weaponOffer.ITEMTPL_19"]
        XCTAssertTrue(spike.waitForExistence(timeout: UITest.timeout), "No Dornenspitze toggle")
        XCTAssertTrue(spike.label.contains("Dornenspitze"), "got \(spike.label)")
        XCTAssertFalse(app.descendants(matching: .any)["combat.announcement.opponentRS"].exists,
                       "No RS note before the spike is chosen")
        XCTAssertTrue(app.scrollUntilHittable(spike), "Could not reach the Dornenspitze toggle")
        spike.tap()

        let rsNote = app.descendants(matching: .any)["combat.announcement.opponentRS"]
        XCTAssertTrue(rsNote.waitForExistence(timeout: UITest.timeout), "The RS note is missing")
        XCTAssertTrue(
            rsNote.staticTexts["Gegner-RS · Rabenschnabel (nur gegen RS 6 oder mehr)"].exists,
            "The RS note should name the rule and its RS 6 limit"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["combat.announcement.opponentDefense"].exists,
            "Armour is not a defence: nothing else lowers it here, so there is no VW box"
        )

        let weiter = app.buttons["combat.announcement.continue"]
        XCTAssertTrue(app.scrollUntilHittable(weiter), "Could not reach Weiter")
        weiter.tap()

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")
        diceBox.tap()

        let note = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Gegner-RS \u{2212}2 · Rabenschnabel (nur gegen RS 6 oder mehr)")
        ).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: UITest.timeout), "The execution note does not carry the RS −2")
    }
}
