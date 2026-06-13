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
}
