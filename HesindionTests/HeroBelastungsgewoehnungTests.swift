import XCTest
import SwiftData
@testable import Hesindion

/// Covers `Hero.effectiveBE`'s Belastungsgewöhnung (SA_41) reduction. The rule's worked
/// example (`specs/rules/SA_41.yaml`, source page 246) states Plattenrüstung (BE 3) behaves
/// as Kettenrüstung (BE 2) at Stufe I — i.e. -1 per Stufe, not -2.
final class HeroBelastungsgewoehnungTests: XCTestCase {
    private func makeHero() -> Hero {
        let schema = Schema([Hero.self, DerivedValues.self, Armor.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T"); ctx.insert(hero)
        return hero
    }

    private func withBE(_ be: Int, on hero: Hero) {
        hero.armors.append(
            Armor(name: "Plattenrüstung", protectionValue: 8, encumbrance: be, weight: 20, isEquipped: true))
    }

    func testStufeIReducesBEByOne() {
        let hero = makeHero()
        withBE(3, on: hero)
        hero.combatSpecialAbilities = [HeroTrait(ruleId: "SA_41", name: "Belastungsgewöhnung", tier: 1)]
        XCTAssertEqual(hero.effectiveBE, 2, "BE 3 at Stufe I behaves as Kettenrüstung (BE 2)")
    }

    func testStufeIIReducesBEByTwo() {
        let hero = makeHero()
        withBE(3, on: hero)
        hero.combatSpecialAbilities = [HeroTrait(ruleId: "SA_41", name: "Belastungsgewöhnung", tier: 2)]
        XCTAssertEqual(hero.effectiveBE, 1)
    }

    func testEffectiveBEClampsAtZero() {
        let hero = makeHero()
        withBE(1, on: hero)
        hero.combatSpecialAbilities = [HeroTrait(ruleId: "SA_41", name: "Belastungsgewöhnung", tier: 2)]
        XCTAssertEqual(hero.effectiveBE, 0, "effectiveBE must not go negative")
    }

    func testNoBelastungsgewoehnungLeavesBEUnchanged() {
        let hero = makeHero()
        withBE(3, on: hero)
        XCTAssertEqual(hero.effectiveBE, 3)
    }
}
