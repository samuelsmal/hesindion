import XCTest
@testable import RulesEngine

final class ValueTests: XCTestCase {
    // MARK: - Helpers

    /// A book of `provide` effects: (rule id, kind, the rule's `provides`, [(name, value)]).
    private func book(_ rules: [(id: String, kind: String, provides: [String: Any], provide: [(String, Any)])]) throws -> RuleBook {
        let json: [String: Any] = [
            "vocabularyVersion": Vocabulary.version, "vocabularySha256": "test", "rulings": [], "reach": [:],
            "rules": rules.map { r in
                [
                    "id": r.id, "name": r.id, "kind": r.kind, "provides": r.provides,
                    "clauses": [[
                        "id": "P1", "text": "Tabelle.",
                        "effects": r.provide.enumerated().map { i, p in
                            ["verb": "provide", "payload": ["name": p.0, "value": p.1], "when": NSNull(), "ruling": [],
                             "because": NSNull(), "phase": "data", "origin": ["rule": r.id, "clause": "P1", "index": i]] as [String: Any]
                        },
                    ]],
                ] as [String: Any]
            },
        ]
        return try RuleBook.decode(JSONSerialization.data(withJSONObject: json))
    }

    private lazy var tables: RuleBook = try! book([
        ("fernkampf", "core", [:], [("fernkampf.FK6", ["gross": 4, "klein": -4, "mittel": 0]),
                                    ("fertigkeitsproben.qs", ["0-3": 1, "4-6": 2, "7-9": 3, "10-12": 4, "13-15": 5, "16+": 6]),
                                    ("exact.first", ["0": 7, "0-3": 1, "-1": 9]),
                                    ("words", ["kopf": "COND_2"])]),
    ])

    private func sheet(_ facts: [String: Int]) -> Situation {
        Situation(owned: [:], facts: facts.map { Fact(name: $0.key, value: .int($0.value), owner: .sheet) })
    }

    /// A resolver that knows the given targets and no facts; each target carries one contributing clause.
    private func targets(_ values: [String: Int]) -> TargetResolver {
        { t, _ in
            ResolvedTarget(value: values[t.description],
                           contributors: values[t.description] == nil ? [] : [ClauseRef(rule: "R_\(t.name)", clause: "C1")])
        }
    }

    private let noTargets: TargetResolver = { _, _ in XCTFail("no target expected"); return ResolvedTarget(value: nil) }

    private func eval(_ v: ValueExpr, level: Int? = nil, _ s: Situation, book: RuleBook? = nil,
                      resolve: TargetResolver? = nil) -> ValueResult {
        Values.evaluate(v, level: level, in: s, book: book ?? tables, resolve: resolve ?? noTargets)
    }

    // MARK: - The brief's numbers

    func testKW1() {
        // of attr.MU, above 8, per 3, round down; MU 14 → 2
        let v = ValueExpr.proportion(Proportion(of: .fact("attr.MU"), per: .number(3), above: .number(8), round: .down))
        let r = eval(v, sheet(["attr.MU": 14]))
        XCTAssertEqual(r.value, 2)
        XCTAssertEqual(r.used, [FactUse(name: "attr.MU", value: .int(14), owner: .sheet)])
        XCTAssertEqual(r.unknown, [])
    }

    func testWundschwelle() {
        // of attr.KO, per 2, round up; KO 15 → 8
        let v = ValueExpr.proportion(Proportion(of: .fact("attr.KO"), per: .number(2), round: .up))
        XCTAssertEqual(eval(v, sheet(["attr.KO": 15])).value, 8)
    }

    func testLevelMinusOne() {
        XCTAssertEqual(eval(.level(times: 1, plus: -1), level: 3, sheet([:])).value, 2)
        XCTAssertEqual(eval(.level(times: -2, plus: 0), level: 3, sheet([:])).value, -6)
        let r = eval(.level(times: 1, plus: -1), sheet([:]))
        XCTAssertNil(r.value)
        XCTAssertEqual(r.unknown, [UnknownFact(name: "level", owner: .sheet)])
    }

    func testANumber() {
        XCTAssertEqual(eval(.number(-2), sheet([:])).value, -2)
    }

    // MARK: - Tables

    func testATableLookupFindsItsValue() {
        let s = Situation(owned: [:], facts: [Fact(name: "target.size", value: .string("klein"), owner: .gm)])
        let r = eval(.table(name: "fernkampf.FK6", key: "target.size"), s)
        XCTAssertEqual(r.value, -4)
        XCTAssertEqual(r.used, [FactUse(name: "target.size", value: .string("klein"), owner: .gm)])
    }

