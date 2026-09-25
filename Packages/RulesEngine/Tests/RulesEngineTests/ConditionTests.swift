import XCTest
@testable import RulesEngine

final class ConditionTests: XCTestCase {
    private func fact(_ name: String, _ comparison: Comparison) -> Condition { .fact(name: name, comparison: comparison) }

    // MARK: - The brief's example

    func testAnUnknownGMFactMakesAllUnknownAndIsNeverGuessed() {
        let s = Situation(owned: ["SA_862": .init(level: 1)],
                          facts: [Fact(name: "hero.mounted", value: .bool(false), owner: .loadout)])
        let c = Condition.all([fact("hero.mounted", .is(.bool(false))),
                               fact("gmFact.fromBehind", .is(.bool(true)))])
        let r = Conditions.evaluate(c, in: s)
        XCTAssertEqual(r.truth, .unknown)
        XCTAssertEqual(r.unknown, [UnknownFact(name: "gmFact.fromBehind", owner: .gm)])
        XCTAssertEqual(r.used, [FactUse(name: "hero.mounted", value: .bool(false), owner: .loadout)])
    }

    // MARK: - Tri-state all / any / not

    private let yes = Condition.fact(name: "hero.mounted", comparison: .is(.bool(true)))
    private let no = Condition.fact(name: "hero.mounted", comparison: .is(.bool(false)))
    private let unknown = Condition.fact(name: "gmFact.fromBehind", comparison: .is(.bool(true)))
    private let mounted = Situation(owned: [:], facts: [Fact(name: "hero.mounted", value: .bool(true), owner: .loadout)])

    private func truth(_ c: Condition) -> Truth { Conditions.evaluate(c, in: mounted).truth }

    func testAllIsNoIfAnyPartIsNoElseUnknownIfAnyIsUnknownElseYes() {
        XCTAssertEqual(truth(.all([yes, yes])), .yes)
        XCTAssertEqual(truth(.all([yes, unknown])), .unknown)
        XCTAssertEqual(truth(.all([unknown, no])), .no)
        XCTAssertEqual(truth(.all([])), .yes)
    }

    func testAnyIsTheDual() {
        XCTAssertEqual(truth(.any([no, no])), .no)
        XCTAssertEqual(truth(.any([no, unknown])), .unknown)
        XCTAssertEqual(truth(.any([unknown, yes])), .yes)
        XCTAssertEqual(truth(.any([])), .no)
    }

    func testNotOfUnknownIsUnknown() {
        XCTAssertEqual(truth(.not(unknown)), .unknown)
        XCTAssertEqual(truth(.not(yes)), .no)
        XCTAssertEqual(truth(.not(no)), .yes)
    }

    func testADecidedAllOrAnyAsksNothing() {
        let r = Conditions.evaluate(.all([unknown, no]), in: mounted)
        XCTAssertEqual(r.unknown, [], "a no decides the all: the unknown fact needs no question")
        let a = Conditions.evaluate(.any([unknown, yes]), in: mounted)
        XCTAssertEqual(a.unknown, [])
        let u = Conditions.evaluate(.not(.all([yes, unknown])), in: mounted)
        XCTAssertEqual(u.unknown, [UnknownFact(name: "gmFact.fromBehind", owner: .gm)])
    }

    func testAnyAbsentFactIsUnknownWithItsVocabularyOwner() {
        let s = Situation(owned: [:], facts: [])
        for (name, owner) in [("round.parries", Owner.round), ("attr.MU", .sheet), ("check.result", .roll),
                              ("choice.power", .player), ("loadout.weapon", .loadout)] {
            let r = Conditions.evaluate(fact(name, .atLeast(1)), in: s)
            XCTAssertEqual(r.truth, .unknown, name)
            XCTAssertEqual(r.unknown, [UnknownFact(name: name, owner: owner)], name)
        }
    }

    // MARK: - hero.has, ally.has, opponent.has

    func testHeroHasIsYesOrNoAndNeverUnknown() {
        let s = Situation(owned: ["STATE_10": .init(level: 1)], facts: [])
        XCTAssertEqual(Conditions.evaluate(fact("hero.has", .is(.string("STATE_10"))), in: s).truth, .yes)
        XCTAssertEqual(Conditions.evaluate(fact("hero.has", .is(.string("SA_43"))), in: s).truth, .no)
        XCTAssertEqual(Conditions.evaluate(fact("hero.has", .in([.string("STATE_15"), .string("STATE_10")])), in: s).truth, .yes)
        XCTAssertEqual(Conditions.evaluate(fact("hero.has", .in([.string("STATE_15"), .string("STATE_9")])), in: s).truth, .no)
        let r = Conditions.evaluate(fact("hero.has", .is(.string("SA_43"))), in: Situation(owned: [:], facts: []))
        XCTAssertEqual(r.truth, .no)
        XCTAssertEqual(r.unknown, [])
        XCTAssertEqual(r.used.map(\.owner), [.sheet])
    }

