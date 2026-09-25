import XCTest
@testable import RulesEngine

/// The harness's matcher (spec §10.2 and the Task 24 bridge rules) against hand-built breakdowns.
/// One test per matching rule; the rule is named in each test's doc line.
final class MatcherTests: XCTestCase {
    private func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }

    /// A compiled situation from the `situations.json` shape; `id`, `file` and the hero are filled in.
    private func situation(_ fields: String) throws -> CompiledSituation {
        var object: [String: Any] = ["id": "T.1", "file": "test.yaml", "owned": [:], "facts": [], "base": [:], "rolls": [],
                                     "sequence": [], "expect": [], "expectSituation": [:], "pending": []]
        let given = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(fields.utf8)) as? [String: Any])
        object.merge(given) { _, new in new }
        return try JSONDecoder().decode(CompiledSituation.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func line(_ value: Int, _ origin: String?, kind: LineKind = .add, via: [String] = [], rulings: [String] = [],
                      owner: Owner? = nil, was: Int? = nil, now: Int? = nil, parts: [Line] = []) -> Line {
        Line(value: value, kind: kind, origin: origin.map(ref), via: via.map(ref), rulings: rulings, owner: owner,
             was: was, now: now, parts: parts)
    }

    private func sheetBase(_ value: Int) -> Line {
        Line(value: value, kind: .base, owner: .sheet, note: "Grundwert laut Bogen")
    }

    private func kinds(_ m: [Mismatch]) -> [Mismatch.Kind] { m.map(\.kind) }

    private func compare(_ s: CompiledSituation, breakdowns: [Breakdown], offers: [OfferedChoice],
                         offering: [String: [ClauseRef]] = [:]) -> [Mismatch] {
        Matcher.compare(s, breakdowns: breakdowns, offers: offers, offering: offering).mismatches
    }

    /// The pipeline fixture book (`Fixtures/pipeline-rules.json`): pl-adds.A4 (an add on the open
    /// ruling pl-adds.open-q) reaches `pa`; pl-moves.M1 is a `*` offer, pl-talk.T1 a `*` tell,
    /// pl-talk.T2 a `*` ask.
    private static let book: RuleBook = {
        let url = Bundle.module.url(forResource: "pipeline-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    /// The pipeline book with pl-moves.M1 (a `*` offer), pl-talk.T1 (a `*` tell) and pl-talk.T2
    /// (a `*` ask) resting on the ruling `t.open`.
    private static let tagged: RuleBook = {
        let url = Bundle.module.url(forResource: "pipeline-rules", withExtension: "json", subdirectory: "Fixtures")!
        var top = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let tag: Set<String> = ["pl-moves.M1", "pl-talk.T1", "pl-talk.T2"]
        top["rules"] = (top["rules"] as! [[String: Any]]).map { rule in
            var rule = rule
            rule["clauses"] = (rule["clauses"] as! [[String: Any]]).map { clause in
                var clause = clause
                guard tag.contains("\(rule["id"]!).\(clause["id"] ?? "")") else { return clause }
                clause["effects"] = (clause["effects"] as? [[String: Any]] ?? []).map { e in
                    var e = e; e["ruling"] = ["t.open"]; return e
                }
                return clause
            }
            return rule
        }
        return try! RuleBook.decode(JSONSerialization.data(withJSONObject: top))
    }()

    // MARK: - Lines (§10.2)

    /// Actual lines the situation does not mention are not checked.
    func testExtraActualLinesAreIgnored() throws {
        let s = try situation(#"{"expect": [{"query": "at", "lines": [{"from": "a.A1", "value": -1}]}]}"#)
        let b = Breakdown(query: Query("at"), base: sheetBase(14), lines: [line(-1, "a.A1"), line(2, "b.B1")])
        XCTAssertEqual(compare(s, breakdowns: [b], offers: []), [])
    }

    /// An expected line with no actual line from its clause is reported as missing.
    func testAMissingLineIsReported() throws {
        let s = try situation(#"{"expect": [{"query": "at", "lines": [{"from": "a.A1", "value": -1}]}]}"#)
        let b = Breakdown(query: Query("at"), base: sheetBase(14), lines: [line(2, "b.B1")])
        let m = compare(s, breakdowns: [b], offers: [])
        XCTAssertEqual(kinds(m), [.missingLine])
        XCTAssertEqual(m.first?.query, "at")
        XCTAssertTrue(m.first?.detail.contains("a.A1") ?? false, m.first?.detail ?? "")
    }

    /// A line from the right clause with the wrong value is reported by its value.
    func testAWrongValueIsReported() throws {
        let s = try situation(#"{"expect": [{"query": "at", "lines": [{"from": "a.A1", "value": -1}]}]}"#)
        let b = Breakdown(query: Query("at"), lines: [line(-2, "a.A1")])
        XCTAssertEqual(kinds(compare(s, breakdowns: [b], offers: [])), [.wrongValue])
    }

    /// `via` compares when given: each expected clause must be in the line's `via` (what the
    /// situation does not mention is not checked, so the line may carry more).
    func testAWrongViaIsReportedAndExtraViaIsNot() throws {
        let s = try situation(#"{"expect": [{"query": "at", "lines": [{"from": "a.A1", "value": -1, "via": ["c.C1"]}]}]}"#)
        let wrong = Breakdown(query: Query("at"), lines: [line(-1, "a.A1", via: ["d.D1"])])
        XCTAssertEqual(kinds(compare(s, breakdowns: [wrong], offers: [])), [.wrongVia])
        let more = Breakdown(query: Query("at"), lines: [line(-1, "a.A1", via: ["d.D1", "c.C1"])])
        XCTAssertEqual(compare(s, breakdowns: [more], offers: []), [])
    }

    /// Order does not matter, and each actual line matches one expected line only.
    func testLinesMatchInAnyOrderEachActualLineOnce() throws {
        let s = try situation(#"{"expect": [{"query": "at", "lines": [{"from": "a.A1", "value": 2}, {"from": "a.A1", "value": 14}, {"from": "a.A1", "value": 2}]}]}"#)
        let one = Breakdown(query: Query("at"), lines: [line(14, "a.A1"), line(2, "a.A1")])
        let m = compare(s, breakdowns: [one], offers: [])
        XCTAssertEqual(kinds(m), [.missingLine])
        XCTAssertTrue(m.first?.detail.contains("match other expected lines") ?? false, m.first?.detail ?? "")
        let two = Breakdown(query: Query("at"), lines: [line(2, "a.A1"), line(14, "a.A1"), line(2, "a.A1")])
        XCTAssertEqual(compare(s, breakdowns: [two], offers: []), [])
    }

    /// `ruling`, `source` (the line's owner), `was` and `kind` compare when given.
    func testRulingSourceWasAndKindCompareWhenGiven() throws {
        let s = try situation(#"{"expect": [{"query": "check.modifier", "lines": [{"from": "a.A1", "value": -1, "ruling": ["a.r"], "source": "gm", "was": -2, "kind": "replaced"}]}]}"#)
        let good = line(-1, "a.A1", kind: .replaced, rulings: ["a.r", "shared.x"], owner: .gm, was: -2, now: -1)
        XCTAssertEqual(compare(s, breakdowns: [Breakdown(query: Query("check.modifier"), lines: [good])], offers: []), [])
        var noRuling = good; noRuling.rulings = []
        XCTAssertEqual(kinds(compare(s, breakdowns: [Breakdown(query: Query("check.modifier"), lines: [noRuling])], offers: [])), [.wrongRuling])
        var player = good; player.owner = .player
        XCTAssertEqual(kinds(compare(s, breakdowns: [Breakdown(query: Query("check.modifier"), lines: [player])], offers: [])), [.wrongSource])
        var was = good; was.was = -3
        XCTAssertEqual(kinds(compare(s, breakdowns: [Breakdown(query: Query("check.modifier"), lines: [was])], offers: [])), [.wrongWas])
        var kind = good; kind.kind = .add
        XCTAssertEqual(kinds(compare(s, breakdowns: [Breakdown(query: Query("check.modifier"), lines: [kind])], offers: [])), [.wrongKind])
    }

    /// Bridge 1 (R21): a line with no `from` matches any shown line carrying its `ruling`, and its
    /// `value` when given.
    func testALineWithoutFromMatchesAnyLineCarryingItsRuling() throws {
        let s = try situation(#"{"expect": [{"query": "ini", "lines": [{"ruling": ["r.rider-ini"], "value": 0}]}]}"#)
        let b = Breakdown(query: Query("ini"), base: sheetBase(12), lines: [line(0, "r.R1", rulings: ["r.rider-ini"])])
        XCTAssertEqual(compare(s, breakdowns: [b], offers: []), [])
        let other = Breakdown(query: Query("ini"), base: sheetBase(12), lines: [line(0, "r.R1", rulings: ["r.other"])])
        XCTAssertEqual(kinds(compare(s, breakdowns: [other], offers: [])), [.missingLine])
        let valueOnly = try situation(#"{"expect": [{"query": "ini", "lines": [{"ruling": ["r.rider-ini"]}]}]}"#)
        let two = Breakdown(query: Query("ini"), lines: [line(-3, "r.R2", rulings: ["r.rider-ini"])])
        XCTAssertEqual(compare(valueOnly, breakdowns: [two], offers: []), [])
    }

    /// Bridge 3: for `set`, `levelAs`, a scale step and `replaced`, the expected `value` is the
    /// value after the step (`Line.now`); for every other kind it is the step (`Line.value`).
    func testSetLevelAsScaleAndReplacedCompareTheValueAfterTheStep() throws {
        let s = try situation(#"{"expect": [{"query": "gs", "lines": [{"from": "a.S1", "value": 0}, {"from": "a.L1", "value": 1}, {"from": "a.Z1", "value": 16}, {"from": "a.R1", "value": -4}, {"from": "a.M1", "value": 3}]}]}"#)
        let b = Breakdown(query: Query("gs"), base: sheetBase(8), lines: [
            line(-8, "a.S1", kind: .set, was: 8, now: 0),
            line(0, "a.L1", kind: .levelAs, was: 2, now: 1),
            line(8, "a.Z1", kind: .add, was: 8, now: 16),         // a scale step: an add with was/now
            line(-4, "a.R1", kind: .replaced, was: -6, now: -4),
            line(3, "a.M1", kind: .multiplied, was: 3, now: 6),   // any other kind: the step
        ])
        XCTAssertEqual(compare(s, breakdowns: [b], offers: []), [])
        let step = try situation(#"{"expect": [{"query": "gs", "lines": [{"from": "a.S1", "value": -8}]}]}"#)
        XCTAssertEqual(kinds(compare(step, breakdowns: [b], offers: [])), [.wrongValue])
    }

    /// Bridge 4: shown lines include the parts of `base` (KW1 14, KW1 2).
    func testTheBasesPartsAreShownLines() throws {
        let s = try situation(#"{"expect": [{"query": "at", "lines": [{"from": "k.KW1", "value": 14}, {"from": "k.KW1", "value": 2}]}]}"#)
        let base = line(16, "k.KW1", kind: .base, parts: [line(14, "k.KW1", kind: .base), line(2, "k.KW1", kind: .base)])
        XCTAssertEqual(compare(s, breakdowns: [Breakdown(query: Query("at"), base: base)], offers: []), [])
    }

    /// Bridge 5: an expected scaled line (value −5, was −10, via the multiplier) matches the
    /// origin line plus the `.multiplied` delta line that scaled it, with the multiplier in `via`.
    func testAScaledLineMatchesItsOriginLinePlusItsMultipliedDelta() throws {
        let s = try situation(#"{"expect": [{"query": "at", "total": -5, "lines": [{"from": "t.TZ5", "value": -5, "was": -10, "via": ["s.GA1"], "ruling": ["s.halving"]}]}]}"#)
        let b = Breakdown(query: Query("at"), base: sheetBase(14), lines: [
            line(-10, "t.TZ5"),
            line(5, "s.GA1", kind: .multiplied, via: ["t.TZ5"], rulings: ["s.halving"], was: -10, now: -5),
        ])
        XCTAssertEqual(compare(s, breakdowns: [b], offers: []), [])
        let noMultiplier = try situation(#"{"expect": [{"query": "at", "lines": [{"from": "t.TZ5", "value": -5, "via": ["x.X1"]}]}]}"#)
        XCTAssertEqual(kinds(compare(noMultiplier, breakdowns: [b], offers: [])), [.wrongVia])
        // The multiplier must be in the expected `via`: without it, the scaled value is no match.
        let noVia = try situation(#"{"expect": [{"query": "at", "lines": [{"from": "t.TZ5", "value": -5}]}]}"#)
        XCTAssertEqual(kinds(compare(noVia, breakdowns: [b], offers: [])), [.wrongValue])
    }

    // MARK: - total and result

    /// `result` compares exactly when given.
    func testResultComparesExactly() throws {
        let s = try situation(#"{"expect": [{"query": "at", "result": 13}]}"#)
        let b = Breakdown(query: Query("at"), base: sheetBase(14), lines: [line(-1, "a.A1")])
        XCTAssertEqual(compare(s, breakdowns: [b], offers: []), [])
        let none = Breakdown(query: Query("at"), lines: [line(-1, "a.A1")])
        XCTAssertEqual(kinds(compare(s, breakdowns: [none], offers: [])), [.result])
    }

    /// Bridge 2: `total` is the result when the base came from a derive (leMax 37); otherwise
    /// (a sheet base, or none) it is the sum of the lines after the base (at −5).
    func testTotalIncludesADerivedBaseButNotASheetBase() throws {
        let derived = try situation(#"{"expect": [{"query": "leMax", "total": 37}]}"#)
        let le = Breakdown(query: Query("leMax"), base: line(35, "l.LE3", kind: .base,
                                                               parts: [line(5, "l.LE3", kind: .base), line(30, "l.LE3", kind: .base)]),
                           lines: [line(2, "h.HL1")])
        XCTAssertEqual(compare(derived, breakdowns: [le], offers: []), [])
        let sheet = try situation(#"{"expect": [{"query": "at", "total": -5}]}"#)
        let at = Breakdown(query: Query("at"), base: sheetBase(16), lines: [line(-3, "c.B3"), line(-2, "c.SZ5")])
        XCTAssertEqual(compare(sheet, breakdowns: [at], offers: []), [])
        let noBase = Breakdown(query: Query("at"), lines: [line(-3, "c.B3"), line(-2, "c.SZ5")])
        XCTAssertEqual(compare(sheet, breakdowns: [noBase], offers: []), [])
        let wrong = Breakdown(query: Query("at"), base: sheetBase(16), lines: [line(-3, "c.B3")])
        XCTAssertEqual(kinds(compare(sheet, breakdowns: [wrong], offers: [])), [.total])
    }

    /// The query key `base`: `from` names the base's clause (or one of its parts'), `value` its value.
    func testTheBaseKeyComparesTheBasesClauseAndValue() throws {
        let s = try situation(#"{"expect": [{"query": "item.ladezeit", "base": {"from": "l.LZ1", "value": 15}}]}"#)
        let good = Breakdown(query: Query("item.ladezeit"), base: line(15, "l.LZ1", kind: .base))
        XCTAssertEqual(compare(s, breakdowns: [good], offers: []), [])
        let sheet = Breakdown(query: Query("item.ladezeit"), base: sheetBase(15))
        XCTAssertEqual(kinds(compare(s, breakdowns: [sheet], offers: [])), [.base])
    }

    // MARK: - notApplied

    /// `notApplied` matches by rule (and clause, when given) and reason code.
    func testNotAppliedMatchesByRuleClauseAndReasonCode() throws {
        let s = try situation(#"{"expect": [{"query": "at", "notApplied": [{"rule": "c", "clause": "B3", "reason": "suppressed", "value": -3, "ruling": ["c.r"]}]}]}"#)
        let entry = NotApplied(origin: ref("c.B3"), reason: .suppressed, rulings: ["c.r"], value: -3)
        XCTAssertEqual(compare(s, breakdowns: [Breakdown(query: Query("at"), notApplied: [entry])], offers: []), [])
        var code = entry; code.reason = .conditionFalse
        XCTAssertEqual(kinds(compare(s, breakdowns: [Breakdown(query: Query("at"), notApplied: [code])], offers: [])), [.wrongReason])
        var clause = entry; clause.origin = ref("c.B4")
        XCTAssertEqual(kinds(compare(s, breakdowns: [Breakdown(query: Query("at"), notApplied: [clause])], offers: [])), [.missingNotApplied])
        var value = entry; value.value = -2
        XCTAssertEqual(kinds(compare(s, breakdowns: [Breakdown(query: Query("at"), notApplied: [value])], offers: [])), [.wrongNotApplied])
        let ruleOnly = try situation(#"{"expect": [{"query": "at", "notApplied": [{"rule": "c", "reason": "suppressed"}]}]}"#)
        XCTAssertEqual(compare(ruleOnly, breakdowns: [Breakdown(query: Query("at"), notApplied: [clause])], offers: []), [])
    }

    /// Bridge 6: `because` is the suppressor's text, or a `RULE.CLAUSE` ref matched against the
    /// entry's `via` (the suppressor or forbid). A `reason` that is such a ref is read the same way.
    func testBecauseIsTheTextOrAClauseRefInVia() throws {
        let text = try situation(#"{"expectSituation": {"notApplied": [{"rule": "c", "clause": "B3", "because": "nicht im Galopp"}]}, "expect": [{"query": "at"}]}"#)
        let entry = NotApplied(origin: ref("c.B3"), reason: .suppressed, because: "nicht im Galopp", via: [ref("s.SP-zustand")])
        XCTAssertEqual(compare(text, breakdowns: [Breakdown(query: Query("at"), notApplied: [entry])], offers: []), [])
        let clause = try situation(#"{"expect": [{"query": "at", "notApplied": [{"rule": "c", "clause": "B3", "because": "s.SP-zustand"}]}]}"#)
        XCTAssertEqual(compare(clause, breakdowns: [Breakdown(query: Query("at"), notApplied: [entry])], offers: []), [])
        let reasonRef = try situation(#"{"expect": [{"query": "at", "notApplied": [{"rule": "c", "clause": "B3", "reason": "s.SP-zustand"}]}]}"#)
        XCTAssertEqual(compare(reasonRef, breakdowns: [Breakdown(query: Query("at"), notApplied: [entry])], offers: []), [])
        let other = try situation(#"{"expect": [{"query": "at", "notApplied": [{"rule": "c", "clause": "B3", "because": "x.X1"}]}]}"#)
        XCTAssertEqual(kinds(compare(other, breakdowns: [Breakdown(query: Query("at"), notApplied: [entry])], offers: [])), [.wrongBecause])
        // A ref is the suppressor, winner or forbid only: never a later `via` entry, never a
        // `conditionFalse` entry's `via`.
        let second = NotApplied(origin: ref("c.B3"), reason: .suppressed, via: [ref("e.E1"), ref("s.SP-zustand")])
        XCTAssertEqual(kinds(compare(clause, breakdowns: [Breakdown(query: Query("at"), notApplied: [second])], offers: [])), [.wrongBecause])
        let unmet = NotApplied(origin: ref("c.B3"), reason: .conditionFalse, via: [ref("s.SP-zustand")])
        XCTAssertEqual(kinds(compare(clause, breakdowns: [Breakdown(query: Query("at"), notApplied: [unmet])], offers: [])), [.wrongBecause])
        let forbid = NotApplied(origin: ref("s.SP-zustand"), reason: .forbidden)
        XCTAssertTrue(Matcher.because("s.SP-zustand", forbid))
    }

    /// R42: a `reason` that is neither a reason code nor a clause ref is prose; the entry is
    /// matched by rule and clause only, and the prose is kept as a note.
    func testAProseReasonMatchesByRuleAndClauseWithANote() throws {
        let s = try situation(#"{"expect": [{"query": "at", "notApplied": [{"rule": "c", "clause": "B3", "reason": "only one weapon attacks"}]}]}"#)
        let entry = NotApplied(origin: ref("c.B3"), reason: .conditionFalse)
        let c = Matcher.compare(s, breakdowns: [Breakdown(query: Query("at"), notApplied: [entry])], offers: [])
        XCTAssertEqual(c.mismatches, [])
        XCTAssertEqual(c.notes.count, 1)
        XCTAssertTrue(c.notes[0].contains("only one weapon attacks"), c.notes[0])
        XCTAssertEqual(kinds(compare(s, breakdowns: [Breakdown(query: Query("at"))], offers: [])), [.missingNotApplied])
    }

    // MARK: - legal

    /// Bridge 7: `allowed` compares; `because` matches any firing forbid or require (RK13 while
    /// GK4 also fires); a bare bool is `allowed`; `span` and `via` are unsupported shapes.
    func testLegalComparesAllowedAndAnyFiringBecause() throws {
        let reasons = [NotApplied(origin: ref("g.GK4"), reason: .forbidden), NotApplied(origin: ref("r.RK13"), reason: .forbidden)]
        let b = Breakdown(query: Query("opponent.pa"), legal: Legality(allowed: false, reasons: reasons))
        let s = try situation(#"{"expect": [{"query": "opponent.pa", "legal": {"allowed": false, "because": "r.RK13"}}]}"#)
        XCTAssertEqual(compare(s, breakdowns: [b], offers: []), [])
        let bare = try situation(#"{"expect": [{"query": "opponent.pa", "legal": false}]}"#)
        XCTAssertEqual(compare(bare, breakdowns: [b], offers: []), [])
        let allowed = try situation(#"{"expect": [{"query": "opponent.pa", "legal": true}]}"#)
        XCTAssertEqual(kinds(compare(allowed, breakdowns: [b], offers: [])), [.legal])
        let other = try situation(#"{"expect": [{"query": "opponent.pa", "legal": {"allowed": false, "because": "x.X1"}}]}"#)
        XCTAssertEqual(kinds(compare(other, breakdowns: [b], offers: [])), [.legal])
        let span = try situation(#"{"expect": [{"query": "opponent.pa", "legal": {"allowed": false, "because": "r.RK13", "span": "round", "via": ["s.SK7"]}}]}"#)
        XCTAssertEqual(kinds(compare(span, breakdowns: [b], offers: [])), [.unsupportedShape, .unsupportedShape])
        let malformed = try situation(#"{"expect": [{"query": "opponent.pa", "legal": {"allowed": "no"}}, {"query": "opponent.pa", "legal": {"because": 3}}]}"#)
        XCTAssertEqual(compare(malformed, breakdowns: [b, b], offers: []).map(\.shape), ["legal.malformed", "legal.malformed"])
    }

    // MARK: - offers

    /// Bridge 8: `offered` / `notOffered` match by choice and origin clause; with a query, against
    /// the breakdowns' offers (a phase-4 suppress acts there), without one against `Engine.offers(in:)`.
    func testOffersMatchByChoiceAndOriginFromTheBreakdownsWhenThereIsAQuery() throws {
        let sch3 = OfferedChoice(choice: "shieldBonus", origin: ref("schilde.SCH3"))
        let s = try situation(#"{"expect": [{"query": "pa(with: shield)"}], "expectSituation": {"notOffered": [{"choice": "shieldBonus", "because": "SA_59.SS2"}]}}"#)
        // The breakdown's offers lack SCH3 (suppressed there by SS2); `offers(in:)` still lists it.
        let suppressed = NotApplied(origin: ref("schilde.SCH3"), reason: .suppressed, via: [ref("SA_59.SS2")])
        let offering = ["shieldBonus": [ref("schilde.SCH3")]]
        XCTAssertEqual(compare(s, breakdowns: [Breakdown(query: Query("pa(with: shield)"), notApplied: [suppressed])], offers: [sch3],
                               offering: offering), [])
        let noQuery = try situation(#"{"expectSituation": {"notOffered": [{"choice": "shieldBonus"}], "offered": [{"choice": "finte", "from": "m.F1"}]}}"#)
        let finte = OfferedChoice(choice: "finte", origin: ref("m.F1"))
        XCTAssertEqual(kinds(compare(noQuery, breakdowns: [], offers: [sch3, finte])), [.unexpectedOffer])
        let wrongFrom = try situation(#"{"expectSituation": {"offered": [{"choice": "finte", "from": "m.F2"}]}}"#)
        XCTAssertEqual(kinds(compare(wrongFrom, breakdowns: [], offers: [finte])), [.missingOffer])
    }

    /// A `notOffered` with `because` / `ruling` needs a reason saying so: an illegal offer's
    /// refusal (by origin or text, rulings of the offer or the refusal), or a suppress of the
    /// offering clause. An offer that is simply absent cannot show its reason: an unsupported
    /// shape, never a pass.
    func testANotOfferedBecauseNeedsAReasonThatSaysSo() throws {
        let refused = OfferedChoice(choice: "vorstoss", origin: ref("s.V1"), rulings: ["shared.sf-technique-lists"],
                                    reasons: [NotApplied(origin: ref("s.V3"), reason: .requirementNotMet)])
        let right = try situation(#"{"expectSituation": {"notOffered": [{"choice": "vorstoss", "because": "s.V3", "ruling": "sf-technique-lists"}]}}"#)
        XCTAssertEqual(compare(right, breakdowns: [], offers: [refused]), [])
        let wrong = try situation(#"{"expectSituation": {"notOffered": [{"choice": "vorstoss", "because": "s.V6"}]}}"#)
        XCTAssertEqual(kinds(compare(wrong, breakdowns: [], offers: [refused])), [.wrongOffer])
        let ruling = try situation(#"{"expectSituation": {"notOffered": [{"choice": "vorstoss", "because": "s.V3", "ruling": "x.other"}]}}"#)
        XCTAssertEqual(kinds(compare(ruling, breakdowns: [], offers: [refused])), [.wrongOffer])
        XCTAssertEqual(compare(wrong, breakdowns: [], offers: []).map(\.shape), ["notOffered reason undecidable"])
        let plain = try situation(#"{"expectSituation": {"notOffered": [{"choice": "vorstoss"}]}}"#)
        XCTAssertEqual(compare(plain, breakdowns: [], offers: []), [])
        let s = try situation(#"{"expect": [{"query": "at"}], "expectSituation": {"notOffered": [{"choice": "shieldBonus", "because": "x.Y1"}]}}"#)
        let suppressed = NotApplied(origin: ref("schilde.SCH3"), reason: .suppressed, via: [ref("SA_59.SS2")])
        XCTAssertEqual(kinds(compare(s, breakdowns: [Breakdown(query: Query("at"), notApplied: [suppressed])], offers: [],
                                     offering: ["shieldBonus": [ref("schilde.SCH3")]])), [.wrongOffer])
    }

    /// An offer that is not legal is not offered; a `choice.option` id is that option of the choice,
    /// offered when the offer lists it and does not refuse it.
    func testAnIllegalOfferAndARefusedOptionAreNotOffered() throws {
        let illegal = OfferedChoice(choice: "vorstoss", origin: ref("s.V1"),
                                    reasons: [NotApplied(origin: ref("s.V3"), reason: .forbidden)])
        let mods = OfferedChoice(choice: "spellModification", origin: ref("z.ZM1"),
                                 options: [.string("erzwingen"), .string("kostenSenken")],
                                 refused: [RefusedOption(option: .string("kostenSenken"), reasons: [NotApplied(origin: ref("z.ZM2"), reason: .forbidden)])])
        let s = try situation(#"{"expectSituation": {"notOffered": [{"choice": "vorstoss"}, {"choice": "spellModification.kostenSenken"}], "offered": [{"choice": "spellModification.erzwingen", "from": "z.ZM1"}]}}"#)
        XCTAssertEqual(compare(s, breakdowns: [], offers: [illegal, mods]), [])
        let wrong = try situation(#"{"expectSituation": {"offered": [{"choice": "vorstoss"}, {"choice": "spellModification.kostenSenken"}]}}"#)
        XCTAssertEqual(kinds(compare(wrong, breakdowns: [], offers: [illegal, mods])), [.missingOffer, .missingOffer])
    }

    /// An offer entry without a `choice` (a defence, an attack, a reroll, a check) is the action
    /// layer's (Task 27): an unsupported shape.
    func testAnOfferEntryWithoutAChoiceIsAnUnsupportedShape() throws {
        let s = try situation(#"{"expectSituation": {"offered": [{"defence": "aw"}], "notOffered": [{"reroll": "ADV_4.B1"}]}}"#)
        XCTAssertEqual(kinds(compare(s, breakdowns: [], offers: [])), [.unsupportedShape, .unsupportedShape])
    }

    // MARK: - questions, texts

    /// `questions` match by fact name in any of the situation's breakdowns; `[]` asserts none is asked.
    func testQuestionsMatchByFactName() throws {
        let s = try situation(#"{"expect": [{"query": "at"}, {"query": "gs"}], "expectSituation": {"questions": [{"fact": "choice.liegend", "from": "x.H3", "text": "Liegt der Held?"}]}}"#)
        let asked = Breakdown(query: Query("gs"), questions: [Question(fact: "choice.liegend", owner: .player)])
        XCTAssertEqual(compare(s, breakdowns: [Breakdown(query: Query("at")), asked], offers: []), [])
        XCTAssertEqual(kinds(compare(s, breakdowns: [Breakdown(query: Query("at")), Breakdown(query: Query("gs"))], offers: [])),
                       [.missingQuestion])
        let none = try situation(#"{"expect": [{"query": "gs"}], "expectSituation": {"questions": []}}"#)
        XCTAssertEqual(kinds(compare(none, breakdowns: [asked], offers: [])), [.unexpectedQuestion])
    }

    /// `texts` match a text of any of the situation's breakdowns by origin (`from`), audience and
    /// exact text, and open ruling (`ruling`); `[]` asserts no `tell`; a structured text or a key
    /// that is no audience is an unsupported shape.
    func testTextsMatchByOriginAudienceTextAndRuling() throws {
        let tell = TextLine(kind: .tell, audience: .opponent, text: "keine Verteidigung", origin: ref("p.PS2"))
        let open = TextLine(kind: .openRuling, text: "…", origin: ref("z.ZM11"), ruling: "z.cost-off-table", question: "?")
        let b = Breakdown(query: Query("at"), texts: [tell, open])
        let s = try situation(#"{"expect": [{"query": "at"}], "expectSituation": {"texts": [{"from": "p.PS2", "opponent": "keine Verteidigung"}, {"ruling": "z.cost-off-table"}]}}"#)
        XCTAssertEqual(compare(s, breakdowns: [b], offers: []), [])
        let player = try situation(#"{"expect": [{"query": "at"}], "expectSituation": {"texts": [{"from": "p.PS2", "player": "keine Verteidigung"}]}}"#)
        XCTAssertEqual(kinds(compare(player, breakdowns: [b], offers: [])), [.missingText])
        let empty = try situation(#"{"expect": [{"query": "at"}], "expectSituation": {"texts": []}}"#)
        XCTAssertEqual(kinds(compare(empty, breakdowns: [b], offers: [])), [.unexpectedText])
        XCTAssertEqual(compare(empty, breakdowns: [Breakdown(query: Query("at"), texts: [open])], offers: []), [])
        let structured = try situation(#"{"expect": [{"query": "at"}], "expectSituation": {"texts": [{"from": "m.MS3", "opponent": {"check": "Kraftakt"}}, {"from": "r.RK13", "mount": "runs on"}]}}"#)
        XCTAssertEqual(kinds(compare(structured, breakdowns: [b], offers: [])), [.unsupportedShape, .unsupportedShape])
    }

    /// Situation-level `notApplied`, `questions` and `texts` are looked up in the situation's
    /// breakdowns; with no query there is none, which is an unsupported shape, not a pass.
    func testSituationLevelEntriesWithoutAQueryAreAnUnsupportedShape() throws {
        let s = try situation(#"{"expectSituation": {"notApplied": [{"rule": "a", "reason": "rulesetOff"}], "texts": [{"from": "a.A1", "player": "x"}], "questions": [{"fact": "f"}]}}"#)
        XCTAssertEqual(kinds(compare(s, breakdowns: [], offers: [])), [.unsupportedShape, .unsupportedShape, .unsupportedShape])
    }

    // MARK: - Shapes the engine does not model

    /// A situation with no expectation the harness checks is reported, never passed; so are a
    /// situation-level `notApplied` entry without a rule and a non-list `offered`.
    func testNothingToCompareAndMalformedEntriesAreReported() throws {
        XCTAssertEqual(compare(try situation(#"{"expect": [{"query": "at"}]}"#), breakdowns: [Breakdown(query: Query("at"))], offers: [])
                        .map(\.shape), ["nothing to compare"])
        let s = try situation(#"{"expect": [{"query": "at"}], "expectSituation": {"notApplied": [{"clause": "B3"}], "offered": {"choice": "x"}}}"#)
        XCTAssertEqual(Set(compare(s, breakdowns: [Breakdown(query: Query("at"))], offers: []).compactMap(\.shape)),
                       ["malformed notApplied", "malformed offered"])
    }

    /// `term` (MIGRATION probe-magie 20.2), `values` (a check's attribute stage), a situation-level
    /// `legal` (loadout, combinations, actions) and any unknown key are reported, never passed.
    func testUnmodelledShapesAreReported() throws {
        let s = try situation(#"{"expect": [{"query": "check.modifier", "lines": [{"from": "z.ZM11", "value": 1, "term": "Erzwingen"}]}, {"query": "check.attribute", "values": [12, 14, 14]}], "expectSituation": {"legal": {"combinations": [{"allowed": false}]}}}"#)
        let b = [Breakdown(query: Query("check.modifier"), lines: [line(1, "z.ZM11")]), Breakdown(query: Query("check.attribute"))]
        XCTAssertEqual(kinds(compare(s, breakdowns: b, offers: [])), [.unsupportedShape, .unsupportedShape, .unsupportedShape])
    }

    // MARK: - Verdicts (R32, conflicts, unsupported)

    private let mismatch = [Mismatch(kind: .missingLine, query: "at", detail: "no line from a.A1")]

    private let listed: Set<ConflictRef> = [ConflictRef(file: "test.yaml", id: "T.1")]

    private func hit(_ ruling: String, _ origin: String?) -> OpenHit { OpenHit(ruling: ruling, origin: origin.map(ref)) }

    /// R41: pending only when an open ruling of the static list that the run hit could explain a
    /// mismatch: the expectation names its clause, rule or ruling; its effect reaches the
    /// mismatched query's target (non-`*`); or a `*` offer / ask / tell for an offer / question /
    /// text mismatch. The verdict names the explaining rulings.
    func testPendingOnlyWhenAHitOpenRulingCouldExplainAMismatch() throws {
        let s = try situation(#"{"pending": ["a.open", "pl-adds.open-q", "t.open"]}"#)
        let named = [Mismatch(kind: .missingLine, query: "at", detail: "", names: ["a.A1", "a"])]
        XCTAssertEqual(Verdict.of(s, mismatches: named, hits: [hit("a.open", "a.A2")], book: nil, conflicts: []), .pending(["a.open"]))
        XCTAssertEqual(Verdict.of(s, mismatches: named, hits: [hit("b.open", "a.A2")], book: nil, conflicts: []), .failed)
        XCTAssertEqual(Verdict.of(s, mismatches: named, hits: [hit("t.open", "x.X1")], book: nil, conflicts: []), .failed)
        // Reach: pl-adds.A4 reaches `pa`, not `at`.
        let pa = [Mismatch(kind: .total, query: "pa(with: shield)", detail: "")]
        let at = [Mismatch(kind: .total, query: "at", detail: "")]
        let a4 = hit("pl-adds.open-q", "pl-adds.A4")
        XCTAssertEqual(Verdict.of(s, mismatches: pa, hits: [a4], book: Self.book, conflicts: []), .pending(["pl-adds.open-q"]))
        XCTAssertEqual(Verdict.of(s, mismatches: at, hits: [a4], book: Self.book, conflicts: []), .failed)
        // Only the clause's effects resting on the ruling count: pl-adds.A4 on another ruling is no hit.
        XCTAssertEqual(Verdict.of(s, mismatches: pa, hits: [hit("t.open", "pl-adds.A4")], book: Self.book, conflicts: []), .failed)
        // `*` player verbs explain only their own kind of mismatch, never a value.
        let offer = [Mismatch(kind: .missingOffer, detail: "")], text = [Mismatch(kind: .missingText, detail: "")]
        let question = [Mismatch(kind: .missingQuestion, detail: "")]
        XCTAssertEqual(Verdict.of(s, mismatches: offer, hits: [hit("t.open", "pl-moves.M1")], book: Self.tagged, conflicts: []), .pending(["t.open"]))
        XCTAssertEqual(Verdict.of(s, mismatches: text, hits: [hit("t.open", "pl-moves.M1")], book: Self.tagged, conflicts: []), .failed)
        XCTAssertEqual(Verdict.of(s, mismatches: text, hits: [hit("t.open", "pl-talk.T1")], book: Self.tagged, conflicts: []), .pending(["t.open"]))
        XCTAssertEqual(Verdict.of(s, mismatches: question, hits: [hit("t.open", "pl-talk.T2")], book: Self.tagged, conflicts: []), .pending(["t.open"]))
        XCTAssertEqual(Verdict.of(s, mismatches: at, hits: [hit("t.open", "pl-talk.T1")], book: Self.tagged, conflicts: []), .failed)
        XCTAssertEqual(Verdict.of(s, mismatches: [], hits: [a4], book: Self.book, conflicts: []), .passed)
        XCTAssertFalse(Verdict.failed.passesTheTest)
        XCTAssertTrue(Verdict.pending(["a.open"]).passesTheTest)
    }

    /// R43: a mismatching situation listed in MIGRATION's conflicts is `conflict` before any
    /// pending check, matched by file and id.
    func testAListedConflictIsItsOwnBucketBeforePending() throws {
        let s = try situation(#"{"pending": ["a.open"]}"#)
        let named = [Mismatch(kind: .missingLine, query: "at", detail: "", names: ["a.A1"])]
        XCTAssertEqual(Verdict.of(s, mismatches: mismatch, hits: [], book: nil, conflicts: listed), .conflict)
        XCTAssertEqual(Verdict.of(s, mismatches: named, hits: [hit("a.open", "a.A1")], book: nil, conflicts: listed), .conflict)
        XCTAssertEqual(Verdict.of(s, mismatches: mismatch, hits: [], book: nil,
                                  conflicts: [ConflictRef(file: "other.yaml", id: "T.1")]), .failed)
        XCTAssertEqual(Verdict.of(s, mismatches: [], hits: [], book: nil, conflicts: listed), .passed)
        XCTAssertTrue(Verdict.conflict.passesTheTest)
    }

    /// R42: a situation whose only mismatches are unsupported shapes is `unsupported`, with the
    /// shape tags; one with a real mismatch besides is judged on it.
    func testOnlyUnsupportedShapesMakeASituationUnsupported() throws {
        let s = try situation("{}")
        let shapes = [Mismatch.shape("legal.span", "x"), Mismatch.shape("term", "y"), Mismatch.shape("term", "z")]
        XCTAssertEqual(Verdict.of(s, mismatches: shapes, hits: [], book: nil, conflicts: []),
                       .unsupported(["shape: legal.span", "shape: term"]))
        XCTAssertEqual(Verdict.of(s, mismatches: shapes + mismatch, hits: [], book: nil, conflicts: []), .failed)
        XCTAssertTrue(Verdict.unsupported([]).passesTheTest)
    }

    /// Finding 1: open rulings are also collected from offers' `openRuling` reasons.
    func testOpenRulingsAreCollectedFromOffersToo() {
        let o = OfferedChoice(choice: "c", origin: ref("r.R1"), reasons: [NotApplied(origin: ref("r.R2"), reason: .openRuling, rulings: ["r.open"])],
                              refused: [RefusedOption(option: .string("x"), reasons: [NotApplied(origin: ref("r.R3"), reason: .openRuling, rulings: ["r.other"])])])
        XCTAssertEqual(Matcher.openRulings(in: [o]), [hit("r.open", "r.R2"), hit("r.other", "r.R3")])
    }

    /// Situations state the current LE/AsP as `base` values; the engine runs with pools filled
    /// from them (max from `leMax` / `aspMax`, else the current value), so `leCurrent` reads the
    /// pool (R39).
    func testThePoolsAreFilledFromTheBaseValues() throws {
        let s = try situation(#"{"base": {"leCurrent": 20, "leMax": 33, "aspCurrent": 5}}"#)
        XCTAssertEqual(s.engineSituation.pools[.le], PoolState(current: 20, max: 33))
        XCTAssertEqual(s.engineSituation.pools[.asp], PoolState(current: 5, max: 5))
        XCTAssertNil(s.engineSituation.pools[.kap])
        let b = Engine(book: Self.book).evaluate(Query("leCurrent"), in: s.engineSituation)
        XCTAssertEqual(b.base?.note, "aktueller Stand")
        XCTAssertEqual(b.result, 20)
    }

    /// Finding 6: every key the vocabulary allows in an expectation is decoded and handled.
    func testEveryExpectationKeyOfTheVocabularyIsHandled() throws {
        let data = try Data(contentsOf: Repo.url("specs/rules/vocabulary.json"))
        let v = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let queryKeys = try XCTUnwrap(v["expectQueryKeys"] as? [String])
        let lineKeys = try XCTUnwrap(v["lineKeys"] as? [String])
        let situationKeys = try XCTUnwrap(v["expectKeys"] as? [String])
        XCTAssertEqual(Set(queryKeys).subtracting(QueryExpectation.CodingKeys.allCases.map(\.rawValue)), [])
        XCTAssertEqual(Set(lineKeys).subtracting(ExpectedLine.CodingKeys.allCases.map(\.rawValue)), [])
        XCTAssertEqual(Set(situationKeys).subtracting(Matcher.situationKeys.union(Matcher.actionKeys)), [])
    }

    /// `sequence`, `rolls`, `events`, `fp`, `qs`, `spent`, `success` need the action layer:
    /// `ActionRunner.canRun` is false for them until Task 26.
    func testActionLayerSituationsAreUnsupported() throws {
        XCTAssertTrue(ActionRunner.canRun(try situation(#"{"expect": [{"query": "at"}]}"#)))
        XCTAssertFalse(ActionRunner.canRun(try situation(#"{"rolls": [3, 4, 5]}"#)))
        XCTAssertFalse(ActionRunner.canRun(try situation(#"{"sequence": [{"rolls": {"check.result": "failure"}}]}"#)))
        for key in ["events", "fp", "qs", "spent", "success", "result"] {
            XCTAssertFalse(ActionRunner.canRun(try situation(#"{"expectSituation": {"\#(key)": []}}"#)), key)
        }
        XCTAssertEqual(ActionRunner.needs(try situation(#"{"rolls": [1], "expectSituation": {"events": []}}"#)), [.rolls, .events])
    }

    // MARK: - The conflicts list and the file filter

    /// The ids after each `<file>.yaml` in MIGRATION's conflicts section, ranges expanded in the
    /// file's order, several files in one bullet.
    func testTheConflictsSectionIsParsedIntoSituationIds() {
        let md = """
        ## Something before
        - situations/a.yaml 9.9: not a conflict.
        ## Expectation conflicts for the owner

        - situations/a.yaml 1.2: expects something.
        - situations/b.yaml 5.6, c.yaml 17.3, 17.22, TZ.4: the `raises` key (x.yaml 3.3 in prose too).
        - situations/a.yaml 1.4–1.6: a range; lebensenergie 15.8's comment is prose.
        ## Reviews reset by hand edits
        - situations/a.yaml 1.3: not a conflict.
        """
        let order = ["a.yaml": ["1.1", "1.2", "1.3", "1.4", "1.4b", "1.5", "1.6", "1.7"]]
        XCTAssertEqual(Conflicts.parse(md, order: order)?.map(\.description),
                       ["a.yaml 1.2", "b.yaml 5.6", "c.yaml 17.3", "c.yaml 17.22", "c.yaml TZ.4", "x.yaml 3.3",
                        "a.yaml 1.4", "a.yaml 1.4b", "a.yaml 1.5", "a.yaml 1.6"])
        XCTAssertNil(Conflicts.parse("## Other\n- situations/a.yaml 1.2", order: order))
    }

    /// `RULES_FILES=kampfwerte,lebensenergie` keeps those files; unset, empty or `all` keeps all.
    func testTheFileFilter() {
        XCTAssertEqual(FileFilter(nil).keeps("kampfwerte.yaml"), true)
        XCTAssertEqual(FileFilter("all").keeps("kampfwerte.yaml"), true)
        XCTAssertEqual(FileFilter("kampfwerte, lebensenergie").keeps("lebensenergie.yaml"), true)
        XCTAssertEqual(FileFilter("kampfwerte,lebensenergie").keeps("schmerz.yaml"), false)
        XCTAssertEqual(FileFilter("none").keeps("schmerz.yaml"), false)
        XCTAssertTrue(FileFilter("none").isNone)
        let files = ["kampfwerte.yaml", "lebensenergie.yaml"]
        XCTAssertEqual(FileFilter("kampfwerte,lebensenrgie").unknown(among: files), ["lebensenrgie"])
        XCTAssertEqual(FileFilter("all").unknown(among: files), [])
        XCTAssertEqual(FileFilter("none").unknown(among: files), [])
        XCTAssertEqual(HarnessReport().summary, "harness: 0 passed, 0 failed, 0 pending, 0 conflict, 0 unsupported")
    }
}
