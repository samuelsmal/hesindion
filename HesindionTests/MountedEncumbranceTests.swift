import XCTest
import SwiftData
@testable import Hesindion

/// Covers the scope of the mounted Belastung relief in `SharedModifiers.encumbrance`.
///
/// `CHAP_Reiterkampf` authors the −1 as `scope: combat`, and the controller ruling is that
/// Kampf and Zaubern are neither the same nor related: only a Kampfprobe is eased. The
/// *unmounted* Belastung penalty is untouched by that ruling and still applies in every
/// domain the definition covers — which is the half a scope fix is most likely to break.
final class MountedEncumbranceTests: XCTestCase {

    private static let combatDomains: [CheckDomain] =
        [.meleeAttack, .meleeParry, .meleeDodge, .rangedAttack]
    private static let castingDomains: [CheckDomain] = [.spellCasting, .liturgyCasting]

    private func makeHero(be: Int) -> Hero {
        let schema = Schema([Hero.self, HeroStateEntry.self, DerivedValues.self, Armor.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        hero.armors.append(
            Armor(name: "Plattenrüstung", protectionValue: 8, encumbrance: be, weight: 20, isEquipped: true))
        XCTAssertEqual(hero.effectiveBE, be, "precondition: effectiveBE is the armour's BE")
        return hero
    }

    private func encumbrance(_ hero: Hero, _ domain: CheckDomain, mounted: Bool) -> Int {
        var ctx = ModifierContext(hero: hero, domain: domain)
        ctx.mounted = mounted
        return ModifierEngine.shared
            .evaluate(context: ctx)
            .filter { $0.source == L("source.belastung") }
            .reduce(0) { $0 + $1.value }
    }

    // MARK: - The reduction: only Kampfproben get it

    func testMountedCombatChecksGetTheReduction() {
        let hero = makeHero(be: 4)
        for domain in Self.combatDomains {
            XCTAssertEqual(encumbrance(hero, domain, mounted: true), -3,
                           "\(domain) is a Kampfprobe: BE 4 is eased to 3 while mounted")
        }
    }

    func testMountedCasterKeepsTheFullBelastung() {
        let hero = makeHero(be: 4)
        for domain in Self.castingDomains {
            XCTAssertEqual(encumbrance(hero, domain, mounted: true), -4,
                           "\(domain) is not a Kampfprobe: the mounted relief must not reach it")
        }
    }

    func testMountedTalentCheckIsUntouched() {
        // The definition does not cover talentCheck at all, mounted or not — asserted so a
        // future widening of `domains` cannot quietly hand talent checks the combat relief.
        let hero = makeHero(be: 4)
        XCTAssertEqual(encumbrance(hero, .talentCheck, mounted: true), 0)
        XCTAssertEqual(encumbrance(hero, .talentCheck, mounted: false), 0)
    }

    // MARK: - The other half: unmounted Belastung still applies everywhere

    func testUnmountedBelastungAppliesInEveryDomainTheDefinitionCovers() {
        let hero = makeHero(be: 4)
        for domain in Self.combatDomains + Self.castingDomains {
            XCTAssertEqual(encumbrance(hero, domain, mounted: false), -4,
                           "\(domain): the unmounted penalty is not scoped and must stay at full BE")
        }
    }

    // MARK: - Boundaries

    func testBEOneIsRelievedToZeroOnlyOnACombatCheck() {
        let hero = makeHero(be: 1)
        XCTAssertEqual(encumbrance(hero, .meleeAttack, mounted: true), 0,
                       "BE 1 eased to 0 emits no line at all")
        XCTAssertEqual(encumbrance(hero, .spellCasting, mounted: true), -1,
                       "the same hero still carries BE 1 on a Zauberprobe")
    }

    func testNoBelastungMeansNoLineInAnyDomain() {
        let hero = makeHero(be: 0)
        for domain in Self.combatDomains + Self.castingDomains {
            XCTAssertEqual(encumbrance(hero, domain, mounted: true), 0)
            XCTAssertEqual(encumbrance(hero, domain, mounted: false), 0)
        }
    }
}
