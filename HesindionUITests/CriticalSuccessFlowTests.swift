import XCTest

/// The optional "Kritische Erfolge" tables end to end (ADR-0011).
///
/// Both flows are scripted rather than rolled for. A confirmed critical needs a 1
/// followed by a successful confirmation, which is roughly a 1-in-20 event, so
/// `test03ReminderCard`'s five-attempt retry loop would not be enough here — and
/// the *result* has to be fixed too, or the assertions could not name a category.
final class CriticalSuccessFlowTests: XCTestCase {

    /// AT 1, confirm 1 → a confirmed critical; 2W6 4+3 = 7 → "Schwerer Treffer";
    /// 1W20 7 → the band that doubles and adds a level of Schmerz.
    ///
    /// `ScriptedDice` repeats its queue, so the five values are consumed exactly
    /// in this order and nothing runs dry mid-flow.
    private static let attackScript = "1,1,4,3,7"

    // MARK: - Attack

    @MainActor
    func testCriticalHitTableReplacesDoubleDamage() {
        continueAfterFailure = false
        let app = UITest.launch(
            path: "combat",
            diceScript: Self.attackScript,
            fokusRules: ["kritischeErfolgeAngriff", "kritischeErfolgeDetail"]
        )

        goToMeleeAnnouncement(app)

        let torso = app.buttons["combat.zone.torso"]
        XCTAssertTrue(torso.waitForExistence(timeout: UITest.timeout), "Zone picker not shown")
        XCTAssertTrue(app.scrollUntilHittable(torso), "Could not reach the zone picker")
        torso.tap()

        app.button(containing: "Weiter").tap()

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")
        diceBox.tap()

        // With the table on, the button out of a confirmed critical leads to the
        // critical screen rather than straight to the opponent's defence: what
        // happens to the damage is settled there, either way.
        let toCritical = app.button(containing: "Kritischer Erfolg")
        XCTAssertTrue(
            toCritical.waitForExistence(timeout: UITest.timeout),
            "A confirmed critical did not offer the Kritische-Erfolge screen"
        )
        XCTAssertFalse(
            app.button(containing: "Weiter zur Verteidigung").exists,
            "The execution screen still skipped past the critical"
        )
        toCritical.tap()

        // The optional rule offers the table, it does not impose it: the basic
        // rule has to still be on the screen, or switching the Fokus-Regel on
        // would have taken plain double damage away.
        let takeTable = app.buttons["combat.critical.takeTable"]
        XCTAssertTrue(takeTable.waitForExistence(timeout: UITest.timeout), "No table option offered")
        XCTAssertTrue(
            app.buttons["combat.critical.takeBasicRule"].exists,
            "The basic rule was not offered alongside the table"
        )
        takeTable.tap()

        // 2W6 for the category.
        let rollCategory = app.buttons["combat.critical.rollCategory"]
        XCTAssertTrue(rollCategory.waitForExistence(timeout: UITest.timeout), "Critical table screen not shown")
        rollCategory.tap()
        app.confirmDiceReveal()

        let result = app.descendants(matching: .any)["combat.critical.result"]
        XCTAssertTrue(result.waitForExistence(timeout: UITest.timeout), "No category was shown")
        XCTAssertTrue(
            app.staticTexts["Schwerer Treffer"].exists,
            "2W6 4+3 = 7 should be Schwerer Treffer"
        )

        // The screen must not settle on the category alone while the Fokusregel
        // is on — the 1W20 can change the damage (7 doubles, 11–12 only adds 5 TP).
        XCTAssertFalse(
            app.buttons["combat.critical.continue"].exists,
            "The flow continued before the 1W20 refinement was rolled"
        )

        let rollDetail = app.buttons["combat.critical.rollDetail"]
        XCTAssertTrue(rollDetail.waitForExistence(timeout: UITest.timeout), "No 1W20 refinement offered")
        rollDetail.tap()
        app.confirmDiceReveal()

        // 1W20 7 lands in the 7–8 band: TP doubled, 1 Stufe Schmerz for 2 KR.
        let damage = app.descendants(matching: .any)
            .matching(identifier: "combat.critical.damage").firstMatch
        XCTAssertTrue(damage.waitForExistence(timeout: UITest.timeout), "The damage effect is not stated")
        XCTAssertTrue(
            app.staticTexts["×2"].exists,
            "Expected the doubling to be carried forward"
        )

        captureScreenshot(app, named: "22-critical-hit-table")

        // And it reaches the damage screen, where the figure is actually applied.
        let proceed = app.buttons["combat.critical.continue"]
        XCTAssertTrue(proceed.waitForExistence(timeout: UITest.timeout), "No way out of the table")
        proceed.tap()
        XCTAssertTrue(
            app.button(containing: "Treffer geht durch").waitForExistence(timeout: UITest.timeout),
            "The table did not lead to the opponent's defence"
        )
    }

