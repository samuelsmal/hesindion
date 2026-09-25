import XCTest
@testable import RulesEngine

/// The consequence chain of a hit (spec §6, plan Task 27): TP → RS → SP → the Wundschwelle
/// comparison → the Wundeffekt check, each a target with its own lines. The numbers are
/// kampfwerte 16.17–16.20, trefferzonen TZ.12–TZ.14 and boronmir-neu 19.6–19.8.
///
/// Three books, all built from the real `build/rules/rules.json`:
/// - the real one, where ADV_54.E1 (Eisern) rests on the open ruling eisern-scope and so adds
///   nothing;
/// - `eisern`: the same book with eisern-scope decided, for the numbers 19.6–19.8 state
///   (Wundschwelle 9);
/// - `minusOne`: the same book with schaden.S1's `sp` derive given a third term, −1: the chain
///   must give one SP less, since it does no arithmetic of its own.
final class DamageChainTests: XCTestCase {
    static let json: Data? = try? Data(contentsOf: Repo.url("build/rules/rules.json"))
    static let real: Engine? = json.flatMap { try? RuleBook.decode($0) }.map(Engine.init)
    static let eisern: Engine? = json.flatMap { try? patched($0, decide: "ADV_54.eisern-scope") }.map(Engine.init)
    static let minusOne: Engine? = json.flatMap { try? patched($0, spMinusOne: true) }.map(Engine.init)

    private func engine(_ e: Engine?) throws -> Engine { try XCTUnwrap(e, "run make rules-json") }
    private func ref(_ s: String) -> ClauseRef { ClauseRef(s)! }

    /// The book with one ruling decided, or with schaden.S1's derive to `sp` given a third term
    /// `{ of: 1, times: -1 }` (tp − rs − 1). The reach index is untouched: S1 reaches `sp` either way.
    static func patched(_ data: Data, decide ruling: String? = nil, spMinusOne: Bool = false) throws -> RuleBook {
        var root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        if let ruling, var rulings = root["rulings"] as? [[String: Any]] {
            for i in rulings.indices where rulings[i]["id"] as? String == ruling { rulings[i]["status"] = "decided" }
            root["rulings"] = rulings
        }
        if spMinusOne, var rules = root["rules"] as? [[String: Any]],
           let r = rules.firstIndex(where: { $0["id"] as? String == "schaden" }),
           var clauses = rules[r]["clauses"] as? [[String: Any]],
           let c = clauses.firstIndex(where: { $0["id"] as? String == "S1" }),
           var effects = clauses[c]["effects"] as? [[String: Any]],
           var payload = effects[0]["payload"] as? [String: Any], var sum = payload["sum"] as? [Any] {
            sum.append(["proportion": ["above": 0, "max": NSNull(), "min": NSNull(), "of": ["number": 1],
                                       "per": ["number": 1], "round": "up", "times": -1]])
            payload["sum"] = sum
            effects[0]["payload"] = payload
            clauses[c]["effects"] = effects
            rules[r]["clauses"] = clauses
            root["rules"] = rules
        }
        return try RuleBook.decode(try JSONSerialization.data(withJSONObject: root))
    }

    /// A hero with KO `ko`, the rule sets `rulesets`, the sheet's `base` and what else is stated.
    private func hero(ko: Int = 15, rulesets: [String] = ["fokus.trefferzonen"], base: [String: Int] = [:],
                      owned: [String: OwnedRule] = [:], facts: [String: JSONValue] = [:], le: Int? = nil) -> Situation {
        var all: [String: JSONValue] = ["attr.KO": .int(ko), "attr.MU": 14, "attr.CH": 13, "attr.GE": 14, "attr.KK": 14,
                                        "fw.TAL_8": 9, "fw.TAL_6": 12,
                                        "rulesets": .array(rulesets.map { .string($0) })]
        for (k, v) in facts { all[k] = v }
        return Situation(owned: owned,
                         facts: all.map { Fact(name: $0.key, value: $0.value, owner: Vocabulary.owner(ofFact: $0.key) ?? .sheet) },
                         base: base, pools: le.map { [.le: PoolState(current: $0, max: 37)] } ?? [:])
    }

