import XCTest
import SwiftData
@testable import Hesindion

/// A pet stored before issue #49 kept its Sonderfertigkeiten text only in the removed
/// `specialSkills`; the launch repair reads its raw `skills` again (final review, Important 1).
@MainActor
final class PetSkillsRepairTests: XCTestCase {
    private func storedPet(skills: String, in context: ModelContext) -> Pet {
        let pet = Pet(petId: "PET_1", name: "Kupperus", size: 1.6, type: "Pferd",
                      attributes: PetAttributes(mu: 12, kl: 8, inValue: 12, ch: 10, ff: 8, ge: 12, ko: 16, kk: 18),
                      lifeEnergy: 60, spirit: 0, toughness: 0, initiative: "12+1W6", speed: 14,
                      attack: "Niederreiten", damage: "2W6+6", reach: "mittel", actions: 1,
                      talents: "Kraftakt 8", skills: skills, notes: "Kampfverhalten: besonnen",
                      attacks: [PetAttack(name: "Niederreiten", at: 15, damage: "2W6+6", reach: "mittel")])
        context.insert(pet)
        return pet
    }

    func testAnUnlabelledLegacySkillBecomesAProblemRow() throws {
        let context = ModelContext(try TestData.makeContainer())
        let pet = storedPet(skills: "Mächtiger Schlag", in: context)

        XCTAssertTrue(PetSkillsRepair.repair(pet))
        XCTAssertEqual(pet.abilities, [])
        XCTAssertEqual(pet.importProblems, [PetImportProblem(pet: "Kupperus", field: .sonderfertigkeiten,
                                                             text: "Mächtiger Schlag", reason: .noLabel)])
        XCTAssertFalse(pet.hasMightyBlow)
    }

    func testALabelledLegacySkillFillsTheLists() throws {
        let context = ModelContext(try TestData.makeContainer())
        let pet = storedPet(skills: "Vorteile: Geduldig; Sonderfertigkeiten: Mächtiger Schlag; Tricks: Aus", in: context)

        XCTAssertTrue(PetSkillsRepair.repair(pet))
        XCTAssertEqual(pet.abilities, ["Mächtiger Schlag"])
        XCTAssertEqual(pet.advantages, ["Geduldig"])
        XCTAssertEqual(pet.tricks, ["Aus"])
        XCTAssertTrue(pet.hasMightyBlow)
        XCTAssertEqual(pet.importProblems, [])
        // Attacks, notes and numbers were stored correctly before #49 and stay as they are.
        XCTAssertEqual(pet.attacks, [PetAttack(name: "Niederreiten", at: 15, damage: "2W6+6", reach: "mittel")])
        XCTAssertEqual(pet.notes, "Kampfverhalten: besonnen")
        XCTAssertNil(pet.defense)
    }

    func testAPetThatAlreadyHasListsIsUntouched() throws {
        let context = ModelContext(try TestData.makeContainer())
        let pet = storedPet(skills: "Sonderfertigkeiten: Mächtiger Schlag; Tricks: Aus", in: context)
        pet.abilities = ["Mächtiger Schlag"]

        XCTAssertFalse(PetSkillsRepair.repair(pet))
        XCTAssertEqual(pet.tricks, [])
    }

    func testAPetWithProblemsIsUntouched() throws {
        let context = ModelContext(try TestData.makeContainer())
        let pet = storedPet(skills: "Mächtiger Schlag", in: context)
        let problem = PetImportProblem(pet: "Kupperus", field: .notizen, text: "BE: eins", reason: .badBE)
        pet.importProblems = [problem]

        XCTAssertFalse(PetSkillsRepair.repair(pet))
        XCTAssertEqual(pet.importProblems, [problem])
    }

    func testAPetWithoutSkillsTextIsUntouched() throws {
        let context = ModelContext(try TestData.makeContainer())
        XCTAssertFalse(PetSkillsRepair.repair(storedPet(skills: "", in: context)))
    }

    func testRunningTwiceChangesNothing() throws {
        let context = ModelContext(try TestData.makeContainer())
        let unlabelled = storedPet(skills: "Mächtiger Schlag", in: context)
        let labelled = storedPet(skills: "Sonderfertigkeiten: Mächtiger Schlag", in: context)
        PetSkillsRepair.repairAll(in: context)
        let problems = unlabelled.importProblems
        let abilities = labelled.abilities

        XCTAssertFalse(PetSkillsRepair.repair(unlabelled))
        XCTAssertFalse(PetSkillsRepair.repair(labelled))
        PetSkillsRepair.repairAll(in: context)
        XCTAssertEqual(unlabelled.importProblems, problems)
        XCTAssertEqual(labelled.abilities, abilities)
        XCTAssertEqual(problems.count, 1)
        XCTAssertEqual(abilities, ["Mächtiger Schlag"])
    }
}
