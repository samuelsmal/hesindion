import XCTest
import SwiftData
@testable import Hesindion

final class StateModifiersTests: XCTestCase {
    private func makeHero() -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self, MeleeWeapon.self,
            configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        return hero
    }

    func testFurchtPenaltyAppliesToTalentChecks() {
        let hero = makeHero(); hero.setStateLevel("furcht", level: 2)
        let lines = ModifierEngine.shared.evaluate(context: Situation(hero: hero, domain: .talentCheck))
        XCTAssertTrue(lines.contains { $0.value == -2 })
    }

    func testZustaendeStackAdditively() {
        let hero = makeHero()
        hero.setStateLevel("furcht", level: 1)
        hero.setStateLevel("verwirrung", level: 2)
        let total = ModifierEngine.shared.totalModifier(context: Situation(hero: hero, domain: .talentCheck))
        XCTAssertEqual(total, -3)
    }

    func testZustandPenaltyCappedAtMinusFive() {
        let hero = makeHero()
        hero.setStateLevel("furcht", level: 4)
        hero.setStateLevel("verwirrung", level: 4)   // raw -8
        let total = ModifierEngine.shared.totalModifier(context: Situation(hero: hero, domain: .talentCheck))
        XCTAssertEqual(total, -5, "Zustand penalties cap at -5")
    }

    func testCapDoesNotClampNonZustandModifiers() {
        // A combat bonus (e.g. schip defense +4) must survive alongside capped zustände.
        let hero = makeHero()
        hero.setStateLevel("furcht", level: 4)
        hero.setStateLevel("verwirrung", level: 4)
        var ctx = Situation(hero: hero, domain: .meleeDodge)
        ctx.round.schipDefenseBoost = true
        let total = ModifierEngine.shared.totalModifier(context: ctx)
        XCTAssertEqual(total, -5 + 4)
    }

    func testSchipIgnoreZustandRemovesPenalty() {
        let hero = makeHero(); hero.setStateLevel("furcht", level: 3)
        var ctx = Situation(hero: hero, domain: .talentCheck)
        ctx.round.schipIgnoreZustand = true
        XCTAssertEqual(ModifierEngine.shared.totalModifier(context: ctx), 0)
    }

    func testLiegendOnlyAffectsCombatDomains() {
        // A Mittel weapon keeps this test about Liegend alone: bare hands are
        // Kurz now (GRW_reichweite), which would add its own −2 against the
        // default Mittel opponent and confuse the assertion below.
        let hero = makeHero()
        hero.meleeWeapons = [MeleeWeapon(name: "Säbel", combatTechniqueId: "CT_12", damage: "1W6+3", at: 12, pa: 8, reach: "Mittel", weight: 1.5)]
        hero.selectedWeaponName = "Säbel"
        hero.setStateLevel("liegend", level: 1)
        let talent = ModifierEngine.shared.totalModifier(context: Situation(hero: hero, domain: .talentCheck))
        let attack = ModifierEngine.shared.totalModifier(context: Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(talent, 0)
        XCTAssertEqual(attack, -4)
    }

    func testLiegendDefensePenaltyIsMinusTwo() {
        let hero = makeHero(); hero.setStateLevel("liegend", level: 1)
        let parry = ModifierEngine.shared.totalModifier(context: Situation(hero: hero, domain: .meleeParry))
        XCTAssertEqual(parry, -2)
    }

    func testSchmerzStillAppliesViaCatalogPath() {
        let hero = makeHero()
        // maxLP 20, current 10 -> schmerzLevel 2 (<=15, <=10, not <=5) -> effectiveSchmerzLevel 2
        hero.derivedValues = DerivedValues(
            lebensenergie: LifeEnergyValue(base: 20, bonus: 0, purchased: 0, max: 20, current: 10),
            astralenergie: nil, karmaenergie: nil,
            seelenkraft: ResourceValue(base: 0, bonus: 0, max: 0),
            zaehigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            ausweichen: ComputedValue(value: 0, bonus: 0, max: 0),
            initiative: ComputedValue(value: 0, bonus: 0, max: 0),
            geschwindigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            wundschwelle: ComputedValue(value: 0, bonus: 0, max: 0),
            schicksalspunkte: MutableResourceValue(current: 0, bonus: 0, max: 0))
        XCTAssertEqual(hero.effectiveSchmerzLevel, 2)
        XCTAssertEqual(hero.schmerzPenalty, -2)
        let lines = ModifierEngine.shared.evaluate(context: Situation(hero: hero, domain: .talentCheck))
        // Exactly one Schmerz-sourced line, value -2, label unchanged (source.schmerz + roman).
        let schmerzLines = lines.filter { $0.source.hasPrefix(L("source.schmerz")) }
        XCTAssertEqual(schmerzLines.count, 1, "Schmerz must not be double-counted")
        XCTAssertEqual(schmerzLines.first?.value, -2)
        XCTAssertEqual(schmerzLines.first?.source, L("source.schmerz") + " II")
    }

    // MARK: - Zustände outside a fight

    /// The owner's question: are Schmerz and the other Zustände applied to rolls
    /// outside battle too — a plain Selbstbeherrschung probe, say?
    ///
    /// They are, and this pins it. The Zustand definitions cover
    /// `Set(CheckDomain.allCases)`, so `.talentCheck` is in scope like every
    /// other domain, and `TalentProbeModal` builds its lines from the same
    /// `ModifierEngine` the combat screens use. A hero with Schmerz II and
    /// Betäubung I rolls Selbstbeherrschung at −3, in two named rows, with no
    /// fight anywhere near them.
    func testZustaendeApplyToAPlainTalentCheckWithNoFightRunning() {
        let hero = makeHero()
        // Schmerz II is derived from the LP total: 10 of 20 is at or below half.
        hero.derivedValues = makeDerivedValues(maxLP: 20, currentLP: 10)
        hero.setStateLevel("betaeubung", level: 1)
        XCTAssertNil(hero.activeCombatId, "precondition: no fight is running")
        XCTAssertEqual(hero.effectiveSchmerzLevel, 2)

        var context = Situation(hero: hero, domain: .talentCheck)
        context.talentId = Talent.selbstbeherrschungRuleId
        let lines = ModifierEngine.shared.evaluate(context: context)

        XCTAssertEqual(
            lines.first { $0.source == L("source.schmerz") + " II" }?.value, -2,
            "Schmerz II is −2 on a Selbstbeherrschung probe as much as on a parry")
        XCTAssertEqual(
            lines.first { $0.source == L("state.betaeubung.name") + " I" }?.value, -1,
            "Betäubung I is −1 on the same roll")
        XCTAssertEqual(ModifierEngine.shared.totalModifier(context: context), -3)
    }

    /// …and the DSA −5 Zustand cap is the same cap out of combat. Schmerz IV
    /// plus Betäubung IV is −8 raw and −5 on the roll.
    func testTheZustandCapAppliesToAPlainTalentCheckToo() {
        let hero = makeHero()
        // 1 of 40 LP: at or below an eighth → Schmerz IV.
        hero.derivedValues = makeDerivedValues(maxLP: 40, currentLP: 1)
        hero.setStateLevel("betaeubung", level: 4)
        XCTAssertEqual(hero.effectiveSchmerzLevel, 4)

        var context = Situation(hero: hero, domain: .talentCheck)
        context.talentId = Talent.selbstbeherrschungRuleId
        XCTAssertEqual(ModifierEngine.shared.totalModifier(context: context), -5)
    }

    /// The other half of the same question. A Patzer's "1 Stufe Schmerz für 3
    /// Kampfrunden" rides on the combat-session block, and a hero with no fight
    /// has no round to count against — so the level a Patzertabelle added does
    /// **not** follow them out of the fight and onto a Selbstbeherrschung probe
    /// at the campfire.
    func testTheTemporaryPatzerSchmerzNeedsARunningFight() {
        let hero = makeHero()
        hero.activeCombatId = UUID()
        hero.activeCombatRound = 1
        hero.addTemporarySchmerz(rolledInRound: 1)

        var context = Situation(hero: hero, domain: .talentCheck)
        context.talentId = Talent.selbstbeherrschungRuleId
        XCTAssertEqual(
            ModifierEngine.shared.totalModifier(context: context), -1,
            "precondition: in the fight the Patzer's level is on the roll")

        hero.activeCombatId = nil
        XCTAssertEqual(hero.effectiveSchmerzLevel, 0)
        XCTAssertTrue(
            ModifierEngine.shared.evaluate(context: context)
                .allSatisfy { $0.source != L("source.schmerz") + " I" },
            "no fight, no temporary Schmerz")
        XCTAssertEqual(ModifierEngine.shared.totalModifier(context: context), 0)
    }

    private func makeDerivedValues(maxLP: Int, currentLP: Int) -> DerivedValues {
        DerivedValues(
            lebensenergie: LifeEnergyValue(
                base: maxLP, bonus: 0, purchased: 0, max: maxLP, current: currentLP),
            astralenergie: nil, karmaenergie: nil,
            seelenkraft: ResourceValue(base: 0, bonus: 0, max: 0),
            zaehigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            ausweichen: ComputedValue(value: 0, bonus: 0, max: 0),
            initiative: ComputedValue(value: 0, bonus: 0, max: 0),
            geschwindigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            wundschwelle: ComputedValue(value: 0, bonus: 0, max: 0),
            schicksalspunkte: MutableResourceValue(current: 0, bonus: 0, max: 0))
    }

    func testSchipIgnoreZustandDoesNotSuppressEncumbrance() {
        // Belastung is gear-derived: a "Zustand ignorieren" Schip must NOT will it away.
        let schema = Schema([
            Hero.self, HeroStateEntry.self, DerivedValues.self, Armor.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        hero.armors.append(Armor(name: "Plattenpanzer", protectionValue: 8, encumbrance: 4, weight: 20, isEquipped: true))
        XCTAssertEqual(hero.effectiveBE, 4, "precondition: effectiveBE > 0")

        var mctx = Situation(hero: hero, domain: .meleeAttack)
        mctx.round.schipIgnoreZustand = true
        let lines = ModifierEngine.shared.evaluate(context: mctx)
        let encumbranceLines = lines.filter { $0.source == L("source.belastung") }
        XCTAssertEqual(encumbranceLines.count, 1, "Belastung must survive schipIgnoreZustand")
        XCTAssertEqual(encumbranceLines.first?.value, -hero.effectiveBE)
    }

    func testEingeengtStatusDrivesBeengtePenaltyWithoutDoubleCount() {
        // Combat re-wires Beengte Umgebung onto the `eingeengt` status: building a melee
        // Situation with `round.beengteUmgebung = hero.hasState("eingeengt")` must produce
        // the weapon-length penalty line, while StateModifiers (mechanic .eingeengt) emits
        // NO separate line — so the penalty is counted exactly once.
        let hero = makeHero()
        hero.meleeWeapons = [MeleeWeapon(name: "Säbel", combatTechniqueId: "CT_12", damage: "1W6+3", at: 12, pa: 8, reach: "Mittel", weight: 1.5)]
        hero.selectedWeaponName = "Säbel"
        hero.setStateLevel("eingeengt", level: 1)
        XCTAssertTrue(hero.hasState("eingeengt"))

        var ctx = Situation(hero: hero, domain: .meleeAttack)
        ctx.round.beengteUmgebung = hero.hasState("eingeengt")   // exactly how the combat views wire it
        let lines = ModifierEngine.shared.evaluate(context: ctx)

        // The Beengte-Umgebung line fires once, from the catalog (Mittel ⇒ −4).
        let beengteLines = lines.filter { $0.ruleId == "GRW_beengteUmgebung" }
        XCTAssertEqual(beengteLines.count, 1, "Beengte Umgebung penalty must fire exactly once")
        XCTAssertEqual(beengteLines.first?.value, -4)

        // No line is tagged as a Zustand and none carries an "eingeengt"-derived penalty:
        // the .eingeengt mechanic intentionally emits nothing in StateModifiers.
        XCTAssertEqual(lines.filter { $0.isZustand }.count, 0, "eingeengt must not be double-counted as a Zustand line")
        XCTAssertEqual(lines.count, 1, "only the single Beengte-Umgebung line should be present")
    }

    func testEntrueckungGottgefaelligFlipsSign() {
        let hero = makeHero()
        hero.setStateLevel("entrueckung", level: 3)

        // Default (gottgefaellig == false): Entrückung III applies as a -3 penalty.
        let penaltyLines = ModifierEngine.shared.evaluate(
            context: Situation(hero: hero, domain: .spellCasting))
        let entLine = penaltyLines.first { $0.source.hasPrefix(L("state.entrueckung.name")) }
        XCTAssertNotNil(entLine, "Entrückung line must be present when not gottgefällig")
        XCTAssertEqual(entLine?.value, -3, "Entrückung III ⇒ -3 by default")
        XCTAssertEqual(
            ModifierEngine.shared.totalModifier(
                context: Situation(hero: hero, domain: .spellCasting)),
            -3)

        // Gottgefällige Probe: flips to a bonus of max(0, level-1) = +2.
        var bonusCtx = Situation(hero: hero, domain: .spellCasting)
        bonusCtx.gottgefaellig = true
        let bonusLines = ModifierEngine.shared.evaluate(context: bonusCtx)
        let bonusLine = bonusLines.first { $0.source.hasPrefix(L("state.entrueckung.name")) }
        XCTAssertNotNil(bonusLine, "Entrückung line must be present when gottgefällig (level 3)")
        XCTAssertEqual(bonusLine?.value, 2, "gottgefällig ⇒ max(0, 3-1) = +2")
        XCTAssertEqual(ModifierEngine.shared.totalModifier(context: bonusCtx), 2)
    }

    func testEntrueckungGottgefaelligLevelOneEmitsNoLine() {
        let hero = makeHero()
        hero.setStateLevel("entrueckung", level: 1)
        var ctx = Situation(hero: hero, domain: .spellCasting)
        ctx.gottgefaellig = true   // max(0, 1-1) == 0 ⇒ no line
        let lines = ModifierEngine.shared.evaluate(context: ctx)
        XCTAssertFalse(
            lines.contains { $0.source.hasPrefix(L("state.entrueckung.name")) },
            "gottgefällig Entrückung I yields 0 ⇒ no modifier line")
    }

    func testCapCorrectionLineIsTaggedNonZustand() {
        let hero = makeHero()
        hero.setStateLevel("furcht", level: 4)
        hero.setStateLevel("verwirrung", level: 4)   // raw -8, cap binds at -5
        let lines = ModifierEngine.shared.evaluate(context: Situation(hero: hero, domain: .talentCheck))
        let capLines = lines.filter { $0.source == L("source.zustandCap") }
        XCTAssertEqual(capLines.count, 1, "cap correction line must be present when the cap binds")
        XCTAssertEqual(capLines.first?.isZustand, false, "cap correction must not itself count as a Zustand")
    }
}