    func testOpponentAndAllyHasReadTheirListsAndAreUnknownWithout() {
        let none = Situation(owned: ["STATE_13": .init(level: 1)], facts: [])
        let r = Conditions.evaluate(fact("opponent.has", .is(.string("STATE_13"))), in: none)
        XCTAssertEqual(r.truth, .unknown, "hero owning it says nothing about the opponent")
        XCTAssertEqual(r.unknown, [UnknownFact(name: "opponent.has", owner: .gm)])
        XCTAssertEqual(Conditions.evaluate(fact("ally.has", .is(.string("SA_152"))), in: none).unknown,
                       [UnknownFact(name: "ally.has", owner: .player)])

        let stated = Situation(owned: [:], facts: [
            Fact(name: "opponent.has", value: .array([.string("STATE_13")]), owner: .gm),
            Fact(name: "ally.has", value: .array([]), owner: .player),
        ])
        XCTAssertEqual(Conditions.evaluate(fact("opponent.has", .is(.string("STATE_13"))), in: stated).truth, .yes)
        XCTAssertEqual(Conditions.evaluate(fact("opponent.has", .is(.string("STATE_10"))), in: stated).truth, .no)
        XCTAssertEqual(Conditions.evaluate(fact("ally.has", .is(.string("SA_152"))), in: stated).truth, .no)
    }

    // MARK: - Comparisons

    func testIsAgainstAListValuedFactMeansContains() {
        let s = Situation(owned: [:], facts: [Fact(name: "rulesets", value: .array([.string("fokus.trefferzonen")]), owner: .gm)])
        XCTAssertEqual(Conditions.evaluate(fact("rulesets", .is(.string("fokus.trefferzonen"))), in: s).truth, .yes)
        XCTAssertEqual(Conditions.evaluate(fact("rulesets", .is(.string("fokus.waffeneigenschaften"))), in: s).truth, .no)
        XCTAssertEqual(Conditions.evaluate(fact("rulesets", .in([.string("x"), .string("fokus.trefferzonen")])), in: s).truth, .yes)
    }

    func testNumbersCompare() {
        let s = Situation(owned: [:], facts: [Fact(name: "round.parries", value: .int(2), owner: .round)])
        func t(_ c: Comparison) -> Truth { Conditions.evaluate(fact("round.parries", c), in: s).truth }
        XCTAssertEqual(t(.atLeast(2)), .yes)
        XCTAssertEqual(t(.atLeast(3)), .no)
        XCTAssertEqual(t(.atMost(2)), .yes)
        XCTAssertEqual(t(.atMost(1)), .no)
        XCTAssertEqual(t(.above(1)), .yes)
        XCTAssertEqual(t(.above(2)), .no)
        XCTAssertEqual(t(.below(3)), .yes)
        XCTAssertEqual(t(.below(2)), .no)
        XCTAssertEqual(t(.is(.int(2))), .yes)
        XCTAssertEqual(t(.is(.double(2))), .yes, "2 and 2.0 are one number")
        XCTAssertEqual(t(.in([.int(1), .int(2)])), .yes)
        XCTAssertEqual(t(.in([.int(1), .int(3)])), .no)
    }

    func testAStatedNullIsKnown() {
        let s = Situation(owned: [:], facts: [Fact(name: "loadout.weapon", value: .null, owner: .loadout)])
        let r = Conditions.evaluate(fact("loadout.weapon", .is(.null)), in: s)
        XCTAssertEqual(r.truth, .yes)
        XCTAssertEqual(r.used, [FactUse(name: "loadout.weapon", value: .null, owner: .loadout)])
    }

    // MARK: - level, option, hero.levelOf

