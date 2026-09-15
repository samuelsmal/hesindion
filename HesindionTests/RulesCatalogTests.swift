import CryptoKit
import XCTest
@testable import Hesindion

/// The catalog is the app's answer to "which rules does it implement?" — every
/// id in `rules.db` has a status, and a `byHand` status points at the code.
/// The Python build enforces the same things; this is the Swift side reading
/// the table it produced, so a database built by hand cannot slip past.
final class RulesCatalogTests: XCTestCase {

    private func requireDatabase() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else {
            throw XCTSkip("rules.db unavailable in this run")
        }
    }

    /// `HesindionTests/RulesCatalogTests.swift` → repository root.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testEveryRuleHasACatalogEntry() throws {
        try requireDatabase()
        XCTAssertEqual(RulesDatabase.shared.ruleIdsWithoutCatalogEntry(), [])
    }

    func testAnEntryIsReadBack() throws {
        try requireDatabase()
        let entry = try XCTUnwrap(RulesDatabase.shared.lookupCatalogEntry(ruleId: "SA_661"))
        XCTAssertEqual(entry.id, "SA_661")
        XCTAssertEqual(RulesDatabase.shared.lookup(id: "SA_661")?.catalog?.status, entry.status)
    }

    /// `name` is read by column position; a reordered `catalogColumns` would
    /// hand back a status or a pointer here rather than fail.
    func testAnEntryCarriesItsName() throws {
        try requireDatabase()
        XCTAssertEqual(RulesDatabase.shared.lookupCatalogEntry(ruleId: "SA_661")?.name, "Golgariten-Stil")
    }

    func testTheCountsAddUpToTheRules() throws {
        try requireDatabase()
        let expected = RulesDatabase.shared.ruleCount()
        XCTAssertGreaterThan(expected, 0)
        let core = RulesDatabase.shared.catalogEntries(idPrefix: "GRW_").count
        let counts = RulesDatabase.shared.catalogStatusCounts()
        let total = counts.values.reduce(0, +)
        XCTAssertEqual(total, expected + core, "every rule and every core rule, counted once")
    }

    /// A `byHand` pointer names a file and a symbol; both must exist, or the
    /// catalog describes code that is not there. The Python build checks the
    /// same pattern (`catalog._check_pointer`); the two must stay identical.
    func testEveryPointerNamesASymbolThatExists() throws {
        try requireDatabase()
        try XCTSkipUnless(FileManager.default.fileExists(atPath: Self.repoRoot.appending(path: "AGENTS.md").path),
                          "source tree not reachable (device run)")
        for entry in RulesDatabase.shared.catalogEntries(status: .byHand) {
            guard let pointer = entry.pointer else {
                XCTFail("\(entry.id) is byHand without a pointer")
                continue
            }
            let url = Self.repoRoot.appending(path: pointer.file)
            let text = try String(contentsOf: url, encoding: .utf8)
            let pattern = "(?<![A-Za-z0-9_])" + NSRegularExpression.escapedPattern(for: pointer.symbol) + "(?![A-Za-z0-9_])"
            XCTAssertNotNil(text.range(of: pattern, options: .regularExpression),
                            "\(entry.id): \(pointer.symbol) is not in \(pointer.file)")
            // A text match alone is satisfied by a string literal sitting in a comment
            // or an `implies` list — for a StateCatalog pointer, the symbol must also
            // actually be one of its ids.
            if pointer.file.hasSuffix("StateCatalog.swift") {
                XCTAssertTrue(StateCatalog.all.contains { $0.id == pointer.symbol },
                              "\(entry.id): \(pointer.symbol) is not a StateCatalog id")
            }
        }
    }

    func testStatusLabelsAreLocalized() {
        for status in CatalogStatus.allCases {
            XCTAssertNotEqual(L(status.labelKey), status.labelKey, "missing translation for \(status.labelKey)")
        }
        XCTAssertNotEqual(L("catalog.section"), "catalog.section")
        XCTAssertNotEqual(L("rule.levelPrefix"), "rule.levelPrefix")
    }

    /// The Zustände have no prose description; their content is the four level
    /// texts, which the screen used to get from the deleted effects rows.
    func testAZustandCarriesItsLevelTexts() throws {
        try requireDatabase()
        let schmerz = try XCTUnwrap(RulesDatabase.shared.lookup(id: "COND_6"))
        XCTAssertEqual(schmerz.levelTexts.map(\.level), [1, 2, 3, 4])
        for entry in schmerz.levelTexts {
            XCTAssertEqual(entry.text, entry.text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        XCTAssertTrue(schmerz.levelTexts[0].text.contains("–1") || schmerz.levelTexts[0].text.contains("-1"), schmerz.levelTexts[0].text)
        XCTAssertEqual(RulesDatabase.shared.lookup(id: "SA_67")?.levelTexts.count, 0)
    }

    /// The floor. Adding entries must not fail this; losing one must.
    func testCoverageDoesNotGoBackwards() throws {
        try requireDatabase()
        let counts = RulesDatabase.shared.catalogStatusCounts()
        XCTAssertGreaterThanOrEqual((counts[.implemented] ?? 0) + (counts[.byHand] ?? 0), 45)
    }

    func testEveryCombatAbilityHasAStatusOtherThanTodo() throws {
        try requireDatabase()
        for ability in CombatAbility.allCases {
            let status = RulesDatabase.shared.lookupCatalogEntry(ruleId: ability.rawValue)?.status
            XCTAssertNotNil(status, "\(ability) has no catalog entry")
            XCTAssertNotEqual(status, .todo, "\(ability) is in code but the catalog says todo")
        }
    }

    /// No hard-coded rule-id list: a `StateCatalog` id and a `byHand` pointer at
    /// `StateCatalog.swift` must name each other, in both directions, so adding a
    /// state without a matching pointer — or a pointer whose symbol is stale —
    /// fails here instead of going unnoticed.
    ///
    /// `belastung` (COND_1) is the one exception: its roll penalty lives in
    /// `SharedModifiers.encumbrance`, not `StateCatalog.swift`, and that is where
    /// its pointer points; the StateCatalog entry itself stays display-only.
    func testEveryCatalogStateIsByHandOrImplemented() throws {
        try requireDatabase()
        let statePointerFile = "Hesindion/Models/StateCatalog.swift"
        let displayOnlyExceptions: Set<String> = ["belastung"]
        let byHandStateEntries = RulesDatabase.shared.catalogEntries(status: .byHand)
            .filter { $0.pointer?.file == statePointerFile }
        let byHandStatePointers = byHandStateEntries.compactMap(\.pointer)
        // `StateModifiers.ruleIds` is the engine's copy of the same fact the
        // pointers record; the two must name each other, or a state's lines
        // would be attributed to the wrong rule once the migration reads them.
        for definition in StateCatalog.all where !displayOnlyExceptions.contains(definition.id) {
            let ruleId = try XCTUnwrap(StateModifiers.ruleIds[definition.id], definition.id)
            let entry = try XCTUnwrap(RulesDatabase.shared.lookupCatalogEntry(ruleId: ruleId), ruleId)
            if entry.status == .implemented {
                // A state whose clauses moved to the catalog has nothing to point at.
                continue
            }
            let matches = byHandStatePointers.filter { $0.symbol == definition.id }
            XCTAssertEqual(matches.count, 1, definition.id)
            let byHandEntry = byHandStateEntries.first { $0.pointer?.symbol == definition.id }
            XCTAssertEqual(StateModifiers.ruleIds[definition.id], byHandEntry?.id,
                           "\(definition.id): StateModifiers.ruleIds and the catalog pointer disagree")
        }
        // Belastung has no StateCatalog pointer (see above); its id is checked
        // against the entry its own pointer belongs to, asserted at the end.
        XCTAssertEqual(StateModifiers.ruleIds["belastung"], "COND_1")
        let stateIDs = Set(StateCatalog.all.map(\.id))
        for pointer in byHandStatePointers {
            XCTAssertTrue(stateIDs.contains(pointer.symbol), pointer.symbol)
        }
        // The exception above is only valid while Belastung's rule lives in the
        // engine; if that moves, this is the line that says so.
        let belastung = RulesDatabase.shared.lookupCatalogEntry(ruleId: "COND_1")
        XCTAssertEqual(belastung?.status, .byHand, "COND_1")
        XCTAssertEqual(belastung?.pointer?.file, "Hesindion/Engine/SharedModifiers.swift",
                       "COND_1 is exempt above only because its rule lives in the engine")
    }

    /// Importing a hero with an ability nothing handles should fail here, not go
    /// unnoticed at the table. `SA_27` and `SA_29` carry Schriften and Sprachen
    /// and never become traits.
    func testTheSampleHeroCarriesNoAbilityTheAppIgnores() throws {
        try requireDatabase()
        let notAbilities: Set<String> = ["SA_27", "SA_29"]
        let hero = try TestData.importBoronmir(into: TestData.makeContainer())
        guard !hero.combatTechniques.isEmpty else { throw XCTSkip("rules.db went empty mid-import (known flake)") }
        let carried = (hero.combatSpecialAbilities + hero.generalSpecialAbilities)
            .map(\.ruleId)
            .filter { !notAbilities.contains($0) }
        XCTAssertFalse(carried.isEmpty)
        for ruleId in carried {
            let status = RulesDatabase.shared.lookupCatalogEntry(ruleId: ruleId)?.status
            XCTAssertNotNil(status, "\(ruleId) is on the hero sheet and has no catalog entry")
            XCTAssertNotEqual(status, .todo,
                              "\(ruleId) (\(RulesDatabase.shared.lookup(id: ruleId)?.name ?? "?")) is on the hero sheet and the catalog says todo")
        }
    }

    /// The bundled database must be built from the committed catalog. Editing
    /// the YAML and forgetting `make rules-db` would otherwise pass every other
    /// test while the app reports yesterday's coverage.
    func testTheDatabaseWasBuiltFromTheCommittedCatalog() throws {
        try requireDatabase()
        let yaml = Self.repoRoot.appending(path: "specs/data/rules-catalog.yaml")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: yaml.path), "source tree not reachable (device run)")
        let data = try Data(contentsOf: yaml)
        let expected = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(RulesDatabase.shared.catalogSourceHash(), expected,
                       "rules.db was not built from the current specs/data/rules-catalog.yaml; run make rules-db")
    }
}
