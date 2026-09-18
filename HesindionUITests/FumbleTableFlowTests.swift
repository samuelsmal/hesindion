import XCTest

/// The Patzertabelle end to end: a confirmed Patzer on a Parade, the table
/// rolled, and the result *applied* rather than described.
///
/// Every roll is scripted. A confirmed fumble needs a 20 followed by a
/// confirmation that also misses, which is a ~1-in-20 event, and the table result
/// has to be fixed too or no assertion could name one — `CriticalSuccessFlowTests`
/// scripts a confirmed critical the same way. `ScriptedDice` repeats its queue, so
/// every die a flow takes is written out in order rather than left to wrap.
final class FumbleTableFlowTests: XCTestCase {

    /// PA 20, confirmation 20 → confirmed Patzer; 2W6 3+4 = 7 → "Sturz";
    /// 3W20 19/19/19 → the Körperbeherrschung check fails (19 exceeds every one
    /// of this hero's attributes by 5–6, so the excesses are far beyond any
    /// plausible FW — and 19 is not 20, so it is an ordinary failure rather than
    /// a Patzer with a branch of its own).
    private static let fallScript = "20,20,3,4,19,19,19"

    /// The same up to the check, which is then passed: 2 clears every attribute
    /// outright (the hero's lowest is 13) without spending a point of FW.
    private static let fallPassedScript = "20,20,3,4,2,2,2"

    /// 2W6 5+6 = 11 → "Selbst verletzt", then a 3 on the Langschwert's own
    /// 1W6+4 → 7 TP against the hero.
    private static let selfDamageScript = "20,20,5,6,3"

    /// 2W6 4+4 = 8 → "Stolpern": the next Handlung is 2 harder, and only the
    /// next one.
    private static let stumbleScript = "20,20,4,4"

    /// 2W6 2+2 = 4 → "Waffe beschädigt": AT and PA 2 harder until it is
    /// repaired. The parry is made with the Langschwert, so the Langschwert is
    /// what the result dents.
    private static let damagedScript = "20,20,2,2"

    // MARK: - Sturz

