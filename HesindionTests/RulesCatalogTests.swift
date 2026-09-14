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

    func testTheCountsAddUpToTheRules() throws {
        try requireDatabase()
        let expected = RulesDatabase.shared.ruleCount()
        XCTAssertGreaterThan(expected, 0)
        let counts = RulesDatabase.shared.catalogStatusCounts()
        let total = counts.values.reduce(0, +)
        XCTAssertEqual(total, expected, "every rule, counted once")
    }

    /// A `byHand` pointer names a file and a symbol; both must exist, or the
    /// catalog describes code that is not there. The Python build checks the
    /// same pattern (`catalog._check_pointer`); the two must stay identical.
    /// `note`/`pointer`/`reviewed*` are otherwise unexercised until Task 7 adds
    /// byHand entries to the catalog.
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
}
