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
        context.insert(hero)
    }

    override func tearDown() { context = nil; hero = nil }

    private func armWithSword() {
        hero.meleeWeapons.append(MeleeWeapon(name: "Schwert", combatTechniqueId: "CT_12", damage: "1W6+4", at: 12, pa: 8, reach: "Mittel", weight: 1.6))
        hero.selectedWeaponName = "Schwert"
    }

    private func line(_ value: Int) -> ModifierLine { ModifierLine(value: value, source: "Test") }

    func testParryWithAWeaponRollsItsPAPlusTheLines() {
        armWithSword()
        let step = DefenseRoute.next(.parieren, hero: hero, lines: [line(2)])
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
        let step = DefenseRoute.next(.parieren, hero: hero, lines: [line(2)])
        if case .weaponSelection(let action) = step {
            XCTAssertEqual(action, .parieren)
        } else {
            XCTFail("expected .weaponSelection, got \(step.persistenceKey)")
        }
    }

    func testParryWithNoWeaponGoesToTheWeaponList() {
        let step = DefenseRoute.next(.parieren, hero: hero, lines: [])
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
            ausweichen: ComputedValue(value: 6, bonus: 0, max: 6),
            initiative: ComputedValue(value: 12, bonus: 0, max: 12),
            geschwindigkeit: ResourceValue(base: 8, bonus: 0, max: 8),
            wundschwelle: ComputedValue(value: 5, bonus: 0, max: 5),
            schicksalspunkte: MutableResourceValue(current: 3, bonus: 0, max: 3)
        )
        let step = DefenseRoute.next(.ausweichen, hero: hero, lines: [line(-4)])
        if case .execution(let action, _, let value, _, _, _, _, _, _, _) = step {
            XCTAssertEqual(action, .ausweichen)
            XCTAssertEqual(value, 2)
        } else {
            XCTFail("expected .execution, got \(step.persistenceKey)")
        }
    }
}
