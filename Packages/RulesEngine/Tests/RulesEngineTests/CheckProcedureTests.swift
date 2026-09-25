import XCTest
@testable import RulesEngine

/// The 3W20 check as a staged procedure (spec §6, plan Task 26): start → dice → reroll →
/// confirm. The numbers are probe-fertigkeiten's (situations 22.x): KL 12, IN 14, GE 12, KO 13,
/// KK 12; Sinnesschärfe (TAL_10, KL/IN/IN) FW 8 with Begabung and the specialisation Suchen;
/// Schwimmen (TAL_7, GE/KO/KK) FW 4.
///
/// Two books: the real `build/rules/rules.json` (where SA_9.FS1 and TAL_7.critical rest on open
/// rulings and so apply nothing), and the fixture `Fixtures/checks-rules.json` (source
/// `Tests/FixtureRules/checks`) with the same shapes, their rulings decided, plus a Schip's
/// Neuer Wurf, the `check` verb's `onSuccess` / `onFailure`, a cost halved on failure and
/// SA_74.VP2's forbid-in-onFailure.
final class CheckProcedureTests: XCTestCase {
    static let real: Engine? = {
        guard let book = try? RuleBook.load(from: Repo.url("build/rules/rules.json")) else { return nil }
        return Engine(book: book)
    }()
    static let fixture: Engine = {
        let url = Bundle.module.url(forResource: "checks-rules", withExtension: "json", subdirectory: "Fixtures")!
        return Engine(book: try! RuleBook.load(from: url))
    }()

    private func real() throws -> Engine { try XCTUnwrap(Self.real, "run make rules-json") }
    private var fixture: Engine { Self.fixture }

    private func ref(_ s: String) -> ClauseRef { ClauseRef(s)! }

    /// The probe-fertigkeiten hero. `advantage` / `specialisation` name the rules owning the
    /// Begabung and the specialisation (the real ids or the fixture's).
    private func hero(_ facts: [String: JSONValue] = [:], advantage: String = "ADV_4", specialisation: String = "SA_9",
                      owned more: [String: OwnedRule] = [:], pools: [Pool: PoolState] = [:]) -> Situation {
        var all: [String: JSONValue] = ["attr.KL": 12, "attr.IN": 14, "attr.GE": 12, "attr.KO": 13, "attr.KK": 12,
                                        "attr.MU": 13, "attr.CH": 11, "fw.TAL_10": 8, "fw.TAL_7": 4, "fw.TAL_23": 6,
                                        "fw.TAL_8": 5, "fw.SPELL_1": 7, "fw.chk-schwimmen": 4]
        for (k, v) in facts { all[k] = v }
        var owned = [advantage: OwnedRule(level: 1, option: "TAL_10"),
                     specialisation: OwnedRule(level: 1, option: "TAL_10", option2: "Suchen")]
        for (k, v) in more { owned[k] = v }
        return Situation(owned: owned,
                         facts: all.map { Fact(name: $0.key, value: $0.value, owner: Vocabulary.owner(ofFact: $0.key) ?? .sheet) },
                         pools: pools)
    }

    private let sinnesschaerfe = { (application: String?) in
        CheckRequest(kind: .talent, id: "TAL_10", attributes: ["KL", "IN", "IN"], application: application)
    }
    private let schwimmen = CheckRequest(kind: .talent, id: "TAL_7", attributes: ["GE", "KO", "KK"])

    /// start, then dice.
    private func rolled(_ r: CheckRequest, _ s: Situation, _ dice: [Int], _ engine: Engine) -> StepResult {
        CheckProcedure.start(r, in: s, engine: engine).state.step(.dice(dice), engine: engine)
    }

    private func result(_ step: StepResult, file: StaticString = #filePath, line: UInt = #line) throws -> CheckResult {
        try XCTUnwrap(step.state.result, "no result: \(step.texts.map(\.text))", file: file, line: line)
    }

    // MARK: - start

