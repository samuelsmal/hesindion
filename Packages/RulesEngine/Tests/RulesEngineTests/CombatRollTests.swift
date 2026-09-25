import XCTest
@testable import RulesEngine

/// The 1W20 combat roll (spec §6, plan Task 27): target → dice → result (a confirmation roll is
/// itself a check on the same target) → consequence. On the real `build/rules/rules.json`.
final class CombatRollTests: XCTestCase {
    static let real: Engine? = {
        guard let book = try? RuleBook.load(from: Repo.url("build/rules/rules.json")) else { return nil }
        return Engine(book: book)
    }()

    private func engine() throws -> Engine { try XCTUnwrap(Self.real, "run make rules-json") }
    private func ref(_ s: String) -> ClauseRef { ClauseRef(s)! }

    /// A hero with the sheet's values `base` and the facts stated.
    private func hero(base: [String: Int] = ["at": 14, "pa": 8, "aw": 7], facts: [String: JSONValue] = [:],
                      owned: [String: OwnedRule] = [:]) -> Situation {
        Situation(owned: owned,
                  facts: facts.map { Fact(name: $0.key, value: $0.value, owner: Vocabulary.owner(ofFact: $0.key) ?? .sheet) },
                  base: base)
    }

    private let bow: [String: JSONValue] = ["loadout.weapon": "Kurzbogen", "loadout.weapon.kind": "ranged",
                                            "loadout.weapon.technique": "CT_2"]

    private func rolled(_ r: CombatRequest, _ s: Situation, _ face: Int, _ e: Engine) -> CombatStep {
        CombatRoll.start(r, in: s, engine: e).state.step(.dice([face]), engine: e)
    }

    // MARK: - target

    /// The target stage is the §5 breakdown of AT, FK, PA or AW: an attack with a melee weapon is
    /// `at`, with a ranged one `fk`; a defence `pa(with: …)` or `aw`. The declaration is stated
    /// for the rules (`action.defence`, `action.with`).
    func testTheTargetStageIsTheBreakdownOfATPAAWOrFK() throws {
        let e = try engine()
        let at = CombatRoll.start(.attack(), in: hero(), engine: e)
        guard case .awaitingDice(let stages) = at.state else { return XCTFail("\(at.state)") }
        XCTAssertEqual(stages.target.query.description, "at")
        XCTAssertEqual(stages.target.result, 14)
        XCTAssertEqual(at.breakdowns.map(\.query.description), ["at"])
        let fk = CombatRoll.start(.attack(with: "Kurzbogen"), in: hero(base: ["fk(with: Kurzbogen)": 14], facts: bow), engine: e)
        XCTAssertEqual(fk.state.stages.target.query.description, "fk(with: Kurzbogen)")
        XCTAssertEqual(fk.state.stages.target.result, 14)
        let shield = CombatRoll.start(.defend(kind: .pa, with: "shield"), in: hero(base: ["pa(with: shield)": 13]), engine: e)
        XCTAssertEqual(shield.state.stages.target.query.description, "pa(with: shield)")
        XCTAssertEqual(shield.state.stages.situation.facts["action.defence"]?.value, "shieldParry")
        XCTAssertEqual(shield.state.stages.situation.facts["action.with"]?.value, "shield")
        let aw = CombatRoll.start(.defend(kind: .aw), in: hero(), engine: e)
        XCTAssertEqual(aw.state.stages.target.query.description, "aw")
        XCTAssertEqual(aw.state.stages.target.result, 7)
    }

    // MARK: - dice and result

    /// A face at or below the target succeeds, above it fails; the attack's outcome is stated as
    /// `action.attack: hit | miss` (R37: an outcome, never a declaration), with the die as
    /// `roll.attack`.
    func testTheDieAgainstTheTarget() throws {
        let e = try engine()
        let hit = rolled(.attack(), hero(), 14, e)
        guard case .resolved(_, let r, _) = hit.state else { return XCTFail("\(hit.state)") }
        XCTAssertEqual(r.success, true)
        XCTAssertEqual(r.value, 14)
        XCTAssertNil(r.confirmation)
        XCTAssertEqual(hit.situation.facts["action.attack"]?.value, "hit")
        XCTAssertEqual(hit.situation.facts["roll.attack"]?.value, 14)
        let miss = rolled(.attack(), hero(), 15, e)
        XCTAssertEqual(miss.state.result?.success, false)
        XCTAssertEqual(miss.situation.facts["action.attack"]?.value, "miss")
        let parry = rolled(.defend(kind: .pa), hero(), 8, e)
        XCTAssertEqual(parry.state.result?.success, true)
        XCTAssertEqual(parry.situation.facts["roll.defence"]?.value, 8)
    }