    private let boronmir = ["ADV_54": OwnedRule(level: 1)]
    private let selbstbeherrschung = ["MU", "MU", "KO"]

    // MARK: - TP → RS → SP

    /// kampfwerte 16.17: 9 TP against RS 6 give 3 SP, each stage a breakdown with its lines: the
    /// TP the hit's input, RS the sheet's, SP schaden.S1's derive (TP, then −RS). The LE after the
    /// hit is schaden.S2's line (37 − 3).
    func testTheChainEvaluatesTPThenRSThenSPEachWithItsOwnLines() throws {
        let engine = try engine(Self.real)
        let r = DamageChain.run(hit: 9, in: hero(rulesets: [], base: ["rs": 6], le: 37), engine: engine)
        XCTAssertEqual(r.tp?.result, 9)
        XCTAssertEqual(r.tp?.base?.facts.map(\.name), ["hit.tp"])
        XCTAssertEqual(r.tp?.base?.owner, .roll)
        XCTAssertEqual(r.rs.query.description, "rs")
        XCTAssertEqual(r.rs.result, 6)
        XCTAssertEqual(r.sp.query.description, "sp")
        XCTAssertEqual(r.sp.result, 3)
        XCTAssertEqual(r.sp.shownLines.map(\.origin), [ref("schaden.S1"), ref("schaden.S1")])
        XCTAssertEqual(r.sp.shownLines.map(\.value), [9, -6])
        XCTAssertEqual(r.leCurrent.result, 34)
        XCTAssertEqual(r.leCurrent.lines.map(\.origin), [ref("schaden.S2")])
        XCTAssertEqual(r.leCurrent.lines.map(\.value), [-3])
        // The derived facts the chain states for the rules that read the hit.
        XCTAssertEqual(r.situation.facts["hit.tp"]?.value, 9)
        XCTAssertEqual(r.situation.facts["hit.sp"]?.value, 3)
        XCTAssertEqual(r.situation.facts["hit.sp"]?.owner, .derived)
        XCTAssertEqual(r.breakdowns.map(\.query.description), ["hit.tp", "rs", "sp", "wundschwelle", "leCurrent"])
    }

    /// kampfwerte 16.18: 5 TP against RS 6 are 0 SP, by S1's own floor (a `.floored` line), and the
    /// LE stays.
    func testFewerTPThanRSAreZeroSPByTheRulesFloor() throws {
        let engine = try engine(Self.real)
        let r = DamageChain.run(hit: 5, in: hero(rulesets: [], base: ["rs": 6], le: 37), engine: engine)
        XCTAssertEqual(r.sp.result, 0)
        XCTAssertEqual(r.sp.lines.map(\.kind), [.floored])
        XCTAssertEqual(r.sp.lines.map(\.origin), [ref("schaden.S1")])
        XCTAssertEqual(r.leCurrent.result, 37)
    }

    /// kampfwerte 16.19: a spell ignoring armour (schaden.S5): the SP are the TP.
    func testIgnoringRSMakesTheSPTheTP() throws {
        let engine = try engine(Self.real)
        let r = DamageChain.run(hit: 7, in: hero(rulesets: [], base: ["rs": 6], facts: ["choice.ignoresRS": true], le: 37),
                                engine: engine)
        XCTAssertEqual(r.sp.result, 7)
        XCTAssertEqual(r.leCurrent.result, 30)
    }