    /// 22.2: three `check.attribute(index: i)` breakdowns (the attribute, then the shared
    /// modifier's lines), the shared `check.modifier` and `check.fw` (FP3's FW), awaiting dice.
    func testStartGivesTheThreeAttributesTheModifierAndTheFW() throws {
        let engine = try real()
        let step = CheckProcedure.start(sinnesschaerfe("Wahrnehmen"), in: hero(), engine: engine)
        guard case .awaitingDice(let stages) = step.state else { return XCTFail("\(step.state)") }
        XCTAssertEqual(stages.attributes.map(\.query.description),
                       ["check.attribute(index: 0)", "check.attribute(index: 1)", "check.attribute(index: 2)"])
        XCTAssertEqual(stages.attributes.map(\.result), [12, 14, 14])
        XCTAssertEqual(stages.attributes[0].base?.facts.map(\.name), ["attr.KL"])
        XCTAssertEqual(stages.modifier.query.description, "check.modifier(talent: TAL_10)")
        XCTAssertEqual(stages.fw.query.description, "check.fw(talent: TAL_10)")
        XCTAssertEqual(stages.fw.result, 8)
        XCTAssertEqual(stages.fw.shownLines.map(\.origin), [ref("fertigkeitsproben.FP3")])
        XCTAssertTrue(stages.legal.allowed)
        XCTAssertEqual(step.breakdowns.map(\.query.name),
                       ["check.modifier", "check.attribute", "check.attribute", "check.attribute", "check.fw"])
        XCTAssertEqual(step.offers, [])
        XCTAssertEqual(step.events, [])
        // The check states its facts for the rules: the kind, the talent, the Anwendungsgebiet.
        XCTAssertEqual(stages.situation.facts["check.talent"]?.value, "TAL_10")
        XCTAssertEqual(stages.situation.facts["check.application"]?.value, "Wahrnehmen")
    }

    /// 22.3 (MIGRATION "Notes for the engine tasks"): the GM's −1 is one line of the shared
    /// `check.modifier`, owner gm, and each attribute breakdown carries it.
    func testTheGMsModifierIsALineOfEveryAttributeWithOwnerGM() throws {
        let engine = try real()
        let step = CheckProcedure.start(sinnesschaerfe("Suchen"), in: hero(["gmFact.checkModifier": -1]), engine: engine)
        let stages = step.state.stages
        XCTAssertEqual(stages.attributes.map(\.result), [11, 13, 13])
        for b in [stages.modifier] + stages.attributes {
            let gm = b.lines.filter { $0.origin == ref("fertigkeitsproben.FM2") }
            XCTAssertEqual(gm.map(\.value), [-1], "\(b.query)")
            XCTAssertEqual(gm.map(\.owner), [.gm], "\(b.query)")
        }
    }

    /// 22.9: an Erschwernis that takes an attribute to 0 makes the check illegal (FP2); dice
    /// are refused with a text, and the state stays where it was.
    func testAnAttributeAtZeroMakesTheCheckIllegal() throws {
        let engine = try real()
        let start = CheckProcedure.start(sinnesschaerfe("Wahrnehmen"), in: hero(["gmFact.checkModifier": -12]), engine: engine)
        let stages = start.state.stages
        XCTAssertEqual(stages.attributes.map(\.result), [0, 2, 2])
        XCTAssertFalse(stages.legal.allowed)
        XCTAssertEqual(stages.legal.reasons.map(\.origin), [ref("fertigkeitsproben.FP2")])
        XCTAssertEqual(stages.attributes.map(\.legal.allowed), [false, true, true])
        let dice = start.state.step(.dice([3, 3, 3]), engine: engine)
        XCTAssertEqual(dice.state, start.state)
        XCTAssertTrue(dice.texts.contains { $0.text.contains("fertigkeitsproben.FP2") }, "\(dice.texts)")
    }

    // MARK: - dice

