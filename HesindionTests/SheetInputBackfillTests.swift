import XCTest
import SwiftData
@testable import Hesindion

@MainActor
final class SheetInputBackfillTests: XCTestCase {
    func testTheImportWritesTheNewInputs() throws {
        let hero = try SampleHeroes.importHero(named: "Boronmir Siebenfeld von Greifenfurt")
        let raben = try XCTUnwrap(hero.meleeWeapons.first { $0.templateId == "ITEMTPL_19" })
        XCTAssertEqual(raben.atModifier, 0)
        XCTAssertEqual(raben.paModifier, -1)
        let schild = try XCTUnwrap(hero.shields.first { $0.templateId == "ITEMTPL_29" })
        XCTAssertEqual(schild.atModifier, -6)
        XCTAssertEqual(hero.derivedValues?.speciesLE, 5)
    }

    func testTheBackfillDerivesThemFromTheFoldedValues() throws {
        let hero = try SampleHeroes.importHero(named: "Boronmir Siebenfeld von Greifenfurt")
        for w in hero.meleeWeapons { w.atModifier = nil; w.paModifier = nil }
        for s in hero.shields { s.atModifier = nil }
        hero.derivedValues?.speciesLE = nil

        XCTAssertTrue(SheetInputBackfill.fill(hero))
        let raben = try XCTUnwrap(hero.meleeWeapons.first { $0.templateId == "ITEMTPL_19" })
        XCTAssertEqual(raben.atModifier, 0)
        XCTAssertEqual(raben.paModifier, -1)
        XCTAssertEqual(hero.shields.first { $0.templateId == "ITEMTPL_29" }?.atModifier, -6)
        XCTAssertEqual(hero.derivedValues?.speciesLE, 5)
        XCTAssertFalse(SheetInputBackfill.fill(hero), "idempotent")
    }

    /// `parseCombatTechniques` stores `pa == 0` for a no-parry technique (e.g. CT_6
    /// Kettenwaffen) as a marker, not a real technique PA the import's fold used — so a
    /// weapon on such a technique cannot have its PA-Mod derived from `weapon.pa - ct.pa`.
    func testTheBackfillLeavesPAModifierNilOnANoParryTechnique() throws {
        let context = ModelContext(try TestData.makeContainer())
        let hero = Hero(name: "Test")
        context.insert(hero)
        let ct = CombatTechnique(ruleId: "CT_6", name: "Kettenwaffen", value: 6, at: 6, pa: 0)
        hero.combatTechniques.append(ct)
        let weapon = MeleeWeapon(name: "Morgenstern", combatTechniqueId: "CT_6",
                                  damage: "1W6+2", at: 8, pa: 3, reach: "Mittel", weight: 3)
        hero.meleeWeapons.append(weapon)

        XCTAssertTrue(SheetInputBackfill.fill(hero))
        XCTAssertEqual(weapon.atModifier, weapon.at - ct.at)
        XCTAssertNil(weapon.paModifier)
    }
}
