import XCTest
import SwiftData
@testable import Hesindion

/// The routing the combat root used to do inline when Parieren or Ausweichen
/// was tapped, now done once the defence screen's questions are answered.
@MainActor
final class CombatDefenseSetupTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        // The base values now come from the engine (`SheetValues`), which needs
        // real attributes and a KtW to compute from — GE 12 gives AW 6 (KW3:
        // ceil(GE/2)), MU/KK 14 give the "3 volle Punkte über 8" +2 bonus
        // (KW1/KW2) that the fixture numbers below are built around.
        hero.attributes = Attributes(mu: 14, kl: 8, inValue: 8, ch: 8, ff: 8, ge: 12, ko: 8, kk: 14)
        context.insert(hero)
    }

    override func tearDown() { context = nil; hero = nil }

    private func armWithSword() {
        // KtW 12 (Schwerter, leit GE/KK — KK 14 is the higher one here): AT 12 + 2
        // = 14, PA 6 + 2 = 8 (KW1/KW2), matching this file's original fixture
        // numbers now that they come from the engine instead of the stored `at`/`pa`.
        hero.combatTechniques.append(CombatTechnique(ruleId: "CT_12", name: "Schwerter", value: 12, at: 0, pa: 0))
        hero.meleeWeapons.append(MeleeWeapon(name: "Schwert", combatTechniqueId: "CT_12", damage: "1W6+4", at: 12, pa: 8, reach: "Mittel", weight: 1.6))
        hero.selectedWeaponName = "Schwert"
    }

    private func line(_ value: Int) -> ModifierLine { ModifierLine(value: value, source: "Test") }

    func testParryWithAWeaponRollsItsPAPlusTheLines() {
        armWithSword()
        let step = DefenseRoute.next(.parieren, hero: hero, size: .mittel, lines: [line(2)])
        if case .execution(let action, let name, let value, _, _, let lines, _, _, _, _) = step {
            XCTAssertEqual(action, .parieren)
            XCTAssertEqual(name, "Schwert")
            XCTAssertEqual(value, 10)
            XCTAssertEqual(lines?.count, 1)
        } else {
            XCTFail("expected .execution, got \(step.persistenceKey)")
        }
    }

    func testParryWithAShieldGoesToTheWeaponList() {
        armWithSword()
        hero.shields = [Shield(name: "Großschild", damage: "1W6+1", at: 6, pa: 11, reach: "Kurz", structurePoints: 30, weight: 6)]
        hero.selectedShieldName = "Großschild"
        let step = DefenseRoute.next(.parieren, hero: hero, size: .mittel, lines: [line(2)])
        if case .weaponSelection(let action) = step {
            XCTAssertEqual(action, .parieren)
        } else {
            XCTFail("expected .weaponSelection, got \(step.persistenceKey)")
        }
    }

    func testParryWithNoWeaponGoesToTheWeaponList() {
        let step = DefenseRoute.next(.parieren, hero: hero, size: .mittel, lines: [])
        if case .weaponSelection(.parieren) = step {} else {
            XCTFail("expected .weaponSelection, got \(step.persistenceKey)")
        }
    }

    func testDodgeRollsAWPlusTheLines() {
        hero.derivedValues = DerivedValues(
            lebensenergie: LifeEnergyValue(base: 27, bonus: 0, purchased: 0, max: 27, current: 27),
            astralenergie: nil, karmaenergie: nil,
            seelenkraft: ResourceValue(base: 1, bonus: 0, max: 1),
            zaehigkeit: ResourceValue(base: 1, bonus: 0, max: 1),
            geschwindigkeit: ResourceValue(base: 8, bonus: 0, max: 8),
            schicksalspunkte: MutableResourceValue(current: 3, bonus: 0, max: 3)
        )
        let step = DefenseRoute.next(.ausweichen, hero: hero, size: .mittel, lines: [line(-4)])
        if case .execution(let action, _, let value, _, _, _, _, _, _, _) = step {
            XCTAssertEqual(action, .ausweichen)
            XCTAssertEqual(value, 2)
        } else {
            XCTFail("expected .execution, got \(step.persistenceKey)")
        }
    }

    // MARK: - Größenkategorie

    private func holdShield() {
        hero.shields = [Shield(name: "Großschild", damage: "1W6+1", at: 6, pa: 11, reach: "Kurz", structurePoints: 30, weight: 6)]
        hero.selectedShieldName = "Großschild"
    }

    func testAGrossAttackerIsParriedWithTheShieldFromTheWeaponList() {
        armWithSword()
        holdShield()
        XCTAssertTrue(DefenseRoute.parryPossible(hero: hero, size: .gross))
        let step = DefenseRoute.next(.parieren, hero: hero, size: .gross, lines: [])
        if case .weaponSelection(.parieren) = step {} else {
            XCTFail("expected .weaponSelection, got \(step.persistenceKey)")
        }
        XCTAssertNil(DefenseRoute.baseValue(.parieren, hero: hero, size: .gross))
    }

    func testAGrossAttackerCannotBeParriedWithAWeapon() {
        armWithSword()
        XCTAssertFalse(DefenseRoute.parryPossible(hero: hero, size: .gross))
        XCTAssertNil(DefenseRoute.baseValue(.parieren, hero: hero, size: .gross))
        let step = DefenseRoute.next(.parieren, hero: hero, size: .gross, lines: [])
        if case .defenseSetup(.ausweichen) = step {} else {
            XCTFail("expected .defenseSetup(.ausweichen), got \(step.persistenceKey)")
        }
    }

    func testARiesigAttackerCannotBeParriedEvenWithAShield() {
        armWithSword()
        holdShield()
        XCTAssertFalse(DefenseRoute.parryPossible(hero: hero, size: .riesig))
    }

    func testSmallerAttackersAreParriedAsBefore() {
        armWithSword()
        for size in [CreatureSize.winzig, .klein, .mittel] {
            XCTAssertTrue(DefenseRoute.parryPossible(hero: hero, size: size), "\(size)")
            XCTAssertEqual(DefenseRoute.baseValue(.parieren, hero: hero, size: size), 8, "\(size)")
        }
    }

    func testADodgeIsAlwaysPossible() {
        let step = DefenseRoute.next(.ausweichen, hero: hero, size: .riesig, lines: [])
        if case .execution(.ausweichen, _, _, _, _, _, _, _, _, _) = step {} else {
            XCTFail("expected .execution, got \(step.persistenceKey)")
        }
    }
}