    /// 22.2: [15, 16, 10] against [12, 14, 14] with FW 8: spent [3, 2, 0], FP 3, QS 1, a success;
    /// the Begabung is offered (ADV_4.B1: the check is on its Fertigkeit).
    func testTheDiceGiveTheSpendTheFPAndTheQS() throws {
        let engine = try real()
        let step = rolled(sinnesschaerfe("Wahrnehmen"), hero(), [15, 16, 10], engine)
        let r = try result(step)
        XCTAssertEqual(r.eew, [12, 14, 14])
        XCTAssertEqual(r.spent, [3, 2, 0])
        XCTAssertEqual(r.fp, 3)
        XCTAssertEqual(r.qs, 1)
        XCTAssertEqual(r.success, true)
        XCTAssertEqual(r.kind, .regular)
        XCTAssertNil(r.from)
        XCTAssertEqual(r.fpStage.shownLines.map(\.origin), [ref("fertigkeitsproben.FP5"), ref("fertigkeitsproben.FP5")])
        XCTAssertEqual(r.qsStage.base?.origin, ref("fertigkeitsproben.QS1"))
        XCTAssertEqual(step.offers.map(\.origin), [ref("ADV_4.B1")])
        XCTAssertEqual(step.offers.map(\.legal), [true])
        XCTAssertEqual(step.offers.first?.remaining, 1)
        // The facts the rules read once the dice are in.
        XCTAssertEqual(r.situation.facts["check.spent"]?.value, 5)
        XCTAssertEqual(r.situation.facts["check.ones"]?.value, 0)
        XCTAssertEqual(r.situation.facts["check.twenties"]?.value, 0)
        XCTAssertEqual(r.situation.facts["check.result"]?.value, "success")
    }

    /// 22.7 before the reroll: [18, 19, 17]: spent [6, 5, 3], FP −6 (not floored: QS2 is for a
    /// passed check), a failure with no QS.
    func testAFailureKeepsItsNegativeFP() throws {
        let engine = try real()
        let r = try result(rolled(sinnesschaerfe("Wahrnehmen"), hero(), [18, 19, 17], engine))
        XCTAssertEqual(r.spent, [6, 5, 3])
        XCTAssertEqual(r.fp, -6)
        XCTAssertEqual(r.success, false)
        XCTAssertNil(r.qs)
        XCTAssertEqual(r.situation.facts["check.result"]?.value, "failure")
    }

    /// 22.6: a Doppel-20 is a Patzer, named by fertigkeitsproben.PZ1 (MIGRATION), and the
    /// Begabung is forbidden by ADV_4.B5.
    func testADoppel20IsAPatzerAndTheBegabungIsForbidden() throws {
        let engine = try real()
        let step = rolled(sinnesschaerfe("Wahrnehmen"), hero(), [20, 20, 7], engine)
        let r = try result(step)
        XCTAssertEqual(r.success, false)
        XCTAssertEqual(r.kind, .patzer)
        XCTAssertEqual(r.from, ref("fertigkeitsproben.PZ1"))
        XCTAssertEqual(r.twenties, 2)
        let b1 = try XCTUnwrap(step.offers.first { $0.origin == ref("ADV_4.B1") })
        XCTAssertFalse(b1.legal)
        XCTAssertEqual(b1.reasons.map(\.origin), [ref("ADV_4.B5")])
        XCTAssertEqual(b1.because, "Doppel-20: Begabung nicht erlaubt")
        let refused = step.state.step(.reroll(die: 0, face: 3), engine: engine)
        XCTAssertEqual(refused.state, step.state)
        XCTAssertFalse(refused.texts.isEmpty)
    }

    /// 22.8: a Doppel-1 is a success whatever the FP (KR1). On the real rules TAL_7's
    /// "FP = doppelter FW" rests on the open ruling crit-qs, so the FP are the rolled −1 lifted
    /// to 1 by QS2; the talent's text is told.
    func testADoppel1IsACriticalSuccess() throws {
        let engine = try real()
        let step = rolled(schwimmen, hero(), [1, 1, 17], engine)
        let r = try result(step)
        XCTAssertEqual(r.eew, [12, 13, 12])
        XCTAssertEqual(r.spent, [0, 0, 5])
        XCTAssertEqual(r.success, true)
        XCTAssertEqual(r.kind, .kritischerErfolg)
        XCTAssertEqual(r.from, ref("fertigkeitsproben.KR1"))
        XCTAssertEqual(r.fp, 1)
        XCTAssertEqual(r.fpStage.lines.map(\.kind), [.floored])
        XCTAssertTrue(r.fpStage.texts.contains { $0.kind == .openRuling && $0.ruling == "fertigkeitsproben.crit-qs" })
        XCTAssertTrue(step.texts.contains { $0.text == "Der Held schwimmt die Strecke in Bestzeit." && $0.audience == .player })
    }

