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
/// 3. **Nothing implements it.** Every ability the app handles is hand-wired;
///    `RuleEffectModifiers` would read the `effects` table but is not wired into
///    `ModifierEngine.shared` and nothing calls it, so having a row there buys an
///    ability nothing at all (issue #27).
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

    /// `wiring` has to be true, not aspirational.
    ///
    /// A `.fromEffects` claim is checked end to end: a hero holding the ability
    /// and nothing else must get a line out of the live `ModifierEngine`. Having
    /// a row in the `effects` table is *not* enough to claim it — five abilities
    /// have combat-scoped rows and none of them reach a roll that way, because
    /// `RuleEffectModifiers` is not wired into the engine (issue #27). Checking
    /// the table instead of the engine is exactly how this field would come to
    /// describe a pipeline that does not run.
    func testAFromEffectsClaimSurvivesTheLiveEngine() {
        for ability in CombatAbility.allCases {
            guard case .fromEffects = ability.wiring else { continue }
            let hero = hero(with: ability, inCombatList: true, tier: 1)
            let lines = CheckDomain.allCases.flatMap { domain in
                ModifierEngine.shared.evaluate(context: ModifierContext(hero: hero, domain: domain))
            }
            XCTAssertFalse(
                lines.isEmpty,
                "\(ability) claims the engine drives it, but a hero holding it gets no line from any domain"
            )
        }
    }

    func testEveryHandWiredAbilitySaysWhatReachesIt() {
        for ability in CombatAbility.allCases {
            guard case .byHand(let note) = ability.wiring else { continue }
            XCTAssertFalse(note.isEmpty, "\(ability) is hand-wired without saying what reaches it")
        }
    }

    /// What the effects table would cover if it were wired up, recorded as a
    /// number so the gap in issue #27 is a measurement and not an impression.
    ///
    /// Deliberately a floor, not an equality: adding rows to `rules.db` should
    /// not fail a test. It fails if coverage goes *backwards*.
    func testTheEffectsTableCoverageIsKnown() throws {
        try requireDatabase()
        let withCombatEffects = CombatAbility.allCases.filter {
            RulesDatabase.shared.lookupEffects(ruleId: $0.rawValue).contains { $0.scope == "combat" }
        }
        XCTAssertGreaterThanOrEqual(
            withCombatEffects.count, 5,
            "Five of the eleven abilities the app handles have a combat-scoped effect row"
        )
        XCTAssertLessThan(
            withCombatEffects.count, CombatAbility.allCases.count,
            "If every ability has a row, the hand-wiring may be removable — see issue #27"
        )
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