    // MARK: - Melee defence

    /// The melee table *replaces* the Passierschlag: only results 7 and up hand it
    /// back. Every die is a 1 here, so 2W6 is 2 — "Geschickter Angriff" — and the
    /// button must be gone. That is the regression worth pinning: offering the
    /// free strike anyway would make the rule strictly better than the one it
    /// replaces, which is the opposite of the trade it describes.
    @MainActor
    func testMeleeDefenceTableCanWithholdThePassierschlag() {
        continueAfterFailure = false
        let app = UITest.launch(
            path: "combat",
            diceScript: "1",
            fokusRules: ["kritischeErfolgeNahkampf"]
        )

        let parry = app.button(containing: "Parieren")
        XCTAssertTrue(parry.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        parry.tap()

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Parry execution screen not shown")
        diceBox.tap()

        let toTable = app.buttons["combat.execution.criticalTable"]
        XCTAssertTrue(
            toTable.waitForExistence(timeout: UITest.timeout),
            "A confirmed critical parry did not offer the table"
        )
        // The basic rule's Passierschlag must not be offered beside the table.
        XCTAssertFalse(
            app.button(containing: "Passierschlag").exists,
            "The Passierschlag is still offered alongside the table it replaces"
        )
        toTable.tap()

        // Only one defensive table is on, so the screen does not have to ask which.
        XCTAssertFalse(app.buttons["combat.critical.chooseMelee"].exists,
                       "Asked which defence with only one table active")

        let takeTable = app.buttons["combat.critical.takeTable"]
        XCTAssertTrue(takeTable.waitForExistence(timeout: UITest.timeout), "No table option offered")
        takeTable.tap()

        let rollCategory = app.buttons["combat.critical.rollCategory"]
        XCTAssertTrue(rollCategory.waitForExistence(timeout: UITest.timeout), "Critical table screen not shown")
        rollCategory.tap()
        app.confirmDiceReveal()

        XCTAssertTrue(
            app.staticTexts["Geschickter Angriff"].waitForExistence(timeout: UITest.timeout),
            "2W6 1+1 = 2 should be Geschickter Angriff"
        )
        XCTAssertFalse(
            app.buttons["combat.critical.passierschlag"].exists,
            "Result 2 grants no Passierschlag, but the button was offered"
        )
        XCTAssertTrue(
            app.buttons["combat.critical.newAction"].waitForExistence(timeout: UITest.timeout),
            "No way back to the combat root"
        )
    }

    // MARK: - Taking the basic rule instead

    /// The optional rule reads "kann auch diese Tabelle benutzt werden" — it adds
    /// an option, it does not remove the rule it replaces. A hero who switched the
    /// Fokus-Regel on must still be able to take plain double damage on the night
    /// the table would only slow things down, exactly as the Patzer screen has
    /// always let them take 1W6+2 SP instead of the Patzertabelle.
    @MainActor
    func testTheBasicRuleIsStillAvailableWithTheTableOn() {
        continueAfterFailure = false
        let app = UITest.launch(
            path: "combat",
            diceScript: Self.attackScript,
            fokusRules: ["kritischeErfolgeAngriff", "kritischeErfolgeDetail"]
        )

        goToMeleeAnnouncement(app)

        let torso = app.buttons["combat.zone.torso"]
        XCTAssertTrue(torso.waitForExistence(timeout: UITest.timeout), "Zone picker not shown")
        XCTAssertTrue(app.scrollUntilHittable(torso), "Could not reach the zone picker")
        torso.tap()

        app.button(containing: "Weiter").tap()

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Attack execution screen not shown")
        diceBox.tap()

        let toTable = app.button(containing: "Kritischer Erfolg")
        XCTAssertTrue(toTable.waitForExistence(timeout: UITest.timeout), "No critical route offered")
        toTable.tap()

        let basic = app.buttons["combat.critical.takeBasicRule"]
        XCTAssertTrue(basic.waitForExistence(timeout: UITest.timeout), "The basic rule was not offered")

        captureScreenshot(app, named: "20-critical-resolution-choice")
        basic.tap()

        // Straight to the answer: no dice, and the plain doubling carried forward.
        XCTAssertFalse(
            app.buttons["combat.critical.rollCategory"].exists,
            "Taking the basic rule still asked for a table roll"
        )
        let damage = app.descendants(matching: .any)
            .matching(identifier: "combat.critical.damage").firstMatch
        XCTAssertTrue(damage.waitForExistence(timeout: UITest.timeout), "The damage effect is not stated")
        XCTAssertTrue(app.staticTexts["×2"].exists, "The basic rule should double the damage")

        captureScreenshot(app, named: "21-critical-basic-rule")

        let proceed = app.buttons["combat.critical.continue"]
        XCTAssertTrue(proceed.waitForExistence(timeout: UITest.timeout), "No way out of the screen")
        proceed.tap()
        XCTAssertTrue(
            app.button(containing: "Treffer geht durch").waitForExistence(timeout: UITest.timeout),
            "The basic rule did not lead to the opponent's defence"
        )
    }

    // MARK: - Skill checks

    /// Not a critical *table* — a skill check's own edge case, and the reason this
    /// test exists at all: `SkillCheckModal` used to draw its three *tumbling*
    /// dice from `DiceRoller` inside the animation loop, so a `dice_script` was
    /// empty long before the settled roll reached it. Every talent, spell,
    /// liturgy and Reiten check goes through that modal, which meant none of them
    /// could be driven to a Kritischer Erfolg or a Patzer from a test at all.
    ///
    /// Three 1s is 2+ ones, so `SkillCheckEngine` returns `.criticalSuccess`.
    @MainActor
    func testASkillCheckCanBeDrivenToACriticalSuccess() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: "1")