    /// The same Doppel-1 with crit-qs decided (the fixture): FP = 2 × FW 4 = 8, QS 3.
    func testADoppel1WithTheCritRulingDecidedDoublesTheFW() throws {
        let r = try result(rolled(CheckRequest(kind: .talent, id: "chk-schwimmen", attributes: ["GE", "KO", "KK"]),
                                  hero(advantage: "chk-begabung", specialisation: "chk-spez"), [1, 1, 17], fixture))
        XCTAssertEqual(r.fp, 8)
        XCTAssertEqual(r.qs, 3)
        XCTAssertEqual(r.fpStage.lines.first?.origin, ref("chk-schwimmen.critical"))
        XCTAssertEqual(r.kind, .kritischerErfolg)
        XCTAssertEqual(r.from, ref("chk-proben.KR1"))
        let triple = try result(rolled(CheckRequest(kind: .talent, id: "chk-schwimmen", attributes: ["GE", "KO", "KK"]),
                                       hero(advantage: "chk-begabung", specialisation: "chk-spez"), [1, 1, 1], fixture))
        XCTAssertEqual(triple.kind, .dreifach1)
        XCTAssertEqual(triple.from, ref("chk-proben.KR2"))
        let botch = try result(rolled(sinnesschaerfe("Wahrnehmen"), hero(advantage: "chk-begabung", specialisation: "chk-spez"),
                                      [20, 20, 20], fixture))
        XCTAssertEqual(botch.kind, .dreifach20)
        XCTAssertEqual(botch.from, ref("chk-proben.PZ1"))
    }

    /// 22.1 and 22.3 with the specialisation's ruling decided: +2 on the FW, its own line, not an
    /// Erleichterung. 22.1: FW 10, spent [3, 2, 0], FP 5, QS 2. 22.3: EEW [11, 13, 13], spent
    /// [2, 5, 0], FP 3, QS 1. Wahrnehmen gets no +2.
    func testTheSpecialisationAddsToTheFWNotToTheAttributes() throws {
        let s = hero(advantage: "chk-begabung", specialisation: "chk-spez")
        let suchen = rolled(sinnesschaerfe("Suchen"), s, [15, 16, 10], fixture)
        XCTAssertEqual(suchen.state.stages.fw.result, 10)
        XCTAssertEqual(suchen.state.stages.fw.shownLines.map(\.origin), [ref("chk-proben.FP3"), ref("chk-spez.FS1")])
        XCTAssertEqual(suchen.state.stages.fw.shownLines.map(\.value), [8, 2])
        var r = try result(suchen)
        XCTAssertEqual(r.eew, [12, 14, 14])
        XCTAssertEqual([r.fp, r.qs], [5, 2])

        let harder = rolled(sinnesschaerfe("Suchen"), hero(["gmFact.checkModifier": -1], advantage: "chk-begabung",
                                                           specialisation: "chk-spez"), [13, 18, 9], fixture)
        r = try result(harder)
        XCTAssertEqual(r.eew, [11, 13, 13])
        XCTAssertEqual(r.spent, [2, 5, 0])
        XCTAssertEqual([r.fp, r.qs], [3, 1])

        let other = rolled(sinnesschaerfe("Wahrnehmen"), s, [15, 16, 10], fixture)
        XCTAssertEqual(other.state.stages.fw.result, 8)
        XCTAssertTrue(other.state.stages.fw.notApplied.contains { $0.origin == ref("chk-spez.FS1") && $0.reason == .conditionFalse })
    }

