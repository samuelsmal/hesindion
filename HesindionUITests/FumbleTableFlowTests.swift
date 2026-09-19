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
    /// next one. The 7 that follows is the parry that actually pays it — an
    /// ordinary roll, neither a 1 nor a 20, so it settles without a confirmation
    /// and without opening a branch of its own.
    private static let stumbleScript = "20,20,4,4,7,7"

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
        continueDefense(app)

        let paCalculation = app.descendants(matching: .any)["combat.execution.breakdown"]
        XCTAssertTrue(paCalculation.waitForExistence(timeout: UITest.timeout), "No parry calculation")
        assertRow(paCalculation, source: "Liegend", value: "-2",
                  "Liegend should cost the parry 2")

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
        assertRow(atCalculation, source: "Liegend", value: "-4",
                  "Liegend should cost the attack 4")
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

        // --- And the opponent's blow, which landed all the same.
        //
        // This Patzer was rolled on a *Parade*: the GM ruled the defence failed
        // before the table was even reached, so the hero takes their own weapon's
        // damage *and* the hit they failed to stop. One prefilled entry can only
        // hold one of the two, and the incoming hit used to be the one that
        // silently disappeared.
        let confirm = app.buttons["combat.takeDamage.confirm"]
        XCTAssertTrue(app.scrollUntilHittable(confirm), "No confirm on the take-damage screen")
        confirm.tap()

        let incoming = app.buttons["combat.takeDamage.incomingHit"]
        XCTAssertTrue(
            incoming.waitForExistence(timeout: UITest.timeout),
            "A fumbled parry ended at the combat root with the opponent's blow unaccounted for"
        )
        XCTAssertFalse(
            app.buttons["combat.takeDamage.newAction"].exists,
            "\"Neue Aktion\" still offers the way out that drops the incoming hit"
        )
        XCTAssertTrue(app.scrollUntilHittable(incoming), "Could not reach the opponent's-blow button")
        incoming.tap()

        // A second entry, empty and unconfirmed — the same `CombatStep` case as
        // the first, so this is also what proves the screen's `@State` was reset
        // rather than carried over already settled.
        let second = app.descendants(matching: .any)["combat.takeDamage.formula"]
        XCTAssertTrue(
            second.waitForExistence(timeout: UITest.timeout),
            "The second take-damage entry did not open"
        )
        XCTAssertTrue(
            second.staticTexts["Treffer des Gegners"].exists,
            "The second entry does not say whose blow it is"
        )
        XCTAssertTrue(second.staticTexts["0 LP"].exists, "The second entry should start empty")
        XCTAssertTrue(
            app.buttons["combat.takeDamage.confirm"].waitForExistence(timeout: UITest.timeout),
            "The second entry opened already confirmed"
        )
        captureScreenshot(app, named: "47-fumble-parry-incoming-hit")
    }

    // MARK: - Stolpern

    /// "Nächste Handlung um –2 erschwert" used to be prose on a panel, and prose
    /// a player has to remember for exactly one roll is prose nobody applies.
    /// The −2 is a modifier line now, so it appears in the calculation of the
    /// next roll — and, because the *roll* that pays it consumes it, in no other.
    ///
    /// The roll, not the screen. Opening Parieren, reading the −2 and backing out
    /// again rolls nothing, so it must cost nothing: the effect used to be spent
    /// in `onAppear`, which let a player look at the penalty and walk away from
    /// it. So this goes through the screen twice before it rolls once.
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

        // --- (a) The next parry names it and shows the −2 …
        app.buttons["combat.parry"].tap()
        continueDefense(app)
        assertStumbleRow(app, present: true, "The next roll does not name the Stolpern")
        captureScreenshot(app, named: "44-fumble-stolpern-next-roll")

        // … and backing out without rolling does not spend it.
        backFromParryExecution(app)

        app.buttons["combat.parry"].tap()
        continueDefense(app)
        assertStumbleRow(
            app, present: true,
            "Opening the roll screen and leaving it spent the Stolpern — nothing was rolled")

        // --- (b) This time the roll is actually made, which is what pays for it.
        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "No dice on the parry screen")
        diceBox.tap()
        // Both a successful and a failed parry end in a "Neue Aktion" of this
        // name — the failed one under "Schaden nehmen" — so it is the settled
        // roll, whichever way the scripted 7 fell against the modified PA.
        XCTAssertTrue(
            app.buttons["combat.execution.newAction.miss"].waitForExistence(timeout: UITest.timeout),
            "The scripted 7 did not settle the parry"
        )
        // The calculation still names it: the lines were built before the roll,
        // so a Schicksalspunkt reroll of this same parry would keep the −2.
        assertStumbleRow(
            app, present: true,
            "The roll that pays the −2 stopped showing it the moment it was spent")

        backFromParryExecution(app)

        // --- (c) And the one after it does not: the roll above consumed it.
        app.buttons["combat.parry"].tap()
        continueDefense(app)
        assertStumbleRow(app, present: false, "The Stolpern was charged twice")
    }

    /// The Stolpern row of the parry calculation, by row rather than by loose
    /// text: a bare `staticTexts["-2"]` is satisfied by any −2 on the screen, and
    /// this screen has several (Liegend, Mehrfache Verteidigung, a damaged
    /// weapon), so it could pass while the Stolpern itself had gone.
    @MainActor
    private func assertStumbleRow(_ app: XCUIApplication, present: Bool, _ message: String) {
        let calculation = app.descendants(matching: .any)["combat.execution.breakdown"]
        XCTAssertTrue(calculation.waitForExistence(timeout: UITest.timeout), "No parry calculation")
        if present {
            assertRow(calculation, source: "Stolpern (Patzer)", value: "-2", message)
        } else {
            XCTAssertFalse(
                calculation.descendants(matching: .any)["combat.breakdown.row.Stolpern (Patzer)"].exists,
                message)
        }
    }

    /// One row of a calculation, asserted as a row: the label and the number in
    /// the same container. `staticTexts["-2"]` on the whole box is satisfied by
    /// *any* −2 in it — and a parry can carry several (Liegend, Mehrfache
    /// Verteidigung, a dented weapon, the Stolpern) — so it passed for a penalty
    /// that had moved to another line or gone entirely.
    @MainActor
    private func assertRow(
        _ box: XCUIElement, source: String, value: String, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let row = box.descendants(matching: .any)["combat.breakdown.row.\(source)"]
        XCTAssertTrue(
            row.waitForExistence(timeout: UITest.timeout),
            "\(message): no \"\(source)\" row in the calculation", file: file, line: line)
        XCTAssertTrue(
            row.staticTexts[value].exists,
            "\(message): the \"\(source)\" row does not say \(value)", file: file, line: line)
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

        // Result 4 prints the escape clause too — "Bei unzerstörbaren Waffen:
        // Waffe verloren" — so the screen asks before it dents anything, and
        // while the question is open it writes nothing at all. An ordinary
        // Langschwert is a "Nein", which is what leaves this test its subject.
        let breakable = app.buttons["combat.fumble.indestructible.no"]
        XCTAssertTrue(app.scrollUntilHittable(breakable), "No \"Nein\" on the indestructibility question")
        breakable.tap()

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
        assertRow(calculation, source: "Langschwert beschädigt", value: "-2",
                  "A damaged weapon should cost the attack 2")

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

    // MARK: - Nach dem Kampf

    /// A fight sets states and never takes them off again.
    ///
    /// The Sturz above is the clearest case: the check fails, Liegend is set,
    /// the fight ends — and the hero walks into the next scene still on the
    /// ground, because nothing in the flow ever cleared it and the player would
    /// have had to remember to open the hero sheet and swipe it away (owner
    /// request). "Kampf beenden" now stops on the way out and offers the list.
    @MainActor
    func testEndingTheFightOffersTheStatesItSet() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.fallScript)

        rollTheTable(app, expecting: "Sturz")
        rollProbe(app)
        backToRoot(app)

        XCTAssertTrue(
            app.descendants(matching: .any)["state.chip.liegend"]
                .waitForExistence(timeout: UITest.timeout),
            "precondition: the failed Sturz laid the hero out"
        )

        let endCombat = app.button(containing: "Kampf beenden")
        XCTAssertTrue(app.scrollUntilHittable(endCombat), "Could not reach the end-combat button")
        endCombat.tap()

        // --- The screen, with the state that is still running on it.
        let row = app.descendants(matching: .any)["combat.aftermath.row.liegend"]
        XCTAssertTrue(
            row.waitForExistence(timeout: UITest.timeout),
            "Ending the fight walked straight out with Liegend still set"
        )
        XCTAssertTrue(row.staticTexts["Liegend"].exists, "The row should name the state")
        captureScreenshot(app, named: "50-aftermath")

        // Liegend is a Status, so it is one button: off, and off again is back.
        let toggle = app.buttons["combat.aftermath.toggle.liegend"]
        XCTAssertTrue(app.scrollUntilHittable(toggle), "No control on the Liegend row")
        toggle.tap()
        XCTAssertTrue(
            row.staticTexts["entfernt"].waitForExistence(timeout: UITest.timeout),
            "The row does not say it was cleared"
        )
        captureScreenshot(app, named: "51-aftermath-cleared")

        let done = app.buttons["combat.aftermath.done"]
        XCTAssertTrue(app.scrollUntilHittable(done), "No \"Fertig\" on the aftermath screen")
        done.tap()

        // --- Out of the fight, and the hero is no longer on the ground.
        XCTAssertTrue(
            app.buttons["combat.parry"].waitForNonExistence(timeout: UITest.timeout),
            "\"Fertig\" did not leave the fight"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["state.chip.liegend"].exists,
            "Liegend survived the screen that exists to end it"
        )
        XCTAssertFalse(app.staticTexts["Liegend"].exists, "The hero sheet still lists Liegend")
    }

    /// And a fight that left nothing behind ends the way it always did: the
    /// button leaves, with no screen in between.
    @MainActor
    func testAFightThatLeftNothingBehindEndsStraightAway() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat")

        let endCombat = app.button(containing: "Kampf beenden")
        XCTAssertTrue(app.scrollUntilHittable(endCombat), "Could not reach the end-combat button")
        endCombat.tap()

        XCTAssertTrue(
            app.buttons["combat.parry"].waitForNonExistence(timeout: UITest.timeout),
            "The end-combat button did not leave the fight"
        )
        XCTAssertFalse(
            app.buttons["combat.aftermath.done"].exists,
            "An empty \"Nach dem Kampf\" only asks the player to confirm nothing"
        )
    }

    // MARK: - Unzerstörbare Waffen

    /// AT 20, confirmation 20 → confirmed Patzer on the attack; 2W6 1+1 = 2 →
    /// "Waffe zerstört", the one result the escape clause is about.
    private static let destroyedScript = "20,20,1,1"

    /// "Certain weapons cannot be destroyed. The wizard's staff for example.
    /// Let's confirm with the user; if the user says it's indestructible it
    /// should be treated as a rolled 5." (owner report)
    ///
    /// The table has always printed the clause — "Bei unzerstörbaren Waffen:
    /// Waffe verloren" — and the app has always ignored it, because nothing in
    /// an Optolith export says which weapons it is about. So the screen asks,
    /// and until it is answered it writes nothing and offers no way on.
    @MainActor
    func testAnIndestructibleWeaponIsDroppedRatherThanDestroyed() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.destroyedScript)

        rollTheAttackTable(app, expecting: "Waffe zerstört")

        // Nothing yet: the result is a question first.
        XCTAssertFalse(
            app.buttons["combat.execution.newAction.miss"].exists,
            "The screen offered a way out while the question was still open"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["combat.fumble.writes"].exists,
            "The weapon was destroyed before anybody was asked"
        )

        let question = app.descendants(matching: .any)["combat.fumble.indestructible"]
        XCTAssertTrue(question.waitForExistence(timeout: UITest.timeout), "The question was not asked")
        XCTAssertTrue(
            question.staticTexts["Ist Langschwert unzerstörbar?"].exists,
            "The question should name the thing in the hand"
        )
        captureScreenshot(app, named: "48-fumble-indestructible-question")

        let yes = app.buttons["combat.fumble.indestructible.yes"]
        XCTAssertTrue(app.scrollUntilHittable(yes), "No \"Ja\" on the question")
        yes.tap()

        // --- It became the table's own result 5.
        let panel = app.descendants(matching: .any)["combat.fumbleEffectPanel"]
        XCTAssertTrue(
            panel.staticTexts["Waffe verloren"].waitForExistence(timeout: UITest.timeout),
            "A \"Ja\" should turn the 2 into the table's fifth result"
        )
        XCTAssertTrue(
            panel.staticTexts["Die Waffe ist zu Boden gefallen."].exists,
            "The applied result should carry result 5's own text, not result 2's"
        )
        // Both halves of the sentence: what was rolled, and what it became.
        XCTAssertTrue(
            app.descendants(matching: .any)["combat.fumble.indestructible.applied"]
                .waitForExistence(timeout: UITest.timeout),
            "The screen does not say why the result changed"
        )

        let writes = app.descendants(matching: .any)["combat.fumble.writes"]
        XCTAssertTrue(writes.waitForExistence(timeout: UITest.timeout), "The screen did not report what it wrote")
        XCTAssertTrue(writes.staticTexts["Langschwert abgelegt"].exists, "The weapon should leave the loadout")
        XCTAssertTrue(writes.staticTexts["Unzerstörbar"].exists, "The answer should be reported as remembered")
        captureScreenshot(app, named: "49-fumble-indestructible-applied")

        // --- And the answer outlives the fight: the hero settings screen is
        //     where it is taken back, beside the damaged equipment.
        let newAction = app.button(containing: "Neue Aktion")
        XCTAssertTrue(app.scrollUntilHittable(newAction), "No way back to the combat root")
        newAction.tap()

        let close = app.buttons["combat.close"]
        XCTAssertTrue(close.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        close.tap()

        let field = app.openCommandPalette()
        XCTAssertTrue(field.waitForExistence(timeout: UITest.timeout), "Command palette did not open")
        field.typeText("Einstellungen")
        let command = app.button(containing: "Einstellungen für")
        XCTAssertTrue(command.waitForExistence(timeout: UITest.timeout), "Settings command not offered")
        command.tap()

        let section = app.descendants(matching: .any)["heroSettings.indestructibleItems"]
        XCTAssertTrue(section.waitForExistence(timeout: UITest.timeout), "Hero settings did not open")
        XCTAssertTrue(app.scrollUntilHittable(section), "Could not reach the indestructible-equipment section")
        XCTAssertTrue(
            app.buttons["heroSettings.breakable.Langschwert"].exists,
            "The remembered answer has no way back"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["heroSettings.damagedItems"].exists,
            "A dropped weapon is not a dented one"
        )
    }

    /// The other answer. An ordinary Langschwert on a rolled 2 is gone for good,
    /// exactly as before this question existed.
    @MainActor
    func testAnOrdinaryWeaponIsStillDestroyed() {
        continueAfterFailure = false
        let app = UITest.launch(path: "combat", diceScript: Self.destroyedScript)

        rollTheAttackTable(app, expecting: "Waffe zerstört")

        let no = app.buttons["combat.fumble.indestructible.no"]
        XCTAssertTrue(app.scrollUntilHittable(no), "No \"Nein\" on the question")
        no.tap()

        let panel = app.descendants(matching: .any)["combat.fumbleEffectPanel"]
        XCTAssertTrue(
            panel.staticTexts["Waffe zerstört"].waitForExistence(timeout: UITest.timeout),
            "A \"Nein\" should leave the rolled result alone"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["combat.fumble.indestructible.applied"].exists,
            "Nothing was substituted"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["combat.fumble.indestructible"].exists,
            "The question should be gone once it is answered"
        )

        let writes = app.descendants(matching: .any)["combat.fumble.writes"]
        XCTAssertTrue(writes.waitForExistence(timeout: UITest.timeout), "The screen did not report what it wrote")
        XCTAssertTrue(writes.staticTexts["Langschwert abgelegt"].exists, "The weapon should leave the loadout")
        XCTAssertFalse(
            writes.staticTexts["Unzerstörbar"].exists,
            "A \"Nein\" is not remembered — the next Langschwert may be an ordinary one"
        )
    }

    // MARK: - Navigation

    /// Combat root → Angriff → announcement → roll → confirmed Patzer →
    /// Patzertabelle. The attack table, not the defence one: destroying the
    /// weapon is the attacker's own Patzer as much as the parrier's.
    @MainActor
    private func rollTheAttackTable(_ app: XCUIApplication, expecting title: String) {
        goToMeleeAnnouncement(app)

        let weiter = app.buttons["combat.announcement.continue"]
        XCTAssertTrue(app.scrollUntilHittable(weiter), "Could not reach Weiter")
        weiter.tap()

        let diceBox = app.otherElements["combat.execution.diceBox"]
        XCTAssertTrue(diceBox.waitForExistence(timeout: UITest.timeout), "Attack roll screen not shown")
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

    /// Combat root → Parieren → roll → confirmed Patzer → Patzertabelle.
    @MainActor
    private func rollTheTable(_ app: XCUIApplication, expecting title: String) {
        let parry = app.buttons["combat.parry"]
        XCTAssertTrue(parry.waitForExistence(timeout: UITest.timeout), "Combat root not shown")
        parry.tap()
        continueDefense(app)

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