    /// A 1 always succeeds and a 20 always fails, and each needs confirming; until then the
    /// result is regular.
    func testAOneOrATwentyNeedsConfirmation() throws {
        let e = try engine()
        let one = rolled(.attack(), hero(), 1, e)
        guard case .awaitingConfirmation(_, let r) = one.state else { return XCTFail("\(one.state)") }
        XCTAssertEqual(r.success, true)
        XCTAssertEqual(r.kind, .regular)
        XCTAssertEqual(r.confirmation?.of, .kritischerErfolg)
        let twenty = rolled(.attack(), hero(base: ["at": 25]), 20, e)
        guard case .awaitingConfirmation(_, let t) = twenty.state else { return XCTFail("\(twenty.state)") }
        XCTAssertEqual(t.success, false)
        XCTAssertEqual(t.confirmation?.of, .patzer)
        // A die the state cannot take: a text, the state unchanged.
        let again = one.state.step(.dice([5]), engine: e)
        XCTAssertEqual(again.state, one.state)
        XCTAssertFalse(again.texts.isEmpty)
    }

    /// The confirmation is a check on the same target: at or below it confirms. A confirmed 1 is
    /// a Kritischer Erfolg, an unconfirmed one a plain hit; a 20 whose confirmation fails is a
    /// Patzer (`action.attack: confirmedFumble`), a confirmed one a plain miss.
    func testTheConfirmationIsACheckOnTheSameTarget() throws {
        let e = try engine()
        let one = rolled(.attack(), hero(), 1, e).state
        let crit = one.step(.confirm(12), engine: e)
        guard case .resolved(_, let c, _) = crit.state else { return XCTFail("\(crit.state)") }
        XCTAssertEqual(c.kind, .kritischerErfolg)
        XCTAssertEqual(c.confirmation?.face, 12)
        XCTAssertEqual(c.confirmation?.success, true)
        XCTAssertEqual(c.success, true)
        let plain = one.step(.confirm(17), engine: e)
        XCTAssertEqual(plain.state.result?.kind, .regular)
        XCTAssertEqual(plain.state.result?.success, true)
        let twenty = rolled(.attack(), hero(), 20, e).state
        let fumble = twenty.step(.confirm(17), engine: e)
        XCTAssertEqual(fumble.state.result?.kind, .patzer)
        XCTAssertEqual(fumble.situation.facts["action.attack"]?.value, "confirmedFumble")
        let saved = twenty.step(.confirm(5), engine: e)
        XCTAssertEqual(saved.state.result?.kind, .regular)
        XCTAssertEqual(saved.situation.facts["action.attack"]?.value, "miss")
    }

    /// probe-fernkampf 21.4 (MIGRATION "Notes for the engine tasks"): fernkampf.FK9 Stufe 4 caps
    /// FK at 0, so any face but a natural 1 misses.
    func testAtFKZeroOnlyANaturalOneHits() throws {
        let e = try engine()
        var facts = bow
        facts["gmFact.sicht"] = 4
        let s = hero(base: ["fk(with: Kurzbogen)": 14], facts: facts)
        let three = rolled(.attack(with: "Kurzbogen"), s, 3, e)
        XCTAssertEqual(three.state.result?.value, 0)
        XCTAssertEqual(three.state.result?.success, false)
        XCTAssertEqual(rolled(.attack(with: "Kurzbogen"), s, 1, e).state.result?.success, true)
    }