    /// `check.onOption` / `check.applicationOnOption` come from the owned instance of the rule
    /// that reads them; an Anwendungsgebiet nobody stated asks the player for `check.application`.
    func testTheOptionFactsComeFromTheOwnedInstance() throws {
        let s = hero(advantage: "chk-begabung", specialisation: "chk-spez")
        let unknown = CheckProcedure.start(sinnesschaerfe(nil), in: s, engine: fixture)
        XCTAssertEqual(unknown.state.stages.fw.result, 8)
        XCTAssertEqual(unknown.state.stages.fw.questions.map(\.fact), ["check.application"])
        XCTAssertEqual(unknown.state.stages.fw.questions.first?.owner, .player)
        // Another talent: not the instance's Fertigkeit, so neither the +2 nor the Begabung.
        let other = rolled(CheckRequest(kind: .talent, id: "TAL_23", attributes: ["MU", "IN", "CH"], application: "Suchen"),
                           s, [5, 5, 5], fixture)
        XCTAssertEqual(other.state.stages.fw.result, 6)
        XCTAssertEqual(other.offers.map(\.origin), [ref("chk-schip.NW1")])
    }

    // MARK: - reroll

    /// 22.4: [5, 19, 12]: spent [0, 5, 0], FP 3, QS 1. The Begabung rerolls die 2 (index 1) to 11:
    /// spent [0, 0, 0], FP 8, QS 3. A `.rerolled` line "W2: 19 → 11, Begabung" keeps both faces;
    /// the Begabung is used up.
    func testARerollReplacesTheDieAndTheLogKeepsBothFaces() throws {
        let engine = try real()
        let before = rolled(sinnesschaerfe("Wahrnehmen"), hero(), [5, 19, 12], engine)
        var r = try result(before)
        XCTAssertEqual(r.spent, [0, 5, 0])
        XCTAssertEqual([r.fp, r.qs], [3, 1])

        let after = before.state.step(.reroll(die: 1, face: 11), engine: engine)
        r = try result(after)
        XCTAssertEqual(r.faces, [5, 11, 12])
        XCTAssertEqual(r.rolled, [[5], [19, 11], [12]])
        XCTAssertEqual(r.spent, [0, 0, 0])
        XCTAssertEqual([r.fp, r.qs], [8, 3])
        let line = try XCTUnwrap(r.dice.lines.first)
        XCTAssertEqual(line.kind, .rerolled)
        XCTAssertEqual(line.note, "W2: 19 → 11, Begabung")
        XCTAssertEqual(line.origin, ref("ADV_4.B1"))
        XCTAssertEqual([line.was, line.now], [19, 11])
        XCTAssertEqual(line.value, -8)
        XCTAssertEqual(r.rerolls.map(\.die), [1])
        XCTAssertEqual(r.rerolls.map(\.counts), [11])
        XCTAssertEqual(after.offers, [], "the Begabung is used")
        XCTAssertEqual(after.breakdowns.map(\.query.name), ["check.dice", "check.fp", "check.qs"])
    }

    /// 22.5: the better of both dice counts: a rerolled 20 over a 19 leaves the 19, so no Patzer.
    func testTheBetterDieCounts() throws {
        let engine = try real()
        let after = rolled(sinnesschaerfe("Wahrnehmen"), hero(), [5, 19, 12], engine).state
            .step(.reroll(die: 1, face: 20), engine: engine)
        let r = try result(after)
        XCTAssertEqual(r.faces, [5, 19, 12])
        XCTAssertEqual(r.rolled[1], [19, 20])
        XCTAssertEqual(r.twenties, 0)
        XCTAssertEqual(r.kind, .regular)
        XCTAssertEqual([r.fp, r.qs], [3, 1])
        XCTAssertEqual(r.dice.lines.first?.note, "W2: 19 → 20, Begabung")
        XCTAssertEqual(r.dice.lines.first?.now, 19)
    }

