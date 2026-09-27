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
}
