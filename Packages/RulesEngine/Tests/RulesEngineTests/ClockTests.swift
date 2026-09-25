import XCTest
@testable import RulesEngine

/// The game clock and spans (spec §7, plan Task 28): `Clock { round, minutes }`,
/// `.advanceClock(minutes:)` paying every `cost { every }` that falls due, `.endRound` /
/// `.endFight` ending what lasts the round or the fight, `whileFormed` and `untilCleared`,
/// `.settle` for the standing gains, and `ActionResult.situation` carrying a roll's state across
/// `perform` calls.
final class ClockTests: XCTestCase {
    private var layer: ActionLayer { ActionLayer(book: ProcessTests.state) }
    private func ref(_ s: String) -> ClauseRef { ClauseRef(s)! }
    private func situation(_ facts: [String: JSONValue], pools: [Pool: PoolState] = [:]) -> Situation {
        var s = ProcessTests.situation(facts: facts)
        s.pools = pools
        return s
    }
    private let magic: [Pool: PoolState] = [.asp: PoolState(current: 30, max: 30)]
    private func paid(_ r: ActionResult) -> [Event] { r.events.filter { $0.kind == .paid } }

    // MARK: - The clock's costs

    /// "2 AsP pro 5 Minuten": after 12 minutes, two payments of 2; three more minutes, a third.
    func testTwoAsPEveryFiveMinutesOverTwelveMinutesIsTwoPayments() {
        let s = situation(["choice.upkeep": true], pools: magic)
        XCTAssertEqual(s.clock, Clock(round: 1, minutes: 0))
        let twelve = layer.perform(.advanceClock(minutes: 12), in: s)
        XCTAssertEqual(paid(twelve).map(\.amount), [2, 2])
        XCTAssertEqual(paid(twelve).map(\.origin), [ref("st-upkeep.U1"), ref("st-upkeep.U1")])
        XCTAssertEqual(twelve.situation.clock.minutes, 12)
        XCTAssertEqual(twelve.situation.pools[.asp]?.current, 26)
        XCTAssertEqual(twelve.situation.fact("clock.minutes")?.value, .int(12))
        let fifteen = layer.perform(.advanceClock(minutes: 3), in: twelve.situation)
        XCTAssertEqual(paid(fifteen).map(\.amount), [2])
        let sixteen = layer.perform(.advanceClock(minutes: 1), in: fifteen.situation)
        XCTAssertEqual(paid(sixteen), [])
        // Without the upkeep, time passes and nothing is paid.
        XCTAssertEqual(paid(layer.perform(.advanceClock(minutes: 60), in: situation([:], pools: magic))), [])
    }

    /// probe-magie 20.5's shape: the interval is read from a fact (`spell.interval: 60`), so 180
    /// minutes pay three times 1 AsP; an unknown interval is asked.
    func testTheIntervalIsReadFromAFact() {
        let s = situation(["spell.maintained": true, "spell.interval": 60], pools: magic)
        let r = layer.perform(.advanceClock(minutes: 180), in: s)
        XCTAssertEqual(paid(r).map(\.amount), [1, 1, 1])
        XCTAssertTrue(paid(r).allSatisfy { $0.facts.contains { $0.name == "spell.interval" && $0.value == .int(60) } })
        let unknown = layer.perform(.advanceClock(minutes: 180), in: situation(["spell.maintained": true], pools: magic))
        XCTAssertEqual(paid(unknown), [])
        XCTAssertTrue(unknown.questions.contains { $0.fact == "spell.interval" && $0.origins == [ref("st-upkeep.U2")] })
        XCTAssertEqual(Clock.due(every: 5, from: 3, to: 12), 2, "the marks at 5 and 10")
        XCTAssertEqual(Clock.due(every: 0, from: 0, to: 12), 0)
    }

    /// A cost counted in rounds falls due at the end of a round: 1 KaP every two rounds.
    func testACostEveryTwoRoundsFallsDueAtTheRoundsEnd() {
        let s = situation(["choice.prayer": true], pools: [.kap: PoolState(current: 5, max: 5)])
        let second = layer.perform(.endRound, in: s)                 // round 1 → 2
        XCTAssertEqual(paid(second).map(\.pool), [.kap])
        let third = layer.perform(.endRound, in: second.situation)   // 2 → 3
        XCTAssertEqual(paid(third), [])
        XCTAssertEqual(paid(layer.perform(.advanceClock(minutes: 30), in: s)), [], "minutes do not move the round counter")
    }