    func testAMissingKeyFactGivesNilAndTheUnknownFact() {
        let r = eval(.table(name: "fernkampf.FK6", key: "target.size"), sheet([:]))
        XCTAssertNil(r.value)
        XCTAssertEqual(r.unknown, [UnknownFact(name: "target.size", owner: .gm)])
    }

    func testAKeyTheTableDoesNotListGivesNilWithoutAQuestion() {
        let s = Situation(owned: [:], facts: [Fact(name: "target.size", value: .string("riesig"), owner: .gm)])
        let r = eval(.table(name: "fernkampf.FK6", key: "target.size"), s)
        XCTAssertNil(r.value)
        XCTAssertEqual(r.unknown, [])
        XCTAssertNil(eval(.table(name: "no.such.table", key: "target.size"), s).value)
    }

    func testRangeKeysAndATargetKey() {
        // fertigkeitsproben.QS1: table(fertigkeitsproben.qs, check.fp), check.fp a target
        for (fp, qs) in [(0, 1), (3, 1), (4, 2), (11, 4), (15, 5), (16, 6), (22, 6)] {
            let r = eval(.table(name: "fertigkeitsproben.qs", key: "check.fp"), sheet([:]), resolve: targets(["check.fp": fp]))
            XCTAssertEqual(r.value, qs, "FP \(fp)")
            // The key target's contributors (R26), then the providing clause (table provenance).
            XCTAssertEqual(r.via, [ClauseRef(rule: "R_check.fp", clause: "C1"), ClauseRef(rule: "fernkampf", clause: "P1")])
        }
        XCTAssertNil(eval(.table(name: "fertigkeitsproben.qs", key: "check.fp"), sheet([:]), resolve: targets(["check.fp": -1])).value)
    }

    func testAnExactKeyBeatsARange() {
        let t = ValueExpr.table(name: "exact.first", key: "check.fp")
        XCTAssertEqual(eval(t, sheet([:]), resolve: targets(["check.fp": 0])).value, 7)
        XCTAssertEqual(eval(t, sheet([:]), resolve: targets(["check.fp": 2])).value, 1)
        XCTAssertEqual(eval(t, sheet([:]), resolve: targets(["check.fp": -1])).value, 9, "-1 is a key, not a range")
    }

    func testAnUnresolvedTargetKeyPassesOnItsUnknowns() {
        let resolve: TargetResolver = { _, _ in
            ResolvedTarget(value: nil, unknown: [UnknownFact(name: "check.result", owner: .roll)])
        }
        let r = eval(.table(name: "fertigkeitsproben.qs", key: "check.fp"), sheet([:]), resolve: resolve)
        XCTAssertNil(r.value)
        XCTAssertEqual(r.unknown, [UnknownFact(name: "check.result", owner: .roll)])
    }

    func testANonNumericEntryIsNoValueButLookupReturnsIt() {
        let s = Situation(owned: [:], facts: [Fact(name: "hit.zone", value: .string("kopf"), owner: .roll)])
        XCTAssertNil(eval(.table(name: "words", key: "hit.zone"), s).value)
        let l = Tables.lookup("words", key: "hit.zone", level: nil, in: s, book: tables, resolve: noTargets)
        XCTAssertEqual(l.value, .string("COND_2"))
    }

    // MARK: - The equipped item's row

    private lazy var weapons: RuleBook = try! book([
        ("ITEMTPL_19", "equipment", ["paMod": -1, "technique": "CT_5"], [("loadout.weapon", "provides")]),
        ("ITEMTPL_35", "equipment", ["paMod": 0, "technique": "CT_12"], [("loadout.weapon", "provides")]),
    ])

    private func holding(_ name: String?, template: String?) -> Situation {
        var facts = [Fact(name: "choice.stat", value: .string("paMod"), owner: .player)]
        if let name {
            facts.append(Fact(name: "loadout.weapon", value: .string(name), owner: .loadout))
            if let template { facts.append(Fact(name: "item.\(name).template", value: .string(template), owner: .loadout)) }
        }
        return Situation(owned: [:], facts: facts)
    }