    /// The chain does no arithmetic of its own: with S1's derive `tp − rs − 1` the same hit gives
    /// one SP less, and the third term is a line of its own.
    func testTheChainDoesNoArithmeticOfItsOwn() throws {
        let real = try engine(Self.real), fixture = try engine(Self.minusOne)
        let s = hero(rulesets: [], base: ["rs": 6], le: 37)
        let a = DamageChain.run(hit: 9, in: s, engine: real), b = DamageChain.run(hit: 9, in: s, engine: fixture)
        XCTAssertEqual(a.sp.result, 3)
        XCTAssertEqual(b.sp.result, 2)
        XCTAssertEqual(b.sp.shownLines.map(\.value), [9, -6, -1])
        XCTAssertEqual(b.situation.facts["hit.sp"]?.value, 2)
        XCTAssertEqual(b.leCurrent.result, 35)
    }

    // MARK: - The Wundschwelle and the Wundeffekt check

    /// boronmir-neu 19.6/19.7: Wundschwelle 9 (⌈KO 15 / 2⌉ = 8 from trefferzonen.TZ8, Eisern +1).
    /// 8 SP are no whole Wundschwelle: no Wundeffekt check, and TZ8's check is `conditionFalse`.
    func testBoronmirWithEisernTakesEightSPWithoutAWundeffekt() throws {
        let engine = try engine(Self.eisern)
        let r = DamageChain.run(hit: nil, zone: "torso", in: hero(base: ["sp": 8], owned: boronmir), engine: engine)
        XCTAssertEqual(r.wundschwelle.result, 9)
        XCTAssertEqual(r.wundschwelle.shownLines.map(\.origin), [ref("trefferzonen.TZ8"), ref("ADV_54.E1")])
        XCTAssertEqual(r.wundschwelle.shownLines.map(\.value), [8, 1])
        XCTAssertEqual(r.situation.facts["hit.sp"]?.value, 8)
        XCTAssertEqual(r.situation.facts["hit.overWundschwelle"]?.value, 0)
        XCTAssertEqual(r.checks, [])
        let tz8 = r.notApplied.filter { $0.origin == ref("trefferzonen.TZ8") }
        XCTAssertEqual(tz8.map(\.reason), [.conditionFalse])
        XCTAssertEqual(tz8.first?.facts.map(\.name), ["hit.overWundschwelle"])
    }

    /// boronmir-neu 19.8: 17 SP are one multiple of 9, not two of 8. The check is TZ8's
    /// Selbstbeherrschung (TAL_8), its application TZ11's for the torso, its failure the zone's
    /// Wundeffekt; started, its modifier is TZ8's −1, with Eisern in `via` (R26).
    func testSeventeenSPAreOneMultipleOfNine() throws {
        let engine = try engine(Self.eisern)
        let r = DamageChain.run(hit: nil, zone: "torso", in: hero(base: ["sp": 17], owned: boronmir), engine: engine)
        XCTAssertEqual(r.situation.facts["hit.overWundschwelle"]?.value, 1)
        let check = try XCTUnwrap(r.checks.first)
        XCTAssertEqual(r.checks.count, 1)
        XCTAssertEqual(check.origin, ref("trefferzonen.TZ8"))
        XCTAssertEqual(check.kind, .talent)
        XCTAssertEqual(check.id, "TAL_8")
        XCTAssertEqual(check.application, "Handlungsfähigkeit bewahren")
        XCTAssertEqual(check.onFailure.map(\.payload.verb), [.gain, .item, .item, .tell])
        let start = CheckProcedure.start(check.request(attributes: selbstbeherrschung), in: check.situation, engine: engine)
        let modifier = start.state.stages.modifier
        XCTAssertEqual(modifier.query.description, "check.modifier(talent: TAL_8)")
        let tz8 = modifier.lines.filter { $0.origin == ref("trefferzonen.TZ8") }
        XCTAssertEqual(tz8.map(\.value), [-1])
        XCTAssertEqual(tz8.first?.via, [ref("trefferzonen.TZ8"), ref("ADV_54.E1")])     // the Wundschwelle's clauses
        // Each attribute of the check carries the modifier's line (fertigkeitsproben.FM1).
        XCTAssertEqual(start.state.stages.attributes.map { $0.lines.filter { $0.origin == ref("trefferzonen.TZ8") }.count }, [1, 1, 1])
    }