    /// fernkampf.FK13: a 1 on a shot is confirmed by the rules' own `check { of: { check: confirm,
    /// with: fk } }`; its `onSuccess` doubles the TP "samt aller Modifikatoren", which the
    /// consequence stage (`tp(with: …)`) shows as FK13's `.multiplied` line.
    func testTheRulesConfirmCheckRunsItsConsequences() throws {
        let e = try engine()
        let s = hero(base: ["fk(with: Kurzbogen)": 14, "tp(with: Kurzbogen)": 7], facts: bow)
        let one = rolled(.attack(with: "Kurzbogen"), s, 1, e)
        XCTAssertEqual(one.state.result?.confirmation?.checks, [ref("fernkampf.FK13")])
        let crit = one.state.step(.confirm(9), engine: e)
        XCTAssertEqual(crit.state.result?.kind, .kritischerErfolg)
        XCTAssertEqual(crit.state.result?.from, ref("fernkampf.FK13"))
        let tp = try XCTUnwrap(crit.consequence)
        XCTAssertEqual(tp.query.description, "tp(with: Kurzbogen)")
        XCTAssertEqual(tp.result, 14)
        XCTAssertEqual(tp.lines.filter { $0.kind == .multiplied }.map(\.origin), [ref("fernkampf.FK13")])
        // Unconfirmed: no doubling.
        let plain = one.state.step(.confirm(18), engine: e)
        XCTAssertEqual(plain.consequence?.result, 7)
        // A melee weapon asks for no FK13 confirm.
        XCTAssertEqual(rolled(.attack(), hero(), 1, e).state.result?.confirmation?.checks, [])
    }

    /// fernkampf.FK14: a failed confirmation of a shot's 20 is the Patzer, and the rules tell the
    /// player the 1W6+2 SP (logged).
    func testAShotsPatzerTellsItsDamage() throws {
        let e = try engine()
        let s = hero(base: ["fk(with: Kurzbogen)": 14], facts: bow)
        let fumble = rolled(.attack(with: "Kurzbogen"), s, 20, e).state.step(.confirm(19), engine: e)
        XCTAssertEqual(fumble.state.result?.kind, .patzer)
        XCTAssertEqual(fumble.events.filter { $0.kind == .logged }.map(\.origin), [ref("fernkampf.FK14")])
        XCTAssertTrue(fumble.texts.contains { $0.kind == .tell && $0.origin == ref("fernkampf.FK14") })
    }

    /// passierschlag.PS4: no Kritische Erfolge or Patzer on a Passierschlag; the 1 simply hits,
    /// with no confirmation, and the forbid says why.
    func testAPassierschlagIsNeverConfirmed() throws {
        let e = try engine()
        let one = rolled(.attack(), hero(facts: ["choice.passierschlag": true]), 1, e)
        guard case .resolved(_, let r, _) = one.state else { return XCTFail("\(one.state)") }
        XCTAssertEqual(r.success, true)
        XCTAssertNil(r.confirmation)
        XCTAssertTrue(one.notApplied.contains { $0.origin == ref("passierschlag.PS4") && $0.reason == .forbidden })
    }

    /// fernkampf.FK17: a confirmed 1 on a defence against a shot leaves
    /// `round.previousDefenceCrit: confirmed` for the next defence of the round, which gives back
    /// MV1's −3 (+3); that defence clears it.
    func testADefenceConfirmationIsKeptForTheNextDefence() throws {
        let e = try engine()
        let s = hero(facts: ["gmFact.incomingAttack": "ranged"])
        let one = rolled(.defend(kind: .aw), s, 1, e)
        XCTAssertEqual(one.state.result?.confirmation?.checks, [ref("fernkampf.FK17")])
        let confirmed = one.state.step(.confirm(3), engine: e)
        XCTAssertEqual(confirmed.situation.facts["round.previousDefenceCrit"]?.value, "confirmed")
        let next = CombatRoll.start(.defend(kind: .aw), in: confirmed.situation, engine: e)
        XCTAssertEqual(next.state.stages.target.lines.filter { $0.origin == ref("fernkampf.FK17") }.map(\.value), [3])
        let after = next.state.step(.dice([5]), engine: e)
        XCTAssertNil(after.situation.facts["round.previousDefenceCrit"])
        let unconfirmed = one.state.step(.confirm(12), engine: e)
        XCTAssertEqual(unconfirmed.situation.facts["round.previousDefenceCrit"]?.value, "unconfirmed")
    }

