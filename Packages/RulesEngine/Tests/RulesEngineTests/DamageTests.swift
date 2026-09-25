import XCTest
@testable import RulesEngine

/// Task 32, the damage domain (trefferzonen, trefferzonen-ruestungsschutz), on the fixture book
/// `Fixtures/damage-rules.json` (source: `Tests/FixtureRules/damage`, rebuilt by
/// `make rules-engine-fixture`).
final class DamageTests: XCTestCase {
    private static let book: RuleBook = {
        let url = Bundle.module.url(forResource: "damage-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    private let engine = Engine(book: DamageTests.book)

    private func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }

    private func situation(owned: [String: Int] = [:], facts: [String: JSONValue] = [:],
                           base: [String: Int] = [:]) -> Situation {
        Situation(owned: owned.mapValues { OwnedRule(level: $0) },
                  facts: facts.sorted { $0.key < $1.key }.map {
                      Fact(name: $0.key, value: $0.value, owner: Vocabulary.owner(ofFact: $0.key) ?? .sheet)
                  }, base: base)
    }

    // MARK: - The piece worn in a zone

    func testAZonesRSIsTheRSOfThePieceWornThereFromTheArmourRows() throws {
        let b = engine.evaluate(Query("rs(zone: kopf)"), in: situation(facts: ["loadout.armourPiece.kopf": "Platte"]))
        XCTAssertEqual(b.result, 6)
        let base = try XCTUnwrap(b.base)
        XCTAssertEqual(base.origin, ref("dm-zones.Z2"))
        XCTAssertTrue(base.via.contains(ref("dm-zones.Z1")), "the armour rows' clause is behind the value")
        XCTAssertTrue(base.facts.contains { $0.name == "loadout.armourPiece.kopf" && $0.value == "Platte" })
        XCTAssertEqual(b.questions.map(\.fact), [])
    }

    func testAZoneWithoutAPieceHasRS0() {
        let b = engine.evaluate(Query("rs(zone: kopf)"), in: situation(facts: ["loadout.armourPiece.kopf": .null]))
        XCTAssertEqual(b.result, 0)
    }

    func testAnUnstatedPieceIsAsked() {
        let b = engine.evaluate(Query("rs(zone: kopf)"), in: situation())
        XCTAssertNil(b.result)
        XCTAssertEqual(b.questions.map(\.fact), ["loadout.armourPiece.kopf"])
    }

    func testAStatedItemFieldWinsOverTheArmourRows() {
        let b = engine.evaluate(Query("rs(zone: kopf)"),
                                in: situation(facts: ["loadout.armourPiece.kopf": "Platte", "item.Platte.rs": 5]))
        XCTAssertEqual(b.result, 5)
    }

    func testTheArmoursRowGivesAnUnstatedSlotField() {
        let b = engine.evaluate(Query("ini"), in: situation(facts: ["loadout.armour": "Leder"]))
        XCTAssertEqual(b.result, 1)
        XCTAssertTrue(b.base?.via.contains(ref("dm-zones.Z1")) ?? false)
    }

    // MARK: - A combination a together forbid refuses

    func testAChoiceATogetherForbidRefusesBesideItsHoldersIsNotTaken() {
        let s = situation(owned: ["dm-under": 1, "dm-aim": 1], facts: ["choice.under": true, "choice.aim": true], base: ["at": 14])
        let b = engine.evaluate(Query("at"), in: s)
        XCTAssertEqual(b.lines.map(\.origin), [ref("dm-under.U1")], "the Spezialmanöver beside Unterlaufen is not taken")
        XCTAssertEqual(b.result, 15)
        let alone = engine.evaluate(Query("at"), in: situation(owned: ["dm-aim": 1], facts: ["choice.aim": true], base: ["at": 14]))
        XCTAssertEqual(alone.result, 12)
    }

    func testAnItemNoRowNamesAsksForTheField() {
        let b = engine.evaluate(Query("rs(zone: kopf)"), in: situation(facts: ["loadout.armourPiece.kopf": "Mithril"]))
        XCTAssertNil(b.result)
        XCTAssertEqual(b.questions.map(\.fact), ["loadout.armourPiece.kopf.rs"])
    }
}
