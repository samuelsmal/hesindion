import XCTest
@testable import RulesEngine

/// Phases 1–3 on the fixture book `Fixtures/pipeline-rules.json` (source:
/// `Tests/FixtureRules/pipeline`, rebuilt by `make rules-engine-fixture`).
final class PipelineTests: XCTestCase {
    private static let book: RuleBook = {
        let url = Bundle.module.url(forResource: "pipeline-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    private let engine = Engine(book: PipelineTests.book)

    private func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }

    /// A fact stated by its vocabulary owner.
    private func fact(_ name: String, _ value: JSONValue) -> Fact {
        Fact(name: name, value: value, owner: Vocabulary.owner(ofFact: name) ?? .sheet)
    }

    private func situation(owned: [String: Int] = [:], facts: [String: JSONValue] = [:],
                           base: [String: Int] = [:]) -> Situation {
        Situation(owned: owned.mapValues { OwnedRule(level: $0) },
                  facts: facts.sorted { $0.key < $1.key }.map { fact($0.key, $0.value) }, base: base)
    }

    private func lines(_ b: Breakdown, from origin: String) -> [Line] {
        b.lines.filter { $0.origin == ref(origin) }
    }

    private func notApplied(_ b: Breakdown, _ origin: String) -> [NotApplied] {
        b.notApplied.filter { $0.origin == ref(origin) }
    }

    // MARK: - Phase 1: base

    func testADeriveGivesTheBaseWithOnePartPerTerm() throws {
        let b = engine.evaluate(Query("aw"), in: situation(facts: ["attr.GE": 13]))
        let base = try XCTUnwrap(b.base)
        XCTAssertEqual(base.kind, .base)
        XCTAssertEqual(base.value, 8)
        XCTAssertEqual(base.origin, ref("pl-kampfwerte.D1"))
        XCTAssertEqual(base.parts.map(\.value), [7, 1])
        XCTAssertEqual(base.parts.map(\.origin), [ref("pl-kampfwerte.D1"), ref("pl-kampfwerte.D1")])
        XCTAssertEqual(base.parts[0].facts, [FactUse(name: "attr.GE", value: .int(13), owner: .sheet)])
        XCTAssertEqual(b.lines, [])
        XCTAssertEqual(b.result, 8)
        XCTAssertEqual(b.shownLines.map(\.value), [7, 1])
    }

    func testEveryApplicableDeriveOfTheTargetAddsToTheBase() throws {
        // KW1's shape: KtW in one derive, the MU bonus in a second one gated by a `when`.
        let s = situation(facts: ["ktw.current": 14, "attr.MU": 14, "loadout.weapon.technique": "Schwerter"])
        let b = engine.evaluate(Query("at(with: Schwerter)"), in: s)
        XCTAssertEqual(b.base?.parts.map(\.value), [14, 2])
        XCTAssertEqual(b.result, 16)
        let whip = engine.evaluate(Query("at"), in: situation(facts: ["ktw.current": 14, "attr.MU": 14,
                                                                      "loadout.weapon.technique": "Peitschen"]))
        XCTAssertEqual(whip.result, 14)
        XCTAssertEqual(notApplied(whip, "pl-kampfwerte.D2").map(\.reason), [.conditionFalse])
    }

    func testAStatedBaseIsTheSheetsAndOverridesTheDerive() throws {
        let b = engine.evaluate(Query("aw"), in: situation(facts: ["attr.GE": 13], base: ["aw": 10]))
        let base = try XCTUnwrap(b.base)
        XCTAssertEqual(base.kind, .base)
        XCTAssertEqual(base.value, 10)
        XCTAssertEqual(base.owner, .sheet)
        XCTAssertEqual(base.note, "Grundwert laut Bogen")
        XCTAssertNil(base.origin)
        XCTAssertEqual(b.result, 10)
        XCTAssertEqual(notApplied(b, "pl-kampfwerte.D1").map(\.reason), [.overridden])
    }

    func testAStatedBaseFallsBackToTheNameWithoutAContextMatch() {
        let s = situation(base: ["pa": 9])
        XCTAssertEqual(engine.evaluate(Query("pa(with: shield)"), in: s).base?.value, 9)
        let exact = situation(base: ["pa": 9, "pa(with: shield)": 11])
        XCTAssertEqual(engine.evaluate(Query("pa(with: shield)"), in: exact).base?.value, 11)
    }

    // MARK: - Phase 3: add and set

    func testTwoAddsEachGiveALineWithTheirFactsAndRuling() throws {
        let s = situation(owned: ["pl-adds": 1],
                          facts: ["round.parries": 2, "gmFact.fromBehind": false, "hero.mounted": false],
                          base: ["pa": 10])
        let b = engine.evaluate(Query("pa"), in: s)
        let a1 = try XCTUnwrap(lines(b, from: "pl-adds.A1").first)
        XCTAssertEqual(a1.value, 1)
        XCTAssertEqual(a1.kind, .add)
        XCTAssertEqual(a1.ruling, "pl-adds.decided-q")
        let a2 = try XCTUnwrap(lines(b, from: "pl-adds.A2").first)
        XCTAssertEqual(a2.value, 4, "2 per round.parries")
        XCTAssertEqual(a2.facts, [FactUse(name: "round.parries", value: .int(2), owner: .round)])
        XCTAssertNil(a2.ruling)
        XCTAssertEqual(b.total, 5)
        XCTAssertEqual(b.result, 15)
        let a5 = try XCTUnwrap(notApplied(b, "pl-adds.A5").first)
        XCTAssertEqual(a5.reason, .conditionFalse)
        XCTAssertEqual(a5.facts, [FactUse(name: "hero.mounted", value: .bool(false), owner: .loadout)])
        XCTAssertEqual(notApplied(b, "pl-adds.A3").map(\.reason), [.conditionFalse])
    }

    func testSetsApplyBeforeAddsAndTheLaterSetWins() throws {
        let s = situation(owned: ["pl-add-ini": 1, "pl-seta": 1, "pl-setb": 1], base: ["iniBase": 10])
        let b = engine.evaluate(Query("iniBase"), in: s)
        XCTAssertEqual(b.lines.map(\.origin), [ref("pl-setb.S1"), ref("pl-add-ini.I1")])
        let set = b.lines[0]
        XCTAssertEqual(set.kind, .set)
        XCTAssertEqual(set.value, -3)
        XCTAssertEqual(set.was, 10)
        XCTAssertEqual(set.now, 7)
        XCTAssertEqual(b.lines[1].value, 1)
        XCTAssertEqual(b.result, 8)
        let lost = try XCTUnwrap(notApplied(b, "pl-seta.S1").first)
        XCTAssertEqual(lost.reason, .overridden)
        XCTAssertEqual(lost.because, "pl-setb.S1")
    }

    // MARK: - Phase 2: level

    func testUseLevelLinesCarryVia() throws {
        // COND_1 (levels 4): B3 add { to: [at, pa, aw], value: -1 * level }
        // SA_41 (levels 2): G1 useLevel { rule: COND_1, lowerBy: level, min: 0 } — lowerBy at SA_41's own level
        let s = Situation(owned: ["COND_1": .init(level: 3), "SA_41": .init(level: 2)], facts: [])
        let b = engine.evaluate(Query("at"), in: s)
        let line = try XCTUnwrap(b.lines.first { $0.origin == ClauseRef(rule: "COND_1", clause: "B3") })
        XCTAssertEqual(line.value, -1)
        XCTAssertEqual(line.via, [ClauseRef(rule: "SA_41", clause: "G1")])
        let levelAs = try XCTUnwrap(b.lines.first { $0.kind == .levelAs })
        XCTAssertEqual(levelAs.note, "Stufe 3 wirkt wie 1")
        XCTAssertEqual(levelAs.value, 0)
        XCTAssertEqual(levelAs.origin, ref("SA_41.G1"))
        XCTAssertEqual(levelAs.ruling, "SA_41.table-shift")
        XCTAssertEqual([levelAs.was, levelAs.now], [3, 1])
    }

    func testLowerByIsFlooredAtItsMin() throws {
        let s = Situation(owned: ["COND_1": .init(level: 1), "SA_41": .init(level: 2)], facts: [])
        let b = engine.evaluate(Query("pa"), in: s)
        XCTAssertEqual(b.lines.first { $0.kind == .levelAs }?.note, "Stufe 1 wirkt wie 0")
        XCTAssertEqual(lines(b, from: "COND_1.B3").first?.value, 0)
    }

    func testChainedUseLevelsBeforeAndAfterACheckPass() throws {
        // The ADV_49 ZH1/ZH3 pattern (R28).
        let before = engine.evaluate(Query("gs"), in: situation(owned: ["pl-tough": 1, "pl-pain": 4], base: ["gs": 8]))
        XCTAssertEqual(lines(before, from: "pl-pain.P2").map(\.value), [-4])
        XCTAssertEqual(lines(before, from: "pl-pain.P2").first?.via, [ref("pl-tough.Z3")])
        XCTAssertEqual(before.lines.filter { $0.kind == .levelAs }.map(\.note), ["Stufe 4 wirkt wie 4"])
        XCTAssertEqual(notApplied(before, "pl-tough.Z1").map(\.reason), [.unknownFact])
        XCTAssertEqual(before.questions.map(\.fact), ["check.result"])
        XCTAssertEqual(before.questions.first?.owner, .roll)

        let after = engine.evaluate(Query("gs"), in: situation(owned: ["pl-tough": 1, "pl-pain": 4],
                                                               facts: ["check.result": "success"], base: ["gs": 8]))
        XCTAssertEqual(lines(after, from: "pl-pain.P1").map(\.value), [-3])
        XCTAssertEqual(lines(after, from: "pl-pain.P1").first?.via, [ref("pl-tough.Z1"), ref("pl-tough.Z3")])
        let levelAs = after.lines.filter { $0.kind == .levelAs }
        XCTAssertEqual(levelAs.map(\.note), ["Stufe 4 wirkt wie 3", "Stufe 3 wirkt wie 3"])
        XCTAssertEqual(levelAs.map(\.ruling), ["pl-tough.counts", nil])
        XCTAssertEqual(notApplied(after, "pl-pain.P2").map(\.reason), [.conditionFalse])
        XCTAssertEqual(after.result, 5)
    }

    func testUseLevelsChainInClauseOrderNotInTheReachIndexOrder() {
        // pl-order: U2 (as 1) comes before U10 (as level + 1) in the rule; "U10" sorts first.
        let b = engine.evaluate(Query("ini"), in: situation(owned: ["pl-order": 1, "pl-steps": 4]))
        XCTAssertEqual(b.lines.filter { $0.kind == .levelAs }.map(\.note), ["Stufe 4 wirkt wie 1", "Stufe 1 wirkt wie 2"])
        XCTAssertEqual(lines(b, from: "pl-steps.K1").map(\.value), [-2])
        XCTAssertEqual(lines(b, from: "pl-steps.K1").first?.via, [ref("pl-order.U2"), ref("pl-order.U10")])
    }

    func testTheLevelQueryResultIsTheEffectiveLevel() throws {
        let s = situation(owned: ["pl-tough": 1, "pl-pain": 4], facts: ["check.result": "success"])
        let b = engine.evaluate(Query("level(rule: pl-pain)"), in: s)
        XCTAssertEqual(b.base?.value, 4)
        XCTAssertEqual(b.base?.owner, .sheet)
        let levelAs = b.lines.filter { $0.kind == .levelAs }
        XCTAssertEqual(levelAs.map(\.value), [-1, 0])
        XCTAssertEqual(levelAs.map(\.now), [3, 3])
        XCTAssertEqual(b.result, 3)
    }

    // MARK: - Questions, rulings, texts

    func testAnUnknownGMFactGivesAQuestionWithItsOwner() throws {
        let s = situation(owned: ["pl-adds": 1], facts: ["round.parries": 0, "hero.mounted": false], base: ["pa": 10])
        let b = engine.evaluate(Query("pa"), in: s)
        XCTAssertEqual(notApplied(b, "pl-adds.A3").map(\.reason), [.unknownFact])
        XCTAssertEqual(b.questions, [Question(fact: "gmFact.fromBehind", owner: .gm, origins: [ref("pl-adds.A3")])])
        XCTAssertEqual(lines(b, from: "pl-adds.A3"), [])
    }

    func testAnOpenRulingAppliesNothingAndShowsItsClauseAndQuestion() throws {
        let s = situation(owned: ["pl-adds": 1], facts: ["round.parries": 0, "hero.mounted": false], base: ["pa": 10])
        let b = engine.evaluate(Query("pa"), in: s)
        XCTAssertEqual(lines(b, from: "pl-adds.A4"), [])
        let na = try XCTUnwrap(notApplied(b, "pl-adds.A4").first)
        XCTAssertEqual(na.reason, .openRuling)
        XCTAssertEqual(na.rulings, ["pl-adds.open-q"])
        XCTAssertEqual(b.texts, [TextLine(kind: .openRuling, text: "PA +5, vielleicht.", origin: ref("pl-adds.A4"),
                                          ruling: "pl-adds.open-q", question: "Does it stack?")])
    }

    // MARK: - Applicability

    func testARequireThatEnablesItsOwnRuleGivesVia() throws {
        let on = engine.evaluate(Query("aw"), in: situation(facts: ["attr.GE": 13, "choice.enable": true]))
        XCTAssertEqual(lines(on, from: "pl-enabled.E2").map(\.value), [3])
        XCTAssertEqual(lines(on, from: "pl-enabled.E2").first?.via, [ref("pl-enabled.E1")])
        let off = engine.evaluate(Query("aw"), in: situation(facts: ["attr.GE": 13, "choice.enable": false]))
        XCTAssertEqual(lines(off, from: "pl-enabled.E2"), [])
        XCTAssertFalse(off.notApplied.contains { $0.rule == "pl-enabled" }, "a rule that does not apply is silent")
    }

    func testARequireForAnotherRuleEnablesThatRule() throws {
        let on = engine.evaluate(Query("aw"), in: situation(facts: ["attr.GE": 13, "hero.mounted": true]))
        XCTAssertEqual(lines(on, from: "pl-target.T1").map(\.value), [4])
        XCTAssertEqual(lines(on, from: "pl-target.T1").first?.via, [ref("pl-enabler.R1")])
        let off = engine.evaluate(Query("aw"), in: situation(facts: ["attr.GE": 13, "hero.mounted": false]))
        XCTAssertEqual(lines(off, from: "pl-target.T1"), [])
    }

    func testACoreRuleOutsideTheRulesetsIsNotAppliedWithRulesetOff() throws {
        let off = engine.evaluate(Query("fk"), in: situation(facts: ["attr.KO": 2, "rulesets": .array([])]))
        XCTAssertEqual(lines(off, from: "pl-focus.F1"), [])
        XCTAssertEqual(notApplied(off, "pl-focus.F1").map(\.reason), [.rulesetOff])
        let on = engine.evaluate(Query("fk"), in: situation(facts: ["attr.KO": 2, "rulesets": .array(["fokus.pl"])]))
        XCTAssertEqual(lines(on, from: "pl-focus.F1").map(\.value), [1])
    }

    func testEquipmentAppliesWhenALoadoutItemHasItsTemplate() {
        let worn = situation(facts: ["loadout.weapon": "Klinge", "item.Klinge.template": "pl-sword"])
        XCTAssertEqual(lines(engine.evaluate(Query("at"), in: worn), from: "pl-sword.E1").map(\.value), [1])
        let other = situation(facts: ["loadout.weapon": "Klinge", "item.Klinge.template": "pl-other"])
        let b = engine.evaluate(Query("at"), in: other)
        XCTAssertEqual(lines(b, from: "pl-sword.E1"), [])
        XCTAssertFalse(b.notApplied.contains { $0.rule == "pl-sword" })
    }

    func testATalentRuleAppliesToItsOwnCheck() {
        let own = situation(facts: ["check.talent": "pl-talent"])
        XCTAssertEqual(lines(engine.evaluate(Query("check.modifier"), in: own), from: "pl-talent.T1").map(\.value), [1])
        let other = situation(facts: ["check.talent": "TAL_1"])
        XCTAssertEqual(lines(engine.evaluate(Query("check.modifier"), in: other), from: "pl-talent.T1"), [])
    }

    func testAnUnownedAbilityIsSilent() {
        let b = engine.evaluate(Query("pa"), in: situation(base: ["pa": 10]))
        XCTAssertEqual(b.lines, [])
        XCTAssertEqual(b.notApplied, [])
        XCTAssertEqual(b.questions, [])
        XCTAssertEqual(b.texts, [])
    }

    // MARK: - R34: hero.levelOf and derived levels

    func testALevelledRuleAppliesAtItsDerivedLevel() throws {
        let s = situation(owned: ["pl-reader": 1], facts: ["gmFact.strain": 2], base: ["rs": 3])
        let b = engine.evaluate(Query("rs"), in: s)
        XCTAssertEqual(lines(b, from: "pl-strain.D2").map(\.value), [-2])
        let r1 = try XCTUnwrap(lines(b, from: "pl-reader.R1").first)
        XCTAssertEqual(r1.value, 5)
        XCTAssertEqual(r1.facts, [FactUse(name: "hero.levelOf.pl-strain", value: .int(2), owner: .derived)])
        XCTAssertEqual(b.result, 6)

        let level = engine.evaluate(Query("level(rule: pl-strain)"), in: s)
        XCTAssertEqual(level.base?.origin, ref("pl-strain.D1"))
        XCTAssertEqual(level.result, 2)
    }

    func testALevelledRuleAtDerivedLevelZeroIsSilent() {
        let s = situation(owned: ["pl-reader": 1], facts: ["gmFact.strain": 0], base: ["rs": 3])
        let b = engine.evaluate(Query("rs"), in: s)
        XCTAssertEqual(lines(b, from: "pl-strain.D2"), [])
        XCTAssertFalse(b.notApplied.contains { $0.rule == "pl-strain" })
        XCTAssertEqual(notApplied(b, "pl-reader.R1").map(\.reason), [.conditionFalse])
    }

    func testAnUnknownDerivedLevelAsksForTheFactsBehindIt() {
        let b = engine.evaluate(Query("rs"), in: situation(owned: ["pl-reader": 1], base: ["rs": 3]))
        XCTAssertEqual(notApplied(b, "pl-reader.R1").map(\.reason), [.unknownFact])
        XCTAssertEqual(b.questions.map(\.fact), ["gmFact.strain"])
        XCTAssertEqual(b.questions.first?.owner, .gm)
    }

    // MARK: - R26: operand provenance, tables, the depth guard

    func testAnOperandsContributorsJoinVia() throws {
        // pl-a.A1 adds +1 to wundschwelle; pl-b.B1 reads `per: wundschwelle`.
        let s = situation(facts: ["hit.sp": 16], base: ["wundschwelle": 7])
        let b = engine.evaluate(Query("check.modifier"), in: s)
        let line = try XCTUnwrap(lines(b, from: "pl-b.B1").first)
        XCTAssertEqual(line.value, -2)
        XCTAssertEqual(line.via, [ref("pl-a.A1")])
        XCTAssertTrue(line.facts.contains(FactUse(name: "hit.sp", value: .int(16), owner: .derived)))
    }

    func testATableReadPutsItsProviderInVia() throws {
        let b = engine.evaluate(Query("fk"), in: situation(facts: ["attr.KO": 5]))
        let line = try XCTUnwrap(lines(b, from: "pl-kampfwerte.T2").first)
        XCTAssertEqual(line.value, 2)
        XCTAssertEqual(line.via, [ref("pl-kampfwerte.T1")])
        XCTAssertNil(b.result, "no base")

        let t = Tables.lookup("pl.table", key: "attr.KO", level: nil, in: situation(facts: ["attr.KO": 5]),
                              book: Self.book, resolve: { _, _ in ResolvedTarget(value: nil) })
        XCTAssertEqual(t.provider, EffectOrigin(rule: "pl-kampfwerte", clause: "T1", index: .top(0)))
    }

    func testAScaleStepIsALineWithWasAndNowAndItsProviderInVia() throws {
        let b = engine.evaluate(Query("spell.cost"), in: situation(facts: ["choice.erzwingen": true], base: ["spell.cost": 8]))
        let line = try XCTUnwrap(lines(b, from: "pl-kampfwerte.S2").first)
        XCTAssertEqual([line.value, line.was, line.now], [8, 8, 16])
        XCTAssertEqual(line.via, [ref("pl-kampfwerte.S1")])
        XCTAssertEqual(b.result, 16)

        let bottom = engine.evaluate(Query("spell.costPerInterval"), in: situation(base: ["spell.costPerInterval": 1]))
        XCTAssertEqual(lines(bottom, from: "pl-kampfwerte.S2").map(\.value), [0], "clamps at the bottom step")
        XCTAssertEqual(bottom.result, 1)

        let off = engine.evaluate(Query("spell.costPerInterval"), in: situation(base: ["spell.costPerInterval": 3]))
        XCTAssertEqual(lines(off, from: "pl-kampfwerte.S2"), [])
        XCTAssertEqual(off.texts.map(\.kind), [.notApplicable])
    }

    func testATargetThatReadsItselfStopsAtTheDepthGuardWithAText() throws {
        let b = engine.evaluate(Query("tp"), in: situation(base: ["tp": 3]))
        XCTAssertEqual(lines(b, from: "pl-loop.L1"), [])
        let text = try XCTUnwrap(b.texts.first)
        XCTAssertEqual(text.kind, .notApplicable)
        XCTAssertTrue(text.text.hasPrefix("Regel konnte nicht angewandt werden: pl-loop.L1 – "), text.text)
        XCTAssertEqual(b.result, 3)
        XCTAssertTrue(b.depthExceeded)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral, ExpressibleByStringLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(stringLiteral value: String) { self = .string(value) }
}