    /// Advancing the clock by nothing changes nothing and says so.
    func testTheClockDoesNotGoBack() {
        let r = layer.perform(.advanceClock(minutes: 0), in: situation([:]))
        XCTAssertEqual(r.events, [])
        XCTAssertEqual(r.situation.clock.minutes, 0)
        XCTAssertEqual(r.texts.map(\.kind), [.notApplicable])
    }

    // MARK: - Spans

    /// `.endRound` clears the round's facts (`round.*`, `round.previousDefenceCrit` among them) and
    /// the choices offered for the round or the action; `.endFight` those for the fight; a
    /// `whileFormed` choice lasts until it is cleared.
    func testEndRoundAndEndFightClearWhatLastsTheirSpan() {
        let s = situation(["round.parries": 2, "round.previousDefenceCrit": "confirmed", "choice.vorstoss": true,
                           "choice.finte": true, "choice.wut": true, "choice.formation": true, "gmFact.sicht": 2])
        let round = layer.perform(.endRound, in: s).situation
        XCTAssertEqual(round.clock.round, 2)
        XCTAssertNil(round.facts["round.parries"])
        XCTAssertNil(round.facts["round.previousDefenceCrit"])
        XCTAssertNil(round.facts["choice.vorstoss"])
        XCTAssertNil(round.facts["choice.finte"])
        XCTAssertEqual(round.facts["choice.wut"]?.value, .bool(true))
        XCTAssertEqual(round.facts["choice.formation"]?.value, .bool(true))
        XCTAssertEqual(round.facts["gmFact.sicht"]?.value, .int(2), "a fact with no span stays")
        let fight = layer.perform(.endFight, in: round).situation
        XCTAssertNil(fight.facts["choice.wut"])
        XCTAssertEqual(fight.facts["choice.formation"]?.value, .bool(true), "whileFormed: until its choice is cleared")
        var broken = fight
        broken.facts["choice.formation"] = nil
        XCTAssertNil(layer.perform(.endFight, in: broken).situation.facts["choice.formation"])
    }

    /// A Stufe gained for a span ends with it: the round's at `.endRound`, the fight's at
    /// `.endFight`; one gained `untilCleared` lasts until a `cleared` event; one cleared for the
    /// action comes back when the round ends.
    func testStufenGainedForASpanEndWithIt() {
        let s = situation(["choice.brace": true, "choice.heat": true, "choice.curse": true])
        let settled = layer.perform(.settle, in: s)
        XCTAssertEqual(settled.events.map(\.rule), ["st-braced", "st-heated", "st-cursed"])
        XCTAssertEqual(settled.events.map(\.span), [.round, .fight, .untilCleared])
        var now = settled.situation
        XCTAssertEqual(now.timed.map(\.span), [.round, .fight, .untilCleared])
        now.facts = [:]                                              // the choices are spent

        let round = layer.perform(.endRound, in: now)
        XCTAssertEqual(round.events.map(\.kind), [.cleared])
        XCTAssertEqual(round.events.first?.rule, "st-braced")
        XCTAssertEqual(round.events.first?.origin, ref("st-spans.P2"))
        XCTAssertNil(round.situation.owned["st-braced"])
        XCTAssertEqual(round.situation.timed.map(\.rule), ["st-heated", "st-cursed"])

        let fight = layer.perform(.endFight, in: round.situation)
        XCTAssertEqual(fight.events.map(\.rule), ["st-heated"])
        XCTAssertNil(fight.situation.owned["st-heated"])
        XCTAssertEqual(fight.situation.owned["st-cursed"]?.level, 1, "untilCleared outlives the fight")
        XCTAssertEqual(layer.perform(.endFight, in: fight.situation).events, [])

        let lifted = fight.situation.applying([Event(kind: .cleared, rule: "st-cursed")], book: ProcessTests.state)
        XCTAssertNil(lifted.owned["st-cursed"])
        XCTAssertEqual(lifted.timed, [])

        // Cleared for the action (COND_6.SZ2's shape): back when the round ends.
        var heated = situation(["choice.calm": true])
        heated.owned["st-heated"] = OwnedRule(level: 2)
        let calmed = layer.perform(.settle, in: heated)
        XCTAssertEqual(calmed.events.map(\.kind), [.cleared])
        XCTAssertEqual(calmed.situation.owned["st-heated"]?.level, 1)
        var later = calmed.situation
        later.facts = [:]
        let back = layer.perform(.endRound, in: later)
        XCTAssertEqual(back.events.map(\.kind), [.gained])
        XCTAssertEqual(back.situation.owned["st-heated"]?.level, 2)
        XCTAssertEqual(back.situation.timed, [])
    }

