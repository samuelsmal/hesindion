import XCTest
@testable import Hesindion

/// Whether a Sonderfertigkeit the hero paid for actually reaches the roll.
///
/// Three ways an ability can be silently ignored, all of them hit in one
/// afternoon:
///
/// 1. **The id is wrong.** They were typed inline at a dozen call sites with the
///    ability's name in a comment beside them, and three of those comments did
///    not match `rules.db` — the app withheld the two-handed grip from
///    *Armbrüste*, forbade a mounted hero the *lance*, and counted no bow as a
///    Schusswaffe.
/// 2. **The importer filed it out of reach.** Until `CombatSpecialAbilityGroup`,
///    an SA went to `combatSpecialAbilities` only when `rules.db` had a
///    combat-scoped effects row for it, which nine of 226 had — so
///    Plänkler-Formation, Gezielter Angriff and Gezielter Schuss sat in the
///    general list while every lookup searched the combat one. Heroes imported
///    back then still carry that split.
/// 3. **Nothing implements it.** Where each ability is reached is recorded in
///    the rules catalog; `RulesCatalogTests` checks the pointers (issue #27).
///
/// None of that is visible on screen — the ability is on the hero sheet, and the
/// roll is simply a little too low. So it is checked here instead.
final class CombatAbilityCoverageTests: XCTestCase {

    private func requireDatabase() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else {
            throw XCTSkip("rules.db unavailable in this run")
        }
    }

    // MARK: - The ids are real

    func testEveryAbilityIdExistsInTheRules() throws {
        try requireDatabase()
        for ability in CombatAbility.allCases {
            XCTAssertNotNil(
                RulesDatabase.shared.lookup(id: ability.rawValue)?.name,
                "\(ability) claims \(ability.rawValue), which is not in rules.db"
            )
        }
    }

    /// The names, written out, so an id that quietly points at a different
    /// ability fails here rather than at the table.
    func testEveryAbilityIdNamesTheAbilityItIsCalled() throws {
        try requireDatabase()
        let expected: [CombatAbility: String] = [
            .aufmerksamkeit: "Aufmerksamkeit",
            .belastungsgewoehnung: "Belastungsgewöhnung",
            .beidhaendigerKampf: "Beidhändiger Kampf",
            .berittenerKampf: "Berittener Kampf",
            .finte: "Finte",
            .schildspalter: "Schildspalter",
            .vorstoss: "Vorstoß",
            .wuchtschlag: "Wuchtschlag",
            .gezielterAngriff: "Gezielter Angriff",
            .gezielterSchuss: "Gezielter Schuss",
            .golgaritenStil: "Golgariten-Stil",
            .plaenklerFormation: "Plänkler-Formation",
        ]
        XCTAssertEqual(expected.count, CombatAbility.allCases.count, "An ability has no expected name")
        for ability in CombatAbility.allCases {
            XCTAssertEqual(
                RulesDatabase.shared.lookup(id: ability.rawValue)?.name,
                expected[ability], ability.rawValue
            )
        }
    }

    // MARK: - Whichever list the importer picked

    private func hero(with ability: CombatAbility, inCombatList: Bool, tier: Int? = nil) -> Hero {
        let hero = Hero(name: "Testheld")
        let trait = HeroTrait(ruleId: ability.rawValue, name: "\(ability)", tier: tier)
        if inCombatList {
            hero.combatSpecialAbilities = [trait]
        } else {
            hero.generalSpecialAbilities = [trait]
        }
        return hero
    }

    /// The bug that hid Plänkler-Formation: which list a trait lands in is a
    /// property of the *data*, and the lookup must not care.
    func testAnAbilityIsFoundInEitherList() {
        for ability in CombatAbility.allCases {
            for inCombatList in [true, false] {
                XCTAssertTrue(
                    hero(with: ability, inCombatList: inCombatList).has(ability),
                    "\(ability) is invisible when filed in the \(inCombatList ? "combat" : "general") list"
                )
            }
        }
    }

    func testTierIsReadFromEitherList() {
        for inCombatList in [true, false] {
            let hero = hero(with: .wuchtschlag, inCombatList: inCombatList, tier: 2)
            XCTAssertEqual(hero.wuchtschlagTier, 2)
        }
    }

    /// Used to be found by `name.contains("Beidhändiger Kampf")`, which a renamed
    /// or untranslated export defeats.
    func testBeidhaendigerKampfIsReadById() {
        let hero = hero(with: .beidhaendigerKampf, inCombatList: true, tier: 2)
        XCTAssertEqual(hero.beidhaendigerKampfLevel, 2)
        XCTAssertEqual(hero.dualAttackPenalty, 0)
        XCTAssertEqual(Hero(name: "Ohne").dualAttackPenalty, -2)
        XCTAssertEqual(self.hero(with: .beidhaendigerKampf, inCombatList: false, tier: nil).dualAttackPenalty, -1)
    }

    /// An ability with no tier in the export is tier I, not tier 0 — 0 reads as
    /// "does not have it" everywhere else.
    func testAnUntieredAbilityCountsAsTierOne() {
        XCTAssertEqual(hero(with: .finte, inCombatList: false, tier: nil).finteTier, 1)
    }

    func testAnAbsentAbilityIsAbsent() {
        let bare = Hero(name: "Ohne")
        for ability in CombatAbility.allCases {
            XCTAssertFalse(bare.has(ability), "\(ability)")
        }
        XCTAssertEqual(bare.wuchtschlagTier, 0)
    }
}
