import XCTest
@testable import RulesEngine

final class VocabularyTests: XCTestCase {
    private func json() throws -> [String: Any] {
        let data = try Data(contentsOf: Repo.url("specs/rules/vocabulary.json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testTheEnumsEqualTheJSON() throws {
        let v = try json()
        XCTAssertEqual(v["version"] as? Int, Vocabulary.version)
        XCTAssertEqual(Set((v["verbs"] as! [String: Any]).keys), Set(Verb.allCases.map(\.rawValue)))
        XCTAssertEqual(v["owners"] as? [String], Owner.allCases.map(\.rawValue))
        XCTAssertEqual(v["phases"] as? [String], Phase.allCases.map(\.rawValue))
        XCTAssertEqual(v["reasons"] as? [String], ReasonCode.allCases.map(\.rawValue))
        XCTAssertEqual(v["kinds"] as? [String], RuleKind.allCases.map(\.rawValue))
        XCTAssertEqual(v["spans"] as? [String], Span.allCases.map(\.rawValue))
        XCTAssertEqual(v["pools"] as? [String], Pool.allCases.map(\.rawValue))
        XCTAssertEqual(v["events"] as? [String], EventKind.allCases.map(\.rawValue))
        XCTAssertEqual(v["audiences"] as? [String], Audience.allCases.map(\.rawValue))
        XCTAssertEqual(v["lineKinds"] as? [String], LineKind.allCases.map(\.rawValue))
        XCTAssertEqual(Set((v["targets"] as! [String: Any]).keys), Vocabulary.targets)
        XCTAssertEqual(v["targetPrefixes"] as? [String], Vocabulary.targetPrefixes)
        let facts = (v["facts"] as! [String: [String: String]]).mapValues { $0["owner"]! }
        XCTAssertEqual(facts, Vocabulary.facts.mapValues(\.rawValue))
        let fams = (v["factFamilies"] as! [String: [String: String]]).mapValues { $0["owner"]! }
        XCTAssertEqual(fams, Vocabulary.factFamilies.mapValues(\.rawValue))
    }

    func testEachVerbKnowsItsLayer() throws {
        let verbs = try json()["verbs"] as! [String: [String: Any]]
        for verb in Verb.allCases {
            XCTAssertEqual(verbs[verb.rawValue]?["phase"] as? String, verb.layerName, verb.rawValue)
        }
    }
}