    /// Begabung and a Schip in either order (ADV_4.B7), each offered until used; the second sees
    /// the dice the first left.
    func testBegabungAndASchipInEitherOrder() throws {
        let s = hero(advantage: "chk-begabung", specialisation: "chk-spez")
        let start = rolled(sinnesschaerfe("Wahrnehmen"), s, [18, 19, 17], fixture)
        XCTAssertEqual(start.offers.map(\.origin), [ref("chk-begabung.B1"), ref("chk-schip.NW1")])

        let schipFirst = start.state.step(.reroll(die: 0, face: 20, using: ref("chk-schip.NW1")), engine: fixture)
        XCTAssertEqual(schipFirst.offers.map(\.origin), [ref("chk-begabung.B1")])
        XCTAssertEqual(try result(schipFirst).faces, [20, 19, 17], "a Schip keeps the new die")
        let both1 = schipFirst.state.step(.reroll(die: 0, face: 3, using: ref("chk-begabung.B1")), engine: fixture)
        XCTAssertEqual(try result(both1).faces, [3, 19, 17])
        XCTAssertEqual(try result(both1).rolled[0], [18, 20, 3])
        XCTAssertEqual(both1.offers, [])

        let begabungFirst = start.state.step(.reroll(die: 0, face: 3, using: ref("chk-begabung.B1")), engine: fixture)
        XCTAssertEqual(begabungFirst.offers.map(\.origin), [ref("chk-schip.NW1")])
        let both2 = begabungFirst.state.step(.reroll(die: 1, face: 2, using: ref("chk-schip.NW1")), engine: fixture)
        let r = try result(both2)
        XCTAssertEqual(r.faces, [3, 2, 17])
        XCTAssertEqual(r.dice.lines.map(\.note), ["W1: 18 → 3, Begabung", "W2: 19 → 2, Schip"])
        XCTAssertEqual(both2.offers, [])
        // Used up: a third reroll is refused, and nothing changes.
        let third = both2.state.step(.reroll(die: 2, face: 1), engine: fixture)
        XCTAssertEqual(third.state, both2.state)
        XCTAssertFalse(third.texts.isEmpty)
    }

    // MARK: - confirm

    /// `.confirm` gives `check.qs` and logs the QS.
    func testConfirmLogsTheQS() throws {
        let engine = try real()
        let step = rolled(sinnesschaerfe("Wahrnehmen"), hero(), [15, 16, 10], engine).state.step(.confirm, engine: engine)
        guard case .confirmed(_, let r, let events) = step.state else { return XCTFail("\(step.state)") }
        XCTAssertEqual(r.qs, 1)
        XCTAssertEqual(step.breakdowns.map(\.query.name), ["check.fp", "check.qs"])
        XCTAssertEqual(events, step.events)
        let logged = events.filter { $0.kind == .logged }
        XCTAssertEqual(logged.map(\.note), ["TAL_10: gelungen, QS 1"])
        let failed = rolled(sinnesschaerfe("Wahrnehmen"), hero(), [18, 19, 17], engine).state.step(.confirm, engine: engine)
        XCTAssertEqual(failed.events.filter { $0.kind == .logged }.map(\.note), ["TAL_10: misslungen"])
        // Nothing after a confirm.
        let again = step.state.step(.confirm, engine: engine)
        XCTAssertEqual(again.state, step.state)
        XCTAssertEqual(again.events, [])
    }

    /// Plan Task 26: a failed Autoritätsglaube (Willenskraft) check logs "gibt nach": DISADV_37.SE2's
    /// tell, which reads the result, fires at `.confirm` and is logged.
    func testAFailedAutoritaetsglaubeCheckLogsGibtNach() throws {
        let engine = try real()
        let s = hero(["gmFact.trigger": "DISADV_37"], owned: ["DISADV_37": OwnedRule(level: 1, option: 2)])
        let willenskraft = CheckRequest(kind: .talent, id: "TAL_23", attributes: ["MU", "IN", "CH"])
        let failed = rolled(willenskraft, s, [19, 18, 20], engine).state.step(.confirm, engine: engine)
        let told = failed.events.filter { $0.kind == .logged && $0.origin == ref("DISADV_37.SE2") }
        XCTAssertEqual(told.map(\.note), ["gibt der Schlechten Eigenschaft nach"])
        let passed = rolled(willenskraft, s, [3, 3, 3], engine).state.step(.confirm, engine: engine)
        XCTAssertEqual(passed.events.filter { $0.origin == ref("DISADV_37.SE2") }, [])
    }

