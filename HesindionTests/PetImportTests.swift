import Testing
import Foundation
import SwiftData
@testable import Hesindion

/// A plain Optolith export's pet fields reach `Pet` (issue #49).
@MainActor
struct PetImportTests {

    private func sample(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("specs/heroes/\(name).json")
    }

    private var current: URL { sample("Boronmir Siebenfeld von Greifenfurt (2026-09-24)") }
    private var older: URL { sample("Boronmir Siebenfeld von Greifenfurt") }

    private func kupperus(_ context: ModelContext) throws -> Pet {
        let hero = try #require(try context.fetch(FetchDescriptor<Hero>()).first)
        return try #require(hero.petsInOrder.first { $0.name == "Kupperus" })
    }

    /// `older` with Kupperus's text fields replaced, as Data.
    private func older(skills: String, notes: String) throws -> Data {
        var root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: older)) as? [String: Any])
        var pets = try #require(root["pets"] as? [String: Any])
        var pet = try #require(pets["PET_1"] as? [String: Any])
        pet["skills"] = skills
        pet["notes"] = notes
        pets["PET_1"] = pet
        root["pets"] = pets
        return try JSONSerialization.data(withJSONObject: root)
    }

    @Test func currentExportGivesTheSpecValues() throws {
        let context = ModelContext(try TestData.makeContainer())
        let result = try OptolithImportService().importHero(from: current, context: context)
        let pet = try kupperus(context)
        #expect(result.problems.isEmpty)
        #expect(pet.defense == 14)
        #expect(pet.armor == 0)
        #expect(pet.encumbrance == 0)
        #expect(pet.apTotal == 336)
        #expect(pet.apSpent == 336)
        #expect(pet.attacks.map(\.name) == ["Tritt", "Biss", "Niederreiten"])
        #expect(pet.attacks.first?.at == 19)
        #expect(pet.advantages.contains("Heldenwuchs"))
        #expect(pet.training == ["Reittier", "Kampftier"])
        #expect(pet.tricks == ["Aus", "Fass I", "Fass II", "Komm", "Sitz"])
        #expect(pet.hasMightyBlow)
        #expect(pet.notes.hasPrefix("Kampfverhalten:"))
        #expect(pet.importProblems.isEmpty)
    }

    @Test func olderExportKeepsItsBaseValues() throws {
        let context = ModelContext(try TestData.makeContainer())
        let result = try OptolithImportService().importHero(from: older, context: context)
        let pet = try kupperus(context)
        #expect(result.problems.isEmpty)
        #expect(pet.attacks == [
            PetAttack(name: "Tritt", at: 15, damage: "1W6+7", reach: "mittel"),
            PetAttack(name: "Biss", at: 12, damage: "1W6+2", reach: "kurz"),
            PetAttack(name: "Niederreiten", at: 15, damage: "2W6+6", reach: "mittel"),
        ])
        #expect(pet.defense == nil)
        #expect(pet.hasMightyBlow)
    }

    @Test func oldFormatExportStoresProblems() throws {
        let context = ModelContext(try TestData.makeContainer())
        let data = try older(skills: "Mächtiger Schlag",
                             notes: "Tritt: AT 15 TP 1W6+7 RW mittel; Kampfverhalten: besonnen.")
        let result = try OptolithImportService().importHero(from: data, context: context)
        let pet = try kupperus(context)
        #expect(result.problems.map(\.reason) == [.noLabel, .attackOutsideAngriffe])
        #expect(pet.importProblems == result.problems)
        #expect(!pet.hasMightyBlow)
        #expect(pet.attacks.map(\.name) == ["Niederreiten"])
    }

    @Test func cleanReimportClearsProblems() throws {
        let context = ModelContext(try TestData.makeContainer())
        try OptolithImportService().importHero(from: try older(skills: "Mächtiger Schlag", notes: ""), context: context)
        #expect(try !kupperus(context).importProblems.isEmpty)
        let again = try OptolithImportService().importHero(from: older, context: context)
        #expect(again == .updated(heroName: "Boronmir Siebenfeld von Greifenfurt (2026-09-24)"))
        #expect(try kupperus(context).importProblems.isEmpty)
    }

    @Test func mightyBlowFromAnAbilityWithANote() throws {
        let context = ModelContext(try TestData.makeContainer())
        try OptolithImportService().importHero(
            from: try older(skills: "Sonderfertigkeiten: Mächtiger Schlag (-4 auf Gegner Kraftakt)", notes: ""),
            context: context)
        #expect(try kupperus(context).hasMightyBlow)
    }

    @Test func aHesindionBlockIsIgnored() throws {
        var root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: older)) as? [String: Any])
        root["hesindion"] = ["schemaVersion": 1, "pets": ["PET_1": ["name": "Kupperus", "values": ["vw": 99]]]]
        let context = ModelContext(try TestData.makeContainer())
        try OptolithImportService().importHero(from: try JSONSerialization.data(withJSONObject: root), context: context)
        #expect(try kupperus(context).defense == nil)
    }

    /// Was `CompanionImportTests.mountedChargeUsesTheCompanionGS`: the mount's GS is Optolith's `mov`,
    /// and the Sturmangriff zu Pferd's RK14 line uses that value, not the breed's 12.
    @Test func mountGSIsTheExportsMov() throws {
        let context = ModelContext(try TestData.makeContainer())
        try OptolithImportService().importHero(from: current, context: context)
        #expect(try kupperus(context).speed == 15)

        let hero = try #require(try context.fetch(FetchDescriptor<Hero>()).first)
        #expect(hero.mount?.name == "Kupperus")
        var charge = Situation(hero: hero, domain: .damage)
        charge.maneuver = .sturmangriff
        charge.round.mounted = true
        let line = DamageModifiers.lines(situation: charge).first { $0.source.hasPrefix(L("source.sturmangriff")) }
        #expect(line?.value == 10)  // 2 + ⌈15/2⌉
        #expect(line?.source == String(format: L("source.sturmangriff.rk14"), "Kupperus", 15))
    }
}