    /// Extra 3: the mount's ordered attack (`choice.order: mountAttack`) sets the attack-hit fact
    /// maechtiger-schlag reads: MS1's text to the opponent appears once the attack hits.
    func testTheMountsOrderedAttackSetsTheAttackHitFact() throws {
        let e = try engine()
        let s = hero(base: ["at(with: mount)": 15],
                     facts: ["hero.mounted": true, "choice.order": "mountAttack", "opponent.size": "mittel"],
                     owned: ["svellttaler-kaltblut": OwnedRule(level: 1)])
        let start = CombatRoll.start(.attack(with: "mount"), in: s, engine: e)
        XCTAssertFalse(start.texts.contains { $0.origin == ref("maechtiger-schlag.MS1") })
        let hit = start.state.step(.dice([9]), engine: e)
        XCTAssertEqual(hit.situation.facts["action.attack"]?.value, "hit")
        XCTAssertTrue(hit.texts.contains { $0.kind == .tell && $0.origin == ref("maechtiger-schlag.MS1") && $0.audience == .opponent },
                      "\(hit.texts.map { "\($0.origin.map(\.description) ?? "-"): \($0.text)" })")
        let miss = start.state.step(.dice([18]), engine: e)
        XCTAssertFalse(miss.texts.contains { $0.kind == .tell && $0.origin == ref("maechtiger-schlag.MS1") })
    }

    // MARK: - What may be rolled

    /// The attacks and defences the situation offers, each with its target and legality:
    /// against a large opponent no weapon parry (groessenkategorie.GK4), the shield parry offered
    /// by schilde.SCH3 while a shield is held, and the dodge.
    func testTheOptionsListTheDefencesWithTheirLegality() throws {
        let e = try engine()
        let s = hero(base: ["pa(with: weapon)": 8, "pa(with: shield)": 13, "aw": 7],
                     facts: ["loadout.weapon": "Langschwert", "loadout.shield": "Großschild", "loadout.other": "shield",
                             "opponent.size": "gross"])
        let options = CombatRoll.options(in: s, engine: e)
        let defences = options.filter { $0.kind == .defence }
        XCTAssertEqual(defences.map(\.id), ["weaponParry", "weaponParry", "weaponParry", "shieldParry", "aw"])
        XCTAssertEqual(defences.map(\.legal), [false, false, false, true, true])
        XCTAssertEqual(defences.first?.reasons.map(\.origin), [ref("groessenkategorie.GK4")])
        // beidhaendiger-kampf.ZW7: the parry with either hand.
        XCTAssertEqual(defences[1...2].map(\.origin), [ref("beidhaendiger-kampf.ZW7"), ref("beidhaendiger-kampf.ZW7")])
        XCTAssertEqual(defences[3].origin, ref("schilde.SCH3"))
        XCTAssertEqual(defences.map(\.target.query.description),
                       ["pa(with: weapon)", "pa(with: mainHand)", "pa(with: offHand)", "pa(with: shield)", "aw"])
        let attacks = options.filter { $0.kind == .attack }
        XCTAssertEqual(attacks.map(\.id), ["melee", "shield", "parryingWeapon"])
        XCTAssertEqual(attacks.dropFirst().map(\.origin), [ref("schilde.SCH2"), ref("schilde.SCH2")])
        // A Passierschlag suffered: no defence at all (passierschlag.PS2).
        let ps = CombatRoll.options(in: hero(facts: ["gmFact.incomingAttack": "passierschlag", "loadout.shield": .null]), engine: e)
        XCTAssertEqual(ps.filter { $0.kind == .defence }.map(\.legal), [false, false, false, false])
    }

    // MARK: - The action layer

    /// `.attack` / `.defend` run the roll with the situation's dice: the first die, then the
    /// confirmation when one is needed.
    func testTheActionLayerRollsWithTheSituationsDice() throws {
        let e = try engine()
        let layer = ActionLayer(engine: e)
        var s = hero(base: ["fk(with: Kurzbogen)": 14, "tp(with: Kurzbogen)": 7], facts: bow)
        s.rolls = [1, 9]
        let r = layer.perform(.attack(with: "Kurzbogen"), in: s)
        XCTAssertEqual(r.breakdowns.map(\.query.description), ["fk(with: Kurzbogen)", "tp(with: Kurzbogen)"])
        XCTAssertEqual(r.breakdowns.last?.result, 14)
        var d = hero()
        d.rolls = [9]
        XCTAssertEqual(layer.perform(.defend(kind: .pa), in: d).breakdowns.map(\.query.description), ["pa"])
    }
}
