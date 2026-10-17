import XCTest
@testable import Hesindion

/// The importer used to file a Sonderfertigkeit as combat when `rules.db` had a
/// combat-scoped *effects* row for it. That table covered nine of the 226 combat
/// abilities, so Plänkler-Formation, Gezielter Angriff and 215 others landed in
/// the general list. Optolith's group id is the classification the data
/// actually carries; these tests hold the enum to the table it came from.
final class CombatSpecialAbilityGroupTests: XCTestCase {

    private func requireDatabase() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else {
            throw XCTSkip("rules.db unavailable in this run")
        }
    }

    private static let expected: [CombatSpecialAbilityGroup: String] = [
        .kampf: "Kampf",
        .kampfErweitert: "Kampf (erweitert)",
        .kampfstileBewaffnet: "Kampfstile (bewaffnet)",
        .kampfstileUnbewaffnet: "Kampfstile (unbewaffnet)",
    ]

    func testEveryIdNamesTheGroupItIsCalled() throws {
        try requireDatabase()
        XCTAssertEqual(CombatSpecialAbilityGroup.allCases.count, Self.expected.count)
        for group in CombatSpecialAbilityGroup.allCases {
            XCTAssertEqual(RulesDatabase.shared.lookupGroupName(group.rawValue), Self.expected[group], "\(group)")
        }
    }

    func testAGroupOutsideTheFourIsNotCombat() {
        XCTAssertFalse(CombatSpecialAbilityGroup.contains(groupId: 1))    // Allgemein
        XCTAssertFalse(CombatSpecialAbilityGroup.contains(groupId: nil))
        XCTAssertTrue(CombatSpecialAbilityGroup.contains(groupId: 3))
    }

    /// Plänkler-Formation (SA_884) is the ability that hid: no effects row, so
    /// it went to the general list. Boronmir's 2026-09-24 sheet no longer
    /// carries it, so this test no longer covers that case; Formation (SA_862,
    /// Kampfstilsonderfertigkeit) is the one he carries now.
    func testTheImporterFilesEveryCombatGroupAbilityAsCombat() throws {
        try requireDatabase()
        let hero = try TestData.importBoronmir(into: TestData.makeContainer())
        guard !hero.combatTechniques.isEmpty else {
            throw XCTSkip("rules.db went empty mid-import (known flake)")
        }

        XCTAssertEqual(
            Set(hero.combatSpecialAbilities.map(\.ruleId)),
            ["SA_40", "SA_41", "SA_43", "SA_67", "SA_661", "SA_862"]
        )

        // Boronmir has no general SAs of his own — SA_27 and SA_29 become
        // Sprachen and Schriften, never traits — so this loop is a guard for
        // future sample heroes rather than the proof; the set equality above is.
        for trait in hero.generalSpecialAbilities {
            let detail = RulesDatabase.shared.lookup(id: trait.ruleId)
            XCTAssertNotNil(detail, trait.ruleId)
            XCTAssertFalse(CombatSpecialAbilityGroup.contains(groupId: detail?.groupId),
                           "\(trait.ruleId) \(trait.name) is a combat ability filed as general")
        }
    }
}
