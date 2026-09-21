import XCTest
import SwiftData
@testable import Hesindion

/// Tests for the finding-3 repair pass (whole-branch review): `OptolithImportService`'s
/// combat-SA classification changed from "has a hand-authored `scope: combat` effect" (9
/// matches) to "Optolith group is one of 3, 9, 10, 11, 12" (232 matches), and a hero imported
/// under the old rule needs its `generalSpecialAbilities` / `combatSpecialAbilities` split
/// re-derived to match what a fresh import produces today.
///
/// Every test drives the classification with a fake `lookupGroupId` closure rather than the
/// bundled `rules.db`, per the brief's injectability requirement.
final class SpecialAbilityClassificationRepairTests: XCTestCase {

    private func makeHero(general: [HeroTrait], combat: [HeroTrait]) -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Hero.self, HeroStateEntry.self, configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T")
        hero.generalSpecialAbilities = general
        hero.combatSpecialAbilities = combat
        ctx.insert(hero)
        return hero
    }

    private func trait(_ id: String) -> HeroTrait {
        HeroTrait(ruleId: id, name: id, tier: nil, sid: nil)
    }

    // MARK: - Reclassification actually moves a misfiled combat SA

    func testMisclassifiedGeneralSAMovesToCombat() {
        // SA_884 (Plänkler-Formation) — group 3, a combat SA the old predicate missed.
        let hero = makeHero(general: [trait("SA_884")], combat: [])
        let lookup: (String) -> Int? = { $0 == "SA_884" ? 3 : nil }

        XCTAssertTrue(SpecialAbilityClassificationRepair.repair(hero, lookupGroupId: lookup))
        XCTAssertEqual(hero.generalSpecialAbilities.map(\.ruleId), [])
        XCTAssertEqual(hero.combatSpecialAbilities.map(\.ruleId), ["SA_884"])
    }

    func testCorrectlyClassifiedHeroIsUnchanged() {
        let hero = makeHero(general: [trait("SA_1")], combat: [trait("SA_884")])
        let lookup: (String) -> Int? = { id in
            switch id {
            case "SA_1": return 99    // some non-combat group
            case "SA_884": return 3
            default: return nil
            }
        }
        XCTAssertFalse(SpecialAbilityClassificationRepair.repair(hero, lookupGroupId: lookup))
        XCTAssertEqual(hero.generalSpecialAbilities.map(\.ruleId), ["SA_1"])
        XCTAssertEqual(hero.combatSpecialAbilities.map(\.ruleId), ["SA_884"])
    }

    // MARK: - Idempotence (shape of `DerivedValueRepairTests.testGeschwindigkeitRepairIsIdempotent`)

    func testReclassificationIsIdempotent() {
        let hero = makeHero(general: [trait("SA_884"), trait("SA_1")], combat: [trait("SA_2")])
        let lookup: (String) -> Int? = { id in
            switch id {
            case "SA_884": return 3      // moves general -> combat
            case "SA_1": return 99        // stays general
            case "SA_2": return 9          // stays combat
            default: return nil
            }
        }

        XCTAssertTrue(SpecialAbilityClassificationRepair.repair(hero, lookupGroupId: lookup))
        let generalAfterFirst = hero.generalSpecialAbilities
        let combatAfterFirst = hero.combatSpecialAbilities

        XCTAssertFalse(
            SpecialAbilityClassificationRepair.repair(hero, lookupGroupId: lookup),
            "second run must report no change"
        )
        XCTAssertEqual(hero.generalSpecialAbilities, generalAfterFirst)
        XCTAssertEqual(hero.combatSpecialAbilities, combatAfterFirst)
    }

    // MARK: - Nothing lost, nothing duplicated

    func testMultisetOfTraitsAcrossBothArraysIsUnchanged() {
        let allTraits = [
            trait("SA_884"), trait("SA_1"), trait("SA_2"), trait("SA_3"), trait("SA_661"),
        ]
        let hero = makeHero(
            general: [allTraits[0], allTraits[1], allTraits[4]],
            combat: [allTraits[2], allTraits[3]]
        )
        let before = Set(hero.generalSpecialAbilities + hero.combatSpecialAbilities)

        let lookup: (String) -> Int? = { id in
            switch id {
            case "SA_884": return 3
            case "SA_661": return 3
            case "SA_1": return 99
            case "SA_2": return 9
            case "SA_3": return nil        // unknown, currently general anyway
            default: return nil
            }
        }
        _ = SpecialAbilityClassificationRepair.repair(hero, lookupGroupId: lookup)

        let after = Set(hero.generalSpecialAbilities + hero.combatSpecialAbilities)
        XCTAssertEqual(before, after, "the repair must only move traits between arrays, never drop or duplicate one")
        XCTAssertEqual(
            hero.generalSpecialAbilities.count + hero.combatSpecialAbilities.count,
            allTraits.count
        )
    }

    /// A trait whose id does not start with `SA_` (if any reaches these arrays) is not
    /// reclassifiable and stays exactly where it was.
    func testNonSATraitStaysPutEvenWhenLookupWouldClassifyItAsCombat() {
        let stray = HeroTrait(ruleId: "ADV_54", name: "Eisern", tier: nil, sid: nil)
        let hero = makeHero(general: [stray], combat: [])
        // Lookup would (nonsensically) say "combat" for anything — must not matter, since
        // the id does not start with `SA_`.
        let lookup: (String) -> Int? = { _ in 3 }

        XCTAssertFalse(SpecialAbilityClassificationRepair.repair(hero, lookupGroupId: lookup))
        XCTAssertEqual(hero.generalSpecialAbilities, [stray])
        XCTAssertEqual(hero.combatSpecialAbilities, [])
    }

    // MARK: - Deliberate demotion of an unknown id

    /// A rule id the database does not know returns `nil`, which is therefore *not* combat —
    /// so a trait currently in `combatSpecialAbilities` whose id is unknown moves to
    /// `generalSpecialAbilities`. This matches what a fresh import of that hero produces
    /// today, which is the whole point of this repair, so it is recorded as a decision
    /// rather than left as a surprise.
    func testUnknownIdInCombatArrayIsDemotedToGeneral() {
        let hero = makeHero(general: [], combat: [trait("SA_999")])
        let lookup: (String) -> Int? = { _ in nil }

        XCTAssertTrue(SpecialAbilityClassificationRepair.repair(hero, lookupGroupId: lookup))
        XCTAssertEqual(hero.generalSpecialAbilities.map(\.ruleId), ["SA_999"])
        XCTAssertEqual(hero.combatSpecialAbilities.map(\.ruleId), [])
    }

    // MARK: - Positive result: no previously-combat SA stops being one

    /// All nine SAs the old predicate matched (`SA_40`, `41`, `43`, `48`, `59`, `65`, `66`,
    /// `67`, `661`) are in groups 3 or 9, so nothing that used to be a combat SA stops being
    /// one under the new predicate. `SA_41` in particular is group 3, which is why
    /// `Hero.belastungsgewoehnungLevel` keeps working.
    func testAllNinePreviouslyCombatSAsRemainCombat() {
        let ids = ["SA_40", "SA_41", "SA_43", "SA_48", "SA_59", "SA_65", "SA_66", "SA_67", "SA_661"]
        // Groups as verified against the built rules.db (whole-branch review, finding 3):
        // eight in group 3 (Kampf), SA_661 alone in group 9 (Kampfstile bewaffnet).
        let groups: [String: Int] = [
            "SA_40": 3, "SA_41": 3, "SA_43": 3, "SA_48": 3, "SA_59": 3,
            "SA_65": 3, "SA_66": 3, "SA_67": 3, "SA_661": 9,
        ]
        let hero = makeHero(general: [], combat: ids.map(trait))
        let lookup: (String) -> Int? = { groups[$0] }

        XCTAssertFalse(SpecialAbilityClassificationRepair.repair(hero, lookupGroupId: lookup))
        XCTAssertEqual(Set(hero.combatSpecialAbilities.map(\.ruleId)), Set(ids))
        XCTAssertTrue(hero.generalSpecialAbilities.isEmpty)
    }
}
