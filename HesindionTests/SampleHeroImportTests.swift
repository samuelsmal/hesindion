import Testing
import Foundation
import SwiftData
@testable import Hesindion

/// The synthetic sample heroes in `specs/heroes/` cover what Boronmir does not: a species other
/// than Menschen, a Geweihte with blessings and liturgies, a Zauberin who bought no extra AsP, a
/// ranged weapon, and Plänkler-Formation (SA_884). Every expectation is the rule's value, computed
/// by hand from the Optolith data (`univ/Races.yaml`, `univ/*Traditions.yaml`) — not what the
/// importer happens to return. Where the importer is wrong today, the check sits in
/// `withKnownIssue`, which fails as soon as the fix lands so the marker is removed with it.
@MainActor
struct SampleHeroImportTests {

    private func importHero(_ fileName: String) throws -> Hero {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // HesindionTests/
            .deletingLastPathComponent()          // project root
            .appendingPathComponent("specs/heroes/\(fileName).json")
        let context = ModelContext(try TestData.makeContainer())
        try OptolithImportService().importHero(from: url, context: context)
        return try #require(try context.fetch(FetchDescriptor<Hero>()).first)
    }

    // MARK: - Ingra: Zwergin, Geweihte des Ingerimm

    /// MU 13, KL 12, IN 14, KO 15, KK 14. Zwerge: LE 8, SK −4, ZK −4, GS 6.
    @Test func dwarfDerivedValuesFollowTheSpecies() throws {
        let hero = try importHero("Ingra Tochter der Ilpetta")
        #expect(hero.personalData?.speciesId == "R_4")
        #expect(hero.personalData?.species == "Zwerge")
        let dv = try #require(hero.derivedValues)
        #expect(dv.lebensenergie.max == 8 + 2 * 15)                     // 38
        #expect(dv.seelenkraft.max == -4 + 7)                           // ⌈(13+12+14)/6⌉ = 7
        #expect(dv.zaehigkeit.max == -4 + 8)                            // ⌈(15+15+14)/6⌉ = 8
        #expect(dv.geschwindigkeit.max == 6)
    }

    @Test func aDwarfIsSmallForTheHitZones() throws {
        let hero = try importHero("Ingra Tochter der Ilpetta")
        #expect(hero.sizeCategory == .klein)
    }

    /// Geweihter gives 20 KaP, and the tradition's primary attribute adds its value
    /// (Ingerimm, SA_691: IN). She bought no extra KaP.
    @Test func aBlessedOneWithoutPurchasedKaPStillHasKarmaenergie() throws {
        let hero = try importHero("Ingra Tochter der Ilpetta")
        withKnownIssue("The importer grants KaP only when some were bought, and ignores the tradition's primary attribute") {
            let kap = try #require(hero.derivedValues?.karmaenergie)
            #expect(kap.max == 20 + 14)
        }
    }

    @Test func blessingsAndLiturgiesAreImported() throws {
        let hero = try importHero("Ingra Tochter der Ilpetta")
        #expect(hero.blessings.count == 12)
        #expect(Set(hero.liturgies.map(\.ruleId)) == ["LITURGY_11", "LITURGY_12"])
    }

    /// Plänkler-Formation has no effects row; it used to be filed as general. Boronmir no longer
    /// carries it, so this hero does.
    @Test func plaenklerFormationIsFiledAsCombat() throws {
        let hero = try importHero("Ingra Tochter der Ilpetta")
        #expect(hero.combatSpecialAbilities.contains { $0.ruleId == "SA_884" })
        #expect(!hero.generalSpecialAbilities.contains { $0.ruleId == "SA_884" })
    }

    @Test func rangedWeaponShieldAndArmorAreSorted() throws {
        let hero = try importHero("Ingra Tochter der Ilpetta")
        #expect(hero.rangedWeapons.map(\.templateId) == ["ITEMTPL_60"])
        #expect(hero.shields.count == 1)
        #expect(hero.armors.count == 1)
        #expect(hero.meleeWeapons.map(\.templateId) == ["ITEMTPL_21"])
    }

    // MARK: - Lyssandra: Halbelfe, Gildenmagierin

    /// MU 12, KL 15, IN 14, KO 11, KK 10. Halbelfen: LE 5, SK −4, ZK −6, GS 8.
    @Test func halfElfLifeAndSpeed() throws {
        let hero = try importHero("Lyssandra Silberhaar")
        #expect(hero.personalData?.speciesId == "R_3")
        let dv = try #require(hero.derivedValues)
        #expect(dv.lebensenergie.max == 5 + 2 * 11)                     // 27
        #expect(dv.geschwindigkeit.max == 8)
        #expect(hero.sizeCategory == .mittel)
    }

    @Test func halfElfSeelenkraftAndZaehigkeit() throws {
        let hero = try importHero("Lyssandra Silberhaar")
        let dv = try #require(hero.derivedValues)
        withKnownIssue("The importer's Halbelfen row says SK −5, ZK −5; Optolith's Races.yaml says −4, −6") {
            #expect(dv.seelenkraft.max == -4 + 7)                       // ⌈(12+15+14)/6⌉ = 7
            #expect(dv.zaehigkeit.max == -6 + 6)                        // ⌈(11+11+10)/6⌉ = 6
        }
    }

    /// Zauberer gives 20 AsP, and the tradition's primary attribute adds its value
    /// (Gildenmagier, SA_70: KL). She bought no extra AsP.
    @Test func aSpellcasterWithoutPurchasedAsPStillHasAstralenergie() throws {
        let hero = try importHero("Lyssandra Silberhaar")
        withKnownIssue("The importer grants AsP only when some were bought, and ignores the tradition's primary attribute") {
            let asp = try #require(hero.derivedValues?.astralenergie)
            #expect(asp.max == 20 + 15)
        }
    }

    @Test func spellsAndCantripsAreImported() throws {
        let hero = try importHero("Lyssandra Silberhaar")
        #expect(Set(hero.spells.map(\.ruleId)) == ["SPELL_21", "SPELL_3", "SPELL_5"])
        #expect(hero.cantrips.count == 2)
    }

    // MARK: - Robak: Gildenmagier with one purchased AsP

    /// KL 15, one AsP bought: 20 + 15 + 1.
    @Test func robaksAstralenergieIncludesThePrimaryAttribute() throws {
        let hero = try importHero("Robak Arkanjeff")
        let asp = try #require(hero.derivedValues?.astralenergie)
        withKnownIssue("The importer ignores the tradition's primary attribute") {
            #expect(asp.max == 20 + 15 + 1)
        }
    }
}
