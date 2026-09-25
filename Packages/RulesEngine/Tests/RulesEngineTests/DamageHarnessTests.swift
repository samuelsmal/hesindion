import XCTest
@testable import RulesEngine

/// Task 32's harness bridges (R62): the shapes of the damage situations (trefferzonen) the
/// matcher now compares, on the fixture book `Fixtures/damage-rules.json`.
final class DamageHarnessTests: XCTestCase {
    private func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }

    private static let book: RuleBook = {
        let url = Bundle.module.url(forResource: "damage-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    private let engine = Engine(book: DamageHarnessTests.book)

    private func situation(_ fields: String) throws -> CompiledSituation {
        var object: [String: Any] = ["id": "T.1", "file": "test.yaml", "owned": [:], "facts": [], "base": [:], "rolls": [],
                                     "sequence": [], "expect": [], "expectSituation": [:], "pending": []]
        let given = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(fields.utf8)) as? [String: Any])
        object.merge(given) { _, new in new }
        return try JSONDecoder().decode(CompiledSituation.self, from: JSONSerialization.data(withJSONObject: object))
    }

    // MARK: - legal.combinations: the refused choices' offers

    /// A refused combination rests on the rulings of its refusing entries and, as a `notOffered`
    /// choice does, on those of its choices' offers (TZ.17: Gezielter Angriff's halving ruling).
    func testARefusedCombinationRestsOnItsChoicesOfferRulings() throws {
        let s = try situation(#"{"owned": {"dm-under": {"level": 1}, "dm-aim": {"level": 1}}, "expectSituation": {"legal": {"combinations": [{"choices": ["under", "aim"], "allowed": false, "because": "dm-under.U3", "ruling": "dm-aim.halving"}]}}}"#)
        XCTAssertEqual(Matcher.match(s, engine: engine), [])
        let other = try situation(#"{"owned": {"dm-under": {"level": 1}, "dm-aim": {"level": 1}}, "expectSituation": {"legal": {"combinations": [{"choices": ["under", "aim"], "allowed": false, "ruling": "dm-aim.other"}]}}}"#)
        XCTAssertEqual(Matcher.match(other, engine: engine).map(\.kind), [.legal])
    }
}