    /// The owner's report: "upon 'Sturz' the direct probe check is not there …
    /// a button to roll the probe and upon failure directly the new status
    /// 'Liegend', which should then make following defenses, attacks and
    /// movement more difficult."
    @MainActor
    func testAFailedSturzCheckAppliesLiegendAndTheNextRollsPayForIt() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.fallScript)

        rollTheTable(app, expecting: "Sturz")

        // Nothing is applied before the check: the result *is* the check.
        XCTAssertFalse(
            app.buttons["combat.execution.newAction.miss"].exists,
            "The screen offered a way out while the Sturz check was still open"
        )

        rollProbe(app)

        let writes = app.descendants(matching: .any)["combat.fumble.writes"]
        XCTAssertTrue(
            writes.waitForExistence(timeout: UITest.timeout),
            "The screen did not report what it wrote"
        )
        XCTAssertTrue(writes.staticTexts["Liegend"].exists, "A failed Sturz check applies Liegend")
        captureScreenshot(app, named: "40-fumble-sturz-liegend")

        // --- Back at the root, the hero is visibly on the ground.
        let newAction = app.buttons["combat.execution.newAction.miss"]
        XCTAssertTrue(app.scrollUntilHittable(newAction), "No way back to the combat root")
        newAction.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["state.chip.liegend"]
                .waitForExistence(timeout: UITest.timeout),
            "The combat root's states strip does not show Liegend"
        )

        // --- The next parry is 2 harder (STATE_10, the rules' own name on the row).
        let parry = app.buttons["combat.parry"]
        XCTAssertTrue(parry.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        parry.tap()

        let paCalculation = app.descendants(matching: .any)["combat.execution.breakdown"]
        XCTAssertTrue(paCalculation.waitForExistence(timeout: UITest.timeout), "No parry calculation")
        XCTAssertTrue(
            paCalculation.staticTexts["Liegend"].exists,
            "The parry does not name Liegend"
        )
        XCTAssertTrue(paCalculation.staticTexts["-2"].exists, "Liegend costs a defence 2")

        // Back to the root: parry execution → weapon list → root.
        app.buttons["combat.back"].tap()
        XCTAssertTrue(
            app.buttons["combat.weaponRow.Langschwert"].waitForExistence(timeout: UITest.timeout),
            "Back from the parry roll should land on the weapon list"
        )
        app.buttons["combat.back"].tap()
        XCTAssertTrue(
            app.buttons["combat.parry"].waitForExistence(timeout: UITest.timeout),
            "Back from the weapon list should land on the combat root"
        )

        // --- And the next attack is 4 harder.
        goToMeleeAnnouncement(app)
        let weiter = app.button(containing: "Weiter")
        XCTAssertTrue(app.scrollUntilHittable(weiter), "Could not reach Weiter")
        weiter.tap()

        let atCalculation = app.descendants(matching: .any)["combat.execution.breakdown"]
        XCTAssertTrue(atCalculation.waitForExistence(timeout: UITest.timeout), "No attack calculation")
        XCTAssertTrue(
            atCalculation.staticTexts["Liegend"].exists,
            "The attack does not name Liegend"
        )
        XCTAssertTrue(atCalculation.staticTexts["-4"].exists, "Liegend costs an attack 4")
        captureScreenshot(app, named: "41-fumble-liegend-attack-penalty")
    }

    /// The other half of the same rule: a passed check applies nothing. An
    /// automatic Liegend would be worse than the prose it replaced.
    @MainActor
    func testAPassedSturzCheckAppliesNothing() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.fallPassedScript)

        rollTheTable(app, expecting: "Sturz")
        rollProbe(app)

        let panel = app.descendants(matching: .any)["combat.fumbleEffectPanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: UITest.timeout), "No effect panel")
        XCTAssertTrue(panel.staticTexts["Erfolg"].exists, "The check should have passed")
        XCTAssertFalse(
            app.descendants(matching: .any)["combat.fumble.writes"].exists,
            "A passed check wrote something"
        )

        let newAction = app.buttons["combat.execution.newAction.miss"]
        XCTAssertTrue(app.scrollUntilHittable(newAction), "No way back to the combat root")
        newAction.tap()

        XCTAssertTrue(
            app.buttons["combat.parry"].waitForExistence(timeout: UITest.timeout),
            "Combat root not shown"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["state.chip.liegend"].exists,
            "A passed Sturz check still laid the hero out"
        )
    }

    // MARK: - Selbst verletzt

    /// Result 11 is the hero's own weapon damage against themselves. The figure
    /// is carried to the take-damage screen prefilled rather than applied on the
    /// fumble screen, so the armour, the Wundschwelle and the single LP write all
    /// stay in the one place that does them.
    @MainActor
    func testSelfInjuryArrivesAtTheDamageScreenWithTheTPAlreadyIn() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.selfDamageScript)

        rollTheTable(app, expecting: "Selbst verletzt")

        let selfDamage = app.descendants(matching: .any)["combat.fumble.selfDamage"]
        XCTAssertTrue(
            selfDamage.waitForExistence(timeout: UITest.timeout),
            "The screen did not show what the hero's own weapon rolled"
        )
        // 1W6+4, a scripted 3.
        XCTAssertTrue(selfDamage.staticTexts["7 TP"].exists, "3 on a 1W6+4 is 7 TP")
        captureScreenshot(app, named: "42-fumble-self-injury")

        let takeDamage = app.buttons["combat.execution.takeDamage"]
        XCTAssertTrue(app.scrollUntilHittable(takeDamage), "No way to the take-damage screen")
        takeDamage.tap()

        let formula = app.descendants(matching: .any)["combat.takeDamage.formula"]
        XCTAssertTrue(
            formula.waitForExistence(timeout: UITest.timeout),
            "The take-damage screen did not open"
        )
        XCTAssertTrue(formula.staticTexts["7"].exists, "The TP did not arrive prefilled")
        XCTAssertTrue(
            formula.staticTexts["Patzer: Selbst verletzt"].exists,
            "The calculation does not say where the TP came from"
        )
        // The armour gets its own row, which is the whole reason the figure is
        // handed over rather than written to LP on the fumble screen. The
        // seeded hero has no *equipped* armour — `Armor.isEquipped` defaults to
        // false and neither the import nor `UITestSeed` sets it, it is the
        // preparation screen's question and a resumed fight skips that — so RS
        // is 0 here and all 7 TP get through. `TakeDamageFlowTests` covers the
        // subtraction itself.
        XCTAssertTrue(formula.staticTexts["RS"].exists, "The armour has no row in the calculation")
        XCTAssertTrue(formula.staticTexts["7 LP"].exists, "7 TP less RS 0 is 7 LP")
    }

    // MARK: - Stolpern

    /// "Nächste Handlung um –2 erschwert" used to be prose on a panel, and prose
    /// a player has to remember for exactly one roll is prose nobody applies.
    /// The −2 is a modifier line now, so it appears in the calculation of the
    /// next roll — and, because the roll that pays it consumes it, in no other.
    @MainActor
    func testStolpernCostsTheNextRollTwoAndOnlyTheNext() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.stumbleScript)

        rollTheTable(app, expecting: "Stolpern")

        let writes = app.descendants(matching: .any)["combat.fumble.writes"]
        XCTAssertTrue(
            writes.waitForExistence(timeout: UITest.timeout),
            "The screen did not report the Stolpern it wrote"
        )
        captureScreenshot(app, named: "43-fumble-stolpern")

        backToRoot(app)

        // --- The next parry names it and pays the −2.
        app.buttons["combat.parry"].tap()
        let firstCalculation = app.descendants(matching: .any)["combat.execution.breakdown"]
        XCTAssertTrue(firstCalculation.waitForExistence(timeout: UITest.timeout), "No parry calculation")
        XCTAssertTrue(
            firstCalculation.staticTexts["Stolpern (Patzer)"].exists,
            "The next roll does not name the Stolpern"
        )
        captureScreenshot(app, named: "44-fumble-stolpern-next-roll")

        backFromParryExecution(app)

        // --- And the one after it does not: the roll above consumed it.
        app.buttons["combat.parry"].tap()
        let secondCalculation = app.descendants(matching: .any)["combat.execution.breakdown"]
        XCTAssertTrue(secondCalculation.waitForExistence(timeout: UITest.timeout), "No second parry calculation")
        XCTAssertFalse(
            secondCalculation.staticTexts["Stolpern (Patzer)"].exists,
            "The Stolpern was charged twice"
        )
    }

    // MARK: - Waffe beschädigt

    /// "Alle Proben auf AT und PA um –2 erschwert, bis sie repariert wird."
    /// Unlike the Stolpern, this one does *not* expire: the −2 is still on the
    /// next attack, and the loadout picker says which weapon is carrying it.
    @MainActor
    func testADamagedWeaponCostsEveryRollUntilItIsRepaired() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.damagedScript)

        rollTheTable(app, expecting: "Waffe beschädigt")

        let writes = app.descendants(matching: .any)["combat.fumble.writes"]
        XCTAssertTrue(
            writes.waitForExistence(timeout: UITest.timeout),
            "The screen did not report the damage it wrote"
        )
        XCTAssertTrue(
            writes.staticTexts["Langschwert beschädigt"].exists,
            "The write should name the weapon the parry was made with"
        )
        captureScreenshot(app, named: "45-fumble-weapon-damaged")

        backToRoot(app)

        // --- The next attack pays for it.
        goToMeleeAnnouncement(app)
        let weiter = app.button(containing: "Weiter")
        XCTAssertTrue(app.scrollUntilHittable(weiter), "Could not reach Weiter")
        weiter.tap()

        let calculation = app.descendants(matching: .any)["combat.execution.breakdown"]
        XCTAssertTrue(calculation.waitForExistence(timeout: UITest.timeout), "No attack calculation")
        XCTAssertTrue(
            calculation.staticTexts["Langschwert beschädigt"].exists,
            "The attack does not name the damaged weapon"
        )
        XCTAssertTrue(calculation.staticTexts["-2"].exists, "A damaged weapon costs 2")

        // --- And the loadout picker marks it, which is where the player picks
        // what to fight with and so the one place the badge has to be. Back from
        // an attack roll is the weapon list, and back from that is the root.
        app.buttons["combat.back"].tap()
        XCTAssertTrue(
            app.buttons["combat.weaponRow.Langschwert"].waitForExistence(timeout: UITest.timeout),
            "Back from the attack roll should land on the weapon list"
        )
        app.buttons["combat.back"].tap()
        XCTAssertTrue(
            app.buttons["combat.parry"].waitForExistence(timeout: UITest.timeout),
            "Back from the weapon list should land on the combat root"
        )

        let changeLoadout = app.button(containing: "Ausrüstung wechseln")
        XCTAssertTrue(app.scrollUntilHittable(changeLoadout), "Could not reach the loadout screen")
        changeLoadout.tap()

        let row = app.buttons["combat.loadout.Langschwert"]
        XCTAssertTrue(row.waitForExistence(timeout: UITest.timeout), "The loadout picker did not open")
        XCTAssertTrue(
            row.label.contains("Beschädigt"),
            "The loadout row does not mark the damaged weapon: \(row.label)"
        )
        captureScreenshot(app, named: "46-fumble-damaged-loadout-badge")
    }

    // MARK: - Navigation

    /// Combat root → Parieren → roll → confirmed Patzer → Patzertabelle.
    @MainActor
    private func rollTheTable(_ app: XCUIApplication, expecting title: String) {
        let parry = app.buttons["combat.parry"]
        XCTAssertTrue(parry.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        parry.tap()

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Parry roll screen not shown")
        diceBox.tap()

        let toFumble = app.button(containing: "Patzer")
        XCTAssertTrue(
            toFumble.waitForExistence(timeout: UITest.timeout),
            "The scripted 20 + 20 did not confirm a Patzer"
        )
        XCTAssertTrue(app.scrollUntilHittable(toFumble), "Could not reach the Patzer button")
        toFumble.tap()

        let rollTable = app.button(containing: "Patzertabelle")
        XCTAssertTrue(rollTable.waitForExistence(timeout: UITest.timeout), "The fumble choice was not offered")
        rollTable.tap()

        let panel = app.descendants(matching: .any)["combat.fumbleEffectPanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: UITest.timeout), "No effect panel after the table roll")
        XCTAssertTrue(panel.staticTexts[title].exists, "The scripted 2W6 did not land on \"\(title)\"")
    }

    /// Opens the result's own check and rolls it, then closes the modal — the
    /// check is dismissed deliberately (a Schip reroll is available until it is),
    /// and leaving it open would make every later assertion meaningless.
    @MainActor
    private func rollProbe(_ app: XCUIApplication) {
        let probe = app.buttons["combat.fumble.rollProbe"]
        XCTAssertTrue(probe.waitForExistence(timeout: UITest.timeout), "No probe button on the panel")
        XCTAssertTrue(app.scrollUntilHittable(probe), "Could not reach the probe button")
        XCTAssertTrue(
            probe.label.contains("Körperbeherrschung"),
            "The Sturz should roll Körperbeherrschung: \(probe.label)"
        )
        probe.tap()

        let die = app.descendants(matching: .any)["skillCheck.die.0"]
        XCTAssertTrue(die.waitForExistence(timeout: UITest.timeout), "Probe dice not shown")
        die.tap()

        let confirm = app.buttons["skillCheck.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: UITest.timeout), "Probe confirm missing")
        confirm.tap()
        XCTAssertTrue(die.waitForNonExistence(timeout: UITest.timeout), "Probe modal did not close")
    }

    /// The resolved fumble screen back to the combat root.
    @MainActor
    private func backToRoot(_ app: XCUIApplication) {
        let newAction = app.buttons["combat.execution.newAction.miss"]
        XCTAssertTrue(app.scrollUntilHittable(newAction), "No way back to the combat root")
        newAction.tap()
        XCTAssertTrue(
            app.buttons["combat.parry"].waitForExistence(timeout: UITest.timeout),
            "Combat root not shown"
        )
    }

    /// A parry roll back to the root: the execution screen's back button lands on
    /// the weapon list, whose own back button lands on the root.
    @MainActor
    private func backFromParryExecution(_ app: XCUIApplication) {
        app.buttons["combat.back"].tap()
        XCTAssertTrue(
            app.buttons["combat.weaponRow.Langschwert"].waitForExistence(timeout: UITest.timeout),
            "Back from the parry roll should land on the weapon list"
        )
        app.buttons["combat.back"].tap()
        XCTAssertTrue(
            app.buttons["combat.parry"].waitForExistence(timeout: UITest.timeout),
            "Back from the weapon list should land on the combat root"
        )
    }

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
