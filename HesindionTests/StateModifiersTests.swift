import XCTest
import SwiftData
@testable import Hesindion

final class StateModifiersTests: XCTestCase {
    private func makeHero() -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self,
            configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        return hero
    }

    func testFurchtPenaltyAppliesToTalentChecks() {
        let hero = makeHero(); hero.setStateLevel("furcht", level: 2)
        let lines = ModifierEngine.shared.evaluate(context: ModifierContext(hero: hero, domain: .talentCheck))
        XCTAssertTrue(lines.contains { $0.value == -2 })
    }

    func testZustaendeStackAdditively() {
        let hero = makeHero()
        hero.setStateLevel("furcht", level: 1)
        hero.setStateLevel("verwirrung", level: 2)
        let total = ModifierEngine.shared.totalModifier(context: ModifierContext(hero: hero, domain: .talentCheck))
        XCTAssertEqual(total, -3)
    }

    func testZustandPenaltyCappedAtMinusFive() {
        let hero = makeHero()
        hero.setStateLevel("furcht", level: 4)
        hero.setStateLevel("verwirrung", level: 4)   // raw -8
        let total = ModifierEngine.shared.totalModifier(context: ModifierContext(hero: hero, domain: .talentCheck))
        XCTAssertEqual(total, -5, "Zustand penalties cap at -5")
    }

    func testCapDoesNotClampNonZustandModifiers() {
        // A combat bonus (e.g. schip defense +4) must survive alongside capped zustände.
        let hero = makeHero()
        hero.setStateLevel("furcht", level: 4)
        hero.setStateLevel("verwirrung", level: 4)
        var ctx = ModifierContext(hero: hero, domain: .meleeDodge)
        ctx.schipDefenseBoost = true
        let total = ModifierEngine.shared.totalModifier(context: ctx)
        XCTAssertEqual(total, -5 + 4)
    }

    func testSchipIgnoreZustandRemovesPenalty() {
        let hero = makeHero(); hero.setStateLevel("furcht", level: 3)
        var ctx = ModifierContext(hero: hero, domain: .talentCheck)
        ctx.schipIgnoreZustand = true
        XCTAssertEqual(ModifierEngine.shared.totalModifier(context: ctx), 0)
    }

    func testLiegendOnlyAffectsCombatDomains() {
        let hero = makeHero(); hero.setStateLevel("liegend", level: 1)
        let talent = ModifierEngine.shared.totalModifier(context: ModifierContext(hero: hero, domain: .talentCheck))
        let attack = ModifierEngine.shared.totalModifier(context: ModifierContext(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(talent, 0)
        XCTAssertEqual(attack, -4)
    }

    func testLiegendDefensePenaltyIsMinusTwo() {
        let hero = makeHero(); hero.setStateLevel("liegend", level: 1)
        let parry = ModifierEngine.shared.totalModifier(context: ModifierContext(hero: hero, domain: .meleeParry))
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
        let lines = ModifierEngine.shared.evaluate(context: ModifierContext(hero: hero, domain: .talentCheck))
        // Exactly one Schmerz-sourced line, value -2, label unchanged (source.schmerz + roman).
        let schmerzLines = lines.filter { $0.source.hasPrefix(L("source.schmerz")) }
        XCTAssertEqual(schmerzLines.count, 1, "Schmerz must not be double-counted")
        XCTAssertEqual(schmerzLines.first?.value, -2)
        XCTAssertEqual(schmerzLines.first?.source, L("source.schmerz") + " II")
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

        var mctx = ModifierContext(hero: hero, domain: .meleeAttack)
        mctx.schipIgnoreZustand = true
        let lines = ModifierEngine.shared.evaluate(context: mctx)
        let encumbranceLines = lines.filter { $0.source == L("source.belastung") }
        XCTAssertEqual(encumbranceLines.count, 1, "Belastung must survive schipIgnoreZustand")
        XCTAssertEqual(encumbranceLines.first?.value, -hero.effectiveBE)
    }

    func testEingeengtStatusDrivesBeengtePenaltyWithoutDoubleCount() {
        // Combat re-wires Beengte Umgebung onto the `eingeengt` status: building a melee
        // ModifierContext with `beengteUmgebung = hero.hasState("eingeengt")` must produce
        // the weapon-length penalty line, while StateModifiers (mechanic .eingeengt) emits
        // NO separate line — so the penalty is counted exactly once.
        let hero = makeHero()
        hero.setStateLevel("eingeengt", level: 1)
        XCTAssertTrue(hero.hasState("eingeengt"))

        var ctx = ModifierContext(hero: hero, domain: .meleeAttack)
        ctx.beengteUmgebung = hero.hasState("eingeengt")   // exactly how the combat views wire it
        let lines = ModifierEngine.shared.evaluate(context: ctx)

        // The Beengte-Umgebung weapon-length line fires (default reach "Mittel" ⇒ −4).
        let beengteLines = lines.filter { $0.source == L("beengteUmgebung") }
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
            context: ModifierContext(hero: hero, domain: .spellCasting))
        let entLine = penaltyLines.first { $0.source.hasPrefix(L("state.entrueckung.name")) }
        XCTAssertNotNil(entLine, "Entrückung line must be present when not gottgefällig")
        XCTAssertEqual(entLine?.value, -3, "Entrückung III ⇒ -3 by default")
        XCTAssertEqual(
            ModifierEngine.shared.totalModifier(
                context: ModifierContext(hero: hero, domain: .spellCasting)),
            -3)

        // Gottgefällige Probe: flips to a bonus of max(0, level-1) = +2.
        var bonusCtx = ModifierContext(hero: hero, domain: .spellCasting)
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
        var ctx = ModifierContext(hero: hero, domain: .spellCasting)
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
        let lines = ModifierEngine.shared.evaluate(context: ModifierContext(hero: hero, domain: .talentCheck))
        let capLines = lines.filter { $0.source == L("source.zustandCap") }
        XCTAssertEqual(capLines.count, 1, "cap correction line must be present when the cap binds")
        XCTAssertEqual(capLines.first?.isZustand, false, "cap correction must not itself count as a Zustand")
    }
}
