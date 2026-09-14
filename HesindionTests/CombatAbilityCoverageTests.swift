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
/// 2. **The importer filed it out of reach.** An SA goes to
///    `combatSpecialAbilities` or `generalSpecialAbilities` depending on whether
///    `rules.db` has a combat-scoped effect for it, and for three of them it has
///    none — so Plänkler-Formation, Gezielter Angriff and Gezielter Schuss all
///    landed in the general list while every lookup searched the combat one.
/// 3. **Nothing implements it.** `RuleEffectModifiers` builds modifiers straight
///    from the effects table, which covers an ability that is a flat number
///    against a named value and silently covers *nothing* for one that is not.
///
/// None of that is visible on screen — the ability is on the hero sheet, and the
/// roll is simply a little too low. So it is checked here instead, and an
/// ability that is neither engine-driven nor deliberately wired fails a test.
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

    // MARK: - Something actually implements it

    /// Either the effects table drives it or the app wires it deliberately, and
    /// the `byHand` case has to say why it cannot be a row in the table.
    func testEveryAbilityIsEitherEngineDrivenOrDeliberatelyWired() throws {
        try requireDatabase()
        for ability in CombatAbility.allCases {
            let combatEffects = RulesDatabase.shared
                .lookupEffects(ruleId: ability.rawValue)
                .filter { $0.scope == "combat" }

            switch ability.wiring {
            case .fromEffects:
                XCTAssertFalse(
                    combatEffects.isEmpty,
                    "\(ability) claims the engine drives it, but rules.db has no combat effect for it"
                )
            case .byHand(let reason):
                XCTAssertFalse(reason.isEmpty, "\(ability) is hand-wired without saying why")
            }
        }
    }

    /// The other direction: every combat Sonderfertigkeit the sample hero
    /// carries is one the app knows about. Importing a hero with an ability that
    /// nothing implements should fail here, not go unnoticed at the table.
    ///
    /// `SA_27` and `SA_29` are the carriers for Schriften and Sprachen — the
    /// importer unpacks them into their own lists and they never become traits.
    func testTheSampleHeroCarriesNoAbilityTheAppIgnores() throws {
        try requireDatabase()
        let notAbilities: Set<String> = ["SA_27", "SA_29"]
        let known = Set(CombatAbility.allCases.map(\.rawValue))

        let hero = try TestData.importBoronmir(into: TestData.makeContainer())
        let carried = (hero.combatSpecialAbilities + hero.generalSpecialAbilities)
            .map(\.ruleId)
            .filter { !notAbilities.contains($0) }

        XCTAssertFalse(carried.isEmpty, "The sample hero should carry some Sonderfertigkeiten")
        for ruleId in carried {
            XCTAssertTrue(
                known.contains(ruleId),
                "\(ruleId) (\(RulesDatabase.shared.lookup(id: ruleId)?.name ?? "?")) is on the hero sheet "
                    + "and nothing in the app does anything with it"
            )
        }
    }
}
