import XCTest
@testable import Hesindion

/// The importer used to file a Sonderfertigkeit as combat when `rules.db` had a
/// combat-scoped *effects* row for it. That table covered ten of the 226 combat
/// abilities, so Plänkler-Formation, Gezielter Angriff and 214 others landed in
/// the general list. Optolith's group id is the classification the data
/// actually carries; these tests hold the enum to the table it came from.
final class SpecialAbilityGroupTests: XCTestCase {

    private func requireDatabase() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else {
            throw XCTSkip("rules.db unavailable in this run")
        }
    }

    private static let expected: [SpecialAbilityGroup: String] = [
        .kampf: "Kampf",
        .kampfErweitert: "Kampf (erweitert)",
        .kampfstileBewaffnet: "Kampfstile (bewaffnet)",
        .kampfstileUnbewaffnet: "Kampfstile (unbewaffnet)",
    ]

    func testEveryIdNamesTheGroupItIsCalled() throws {
        try requireDatabase()
        XCTAssertEqual(SpecialAbilityGroup.allCases.count, Self.expected.count)
        for group in SpecialAbilityGroup.allCases {
            XCTAssertEqual(RulesDatabase.shared.lookupGroupName(group.rawValue), Self.expected[group], "\(group)")
        }
    }

    func testAGroupOutsideTheFourIsNotCombat() {
        XCTAssertFalse(SpecialAbilityGroup.isCombat(groupId: 1))    // Allgemein
        XCTAssertFalse(SpecialAbilityGroup.isCombat(groupId: nil))
        XCTAssertTrue(SpecialAbilityGroup.isCombat(groupId: 3))
    }

    /// Plänkler-Formation (SA_884) is the ability that hid: no effects row, so
    /// it went to the general list. Boronmir carries it.
    func testTheImporterFilesEveryCombatGroupAbilityAsCombat() throws {
        try requireDatabase()
        let hero = try TestData.importBoronmir(into: TestData.makeContainer())
        XCTAssertTrue(hero.combatSpecialAbilities.contains { $0.ruleId == "SA_884" },
                      "Plänkler-Formation is filed as general")
        for trait in hero.generalSpecialAbilities {
            let groupId = RulesDatabase.shared.lookup(id: trait.ruleId)?.groupId
            XCTAssertFalse(SpecialAbilityGroup.isCombat(groupId: groupId),
                           "\(trait.ruleId) \(trait.name) is a combat ability filed as general")
        }
    }
}
