import XCTest
@testable import RulesEngine

/// Item state (spec §7, plan Task 28): keyed by instance (`item.<instance>.*`), never by name.
/// The rules read the item in a slot (`loadout.weapon.loaded`) through `loadout.<slot>.instance`;
/// `item { instance, change }` gives `itemChanged`; a shield's current StP go down with
/// Schildspalter, and at 0 it is destroyed and leaves the loadout.
final class ItemStateTests: XCTestCase {
    private var layer: ActionLayer { ActionLayer(book: ProcessTests.state) }
    private func ref(_ s: String) -> ClauseRef { ClauseRef(s)! }
    private func situation(_ facts: [String: JSONValue], base: [String: Int] = [:], owned: [String: OwnedRule] = [:]) -> Situation {
        ProcessTests.situation(owned: owned, facts: facts, base: base)
    }

    /// Two identical daggers are two items: a Dolch in each hand, instances dolch1 and dolch2. A
    /// missed stroke damages the one in the weapon hand only.
    func testTwoIdenticalDaggersAreTwoItems() {
        var s = situation(["loadout.weapon": "Dolch", "loadout.weapon.kind": "melee", "loadout.weapon.instance": "dolch1",
                           "loadout.other": "Dolch", "loadout.other.instance": "dolch2",
                           "item.dolch1.held": true, "item.dolch2.held": true], base: ["at": 10])
        XCTAssertEqual(s.items, ["dolch1": ItemState(held: true), "dolch2": ItemState(held: true)])
        XCTAssertNil(s.facts["item.dolch1.held"], "an item field is item state, not a loose fact")
        s.rolls = [19]
        let miss = layer.perform(.attack(with: "Dolch"), in: s)
        let change = miss.events.filter { $0.kind == .itemChanged }
        XCTAssertEqual(change.map(\.item), ["dolch1"])
        XCTAssertEqual(change.first?.change, ["damaged": .bool(true)])
        XCTAssertEqual(change.first?.origin, ref("st-dagger.D1"))
        XCTAssertTrue(change.first?.facts.contains { $0.name == "loadout.weapon.instance" && $0.value == "dolch1" } ?? false)
        let after = miss.situation
        XCTAssertEqual(after.items["dolch1"], ItemState(damaged: true, held: true))
        XCTAssertEqual(after.items["dolch2"], ItemState(held: true))
        XCTAssertEqual(after.fact("item.dolch1.damaged")?.value, .bool(true))
        XCTAssertNil(after.fact("item.dolch2.damaged"))
        XCTAssertEqual(after.fact("loadout.weapon.damaged")?.value, .bool(true))
        XCTAssertNil(after.fact("loadout.other.damaged"), "the other dagger is another item")
        // Swapping hands: the weapon hand now holds the whole one.
        var swapped = after
        swapped.state(Fact(name: "loadout.weapon.instance", value: "dolch2", owner: .loadout))
        swapped.state(Fact(name: "loadout.other.instance", value: "dolch1", owner: .loadout))
        XCTAssertNil(swapped.fact("loadout.weapon.damaged"))
        XCTAssertEqual(swapped.fact("loadout.other.damaged")?.value, .bool(true))
    }

    /// A slot without a stated instance cannot be changed: the instance is asked, no event.
    func testAnItemEffectWithoutAnInstanceAsksForIt() {
        var s = situation(["loadout.weapon": "Dolch", "loadout.weapon.kind": "melee"], base: ["at": 10])
        s.rolls = [19]
        let miss = layer.perform(.attack(with: "Dolch"), in: s)
        XCTAssertEqual(miss.events.filter { $0.kind == .itemChanged }, [])
        XCTAssertTrue(miss.questions.contains { $0.fact == "loadout.weapon.instance" && $0.origins == [ref("st-dagger.D1")] })
    }

    /// Schildspalter's shape (st-split = SA_59.SS3): the TP of the hit come off the shield's
    /// current StP (a change: `{ of: hit.tp, times: -1 }`); at 0 or below the shield is destroyed
    /// and leaves the loadout.
    func testASchildspalterLowersTheShieldsStPAndAtZeroDestroysIt() throws {
        let s = situation(["loadout.shield": "Großschild", "loadout.shield.instance": "schild1", "loadout.shield.structurePoints": 10,
                           "opponent.manoeuvre": "schildspalter", "check.result": "failure"])
        let first = layer.perform(.takeHit(tp: 7), in: s)
        let lowered = first.events.filter { $0.kind == .itemChanged }
        XCTAssertEqual(lowered.count, 1)
        XCTAssertEqual(lowered.first?.item, "schild1")
        XCTAssertEqual(lowered.first?.change, ["structurePoints": .int(3)])
        XCTAssertEqual(lowered.first?.amount, -7)
        XCTAssertEqual(lowered.first?.origin, ref("st-split.S1"))
        XCTAssertEqual(first.situation.items["schild1"]?.structurePoints, 3)
        XCTAssertEqual(first.situation.fact("loadout.shield.structurePoints")?.value, .int(3))
        XCTAssertEqual(first.notApplied.first { $0.origin == ref("st-split.S1") && $0.reason == .conditionFalse }?.facts
                        .first { $0.name == "loadout.shield.structurePoints" }?.value, .int(3),
                       "the destruction reads the StP after the change")

        let second = layer.perform(.takeHit(tp: 5), in: first.situation)
        let changes = second.events.filter { $0.kind == .itemChanged }
        XCTAssertEqual(changes.map(\.change), [["structurePoints": .int(-2)], ["destroyed": .bool(true)]])
        let after = second.situation
        XCTAssertEqual(after.items["schild1"], ItemState(structurePoints: -2, destroyed: true))
        XCTAssertEqual(after.facts["loadout.shield"]?.value, .null, "the shield leaves the loadout")
        XCTAssertNil(after.facts["loadout.shield.instance"])
        XCTAssertNil(after.fact("loadout.shield.structurePoints"))
    }