    /// On the real book Eisern rests on the open ruling eisern-scope: it adds nothing (the
    /// clause and the ruling's question are shown), so the Wundschwelle is 8 and 8 SP are one.
    func testOnTheRealBookEisernRestsOnItsOpenRuling() throws {
        let engine = try engine(Self.real)
        let r = DamageChain.run(hit: nil, zone: "torso", in: hero(base: ["sp": 8], owned: boronmir), engine: engine)
        XCTAssertEqual(r.wundschwelle.result, 8)
        XCTAssertTrue(r.wundschwelle.texts.contains { $0.kind == .openRuling && $0.ruling == "ADV_54.eisern-scope" })
        XCTAssertEqual(r.situation.facts["hit.overWundschwelle"]?.value, 1)
        XCTAssertEqual(r.checks.map(\.origin), [ref("trefferzonen.TZ8")])
    }

    /// trefferzonen TZ.12: 12 SP on the torso at Wundschwelle 6 (the sheet's) are two multiples:
    /// −2 on the check.
    func testTwelveSPAreTwiceTheWundschwelle() throws {
        let engine = try engine(Self.real)
        let s = hero(ko: 11, base: ["sp": 12, "wundschwelle": 6])
        let r = DamageChain.run(hit: nil, zone: "torso", in: s, engine: engine)
        XCTAssertEqual(r.wundschwelle.result, 6)
        XCTAssertEqual(r.situation.facts["hit.overWundschwelle"]?.value, 2)
        let check = try XCTUnwrap(r.checks.first)
        let start = CheckProcedure.start(check.request(attributes: selbstbeherrschung), in: check.situation, engine: engine)
        XCTAssertEqual(start.state.stages.modifier.lines.filter { $0.origin == ref("trefferzonen.TZ8") }.map(\.value), [-2])
        XCTAssertEqual(start.state.stages.modifier.total, -2)
    }

    /// trefferzonen TZ.13: 5 SP on a leg are below the Wundschwelle 6 (no check); 6 SP are one:
    /// the check's application is TZ11's for the legs.
    func testBelowTheWundschwelleNoCheckAtItOne() throws {
        let engine = try engine(Self.real)
        let five = DamageChain.run(hit: nil, zone: "beine", in: hero(ko: 11, base: ["sp": 5, "wundschwelle": 6]), engine: engine)
        XCTAssertEqual(five.checks, [])
        // TZ8's derive is overridden by the sheet's Wundschwelle; its check's `when` is no.
        XCTAssertEqual(five.notApplied.filter { $0.origin == ref("trefferzonen.TZ8") }.map(\.reason), [.overridden, .conditionFalse])
        let six = DamageChain.run(hit: nil, zone: "beine", in: hero(ko: 11, base: ["sp": 6, "wundschwelle": 6]), engine: engine)
        XCTAssertEqual(six.checks.map(\.application), ["Störungen ignorieren"])
    }

