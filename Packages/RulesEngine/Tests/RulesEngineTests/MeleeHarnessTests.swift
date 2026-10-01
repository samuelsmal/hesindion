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

    // MARK: - R69: a listed conflict is a conflict only on a comparable mismatch

    func testAListedConflictThatCannotRunStaysUnsupported() throws {
        let s = try situation(#"{"expectSituation": {"events": [{"logged": "x", "from": "me-core.K3"}]}}"#)
        let listed = SituationsHarnessTests.judge(s, engine: engine, conflicts: [ConflictRef(file: "test.yaml", id: "T.1")])
        XCTAssertEqual(listed.verdict, .unsupported(["action: events"]))
        let shapes = [Mismatch.shape("term", "x")]
        XCTAssertEqual(Verdict.of(s, mismatches: shapes, hits: [], book: nil, conflicts: [ConflictRef(file: "test.yaml", id: "T.1")]),
                       .unsupported(["shape: term"]))
    }

    // MARK: - shapes compared as mismatches (R62)

    /// A structured text from a clause is compared with that clause's plain tell: it never
    /// matches, a real mismatch.
    func testAStructuredTextFromAClauseIsCompared() {
        let tell = TextLine(kind: .tell, audience: .gm, text: "Gleiche INI", origin: ref("x.GR3"))
        let m = Matcher.texts([.object(["order": "opponent acts first", "from": "x.GR3"])], in: [tell])
        XCTAssertEqual(m.map(\.kind), [.missingText])
        XCTAssertEqual(Matcher.texts([.object(["order": "first"])], in: [tell]).map(\.shape), ["text shape"])
    }

    /// An offered check is no choice: the rules ask checks, they do not offer them.
    func testAnOfferedCheckIsAMissingOffer() {
        let entry: JSONValue = .object(["check": .object(["talent": "Willenskraft"]), "cause": .object(["rule": "x.SE1"]), "ruling": "x.open"])
        let m = Matcher.offer(entry, wanted: true, in: [], notApplied: [], offering: [:])
        XCTAssertEqual(m.map(\.kind), [.missingOffer])
        XCTAssertTrue(m[0].names.contains("x.open"))
    }

    /// An expected check that is no talent check (the mount's attack) is compared by its clause.
    func testAnAttackCheckEventIsComparedByItsClause() {
        let m = CombatRunner.events([.object(["check": .object(["attack": "Niederreiten", "by": "mount"]), "from": "x.SK3"])],
                                    events: [], checks: [])
        XCTAssertEqual(m.map(\.kind), [.missingEvent])
    }

    /// `offered.on: takeDamage`: the offer is made on the take-damage screen, a hit's.
    func testOfferedOnTheTakeDamageScreen() {
        let o = offer("mountHit", "x.RK11")
        XCTAssertEqual(Matcher.offer(.object(["choice": "mountHit", "on": "takeDamage"]), wanted: true, in: [o], notApplied: [],
                                     offering: [:], screen: "takeDamage"), [])
        XCTAssertEqual(Matcher.offer(.object(["choice": "mountHit", "on": "takeDamage"]), wanted: true, in: [o], notApplied: [],
                                     offering: [:]).map(\.kind), [.wrongOffer])
    }

    /// `legal.via`: the firing entries' `via`.
    func testLegalViaIsTheFiringEntriesVia() {
        let actual = Legality(allowed: false, reasons: [NotApplied(origin: ref("g.GK4"), reason: .forbidden, via: [ref("s.SK7")])])
        XCTAssertEqual(Matcher.legal(.object(["allowed": false, "via": .array(["s.SK7"])]), actual, query: "opponent.pa"), [])
        XCTAssertEqual(Matcher.legal(.object(["allowed": false, "via": .array(["s.SK8"])]), actual, query: "opponent.pa").map(\.kind), [.legal])
    }

    /// A check the situation states with only its result (`rolls: { check.result: failure }`) runs
    /// as the check's outcome, and its events are compared.
    func testACheckWithAStatedResultRunsForItsEvents() throws {
        let s = try situation(#"{"facts": [{"name": "check.kind", "value": "talent", "owner": "player"}, {"name": "check.talent", "value": "TAL_23", "owner": "player"}, {"name": "check.result", "value": "failure", "owner": "roll"}], "expectSituation": {"events": [{"logged": "x", "from": "me-core.K3"}]}}"#)
        XCTAssertTrue(ActionRunner.canRun(s, attributes: ["TAL_23": ["MU", "IN", "CH"]]))
        let run = try XCTUnwrap(ActionRunner.run(s, engine: engine, attributes: ["TAL_23": ["MU", "IN", "CH"]]))
        XCTAssertEqual(run.mismatches.map(\.kind), [.missingEvent])
    }

    /// An `other: <item>` loadout entry states the piece's kind from data: a shield (its
    /// technique is the shield slot's) or a weapon of its technique, never the item's name.
    func testALoadoutEntryNamingTheOtherPieceStatesItsKind() {
        var s = Situation(owned: [:], facts: [Fact(name: "item.Holzschild.technique", value: "CT_10", owner: .loadout),
                                               Fact(name: "item.Dolch.technique", value: "CT_3", owner: .loadout)])
        s.facts["loadout.weapon"] = Fact(name: "loadout.weapon", value: "Morgenstern", owner: .loadout)
        let shield = LegalView.slotFacts(["loadout.other": "Holzschild"], in: s, book: Self.book)
        XCTAssertEqual(shield["loadout.other"], "shield")
        XCTAssertEqual(shield["loadout.shield"], "Holzschild")
        let dagger = LegalView.slotFacts(["loadout.other": "Dolch"], in: s, book: Self.book)
        XCTAssertEqual(dagger["loadout.other"], "weapon")
        XCTAssertEqual(dagger["loadout.other.technique"], "CT_3")
        XCTAssertEqual(LegalView.slotFacts(["loadout.other": "shield"], in: s, book: Self.book)["loadout.other"], "shield")
    }

    // MARK: - taking the choice the events come from

    func testTheImpliedActionIsTakingTheChoiceTheEventsAreGatedOn() throws {
        let s = try situation(#"{"facts": [{"name": "hero.mounted", "value": true, "owner": "loadout"}, {"name": "choice.order", "value": "flucht", "owner": "player"}], "expectSituation": {"events": [{"check": {"talent": "TAL_6", "with": "Kampfmanöver"}, "from": "me-rider.R12"}]}}"#)
        XCTAssertEqual(StateRunner.taking(s, book: Self.book), .take(choice: "order"))
        XCTAssertTrue(StateRunner.canRun(s, book: Self.book))
        let other = try situation(#"{"facts": [{"name": "choice.order", "value": "flucht", "owner": "player"}], "expectSituation": {"events": [{"check": {"talent": "TAL_6"}, "from": "me-core.K3"}]}}"#)
        XCTAssertNil(StateRunner.taking(other, book: Self.book))
        // Fix round 1: one event from a gated clause names the action; the others are compared.
        let mixed = try situation(#"{"facts": [{"name": "hero.mounted", "value": true, "owner": "loadout"}, {"name": "choice.order", "value": "flucht", "owner": "player"}], "expectSituation": {"events": [{"check": {"talent": "TAL_6"}, "from": "me-rider.R12"}, {"check": {"attack": "Tritt"}, "from": "me-core.K3"}]}}"#)
        XCTAssertEqual(StateRunner.taking(mixed, book: Self.book), .take(choice: "order"))
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

    /// A step query's `from` is compared with the clauses its base and lines come from.
    func testAStepQuerysFromIsCompared() {
        let b = Breakdown(query: Query("ini"), base: Line(value: 18, kind: .base, origin: ref("k.KW10")))
        var c = MatchResult()
        CombatRunner.compare(["ini": .object(["result": 18, "from": "k.KW11"])], label: "step 2", events: [], checks: [], texts: [],
                             notApplied: [], questions: [], success: nil, successQuery: nil, breakdown: { _ in b }, &c)
        XCTAssertEqual(c.mismatches.map(\.kind), [.base])
        var ok = MatchResult()
        CombatRunner.compare(["ini": .object(["result": 18, "from": "k.KW10"])], label: "step 2", events: [], checks: [], texts: [],
                             notApplied: [], questions: [], success: nil, successQuery: nil, breakdown: { _ in b }, &ok)
        XCTAssertEqual(ok.mismatches, [])
    }

    // MARK: - Fix round 2

    /// R72: an attack check event is compared with the attacks the action asks: name, who,
    /// AT, TP, origin, via and ruling.
    func testAnAttackCheckEventIsComparedWithTheAttacksAsked() {
        let tritt = PendingAttack(origin: ref("x.SK3"), attack: "Tritt", by: "mount", at: 15, tp: "1W6+7", rulings: ["x.own"],
                                  via: [ref("x.RK12")])
        let good: JSONValue = .object(["check": .object(["attack": "Tritt", "by": "mount", "at": 15, "tp": "1W6+7"]), "from": "x.SK3",
                                       "ruling": "x.own"])
        XCTAssertEqual(CombatRunner.events([good], events: [], checks: [], attacks: [tritt]), [])
        let wrong: JSONValue = .object(["check": .object(["attack": "Tritt", "by": "mount", "at": 16]), "from": "x.SK3"])
        XCTAssertEqual(CombatRunner.events([wrong], events: [], checks: [], attacks: [tritt]).map(\.kind), [.missingEvent])
    }

    /// A paid event's unmodelled field is a shape, and the rest (its ruling) is still compared.
    func testAPaidEventsExtraFieldDoesNotMaskItsRuling() {
        let paid = Event(kind: .paid, origin: ref("x.RK12"), pool: .actions, amount: 1, rulings: [])
        let r = ActionResult(events: [paid], situation: Situation(owned: [:], facts: []))
        var used = Set<Int>()
        let m = StateRunner.paid(["paid": .object(["pool": "actions", "amount": 1]), "instead_of": "x", "from": "x.RK12", "ruling": "x.own"],
                                 ["pool": "actions", "amount": 1], r, before: r.situation, &used)
        XCTAssertEqual(m.map(\.kind).sorted { $0.rawValue < $1.rawValue }, [.missingEvent, .unsupportedShape])
    }

    /// A malformed `legal.via` or `offered.on` is an unsupported shape.
    func testMalformedViaAndOnAreShapes() {
        let actual = Legality(allowed: false, reasons: [NotApplied(origin: ref("g.GK4"), reason: .forbidden)])
        XCTAssertEqual(Matcher.legal(.object(["allowed": false, "via": 3]), actual, query: "pa").map(\.shape), ["legal.malformed"])
        XCTAssertEqual(Matcher.offer(.object(["choice": "c", "on": 3]), wanted: true, in: [offer("c", "x.X1")], notApplied: [],
                                     offering: [:]).map(\.shape), ["malformed offer"])
    }

    /// A step stating only its check's result enters the outcome of the check the last action
    /// asked, and its texts (an `onFailure` tell) are compared.
    func testAStepStatingACheckResultEntersThePendingCheck() throws {
        let s = try situation(#"{"facts": [{"name": "hero.mounted", "value": true, "owner": "loadout"}, {"name": "choice.order", "value": "flucht", "owner": "player"}], "expectSituation": {"events": [{"check": {"talent": "TAL_6"}, "from": "me-rider.R12"}]}, "sequence": [{"rolls": {"check.result": "failure"}, "expect": {"texts": [{"player": "Der Befehl wird nicht ausgeführt.", "from": "me-rider.R12"}]}}]}"#)
        let run = StateRunner.run(s, engine: engine, attributes: ["TAL_6": ["MU", "GE", "KK"]])
        XCTAssertEqual(run.mismatches, [])
    }
}
