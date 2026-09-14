import CryptoKit
import XCTest
@testable import Hesindion

/// The vocabulary is closed: what the Swift enums list is what the Python
/// build accepts and what the authoring pipeline may emit. The JSON file is
/// the handshake between the three, so it must equal the enums exactly.
final class RuleVocabularyTests: XCTestCase {

    /// `HesindionTests/RuleVocabularyTests.swift` → repository root.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Record-style: on a mismatch the fresh export is written over the file
    /// and the test fails once, the way a snapshot test records. Commit the
    /// file and rerun.
    func testTheCommittedFileEqualsTheExport() throws {
        let url = Self.repoRoot.appending(path: "specs/data/rule-vocabulary.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: Self.repoRoot.appending(path: "AGENTS.md").path),
                          "source tree not reachable (device run)")
        let fresh = RuleVocabulary.exportJSON()
        let onDisk = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if onDisk != fresh {
            try fresh.write(to: url, atomically: true, encoding: .utf8)
            XCTFail("specs/data/rule-vocabulary.json did not match RuleVocabulary; it has been rewritten — commit it and rerun")
        }
    }

    func testTheExportListsEveryEnum() throws {
        let data = Data(RuleVocabulary.exportJSON().utf8)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let predicates = try XCTUnwrap(root["predicates"] as? [String: Any])
        XCTAssertEqual(Set(predicates.keys), Set(RuleVocabulary.Predicate.allCases.map(\.rawValue)))
        let effects = try XCTUnwrap(root["effects"] as? [String: Any])
        XCTAssertEqual(Set(effects.keys), Set(RuleVocabulary.Effect.allCases.map(\.rawValue)))
        let enums = try XCTUnwrap(root["enums"] as? [String: [String]])
        XCTAssertEqual(enums["domain"], RuleDomain.allCases.map(\.rawValue))
        XCTAssertEqual(enums["target"], RuleVocabulary.Target.allCases.map(\.rawValue))
        XCTAssertEqual(enums["span"], FactSpan.allCases.map(\.rawValue))
        XCTAssertEqual(enums["reach"], WeaponReach.allCases.map(\.rawValue))
        XCTAssertEqual(enums["zone"], HitZone.allCases.map(\.rawValue))
        XCTAssertEqual(enums["kind"], RuleVocabulary.ClauseKind.allCases.map(\.rawValue))
        XCTAssertEqual(root["version"] as? Int, RuleVocabulary.version)
    }

    /// `make rules-db` validated the catalog against the exported vocabulary and
    /// wrote its hash; if the enums moved since, the bundled clauses were checked
    /// against a contract the app no longer has.
    func testTheDatabaseWasBuiltAgainstThisVocabulary() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        let expected = SHA256.hash(data: Data(RuleVocabulary.exportJSON().utf8)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(RulesDatabase.shared.catalogVocabularyHash(), expected,
                       "rules.db was built against another rule-vocabulary.json; run make test-ui (to re-export) and make rules-db")
    }

    func testTheExportIsDeterministicAndEndsWithANewline() {
        let a = RuleVocabulary.exportJSON(), b = RuleVocabulary.exportJSON()
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.hasSuffix("\n"))
    }
}
