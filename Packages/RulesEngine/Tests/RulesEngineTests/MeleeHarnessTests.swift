import XCTest
@testable import RulesEngine

/// Task 31's harness bridges (R62): the shapes of the melee situations the matcher now compares.
final class MeleeHarnessTests: XCTestCase {
    private func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }

    private static let book: RuleBook = {
        let url = Bundle.module.url(forResource: "melee-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    private let engine = Engine(book: MeleeHarnessTests.book)

    private func situation(_ fields: String) throws -> CompiledSituation {
        var object: [String: Any] = ["id": "T.1", "file": "test.yaml", "owned": [:], "facts": [], "base": [:], "rolls": [],
                                     "sequence": [], "expect": [], "expectSituation": [:], "pending": []]
        let given = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(fields.utf8)) as? [String: Any])
        object.merge(given) { _, new in new }
        return try JSONDecoder().decode(CompiledSituation.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func offer(_ choice: String, _ origin: String, via: [String] = [], span: Span? = nil) -> OfferedChoice {
        OfferedChoice(choice: choice, origin: ref(origin), span: span, via: via.map(ref))
    }

    // MARK: - legal.span

    /// A firing entry that read `choice.X` lasts the span X's offer is made for.
    func testLegalSpanIsTheSpanOfTheChoiceTheFiringEntryRead() {
        let entry = NotApplied(origin: ref("x.V2"), reason: .forbidden,
                               facts: [FactUse(name: "choice.vorstoss", value: .bool(true), owner: .player)])
        let actual = Legality(allowed: false, reasons: [entry])
        let offers = [offer("vorstoss", "x.V3", span: .round)]
        XCTAssertEqual(Matcher.legal(.object(["allowed": false, "span": "round"]), actual, query: "pa", offers: offers), [])
        XCTAssertEqual(Matcher.legal(.object(["allowed": false, "span": "fight"]), actual, query: "pa", offers: offers).map(\.kind), [.legal])
    }

    // MARK: - offered: kind, from an enabler

    /// `kind` is the manoeuvre kind of the offering rule; `from` may name the require that enables
    /// the offer's rule (the first of its `via`), never another clause of its `via`.
    func testOfferedKindAndFromTheEnablingRequire() {
        let finte = offer("finte", "me-finte.F1")
        XCTAssertEqual(Matcher.offer(.object(["choice": "finte", "kind": "basismanoever"]), wanted: true, in: [finte], notApplied: [],
                                     offering: [:], book: Self.book), [])
        XCTAssertEqual(Matcher.offer(.object(["choice": "finte", "kind": "spezialmanoever"]), wanted: true, in: [finte], notApplied: [],
                                     offering: [:], book: Self.book).map(\.kind), [.wrongOffer])
        XCTAssertEqual(Matcher.offer(.object(["choice": "finte", "kind": "basismanoever"]), wanted: true, in: [finte], notApplied: [],
                                     offering: [:]).map(\.shape), ["offered field kind"])
        let enabled = offer("position", "me-position.P1", via: ["me-rider.R2"])
        XCTAssertEqual(Matcher.offer(.object(["choice": "position", "from": "me-rider.R2"]), wanted: true, in: [enabled],
                                     notApplied: [], offering: [:], book: Self.book), [])
        let levelled = offer("position", "me-position.P1", via: ["me-core.K3"])
        XCTAssertEqual(Matcher.offer(.object(["choice": "position", "from": "me-core.K3"]), wanted: true, in: [levelled],
                                     notApplied: [], offering: [:], book: Self.book).map(\.kind), [.missingOffer])
    }

    // MARK: - notOffered because its own when is no

    func testNotOfferedBecauseItsOwnConditionIsFalse() {
        let entry = NotApplied(origin: ref("x.V3"), reason: .conditionFalse)
        let offering = ["vorstoss": [ref("x.V3")]]
        XCTAssertEqual(Matcher.offer(.object(["choice": "vorstoss", "because": "x.V3"]), wanted: false, in: [], notApplied: [entry],
                                     offering: offering), [])
        XCTAssertEqual(Matcher.offer(.object(["choice": "vorstoss", "because": "x.V3"]), wanted: false, in: [], notApplied: [],
                                     offering: offering).map(\.shape), ["notOffered reason undecidable"])
    }

    // MARK: - legal: combinations and actions

    func testCombinationsAreComparedAgainstTheEngine() throws {
        let s = try situation(#"{"owned": {"me-finte": {"level": 1}, "me-wucht": {"level": 1}, "me-charge": {"level": 1}}, "expectSituation": {"legal": {"combinations": [{"choices": ["sturmangriff", "finte"], "allowed": false, "because": "me-charge.C4"}, {"choices": ["finte", "wuchtschlag"], "allowed": false, "because": "me-core.K3"}, {"choices": ["sturmangriff", "wuchtschlag"], "allowed": true}]}}}"#)
        XCTAssertEqual(Matcher.run(s, engine: engine).mismatches, [])
        let from = try situation(#"{"owned": {"me-finte": {"level": 1}, "me-charge": {"level": 1}}, "expectSituation": {"legal": {"combinations": [{"choices": ["sturmangriff", "finte"], "allowed": true, "from": "me-core.K3"}]}}}"#)
        XCTAssertEqual(Matcher.run(from, engine: engine).mismatches.map(\.kind), [.legal])
    }

    func testActionKindsForbiddenAllowedAndFreeActions() {
        let forbid = NotApplied(origin: ref("me-core.K3"), reason: .forbidden, rulings: ["x.free"])
        var view = LegalView()
        view.actionKinds = ["attack": [Breakdown(query: Query("at"), legal: Legality(allowed: false, reasons: [forbid]))], "freeAction": []]
        let o: [String: JSONValue] = ["attack": "forbidden", "freeAction": .object(["allowed": true, "ruling": "x.free"])]
        XCTAssertEqual(Matcher.actionKinds(o, view), [])
        view.freeActionForbids = [forbid]
        XCTAssertEqual(Matcher.actionKinds(o, view).map(\.kind), [.legal])
    }

    // MARK: - a situation-level notApplied the queries do not touch

    /// Looked up on the hero sheet (a `*` action effect whose `when` is no) and in the targets its
    /// clause reaches.
    func testANotAppliedEntryOutsideTheQueriesIsLookedUpWhereItsClauseActs() throws {
        let s = try situation(#"{"facts": [{"name": "loadout.weapon", "value": "Rabenschnabel", "owner": "loadout"}, {"name": "hero.mounted", "value": true, "owner": "loadout"}], "base": {"at": 14, "tp": 0}, "expect": [{"query": "at", "total": 2}], "expectSituation": {"notApplied": [{"rule": "me-weapon", "clause": "W4"}, {"rule": "me-weapon", "clause": "W3"}]}}"#)
        XCTAssertEqual(Matcher.run(s, engine: engine).mismatches, [])
    }

    // MARK: - a listed conflict the harness cannot run

    func testAListedConflictThatCannotRunIsAConflict() throws {
        let s = try situation(#"{"expectSituation": {"events": [{"logged": "x", "from": "me-core.K3"}]}}"#)
        let listed = SituationsHarnessTests.judge(s, engine: engine, conflicts: [ConflictRef(file: "test.yaml", id: "T.1")])
        XCTAssertEqual(listed.verdict, .conflict)
        let unlisted = SituationsHarnessTests.judge(s, engine: engine, conflicts: [])
        XCTAssertEqual(unlisted.verdict, .unsupported(["action: events"]))
    }

    // MARK: - taking the choice the events come from

    func testTheImpliedActionIsTakingTheChoiceTheEventsAreGatedOn() throws {
        let s = try situation(#"{"facts": [{"name": "hero.mounted", "value": true, "owner": "loadout"}, {"name": "choice.order", "value": "flucht", "owner": "player"}], "expectSituation": {"events": [{"check": {"talent": "TAL_6", "with": "Kampfmanöver"}, "from": "me-rider.R12"}]}}"#)
        XCTAssertEqual(StateRunner.taking(s, book: Self.book), .take(choice: "order"))
        XCTAssertTrue(StateRunner.canRun(s, book: Self.book))
        let other = try situation(#"{"facts": [{"name": "choice.order", "value": "flucht", "owner": "player"}], "expectSituation": {"events": [{"check": {"talent": "TAL_6"}, "from": "me-core.K3"}]}}"#)
        XCTAssertNil(StateRunner.taking(other, book: Self.book))
    }

    // MARK: - roll steps with a bare die, and their legal

    func testRollStepsTakeABareDie() throws {
        let s = try situation(#"{"sequence": [{"rolls": [1], "expect": {"success": true, "legal": {"confirm": false}}}]}"#)
        XCTAssertEqual(CombatRunner.rollSteps(s)?.map(\.die), [1])
        XCTAssertEqual(CombatRunner.rollLegal(.object(["confirm": false, "ruling": "x.dice"]), label: "step 1", confirmation: false,
                                              recorded: [NotApplied(origin: ref("x.PS4"), reason: .forbidden, rulings: ["x.dice"])],
                                              query: "at"), [])
        XCTAssertEqual(CombatRunner.rollLegal(.object(["confirm": false]), label: "step 1", confirmation: true, recorded: [], query: "at")
            .map(\.kind), [.legal])
    }

    // MARK: - a line's ruling as a step writes it

    func testALinesRulingMayBeUnqualified() {
        let line = Line(value: 5, kind: .add, origin: ref("x.ST2"), rulings: ["shared.round-up", "x.gs"])
        var e = try! JSONDecoder().decode(ExpectedLine.self, from: Data(#"{"from": "x.ST2", "ruling": ["gs", "round-up"]}"#.utf8))
        XCTAssertEqual(Matcher.failures(e, line), [])
        e.ruling = ["x.other"]
        XCTAssertEqual(Matcher.failures(e, line), [.wrongRuling])
    }

    // MARK: - R48 through a clause the mismatch names

    /// A mismatch naming a clause is explained by an open ruling on the operand chain of the
    /// targets that clause's effects read (the Wundeffekt check TZ8 reads the Wundschwelle, on
    /// which Eisern rests on an open ruling).
    func testAnOpenRulingOnTheOperandChainOfANamedClauseExplains() {
        let hit = OpenHit(ruling: "me-iron.scope", origin: ref("me-iron.E1"))
        let s = Situation(owned: ["me-iron": OwnedRule()], facts: [])
        let named = Mismatch(kind: .unexpectedEvent, detail: "x", names: ["me-core.W8"])
        XCTAssertTrue(Explainer.explains(hit, named, book: Self.book, situation: s))
        let other = Mismatch(kind: .unexpectedEvent, detail: "x", names: ["me-core.K3"])
        XCTAssertFalse(Explainer.explains(hit, other, book: Self.book, situation: s))
    }

    // MARK: - legal.exclusive, and a combination's open rulings

    /// `exclusive: [{ choices, ruling }]`: the choices may not be taken together, resting on the
    /// ruling. A forbid on an open ruling refuses nothing, and its ruling is met (for R32).
    func testExclusiveChoicesAndTheOpenRulingsOfACombination() {
        let s = Situation(owned: ["me-line": OwnedRule()], facts: [])
        let b = engine.evaluation(s).combinationBreakdown(["line", "skirmish"])
        XCTAssertTrue(b.legal.allowed)
        XCTAssertEqual(Set(Matcher.openRulings(in: [b]).map(\.ruling)), ["me-line.both"])
        var view = LegalView()
        view.combinations[["line", "skirmish"]] = b.legal
        let exclusive: JSONValue = .object(["exclusive": .array([.object(["choices": .array(["line", "skirmish"]), "ruling": "both"])])])
        let m = Matcher.situationLegal(exclusive, view)
        XCTAssertEqual(m.map(\.kind), [.legal])
        XCTAssertEqual(m.first?.names, ["both"])
    }

    /// A prose `reason` that names a ruling ("… (ruling formation-and-plaenkler)") names it for R41.
    func testAProseReasonNamesTheRulingItCites() {
        let e = ExpectedNotApplied(rule: "SA_884", reason: "in Formation instead (ruling formation-and-plaenkler)")
        XCTAssertTrue(Matcher.names(e).contains("formation-and-plaenkler"))
        let hit = OpenHit(ruling: "me-line.both", origin: ref("me-line.L1"))
        let m = Mismatch(kind: .missingNotApplied, detail: "x", names: ["SA_884", "both"])
        XCTAssertTrue(Explainer.explains(hit, m, book: Self.book, situation: Situation(owned: ["me-line": OwnedRule()], facts: [])))
    }
}
