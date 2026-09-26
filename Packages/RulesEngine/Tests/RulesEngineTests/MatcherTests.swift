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
    /// (a `*` ask) resting on the ruling `t.open`, and pl-adds.A4 (the open-q add on `pa`) with
    /// `when: gmFact.fromBehind`.
    private static let tagged: RuleBook = {
        let url = Bundle.module.url(forResource: "pipeline-rules", withExtension: "json", subdirectory: "Fixtures")!
        var top = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let tag: Set<String> = ["pl-moves.M1", "pl-talk.T1", "pl-talk.T2"]
        top["rules"] = (top["rules"] as! [[String: Any]]).map { rule in
            var rule = rule
            rule["clauses"] = (rule["clauses"] as! [[String: Any]]).map { clause in
                var clause = clause
                if "\(rule["id"]!).\(clause["id"] ?? "")" == "pl-adds.A4" {
                    clause["effects"] = (clause["effects"] as! [[String: Any]]).map { e in
                        var e = e; e["when"] = ["fact": "gmFact.fromBehind", "is": true]; return e
                    }
                }
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

    /// Task 35: a line's `term` is one of the fields it is matched by: two lines of one clause and
    /// one value (zaubermodifikationen.ZM11's +1 for Erzwingen and for Zauberdauer erhöhen, 20.2)
    /// pair by their terms, whatever their order; a term that no line carries is `wrongTerm`.
    func testLinesOfOneClauseAndValuePairByTheirTerms() throws {
        let s = try situation(#"{"expect": [{"query": "check.modifier", "lines": [{"from": "z.ZM11", "value": 1, "term": "Erzwingen"}, {"from": "z.ZM11", "value": 1, "term": "Zauberdauer erhöhen"}]}]}"#)
        var dauer = line(1, "z.ZM11"); dauer.term = "Zauberdauer erhöhen"
        var erzwingen = line(1, "z.ZM11"); erzwingen.term = "Erzwingen"
        for order in [[dauer, erzwingen], [erzwingen, dauer]] {
            XCTAssertEqual(compare(s, breakdowns: [Breakdown(query: Query("check.modifier"), lines: order)], offers: []), [])
        }
        var other = erzwingen; other.term = "Kosten senken"
        XCTAssertEqual(kinds(compare(s, breakdowns: [Breakdown(query: Query("check.modifier"), lines: [dauer, other])], offers: [])),
                       [.wrongTerm])
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
        // `conditionFalse` entry's `via` (unless its `when` read the level: Task 30).
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
    /// GK4 also fires); a bare bool is `allowed`; `via` is an unsupported shape, and `span` (Task 31)
    /// is compared: no firing entry here read a choice offered for the round.
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
        // Task 31: `span` and (fix round 1) `via` are compared: no firing entry read a round choice
        // or rests on s.SK7.
        XCTAssertEqual(kinds(compare(span, breakdowns: [b], offers: [])), [.legal, .legal])
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

    /// R47: every `offered` field `OfferedChoice` models is compared (`ruling`, `options`, `max`,
    /// `via`, `costs`); every other field is an unsupported shape, never ignored.
    func testOfferedFieldsAreComparedOrReported() throws {
        let laden = Effect(payload: .cost(Cost(pool: .freeActions, amount: .number(1))),
                           origin: EffectOrigin(rule: "l", clause: "LZ2", index: .nested("0.costs.0")))
        let offer = OfferedChoice(choice: "laden", origin: ref("l.LZ2"), options: [.string("a"), .string("b")],
                                  costs: [laden], rulings: ["l.r"], via: [ref("v.V1")], max: 2,
                                  refused: [RefusedOption(option: .string("b"), reasons: [])])
        let good = try situation(#"{"expectSituation": {"offered": [{"choice": "laden", "ruling": "r", "options": ["a"], "max": 2, "via": ["v.V1"], "costs": {"freeAction": 1}}]}}"#)
        XCTAssertEqual(compare(good, breakdowns: [], offers: [offer]), [])
        for field in [#""ruling": "x.other""#, #""options": ["b"]"#, #""max": 3"#, #""via": ["w.W1"]"#, #""costs": "action""#] {
            let s = try situation(#"{"expectSituation": {"offered": [{"choice": "laden", "# + field + "}]}}")
            XCTAssertEqual(kinds(compare(s, breakdowns: [], offers: [offer])), [.wrongOffer], field)
        }
        let kind = try situation(#"{"expectSituation": {"offered": [{"choice": "laden", "kind": "basismanoever", "on": "x"}]}}"#)
        // Task 31: `kind` needs the book (a shape without it); `on` is compared (fix round 1): no hit here.
        XCTAssertEqual(compare(kind, breakdowns: [], offers: [offer]).map(\.shape), ["offered field kind", nil])
        let extra = try situation(#"{"expectSituation": {"notOffered": [{"choice": "other", "reason": "x"}]}}"#)
        XCTAssertEqual(compare(extra, breakdowns: [], offers: [offer]).map(\.shape), ["notOffered field reason"])
        // R47: a malformed `costs` never passes, whether the entry comes through the matcher (a
        // "malformed offer" shape) or straight to offerFailures (a failure naming it).
        let malformed = try situation(#"{"expectSituation": {"offered": [{"choice": "laden", "costs": {"nonsense": 1}}]}}"#)
        XCTAssertEqual(compare(malformed, breakdowns: [], offers: [offer]).map(\.shape), ["malformed offer"])
        XCTAssertEqual(Matcher.offerFailures(["costs": .object(["nonsense": .int(1)])], offer).count, 1)
        XCTAssertEqual(Matcher.offerFailures(["costs": .string("action")], offer).count, 1)
        XCTAssertEqual(Matcher.offerFailures(["costs": .object(["freeAction": .int(1)])], offer), [])
    }

    /// R41: a ruling the expectation names by its short id (as a situation writes a shared
    /// ruling, `round-up`) is the shared ruling or one of the rule the hit's clause sits on, never
    /// another rule's ruling of the same short name.
    func testAShortRulingNameExplainsOnlyTheSharedOrItsOwnRulesRuling() {
        let s = Situation(owned: [:], facts: [])
        func explains(_ ruling: String, _ origin: String, _ names: [String]) -> Bool {
            Explainer.explains(hit(ruling, origin), Mismatch(kind: .missingLine, query: "at", detail: "", names: names),
                               book: nil, situation: s)
        }
        XCTAssertTrue(explains("shared.round-up", "x.X1", ["round-up"]))
        XCTAssertTrue(explains("SA_41.table-shift", "SA_41.G1", ["table-shift"]))
        XCTAssertTrue(explains("other.open", "a.A2", ["other.open"]))
        XCTAssertFalse(explains("other.open", "a.A2", ["open"]))
        XCTAssertFalse(explains("b.round-up", "x.X1", ["round-up"]))
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
        // Task 31 fix round 1: a structured text from a clause is compared (it never matches the
        // clause's plain texts); without a `from` it stays a shape.
        XCTAssertEqual(kinds(compare(structured, breakdowns: [b], offers: [])), [.missingText, .missingText])
        let loose = try situation(#"{"expect": [{"query": "at"}], "expectSituation": {"texts": [{"mount": "runs on"}]}}"#)
        XCTAssertEqual(kinds(compare(loose, breakdowns: [b], offers: [])), [.unsupportedShape])
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

    /// R46.1: pending only when every mismatch is explained; one unexplained mismatch fails it.
    func testEveryMismatchMustBeExplainedForPending() throws {
        let s = try situation(#"{"pending": ["a.open"]}"#)
        let explained = Mismatch(kind: .missingLine, query: "at", detail: "", names: ["a.A1", "a"])
        let unexplained = Mismatch(kind: .missingLine, query: "at", detail: "", names: ["b.B1", "b"])
        let alsoExplained = Mismatch(kind: .result, query: "gs", detail: "", names: ["a.open"])
        let h = [hit("a.open", "a.A1")]
        XCTAssertEqual(Verdict.of(s, mismatches: [explained, unexplained], hits: h, book: nil, conflicts: []), .failed)
        XCTAssertEqual(Verdict.of(s, mismatches: [explained, alsoExplained], hits: h, book: nil, conflicts: []), .pending(["a.open"]))
        // Unsupported shapes beside explained mismatches need no explaining.
        XCTAssertEqual(Verdict.of(s, mismatches: [explained, .shape("term", "x")], hits: h, book: nil, conflicts: []),
                       .pending(["a.open"]))
    }

    /// R46.2: the explaining open-ruling effect's `when` must not be `no` in the situation
    /// (`unknown` and `yes` explain), whether it explains by reach or by name.
    func testAnOpenRulingEffectWhoseWhenIsNoExplainsNothing() throws {
        let pa = [Mismatch(kind: .total, query: "pa", detail: "")]
        let named = [Mismatch(kind: .missingLine, query: "at", detail: "", names: ["pl-adds.A4", "pl-adds"])]
        let a4 = [hit("pl-adds.open-q", "pl-adds.A4")]
        func verdict(_ fromBehind: String?, _ m: [Mismatch]) throws -> Verdict {
            let facts = fromBehind.map { #", "facts": [{"name": "gmFact.fromBehind", "value": \#($0), "owner": "gm"}]"# } ?? ""
            let s = try situation(#"{"pending": ["pl-adds.open-q"]"# + facts + "}")
            return Verdict.of(s, mismatches: m, hits: a4, book: Self.tagged, conflicts: [])
        }
        XCTAssertEqual(try verdict("false", pa), .failed)
        XCTAssertEqual(try verdict("false", named), .failed)
        XCTAssertEqual(try verdict(nil, pa), .pending(["pl-adds.open-q"]))
        XCTAssertEqual(try verdict("true", pa), .pending(["pl-adds.open-q"]))
        XCTAssertEqual(try verdict("true", named), .pending(["pl-adds.open-q"]))
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

    /// R78: a listed conflict's mismatches reduce to fingerprints (query, step, kind, a shape's tag;
    /// no numbers), so the same mismatch with other numbers is the same fingerprint.
    func testAMismatchsFingerprintIsItsQueryStepAndKind() {
        let a = ConflictFingerprint(Mismatch(kind: .total, query: "pa", detail: "step 2: expected total -1, got 1"))
        let b = ConflictFingerprint(Mismatch(kind: .total, query: "pa", detail: "step 2: expected total -1, got 7"))
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, ConflictFingerprint(query: "pa", step: 2, kind: "total"))
        XCTAssertEqual(ConflictFingerprint(Mismatch.shape("paid event: field of", "x")),
                       ConflictFingerprint(query: nil, step: nil, kind: "unsupportedShape", shape: "paid event: field of"))
        XCTAssertNotEqual(a, ConflictFingerprint(Mismatch(kind: .total, query: "pa", detail: "step 3: expected total -1, got 1")))
    }

    /// R78: a listed conflict whose mismatches match its snapshot stays `conflict`; one with a
    /// mismatch outside it fails; one whose snapshot names a fingerprint that no longer occurs
    /// stays `conflict`, and the diff reports the gone fingerprint.
    func testAListedConflictFailsWhenItsMismatchesGrowBeyondItsFingerprints() throws {
        let s = try situation("{}")
        let t1 = ConflictRef(file: "test.yaml", id: "T.1")
        let total = Mismatch(kind: .total, query: "at", detail: "expected total 1, got 0")
        let result = Mismatch(kind: .result, query: "at", detail: "expected result 17, got 16")
        let snapshot = ConflictSnapshot(conflicts: [t1.description: [ConflictFingerprint(total), ConflictFingerprint(result)]])
        // Same set: conflict, nothing new, nothing gone.
        XCTAssertEqual(Verdict.of(s, mismatches: [total, result], hits: [], book: nil, conflicts: listed, snapshot: snapshot), .conflict)
        XCTAssertEqual(snapshot.diff(t1, [total, result]), ConflictSnapshot.Diff(new: [], gone: []))
        // Grown set: failed, the new fingerprint named.
        let offer = Mismatch(kind: .missingOffer, detail: "expected formation offered")
        XCTAssertEqual(Verdict.of(s, mismatches: [total, result, offer], hits: [], book: nil, conflicts: listed, snapshot: snapshot), .failed)
        XCTAssertEqual(snapshot.diff(t1, [total, result, offer]).new, [ConflictFingerprint(offer)])
        // Shrunk set: still a conflict, the gone fingerprint reported.
        XCTAssertEqual(Verdict.of(s, mismatches: [total], hits: [], book: nil, conflicts: listed, snapshot: snapshot), .conflict)
        XCTAssertEqual(snapshot.diff(t1, [total]), ConflictSnapshot.Diff(new: [], gone: [ConflictFingerprint(result)]))
        // A listed conflict the snapshot does not know: every mismatch is new.
        XCTAssertEqual(Verdict.of(s, mismatches: [total], hits: [], book: nil, conflicts: listed, snapshot: ConflictSnapshot()), .failed)
        // Without a snapshot (record mode, the log round trip) nothing is checked.
        XCTAssertEqual(Verdict.of(s, mismatches: [total, offer], hits: [], book: nil, conflicts: listed), .conflict)
    }

    /// R78: the report names grown and shrunk conflicts, and snapshot entries for situations no
    /// longer listed; recording keeps other files' entries and drops a run file's passing ones.
    func testTheFingerprintsReportAndRecord() {
        let t1 = ConflictRef(file: "a.yaml", id: "1"), t2 = ConflictRef(file: "a.yaml", id: "2")
        let t3 = ConflictRef(file: "b.yaml", id: "3")
        let total = Mismatch(kind: .total, query: "at", detail: ""), legal = Mismatch(kind: .legal, query: "pa", detail: "")
        var snapshot = ConflictSnapshot(conflicts: [t1.description: [ConflictFingerprint(total)],
                                                    t2.description: [ConflictFingerprint(total)],
                                                    t3.description: [ConflictFingerprint(legal)],
                                                    "a.yaml 9": [ConflictFingerprint(legal)]])
        var report = HarnessReport()
        report.fingerprints(t1, snapshot.diff(t1, [total, legal]))
        report.fingerprints(t2, snapshot.diff(t2, []))
        XCTAssertEqual(report.conflictsGrown, ["a.yaml 1": ["pa: legal"]])
        XCTAssertEqual(report.conflictsShrunk, ["a.yaml 2": ["at: total"]])
        XCTAssertEqual(snapshot.unlisted([t1, t2, t3], files: ["a.yaml"]), ["a.yaml 9"])
        snapshot.record([t1: [total, legal], t2: []], listed: [t1, t2, t3], files: ["a.yaml"])
        XCTAssertEqual(snapshot.conflicts, [t1.description: [ConflictFingerprint(total), ConflictFingerprint(legal)].sorted(),
                                            t3.description: [ConflictFingerprint(legal)]])
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

    /// Task 34: the Probe table is rulec's (`checks.yaml` → situations.json's `checks`), not
    /// rules.db: each row's three attributes and a talent's Belastung flag.
    func testTheProbeTableIsReadFromSituationsJSON() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "checks-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"""
            {"vocabularyVersion": 1, "situations": [],
             "checks": {"TAL_10": {"attributes": ["KL", "IN", "IN"], "hinderedByBelastung": "maybe",
                                   "applications": {"2": "Suchen"}},
                        "TAL_3": {"attributes": ["MU", "GE", "KK"], "hinderedByBelastung": true},
                        "SPELL_21": {"attributes": ["MU", "KL", "CH"]}}}
            """#.utf8).write(to: url)
        let table = CheckAttributes.table(from: url)
        XCTAssertEqual(table.attributes, ["TAL_10": ["KL", "IN", "IN"], "TAL_3": ["MU", "GE", "KK"],
                                          "SPELL_21": ["MU", "KL", "CH"]])
        XCTAssertEqual(table.hinderedByBelastung, ["TAL_10": "maybe", "TAL_3": true])
        XCTAssertEqual(CheckAttributes.table(from: Repo.url("build/rules/no-such.json")).attributes, [:])
    }

    /// Task 30: a talent check's `check.hinderedByBelastung` is the talent's own Belastung flag,
    /// which the harness, as the app, hands in from the Probe table (`checks.yaml`), as it hands
    /// in the Probe's attributes; a stated one is kept.
    func testATalentChecksBelastungFlagIsHandedIn() throws {
        try XCTSkipIf(CheckAttributes.all.isEmpty, "run make rules-json")
        let climb = try situation(#"{"facts": [{"name": "check.talent", "value": "TAL_3", "owner": "player"}]}"#)
        XCTAssertEqual(climb.engineSituation.facts["check.hinderedByBelastung"],
                       Fact(name: "check.hinderedByBelastung", value: true, owner: .derived))
        let senses = try situation(#"{"facts": [{"name": "check.talent", "value": "TAL_10", "owner": "player"}]}"#)
        XCTAssertEqual(senses.engineSituation.facts["check.hinderedByBelastung"]?.value, "maybe")
        let talk = try situation(#"{"facts": [{"name": "check.talent", "value": "TAL_21", "owner": "player"}]}"#)
        XCTAssertEqual(talk.engineSituation.facts["check.hinderedByBelastung"]?.value, false)
        let stated = try situation(#"{"facts": [{"name": "check.talent", "value": "TAL_3", "owner": "player"},"#
                                   + #"{"name": "check.hinderedByBelastung", "value": false, "owner": "derived"}]}"#)
        XCTAssertEqual(stated.engineSituation.facts["check.hinderedByBelastung"]?.value, false)
        XCTAssertNil(try situation("{}").engineSituation.facts["check.hinderedByBelastung"])
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
        // A notApplied entry's keys (rulec checks them; a step's entries, passed through, are
        // checked here): the decoder reads exactly the vocabulary's, and an unknown key is malformed.
        let notAppliedKeys = try XCTUnwrap(v["notAppliedKeys"] as? [String])
        XCTAssertEqual(Set(notAppliedKeys), Set(ExpectedNotApplied.CodingKeys.allCases.map(\.rawValue)))
        XCTAssertNotNil(ExpectedNotApplied(.object(["rule": .string("x"), "because": .string("y")])))
        XCTAssertNil(ExpectedNotApplied(.object(["rule": .string("x"), "becuase": .string("y")])))
        let s = try situation(#"{"expect": [{"query": "at", "total": 0}], "expectSituation": {"notApplied": [{"rule": "x", "colour": "red"}]}}"#)
        XCTAssertEqual(compare(s, breakdowns: [Breakdown(query: Query("at"))], offers: []).map(\.shape), ["malformed notApplied"])
    }

    /// U1 (Task 26): the action layer runs a 3W20 check. `rolls`, `fp`, `qs`, `spent`, `success`,
    /// `result` and a `sequence` of reroll steps run when the situation states a talent or spell
    /// check whose Probe the Probe table knows, with one die per attribute; `events`, dice without a
    /// check and any other step stay unsupported.
    func testOnlyA3W20CheckRunsOnTheActionLayer() throws {
        let check = #""facts": [{"name": "check.kind", "value": "talent", "owner": "player"}, {"name": "check.talent", "value": "TAL_10", "owner": "player"}]"#
        let reroll = #"{"choose": {"choice.reroll": "ADV_4", "choice.rerollDie": 2}, "rolls": {"roll.reroll": 11}, "expect": {"fp": 8}}"#
        try XCTSkipIf(CheckAttributes.all["TAL_10"] == nil, "run make rules-json")
        XCTAssertEqual(CheckAttributes.all["TAL_10"], ["KL", "IN", "IN"])
        XCTAssertTrue(ActionRunner.canRun(try situation(#"{"expect": [{"query": "at"}]}"#)))
        XCTAssertFalse(ActionRunner.canRun(try situation(#"{"rolls": [3, 4, 5]}"#)))
        XCTAssertFalse(ActionRunner.canRun(try situation(#"{"sequence": [{"rolls": {"check.result": "failure"}}]}"#)))
        for key in ["events", "fp", "qs", "spent", "success", "result"] {
            XCTAssertFalse(ActionRunner.canRun(try situation(#"{"expectSituation": {"\#(key)": []}}"#)), key)
        }
        XCTAssertTrue(ActionRunner.canRun(try situation(#"{\#(check), "rolls": [3, 4, 5], "expectSituation": {"fp": 1, "qs": 1}}"#)))
        XCTAssertTrue(ActionRunner.canRun(try situation(#"{\#(check), "rolls": [3, 4, 5], "sequence": [\#(reroll)]}"#)))
        XCTAssertFalse(ActionRunner.canRun(try situation(#"{\#(check), "rolls": [3, 4], "expectSituation": {"fp": 1}}"#)))
        XCTAssertFalse(ActionRunner.canRun(try situation(#"{\#(check), "rolls": [3, 4, 5], "expectSituation": {"events": []}}"#)))
        XCTAssertFalse(ActionRunner.canRun(try situation(#"{\#(check), "rolls": [3, 4, 5], "sequence": [{"rolls": {"check.result": "failure"}}]}"#)))
        XCTAssertNotNil(ActionRunner.RerollStep(try JSONDecoder().decode(JSONValue.self, from: Data(reroll.utf8))))
        XCTAssertEqual(ActionRunner.needs(try situation(#"{"rolls": [1], "expectSituation": {"events": []}}"#)), [.rolls, .events])
    }

    /// V1 (Task 26): `values` compares the attribute stage's effective values; without a check
    /// it is an unsupported shape, and malformed values are reported.
    func testValuesCompareTheAttributeStage() throws {
        let q = QueryExpectation(query: "check.attribute", values: .array([12, 14, 14]))
        var c = MatchResult()
        Matcher.query(q, Breakdown(query: Query("check.attribute")), values: [12, 14, 14], &c)
        XCTAssertEqual(kinds(c.mismatches), [])
        c = MatchResult()
        Matcher.query(q, Breakdown(query: Query("check.attribute")), values: [11, 13, 13], &c)
        XCTAssertEqual(kinds(c.mismatches), [.values])
        c = MatchResult()
        Matcher.query(q, Breakdown(query: Query("check.attribute")), &c)
        XCTAssertEqual(c.mismatches.map(\.shape), ["values"])
        c = MatchResult()
        Matcher.query(QueryExpectation(query: "check.attribute", values: .array(["a"])), Breakdown(query: Query("check.attribute")),
                      values: [12], &c)
        XCTAssertEqual(c.mismatches.map(\.shape), ["malformed values"])
    }

    /// O4 (Task 26): a `reroll` offer entry matches the check's reroll offers by clause (or rule)
    /// and `from`; offered needs a legal one; `notOffered` with `because` needs an illegal one
    /// refused by it; a reroll not offered at all cannot show its reason; other fields are shapes.
    func testRerollOffersMatchTheChecksRerolls() {
        let b5 = NotApplied(origin: ref("ADV_4.B5"), reason: .forbidden, because: "Doppel-20: Begabung nicht erlaubt")
        let legal = RerollOffer(origin: ref("ADV_4.B1"), name: "Begabung", dice: [0, 1, 2], keep: "better", remaining: 1)
        let refused = RerollOffer(origin: ref("ADV_4.B1"), name: "Begabung", dice: [0, 1, 2], keep: "better", remaining: 1,
                                  reasons: [b5])
        func check(_ entry: [String: JSONValue], _ wanted: Bool, _ offers: [RerollOffer]) -> [Mismatch.Kind] {
            kinds(Matcher.offer(.object(entry), wanted: wanted, in: [], notApplied: [], offering: [:], rerolls: offers))
        }
        XCTAssertEqual(check(["reroll": "ADV_4.B1"], true, [legal]), [])
        XCTAssertEqual(check(["reroll": "ADV_4"], true, [legal]), [], "a rule id names its reroll")
        XCTAssertEqual(check(["reroll": "ADV_4.B1"], true, [refused]), [.missingOffer])
        XCTAssertEqual(check(["reroll": "ADV_4.B1", "from": "ADV_4.B7"], true, [legal]), [.missingOffer])
        XCTAssertEqual(check(["reroll": "ADV_4.B1", "because": "ADV_4.B5"], false, [refused]), [])
        XCTAssertEqual(check(["reroll": "ADV_4.B1", "because": "Doppel-20: Begabung nicht erlaubt"], false, [refused]), [])
        XCTAssertEqual(check(["reroll": "ADV_4.B1", "because": "ADV_4.B6"], false, [refused]), [.wrongOffer])
        XCTAssertEqual(check(["reroll": "ADV_4.B1"], false, [legal]), [.unexpectedOffer])
        XCTAssertEqual(check(["reroll": "ADV_4.B1", "because": "ADV_4.B5"], false, []), [.unsupportedShape])
        XCTAssertEqual(check(["reroll": "ADV_4.B1", "togetherWith": "x"], true, [legal]), [.unsupportedShape])
        // Without a check the entry stays the action layer's.
        XCTAssertEqual(kinds(Matcher.offer(.object(["reroll": "ADV_4.B1"]), wanted: true, in: [], notApplied: [], offering: [:])),
                       [.unsupportedShape])
    }

    /// R1 (Task 26): `fp`, `qs`, `spent`, `success`, `result {success, kind, from}` and `dice`
    /// compare the procedure's result (fixture book, probe-fertigkeiten's numbers).
    func testTheResultKeysCompareTheProcedure() throws {
        let engine = CheckProcedureTests.fixture
        let facts: [Fact] = [("attr.KL", 12), ("attr.IN", 14), ("fw.TAL_10", 8)].map { Fact(name: $0.0, value: .int($0.1), owner: .sheet) }
        let s = Situation(owned: ["chk-begabung": OwnedRule(level: 1, option: "TAL_10")], facts: facts)
        let request = CheckRequest(kind: .talent, id: "TAL_10", attributes: ["KL", "IN", "IN"])
        let rolled = CheckProcedure.start(request, in: s, engine: engine).state.step(.dice([5, 19, 12]), engine: engine)
        let view = ProcedureView(stages: rolled.state.stages, result: rolled.state.result, offers: rolled.offers)
        func compare(_ expect: String, _ v: ProcedureView = view) throws -> [Mismatch] {
            let o = try XCTUnwrap(try JSONDecoder().decode(JSONValue.self, from: Data(expect.utf8)).objectValue)
            var c = MatchResult()
            ActionRunner.compareResult(o, v, step: nil, &c)
            return c.mismatches
        }
        XCTAssertEqual(kinds(try compare(#"{"fp": 3, "qs": 1, "spent": [0, 5, 0], "success": true, "result": {"kind": "regular"}}"#)), [])
        XCTAssertEqual(kinds(try compare(#"{"fp": 4, "qs": 2, "spent": [0, 0, 0], "success": false}"#)), [.fp, .qs, .spent, .success])
        XCTAssertEqual(try compare(#"{"fp": 4}"#).first?.query, "check.fp", "R41 reads the stage the key stands for")
        XCTAssertEqual(kinds(try compare(#"{"result": {"kind": "patzer", "from": "chk-proben.PZ1"}}"#)), [.checkResult])
        XCTAssertEqual(kinds(try compare(#"{"result": {"kind": "regular", "note": "x"}}"#)), [.unsupportedShape])

        let after = rolled.state.step(.reroll(die: 1, face: 11), engine: engine)
        let v2 = ProcedureView(stages: after.state.stages, result: after.state.result, offers: after.offers)
        XCTAssertEqual(kinds(try compare(#"{"dice": [{"die": 2, "rolled": [19, 11], "counts": 11, "from": "chk-begabung.B1"}]}"#, v2)), [])
        XCTAssertEqual(kinds(try compare(#"{"dice": [{"die": 2, "rolled": [19, 11], "counts": 11, "from": "chk-begabung.B2"}]}"#, v2)), [.dice])
        XCTAssertEqual(kinds(try compare(#"{"fp": 8, "qs": 3, "spent": [0, 0, 0]}"#, v2)), [])
    }

    /// R48: an open-ruling effect explains a mismatch on a target that reads its target as an
    /// operand: SA_9.FS1 (open spezialisierung-when) reaches `check.fw`, which `check.fp` reads,
    /// which `check.qs` reads. Not a target outside the chain (`at`). Real rules.
    func testAnOpenRulingExplainsAMismatchDownTheOperandChain() throws {
        let book = try XCTUnwrap(CheckProcedureTests.real?.book, "run make rules-json")
        XCTAssertEqual(Explainer.operandChain("check.qs", book), ["check.qs", "check.fp", "check.fw"])
        let hit = OpenHit(ruling: "SA_9.spezialisierung-when", origin: ref("SA_9.FS1"))
        let s = Situation(owned: ["SA_9": OwnedRule(level: 1, option: "TAL_10", option2: 2)], facts: [])
        for q in ["check.qs", "check.fp", "check.fw"] {
            XCTAssertTrue(Explainer.explains(hit, Mismatch(kind: .qs, query: q, detail: ""), book: book, situation: s), q)
        }
        XCTAssertFalse(Explainer.explains(hit, Mismatch(kind: .total, query: "at", detail: ""), book: book, situation: s))
        XCTAssertFalse(Explainer.explains(hit, Mismatch(kind: .checkResult, detail: ""), book: book, situation: s))
    }

    /// A stated check whose Probe the Probe table lacks runs and mismatches; it is not unsupported.
    /// A reroll step naming a rule that offers none stops the sequence with one mismatch.
    func testAMissingProbeRowOrRerollIsAMismatch() throws {
        let engine = try XCTUnwrap(CheckProcedureTests.real, "run make rules-json")
        let facts = #""facts": [{"name": "check.kind", "value": "talent", "owner": "player"}, {"name": "check.talent", "value": "TAL_10", "owner": "player"}, {"name": "attr.KL", "value": 12, "owner": "sheet"}, {"name": "attr.IN", "value": 14, "owner": "sheet"}, {"name": "fw.TAL_10", "value": 8, "owner": "sheet"}]"#
        let s = try situation(#"{\#(facts), "rolls": [5, 19, 12], "expectSituation": {"fp": 3}}"#)
        XCTAssertTrue(ActionRunner.canRun(s, attributes: [:]))
        let missing = try XCTUnwrap(ActionRunner.run(s, engine: engine, attributes: [:]))
        XCTAssertEqual(kinds(missing.mismatches), [.checkResult])
        XCTAssertNil(missing.view)

        let probe = ["TAL_10": ["KL", "IN", "IN"]]
        let wrongRule = try situation(#"""
            {\#(facts), "rolls": [5, 19, 12], "expectSituation": {"fp": 3},
             "sequence": [{"choose": {"choice.reroll": "SA_9", "choice.rerollDie": 2}, "rolls": {"roll.reroll": 11}, "expect": {"fp": 8}},
                          {"choose": {"choice.reroll": "ADV_4", "choice.rerollDie": 1}, "rolls": {"roll.reroll": 1}, "expect": {"fp": 99}}]}
            """#)
        let run = try XCTUnwrap(ActionRunner.run(wrongRule, engine: engine, attributes: probe))
        XCTAssertEqual(kinds(run.mismatches), [.missingOffer], "the sequence stops at the missing reroll: \(run.mismatches)")
    }

    /// R50: a situation expecting a `gained` / `cleared` event (at the top or in a step) keeps its
    /// query expectations uncompared.
    func testASituationExpectingAStateChangeIsDescribedAfterIt() throws {
        XCTAssertTrue(SituationsHarnessTests.expectsStateChange(try situation(#"{"expectSituation": {"events": [{"gained": "STATE_8"}]}}"#)))
        XCTAssertTrue(SituationsHarnessTests.expectsStateChange(try situation(#"{"sequence": [{"expect": {"events": [{"cleared": "X"}]}}]}"#)))
        XCTAssertFalse(SituationsHarnessTests.expectsStateChange(try situation(#"{"expectSituation": {"events": [{"paid": "asp"}]}}"#)))
    }

    /// Q2 (Task 26 extra 8): a situation whose action part cannot run still has its query
    /// expectations compared, and only those.
    func testOnlyTheQueriesOfAnUnsupportedSituationAreCompared() throws {
        let s = try situation(#"""
            {"base": {"pa": 8}, "expect": [{"query": "pa", "total": 5}],
             "expectSituation": {"events": [{"paid": "asp"}], "texts": [{"gm": "x"}], "legal": {"allowed": false}}}
            """#)
        XCTAssertFalse(ActionRunner.canRun(s))
        let run = Matcher.run(s, engine: Engine(book: Self.book), onlyQueries: true)
        XCTAssertEqual(kinds(run.mismatches), [.total])
        XCTAssertEqual(run.mismatches.first?.query, "pa")
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

    /// R77: the section is split into `###` category subsections; every id under any of them is
    /// listed, none from the section before or after, and a subsection's intro adds none.
    func testTheConflictsSubsectionsAreAllRead() {
        let md = """
        ## Something before
        - situations/a.yaml 9.9: not a conflict.
        ## Expectation conflicts for the owner

        Three categories (R77); the fingerprints are in conflict-fingerprints.json.

        ### (a) The expectation is wrong per the rule text

        - situations/a.yaml 1.2: expects something.

        ### (b) Input convention

        The owner restates the bases.

        - situations/b.yaml 5.6, c.yaml 17.3: folded bases.

        ### (c) Rule data not written

        - situations/a.yaml 1.4: no rule.
        ## Reviews reset by hand edits
        - situations/a.yaml 1.3: not a conflict.
        """
        XCTAssertEqual(Conflicts.parse(md, order: [:])?.map(\.description), ["a.yaml 1.2", "b.yaml 5.6", "c.yaml 17.3", "a.yaml 1.4"])
        XCTAssertEqual(Conflicts.categories(md).map(\.heading),
                       ["(a) The expectation is wrong per the rule text", "(b) Input convention", "(c) Rule data not written"])
    }

    /// R77: MIGRATION.md's conflicts section has the three category subsections, each listing
    /// situations, and every listed conflict is under one of them.
    func testMIGRATIONsConflictsAreInTheThreeCategories() throws {
        let md = try String(contentsOf: Repo.url("docs/rules-rework/examples/MIGRATION.md"), encoding: .utf8)
        let categories = Conflicts.categories(md)
        XCTAssertEqual(categories.map { String($0.heading.prefix(3)) }, ["(a)", "(b)", "(c)"])
        let all = try XCTUnwrap(Conflicts.parse(md, order: [:]))
        var inCategories: [ConflictRef] = []
        for c in categories {
            let ids = Conflicts.parse(Conflicts.section + "\n" + c.body, order: [:]) ?? []
            XCTAssertFalse(ids.isEmpty, c.heading)
            inCategories += ids
        }
        XCTAssertEqual(Set(all), Set(inCategories))
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

    // MARK: - Task 27: hits, combat rolls, attacks and defences

    private func check(_ id: String, _ application: String?, from: String, via: [String] = []) -> PendingCheck {
        PendingCheck(origin: ref(from), kind: .talent, id: id, application: application, onSuccess: [], onFailure: [],
                     situation: Situation(owned: [:], facts: []), via: via.map(ref))
    }

    /// E1: `events` against what the action gave. A `check` entry is a check it asked for (talent,
    /// application or `with`, clause, `via`); `gained` / `cleared` / `logged` / `paid` are events by
    /// kind, rule or note, clause; each actual entry matches once; `[]` asserts neither an event nor
    /// a check; an event the engine has no kind for (`damage`, `itemChanged`) is an unsupported shape.
    func testEventsMatchTheChecksAskedForAndTheEventsGiven() throws {
        let tz8 = check("TAL_8", "Handlungsfähigkeit bewahren", from: "trefferzonen.TZ8", via: ["ADV_54.E1"])
        let gained = Event(kind: .gained, origin: ref("trefferzonen.TZ8"), rule: "STATE_10", levels: 1)
        func events(_ json: String, _ actual: [Event] = [], _ checks: [PendingCheck] = []) throws -> [Mismatch] {
            let list = try JSONDecoder().decode([JSONValue].self, from: Data(json.utf8))
            return CombatRunner.events(list, events: actual, checks: checks)
        }
        XCTAssertEqual(try events(#"[{"check": {"talent": "TAL_8", "application": "Handlungsfähigkeit bewahren"}, "from": "trefferzonen.TZ8"}]"#, [], [tz8]), [])
        XCTAssertEqual(try events(#"[{"check": {"talent": "TAL_8", "with": null}, "from": "trefferzonen.TZ8", "via": ["ADV_54.E1"]}]"#, [], [tz8]), [])
        XCTAssertEqual(kinds(try events(#"[{"check": {"talent": "TAL_8", "application": "Störungen ignorieren"}}]"#, [], [tz8])), [.missingEvent])
        XCTAssertEqual(kinds(try events(#"[{"check": {"talent": "TAL_8"}}, {"check": {"talent": "TAL_8"}}]"#, [], [tz8])), [.missingEvent])
        XCTAssertEqual(try events(#"[{"gained": "STATE_10", "from": "trefferzonen.TZ8", "levels": 1}]"#, [gained]), [])
        XCTAssertEqual(kinds(try events(#"[{"gained": "STATE_10", "from": "trefferzonen.TZ11"}]"#, [gained])), [.missingEvent])
        XCTAssertEqual(try events("[]"), [])
        XCTAssertEqual(kinds(try events("[]", [], [tz8])), [.unexpectedEvent])
        XCTAssertEqual(kinds(try events("[]", [gained])), [.unexpectedEvent])
        // R53: a hit's `damaged` matches by amount, pool and clause; `[]` does not count it (the
        // hit is the situation's own statement).
        let damaged = Event(kind: .damaged, origin: ref("schaden.S2"), pool: .le, amount: 8)
        XCTAssertEqual(try events(#"[{"damaged": {"amount": 8, "pool": "le"}, "from": "schaden.S2"}]"#, [damaged]), [])
        XCTAssertEqual(kinds(try events(#"[{"damaged": {"amount": 9, "pool": "le"}}]"#, [damaged])), [.missingEvent])
        XCTAssertEqual(try events("[]", [damaged]), [])
        let shapes = try events(#"[{"damage": {"formula": "1W3+1"}, "from": "trefferzonen.TZ11"}, {"itemChanged": {"held": false}, "from": "trefferzonen.TZ11"}, {"check": {"at": 15, "attack": "Tritt", "by": "mount"}}]"#)
        // R72 (Task 31 fix round 2): an attack check is compared with the attacks asked (none here).
        // Task 32 (R62): a damage by a formula and an item let go are compared too (none here).
        XCTAssertEqual(kinds(shapes), [.missingEvent, .missingEvent, .missingEvent])
    }

    /// C1: an `offered` / `notOffered` entry naming an attack or a defence (`defence: shieldParry`,
    /// `defence: [pa, aw]`, `attack: ranged`) matches `CombatRoll.options`: a generic id names every
    /// option on its target; offered needs a legal one (from `from`, with `result` / `base` / `lines`
    /// compared on its target); not offered needs none legal, refused by the `because` and `ruling`.
    func testAttackAndDefenceEntriesMatchTheCombatOptions() throws {
        let gk4 = NotApplied(origin: ref("groessenkategorie.GK4"), reason: .forbidden, because: "nur Schild oder Ausweichen",
                             rulings: ["groessenkategorie.mounted-size"])
        func target(_ q: String, _ result: Int) -> Breakdown { Breakdown(query: Query(q), base: sheetBase(result)) }
        let options = [
            CombatOption(kind: .attack, id: "melee", request: .attack(), origin: nil, target: target("at", 14), reasons: []),
            CombatOption(kind: .defence, id: "weaponParry", request: .defend(kind: .pa, with: "weapon"), origin: nil,
                         target: target("pa(with: weapon)", 8), reasons: [gk4]),
            CombatOption(kind: .defence, id: "shieldParry", request: .defend(kind: .pa, with: "shield"), origin: ref("schilde.SCH3"),
                         target: target("pa(with: shield)", 13), reasons: []),
            CombatOption(kind: .defence, id: "aw", request: .defend(kind: .aw), origin: nil, target: target("aw", 7), reasons: []),
        ]
        func match(_ json: String, _ wanted: Bool) throws -> MatchResult {
            let o = try XCTUnwrap(try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8)).objectValue)
            var c = MatchResult()
            Matcher.combatOffer(o, wanted: wanted, options: options, &c)
            return c
        }
        XCTAssertEqual(try match(#"{"defence": "shieldParry", "from": "schilde.SCH3", "result": 13}"#, true).mismatches, [])
        XCTAssertEqual(kinds(try match(#"{"defence": "shieldParry", "result": 12}"#, true).mismatches), [.result])
        XCTAssertEqual(kinds(try match(#"{"defence": "shieldParry", "from": "schilde.SCH6"}"#, true).mismatches), [.missingOffer])
        XCTAssertEqual(try match(#"{"defence": "weaponParry", "because": "groessenkategorie.GK4", "ruling": "groessenkategorie.mounted-size"}"#, false).mismatches, [])
        XCTAssertEqual(kinds(try match(#"{"defence": "weaponParry", "because": "passierschlag.PS2"}"#, false).mismatches), [.wrongOffer])
        // `pa` names both parries: the shield parry is still legal.
        XCTAssertEqual(kinds(try match(#"{"defence": ["pa", "aw"], "because": "groessenkategorie.GK4"}"#, false).mismatches),
                       [.unexpectedOffer, .unexpectedOffer])
        XCTAssertEqual(try match(#"{"attack": "at"}"#, true).mismatches, [])
        XCTAssertEqual(kinds(try match(#"{"attack": "ranged"}"#, true).mismatches), [.missingOffer])
        let prose = try match(#"{"attack": "ranged", "reason": "im Nahkampf nicht"}"#, false)
        XCTAssertEqual(prose.mismatches, [])
        XCTAssertEqual(prose.notes.count, 1)
        XCTAssertEqual(kinds(try match(#"{"defence": "aw", "on": "takeDamage"}"#, true).mismatches), [.unsupportedShape])
    }

    /// R50 kept, per expectation (Task 27): a query is compared after the action when its breakdown
    /// there differs and reads what the action changed (a fact it stated, a rule an event gained or
    /// cleared); otherwise before.
    func testAQueryDescribesTheStateAfterTheActionWhenItReadsWhatTheActionChanged() {
        let before = Breakdown(query: Query("check.modifier"), lines: [line(-2, "DISADV_57.VW1")])
        var tz8 = line(-1, "trefferzonen.TZ8")
        tz8.facts = [FactUse(name: "hit.overWundschwelle", value: 1, owner: .derived)]
        let after = Breakdown(query: Query("check.modifier"), lines: [line(-2, "DISADV_57.VW1"), tz8])
        XCTAssertTrue(CombatRunner.describesTheAfter(after, differsFrom: before, changed: ["hit.overWundschwelle"], rules: []))
        XCTAssertFalse(CombatRunner.describesTheAfter(after, differsFrom: before, changed: ["hit.sp"], rules: []))
        XCTAssertFalse(CombatRunner.describesTheAfter(before, differsFrom: before, changed: ["hit.overWundschwelle"], rules: []))
        let liegend = Breakdown(query: Query("pa"), lines: [line(-2, "STATE_10.L2")])
        XCTAssertTrue(CombatRunner.describesTheAfter(liegend, differsFrom: Breakdown(query: Query("pa")), changed: [], rules: ["STATE_10"]))
    }

    /// Which situations run as a hit or as the rolls of an attack: the SP or a `hit.*` fact stated
    /// (at the top or in a step), a check event expected from a clause whose `check` reads a hit
    /// (reiterkampf.RK10), or steps that are all `rolls: [{ w20: n }]`.
    func testAHitOrAnAttacksRollsRunOnTheCombatRunner() throws {
        let book = try XCTUnwrap(try? RuleBook.load(from: Repo.url("build/rules/rules.json")), "run make rules-json")
        XCTAssertTrue(CombatRunner.canRun(try situation(#"{"base": {"sp": 7}}"#), book: book))
        XCTAssertTrue(CombatRunner.canRun(try situation(#"{"facts": [{"name": "hit.tp", "value": 9, "owner": "roll"}]}"#), book: book))
        XCTAssertTrue(CombatRunner.canRun(try situation(#"{"sequence": [{"hero": {"values": {"sp": 5}}}]}"#), book: book))
        XCTAssertTrue(CombatRunner.canRun(try situation(#"{"sequence": [{"choose": {"choice.mountHit": true}, "expect": {"events": [{"check": {"talent": "TAL_6"}, "from": "reiterkampf.RK10"}]}}]}"#), book: book))
        XCTAssertFalse(CombatRunner.canRun(try situation(#"{"expectSituation": {"events": [{"check": {"talent": "TAL_6"}, "from": "reiterkampf.RK12"}]}}"#), book: book))
        XCTAssertTrue(CombatRunner.canRun(try situation(#"{"sequence": [{"rolls": [{"w20": 3}], "expect": {"success": false}}]}"#), book: book))
        XCTAssertFalse(CombatRunner.canRun(try situation(#"{"sequence": [{"rolls": [{"w20": 3}]}, {"round": {"phase": "start"}}]}"#), book: book))
        XCTAssertFalse(CombatRunner.canRun(try situation(#"{"expect": [{"query": "at"}]}"#), book: book))
    }

    /// R52, Task 30: in a hit run without a query, a situation-level `notApplied` for a rule no
    /// stage of the hit evaluates is about the hero sheet: it is looked up in the sheet's
    /// breakdown (`Engine.sheet(in:)`). A rule a stage does evaluate is compared as ever.
    func testASheetWideNotAppliedIsLookedUpOnTheSheet() throws {
        let s = try situation(#"{"expectSituation": {"notApplied": [{"rule": "DISADV_57", "reason": "needs the Fokusregel"}, {"rule": "trefferzonen", "clause": "TZ8", "reason": "conditionFalse"}]}}"#)
        let stage = Breakdown(query: Query("wundschwelle"), base: line(8, "trefferzonen.TZ8", kind: .base))
        let hit = HitView(queries: [:], breakdowns: [stage], situation: Situation(owned: [:], facts: []))
        var c = MatchResult()
        let sheet = Breakdown(query: Query("sheet"), notApplied: [NotApplied(origin: ref("DISADV_57.VW1"), reason: .conditionFalse)])
        Matcher.situationLevel(s, breakdowns: [], offers: [], offering: [:], hit: hit, sheet: sheet, &c)
        XCTAssertEqual(kinds(c.mismatches), [.missingNotApplied], "DISADV_57 is on the sheet; TZ8 is not in the stage")
        var none = MatchResult()
        Matcher.situationLevel(s, breakdowns: [], offers: [], offering: [:], hit: hit, sheet: Breakdown(query: Query("sheet")), &none)
        XCTAssertEqual(kinds(none.mismatches), [.missingNotApplied, .missingNotApplied])
    }

    /// Task 30 (R62): a situation without a query compares its situation-level `texts`,
    /// `notApplied` and `questions` with the hero sheet's breakdown (lebensenergie 15.17–15.19).
    func testASituationWithoutAQueryReadsTheSheet() throws {
        let s = try situation(#"{"expectSituation": {"texts": [{"player": "Heilkräuter wirken dennoch.", "from": "r.R7"}]}}"#)
        let sheet = Breakdown(query: Query("sheet"), texts: [TextLine(kind: .tell, audience: .player, text: "Heilkräuter wirken dennoch.",
                                                                      origin: ref("r.R7"))])
        var c = MatchResult()
        Matcher.situationLevel(s, breakdowns: [], offers: [], offering: [:], sheet: sheet, &c)
        XCTAssertEqual(c.mismatches, [])
        var without = MatchResult()
        Matcher.situationLevel(s, breakdowns: [], offers: [], offering: [:], &without)
        XCTAssertEqual(without.mismatches.compactMap(\.shape), ["situation texts without a query"])
    }

    // MARK: - Sequences and implied actions (Task 28)

    /// Which situations run on the `StateRunner`: a sequence of steps it models (actions, the
    /// clock, statements), or events of the action the situation implies: a cast (any event) or
    /// settling (only Stufen gained or cleared). Dice and events no implied action gives stay
    /// with the other runners, or unsupported.
    func testWhichSituationsRunAsActionsInOrder() throws {
        XCTAssertTrue(StateRunner.canRun(try situation(#"{"sequence": [{"action": "zielen", "expect": {"process": {"zielen": 1}}}]}"#)))
        XCTAssertTrue(StateRunner.canRun(try situation(#"{"sequence": [{"advanceClock": {"minutes": 60}}]}"#)))
        XCTAssertTrue(StateRunner.canRun(try situation(#"{"sequence": [{"choose": {"choice.x": true}, "expect": {"at": {"total": 1}}}]}"#)))
        XCTAssertTrue(StateRunner.canRun(try situation(#"{"expectSituation": {"events": [{"gained": "STATE_8"}]}}"#)))
        XCTAssertTrue(StateRunner.canRun(try situation(#"""
            {"facts": [{"name": "check.kind", "value": "spell", "owner": "player"}, {"name": "check.spell", "value": "SPELL_1", "owner": "player"}],
             "expectSituation": {"events": [{"paid": {"pool": "asp", "amount": 8}}]}}
            """#)))
        XCTAssertFalse(StateRunner.canRun(try situation(#"{"expectSituation": {"events": [{"after": {"leCurrent": 23}}]}}"#)),
                       "no implied action gives a regeneration's LeP")
        XCTAssertFalse(StateRunner.canRun(try situation(#"{"sequence": [{"rolls": [{"w20": 3}]}]}"#)))
        XCTAssertTrue(StateRunner.canRun(try situation(#"{"sequence": [{"event": {"COND_1": 0}}]}"#)), "Task 30: a Stufe stated")
        XCTAssertFalse(StateRunner.canRun(try situation(#"{"expect": [{"query": "at", "total": 1}]}"#)))
    }

    /// A sequence runs its steps as actions in order, each step's `expect` checked against the
    /// state after it: `process` (progress, `capped`, `ended`) and a query of the shot's own
    /// breakdown (its die from `rolls: { roll.attack }`). On the fixture book's Zielen (st-aim.A1).
    func testEachStepIsCheckedAgainstTheStateAfterIt() throws {
        let engine = Engine(book: ProcessTests.state)
        let s = try situation(#"""
            {"facts": [{"name": "loadout.weapon", "value": "Kurzbogen", "owner": "loadout"},
                       {"name": "loadout.weapon.kind", "value": "ranged", "owner": "loadout"}],
             "base": {"fk(with: Kurzbogen)": 14},
             "sequence": [{"action": "zielen", "expect": {"process": {"zielen": 1}}},
                          {"action": "zielen", "expect": {"process": {"zielen": 2}}},
                          {"action": "zielen", "expect": {"process": {"zielen": 2, "capped": true}}},
                          {"action": "shoot", "rolls": {"roll.attack": 3},
                           "expect": {"fk(with: Kurzbogen)": {"total": 4, "lines": [{"from": "st-aim.A1", "value": 4}]},
                                                         "process": {"zielen": "ended"}}}]}
            """#)
        XCTAssertTrue(StateRunner.canRun(s))
        XCTAssertEqual(StateRunner.run(s, engine: engine).mismatches, [])

        let wrong = try situation(#"""
            {"facts": [{"name": "loadout.weapon.kind", "value": "ranged", "owner": "loadout"}],
             "sequence": [{"action": "zielen", "expect": {"process": {"zielen": 2}}},
                          {"action": "zielen", "expect": {"process": {"zielen": 2, "capped": true}}}]}
            """#)
        let run = StateRunner.run(wrong, engine: engine)
        XCTAssertEqual(kinds(run.mismatches), [.process, .process])
        XCTAssertEqual(run.mismatches.map(\.names), [["st-aim.A1"], ["st-aim.A1"]])
        XCTAssertTrue(run.mismatches[0].detail.hasPrefix("step 1: expected zielen at 2, got 1 of 2"))
        XCTAssertTrue(run.mismatches[1].detail.hasPrefix("step 2: expected zielen capped"))
    }

    /// Events the harness reads beyond `CombatRunner.events`: a `paid` of several `pools` (one
    /// cost's events, in order, summed), `over` some minutes (the step's payments summed), `after`
    /// (the pools the action leaves), and a `from` list (an event has one origin: never met).
    func testPaymentsInSeveralPoolsOverTimeAndAfter() {
        let vp3 = ref("SA_74.VP3"), zm5 = ref("zaubermodifikationen.ZM5")
        var after = Situation(owned: [:], facts: [])
        after.pools = [.asp: PoolState(current: 0, max: 30), .le: PoolState(current: 28, max: 29)]
        after.clock.minutes = 180
        let r = ActionResult(events: [Event(kind: .paid, origin: vp3, pool: .asp, amount: 3), Event(kind: .paid, origin: vp3, pool: .le, amount: 1),
                                      Event(kind: .paid, origin: zm5, pool: .asp, amount: 1), Event(kind: .paid, origin: zm5, pool: .asp, amount: 1),
                                      Event(kind: .paid, origin: zm5, pool: .asp, amount: 1)],
                             situation: after)
        let book = ProcessTests.state, engine = Engine(book: book)
        let before = Situation(owned: [:], facts: [])
        func json(_ text: String) -> [JSONValue] { try! JSONDecoder().decode([JSONValue].self, from: Data(text.utf8)) }
        XCTAssertEqual(StateRunner.events(json(#"""
            [{"paid": {"amount": 4, "pools": [{"asp": 3}, {"le": 1}]}, "from": "SA_74.VP3"},
             {"paid": {"pool": "asp", "amount": 3}, "over": {"minutes": 180}, "from": "zaubermodifikationen.ZM5"},
             {"after": {"aspCurrent": 0, "leCurrent": 28, "conditions": {}}}]
            """#), r, before: before, engine: engine), [])
        let wrong = StateRunner.events(json(#"""
            [{"paid": {"amount": 4, "pools": [{"le": 1}, {"asp": 3}]}, "from": "SA_74.VP3"},
             {"paid": {"pool": "asp", "amount": 3}, "over": {"minutes": 60}, "from": "zaubermodifikationen.ZM5"},
             {"after": {"leCurrent": 24}},
             {"paid": {"pool": "asp", "amount": 3}, "from": ["SA_74.VP3", "zaubermodifikationen.ZM12"]}]
            """#), r, before: before, engine: engine)
        XCTAssertEqual(kinds(wrong), [.missingEvent, .missingEvent, .missingEvent, .missingEvent])
        XCTAssertTrue(wrong[1].detail.contains("expected 60 minutes to pass, 180 passed"))
        XCTAssertTrue(wrong[3].detail.contains("an event has one origin"))
    }

    /// A step's `notApplied` is looked up in the step's own query breakdowns too (18.6's shape):
    /// the query is read first.
    func testAStepsNotAppliedSeesItsOwnQueries() throws {
        let engine = Engine(book: ProcessTests.state)
        let s = try situation(#"""
            {"base": {"fk": 10},
             "sequence": [{"choose": {"process.x": 1}, "expect": {"fk": {"result": 10}, "notApplied": [{"rule": "st-aim", "clause": "A1", "reason": "conditionFalse"}]}}]}
            """#)
        XCTAssertTrue(StateRunner.canRun(s))
        XCTAssertEqual(StateRunner.run(s, engine: engine).mismatches, [])
    }

    // MARK: - Task 30

    /// A step `event: { RULE: n }` states the Stufe the hero now has of the rule (kampfwerte
    /// 16.12: the plate taken off, Belastung 0), as the sheet's `level(rule: RULE)`.
    func testAStepEventStatesAStufe() throws {
        let engine = Engine(book: Self.book)
        let s = try situation(#"""
            {"owned": {"COND_1": {"level": 2}}, "base": {"at": 14},
             "sequence": [{"expect": {"at": {"total": -2}}},
                          {"event": {"COND_1": 0}, "expect": {"at": {"total": 0, "result": 14}}}]}
            """#)
        XCTAssertTrue(StateRunner.canRun(s))
        XCTAssertEqual(StateRunner.run(s, engine: engine).mismatches, [])
        let bad = try situation(#"{"sequence": [{"event": {"COND_1": "off"}}]}"#)
        XCTAssertEqual(StateRunner.run(bad, engine: engine).mismatches.compactMap(\.shape), ["step event"])
    }

    /// A step's query expectation holds the query keys (and `from`, Task 31) only: any other key is
    /// an unsupported shape (R42), never dropped; a line's `ruling` in a step (which rulec passes through) may be
    /// a string.
    func testAStepsQueryKeysAreChecked() throws {
        let engine = Engine(book: Self.book)
        let s = try situation(#"""
            {"owned": {"COND_1": {"level": 2}, "SA_41": {"level": 1}}, "base": {"at": 14},
             "sequence": [{"expect": {"at": {"result": 13, "from": "COND_1.B3", "kept": {"w6": 4},
                                              "lines": [{"from": "COND_1.B3", "value": -1, "ruling": "SA_41.table-shift"}]}}}]}
            """#)
        let run = StateRunner.run(s, engine: engine)
        // Task 31 fix round 1: `from` is compared (COND_1.B3 is a line of `at`); `kept` stays a shape.
        XCTAssertEqual(run.mismatches.compactMap(\.shape).sorted(), ["step query key kept"])
        XCTAssertEqual(run.mismatches.filter { $0.shape == nil }, [])
    }

    /// Bridge 6, Task 30: a clause ref `because` also names what made a `when` false through the
    /// level it reads: the useLevel first in the entry's `via` (lebensenergie 15.4: Schmerz I
    /// treated as none by ADV_49.ZH4).
    func testAClauseBecauseNamesTheUseLevelBehindAFalseCondition() {
        let level = [FactUse(name: "level", value: 0, owner: .sheet)]
        let entry = NotApplied(origin: ref("COND_6.SZ5"), reason: .conditionFalse, facts: level, via: [ref("ADV_49.ZH4")])
        XCTAssertTrue(Matcher.because("ADV_49.ZH4", entry))
        XCTAssertFalse(Matcher.because("ADV_49.ZH1", entry))
        XCTAssertFalse(Matcher.because("ADV_49.ZH4", NotApplied(origin: ref("COND_6.SZ5"), reason: .conditionFalse, facts: level)))
        // A `when` that read no level: the rule's `via` (an enabling require) is no reason for it.
        XCTAssertFalse(Matcher.because("ADV_49.ZH4", NotApplied(origin: ref("COND_6.SZ5"), reason: .conditionFalse,
                                                                via: [ref("ADV_49.ZH4")])))
    }

    /// Task 30 (R62): a situation-level `legal` says what the hero may do: `actions: none` (no
    /// action query, `at` and `fk`, is allowed), `defences: none` (neither `pa` nor `aw`), and
    /// `loadout: [...]` (each piece's `Engine.legality(ofLoadout:)`, with `allowed`, `because`,
    /// `ruling`). Any other key is an unsupported shape (Task 31 models `combinations`, `exclusive`
    /// and an `actions` object: MeleeHarnessTests).
    func testASituationLevelLegalIsCompared() throws {
        let refused = NotApplied(origin: ref("STATE_8.H2"), reason: .forbidden, because: "Handlungsunfähig")
        let no = Breakdown(query: Query("at"), legal: Legality(allowed: false, reasons: [refused]))
        let yes = Breakdown(query: Query("aw"))
        let armour = Legality(allowed: false, reasons: [NotApplied(origin: ref("r.A1"), reason: .forbidden, because: "eine Rüstung",
                                                                   rulings: ["r.one"])])
        let view = LegalView(actions: [no, no], defences: [no, yes],
                             loadout: [["armour": "Leder", "secondArmour": true]: armour])
        let s = try situation(#"""
            {"expectSituation": {"legal": {"actions": "none", "defences": "none",
                                           "loadout": [{"armour": "Leder", "secondArmour": true, "allowed": false, "because": "r.A1", "ruling": "one"}],
                                           "reach": []}}}
            """#)
        var c = MatchResult()
        Matcher.situationLevel(s, breakdowns: [], offers: [], offering: [:], legal: view, &c)
        XCTAssertEqual(kinds(c.mismatches), [.legal, .unsupportedShape])
        XCTAssertTrue(c.mismatches[0].detail.contains("defences"), c.mismatches[0].detail)
        XCTAssertEqual(c.mismatches[1].shape, "situation legal reach")
        let wrong = try situation(#"{"expectSituation": {"legal": {"loadout": [{"armour": "Leder", "secondArmour": true, "allowed": true}]}}}"#)
        var w = MatchResult()
        Matcher.situationLevel(wrong, breakdowns: [], offers: [], offering: [:], legal: view, &w)
        XCTAssertEqual(kinds(w.mismatches), [.legal])
    }

    /// Task 30: `base.technique` is the technique the value is for: a KtW the base read, else the
    /// technique the query is made with (either form).
    func testABasesTechnique() throws {
        var part = line(10, "kampfwerte.KW1", kind: .base)
        part.facts = [FactUse(name: "ktw.Schilde", value: 10, owner: .sheet)]
        let derived = Breakdown(query: Query("at"), base: Line(value: 12, kind: .base, origin: ref("kampfwerte.KW1"), parts: [part]))
        let want: JSONValue = .object(["value": 12, "technique": "Schilde"])
        XCTAssertEqual(Matcher.base(want, derived, query: "at"), [])
        let sheet = Breakdown(query: Query("pa(with: shield)"), base: sheetBase(12))
        XCTAssertEqual(Matcher.base(want, sheet, query: "pa(with: shield)", techniques: ["CT_10", "Schilde"]), [])
        XCTAssertEqual(kinds(Matcher.base(want, sheet, query: "pa(with: shield)", techniques: [])), [.base])
    }

    /// Task 30 (R62): a step's `offered` / `notOffered` is matched as a situation's, against the
    /// offers of the step's breakdowns; an offer's `default` is compared (belastung 4.5).
    func testAStepsOffersAndAnOffersDefault() throws {
        let c = OfferedChoice(choice: "belastungZaehlt", origin: ref("COND_1.B3"), default: false, rulings: ["COND_1.maybe"])
        XCTAssertEqual(Matcher.offerFailures(["default": false], c), [])
        XCTAssertEqual(Matcher.offerFailures(["default": true], c).count, 1)
        let engine = Engine(book: Self.book)
        let s = try situation(#"""
            {"sequence": [{"expect": {"offered": [{"choice": "nothingOffersThis"}]}}]}
            """#)
        XCTAssertEqual(kinds(StateRunner.run(s, engine: engine).mismatches), [.missingOffer])
    }

    /// Task 35 (R62, MIGRATION probe-magie 20.8): a cast step's `result {success, from, ruling}` is
    /// the spell check's result as the step states it: a failed roll fails the checks the cast
    /// asked (chk-pforte.VP2's Selbstbeherrschung), whose forbid fails the cast, named by it.
    func testACastStepsResultIsItsSpellCheck() throws {
        let engine = CheckProcedureTests.fixture
        let attributes = ["SPELL_1": ["KL", "IN", "CH"], "TAL_8": ["MU", "MU", "KO"]]
        func cast(_ owned: String, _ result: String) throws -> CompiledSituation {
            let facts = [("attr.KL", "12"), ("attr.IN", "14"), ("attr.CH", "11"), ("attr.MU", "13"), ("attr.KO", "13"),
                         ("fw.SPELL_1", "7"), ("fw.TAL_8", "5")].map { #"{"name": "\#($0.0)", "value": \#($0.1), "owner": "sheet"}"# }
                + [#"{"name": "check.kind", "value": "spell", "owner": "player"}"#,
                   #"{"name": "check.spell", "value": "SPELL_1", "owner": "player"}"#]
            return try situation(#"{"owned": {\#(owned)}, "base": {"spell.cost": 8}, "facts": [\#(facts.joined(separator: ", "))], "#
                + #""sequence": [{"rolls": {"check.result": "failure"}, "expect": {"result": \#(result)}}]}"#)
        }
        let pforte = #""chk-pforte": {"level": 1}"#
        XCTAssertEqual(StateRunner.run(try cast(pforte, #"{"success": false, "from": "chk-pforte.VP2", "ruling": "chk-pforte.sequence"}"#),
                                       engine: engine, attributes: attributes).mismatches, [])
        // Without the rule the roll alone fails the cast: no clause names the failure.
        let alone = StateRunner.run(try cast("", #"{"success": false, "from": "chk-pforte.VP2", "ruling": "chk-pforte.open"}"#),
                                    engine: engine, attributes: attributes).mismatches
        XCTAssertEqual(kinds(alone), [.checkResult])
        XCTAssertEqual(alone.first?.names, ["chk-pforte.VP2", "chk-pforte.open"])
        XCTAssertEqual(StateRunner.run(try cast("", #"{"success": false}"#), engine: engine, attributes: attributes).mismatches, [])
    }

    /// Ruling R64 (Task 30): a situation expecting `after` whose queries read what a `restore`
    /// restores (`regeneration.le`) implies taking the choice that restore is gated on
    /// (`.take(choice: regenerationsphase)`); `after` compares `levels` (the base of
    /// `level(rule: X)`) and `actsAs` (its result), and its `from` is an event's origin or `via`.
    func testARestoresChoiceIsTheImpliedActionOfAnAfter() throws {
        let book = try RuleBook.load(from: Bundle.module.url(forResource: "sheet-rules", withExtension: "json", subdirectory: "Fixtures")!)
        let engine = Engine(book: book)
        let s = try situation(#"""
            {"owned": {"sh-stun": {"level": 2}}, "base": {"leCurrent": 28, "leMax": 30},
             "facts": [{"name": "roll.regeneration", "value": 5, "owner": "roll"}, {"name": "attr.KO", "value": 15, "owner": "sheet"}],
             "expect": [{"query": "regeneration.le", "total": 5}],
             "expectSituation": {"events": [{"after": {"leCurrent": 30, "levels": {"sh-stun": 2}, "actsAs": {"sh-stun": 2}}, "from": "sh-rest.R5"}]}}
            """#)
        XCTAssertTrue(StateRunner.canRun(s, book: book))
        XCTAssertFalse(StateRunner.canRun(s), "without the book no restore is known")
        XCTAssertEqual(StateRunner.implied(s, book: book), .take(choice: "regenerationsphase"))
        XCTAssertEqual(StateRunner.run(s, engine: engine).mismatches, [])
        let wrong = try situation(#"""
            {"base": {"leCurrent": 20, "leMax": 30},
             "facts": [{"name": "roll.regeneration", "value": 5, "owner": "roll"}, {"name": "attr.KO", "value": 15, "owner": "sheet"}],
             "expect": [{"query": "regeneration.le", "total": 5}],
             "expectSituation": {"events": [{"after": {"leCurrent": 26, "actsAs": {"sh-stun": 1}}, "from": "sh-rest.R5"}]}}
            """#)
        XCTAssertEqual(StateRunner.run(wrong, engine: engine).mismatches.map(\.kind), [.missingEvent, .missingEvent, .missingEvent])
    }
}

