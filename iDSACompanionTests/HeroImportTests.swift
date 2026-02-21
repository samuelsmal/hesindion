import Testing
import Foundation
import SwiftData
@testable import iDSACompanion

@MainActor
struct HeroImportTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Hero.self, PersonalData.self, Experience.self, Attributes.self,
            DerivedValues.self, Talent.self, CombatTechnique.self,
            MeleeWeapon.self, Armor.self, Shield.self, EquipmentItem.self,
            Money.self, Mount.self, Language.self,
        ])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private var sampleJSONURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // iDSACompanionTests/
            .deletingLastPathComponent()          // project root
            .appendingPathComponent("specs/001_heros-view/hero.json")
    }

    @Test func importHeroFromSampleJSON() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        try HeroImportService().importHero(from: sampleJSONURL, context: context)

        let heroes = try context.fetch(FetchDescriptor<Hero>())
        #expect(heroes.count == 1)
        let hero = try #require(heroes.first)

        // Identity
        #expect(hero.name == "Boronmir Siebenfeld von Ferdok")
        // carryingCapacity is derived: KK * 2 = 15 * 2 = 30
        #expect(hero.carryingCapacity == 30)

        // Advantages / disadvantages
        #expect(hero.advantages.count == 6)
        #expect(hero.disadvantages.count == 4)

        // Languages
        #expect(hero.languages.count == 3)

        // Talents
        let talentCount = hero.talents.count
        #expect(talentCount == 14 + 9 + 7 + 12 + 17) // body + society + nature + knowledge + craft

        // Combat techniques
        #expect(hero.combatTechniques.count == 14)

        // Equipment (Ausrüstung only)
        #expect(hero.equipment.count == 3)

        // Weapons parsed from equipment
        #expect(hero.meleeWeapons.count == 2)
        #expect(hero.meleeWeapons.contains { $0.name == "Langschwert" })
        #expect(hero.meleeWeapons.contains { $0.name == "Rabenschnabel" })

        // Armor parsed from equipment
        #expect(hero.armors.count == 1)
        let armor = try #require(hero.armors.first)
        #expect(armor.name == "Plattenrüstung")
        #expect(armor.protectionValue == 11)
        #expect(armor.encumbrance == 3)

        // Shield parsed from equipment
        #expect(hero.shields.count == 1)
        let shield = try #require(hero.shields.first)
        #expect(shield.name == "Großschild")

        // Derived values
        let dv = try #require(hero.derivedValues)
        #expect(dv.lebensenergie.max == 33)
        #expect(dv.lebensenergie.current == 33)
        #expect(dv.schicksalspunkte.max == 3)
        #expect(dv.schicksalspunkte.current == 3)

        // Mount
        let mount = try #require(hero.mount)
        #expect(mount.name == "Kupperus")
        #expect(mount.attacks.count == 3)
        #expect(mount.talents.count == 8)

        // Money
        let money = try #require(hero.money)
        #expect(money.dukaten == 9)
        #expect(money.silbertaler == 5)
    }
}
