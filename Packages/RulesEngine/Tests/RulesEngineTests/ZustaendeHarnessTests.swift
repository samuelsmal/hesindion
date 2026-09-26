import XCTest
@testable import RulesEngine

/// Task 33's harness bridges (R62): standing up from Liegend (liegend 7.6), on the melee fixture
/// book's `me-prone` (STATE_10.L4's shape).
final class ZustaendeHarnessTests: XCTestCase {
    private static let book: RuleBook = {
        let url = Bundle.module.url(forResource: "melee-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    private let engine = Engine(book: ZustaendeHarnessTests.book)

    private func situation(_ fields: String) throws -> CompiledSituation {
        var object: [String: Any] = ["id": "T.1", "file": "test.yaml", "owned": [:], "facts": [], "base": [:], "rolls": [],
                                     "sequence": [], "expect": [], "expectSituation": [:], "pending": []]
        let given = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(fields.utf8)) as? [String: Any])
        object.merge(given) { _, new in new }
        return try JSONDecoder().decode(CompiledSituation.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private let standing = #"""
        "owned": {"me-prone": {"level": 1}},
        "facts": [{"name": "choice.aufstehen", "value": true, "owner": "player"},
                  {"name": "choice.passierschlagVermeiden", "value": true, "owner": "player"},
                  {"name": "check.kind", "value": "talent", "owner": "player"},
                  {"name": "check.talent", "value": "TAL_4", "owner": "player"},
                  {"name": "check.result", "value": "failure", "owner": "roll"}]
        """#

    /// The event names the choice that gates the effect giving it: the `cleared` comes from the
    /// `gain` gated on `aufstehen` alone, though the clause's check reads the second choice too.
    func testTheTakenChoiceIsTheOneGatingTheEffectOfTheEventsKind() throws {
        let s = try situation("{\(standing), \"expectSituation\": {\"events\": [{\"cleared\": \"me-prone\", \"from\": \"me-prone.L4\"}]}}")
        XCTAssertEqual(StateRunner.taking(s, book: Self.book), .take(choice: "aufstehen"))
    }

    /// The top action's checks take the stated result (`check.result`), as a step's do, so the
    /// check's `onFailure` tell is among the situation's texts; the choice taken was offered
    /// before it was taken.
    func testTheTopActionsCheckTakesTheStatedResultAndTheOfferIsReadBeforeTheTake() throws {
        let s = try situation("{\(standing), \"expectSituation\": {\"events\": [{\"cleared\": \"me-prone\", \"from\": \"me-prone.L4\"}], "
                              + "\"offered\": [{\"choice\": \"aufstehen\", \"from\": \"me-prone.L4\"}], "
                              + "\"texts\": [{\"opponent\": \"passierschlag\", \"from\": \"me-prone.L4\"}]}}")
        let run = StateRunner.run(s, engine: engine, attributes: ["TAL_4": ["MU", "GE", "KK"]])
        let result = Matcher.run(s, engine: engine, hit: run.view)
        XCTAssertEqual(run.mismatches + result.mismatches, [])
        // A passed check tells nothing of its own: the stages' tells (L1's) are no action's texts.
        let passed = try situation("{\(standing.replacingOccurrences(of: "\"failure\"", with: "\"success\"")), "
                                   + "\"expectSituation\": {\"events\": [{\"cleared\": \"me-prone\", \"from\": \"me-prone.L4\"}], \"texts\": []}}")
        let quiet = StateRunner.run(passed, engine: engine, attributes: ["TAL_4": ["MU", "GE", "KK"]])
        XCTAssertEqual(quiet.mismatches + Matcher.run(passed, engine: engine, hit: quiet.view).mismatches, [])
    }
}
