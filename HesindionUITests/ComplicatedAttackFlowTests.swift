import XCTest

/// One heavily modified attack, end to end, because every part of this app is
/// easy to check on its own and the question at the table is whether they still
/// add up together.
///
/// The turn: a Langschwert (reach Mittel) against a longer weapon, from an
/// advantageous position, at a surprised opponent's head, swung as Wuchtschlag II
/// — five modifiers on one roll, three of them negative — confirmed as a critical
/// and resolved by the basic rule, which doubles the damage *including* the
/// manoeuvre's own bonus.
///
/// Scripted, because a confirmed critical is a 1-in-20-ish event and the numbers
/// have to be nameable: AT 1, confirmation 1, then 5 on the damage W6.
final class ComplicatedAttackFlowTests: XCTestCase {

    private static let script = "1,1,5"

    /// AT 14 base − 2 reach + 2 position − 4 Wuchtschlag II − 8 head (the
    /// Zonenaufschlag's −10, eased by 2 because the target is surprised) = AT 2.
    /// Damage 5 (1W6) + 4 weapon + 4 Wuchtschlag II, doubled = 26 TP.
    @MainActor
    func testEveryModifierOnOneAttack() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.script, wuchtschlagTier: 2)

        let angriff = app.button(containing: "Angriff")
        XCTAssertTrue(angriff.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        angriff.tap()

        let oneHanded = app.button(containing: "Einhändig")
        if oneHanded.waitForExistence(timeout: UITest.probeTimeout) { oneHanded.tap() }

        // Everything about the other side lives in one fold now, shut by default.
        openOpponentSection(app)

        // 1. The opponent out-reaches the hero: Mittel against Lang is −2 AT, and
        //    the chip says so before it is chosen.
        let longReach = app.buttons["combat.reach.Lang"]
        XCTAssertTrue(longReach.waitForExistence(timeout: UITest.timeout), "Announcement screen not shown")
        XCTAssertTrue(longReach.label.contains("−2") || longReach.label.contains("-2"),
                      "The Lang chip should print its AT cost, got \(longReach.label)")
        longReach.tap()

        // 2. Vorteilhafte Position: +2 AT.
        let position = app.buttons["combat.attack.advantageousPosition"]
        XCTAssertTrue(position.waitForExistence(timeout: UITest.timeout), "Position toggle missing")
        position.tap()

        // 2b. And the target is on the ground. The penalty for that is *theirs*,
        //     on their defence — the rules give the attacker nothing for it — so
        //     it must not turn up in the hero's AT.
        let prone = app.buttons["combat.attack.prone"]
        XCTAssertTrue(prone.waitForExistence(timeout: UITest.timeout), "Prone toggle missing")
        XCTAssertTrue(app.scrollUntilHittable(prone), "Could not reach the prone toggle")
        prone.tap()

        // 3. Wuchtschlag II — offered as its own row beside Wuchtschlag I, because
        //    the hero may swing either.
        let wuchtschlagII = app.button(containing: "Wuchtschlag II")
        XCTAssertTrue(
            wuchtschlagII.waitForExistence(timeout: UITest.timeout),
            "A hero with Wuchtschlag II must be offered both tiers"
        )
        XCTAssertTrue(app.button(containing: "Wuchtschlag I").exists, "Tier I is still a legal choice")
        XCTAssertTrue(app.scrollUntilHittable(wuchtschlagII), "Could not reach Wuchtschlag II")
        wuchtschlagII.tap()

        // 4. The head, against a surprised opponent: −10 eased by 2. The zones on
        //    offer are the opponent's — a humanoid, here, so the familiar four.
        let kopf = app.buttons["combat.zone.kopf"]
        XCTAssertTrue(app.scrollUntilHittable(kopf), "Could not reach the zone picker")
        kopf.tap()

        let surprised = app.buttons["combat.zone.surprised"]
        XCTAssertTrue(surprised.waitForExistence(timeout: UITest.timeout), "Surprise toggle missing")
        XCTAssertTrue(app.scrollUntilHittable(surprised), "Could not reach the surprise toggle")
        surprised.tap()

        // The announcement's own box for what the target's posture costs
        // *them* (opponent.state liegend → STATE_10), shown before the roll.
        let announcementOpponentDefense = app.descendants(matching: .any)["combat.announcement.opponentDefense"]
        XCTAssertTrue(
            announcementOpponentDefense.waitForExistence(timeout: UITest.timeout),
            "The announcement's opponent-defence box is missing"
        )
        XCTAssertTrue(
            announcementOpponentDefense.staticTexts["Liegend"].exists,
            "The prone opponent's penalty should be named Liegend"
        )

        captureScreenshot(app, named: "34-attack-announced-complicated")

        let weiter = app.button(containing: "Weiter")
        XCTAssertTrue(app.scrollUntilHittable(weiter), "Could not reach Weiter")
        weiter.tap()

        // Every modifier, named, on one screen — the point of the calculation box.
        // Asked of the box itself: a rule's name can appear elsewhere in the app
        // (the hero sheet under the combat cover lists the Sonderfertigkeiten),
        // so an app-wide search would not be about this calculation at all.
        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")
        let atCalculation = app.descendants(matching: .any)["combat.execution.breakdown"]
        XCTAssertTrue(atCalculation.waitForExistence(timeout: UITest.timeout), "No attack calculation")
        // The zone modifier is the catalog's GRW_vorteilhaftePosition sibling
        // GRW_zonenaufschlag, and a catalog line carries the rule's own name.
        for label in ["Reichweite", "Wuchtschlag II", "Zonenaufschlag"] {
            XCTAssertTrue(
                atCalculation.staticTexts[label].exists,
                "The calculation should name \(label)"
            )
        }
        XCTAssertFalse(
            atCalculation.staticTexts["Liegend"].exists,
            "A prone target costs the hero's attack nothing"
        )
        captureScreenshot(app, named: "35-attack-calculation-complicated")

        diceBox.tap()

        // A confirmed critical, resolved by the basic rule: the table Fokusregel
        // is off, so the doubling applies without a further choice.
        let toDefense = app.button(containing: "Weiter zur Verteidigung")
        XCTAssertTrue(
            toDefense.waitForExistence(timeout: UITest.timeout),
            "The scripted 1 + 1 did not confirm a critical"
        )
        toDefense.tap()

        app.button(containing: "Treffer geht durch").tap()

        // The one calculation that *does* belong on this screen: what the GM
        // takes off the opponent's defence. This slot used to hold the hero's
        // own AT modifiers, spent on a roll that had already happened.
        let opponentDefense = app.descendants(matching: .any)["combat.dealDamage.opponentDefense"]
        XCTAssertTrue(
            opponentDefense.waitForExistence(timeout: UITest.timeout),
            "The opponent's defence modifiers are missing"
        )
        // STATE_10 is the only opponent line in this flow (no Finte announced):
        // Liegend, −2, and nothing else in the total.
        XCTAssertTrue(
            opponentDefense.staticTexts["Liegend"].exists,
            "The prone opponent's penalty should be named Liegend"
        )
        XCTAssertTrue(
            opponentDefense.staticTexts["Parieren -2"].exists,
            "Liegend is the only opponent line here: −2"
        )
        // The recap of the hero's own AT modifiers is gone: it sat under a
        // MANÖVER heading, listing numbers already spent on a roll that had
        // happened, in a row style used nowhere else.
        XCTAssertFalse(
            app.staticTexts["MANÖVER"].exists,
            "The hero's own AT modifiers do not belong on the damage screen"
        )

        let damageBox = app.staticTexts["Antippen zum Würfeln"].firstMatch
        XCTAssertTrue(damageBox.waitForExistence(timeout: UITest.timeout), "Damage dice not offered")
        damageBox.tap()

        // 5 + 4 + 4 = 13, doubled = 26. The critical multiplies the manoeuvre's
        // bonus too, which is exactly the part a folded-up formula used to hide.
        let breakdown = app.descendants(matching: .any)["combat.dealDamage.breakdown"]
        XCTAssertTrue(breakdown.waitForExistence(timeout: UITest.timeout), "Damage calculation missing")
        XCTAssertTrue(app.staticTexts["×2"].exists, "The critical's multiplier should be a row of its own")
        XCTAssertTrue(app.staticTexts["26 TP"].exists, "5 + 4 + 4 doubled is 26 TP")
        app.scrollUntilHittable(breakdown, maxSwipes: 4)
        captureScreenshot(app, named: "36-damage-complicated")
    }
}