    /// Extra 4: the Wundeffekt check runs through the check procedure; a failure gains the leg's
    /// Status Liegend through the action layer (origin TZ8, the clause holding the `onFailure`),
    /// held within the rule's Stufen for the whole run: a hero already Liegend gains nothing.
    func testAFailedWundeffektCheckGainsTheZonesStateThroughTheActionLayer() throws {
        let engine = try engine(Self.real)
        let r = DamageChain.run(hit: nil, zone: "beine", in: hero(ko: 11, base: ["sp": 6, "wundschwelle": 6]), engine: engine)
        let check = try XCTUnwrap(r.checks.first)
        let request = check.request(attributes: selbstbeherrschung)
        // MU 14, MU 14, KO 11, FW 9, modifier −1: [20, 20, 5] is a Patzer, a failure.
        let rolled = CheckProcedure.start(request, in: check.situation, engine: engine).state.step(.dice([20, 20, 5]), engine: engine)
        XCTAssertEqual(rolled.state.result?.success, false)
        let confirmed = rolled.state.step(.confirm, engine: engine)
        let gained = confirmed.events.filter { $0.kind == .gained }
        XCTAssertEqual(gained.map(\.rule), ["STATE_10"])
        XCTAssertEqual(gained.map(\.origin), [ref("trefferzonen.TZ8")])
        // The same failure entered at the table (`check.result: failure`, no dice).
        let entered = CheckProcedure.start(request, in: check.situation, engine: engine).state.step(.outcome(success: false), engine: engine)
        XCTAssertEqual(entered.events.filter { $0.kind == .gained }.map(\.rule), ["STATE_10"])
        guard case .confirmed = entered.state else { return XCTFail("\(entered.state)") }
        // Already Liegend: nothing left to gain.
        var liegend = check.situation
        liegend.owned["STATE_10"] = OwnedRule(level: 1)
        let again = CheckProcedure.start(request, in: liegend, engine: engine).state.step(.outcome(success: false), engine: engine)
        XCTAssertEqual(again.events.filter { $0.kind == .gained }, [])
        XCTAssertTrue(again.notApplied.contains { $0.origin == ref("trefferzonen.TZ8") && $0.reason == .overridden })
        // A success: no Wundeffekt.
        let passed = CheckProcedure.start(request, in: check.situation, engine: engine).state.step(.outcome(success: true), engine: engine)
        XCTAssertEqual(passed.events.filter { $0.kind == .gained }, [])
    }

    /// With the Fokusregel off there is no Wundeffekt check (TZ8 `rulesetOff`), however many SP.
    func testWithTheFokusregelOffNoWundeffektIsAsked() throws {
        let engine = try engine(Self.real)
        let r = DamageChain.run(hit: nil, in: hero(ko: 11, rulesets: [], base: ["sp": 13, "wundschwelle": 6]), engine: engine)
        XCTAssertEqual(r.checks, [])
        XCTAssertTrue(r.notApplied.contains { $0.origin == ref("trefferzonen.TZ8") && $0.reason == .rulesetOff })
    }

    /// hit.zoneRs where Trefferzonen-Rüstungsschutz applies: the `rs(zone: …)` of the zone hit
    /// (the arm and side a hit names: armRechts), which trefferzonen-ruestungsschutz.RS2 sets as
    /// the RS the SP come from.
    func testTheZonesRSWhereTrefferzonenRSApplies() throws {
        let engine = try engine(Self.real)
        let s = hero(rulesets: ["fokus.trefferzonen", "fokus.trefferzonen-rs"], base: ["rs": 6, "rs(zone: armRechts)": 3])
        let r = DamageChain.run(hit: 9, zone: "arme", side: "rechts", in: s, engine: engine)
        XCTAssertEqual(r.situation.facts["hit.zoneRs"]?.value, 3)
        XCTAssertEqual(r.rs.result, 3)
        XCTAssertEqual(r.rs.lines.map(\.origin), [ref("trefferzonen-ruestungsschutz.RS2")])
        XCTAssertEqual(r.sp.result, 6)
        // Without the Fokusregel Stufe II the whole armour's RS counts, and no zone RS is derived.
        let plain = DamageChain.run(hit: 9, zone: "arme", side: "rechts",
                                    in: hero(base: ["rs": 6, "rs(zone: armRechts)": 3]), engine: engine)
        XCTAssertNil(plain.situation.facts["hit.zoneRs"])
        XCTAssertEqual(plain.sp.result, 3)
    }

    // MARK: - The mount's hit (R25)