        let takeDamage = app.button(containing: "Schaden nehmen")
        XCTAssertTrue(takeDamage.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        takeDamage.tap()

        // Past the Wundschwelle, so the Selbstbeherrschung probe is in play.
        let plus = app.buttons["combat.takeDamage.increaseTP"]
        XCTAssertTrue(plus.waitForExistence(timeout: UITest.timeout), "Take-damage screen not shown")
        for _ in 0..<30 { plus.tap() }

        let torso = app.buttons["combat.zone.torso"]
        XCTAssertTrue(torso.waitForExistence(timeout: UITest.timeout), "Hit-zone row not shown")
        torso.tap()

        let probe = app.button(containing: "Selbstbeherrschung")
        XCTAssertTrue(probe.waitForExistence(timeout: UITest.timeout), "Probe button missing")
        XCTAssertTrue(app.scrollUntilHittable(probe), "Could not reach the probe button")
        probe.tap()

        let die = app.descendants(matching: .any)["skillCheck.die.0"]
        XCTAssertTrue(die.waitForExistence(timeout: UITest.timeout), "Probe dice not shown")
        die.tap()

        XCTAssertTrue(
            app.staticTexts["Kritischer Erfolg!"].waitForExistence(timeout: UITest.timeout),
            "Three scripted 1s did not produce a Kritischer Erfolg — the script is being consumed elsewhere"
        )
    }

    // MARK: - Helpers

    /// Combat root → Angriff → (grip choice) → melee announcement.
    @MainActor
    private func goToMeleeAnnouncement(_ app: XCUIApplication) {
        let angriff = app.button(containing: "Angriff")
        XCTAssertTrue(angriff.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        angriff.tap()

        let oneHanded = app.button(containing: "Einhändig")
        if oneHanded.waitForExistence(timeout: UITest.probeTimeout) {
            oneHanded.tap()
        }
    }
}

@MainActor
extension XCUIApplication {
    /// Waits for `DSADiceRevealModal` to settle and dismisses it. The modal holds
    /// its result until confirmed on purpose, so every scripted roll needs this.
    func confirmDiceReveal() {
        let confirm = buttons["dice.reveal.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: UITest.timeout), "Dice reveal never settled")
        confirm.tap()
    }
}