    /// Without the shield's current StP (no state, none stated) the change is asked, not guessed.
    func testUnknownStructurePointsAreAsked() {
        let s = situation(["loadout.shield": "Großschild", "loadout.shield.instance": "schild1",
                           "opponent.manoeuvre": "schildspalter", "check.result": "failure"])
        let r = layer.perform(.takeHit(tp: 7), in: s)
        XCTAssertEqual(r.events.filter { $0.kind == .itemChanged }, [])
        XCTAssertTrue(r.questions.contains { $0.fact == "loadout.shield.structurePoints" })
    }

    /// On the real book (the hero owns SA_59; the opponent's Schildspalter, the defence failed): the
    /// hit's TP come off the Großschild's StP from SA_59.SS3, on its ruling, and none reach LeP.
    func testOnTheRealBookSchildspalterTakesTheTPOffTheShield() throws {
        let layer = ActionLayer(engine: try XCTUnwrap(CombatRollTests.real, "run make rules-json"))
        var s = situation(["loadout.shield": "Großschild", "loadout.shield.instance": "grossschild1",
                           "loadout.shield.structurePoints": 30, "opponent.manoeuvre": "schildspalter", "check.result": "failure"],
                          owned: ["SA_59": OwnedRule(level: 1)])
        s.pools[.le] = PoolState(current: 30, max: 30)
        let r = layer.perform(.takeHit(tp: 7), in: s)
        let change = try XCTUnwrap(r.events.first { $0.kind == .itemChanged })
        XCTAssertEqual(change.origin, ref("SA_59.SS3"))
        XCTAssertEqual(change.change, ["structurePoints": .int(23)])
        XCTAssertEqual(change.rulings, ["SA_59.schildspalter-against-hero"])
        XCTAssertEqual(r.events.filter { $0.kind == .damaged }, [], "SS3 suppresses schaden.S1/S2: no LeP lost")
        XCTAssertEqual(r.situation.pools[.le]?.current, 30)
        XCTAssertEqual(r.situation.items["grossschild1"]?.structurePoints, 23)
    }

    /// The compiled situations keep decoding: an `item.<instance>.loaded` fact becomes the
    /// instance's state, which `loadout.weapon.loaded` reads (probe-fernkampf 21.8). The state
    /// over time round-trips through JSON.
    func testTheCompiledSituationsDecodeAndTheStateRoundTrips() throws {
        let all = try XCTUnwrap(try CompiledSituations.load(from: Repo.url("build/rules/situations.json")), "run make rules-json")
        XCTAssertEqual(all.situations.count, 309)
        let s = try XCTUnwrap(all.situations.first { $0.id == "21.8" }).situation
        XCTAssertEqual(s.items, ["kurzbogen1": ItemState(loaded: false)])
        XCTAssertEqual(s.fact("loadout.weapon.loaded")?.value, .bool(false))
        XCTAssertEqual(s.fact("loadout.weapon.loaded")?.owner, .loadout)
        XCTAssertNil(s.facts["item.kurzbogen1.loaded"])
        for c in all.situations {
            XCTAssertEqual(try JSONDecoder().decode(Situation.self, from: JSONEncoder().encode(c.situation)), c.situation, c.id)
        }

        var full = s
        full.processes["laden"] = ProcessState(id: "laden", rule: "ladezeiten", origin: EffectOrigin(rule: "ladezeiten", clause: "LZ2", index: .top(1)),
                                               progress: 1, steps: 2, startedRound: 3, instance: "kurzbogen1")
        full.items["schild1"] = ItemState(structurePoints: 12, destroyed: false)
        full.clock = Clock(round: 4, minutes: 95)
        full.timed = [TimedChange(rule: "COND_2", levels: 1, span: .round, origin: ref("zustaende.Z5"))]
        let data = try JSONEncoder().encode(full)
        XCTAssertEqual(try JSONDecoder().decode(Situation.self, from: data), full)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual((object["clock"] as? [String: Int]), ["round": 4, "minutes": 95])
        XCTAssertEqual(((object["items"] as? [String: Any])?["kurzbogen1"] as? [String: Bool]), ["loaded": false])
        XCTAssertNotNil((object["processes"] as? [String: Any])?["laden"])
    }