    func testLevelIsTheEffectiveLevelPassedIn() {
        let s = Situation(owned: ["COND_1": .init(level: 3)], facts: [])
        XCTAssertEqual(Conditions.evaluate(fact("level", .in([.int(1), .int(2), .int(3)])), in: s, level: 3).truth, .yes)
        XCTAssertEqual(Conditions.evaluate(fact("level", .atLeast(4)), in: s, level: 3).truth, .no)
        XCTAssertEqual(Conditions.evaluate(fact("level", .atLeast(4)), in: s, rule: "COND_1").truth, .no,
                       "without a level passed in, the acting rule's owned level")
        XCTAssertEqual(Conditions.evaluate(fact("level", .atLeast(4)), in: s).unknown,
                       [UnknownFact(name: "level", owner: .sheet)])
    }

    func testOptionIsTheActingRulesOption() {
        let s = Situation(owned: ["SA_60": .init(level: 1, option: .int(2))], facts: [])
        XCTAssertEqual(Conditions.evaluate(fact("option", .is(.int(2))), in: s, rule: "SA_60").truth, .yes)
        XCTAssertEqual(Conditions.evaluate(fact("option", .is(.int(3))), in: s, rule: "SA_60").truth, .no)
        XCTAssertEqual(Conditions.evaluate(fact("option", .is(.int(2))), in: s).truth, .unknown)
    }

    func testLevelOfIsTheOwnedStufe() {
        let s = Situation(owned: ["COND_6": .init(level: 4)], facts: [])
        let r = Conditions.evaluate(fact("hero.levelOf.COND_6", .is(.int(4))), in: s)
        XCTAssertEqual(r.truth, .yes)
        XCTAssertEqual(r.used, [FactUse(name: "hero.levelOf.COND_6", value: .int(4), owner: .derived)])
        XCTAssertEqual(Conditions.evaluate(fact("hero.levelOf.COND_6", .in([.int(2), .int(3)])), in: s).truth, .no)
        XCTAssertEqual(Conditions.evaluate(fact("hero.levelOf.COND_2", .is(.int(1))), in: s).truth, .no,
                       "a Zustand the hero does not have is at Stufe 0: the sheet is complete")
    }

    func testTheOtherDerivedFactsStayUnknown() {
        let s = Situation(owned: ["COND_6": .init(level: 4)], facts: [])
        for name in ["hero.conditionLevels", "fw.current", "hit.overWundschwelle"] {
            XCTAssertEqual(Conditions.evaluate(fact(name, .atLeast(1)), in: s).truth, .unknown, name)
        }
    }

    // MARK: - Situation

    func testTheCompiledSituationShapeDecodes() throws {
        let json = """
        {"id": "x", "owned": {"SA_60": {"level": 1, "option": 2}, "SA_9": {"level": 1, "option": "TAL_1", "option2": 3}},
         "facts": [{"name": "attr.MU", "owner": "sheet", "value": 14}, {"name": "loadout.weapon", "owner": "loadout", "value": null}],
         "base": {"at": 14, "pa(with: shield)": 9}, "rolls": [3, 17], "expect": [], "pending": []}
        """
        let s = try JSONDecoder().decode(Situation.self, from: Data(json.utf8))
        XCTAssertEqual(s.owned["SA_60"], OwnedRule(level: 1, option: .int(2)))
        XCTAssertEqual(s.owned["SA_9"], OwnedRule(level: 1, option: .string("TAL_1"), option2: .int(3)))
        XCTAssertEqual(s.facts["attr.MU"], Fact(name: "attr.MU", value: .int(14), owner: .sheet))
        XCTAssertEqual(s.facts["loadout.weapon"]?.value, .null)
        XCTAssertEqual(s.base, ["at": 14, "pa(with: shield)": 9])
        XCTAssertEqual(s.rolls, [3, 17])
        XCTAssertEqual(s.pools, [:])
        XCTAssertTrue(s.processes.isEmpty && s.items.isEmpty && s.timed.isEmpty)
        XCTAssertEqual(s.clock, Clock(round: 1, minutes: 0))
        XCTAssertNil(s.heroId)

        let again = try JSONDecoder().decode(Situation.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(again, s)
    }

    func testPoolsRoundTrip() throws {
        var s = Situation(owned: [:], facts: [])
        s.pools = [.asp: PoolState(current: 20, max: 32)]
        s.heroId = "H_1"
        let again = try JSONDecoder().decode(Situation.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(again, s)
    }

    func testEveryCompiledSituationDecodes() throws {
        let url = Repo.url("build/rules/situations.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "run make rules-json")
        struct File: Decodable { var situations: [Situation] }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        XCTAssertGreaterThan(file.situations.count, 300)
        XCTAssertTrue(file.situations.contains { $0.owned.values.contains { $0.option2 != nil } })
    }
}
