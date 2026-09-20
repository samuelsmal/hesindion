import XCTest

/// Status Handlungsunfähig on the combat root (Regelwerk 36).
///
/// > "Eine handlungsunfähige Person kann keine Aktionen oder Verteidigungen
/// > ausführen."
///
/// The screen used to put up the warning banner and leave every button live.
/// Furcht IV is one of the Zustände that carry the status, so the hero reaches
/// it without anything being said about the status itself.
final class HandlungsunfaehigFlowTests: XCTestCase {

    @MainActor
    func testNoActionOrDefenceIsOfferedWhileIncapacitated() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", states: ["furcht:4"])

        let attack = app.buttons["combat.attack"]
        XCTAssertTrue(attack.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        XCTAssertFalse(attack.isEnabled, "Angriff is still offered to a handlungsunfähig hero")
        XCTAssertFalse(app.buttons["combat.flucht"].isEnabled, "Flucht is still offered")
        XCTAssertFalse(app.buttons["combat.parry"].isEnabled, "Parieren is still offered")
        XCTAssertFalse(app.buttons["combat.dodge"].isEnabled, "Ausweichen is still offered")

        // Each shut group says which rule shut it.
        let reason = app.descendants(matching: .any)["combat.incapacitated.reason"]
        XCTAssertTrue(reason.waitForExistence(timeout: UITest.timeout),
                      "Nothing says why the actions are shut")

        // Bookkeeping is not an action: taking damage still has to be possible,
        // since that is what the rest of the table is doing to the hero.
        XCTAssertTrue(app.button(containing: "Schaden nehmen").isEnabled,
                      "Schaden nehmen must stay open")

        captureScreenshot(app, named: "52-combat-handlungsunfaehig")
    }
}
