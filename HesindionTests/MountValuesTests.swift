import XCTest
import SwiftData
import RulesEngine
@testable import Hesindion

/// Issue #48: the mount's values come from its own engine evaluation.
@MainActor
final class MountValuesTests: XCTestCase {
    private var context: ModelContext!

    override func setUpWithError() throws {
        guard RulesEngineStore.shared != nil else { throw XCTSkip("rules.json unavailable") }
        context = ModelContext(try TestData.makeContainer())
    }

    private func kupperus(le: Int, type: String = "Svellttaler Kaltblut",
                          advantages: [String] = ["Zähes Tier"]) -> Pet {
        let pet = Pet(
            petId: "PET_1", name: "Kupperus", size: 1.9, type: type,
            attributes: PetAttributes(mu: 15, kl: 10, inValue: 12, ch: 12, ff: 8, ge: 15, ko: 26, kk: 28),
            lifeEnergy: 137, currentLifeEnergy: le, spirit: 0, toughness: 0, initiative: "15+1W6", speed: 15,
            attack: "Tritt", damage: "1W6+8", reach: "mittel", actions: 1,
            talents: "", skills: "", notes: "")
        pet.defense = 14
        pet.advantages = advantages
        pet.attacks = [PetAttack(name: "Tritt", at: 19, damage: "1W6+8", reach: "mittel"),
                       PetAttack(name: "Niederreiten", at: 19, damage: "2W6+7", reach: "mittel")]
        context.insert(pet)
        return pet
    }

    func testTheBreedIsFoundByItsName() {
        let mapped = PetSheetMapping.sheet(for: kupperus(le: 137), book: RulesEngineStore.shared?.engine.book)
        XCTAssertEqual(mapped.breed, "svellttaler-kaltblut")
        XCTAssertNotNil(mapped.sheet.owned["zaehes-tier"])
        XCTAssertEqual(mapped.sheet.attacks["Niederreiten"], 19)
    }

    func testKupperusAt60LeP() throws {
        let v = try XCTUnwrap(MountValues.of(kupperus(le: 60)))
        XCTAssertEqual(v.schmerz, 2)
        XCTAssertEqual(v.gs.result, 14)               // Zähes Tier: acts at I
        XCTAssertEqual(v.at(with: "Tritt")?.result, 18)
        XCTAssertEqual(v.vw?.result, 13)
        XCTAssertFalse(v.handlungsunfaehig)
    }

    func testAMountWithoutABreedRuleHasNoThresholds() throws {
        let v = try XCTUnwrap(MountValues.of(kupperus(le: 10, type: "Pferd")))
        XCTAssertFalse(v.hasBreedRule)
        XCTAssertEqual(v.schmerz, 0)
        XCTAssertEqual(v.gs.result, 15)
    }

    func testTheStatusLineNamesTheStufeAndTheGS() throws {
        XCTAssertNil(MountValues.of(kupperus(le: 137))?.statusText(name: "Kupperus"))
        XCTAssertEqual(MountValues.of(kupperus(le: 60, advantages: []))?.statusText(name: "Kupperus"),
                       String(format: L("mount.schmerz.status"), "II", 13))
        XCTAssertEqual(MountValues.of(kupperus(le: 10, type: "Pferd"))?.statusText(name: "Kupperus"),
                       String(format: L("mount.schmerz.noThresholds"), "Kupperus"))
    }

    func testHealingTheMountLowersTheStufe() throws {
        let pet = kupperus(le: 29)
        XCTAssertEqual(MountValues.of(pet)?.schmerz, 3)
        pet.currentLifeEnergy = 100
        XCTAssertEqual(MountValues.of(pet)?.schmerz, 0)
    }
}