    /// Time passing (minutes are longer than a Kampfrunde) ends what lasts the round or the action,
    /// as the round's end does: the Zustand durations stated as spans.
    func testAdvancingTheClockEndsWhatLastsTheRound() {
        let settled = layer.perform(.settle, in: situation(["choice.brace": true]))
        var now = settled.situation
        now.facts = ["choice.vorstoss": Fact(name: "choice.vorstoss", value: true, owner: .player)]
        let later = layer.perform(.advanceClock(minutes: 10), in: now)
        XCTAssertEqual(later.events.map(\.kind), [.cleared])
        XCTAssertNil(later.situation.owned["st-braced"])
        XCTAssertNil(later.situation.facts["choice.vorstoss"])
        XCTAssertEqual(later.situation.clock, Clock(round: 1, minutes: 10))
    }

    // MARK: - Across calls and settling (extra 5, 6)

    /// FK17 across `perform` calls: a confirmed critical defence leaves `round.previousDefenceCrit`
    /// in `ActionResult.situation`; the next defence, started from it, gets the +3; the round's end
    /// clears it.
    func testTheRollsStateCarriesAcrossPerformCallsAndEndsWithTheRound() throws {
        let layer = ActionLayer(engine: try XCTUnwrap(CombatRollTests.real, "run make rules-json"))
        var s = ProcessTests.situation(facts: ["gmFact.incomingAttack": "ranged"], base: ["at": 14, "pa": 8, "aw": 7])
        s.rolls = [1, 3]
        let crit = layer.perform(.defend(kind: .aw), in: s)
        XCTAssertEqual(crit.situation.facts["round.previousDefenceCrit"]?.value, "confirmed")
        var next = crit.situation
        next.rolls = [5]
        let second = layer.perform(.defend(kind: .aw), in: next)
        XCTAssertEqual(second.breakdowns.first?.lines.filter { $0.origin == ref("fernkampf.FK17") }.map(\.value), [3])
        XCTAssertNil(second.situation.facts["round.previousDefenceCrit"])
        XCTAssertNil(layer.perform(.endRound, in: crit.situation).situation.facts["round.previousDefenceCrit"])
    }

    /// Extra 5 (1.4's shape): Belastung IV gains Handlungsunfähig on `.settle`, with no action; a
    /// cast in the same situation neither gains it nor asks for what unrelated effects read.
    func testSettleRunsTheStandingGainsAndACastDoesNot() throws {
        let layer = ActionLayer(engine: try XCTUnwrap(CombatRollTests.real, "run make rules-json"))
        var s = ProcessTests.situation(facts: ["loadout.armour": "Gestechrüstung", "loadout.armour.belastung": 4,
                                               "loadout.armour.extraPenalty": 0, "check.result": "success"],
                                       base: ["spell.cost": 8])
        s.pools[.asp] = PoolState(current: 30, max: 30)
        let settled = layer.perform(.settle, in: s)
        let gained = settled.events.filter { $0.kind == .gained }
        XCTAssertEqual(gained.map(\.rule), ["STATE_8"])
        XCTAssertEqual(gained.first?.origin, ref("COND_1.B4"))
        XCTAssertEqual(settled.situation.owned["STATE_8"]?.level, 1)
        XCTAssertEqual(settled.events.filter { $0.kind == .paid }, [], "settling pays nothing")

        let cast = layer.perform(.cast(spell: "SPELL_21", modifications: []), in: s)
        XCTAssertEqual(cast.events.filter { $0.kind == .gained }, [])
        XCTAssertEqual(cast.events.filter { $0.kind == .paid }.map(\.amount), [8])
        let asked = Set(cast.questions.map(\.fact))
        for unrelated in ["hero.mounted", "action.attack", "action.gaitChange", "choice.order", "hit.tp"] {
            XCTAssertFalse(asked.contains(unrelated), "\(unrelated) is not the cast's: \(asked.sorted())")
        }
    }
}
