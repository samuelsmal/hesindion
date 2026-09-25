import XCTest
@testable import RulesEngine

/// Processes (spec §7, plan Task 28): Laden, Zielen, Bogen spannen. A process starts when the
/// action its `advancedBy` names happens (the offered choice taken, or `.advance(process:)`),
/// each such action gives `progressed`, reaching `steps` gives `completed` and the `completes`
/// effects, `breaksOff` turning yes gives `brokenOff`, and it outlives `.endRound`. The Laden
/// tests run on the real `build/rules/rules.json` (ladezeiten.LZ2, SA_60.SL2); Zielen's shape on
/// the fixture `Fixtures/state-rules.json` (fernkampf.FK11 rests on an open ruling).
final class ProcessTests: XCTestCase {
    static let state: RuleBook = {
        let url = Bundle.module.url(forResource: "state-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    private func real() throws -> ActionLayer {
        ActionLayer(engine: try XCTUnwrap(CombatRollTests.real, "run make rules-json"))
    }
    private func ref(_ s: String) -> ClauseRef { ClauseRef(s)! }

    static func situation(owned: [String: OwnedRule] = [:], facts: [String: JSONValue], base: [String: Int] = [:]) -> Situation {
        Situation(owned: owned,
                  facts: facts.sorted { $0.key < $1.key }.map {
                      Fact(name: $0.key, value: $0.value, owner: Vocabulary.owner(ofFact: $0.key) ?? .sheet)
                  },
                  base: base)
    }

    /// A Leichte Armbrust with Ladezeit 4, not loaded, and Schnellladen (Armbrüste): the Ladezeit
    /// is halved to 2 (SA_60.SL2's `multiply` on `item.ladezeit`).
    private let crossbow: [String: JSONValue] = [
        "loadout.weapon": "Leichte Armbrust", "loadout.weapon.technique": "CT_1", "loadout.weapon.kind": "ranged",
        "loadout.weapon.ladezeit": 4, "loadout.weapon.instance": "armbrust1", "item.armbrust1.loaded": false,
    ]
    private var loading: Situation {
        Self.situation(owned: ["SA_60": OwnedRule(level: 1, option: .int(1))], facts: crossbow)
    }

    // MARK: - Laden

    /// The brief's test: Laden of a Leichte Armbrust, Ladezeit 4 with Schnellladen halved to 2,
    /// completes after 2 actions and sets `item.loaded` on the crossbow's instance. The process
    /// outlives the end of the round between the two actions.
    func testLadenOfALeichteArmbrustHalvedToTwoCompletesAfterTwoActions() throws {
        let layer = try real()
        let s = loading
        let ladezeit = layer.engine.evaluate(Query("item.ladezeit"), in: s)
        XCTAssertEqual(ladezeit.result, 2)
        XCTAssertEqual(ladezeit.lines.map(\.kind), [.multiplied])
        XCTAssertEqual(ladezeit.lines.first?.origin, ref("SA_60.SL2"))

        let first = layer.perform(.take(choice: "laden"), in: s)
        XCTAssertEqual(first.events.map(\.kind), [.paid, .progressed])
        XCTAssertEqual(first.events[0].pool, .actions)
        let progressed = first.events[1]
        XCTAssertEqual(progressed.origin, ref("ladezeiten.LZ2"))
        XCTAssertEqual(progressed.process, "laden")
        XCTAssertEqual(progressed.progress, 1)
        XCTAssertEqual(progressed.steps, 2)
        XCTAssertEqual(progressed.item, "armbrust1")
        let running = try XCTUnwrap(first.situation.processes["laden"])
        XCTAssertEqual(running, ProcessState(id: "laden", rule: "ladezeiten",
                                             origin: EffectOrigin(rule: "ladezeiten", clause: "LZ2", index: .top(1)),
                                             progress: 1, steps: 2, startedRound: 1, instance: "armbrust1"))
        XCTAssertEqual(first.situation.fact("process.laden")?.value, .int(1))
        XCTAssertEqual(first.situation.fact("process.laden")?.owner, .derived)
        XCTAssertEqual(first.situation.fact("loadout.weapon.loaded")?.value, .bool(false))

        // The round ends: the process goes on.
        let later = layer.perform(.endRound, in: first.situation)
        XCTAssertEqual(later.situation.processes["laden"], running)
        XCTAssertEqual(later.situation.clock.round, 2)

        let second = layer.perform(.take(choice: "laden"), in: later.situation)
        XCTAssertEqual(second.events.map(\.kind), [.paid, .progressed, .completed, .itemChanged])
        XCTAssertEqual(second.events[1].progress, 2)
        XCTAssertEqual(second.events[3].item, "armbrust1")
        XCTAssertEqual(second.events[3].change, ["loaded": .bool(true)])
        XCTAssertEqual(second.events[3].origin, ref("ladezeiten.LZ2"))
        XCTAssertNil(second.situation.processes["laden"])
        XCTAssertEqual(second.situation.items["armbrust1"]?.loaded, true)
        XCTAssertEqual(second.situation.fact("loadout.weapon.loaded")?.value, .bool(true))
        XCTAssertEqual(second.situation.fact("process.laden")?.value, .int(0), "no process runs: 0")
        // Loaded, the crossbow is readied with a free action (LZ3) and Laden is no longer offered.
        let offers = layer.engine.offers(in: second.situation)
        XCTAssertTrue(offers.contains { $0.choice == "bereitmachen" && $0.legal })
        XCTAssertFalse(offers.contains { $0.choice == "laden" })
    }

    /// Without Schnellladen the Ladezeit is the weapon's own, 4 actions.
    func testWithoutSchnellladenTheLadezeitIsTheWeapons() throws {
        let layer = try real()
        let s = Self.situation(facts: crossbow)
        var now = s
        for step in 1...4 {
            let r = layer.perform(.take(choice: "laden"), in: now)
            XCTAssertEqual(r.events.first { $0.kind == .progressed }?.progress, step)
            now = r.situation
        }
        XCTAssertEqual(now.items["armbrust1"]?.loaded, true)
    }

    /// MIGRATION ladezeiten.LZ2: the process is bound to the instance it started on. With a dagger
    /// in hand, the next step still loads the crossbow, not the dagger.
    func testTheProcessIsBoundToTheInstanceItStartedOn() throws {
        let layer = try real()
        let first = layer.perform(.take(choice: "laden"), in: loading)
        var s = first.situation
        for (name, value) in ["loadout.weapon": JSONValue.string("Dolch"), "loadout.weapon.kind": "melee",
                              "loadout.weapon.technique": "CT_3", "loadout.weapon.instance": "dolch1"] {
            s.state(Fact(name: name, value: value, owner: .loadout))
        }
        let second = layer.perform(.advance(process: "laden"), in: s)
        XCTAssertEqual(second.events.map(\.kind), [.progressed, .completed, .itemChanged], "advance pays no cost")
        XCTAssertEqual(second.events.last?.item, "armbrust1")
        XCTAssertEqual(second.situation.items["armbrust1"]?.loaded, true)
        XCTAssertNil(second.situation.items["dolch1"])
    }

    /// LZ2's `breaksOff`: a melee attack (`action.attack: [hit, miss]` with a melee weapon in hand)
    /// breaks Laden off: `brokenOff`, the process ends, the crossbow stays unloaded.
    func testAMeleeAttackBreaksLadenOff() throws {
        let layer = try real()
        let first = layer.perform(.take(choice: "laden"), in: loading)
        var s = first.situation
        for (name, value) in ["loadout.weapon": JSONValue.string("Dolch"), "loadout.weapon.kind": "melee",
                              "loadout.weapon.technique": "CT_3", "loadout.weapon.instance": "dolch1"] {
            s.state(Fact(name: name, value: value, owner: .loadout))
        }
        s.base["at"] = 12
        s.rolls = [5]
        let attack = layer.perform(.attack(with: "Dolch"), in: s)
        let broken = attack.events.filter { $0.kind == .brokenOff }
        XCTAssertEqual(broken.map(\.process), ["laden"])
        XCTAssertEqual(broken.first?.origin, ref("ladezeiten.LZ2"))
        XCTAssertEqual(Set(broken.first?.facts.map(\.name) ?? []), ["action.attack", "loadout.weapon.kind"])
        XCTAssertNil(attack.situation.processes["laden"])
        XCTAssertEqual(attack.situation.items["armbrust1"]?.loaded, false)
        // A missed stroke breaks it off as well; a talk (no attack) does not.
        s.rolls = [19]
        XCTAssertEqual(layer.perform(.attack(with: "Dolch"), in: s).events.filter { $0.kind == .brokenOff }.count, 1)
        XCTAssertEqual(layer.perform(.endRound, in: first.situation).events.filter { $0.kind == .brokenOff }, [])
    }

    /// The shot empties the crossbow (LZ2's `item … loaded: false` after `action.attack`) and
    /// spends a bolt (LZ7): consequences of the roll, run by the action layer.
    func testTheShotEmptiesTheWeaponAndSpendsABolt() throws {
        let layer = try real()
        var s = Self.situation(facts: crossbow.merging(["item.armbrust1.loaded": true]) { $1 },
                               base: ["fk(with: Leichte Armbrust)": 12])
        s.pools[.ammunition] = PoolState(current: 10, max: 20)
        s.rolls = [4]
        let shot = layer.perform(.attack(with: "Leichte Armbrust"), in: s)
        XCTAssertEqual(shot.situation.facts["action.attack"]?.value, "hit")
        let unload = try XCTUnwrap(shot.events.first { $0.kind == .itemChanged })
        XCTAssertEqual(unload.origin, ref("ladezeiten.LZ2"))
        XCTAssertEqual(unload.change, ["loaded": .bool(false)])
        XCTAssertEqual(shot.events.first { $0.kind == .paid }?.origin, ref("ladezeiten.LZ7"))
        XCTAssertEqual(shot.situation.items["armbrust1"]?.loaded, false)
        XCTAssertEqual(shot.situation.pools[.ammunition]?.current, 9)
    }

    // MARK: - Zielen (the fixture's shape)

    /// Two steps of +2, the third buys nothing; the progress is the fact `process.zielen` the
    /// bonus reads; the round's end does not stop it; the shot breaks it off.
    func testAimingIsCappedAtItsStepsAndTheShotBreaksItOff() {
        let layer = ActionLayer(book: Self.state)
        var s = Self.situation(facts: ["loadout.weapon": "Kurzbogen", "loadout.weapon.kind": "ranged",
                                       "loadout.weapon.instance": "bogen1"], base: ["fk(with: Kurzbogen)": 14])
        func bonus(_ s: Situation) -> [Int] {
            layer.engine.evaluate(Query("fk(with: Kurzbogen)"), in: s).lines.filter { $0.origin == ref("st-aim.A1") }.map(\.value)
        }
        XCTAssertEqual(bonus(s), [])
        let one = layer.perform(.take(choice: "zielen"), in: s)
        XCTAssertEqual(one.events.map(\.kind), [.paid, .progressed])
        XCTAssertEqual(bonus(one.situation), [2])
        let two = layer.perform(.take(choice: "zielen"), in: layer.perform(.endRound, in: one.situation).situation)
        XCTAssertEqual(two.events.map(\.kind), [.paid, .progressed])
        XCTAssertEqual(two.situation.processes["zielen"]?.progress, 2)
        XCTAssertEqual(bonus(two.situation), [4])
        let three = layer.perform(.take(choice: "zielen"), in: two.situation)
        XCTAssertEqual(three.events.map(\.kind), [.paid], "capped: the action is spent, no progress")
        XCTAssertEqual(three.texts.map(\.text), ["Nichts geändert: zielen hat alle 2 Schritte"])
        XCTAssertEqual(three.situation.processes["zielen"]?.progress, 2)
        XCTAssertEqual(bonus(three.situation), [4])

        s = three.situation
        s.rolls = [3]
        let shot = layer.perform(.attack(with: "Kurzbogen"), in: s)
        XCTAssertEqual(shot.breakdowns.first?.lines.filter { $0.origin == ref("st-aim.A1") }.map(\.value), [4],
                       "the shot reads the bonus before it breaks the process off")
        XCTAssertEqual(shot.events.filter { $0.kind == .brokenOff }.map(\.process), ["zielen"])
        XCTAssertNil(shot.situation.processes["zielen"])
        XCTAssertEqual(bonus(shot.situation), [])
    }

    /// An action that cannot be paid (no Aktion left) is not taken: the process does not advance.
    func testAnUnpaidActionAdvancesNothing() {
        let layer = ActionLayer(book: Self.state)
        var s = Self.situation(facts: ["loadout.weapon.kind": "ranged"])
        s.pools[.actions] = PoolState(current: 0, max: 1)
        let r = layer.perform(.take(choice: "zielen"), in: s)
        XCTAssertEqual(r.events, [])
        XCTAssertTrue(r.situation.processes.isEmpty)
        XCTAssertTrue(r.texts.contains { $0.text == "Nichts geändert: zielen ist nicht bezahlt, kein Vorgang geht weiter" })
    }

    /// A fact stated before the action that already makes `breaksOff` yes breaks nothing: only a
    /// `breaksOff` that turns yes does (a hero who shot last round and aims now).
    func testOnlyABreaksOffThatTurnsYesBreaksTheProcess() {
        let layer = ActionLayer(book: Self.state)
        let s = Self.situation(facts: ["loadout.weapon": "Kurzbogen", "loadout.weapon.kind": "ranged", "action.attack": "hit"])
        let aimed = layer.perform(.take(choice: "zielen"), in: s)
        XCTAssertEqual(aimed.events.map(\.kind), [.paid, .progressed])
        XCTAssertEqual(aimed.situation.processes["zielen"]?.progress, 1)
    }

    /// On the real book, Zielen's process rests on the open ruling fernkampf.zielen-interrupted:
    /// the action is paid, nothing progresses, and the ruling's text is shown.
    func testOnTheRealBookZielenRestsOnItsOpenRuling() throws {
        let layer = try real()
        let s = Self.situation(facts: ["loadout.weapon": "Kurzbogen", "loadout.weapon.kind": "ranged",
                                       "loadout.weapon.technique": "CT_2"])
        let r = layer.perform(.take(choice: "zielen"), in: s)
        XCTAssertEqual(r.events.map(\.kind), [.paid])
        XCTAssertTrue(r.texts.contains { $0.kind == .openRuling && $0.ruling == "fernkampf.zielen-interrupted" })
        XCTAssertEqual(r.notApplied.first { $0.origin == ref("fernkampf.FK11") }?.reason, .openRuling)
        XCTAssertTrue(r.situation.processes.isEmpty)
    }

    /// `.advance(process:)` for a process that neither runs nor may start says so and changes
    /// nothing; a step decoded as an event starts the process where it says.
    func testAdvancingNoProcessChangesNothing() {
        let layer = ActionLayer(book: Self.state)
        let r = layer.perform(.advance(process: "nichts"), in: Self.situation(facts: [:]))
        XCTAssertEqual(r.events, [])
        XCTAssertEqual(r.texts.map(\.text), ["Nichts geändert: kein Vorgang nichts läuft oder beginnt"])
        let started = Self.situation(facts: [:]).applying([Event(kind: .progressed, origin: ref("st-aim.A1"), process: "zielen",
                                                                 progress: 1, steps: 2, index: .top(1))])
        XCTAssertEqual(started.processes["zielen"]?.origin, EffectOrigin(rule: "st-aim", clause: "A1", index: .top(1)))
        XCTAssertNil(started.applying([Event(kind: .brokenOff, process: "zielen")]).processes["zielen"])
    }
}