    /// A `check` effect naming this check runs its `onSuccess` or `onFailure` at `.confirm`
    /// (fixture chk-wille.SE1, the COND_6.SZ2 / DISADV_37.SE1 shape).
    func testACheckEffectRunsItsOnSuccessOrOnFailure() throws {
        let s = hero(["gmFact.trigger": "chk-wille"], advantage: "chk-begabung", specialisation: "chk-spez",
                     owned: ["chk-wille": OwnedRule()])
        let willenskraft = CheckRequest(kind: .talent, id: "TAL_23", attributes: ["MU", "IN", "CH"])
        let failed = rolled(willenskraft, s, [19, 18, 20], fixture).state.step(.confirm, engine: fixture)
        XCTAssertEqual(failed.events.filter { $0.kind == .gained }.map(\.rule), ["chk-bann"])
        XCTAssertEqual(failed.events.first { $0.kind == .gained }?.origin, ref("chk-wille.SE1"))
        XCTAssertEqual(failed.events.filter { $0.kind == .logged }.map(\.note),
                       ["TAL_23: misslungen", "gibt der Schlechten Eigenschaft nach"])
        let passed = rolled(willenskraft, s, [3, 3, 3], fixture).state.step(.confirm, engine: fixture)
        XCTAssertEqual(passed.events.filter { $0.kind == .gained }.map(\.rule), ["chk-mut"])
        // Another talent's check is not the one chk-wille.SE1 asks for.
        let other = rolled(sinnesschaerfe("Suchen"), s, [3, 3, 3], fixture).state.step(.confirm, engine: fixture)
        XCTAssertEqual(other.events.filter { $0.kind == .gained }, [])
    }

    /// `cost { onFailure: 0.5 }` pays half on a failed spell check, through the action layer.
    func testConfirmPaysTheCostHalfOnFailure() throws {
        let pools: [Pool: PoolState] = [.asp: PoolState(current: 20, max: 30)]
        let s = hero(advantage: "chk-begabung", specialisation: "chk-spez", pools: pools)
        let spell = CheckRequest(kind: .spell, id: "SPELL_1", attributes: ["KL", "IN", "CH"])
        let passed = rolled(spell, s, [3, 3, 3], fixture).state.step(.confirm, engine: fixture)
        XCTAssertEqual(passed.events.filter { $0.kind == .paid }.map(\.amount), [8])
        let failed = rolled(spell, s, [19, 19, 18], fixture).state.step(.confirm, engine: fixture)
        let paid = failed.events.filter { $0.kind == .paid }
        XCTAssertEqual(paid.map(\.amount), [4])
        XCTAssertEqual(paid.map(\.origin), [ref("chk-magie.M1")])
    }

    /// SA_74.VP2's shape (MIGRATION probe-magie 20.7/20.8): a failed Selbstbeherrschung's
    /// `onFailure: forbid { check: [spell] }` comes out of its `.confirm`; handed to the spell's
    /// procedure it reads as a failed cast, named by the forbid's clause, and the cost on failure
    /// is paid.
    func testAForbidInOnFailureReadsAsAFailedCast() throws {
        let pools: [Pool: PoolState] = [.asp: PoolState(current: 20, max: 30)]
        let s = hero(["check.kind": "spell"], advantage: "chk-begabung", specialisation: "chk-spez",
                     owned: ["chk-pforte": OwnedRule()], pools: pools)
        let selbstbeherrschung = CheckRequest(kind: .talent, id: "TAL_8", attributes: ["MU", "MU", "KO"])
        var outer = s
        outer.facts["check.kind"] = nil
        let failed = rolled(selbstbeherrschung, s, [19, 20, 19], fixture).state.step(.confirm, engine: fixture)
        XCTAssertEqual(failed.forbidden.map(\.origin), [ref("chk-pforte.VP2")])
        XCTAssertEqual(failed.forbidden.map(\.because), ["Selbstbeherrschung misslungen: der Zauber misslingt"])

        let spell = CheckRequest(kind: .spell, id: "SPELL_1", attributes: ["KL", "IN", "CH"])
        let cast = CheckProcedure.start(spell, in: outer, engine: fixture).state.step(.forbidden(failed.forbidden), engine: fixture)
        guard case .confirmed(_, let r, let events) = cast.state else { return XCTFail("\(cast.state)") }
        XCTAssertEqual(r.success, false)
        XCTAssertEqual(r.from, ref("chk-pforte.VP2"))
        XCTAssertEqual(r.faces, [])
        XCTAssertEqual(events.filter { $0.kind == .paid }.map(\.amount), [4])

        let passed = rolled(selbstbeherrschung, s, [3, 3, 3], fixture).state.step(.confirm, engine: fixture)
        XCTAssertEqual(passed.forbidden, [])
    }

