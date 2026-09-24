import Testing
import Foundation
import SwiftData
@testable import Hesindion

@MainActor
struct CompanionImportTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Hero.self, HeroStateEntry.self, PersonalData.self, Experience.self, Attributes.self,
            DerivedValues.self, Talent.self, CombatTechnique.self,
            MeleeWeapon.self, RangedWeapon.self, Armor.self, Shield.self,
            EquipmentItem.self, Money.self, Pet.self, Language.self,
            HeroSpell.self, LogEntry.self, Adventure.self, WeatherDay.self,
        ])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func sample(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/sample_heros/\(name)")
    }

    private var withBlock: URL { sample("Boronmir Siebenfeld von Greifenfurt (2026-09-24).json") }
    private var withoutBlock: URL { sample("Boronmir Siebenfeld von Greifenfurt.json") }

    private func kupperus(_ context: ModelContext) throws -> Pet {
        let hero = try #require(try context.fetch(FetchDescriptor<Hero>()).first)
        return try #require(hero.petsInOrder.first { $0.name == "Kupperus" })
    }

    /// The with-block sample as a plain Optolith re-export: same hero, no `hesindion` block.
    /// `edit` changes the pet before serialising, to prove Optolith fields come from the new file.
    private func plainReexport(_ edit: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        var root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: withBlock)) as? [String: Any])
        root.removeValue(forKey: "hesindion")
        var pets = try #require(root["pets"] as? [String: Any])
        var pet = try #require(pets["PET_1"] as? [String: Any])
        edit(&pet)
        pets["PET_1"] = pet
        root["pets"] = pets
        return try JSONSerialization.data(withJSONObject: root)
    }

    @Test func importReadsCompanionBlock() throws {
        let context = ModelContext(try makeContainer())
        try OptolithImportService().importHero(from: withBlock, context: context)
        let pet = try kupperus(context)

        #expect(pet.hasCompanionData)
        #expect(pet.defense == 14)
        #expect(pet.armor == 0)
        #expect(pet.encumbrance == 0)
        #expect(pet.apTotal == 336)
        #expect(pet.apSpent == 336)
        #expect(pet.training == ["Reittier", "Kampftier"])
        #expect(pet.tricks == ["Aus", "Fass I", "Fass II", "Komm"])
        #expect(pet.advantages.count == 10)
        #expect(pet.abilities == ["Mächtiger Schlag"])
        #expect(pet.purchases.count == 19)
        #expect(pet.purchases.contains(PetPurchase(kind: "raise", target: "vw", ap: 30, from: 7, to: 14)))
        #expect(pet.attacks.map(\.name) == ["Tritt", "Biss", "Niederreiten"])
        #expect(pet.attacks[1] == PetAttack(name: "Biss", at: 16, damage: "1W6+3", reach: "kurz"))
        #expect(pet.hasMightyBlow)
    }

    @Test func importWithoutBlockKeepsTodaysParsing() throws {
        let context = ModelContext(try makeContainer())
        try OptolithImportService().importHero(from: withoutBlock, context: context)
        let pet = try kupperus(context)

        #expect(!pet.hasCompanionData)
        #expect(pet.defense == nil)
        #expect(pet.training.isEmpty)
        #expect(pet.attacks.map(\.name) == ["Tritt", "Biss", "Niederreiten"])
        #expect(pet.attacks.first?.at == 15)
        #expect(pet.hasMightyBlow)  // from `skills`, the fallback
    }

    @Test func undecodableBlockIsIgnoredForThatPet() throws {
        var root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: withBlock)) as? [String: Any])
        root["hesindion"] = ["schemaVersion": 1, "pets": ["PET_1": ["name": "Kupperus"]]]
        let data = try JSONSerialization.data(withJSONObject: root)
        let context = ModelContext(try makeContainer())

        try OptolithImportService().importHero(from: data, context: context)

        let pet = try kupperus(context)
        #expect(!pet.hasCompanionData)
        #expect(pet.attacks.count == 3)  // regex over the fixed notes
    }

    @Test func conflictWhenReimportLosesTheBlock() throws {
        let context = ModelContext(try makeContainer())
        let service = OptolithImportService()
        try service.importHero(from: withBlock, context: context)

        #expect(try service.companionConflicts(in: plainReexport(), context: context) == ["Kupperus"])
        #expect(try service.companionConflicts(in: Data(contentsOf: withBlock), context: context).isEmpty)
    }

    @Test func noConflictForNewHeroOrPlainPet() throws {
        let context = ModelContext(try makeContainer())
        let service = OptolithImportService()
        #expect(try service.companionConflicts(in: Data(contentsOf: withoutBlock), context: context).isEmpty)

        try service.importHero(from: withoutBlock, context: context)
        #expect(try service.companionConflicts(in: Data(contentsOf: withoutBlock), context: context).isEmpty)
    }

    @Test func noConflictWhenPetIsGoneFromNewFile() throws {
        let context = ModelContext(try makeContainer())
        let service = OptolithImportService()
        try service.importHero(from: withBlock, context: context)
        var root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: withBlock)) as? [String: Any])
        root.removeValue(forKey: "hesindion")
        root["pets"] = [String: Any]()
        let data = try JSONSerialization.data(withJSONObject: root)

        #expect(try service.companionConflicts(in: data, context: context).isEmpty)
    }

    @Test func keepRestoresOnlyTheAddedFields() throws {
        let context = ModelContext(try makeContainer())
        let service = OptolithImportService()
        try service.importHero(from: withBlock, context: context)

        try service.importHero(from: try plainReexport { $0["lp"] = "140"; $0["str"] = "27" }, context: context,
                               keepingCompanionDataFor: ["Kupperus"])

        let pet = try kupperus(context)
        #expect(pet.defense == 14)
        #expect(pet.apTotal == 336)
        #expect(pet.training == ["Reittier", "Kampftier"])
        #expect(pet.attacks[1] == PetAttack(name: "Biss", at: 16, damage: "1W6+3", reach: "kurz"))
        #expect(pet.lifeEnergy == 140)          // Optolith field: from the new file
        #expect(pet.attributes.kk == 27)
    }

    @Test func discardDropsTheAddedFields() throws {
        let context = ModelContext(try makeContainer())
        let service = OptolithImportService()
        try service.importHero(from: withBlock, context: context)

        try service.importHero(from: try plainReexport(), context: context)

        let pet = try kupperus(context)
        #expect(!pet.hasCompanionData)
        #expect(pet.defense == nil)
        #expect(pet.attacks.first?.at == 19)
    }
}