    /// reiterkampf.RK11: a Passierschlag hits the mount, not the rider. schaden.S1 and S2 are
    /// suppressed: the rider has no SP (no `hit.sp`, so no Wundeffekt from his RS) and loses no
    /// LeP. The mount's SP are the stated `hit.mountSp`, which the rider's chain never fills;
    /// RK10's Reiten check is due, its −1 per 5 full SP read from them.
    func testTheMountsHitIsNotTheRiders() throws {
        let engine = try engine(Self.real)
        let mounted: [String: JSONValue] = ["hero.mounted": true, "choice.mountHit": true,
                                            "gmFact.incomingAttack": "passierschlag"]
        let r = DamageChain.run(hit: 9, zone: "torso", in: hero(ko: 11, base: ["rs": 6], facts: mounted, le: 37), engine: engine)
        XCTAssertNil(r.sp.result)
        XCTAssertTrue(r.sp.notApplied.contains { $0.origin == ref("schaden.S1") && $0.reason == .suppressed })
        XCTAssertNil(r.situation.facts["hit.sp"])
        XCTAssertNil(r.situation.facts["hit.mountSp"])
        XCTAssertEqual(r.leCurrent.result, 37)
        XCTAssertTrue(r.leCurrent.notApplied.contains { $0.origin == ref("schaden.S2") && $0.reason == .suppressed })
        let check = try XCTUnwrap(r.checks.first { $0.origin == ref("reiterkampf.RK10") })
        XCTAssertEqual(check.id, "TAL_6")
        XCTAssertEqual(check.application, "Kampfmanöver")
        XCTAssertFalse(r.checks.contains { $0.origin == ref("trefferzonen.TZ8") })
        let reiten = ["CH", "GE", "KK"]
        let unknown = CheckProcedure.start(check.request(attributes: reiten), in: check.situation, engine: engine)
        XCTAssertTrue(unknown.questions.contains { $0.fact == "hit.mountSp" }, "\(unknown.questions.map(\.fact))")
        var stated = check.situation
        stated.facts["hit.mountSp"] = Fact(name: "hit.mountSp", value: 12, owner: .roll)
        let known = CheckProcedure.start(check.request(attributes: reiten), in: stated, engine: engine)
        XCTAssertEqual(known.state.stages.modifier.lines.filter { $0.origin == ref("reiterkampf.RK10") }.map(\.value), [-2])
    }

    // MARK: - Paying LeP is not damage

    /// Extra 5: paying LeP lowers LE and nothing else. Only a hit (`.takeHit`) runs the chain:
    /// a payment far over the Wundschwelle asks for no Wundeffekt check and states no hit.
    func testPayingLePIsNotDamage() throws {
        let engine = try engine(Self.real)
        let layer = ActionLayer(engine: engine)
        let s = hero(ko: 11, base: ["wundschwelle": 6, "rs": 0], le: 37)
        let paid = layer.perform(.pay(.le, 20), in: s)
        XCTAssertEqual(paid.events.map(\.kind), [.paid])
        XCTAssertEqual(paid.checks, [])
        let after = s.applying(paid.events)
        XCTAssertFalse(after.facts.keys.contains { $0.hasPrefix("hit.") })
        XCTAssertEqual(after.pools[.le]?.current, 17)
        // The same 20 as a hit on the torso: SP 20, three Wundschwellen, the check is due.
        let hit = layer.perform(.takeHit(tp: 20, zone: "torso"), in: s)
        XCTAssertEqual(hit.events, [])
        XCTAssertEqual(hit.checks.map(\.origin), [ref("trefferzonen.TZ8")])
        XCTAssertEqual(hit.breakdowns.map(\.query.description), ["hit.tp", "rs", "sp", "wundschwelle", "leCurrent"])
        XCTAssertEqual(hit.breakdowns.last?.result, 17)
    }

    /// A hit with nothing to go on (no TP, no SP stated) asks for the TP and stops there: no
    /// SP, no Wundeffekt, nothing thrown.
    func testAHitWithoutTPAsksForIt() throws {
        let engine = try engine(Self.real)
        let r = DamageChain.run(hit: nil, zone: "kopf", in: hero(base: ["rs": 4]), engine: engine)
        XCTAssertNil(r.tp)
        XCTAssertNil(r.sp.result)
        XCTAssertNil(r.situation.facts["hit.sp"])
        XCTAssertTrue(r.questions.contains { $0.fact == "hit.tp" }, "\(r.questions.map(\.fact))")
        XCTAssertEqual(r.checks, [])
    }
}
