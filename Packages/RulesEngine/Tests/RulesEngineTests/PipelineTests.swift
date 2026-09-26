import XCTest
@testable import RulesEngine

/// The value pipeline (phases 1–7), offers and texts on the fixture book `Fixtures/pipeline-rules.json` (source:
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

    func testAnUnknownDerivedLevelIsNoGuessItsEffectsAskForTheFacts() throws {
        // pl-strain's level derives from gmFact.strain, which nobody stated: not silent, not 0.
        let b = engine.evaluate(Query("rs"), in: situation(base: ["rs": 3]))
        XCTAssertEqual(lines(b, from: "pl-strain.D2"), [])
        XCTAssertEqual(notApplied(b, "pl-strain.D2").map(\.reason), [.unknownFact])
        XCTAssertEqual(b.questions, [Question(fact: "gmFact.strain", owner: .gm, origins: [ref("pl-strain.D2")])])
    }

    func testHeroLevelOfIsTheLevelBeforeAnyUseLevel() throws {
        // pl-lower.G1: pl-strain acts as 0; hero.levelOf.pl-strain stays 2 for pl-reader.R1.
        let s = situation(owned: ["pl-reader": 1, "pl-lower": 1], facts: ["gmFact.strain": 2], base: ["rs": 3])
        let b = engine.evaluate(Query("rs"), in: s)
        XCTAssertEqual(b.lines.filter { $0.kind == .levelAs }.map(\.note), ["Stufe 2 wirkt wie 0"])
        XCTAssertEqual(lines(b, from: "pl-strain.D2").map(\.value), [0])
        let r1 = try XCTUnwrap(lines(b, from: "pl-reader.R1").first)
        XCTAssertEqual(r1.facts, [FactUse(name: "hero.levelOf.pl-strain", value: .int(2), owner: .derived)])
        XCTAssertEqual(engine.evaluate(Query("level(rule: pl-strain)"), in: s).result, 0)
    }

    func testTheNameFallbackOfTheBaseNeverSetsALevel() {
        let s = situation(owned: ["pl-pain": 2], base: ["level": 4])
        XCTAssertEqual(engine.evaluate(Query("level(rule: pl-pain)"), in: s).result, 2)
    }

    // MARK: - R35: a suppress between alternative derives acts in the base phase

    func testASuppressPicksOneOfTwoAlternativeLevelDerives() throws {
        let facts: [String: JSONValue] = ["loadout.armour.belastung": 3, "gmFact.zoneLoad": 1]
        var zones = facts; zones["rulesets"] = .array(["fokus.zones"])
        let level = engine.evaluate(Query("level(rule: pl-load)"), in: situation(facts: zones))
        XCTAssertEqual(level.base?.parts.map(\.origin), [ref("pl-zones.Z1")])
        XCTAssertEqual(level.result, 1, "not 3 + 1")
        let na = try XCTUnwrap(notApplied(level, "pl-armour.A1").first)
        XCTAssertEqual(na.reason, .suppressed)
        XCTAssertEqual(na.because, "pl-zones.Z1")
        // hero.levelOf and the rule's own lines read the same level.
        let asp = engine.evaluate(Query("regeneration.asp"), in: situation(facts: zones, base: ["regeneration.asp": 5]))
        XCTAssertEqual(lines(asp, from: "pl-load.L1").map(\.value), [-1])

        var off = facts; off["rulesets"] = .array([])
        let plain = engine.evaluate(Query("level(rule: pl-load)"), in: situation(facts: off))
        XCTAssertEqual(plain.result, 3)
        XCTAssertEqual(notApplied(plain, "pl-zones.Z1").map(\.reason), [.rulesetOff])
    }

    func testASuppressWithAWhenActsOnlyWhenItHolds() throws {
        // The iniBase shape: pl-mount.M1 suppresses pl-kampfwerte.I1 and derives instead when mounted.
        let mounted = engine.evaluate(Query("regeneration.kap"),
                                      in: situation(facts: ["attr.KL": 12, "hero.mounted": true, "mount.kap": 3]))
        XCTAssertEqual(mounted.base?.parts.map(\.origin), [ref("pl-mount.M1")])
        XCTAssertEqual(mounted.result, 3)
        XCTAssertEqual(notApplied(mounted, "pl-kampfwerte.I1").map(\.reason), [.suppressed])

        let afoot = engine.evaluate(Query("regeneration.kap"),
                                    in: situation(facts: ["attr.KL": 12, "hero.mounted": false, "mount.kap": 3]))
        XCTAssertEqual(afoot.result, 6)
        XCTAssertEqual(notApplied(afoot, "pl-kampfwerte.I1"), [])

        let unknown = engine.evaluate(Query("regeneration.kap"), in: situation(facts: ["attr.KL": 12]))
        XCTAssertEqual(unknown.result, 6, "a suppress whose when is unknown suppresses nothing")
        XCTAssertEqual(unknown.questions.map(\.fact), ["hero.mounted"])
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

    func testTheClausesSettingAnOperandsBaseJoinVia() throws {
        // pl-c.C1 reads aw, whose base is pl-kampfwerte.D1's derive.
        let b = engine.evaluate(Query("regeneration.le"), in: situation(facts: ["attr.GE": 13]))
        let line = try XCTUnwrap(lines(b, from: "pl-c.C1").first)
        XCTAssertEqual(line.value, 2)
        XCTAssertEqual(line.via, [ref("pl-kampfwerte.D1")])
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

// MARK: - Task 23: phases 4–7 and the player-facing parts of the breakdown

extension PipelineTests {
    private func shownSumIsTheResult(_ b: Breakdown, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(b.shownLines.reduce(0) { $0 + $1.value }, b.result, "Σ shown lines == result", file: file, line: line)
    }

    private func offer(_ offers: [OfferedChoice], _ choice: String) -> OfferedChoice? {
        offers.first { $0.choice == choice }
    }

    // MARK: Phase 4: replace, suppress

    func testAReplaceSwapsTheValueBeforePerAndKeepsTheLinesOrigin() throws {
        // SA_923.VS1 on mehrfache-verteidigung.MV1: −2 instead of −3, still per defence made.
        let s = situation(owned: ["pl-defence": 1, "pl-style": 1],
                          facts: ["round.defencesMade": 2, "loadout.weapon.technique": "CT_1"], base: ["pa": 8])
        let b = engine.evaluate(Query("pa"), in: s)
        let line = try XCTUnwrap(lines(b, from: "pl-defence.V1").first)
        XCTAssertEqual(line.kind, .replaced)
        XCTAssertEqual(line.value, -4)
        XCTAssertEqual(line.was, -6)
        XCTAssertEqual(line.via, [ref("pl-style.VS1")])
        XCTAssertEqual(line.rulings, ["pl-style.style"])
        XCTAssertTrue(line.facts.contains { $0.name == "round.defencesMade" })
        let replaced = try XCTUnwrap(notApplied(b, "pl-defence.V1").first)
        XCTAssertEqual(replaced.reason, .replaced)
        XCTAssertEqual(replaced.value, -6)
        XCTAssertEqual(replaced.because, "pl-style.VS1")
        XCTAssertEqual(b.result, 4)
        shownSumIsTheResult(b)

        let other = engine.evaluate(Query("pa"), in: situation(owned: ["pl-defence": 1, "pl-style": 1],
            facts: ["round.defencesMade": 2, "loadout.weapon.technique": "CT_2"], base: ["pa": 8]))
        XCTAssertEqual(lines(other, from: "pl-defence.V1").map(\.kind), [.add])
        XCTAssertEqual(lines(other, from: "pl-defence.V1").map(\.value), [-6])
        XCTAssertEqual(notApplied(other, "pl-style.VS1").map(\.reason), [.conditionFalse])
    }

    func testAReplaceKeepsTheReplacedEffectsWhen() {
        let s = situation(owned: ["pl-defence": 1, "pl-style": 1],
                          facts: ["round.defencesMade": 0, "round.defendedThisAttack": false,
                                  "loadout.weapon.technique": "CT_1"], base: ["pa": 8])
        let b = engine.evaluate(Query("pa"), in: s)
        XCTAssertEqual(lines(b, from: "pl-defence.V1"), [])
        XCTAssertTrue(notApplied(b, "pl-defence.V1").contains {
            $0.reason == .conditionFalse && $0.facts.contains { $0.name == "round.defencesMade" }
        }, "the add's own when, kept")
        XCTAssertFalse(notApplied(b, "pl-defence.V1").contains { $0.reason == .replaced })
        XCTAssertEqual(b.result, 8)
    }

    func testAReplaceWithATableValueStandsEvenWhereTheOriginalCannotBeComputed() throws {
        // fernkampf.FK8 on FK6: in cover the target counts as klein.
        let s = situation(owned: ["pl-cover": 1], facts: ["target.size": "mittel", "target.cover": "teilweise",
                                                          "target.sizeInCover": "klein"], base: ["fk": 12])
        let b = engine.evaluate(Query("fk"), in: s)
        let line = try XCTUnwrap(lines(b, from: "pl-cover.C1").first)
        XCTAssertEqual([line.value, line.was], [-4, 0])
        XCTAssertEqual(line.kind, .replaced)
        XCTAssertEqual(line.via, [ref("pl-cover.C1"), ref("pl-cover.C2")], "the table's provider, then the replacer")
        XCTAssertEqual(b.result, 8)

        let unsized = engine.evaluate(Query("fk"), in: situation(owned: ["pl-cover": 1],
            facts: ["target.cover": "teilweise", "target.sizeInCover": "klein"], base: ["fk": 12]))
        let replaced = try XCTUnwrap(lines(unsized, from: "pl-cover.C1").first)
        XCTAssertEqual(replaced.value, -4)
        XCTAssertNil(replaced.was)
        XCTAssertFalse(unsized.questions.contains { $0.fact == "target.size" }, "the replaced value is not asked for")
    }

    func testAReplaceOfADeriveReplacesItsPartsInTheBase() throws {
        let s = situation(owned: ["pl-swap": 1], facts: ["attr.GE": 13, "choice.swap": true])
        let b = engine.evaluate(Query("aw"), in: s)
        let base = try XCTUnwrap(b.base)
        XCTAssertEqual(base.value, 5)
        XCTAssertEqual(base.parts.map(\.value), [5])
        XCTAssertEqual(base.parts.map(\.kind), [.replaced])
        XCTAssertEqual(base.parts.first?.origin, ref("pl-kampfwerte.D1"))
        XCTAssertEqual(base.parts.first?.via, [ref("pl-swap.X1")])
        XCTAssertEqual(base.parts.first?.was, 8)
        XCTAssertEqual(notApplied(b, "pl-kampfwerte.D1").map(\.reason), [.replaced])
        XCTAssertEqual(notApplied(b, "pl-kampfwerte.D1").first?.value, 8)
        XCTAssertEqual(b.result, 5)
        shownSumIsTheResult(b)
    }

    func testASuppressRemovesTheLineWithBecause() throws {
        let s = situation(owned: ["pl-adds": 1, "pl-quiet": 1], facts: ["choice.quiet": true], base: ["pa": 10])
        let b = engine.evaluate(Query("pa"), in: s)
        XCTAssertEqual(lines(b, from: "pl-adds.A1"), [])
        let entry = try XCTUnwrap(notApplied(b, "pl-adds.A1").first)
        XCTAssertEqual(entry.reason, .suppressed)
        XCTAssertEqual(entry.because, "pl-quiet.Q1")
        XCTAssertEqual(entry.via, [ref("pl-quiet.Q1")])
        XCTAssertEqual(entry.value, 1, "the value its line would have had")
        XCTAssertFalse(b.questions.contains { $0.origins == [ref("pl-adds.A1")] })

        let unknown = engine.evaluate(Query("pa"), in: situation(owned: ["pl-adds": 1, "pl-quiet": 1], base: ["pa": 10]))
        XCTAssertEqual(lines(unknown, from: "pl-adds.A1").map(\.value), [1])
        XCTAssertTrue(unknown.questions.contains { $0.fact == "choice.quiet" && $0.origins == [ref("pl-quiet.Q1")] })
    }

    func testASuppressOfATellAndOfEveryConditionsLines() {
        let s = situation(owned: ["pl-talk": 1, "pl-quiet": 1, "pl-hurt": 2], facts: ["choice.schip": true],
                          base: ["at": 14])
        let b = engine.evaluate(Query("at"), in: s)
        XCTAssertTrue(b.texts.contains { $0.kind == .tell && $0.text == "Leiser Hinweis." })
        XCTAssertFalse(b.texts.contains { $0.text == "Lauter Hinweis." })
        XCTAssertEqual(notApplied(b, "pl-talk.T4").map(\.reason), [.suppressed])
        XCTAssertEqual(lines(b, from: "pl-hurt.C1"), [])
        XCTAssertEqual(notApplied(b, "pl-hurt.C1").map(\.reason), [.suppressed])
        XCTAssertEqual(notApplied(b, "pl-hurt.C1").map(\.value), [-2])
        XCTAssertEqual(b.result, 14)
    }

    func testASuppressedDeriveIsRecordedOnceAndItsClausesOtherLinesToo() {
        // Extra 4 (R35): the base phase suppresses A1's derive; the lines phase must not record it again.
        let facts: [String: JSONValue] = ["rulesets": .array(["fokus.zones"]), "gmFact.zoneLoad": 1, "loadout.armour.belastung": 3]
        let level = engine.evaluate(Query("level(rule: pl-load)"), in: situation(facts: facts))
        XCTAssertEqual(notApplied(level, "pl-armour.A1").map(\.reason), [.suppressed])
        XCTAssertEqual(level.result, 1)
        let kap = engine.evaluate(Query("kapMax"), in: situation(facts: facts, base: ["kapMax": 10]))
        XCTAssertEqual(lines(kap, from: "pl-armour.A1"), [])
        XCTAssertEqual(notApplied(kap, "pl-armour.A1").map(\.reason), [.suppressed])
        XCTAssertEqual(kap.result, 10)
    }

    // MARK: Phase 5: multiply

    func testMultiplyScalesTheResultWithADeltaLine() throws {
        // TP doubled on 1W6+4 = 7: a line of +7.
        let b = engine.evaluate(Query("tp"), in: situation(owned: ["pl-double": 1], facts: ["choice.double": true],
                                                          base: ["tp": 7]))
        let line = try XCTUnwrap(lines(b, from: "pl-double.D1").first)
        XCTAssertEqual(line.kind, .multiplied)
        XCTAssertEqual([line.value, line.was, line.now], [7, 7, 14])
        XCTAssertEqual(b.result, 14)
        shownSumIsTheResult(b)
    }

    func testMultiplyWithALineScalesOnlyThatLine() throws {
        let s = situation(owned: ["pl-aim": 1, "pl-double": 1, "COND_1": 1],
                          facts: ["choice.aim": true, "choice.halve": true], base: ["at": 14])
        let b = engine.evaluate(Query("at"), in: s)
        XCTAssertEqual(lines(b, from: "pl-aim.A1").map(\.value), [-5])
        let line = try XCTUnwrap(lines(b, from: "pl-double.D2").first)
        XCTAssertEqual(line.kind, .multiplied)
        XCTAssertEqual([line.value, line.was, line.now], [2, -5, -3], "−2.5 rounds up in magnitude to −3")
        XCTAssertEqual(line.via, [ref("pl-aim.A1")])
        XCTAssertEqual(b.result, 14 - 5 + 2 - 1)
    }

    func testMultiplyRoundsTheMagnitudeUpByDefaultAndDownWhenStated() {
        let up = engine.evaluate(Query("item.ladezeit"), in: situation(owned: ["pl-double": 1], base: ["item.ladezeit": 15]))
        XCTAssertEqual(lines(up, from: "pl-double.D3").map(\.value), [-7])
        XCTAssertEqual(up.result, 8, "15 × ½ = 7.5, up: 8 (probe-fernkampf 21.8e)")
        let down = engine.evaluate(Query("pa"), in: situation(owned: ["pl-double": 1], facts: ["choice.halvePa": true],
                                                             base: ["pa": 9]))
        XCTAssertEqual(lines(down, from: "pl-double.D4").map(\.value), [-5])
        XCTAssertEqual(down.result, 4)
    }

    // MARK: Phase 6: cap, floor

    func testTheZustandCapSumsOnlyTheConditionsAddLines() throws {
        // Schmerz III −3 + Belastung II −2 + Betäubung I −1 = −6: a capped line of +1.
        let s = situation(owned: ["pl-cap": 1, "pl-hurt": 3, "pl-tired": 2, "pl-dazed": 1, "pl-aim": 1],
                          facts: ["choice.aim": true], base: ["at": 14])
        let b = engine.evaluate(Query("at"), in: s)
        XCTAssertEqual(b.lines.filter { $0.kind == .add }.map(\.value), [-5, -1, -3, -2])
        let cap = try XCTUnwrap(lines(b, from: "pl-cap.Z3").first)
        XCTAssertEqual(cap.kind, .capped)
        XCTAssertEqual([cap.value, cap.was, cap.now], [1, -6, -5])
        XCTAssertEqual(b.result, 14 - 5 - 6 + 1, "pl-aim's −5 is no condition's")
        shownSumIsTheResult(b)

        // A set is never summed: Schmerz IV's GS 0.
        let gs = engine.evaluate(Query("gs"), in: situation(owned: ["pl-cap": 1, "pl-hurt": 4, "pl-tired": 2],
                                                           base: ["gs": 8]))
        XCTAssertEqual(lines(gs, from: "pl-hurt.C4").map(\.kind), [.set])
        XCTAssertEqual(lines(gs, from: "pl-cap.Z3").map(\.value), [1])
        XCTAssertEqual(gs.result, 8 - 8 - 4 - 2 + 1)

        let under = engine.evaluate(Query("at"), in: situation(owned: ["pl-cap": 1, "pl-hurt": 2, "pl-tired": 2],
                                                              base: ["at": 14]))
        XCTAssertEqual(lines(under, from: "pl-cap.Z3"), [], "−4 is within the cap")
    }

    func testASuppressOfAConditionsLinesLiftsItsCapToo() throws {
        // Task 33 (COND_6.SZ5, schmerz S12): Stufe IV holds GS at 0 over Belastung's −2.
        let held = engine.evaluate(Query("gs"), in: situation(owned: ["pl-fallen": 4, "pl-tired": 2], base: ["gs": 8]))
        XCTAssertEqual(held.result, 0)
        let bound = try XCTUnwrap(lines(held, from: "pl-fallen.F4").first { $0.kind == .capped })
        XCTAssertEqual([bound.value, bound.was, bound.now], [2, -2, 0])
        // The Schip suppresses every condition's lines: the set, the add and the bound alike.
        let schip = engine.evaluate(Query("gs"), in: situation(owned: ["pl-fallen": 4, "pl-tired": 2, "pl-quiet": 1],
                                                               facts: ["choice.schip": true], base: ["gs": 8]))
        XCTAssertEqual(lines(schip, from: "pl-fallen.F4"), [])
        XCTAssertEqual(notApplied(schip, "pl-fallen.F4").map(\.reason), [.suppressed])
        XCTAssertEqual(schip.result, 8)
    }

    func testACapWithAMaxAndAFloorBoundTheResult() throws {
        let fk = engine.evaluate(Query("fk"), in: situation(owned: ["pl-cap": 1], facts: ["gmFact.sicht": 4],
                                                           base: ["fk": 5]))
        let cap = try XCTUnwrap(lines(fk, from: "pl-cap.K1").first)
        XCTAssertEqual(cap.kind, .capped)
        XCTAssertEqual([cap.value, cap.was, cap.now], [-5, 5, 0])
        XCTAssertEqual(fk.result, 0)
        let sp = engine.evaluate(Query("sp"), in: situation(owned: ["pl-cap": 1], base: ["sp": -2]))
        let floor = try XCTUnwrap(lines(sp, from: "pl-cap.F1").first)
        XCTAssertEqual(floor.kind, .floored)
        XCTAssertEqual([floor.value, floor.was, floor.now], [2, -2, 0])
        XCTAssertEqual(sp.result, 0)
        let clear = engine.evaluate(Query("fk"), in: situation(owned: ["pl-cap": 1], base: ["fk": 5]))
        XCTAssertTrue(clear.questions.contains { $0.fact == "gmFact.sicht" })
        XCTAssertEqual(clear.result, 5)
    }

    // MARK: Phase 7: legality

    func testAForbidOnTheQuerySetsLegalFalse() {
        let s = situation(owned: ["pl-defence": 1], facts: ["round.defendedThisAttack": true], base: ["pa": 8, "aw": 7])
        for q in ["pa", "aw"] {
            let b = engine.evaluate(Query(q), in: s)
            XCTAssertFalse(b.legal.allowed, q)
            XCTAssertEqual(b.legal.reasons.map(\.origin), [ref("pl-defence.V1")], q)
            XCTAssertEqual(b.legal.reasons.map(\.reason), [.forbidden], q)
        }
        let free = engine.evaluate(Query("pa"), in: situation(owned: ["pl-defence": 1],
            facts: ["round.defendedThisAttack": false, "round.parries": 0], base: ["pa": 8]))
        XCTAssertTrue(free.legal.allowed)
    }

    func testAResultAtOrBelowZeroIsForbiddenByTheRuleThatSaysSoNeverByTheEngine() {
        let facts: [String: JSONValue] = ["round.defencesMade": 1, "round.defendedThisAttack": false, "round.parries": 0]
        let b = engine.evaluate(Query("pa"), in: situation(owned: ["pl-defence": 1], facts: facts, base: ["pa": 2]))
        XCTAssertEqual(b.result, -1)
        XCTAssertFalse(b.legal.allowed)
        XCTAssertEqual(b.legal.reasons.map(\.origin), [ref("pl-defence.V3")])
        XCTAssertEqual(b.legal.reasons.first?.rulings, ["pl-defence.zero-value"])
        XCTAssertTrue(b.legal.reasons.first?.facts.contains { $0.name == "query.result" && $0.value == .int(-1) } ?? false)
        let noRule = engine.evaluate(Query("pa"), in: situation(facts: facts, base: ["pa": -1]))
        XCTAssertTrue(noRule.legal.allowed, "no built-in check")
        let noBase = engine.evaluate(Query("pa"), in: situation(owned: ["pl-defence": 1], facts: facts))
        XCTAssertTrue(noBase.legal.allowed)
        XCTAssertEqual(notApplied(noBase, "pl-defence.V3").map(\.reason), [.unknownFact])
        XCTAssertFalse(noBase.questions.contains { $0.fact.hasPrefix("query.") }, "nobody states the query's own facts")
    }

    func testARequireForTheQueryThatIsFalseMakesItIllegal() {
        let no = engine.evaluate(Query("aw"), in: situation(owned: ["pl-defence": 1],
            facts: ["gmFact.room": false, "round.defendedThisAttack": false], base: ["aw": 7]))
        XCTAssertFalse(no.legal.allowed)
        XCTAssertEqual(no.legal.reasons.map(\.reason), [.requirementNotMet])
        XCTAssertEqual(no.legal.reasons.map(\.origin), [ref("pl-defence.V5")])
        let unknown = engine.evaluate(Query("aw"), in: situation(owned: ["pl-defence": 1],
            facts: ["round.defendedThisAttack": false], base: ["aw": 7]))
        XCTAssertTrue(unknown.legal.allowed)
        XCTAssertTrue(unknown.questions.contains { $0.fact == "gmFact.room" })
    }

    func testALimitReachedOnItsCountFactMakesTheQueryIllegal() {
        let base = ["pa": 8]
        let reached = engine.evaluate(Query("pa"), in: situation(owned: ["pl-defence": 1],
            facts: ["round.parries": 1, "round.defendedThisAttack": false], base: base))
        XCTAssertFalse(reached.legal.allowed)
        XCTAssertEqual(reached.legal.reasons.map(\.origin), [ref("pl-defence.V4")])
        XCTAssertEqual(reached.legal.reasons.map(\.reason), [.forbidden])
        let first = engine.evaluate(Query("pa"), in: situation(owned: ["pl-defence": 1],
            facts: ["round.parries": 0, "round.defendedThisAttack": false], base: base))
        XCTAssertTrue(first.legal.allowed)
        let unknown = engine.evaluate(Query("pa"), in: situation(owned: ["pl-defence": 1],
            facts: ["round.defendedThisAttack": false], base: base))
        XCTAssertTrue(unknown.questions.contains { $0.fact == "round.parries" && $0.owner == .round })
    }

    func testForbidsWithTheOpponentPrefixAndEveryFiringForbidIsKept() {
        // Extras 7 and 8: indexed under opponent.pa, and both forbids are kept.
        let s = situation(owned: ["pl-opp": 1], facts: ["choice.charge": true], base: ["opponent.pa": 9, "pa": 8])
        let weapon = engine.evaluate(Query("opponent.pa(with: weapon)"), in: s)
        XCTAssertFalse(weapon.legal.allowed)
        XCTAssertEqual(weapon.legal.reasons.map(\.origin), [ref("pl-opp.O1"), ref("pl-opp.O2")])
        let shield = engine.evaluate(Query("opponent.pa(with: shield)"), in: s)
        XCTAssertEqual(shield.legal.reasons.map(\.origin), [ref("pl-opp.O2")])
        XCTAssertTrue(engine.evaluate(Query("pa"), in: s).legal.allowed, "the hero's own parry")
    }

    func testAForbidMatchesADeclaredAction() {
        let s = situation(owned: ["pl-opp": 1], facts: ["action.manoeuvre": "finte", "gmFact.tight": true], base: ["at": 12])
        let b = engine.evaluate(Query("at"), in: s)
        XCTAssertFalse(b.legal.allowed)
        XCTAssertEqual(b.legal.reasons.map(\.origin), [ref("pl-opp.O3")])
        let other = engine.evaluate(Query("at"), in: situation(owned: ["pl-opp": 1],
            facts: ["action.manoeuvre": "wuchtschlag", "gmFact.tight": true], base: ["at": 12]))
        XCTAssertTrue(other.legal.allowed)
    }

    // MARK: Offers

    func testOffersListEveryApplicableOfferWithItsSpanAndCosts() throws {
        let s = situation(owned: ["pl-moves": 1], facts: ["round.phase": "start", "loadout.weapon.technique": "CT_3",
                                                          "hero.mounted": false])
        let offers = engine.offers(in: s)
        let vorstoss = try XCTUnwrap(offer(offers, "vorstoss"))
        XCTAssertEqual(vorstoss.origin, ref("pl-moves.M1"))
        XCTAssertEqual(vorstoss.span, .round)
        XCTAssertTrue(vorstoss.legal)
        let doppel = try XCTUnwrap(offer(offers, "doppel"))
        XCTAssertEqual(doppel.costs.count, 1)
        guard case .cost(let cost)? = doppel.costs.first?.payload else { return XCTFail("a cost") }
        XCTAssertEqual(cost.pool, .actions)
        XCTAssertTrue(doppel.legal)

        let later = engine.offers(in: situation(owned: ["pl-moves": 1], facts: ["round.phase": "end"]))
        XCTAssertNil(offer(later, "vorstoss"), "its when is no")
        XCTAssertNotNil(offer(engine.offers(in: situation(owned: ["pl-moves": 1])), "vorstoss"), "unknown is not no")
        XCTAssertEqual(engine.offers(in: situation()).filter { $0.origin.rule == "pl-moves" }, [], "not owned")
    }

    func testAnOfferIsIllegalWhenAForbidOrARequireRefusesIt() throws {
        let mounted = engine.offers(in: situation(owned: ["pl-moves": 1, "pl-opp": 1],
            facts: ["round.phase": "start", "loadout.weapon.technique": "CT_3", "hero.mounted": true]))
        let doppel = try XCTUnwrap(offer(mounted, "doppel"))
        XCTAssertFalse(doppel.legal)
        XCTAssertEqual(doppel.because, "pl-moves.M4")
        XCTAssertEqual(doppel.reasons.map(\.origin), [ref("pl-moves.M4"), ref("pl-opp.O4")],
                       "its own forbid, and the one on every mounted special manoeuvre: pl-moves is one")
        XCTAssertEqual(doppel.reasons.map(\.reason), [.forbidden, .forbidden])
        let vorstoss = try XCTUnwrap(offer(mounted, "vorstoss"))
        XCTAssertFalse(vorstoss.legal)
        XCTAssertEqual(vorstoss.reasons.map(\.origin), [ref("pl-opp.O4")], "a forbid on the rule's manoeuvre kind")

        let hurt = engine.offers(in: situation(owned: ["pl-moves": 1, "pl-pain": 1],
            facts: ["round.phase": "start", "loadout.weapon.technique": "CT_1", "hero.mounted": false]))
        XCTAssertEqual(offer(hurt, "doppel")?.reasons.map(\.origin), [ref("pl-moves.M2"), ref("pl-moves.M4")])
        XCTAssertEqual(offer(hurt, "doppel")?.reasons.map(\.reason), [.requirementNotMet, .requirementNotMet])
        XCTAssertEqual(offer(hurt, "vorstoss")?.reasons.map(\.origin), [ref("pl-moves.M2")], "the rule's own require")
    }

    func testEvaluatePutsTheOffersThatReachTheQuery() {
        let b = engine.evaluate(Query("at"), in: situation(owned: ["pl-moves": 1], base: ["at": 12]))
        XCTAssertNotNil(offer(b.offers, "doppel"))
    }

    func testLimitsOverAChoicesOptionsBoundItAndRefuseAnOptionBeyondThem() throws {
        // zaubermodifikationen.ZM1/ZM2: FW 5 → at most 1; a and c chosen, so c is refused and adds nothing.
        let s = situation(owned: ["pl-spell": 1], facts: ["check.spell": "SPELL_1", "fw.SPELL_1": 5,
                                                          "choice.mod.a": true, "choice.mod.c": true])
        let mod = try XCTUnwrap(offer(engine.offers(in: s), "mod"))
        XCTAssertEqual(mod.max, 1)
        XCTAssertTrue(mod.legal)
        XCTAssertEqual(mod.refused.map(\.option), ["a", "b", "c"])
        XCTAssertEqual(mod.refused.first { $0.option == "b" }?.reasons.map(\.origin),
                       [ref("pl-spell.S1"), ref("pl-spell.S2")])
        let b = engine.evaluate(Query("check.modifier"), in: s)
        XCTAssertEqual(lines(b, from: "pl-spell.S3").map(\.value), [2], "c is beyond the limit: no +1")
    }

    // MARK: Texts, questions, free lines

    func testTellsAsksAndUnencodedClausesFillTheTextsAndQuestions() throws {
        let s = situation(owned: ["pl-talk": 1], facts: ["gmFact.alarm": true], base: ["ini": 10])
        let b = engine.evaluate(Query("ini"), in: s)
        XCTAssertTrue(b.texts.contains(TextLine(kind: .tell, audience: .gm, text: "Achtung.", origin: ref("pl-talk.T1"))))
        XCTAssertTrue(b.texts.contains(TextLine(kind: .unencoded, text: "Ein Satz, den die App nicht abbilden kann.",
                                                origin: ref("pl-talk.T3"))))
        let q = try XCTUnwrap(b.questions.first { $0.fact == "target.cover" })
        XCTAssertEqual(q.owner, .gm)
        XCTAssertEqual(q.options, ["keine", "teilweise"])
        XCTAssertEqual(q.origins, [ref("pl-talk.T2")])
        let answered = engine.evaluate(Query("ini"), in: situation(owned: ["pl-talk": 1],
            facts: ["gmFact.alarm": false, "target.cover": "keine"], base: ["ini": 10]))
        XCTAssertFalse(answered.questions.contains { $0.fact == "target.cover" })
        XCTAssertFalse(answered.texts.contains { $0.text == "Achtung." })
    }

    func testAFreeModifierAndTheGMsAreLinesWithTheirOwners() throws {
        let s = situation(facts: ["choice.freeModifier.at": -2, "gmFact.modifier.at": 1], base: ["at": 10])
        let b = engine.evaluate(Query("at"), in: s)
        let free = try XCTUnwrap(b.lines.first { $0.kind == .free })
        XCTAssertEqual(free.value, -2)
        XCTAssertEqual(free.owner, .player)
        XCTAssertEqual(free.note, "frei eingegeben")
        XCTAssertEqual(free.facts.map(\.name), ["choice.freeModifier.at"])
        let gm = try XCTUnwrap(b.lines.first { $0.owner == .gm })
        XCTAssertEqual(gm.kind, .add)
        XCTAssertEqual(gm.value, 1)
        XCTAssertEqual(b.result, 9)
        shownSumIsTheResult(b)
    }

    func testAValueThatCannotBeComputedGivesATextAndNoLine() throws {
        // §11: a table key with no row, and an operand beyond the recursion depth.
        let table = engine.evaluate(Query("fk"), in: situation(facts: ["attr.KO": -1], base: ["fk": 10]))
        XCTAssertEqual(lines(table, from: "pl-kampfwerte.T2"), [])
        let text = try XCTUnwrap(table.texts.first { $0.origin == ref("pl-kampfwerte.T2") })
        XCTAssertEqual(text.kind, .notApplicable)
        XCTAssertTrue(text.text.hasPrefix("Regel konnte nicht angewandt werden: pl-kampfwerte.T2 – "), text.text)
        XCTAssertEqual(table.result, 10)
        let deep = engine.evaluate(Query("tp"), in: situation(base: ["tp": 3]))
        XCTAssertEqual(lines(deep, from: "pl-loop.L1"), [])
        XCTAssertTrue(deep.texts.contains { $0.text.hasPrefix("Regel konnte nicht angewandt werden: pl-loop.L1 – ") })
    }

    // MARK: Fix round 1

    func testAManoeuvreLimitIsTheChoicesNotPhase7s() {
        // kampfsonderfertigkeiten.KS3: nothing in phase 7 counts manoeuvres.
        let b = engine.evaluate(Query("at"), in: situation(owned: ["pl-opp": 1],
            facts: ["action.manoeuvre": "pl-aim", "gmFact.tight": false], base: ["at": 12]))
        XCTAssertFalse(b.texts.contains { $0.origin == ref("pl-opp.O5") }, "\(b.texts)")
        XCTAssertTrue(b.legal.allowed)
    }

    func testAnActionSelectorNamesTheHerosActionQueriesOnly() {
        // R37: STATE_8.H2 [any] and SA_65.VH1 [aktion] name at, fk, check.*; not a defence, not tp.
        let s = situation(owned: ["pl-still": 1], facts: ["gmFact.frozen": true, "choice.stance": true],
                          base: ["at": 12, "pa": 8, "tp": 5, "opponent.rs": 2])
        for q in ["at", "fk", "check.modifier(talent: TAL_1)"] {
            XCTAssertEqual(engine.evaluate(Query(q), in: s).legal.reasons.map(\.origin),
                           [ref("pl-still.S1"), ref("pl-still.S2")], q)
        }
        for q in ["pa", "aw", "tp", "opponent.rs"] {
            XCTAssertTrue(engine.evaluate(Query(q), in: s).legal.allowed, q)
        }
    }

    func testActionAttackIsAnOutcomeNeverADeclaration() {
        let s = situation(owned: ["pl-still": 1], facts: ["action.attack": "hit", "gmFact.hitCheck": true,
                                                          "gmFact.frozen": false, "choice.stance": false], base: ["at": 12])
        XCTAssertTrue(engine.evaluate(Query("at"), in: s).legal.allowed)
    }

    func testAKnownDerivedLevelAsksTheQuestionsThatCouldChangeIt() throws {
        // R38: carryingCapacity 25 gives pl-weak II; P1's open when on that input is asked, the level used.
        let s = situation(base: ["carryingCapacity": 25, "at": 14])
        XCTAssertEqual(engine.evaluate(Query("level(rule: pl-weak)"), in: s).result, 2)
        let b = engine.evaluate(Query("at"), in: s)
        XCTAssertEqual(lines(b, from: "pl-weak.W2").map(\.value), [-2])
        XCTAssertTrue(b.questions.contains { $0.fact == "gmFact.drain" && $0.origins.contains(ref("pl-weak.W2")) },
                      "\(b.questions)")
        let known = engine.evaluate(Query("at"), in: situation(facts: ["gmFact.drain": false],
                                                              base: ["carryingCapacity": 25, "at": 14]))
        XCTAssertFalse(known.questions.contains { $0.fact == "gmFact.drain" })
    }

    func testASuppressedClauseStopsItsOffersAsksAndForbidsToo() {
        // Q4 names only an ask, an offer and a forbid: no line of this query.
        let s = situation(owned: ["pl-quiet": 1, "pl-talk": 1, "pl-moves": 1, "pl-defence": 1],
                          facts: ["choice.hush": true, "round.defendedThisAttack": false, "round.defencesMade": 1,
                                  "round.parries": 0], base: ["pa": 2])
        let b = engine.evaluate(Query("pa"), in: s)
        XCTAssertEqual(b.result, -1)
        XCTAssertTrue(b.legal.allowed, "V3's forbid is suppressed with its clause")
        XCTAssertNil(offer(b.offers, "doppel"))
        XCTAssertFalse(b.questions.contains { $0.fact == "target.cover" })
        for c in ["pl-talk.T2", "pl-moves.M3", "pl-defence.V3"] {
            XCTAssertTrue(notApplied(b, c).contains { $0.reason == .suppressed }, c)
        }
    }

    func testANumberBeyondIntGivesATextNotATrap() throws {
        let huge = situation(owned: ["pl-adds": 1], facts: ["round.parries": .double(1e300),
                                                            "choice.freeModifier.pa": .double(1e300)], base: ["pa": 8])
        let b = engine.evaluate(Query("pa"), in: huge)
        XCTAssertEqual(lines(b, from: "pl-adds.A2"), [])
        XCTAssertTrue(b.texts.contains { $0.origin == ref("pl-adds.A2") && $0.kind == .notApplicable })
        XCTAssertFalse(b.lines.contains { $0.kind == .free })
        XCTAssertTrue(b.texts.contains { $0.text.hasPrefix("Regel konnte nicht angewandt werden: choice.freeModifier.pa") })
    }

    // MARK: Carried from the Task 22 review

    func testASuppressorsOwnLevelIsReadAsItsDerivesAre() throws {
        // Extra 1: hero.levelOf.pl-alt and level(rule: pl-alt) agree.
        let s = situation(owned: ["pl-alt-reader": 1],
                          facts: ["gmFact.altA": 2, "gmFact.altB": 1, "gmFact.altMode": true], base: ["regeneration.kap": 0])
        XCTAssertEqual(engine.evaluate(Query("level(rule: pl-alt)"), in: s).result, 1)
        let b = engine.evaluate(Query("regeneration.kap"), in: s)
        XCTAssertEqual(lines(b, from: "pl-alt-reader.R1").map(\.value), [1])
    }

    func testAnUnknownLevelWithNoFactToAskGivesAText() throws {
        // Extra 2: pl-broken's level reads a table with no row.
        let b = engine.evaluate(Query("aspMax"), in: situation(facts: ["attr.KO": -1], base: ["aspMax": 20]))
        XCTAssertEqual(lines(b, from: "pl-broken.B2"), [])
        XCTAssertFalse(notApplied(b, "pl-broken.B2").contains { $0.reason == .unknownFact })
        let text = try XCTUnwrap(b.texts.first { $0.origin == ref("pl-broken.B2") })
        XCTAssertTrue(text.text.hasPrefix("Regel konnte nicht angewandt werden: pl-broken.B2 – "), text.text)
    }

    func testAnUnknownWhenInALevelsDerivesLeavesTheLevelUnknown() {
        // Extra 3: W1 gives 2, W2's +1 hangs on gmFact.w2.
        let unknown = engine.evaluate(Query("aspCurrent"), in: situation(facts: ["gmFact.w1": 2], base: ["aspCurrent": 20]))
        XCTAssertEqual(lines(unknown, from: "pl-two.W3"), [])
        XCTAssertEqual(notApplied(unknown, "pl-two.W3").map(\.reason), [.unknownFact])
        XCTAssertTrue(unknown.questions.contains { $0.fact == "gmFact.w2" })
        let known = engine.evaluate(Query("aspCurrent"), in: situation(facts: ["gmFact.w1": 2, "gmFact.w2": false],
                                                                      base: ["aspCurrent": 20]))
        XCTAssertEqual(lines(known, from: "pl-two.W3").map(\.value), [-2])
    }
}

extension JSONValue: ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral, ExpressibleByStringLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(stringLiteral value: String) { self = .string(value) }
}
