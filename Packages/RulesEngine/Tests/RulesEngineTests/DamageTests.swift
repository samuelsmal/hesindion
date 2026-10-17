import XCTest
@testable import RulesEngine

/// Task 32, the damage domain (trefferzonen, trefferzonen-ruestungsschutz), on the fixture book
/// `Fixtures/damage-rules.json` (source: `Tests/FixtureRules/damage`, rebuilt by
/// `make rules-engine-fixture`).
final class DamageTests: XCTestCase {
    private static let book: RuleBook = {
        let url = Bundle.module.url(forResource: "damage-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    private let engine = Engine(book: DamageTests.book)

    private func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }

    private func situation(owned: [String: Int] = [:], facts: [String: JSONValue] = [:],
                           base: [String: Int] = [:]) -> Situation {
        Situation(owned: owned.mapValues { OwnedRule(level: $0) },
                  facts: facts.sorted { $0.key < $1.key }.map {
                      Fact(name: $0.key, value: $0.value, owner: Vocabulary.owner(ofFact: $0.key) ?? .sheet)
                  }, base: base)
    }

    // MARK: - The piece worn in a zone

    func testAZonesRSIsTheRSOfThePieceWornThereFromTheArmourRows() throws {
        let b = engine.evaluate(Query("rs(zone: kopf)"), in: situation(facts: ["loadout.armourPiece.kopf": "Platte"]))
        XCTAssertEqual(b.result, 6)
        let base = try XCTUnwrap(b.base)
        XCTAssertEqual(base.origin, ref("dm-zones.Z2"))
        XCTAssertTrue(base.via.contains(ref("dm-zones.Z1")), "the armour rows' clause is behind the value")
        XCTAssertTrue(base.facts.contains { $0.name == "loadout.armourPiece.kopf" && $0.value == "Platte" })
        XCTAssertEqual(b.questions.map(\.fact), [])
    }

    func testAZoneWithoutAPieceHasRS0() {
        let b = engine.evaluate(Query("rs(zone: kopf)"), in: situation(facts: ["loadout.armourPiece.kopf": .null]))
        XCTAssertEqual(b.result, 0)
    }

    func testAnUnstatedPieceIsAsked() {
        let b = engine.evaluate(Query("rs(zone: kopf)"), in: situation())
        XCTAssertNil(b.result)
        XCTAssertEqual(b.questions.map(\.fact), ["loadout.armourPiece.kopf"])
    }

    func testAStatedItemFieldWinsOverTheArmourRows() {
        let b = engine.evaluate(Query("rs(zone: kopf)"),
                                in: situation(facts: ["loadout.armourPiece.kopf": "Platte", "item.Platte.rs": 5]))
        XCTAssertEqual(b.result, 5)
    }

    func testTheArmoursRowGivesAnUnstatedSlotField() {
        let b = engine.evaluate(Query("ini"), in: situation(facts: ["loadout.armour": "Leder"]))
        XCTAssertEqual(b.result, 1)
        XCTAssertTrue(b.base?.via.contains(ref("dm-zones.Z1")) ?? false)
    }

    // MARK: - An owned rule of a rule set that is off

    func testAnOwnedRuleOfARuleSetThatIsOffDoesNothingAndSaysWhy() throws {
        let off = engine.evaluate(Query("at"), in: situation(owned: ["dm-fokus": 1], base: ["at": 14]))
        XCTAssertEqual(off.result, 14)
        let entry = try XCTUnwrap(off.notApplied.first { $0.origin == ref("dm-fokus.F1") })
        XCTAssertEqual(entry.reason, .rulesetOff)
        let on = engine.evaluate(Query("at"), in: situation(owned: ["dm-fokus": 1], facts: ["rulesets": .array(["fokus.dm"])], base: ["at": 14]))
        XCTAssertEqual(on.result, 13)
        let state = engine.evaluate(Query("at"), in: situation(owned: ["dm-state": 1], base: ["at": 14]))
        XCTAssertEqual(state.result, 12, "the rule set core is always on")
    }

    // MARK: - Whether a rule set may be switched on

    func testARuleSetWhoseRuleLevelRequireIsNotMetIsNotOffered() throws {
        let alone = engine.legality(ofRuleset: "fokus.dm2", in: situation(facts: ["rulesets": .array(["fokus.dm2"])]))
        XCTAssertFalse(alone.allowed)
        let reason = try XCTUnwrap(alone.reasons.first)
        XCTAssertEqual(reason.origin, ref("dm-rs.R1"))
        XCTAssertEqual(reason.reason, .requirementNotMet)
        XCTAssertEqual(reason.rulings, ["dm-rs.needs"])
        XCTAssertTrue(engine.legality(ofRuleset: "fokus.dm2", in: situation(facts: ["rulesets": .array(["fokus.dm", "fokus.dm2"])])).allowed)
        XCTAssertTrue(engine.legality(ofRuleset: "fokus.dm", in: situation()).allowed, "no rule of it requires anything")
    }

    // MARK: - What the hit hand holds

    func testTheHitHandHoldsWhatTheLoadoutPutsInIt() throws {
        func at(_ facts: [String: JSONValue]) -> Breakdown {
            engine.evaluate(Query("at"), in: situation(facts: facts, base: ["at": 14]))
        }
        let loadout: [String: JSONValue] = ["loadout.weapon": "Schwert", "loadout.shield": "Schild", "loadout.other": "shield",
                                            "loadout.weaponHand": "rechts"]
        let right = at(loadout.merging(["hit.side": "rechts"]) { a, _ in a })
        XCTAssertEqual(right.result, 13)
        let held = try XCTUnwrap(right.lines.first?.facts.first { $0.name == "hit.heldInHand" })
        XCTAssertEqual(held.value, "weapon")
        XCTAssertEqual(held.owner, .derived)
        XCTAssertEqual(at(loadout.merging(["hit.side": "links"]) { a, _ in a }).result, 12, "the shield hand")
        var dagger = loadout
        dagger["loadout.other"] = "parryingWeapon"
        XCTAssertEqual(at(dagger.merging(["hit.side": "links"]) { a, _ in a }).result, 11, "a Parierwaffe is another object")
        var empty = loadout
        empty["loadout.other"] = .null
        XCTAssertEqual(at(empty.merging(["hit.side": "links"]) { a, _ in a }).result, 14, "an empty hand holds nothing")
        var unsaid = loadout
        unsaid["loadout.weaponHand"] = nil
        let asked = at(unsaid.merging(["hit.side": "links"]) { a, _ in a })
        XCTAssertEqual(asked.result, 14)
        XCTAssertEqual(asked.questions.map(\.fact), ["loadout.weaponHand"], "which hand holds the weapon is asked")
    }

    // MARK: - A replace acts on lines

    /// A replace naming a clause replaces its lines only: on a query no line of that clause
    /// reaches (the clause's offer does, a `*` effect), it is not read and asks nothing.
    func testAReplaceOfAClauseAsksNothingWhereNoLineOfItIs() {
        let s = situation(facts: ["choice.zone": "kopf", "attr.KK": 14], base: ["at": 14, "ini": 10])
        XCTAssertEqual(engine.evaluate(Query("ini"), in: s).questions.map(\.fact), [])
        let at = engine.evaluate(Query("at"), in: s)
        XCTAssertEqual(at.result, 10)
        XCTAssertTrue(at.questions.contains { $0.fact == "opponent.has" }, "where the line is, the replace's condition is asked")
    }

    // MARK: - Nothing above a threshold

    /// An `add` per point above a threshold (schaden.S3's Schadensbonus) with nothing above it
    /// gives no line: its condition ("mehr Punkte … als die Schadensschwelle") is not met.
    func testAnAddWithNothingAboveItsThresholdIsNotApplied() throws {
        let at14 = engine.evaluate(Query("tp"), in: situation(facts: ["attr.KK": 14], base: ["tp": 5]))
        XCTAssertEqual(at14.lines.filter { $0.origin == ref("dm-bonus.B1") }, [])
        let entry = try XCTUnwrap(at14.notApplied.first { $0.origin == ref("dm-bonus.B1") })
        XCTAssertEqual(entry.reason, .conditionFalse)
        XCTAssertTrue(entry.facts.contains { $0.name == "attr.KK" && $0.value == 14 })
        let at16 = engine.evaluate(Query("tp"), in: situation(facts: ["attr.KK": 16], base: ["tp": 5]))
        XCTAssertEqual(at16.lines.first { $0.origin == ref("dm-bonus.B1") }?.value, 2)
    }

    /// Fix round 1: "nothing above" is the value not above the threshold, not a line of 0: one
    /// point above, rounded down per two, is a line of 0, not a condition unmet.
    func testAPointAboveTheThresholdRoundedToZeroIsStillALine() {
        let b = engine.evaluate(Query("ini"), in: situation(facts: ["attr.KK": 15], base: ["ini": 10]))
        XCTAssertEqual(b.lines.filter { $0.origin == ref("dm-bonus.B2") }.map(\.value), [0])
        XCTAssertNil(b.notApplied.first { $0.origin == ref("dm-bonus.B2") && $0.reason == .conditionFalse })
        let at14 = engine.evaluate(Query("ini"), in: situation(facts: ["attr.KK": 14], base: ["ini": 10]))
        XCTAssertEqual(at14.notApplied.first { $0.origin == ref("dm-bonus.B2") }?.reason, .conditionFalse)
    }

    // MARK: - The opponent's values

    /// The GM states the opponent's values (`opponent: { rs: 6 }`): the base of the opponent's
    /// target (`opponent.rs`), as the sheet's is the hero's.
    func testTheOpponentsStatedValueIsTheBaseOfItsTarget() throws {
        let b = engine.evaluate(Query("opponent.rs"), in: situation(facts: ["opponent.rs": 6]))
        XCTAssertEqual(b.result, 6)
        let base = try XCTUnwrap(b.base)
        XCTAssertEqual(base.owner, .gm)
        XCTAssertEqual(base.facts.map(\.name), ["opponent.rs"])
        XCTAssertNil(engine.evaluate(Query("opponent.rs"), in: situation()).result)
    }

    // MARK: - A set without a base

    /// A `set` fixes the value whatever was before it: without a base (the sheet states no RS
    /// under Trefferzonen-Rüstungsschutz, RS2 sets it to the zone's) its value is the result.
    func testASetWithoutABaseGivesTheResult() {
        XCTAssertEqual(engine.evaluate(Query("gs"), in: situation()).result, 3)
        XCTAssertEqual(engine.evaluate(Query("gs"), in: situation(base: ["gs": 8])).result, 3)
    }

    /// Fix round 1: a suppress is read only where an effect it names would act: on a query where
    /// the named clause's ask is gated off, the suppress's condition is not asked.
    func testASuppressIsNotReadWhereWhatItNamesIsGatedOff() {
        let s = situation(facts: ["attr.KK": 14], base: ["ini": 10, "gs": 8])
        XCTAssertFalse(engine.evaluate(Query("ini"), in: s).questions.contains { $0.fact == "choice.sturm" })
        let gs = engine.evaluate(Query("gs"), in: s).questions.map(\.fact)
        XCTAssertTrue(gs.contains("choice.sturm") && gs.contains("choice.lager"), "\(gs)")
    }

    // MARK: - A combination a together forbid refuses

    func testAChoiceATogetherForbidRefusesBesideItsHoldersIsNotTaken() {
        let s = situation(owned: ["dm-under": 1, "dm-aim": 1], facts: ["choice.under": true, "choice.aim": true], base: ["at": 14])
        let b = engine.evaluate(Query("at"), in: s)
        XCTAssertEqual(b.lines.map(\.origin), [ref("dm-under.U1")], "the Spezialmanöver beside Unterlaufen is not taken")
        XCTAssertEqual(b.result, 15)
        let alone = engine.evaluate(Query("at"), in: situation(owned: ["dm-aim": 1], facts: ["choice.aim": true], base: ["at": 14]))
        XCTAssertEqual(alone.result, 12)
    }

    func testAnItemNoRowNamesAsksForTheField() {
        let b = engine.evaluate(Query("rs(zone: kopf)"), in: situation(facts: ["loadout.armourPiece.kopf": "Mithril"]))
        XCTAssertNil(b.result)
        XCTAssertEqual(b.questions.map(\.fact), ["loadout.armourPiece.kopf.rs"])
    }
}