    func testTheRowIsTheEquippedItemsNotTheFirst() {
        let t = ValueExpr.table(name: "loadout.weapon", key: "choice.stat")
        XCTAssertEqual(eval(t, holding("Langschwert", template: "ITEMTPL_35"), book: weapons).value, 0)
        let r = eval(t, holding("Rabenschnabel", template: "ITEMTPL_19"), book: weapons)
        XCTAssertEqual(r.value, -1)
        XCTAssertEqual(Set(r.used.map(\.name)), ["choice.stat", "loadout.weapon", "item.Rabenschnabel.template"])
        XCTAssertEqual(Tables.row("loadout.weapon", in: holding("Langschwert", template: "ITEMTPL_35"), book: weapons).row,
                       .object(["paMod": .int(0), "technique": .string("CT_12")]))
    }

    func testAnItemWithoutAKnownTemplateHasNoRow() {
        let t = ValueExpr.table(name: "loadout.weapon", key: "choice.stat")
        let noTemplate = eval(t, holding("Rabenschnabel", template: nil), book: weapons)
        XCTAssertNil(noTemplate.value)
        XCTAssertEqual(noTemplate.unknown, [UnknownFact(name: "item.Rabenschnabel.template", owner: .loadout)])

        let nothingInHand = eval(t, holding(nil, template: nil), book: weapons)
        XCTAssertNil(nothingInHand.value)
        XCTAssertEqual(nothingInHand.unknown, [UnknownFact(name: "loadout.weapon", owner: .loadout)])

        let otherTemplate = eval(t, holding("Dolch", template: "ITEMTPL_1"), book: weapons)
        XCTAssertNil(otherTemplate.value, "a template no rule provides has no row")
        XCTAssertEqual(otherTemplate.unknown, [])
    }

    // MARK: - Proportions

    func testASumOperand() {
        // kampfwerte.KW9: (MU + GE) / 2, round up
        let v = ValueExpr.proportion(Proportion(of: .sum([.fact("attr.MU"), .fact("attr.GE")]), per: .number(2)))
        let r = eval(v, sheet(["attr.MU": 13, "attr.GE": 14]))
        XCTAssertEqual(r.value, 14)
        XCTAssertEqual(r.used.map(\.name), ["attr.MU", "attr.GE"])
    }

    func testABoundListClampsByEachBound() {
        // SA_62.ST2: (gs + 4) / 2, round up, max [10, gsNatural]
        let v = ValueExpr.proportion(Proportion(of: .sum([.target(TargetRef("gs")), .number(4)]), per: .number(2),
                                                max: .each([.number(10), .target(TargetRef("gsNatural"))])))
        XCTAssertEqual(eval(v, sheet([:]), resolve: targets(["gs": 8, "gsNatural": 12])).value, 6)
        let r = eval(v, sheet([:]), resolve: targets(["gs": 8, "gsNatural": 5]))
        XCTAssertEqual(r.value, 5)
        XCTAssertEqual(r.via, [ClauseRef(rule: "R_gs", clause: "C1"), ClauseRef(rule: "R_gsNatural", clause: "C1")])
        XCTAssertEqual(eval(v, sheet([:]), resolve: targets(["gs": 30, "gsNatural": 40])).value, 10)
    }

    func testMinAndMaxBounds() {
        let v = ValueExpr.proportion(Proportion(of: .fact("attr.MU"), per: .number(2), min: .number(1), max: .operand(.fact("attr.KO"))))
        XCTAssertEqual(eval(v, sheet(["attr.MU": 0, "attr.KO": 5])).value, 1)
        XCTAssertEqual(eval(v, sheet(["attr.MU": 20, "attr.KO": 5])).value, 5)
    }

    func testAboveAsATarget() {
        let v = ValueExpr.proportion(Proportion(of: .fact("attr.KK"), above: .target(TargetRef("check.fw"))))
        let r = eval(v, sheet(["attr.KK": 16]), resolve: targets(["check.fw": 14]))
        XCTAssertEqual(r.value, 2)
        XCTAssertEqual(r.via, [ClauseRef(rule: "R_check.fw", clause: "C1")])
    }

    func testAboveAsAFactAndTheZeroClamp() {
        // DISADV_37.SE4: of gmFact.triggerModifier above …: max(0, of − above) never goes negative
        let v = ValueExpr.proportion(Proportion(of: .fact("attr.MU"), above: .fact("gmFact.triggerModifier")))
        let s = Situation(owned: [:], facts: [Fact(name: "attr.MU", value: .int(5), owner: .sheet),
                                              Fact(name: "gmFact.triggerModifier", value: .int(8), owner: .gm)])
        XCTAssertEqual(eval(v, s).value, 0)
    }