    // MARK: - The procedure as a value

    /// `(state, input) → (state, breakdowns, offers, events)`: the same state and input give the
    /// same step, and the state holds everything (a copy steps on as the original does).
    func testTheProcedureIsAPureFunctionOfItsState() throws {
        let engine = try real()
        let a = CheckProcedure.start(sinnesschaerfe("Wahrnehmen"), in: hero(), engine: engine)
        let b = CheckProcedure.start(sinnesschaerfe("Wahrnehmen"), in: hero(), engine: engine)
        XCTAssertEqual(a, b)
        let copy = a.state
        XCTAssertEqual(a.state.step(.dice([5, 19, 12]), engine: engine), copy.step(.dice([5, 19, 12]), engine: engine))
        let rolledState = a.state.step(.dice([5, 19, 12]), engine: engine).state
        XCTAssertEqual(rolledState.step(.reroll(die: 1, face: 11), engine: engine),
                       CheckProcedure.step(rolledState, .reroll(die: 1, face: 11), engine: engine))
        XCTAssertEqual(a.state, copy, "stepping does not change the state it steps from")
    }

    /// Wrong input never traps: it gives a text and leaves the state as it was.
    func testWrongInputGivesATextAndChangesNothing() throws {
        let engine = try real()
        let start = CheckProcedure.start(sinnesschaerfe("Wahrnehmen"), in: hero(), engine: engine)
        for input: ProcedureInput in [.reroll(die: 0, face: 3), .confirm, .dice([1, 2]), .dice([0, 5, 5]), .dice([21, 5, 5])] {
            let step = start.state.step(input, engine: engine)
            XCTAssertEqual(step.state, start.state, "\(input)")
            XCTAssertFalse(step.texts.isEmpty, "\(input)")
        }
        let rolledState = start.state.step(.dice([5, 19, 12]), engine: engine).state
        for input: ProcedureInput in [.reroll(die: 3, face: 3), .reroll(die: 0, face: 0), .dice([1, 1, 1]),
                                      .reroll(die: 0, face: 3, using: ref("ADV_4.B5"))] {
            let step = rolledState.step(input, engine: engine)
            XCTAssertEqual(step.state, rolledState, "\(input)")
            XCTAssertFalse(step.texts.isEmpty, "\(input)")
        }
        // An attribute nobody stated: no value, a question, and no dice.
        var s = hero()
        s.facts["attr.KL"] = nil
        let unknown = CheckProcedure.start(sinnesschaerfe("Wahrnehmen"), in: s, engine: engine)
        XCTAssertNil(unknown.state.stages.attributes[0].result)
        XCTAssertTrue(unknown.questions.contains { $0.fact == "attr.KL" })
        let dice = unknown.state.step(.dice([5, 5, 5]), engine: engine)
        XCTAssertEqual(dice.state, unknown.state)
    }

    /// `Action.check`: the action layer runs the procedure; with the situation's rolls it goes on
    /// to the dice and the confirm, and returns the events.
    func testTheCheckActionRunsTheProcedure() throws {
        let engine = try real()
        let layer = ActionLayer(engine: engine)
        let started = layer.perform(.check(sinnesschaerfe("Wahrnehmen")), in: hero())
        XCTAssertEqual(started.events, [])
        XCTAssertEqual(started.breakdowns.map(\.query.name).first, "check.modifier")
        var s = hero()
        s.rolls = [15, 16, 10]
        let done = layer.perform(.check(sinnesschaerfe("Wahrnehmen")), in: s)
        XCTAssertEqual(done.events.filter { $0.kind == .logged }.map(\.note), ["TAL_10: gelungen, QS 1"])
        XCTAssertEqual(done.breakdowns.map(\.query.name).suffix(2), ["check.fp", "check.qs"])
    }
}
