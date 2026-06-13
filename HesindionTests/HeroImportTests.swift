import Testing
import Foundation
import SwiftData
@testable import Hesindion

@MainActor
struct HeroImportTests {

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

    private var sampleBoronmirURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // HesindionTests/
            .deletingLastPathComponent()          // project root
            .appendingPathComponent("docs/sample_heros/Boronmir Siebenfeld von Greifenfurt.json")
    }

    @Test func importBoronmirFromOptolith() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        try OptolithImportService().importHero(from: sampleBoronmirURL, context: context)

        let heroes = try context.fetch(FetchDescriptor<Hero>())
        #expect(heroes.count == 1)
        let hero = try #require(heroes.first)

        // Identity
        #expect(hero.name == "Boronmir Siebenfeld von Greifenfurt")
        #expect(hero.avatar != nil)

        // Attributes
        let attr = try #require(hero.attributes)
        #expect(attr.mu == 14)
        #expect(attr.kl == 12)
        #expect(attr.inValue == 13)
        #expect(attr.ko == 13)
        #expect(attr.kk == 15)

        // Carrying capacity: KK * 2 = 30
        #expect(hero.carryingCapacity == 30)

        // Advantages (ADV_ entries from activatable: ADV_36, ADV_49, ADV_44, ADV_75, ADV_25, ADV_5)
        #expect(hero.advantages.count == 6)
        #expect(hero.advantages.contains { $0.ruleId == "ADV_5" })
        #expect(hero.advantages.contains { $0.ruleId == "ADV_44" && $0.tier == 2 })

        // Disadvantages (DISADV_ entries, some with multiple instances)
        #expect(hero.disadvantages.count >= 5)
        #expect(hero.disadvantages.contains { $0.ruleId == "DISADV_34" })

        // Special abilities (SA_ entries, excluding SA_29 languages and SA_27 scripts)
        #expect(!hero.generalSpecialAbilities.isEmpty || !hero.combatSpecialAbilities.isEmpty)
        let allSAs = hero.generalSpecialAbilities + hero.combatSpecialAbilities
        #expect(allSAs.count >= 8)

        // Languages (from SA_29)
        #expect(hero.languages.count == 3)

        // Scripts (from SA_27)
        #expect(!hero.scripts.isEmpty)

        // Talents: import backfills all 59 standard talents (TAL_1…TAL_59),
        // defaulting any not present in the export to level 0.
        #expect(hero.talents.count == 59)

        // Combat techniques: import lists all 21 standard techniques,
        // defaulting any not rated in the export to base value 6.
        #expect(hero.combatTechniques.count == 21)

        // Equipment split
        #expect(hero.meleeWeapons.count == 2)  // Rabenschnabel + Langschwert
        #expect(hero.meleeWeapons.contains { $0.name == "Langschwert" })
        #expect(hero.meleeWeapons.contains { $0.name == "Rabenschnabel" })

        #expect(hero.shields.count == 1)        // Großschild
        let shield = try #require(hero.shields.first)
        #expect(shield.name == "Großschild")
        #expect(shield.structurePoints == 30)

        #expect(hero.armors.count == 1)         // Plattenrüstung
        let armor = try #require(hero.armors.first)
        #expect(armor.name == "Plattenrüstung")
        #expect(armor.protectionValue == 6)
        #expect(armor.encumbrance == 3)

        // General equipment
        #expect(hero.equipment.count == 3)  // Schwertscheide + Unterkleidung + Waffenpflegeset

        // No spells/cantrips for this hero
        #expect(hero.spells.isEmpty)
        #expect(hero.cantrips.isEmpty)

        // Pet
        #expect(hero.pets.count == 1)
        let pet = try #require(hero.pets.first)
        #expect(pet.name == "Kupperus")
        #expect(pet.type == "Svellttaler Kaltblut")
        #expect(pet.lifeEnergy == 75)
        #expect(pet.speed == 12)
        #expect(pet.attributes.kk == 25)

        // Derived values
        let dv = try #require(hero.derivedValues)
        #expect(dv.lebensenergie.max > 0)
        #expect(dv.lebensenergie.current == dv.lebensenergie.max)
        #expect(dv.seelenkraft.max == 2)
        #expect(dv.zaehigkeit.max == 2)
        #expect(dv.schicksalspunkte.max == 3)
        #expect(dv.schicksalspunkte.current == 3)

        // Money
        let money = try #require(hero.money)
        #expect(money.dukaten == 9)
        #expect(money.silbertaler == 5)

        // Experience
        let exp = try #require(hero.experience)
        #expect(exp.totalAP == 1200)
        #expect(exp.level == "Erfahren")
    }

    @Test func importUpsertReplacesSameHero() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Import twice
        try OptolithImportService().importHero(from: sampleBoronmirURL, context: context)
        try OptolithImportService().importHero(from: sampleBoronmirURL, context: context)

        let heroes = try context.fetch(FetchDescriptor<Hero>())
        #expect(heroes.count == 1)
    }
}