    /// `itemChanged` sets each field of its change on the instance, and an event decoded from JSON
    /// applies as a computed one does.
    func testApplyingAnItemChangeSetsItsFields() throws {
        let s = situation(["loadout.weapon": "Kurzbogen", "loadout.weapon.instance": "bogen1", "item.bogen1.strung": false])
        let json = #"{"kind":"itemChanged","item":"bogen1","change":{"strung":true,"damaged":false}}"#
        let e = try JSONDecoder().decode(Event.self, from: Data(json.utf8))
        let after = s.applying([e])
        XCTAssertEqual(after.items["bogen1"], ItemState(strung: true, damaged: false))
        XCTAssertEqual(after.fact("loadout.weapon.strung")?.value, .bool(true))
        XCTAssertEqual(try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(e)), e)
    }

    /// The Wundeffekt's arm drop (trefferzonen.TZ8's `onFailure` `item`, Task 27 carry): a failed
    /// Selbstbeherrschung after a hit on the weapon arm gives `itemChanged(held: false)` on the
    /// weapon's instance, on its ruling, where Task 27 showed a §11 text.
    func testAFailedWundeffektCheckDropsTheWeaponFromTheHitArm() throws {
        let engine = try XCTUnwrap(CombatRollTests.real, "run make rules-json")
        let s = situation(["attr.KO": 11, "attr.MU": 14, "fw.TAL_8": 9, "rulesets": .array(["fokus.trefferzonen"]),
                           "loadout.weapon": "Langschwert", "loadout.weapon.instance": "schwert1", "loadout.twoHanded": false,
                           "hit.heldInHand": "weapon"],
                          base: ["sp": 6, "wundschwelle": 6])
        let chain = DamageChain.run(hit: nil, zone: "arme", side: "rechts", in: s, engine: engine)
        let check = try XCTUnwrap(chain.checks.first)
        let failed = CheckProcedure.start(check.request(attributes: ["MU", "MU", "KO"]), in: check.situation, engine: engine)
            .state.step(.outcome(success: false), engine: engine)
        let drop = try XCTUnwrap(failed.events.first { $0.kind == .itemChanged })
        XCTAssertEqual(drop.item, "schwert1")
        XCTAssertEqual(drop.change, ["held": .bool(false)])
        XCTAssertEqual(drop.origin, ref("trefferzonen.TZ8"))
        XCTAssertEqual(drop.rulings, ["trefferzonen.wundeffekt-arm-drop"])
        XCTAssertFalse(failed.texts.contains { $0.text.contains("nicht ausgeführt") })
        XCTAssertEqual(check.situation.applying(failed.events).fact("loadout.weapon.held")?.value, .bool(false))
    }

    /// R58, across two actions on the real book: a shield parry against Schildspalter fails, then
    /// the hit comes through it. The parry's outcome is its own roll's (it does not outlive it);
    /// the hit carries it (`failedDefence`), and SA_59.SS3 takes the TP off the shield's StP.
    func testAFailedShieldParryThenTheHitLowersTheShieldsStP() throws {
        let layer = ActionLayer(engine: try XCTUnwrap(CombatRollTests.real, "run make rules-json"))
        var s = situation(["loadout.shield": "Großschild", "loadout.shield.instance": "grossschild1",
                           "loadout.shield.structurePoints": 30, "opponent.manoeuvre": "schildspalter"],
                          base: ["pa(with: shield)": 7], owned: ["SA_59": OwnedRule(level: 1)])
        s.pools[.le] = PoolState(current: 30, max: 30)
        s.rolls = [15]
        let parry = layer.perform(.defend(kind: .pa, with: "shield"), in: s)
        XCTAssertNil(parry.situation.facts["roll.defence"], "the parry's die is its own")
        XCTAssertNil(parry.situation.facts["check.result"])
        var next = parry.situation
        next.rolls = []
        let hit = layer.perform(.takeHit(tp: 7, failedDefence: true), in: next)
        let change = try XCTUnwrap(hit.events.first { $0.kind == .itemChanged })
        XCTAssertEqual(change.origin, ref("SA_59.SS3"))
        XCTAssertEqual(change.change, ["structurePoints": .int(23)])
        XCTAssertEqual(hit.situation.items["grossschild1"]?.structurePoints, 23)
        XCTAssertEqual(hit.situation.pools[.le]?.current, 30, "the TP go on the shield, not the LeP")
        XCTAssertNil(hit.situation.facts["check.result"], "the carried outcome is the hit's input only")
        // Without the failed defence the hit does not reach the shield.
        let plain = layer.perform(.takeHit(tp: 7), in: next)
        XCTAssertEqual(plain.events.filter { $0.kind == .itemChanged }, [])
    }
}
