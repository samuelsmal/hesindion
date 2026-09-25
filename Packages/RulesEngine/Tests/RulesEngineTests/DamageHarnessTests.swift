import XCTest
@testable import RulesEngine

/// Task 32's harness bridges (R62): the shapes of the damage situations (trefferzonen) the
/// matcher now compares, on the fixture book `Fixtures/damage-rules.json`.
final class DamageHarnessTests: XCTestCase {
    private func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }

    private static let book: RuleBook = {
        let url = Bundle.module.url(forResource: "damage-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    private let engine = Engine(book: DamageHarnessTests.book)

    private func situation(_ fields: String) throws -> CompiledSituation {
        var object: [String: Any] = ["id": "T.1", "file": "test.yaml", "owned": [:], "facts": [], "base": [:], "rolls": [],
                                     "sequence": [], "expect": [], "expectSituation": [:], "pending": []]
        let given = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(fields.utf8)) as? [String: Any])
        object.merge(given) { _, new in new }
        return try JSONDecoder().decode(CompiledSituation.self, from: JSONSerialization.data(withJSONObject: object))
    }

    // MARK: - legal.combinations: the refused choices' offers

    /// A refused combination rests on the rulings of its refusing entries and, as a `notOffered`
    /// choice does, on those of its choices' offers (TZ.17: Gezielter Angriff's halving ruling).
    func testARefusedCombinationRestsOnItsChoicesOfferRulings() throws {
        let s = try situation(#"{"owned": {"dm-under": {"level": 1}, "dm-aim": {"level": 1}}, "expectSituation": {"legal": {"combinations": [{"choices": ["under", "aim"], "allowed": false, "because": "dm-under.U3", "ruling": "dm-aim.halving"}]}}}"#)
        XCTAssertEqual(Matcher.match(s, engine: engine), [])
        let other = try situation(#"{"owned": {"dm-under": {"level": 1}, "dm-aim": {"level": 1}}, "expectSituation": {"legal": {"combinations": [{"choices": ["under", "aim"], "allowed": false, "ruling": "dm-aim.other"}]}}}"#)
        XCTAssertEqual(Matcher.match(other, engine: engine).map(\.kind), [.legal])
    }

    // MARK: - notOffered because the rule set is off

    /// `because: <rule>.ruleset` names the `ruleset` of the offering clause's rule: an offer that
    /// is not there because that set is off has a `rulesetOff` entry on its offering clause (TZ.1).
    func testNotOfferedBecauseTheOfferingRulesRuleSetIsOff() {
        let off = NotApplied(origin: ref("dm-zones.Z9"), reason: .rulesetOff, because: "Regelset fokus.dm nicht aktiv")
        let entry = JSONValue.object(["choice": "zone", "because": "dm-zones.ruleset"])
        XCTAssertEqual(Matcher.offer(entry, wanted: false, in: [], notApplied: [off], offering: ["zone": [ref("dm-zones.Z9")]]), [])
        let other = JSONValue.object(["choice": "zone", "because": "dm-aim.ruleset"])
        XCTAssertEqual(Matcher.offer(other, wanted: false, in: [], notApplied: [off], offering: ["zone": [ref("dm-zones.Z9")]]).map(\.kind),
                       [.wrongOffer])
    }

    // MARK: - offered / notOffered: a rule set

    /// `{ ruleset, because, ruling }`: whether the rule set may be switched on
    /// (`Engine.legality(ofRuleset:)`), refused by `because` resting on `ruling` (TZ.25).
    func testARuleSetOfferIsItsLegality() throws {
        let facts = #""facts": [{"name": "rulesets", "value": ["fokus.dm2"], "owner": "gm"}]"#
        let refused = try situation(#"{\#(facts), "expectSituation": {"notOffered": [{"ruleset": "fokus.dm2", "because": "dm-rs.R1", "ruling": "dm-rs.needs"}]}}"#)
        XCTAssertEqual(Matcher.match(refused, engine: engine), [])
        let offered = try situation(#"{\#(facts), "expectSituation": {"offered": [{"ruleset": "fokus.dm2"}]}}"#)
        XCTAssertEqual(Matcher.match(offered, engine: engine).map(\.kind), [.missingOffer])
        let wrong = try situation(#"{\#(facts), "expectSituation": {"notOffered": [{"ruleset": "fokus.dm2", "because": "dm-rs.R9"}]}}"#)
        XCTAssertEqual(Matcher.match(wrong, engine: engine).map(\.kind), [.wrongOffer])
    }

    // MARK: - A hit's events

    /// `events: []` asserts that the action asks for no attack either (R42: never a silent pass).
    func testNoEventsCountsTheAttacksAsked() {
        let attack = PendingAttack(origin: ref("dm-aim.G1"), attack: "tritt", by: "mount", at: 12, tp: "1W6")
        XCTAssertEqual(CombatRunner.events([], events: [], checks: [], attacks: [attack]).map(\.kind), [.unexpectedEvent])
        XCTAssertEqual(CombatRunner.events([], events: [], checks: [], attacks: []), [])
    }

    /// `damage: { formula }` (TZ.12's 1W3+1 SP) is a damage event: the engine's are `damaged`
    /// with an amount, so one with a dice formula is missing, not an unsupported shape.
    func testADamageEventWithAFormulaIsCompared() {
        let damaged = Event(kind: .damaged, origin: ref("dm-zones.Z2"), pool: .le, amount: 4)
        let expected: [JSONValue] = [.object(["damage": .object(["formula": "1W3+1"]), "from": "dm-zones.Z2"])]
        XCTAssertEqual(CombatRunner.events(expected, events: [damaged], checks: []).map(\.kind), [.missingEvent])
    }

    /// `itemChanged: { <slot>: <item>, <field>: <value> }` (TZ.14: the Schwert let go) is the
    /// change of the instance in that slot, holding that item.
    func testAnItemChangedByItsSlotAndItem() {
        let s = Situation(owned: [:], facts: [Fact(name: "loadout.weapon", value: "Schwert", owner: .loadout),
                                              Fact(name: "loadout.weapon.instance", value: "s1", owner: .loadout)])
        let let_go = Event(kind: .itemChanged, origin: ref("dm-hand.H1"), item: "s1", change: ["held": .bool(false)], rulings: ["dm-hand.drop"])
        let expected: [JSONValue] = [.object(["itemChanged": .object(["weapon": "Schwert", "held": .bool(false)]), "from": "dm-hand.H1",
                                              "ruling": "dm-hand.drop"])]
        XCTAssertEqual(CombatRunner.events(expected, events: [let_go], checks: [], situation: s), [])
        var other = let_go
        other.item = "s2"
        XCTAssertEqual(CombatRunner.events(expected, events: [other], checks: [], situation: s).map(\.kind), [.missingEvent])
        XCTAssertEqual(CombatRunner.events(expected, events: [], checks: [], situation: s).map(\.kind), [.missingEvent])
    }

    // MARK: - Dice no action reads

    /// A situation that states only dice (TZ.9–TZ.11's zone dice, no check, no step, no
    /// expectation) is run: no action of the engine reads them, and the roll layer's questions say
    /// what the dice are for. That is a mismatch of the dice, never a silent pass.
    func testDiceNoActionReadsAreAMismatch() throws {
        let s = try situation(#"{"rolls": [2, 13]}"#)
        let judged = SituationsHarnessTests.judge(s, engine: engine, conflicts: [])
        XCTAssertEqual(judged.mismatches.map(\.kind), [.dice])
        XCTAssertEqual(judged.verdict, .failed)
        let listed = SituationsHarnessTests.judge(s, engine: engine, conflicts: [ConflictRef(file: "test.yaml", id: "T.1")])
        XCTAssertEqual(listed.verdict, .conflict)
    }

    // MARK: - A scaled line's was

    /// Bridge 5 (Task 32): a replaced line then scaled (TZ.4: the aiming −4 eased to −2, then
    /// halved to −1) is named with the value it had before either, the replaced line's `was`.
    func testAScaledReplacedLineWasItsOriginalValue() throws {
        let eased = Line(value: -2, kind: .replaced, origin: ref("x.TZ5"), via: [ref("x.TZ5")], was: -4, now: -2)
        let halved = Line(value: 1, kind: .multiplied, origin: ref("y.GA1"), via: [ref("x.TZ5")], was: -2, now: -1)
        let b = Breakdown(query: Query("at"), base: Line(value: 14, kind: .base), lines: [eased, halved])
        let expected = try JSONDecoder().decode([ExpectedLine].self, from: Data(#"[{"from": "x.TZ5", "value": -1, "was": -4, "via": ["y.GA1"]}]"#.utf8))
        XCTAssertEqual(Matcher.lines(expected, b, query: "at"), [])
        let plain = Line(value: -10, kind: .add, origin: ref("x.TZ5"))
        let halvedPlain = Line(value: 5, kind: .multiplied, origin: ref("y.GA1"), via: [ref("x.TZ5")], was: -10, now: -5)
        let c = Breakdown(query: Query("at"), base: Line(value: 14, kind: .base), lines: [plain, halvedPlain])
        let three = try JSONDecoder().decode([ExpectedLine].self, from: Data(#"[{"from": "x.TZ5", "value": -5, "was": -10, "via": ["y.GA1"]}]"#.utf8))
        XCTAssertEqual(Matcher.lines(three, c, query: "at"), [])
    }

    // MARK: - A stated base's total

    /// Bridge 2 (Task 32): a base the GM states (the opponent's RS 6) is stated, as the sheet's
    /// is: the situation's `total` is the lines after it (kupperus-und-waffen 18.5: −2).
    func testAGMStatedBaseDoesNotCountInTheTotal() throws {
        let b = Breakdown(query: Query("opponent.rs"), base: Line(value: 6, kind: .base, owner: .gm),
                          lines: [Line(value: -2, kind: .add, origin: ref("x.RS2"))])
        let q = try JSONDecoder().decode(QueryExpectation.self, from: Data(#"{"query": "opponent.rs", "total": -2, "result": 4}"#.utf8))
        var c = MatchResult()
        Matcher.query(q, b, &c)
        XCTAssertEqual(c.mismatches, [])
    }
}
