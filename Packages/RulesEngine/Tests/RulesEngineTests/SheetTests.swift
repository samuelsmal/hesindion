import XCTest
@testable import RulesEngine

/// Task 30, the derived values and the sheet, on the fixture book `Fixtures/sheet-rules.json`
/// (source: `Tests/FixtureRules/sheet`, rebuilt by `make rules-engine-fixture`).
final class SheetTests: XCTestCase {
    private static let book: RuleBook = {
        let url = Bundle.module.url(forResource: "sheet-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    private let engine = Engine(book: SheetTests.book)

    private func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }

    private func situation(owned: [String: Int] = [:], facts: [String: JSONValue] = [:],
                           base: [String: Int] = [:]) -> Situation {
        Situation(owned: owned.mapValues { OwnedRule(level: $0) },
                  facts: facts.sorted { $0.key < $1.key }.map {
                      Fact(name: $0.key, value: $0.value, owner: Vocabulary.owner(ofFact: $0.key) ?? .sheet)
                  }, base: base)
    }

    private func lines(_ b: Breakdown, from origin: String) -> [Line] {
        b.lines.filter { $0.origin == ref(origin) }
    }

    private let plate: [String: JSONValue] = ["loadout.armour": "Platte", "loadout.armour.belastung": 3]

    // MARK: - belastung.source

    func testBelastungFromWornArmourHasTheSourceArmour() {
        let b = engine.evaluate(Query("level(rule: sh-load)"), in: situation(owned: ["sh-habit": 1], facts: plate))
        XCTAssertEqual(b.result, 2)
        let levelAs = b.lines.first { $0.kind == .levelAs }
        XCTAssertEqual(levelAs?.facts.first { $0.name == "belastung.source" }?.value, "armour")
        XCTAssertEqual(levelAs?.facts.first { $0.name == "belastung.source" }?.owner, .derived)
        XCTAssertEqual(b.questions.map(\.fact), [])
    }

    func testWithoutAStatedArmourTheSourceAsksForTheArmour() {
        let b = engine.evaluate(Query("level(rule: sh-load)"),
                                in: situation(owned: ["sh-habit": 1], facts: ["loadout.armour.belastung": 3]))
        XCTAssertEqual(b.result, 3)
        XCTAssertEqual(b.notApplied.first { $0.origin == ref("sh-habit.G1") }?.reason, .unknownFact)
        XCTAssertEqual(b.questions.map(\.fact), ["loadout.armour"])
    }

    // MARK: - A derived Stufe above the rule's highest

    func testADerivedStufeIsCappedAtTheRulesHighest() throws {
        let facts: [String: JSONValue] = ["loadout.armour": "Turnier", "loadout.armour.belastung": 5]
        let b = engine.evaluate(Query("level(rule: sh-load)"), in: situation(facts: facts))
        XCTAssertEqual(b.result, 4)
        let base = try XCTUnwrap(b.base)
        XCTAssertEqual(base.value, 4)
        XCTAssertEqual(base.parts.map(\.value), [5, -1])
        XCTAssertEqual(base.parts.last?.kind, .capped)
        XCTAssertEqual([base.parts.last?.was, base.parts.last?.now], [5, 4])
        // hero.levelOf reads the capped Stufe too.
        XCTAssertEqual(engine.evaluation(situation(facts: facts)).baseLevel(of: "sh-load", depth: 0).value, 4)
    }

    // MARK: - The rulings of the useLevels a line rests on

    func testALineCarriesTheRulingsOfTheUseLevelsInItsVia() throws {
        let b = engine.evaluate(Query("at"), in: situation(owned: ["sh-habit": 1], facts: plate, base: ["at": 14]))
        let line = try XCTUnwrap(lines(b, from: "sh-load.L1").first)
        XCTAssertEqual(line.value, -2)
        XCTAssertEqual(line.via, [ref("sh-habit.G1")])
        XCTAssertEqual(line.rulings, ["sh-habit.shift"])
    }

    // MARK: - Action effects act at the Stufe the rule acts at

    func testAGainReadsTheStufeAfterTheUseLevels() {
        let layer = ActionLayer(engine: engine)
        let heavy: [String: JSONValue] = ["loadout.armour": "Gestech", "loadout.armour.belastung": 4]
        let alone = layer.perform(.settle, in: situation(facts: heavy))
        XCTAssertEqual(alone.events.map(\.rule), ["sh-helpless"])
        XCTAssertEqual(alone.events.first?.rulings, ["sh-load.jouster"])
        let used = layer.perform(.settle, in: situation(owned: ["sh-habit": 1], facts: heavy))
        XCTAssertEqual(used.events, [])
    }
}

extension SheetTests {
    // MARK: - A choice nobody made

    func testAnUnmadeChoiceReadsItsOffersDefault() throws {
        let b = engine.evaluate(Query("aw"), in: situation(facts: ["hero.mounted": true], base: ["aw": 7]))
        let line = try XCTUnwrap(lines(b, from: "sh-mount.R6").first)
        XCTAssertEqual(line.value, -2)
        XCTAssertEqual(line.facts.first { $0.name == "choice.jumpOff" }?.value, false)
        let jumped = engine.evaluate(Query("aw"), in: situation(facts: ["hero.mounted": true, "choice.jumpOff": true],
                                                                base: ["aw": 7]))
        XCTAssertEqual(lines(jumped, from: "sh-mount.R6"), [])
    }

    // MARK: - A check query names its check

    func testACheckQuerysContextStatesTheKindOfCheck() throws {
        let spell = engine.evaluate(Query("check.modifier(spell: any)"), in: situation(facts: plate))
        XCTAssertEqual(lines(spell, from: "sh-load.L1").map(\.value), [-3])
        let talent = engine.evaluate(Query("check.modifier(talent: TAL_3)"), in: situation(facts: plate))
        XCTAssertEqual(lines(talent, from: "sh-load.L1"), [])
        XCTAssertEqual(talent.notApplied.first { $0.origin == ref("sh-load.L1") }?.reason, .conditionFalse)
    }
}