    func testARoundedMultiplyByMinusOneRoundsTheMagnitude() {
        // trefferzonen.TZ8: of hit.sp, per wundschwelle, times -1, round down; 7 SP over Wundschwelle 4 → −1, not −2
        let v = ValueExpr.proportion(Proportion(of: .fact("hit.sp"), per: .target(TargetRef("wundschwelle")), times: -1, round: .down))
        let s = Situation(owned: [:], facts: [Fact(name: "hit.sp", value: .int(7), owner: .derived)])
        let r = eval(v, s, resolve: targets(["wundschwelle": 4]))
        XCTAssertEqual(r.value, -1)
        XCTAssertEqual(r.via, [ClauseRef(rule: "R_wundschwelle", clause: "C1")], "R26: the operand's contributors")
        let up = ValueExpr.proportion(Proportion(of: .fact("hit.sp"), per: .number(4), times: -1, round: .up))
        XCTAssertEqual(eval(up, s).value, -2)
    }

    func testAnUnknownOperandGivesNilAndEveryUnknownFact() {
        let v = ValueExpr.proportion(Proportion(of: .sum([.fact("attr.MU"), .fact("attr.GE")]), per: .number(2)))
        let r = eval(v, sheet(["attr.GE": 14]))
        XCTAssertNil(r.value)
        XCTAssertEqual(r.unknown, [UnknownFact(name: "attr.MU", owner: .sheet)])
        XCTAssertEqual(r.used, [FactUse(name: "attr.GE", value: .int(14), owner: .sheet)])
    }

    func testDivisionByZeroIsNoValue() {
        let v = ValueExpr.proportion(Proportion(of: .number(4), per: .fact("attr.MU")))
        XCTAssertNil(eval(v, sheet(["attr.MU": 0])).value)
    }

    func testTheResolverPassesOnFactsAndUnknowns() {
        let resolve: TargetResolver = { _, _ in
            ResolvedTarget(value: nil, contributors: [], used: [FactUse(name: "attr.KO", value: .int(12), owner: .sheet)],
                           unknown: [UnknownFact(name: "gmFact.x", owner: .gm)])
        }
        let v = ValueExpr.proportion(Proportion(of: .target(TargetRef("wundschwelle"))))
        let r = eval(v, sheet([:]), resolve: resolve)
        XCTAssertNil(r.value)
        XCTAssertEqual(r.used, [FactUse(name: "attr.KO", value: .int(12), owner: .sheet)])
        XCTAssertEqual(r.unknown, [UnknownFact(name: "gmFact.x", owner: .gm)])
    }

    // MARK: - The depth guard

    func testTheResolverStopsAtDepthEight() {
        var calls: [Int] = []
        let v = ValueExpr.proportion(Proportion(of: .target(TargetRef("leMax"))))
        let s = sheet([:])
        let book = tables
        // leMax reads leMax: every resolution evaluates the value again, one level deeper.
        func resolve(_ t: TargetRef, _ depth: Int) -> ResolvedTarget {
            calls.append(depth)
            let r = Values.evaluate(v, level: nil, in: s, book: book, depth: depth, resolve: resolve)
            return ResolvedTarget(value: r.value, depthExceeded: r.depthExceeded)
        }
        let r = Values.evaluate(v, level: nil, in: s, book: book, resolve: resolve)
        XCTAssertNil(r.value)
        XCTAssertTrue(r.depthExceeded)
        XCTAssertEqual(calls, Array(1...Values.maxDepth))
        XCTAssertEqual(Values.maxDepth, 8)
    }

    // MARK: - The real book

    func testTheRealBooksForms() throws {
        let url = Repo.url("build/rules/rules.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "run make rules-json")
        let real = try RuleBook.load(from: url)
        func derived(_ rule: String, _ clause: String, _ i: Int) throws -> ValueExpr {
            let e = try XCTUnwrap(real.effect(at: EffectOrigin(rule: rule, clause: clause, index: .top(i))))
            guard case .derive(let d) = e.payload else { throw XCTSkip("\(rule).\(clause) is not a derive") }
            return try XCTUnwrap(d.sum.first)
        }
        XCTAssertEqual(eval(try derived("kampfwerte", "KW1", 1), sheet(["attr.MU": 14]), book: real).value, 2)
        let qs = try derived("fertigkeitsproben", "QS1", 1)
        XCTAssertEqual(eval(qs, sheet([:]), book: real, resolve: targets(["check.fp": 8])).value, 3)
        XCTAssertEqual(eval(qs, sheet([:]), book: real, resolve: targets(["check.fp": 17])).value, 6)
    }
}
