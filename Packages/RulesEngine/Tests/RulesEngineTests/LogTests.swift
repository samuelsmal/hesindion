import XCTest
@testable import RulesEngine

/// The log and its export (spec §8, plan Task 29): a `LogEntry` holds everything §8 lists, the
/// log exports as JSON Lines, and one entry exports as a situations-file draft (§10.1) whose
/// compiled form reproduces the entry's breakdowns.
final class LogTests: XCTestCase {
    private static let date = Date(timeIntervalSince1970: 1_790_000_000)       // 2026-09-21T14:13:20Z
    private static let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000029")!

    private func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }

    /// The real book and situations (`make rules-json`), or a skip.
    private func real() throws -> (Engine, CompiledSituations) {
        let rulesURL = Repo.url("build/rules/rules.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: rulesURL.path), "run make rules-json")
        let all = try XCTUnwrap(try CompiledSituations.load(from: Repo.url("build/rules/situations.json")), "run make rules-json")
        return (Engine(book: try RuleBook.load(from: rulesURL)), all)
    }

    /// One event of every kind, each with the fields its kind fills (R53, R56 included).
    private var everyEvent: [Event] {
        [
            Event(kind: .paid, origin: ref("SA_74.VP1"), pool: .asp, amount: 3, via: [ref("kampfwerte.KW1")],
                  rulings: ["shared.round-up"], facts: [FactUse(name: "check.result", value: "success", owner: .roll)]),
            Event(kind: .damaged, origin: ref("schaden.S2"), pool: .le, amount: 7),
            Event(kind: .progressed, origin: ref("ladezeiten.LZ2"), process: "laden", item: "armbrust-1", progress: 1,
                  steps: 2, index: .top(0)),
            Event(kind: .completed, process: "laden"),
            Event(kind: .brokenOff, process: "zielen"),
            Event(kind: .itemChanged, amount: -3, item: "schild-1", change: ["structurePoints": 12, "damaged": true]),
            Event(kind: .gained, origin: ref("COND_1.B4"), rule: "STATE_10", levels: 1, span: .round),
            Event(kind: .cleared, rule: "COND_6", levels: 2),
            Event(kind: .clockAdvanced, minutes: 5, rounds: 1, ends: [.action, .round]),
            Event(kind: .stated, fact: "round.previousDefenceCrit", value: true, owner: .round),
            Event(kind: .stated, fact: "loadout.weapon", value: .null, owner: .loadout),
            Event(kind: .logged, note: "n"),
        ]
    }

    /// A situation with every part of the state over time filled (extra 1).
    private var fullSituation: Situation {
        var s = Situation(owned: ["SA_41": OwnedRule(level: 2), "SA_9": OwnedRule(level: 1, option: "TAL_10", option2: 3)],
                          facts: [Fact(name: "choice.formation", value: true, owner: .player),
                                  Fact(name: "gmFact.fromBehind", value: false, owner: .gm),
                                  Fact(name: "round.parries", value: 1, owner: .round),
                                  Fact(name: "loadout.weapon", value: "Langschwert", owner: .loadout),
                                  Fact(name: "item.armbrust-1.loaded", value: true, owner: .loadout),
                                  Fact(name: "hit.zone", value: "kopf", owner: .roll),
                                  Fact(name: "attr.MU", value: 14, owner: .sheet)],
                          base: ["at(with: Langschwert)": 14, "leCurrent": 20],
                          rolls: [12, 3], pools: [.le: PoolState(current: 20, max: 29), .kap: PoolState(current: 4, max: 10)],
                          heroId: "hero-1")
        s.processes["laden"] = ProcessState(id: "laden", rule: "ladezeiten", origin: EffectOrigin(rule: "ladezeiten", clause: "LZ2", index: .top(0)),
                                            progress: 1, steps: 2, startedRound: 1, instance: "armbrust-1")
        s.clock = Clock(round: 3, minutes: 10)
        s.timed = [TimedChange(rule: "STATE_10", levels: 1, span: .round, origin: ref("COND_1.B4"))]
        s.unstated = ["hero.levelOf.COND_1"]
        return s
    }

    private func actionEntry(action: Action = .endRound) -> LogEntry {
        LogEntry(id: Self.uuid, date: Self.date, kind: .action, action: action, situation: fullSituation, breakdowns: [],
                 offersTaken: ["formation"], answers: ["gmFact.fromBehind": false, "hit.zone": "kopf"], rolls: [12, 3],
                 rerolls: [RerolledDie(die: 1, old: 19, new: 11, counts: 11, origin: ref("ADV_4.B1"))],
                 events: everyEvent, appVersion: "1.2.3 (45)", rulesSha256: String(repeating: "a", count: 64),
                 note: "das war falsch", flagged: true)
    }

    // MARK: - LogEntry

    func testAnEntryHoldsEverythingInSection8AndRoundTrips() throws {
        let entry = actionEntry()
        XCTAssertEqual(entry.heroId, "hero-1", "the hero file id comes from the situation")
        XCTAssertEqual(entry.vocabularyVersion, Vocabulary.version)
        XCTAssertEqual(entry.situation.unstated, [], "the evaluator's own fields are not logged")
        let text = LogExport.jsonLines([entry])
        let back = try LogExport.entries(fromJSONLines: text)
        XCTAssertEqual(back, [entry])
        XCTAssertEqual(back.first?.events.map(\.kind), everyEvent.map(\.kind))
        XCTAssertEqual(back.first?.situation.processes, entry.situation.processes)
        XCTAssertEqual(back.first?.situation.items["armbrust-1"]?.loaded, true)
        XCTAssertEqual(back.first?.situation.clock, Clock(round: 3, minutes: 10))
        XCTAssertEqual(back.first?.situation.pools[.kap], PoolState(current: 4, max: 10))
        // Every §8 field is in the JSON.
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["id", "date", "kind", "action", "situation", "breakdowns", "offersTaken", "answers",
                                          "rolls", "rerolls", "events", "appVersion", "rulesSha256", "vocabularyVersion",
                                          "heroId", "note", "flagged"])
        let situation = try XCTUnwrap(object["situation"] as? [String: Any])
        XCTAssertEqual(Set(situation.keys), ["owned", "facts", "base", "rolls", "pools", "processes", "items", "clock", "timed", "heroId"],
                       "complete, and without unstated or inForce")
    }

    func testEveryEventKindIsExported() throws {
        let kinds = Set(actionEntry().events.map(\.kind))
        XCTAssertEqual(kinds, Set(EventKind.allCases))
        let line = LogExport.jsonLines([actionEntry()])
        for kind in EventKind.allCases { XCTAssertTrue(line.contains("\"kind\":\"\(kind.rawValue)\""), kind.rawValue) }
    }

    func testEveryActionRoundTrips() throws {
        let actions: [Action] = [
            .cast(spell: "SPELL_21", modifications: ["gesteWeglassen"]), .pay(.asp, 3), .state(rule: "COND_6", levels: -1),
            .take(choice: "laden"), .check(CheckRequest(kind: .talent, id: "TAL_10", attributes: ["MU", "IN", "KK"], application: "x")),
            .check(CheckRequest(kind: .spell, id: "SPELL_21", attributes: ["KL", "IN", "IN"])),
            .attack(with: nil), .attack(with: "Langschwert"), .defend(kind: .pa, with: "shield"), .defend(kind: .aw),
            .takeHit(tp: 7, zone: "kopf", side: "links", failedDefence: true), .takeHit(tp: nil),
            .advance(process: "zielen"), .advanceClock(minutes: 5), .endRound, .endFight, .settle,
        ]
        for a in actions {
            let data = try JSONEncoder().encode(a)
            XCTAssertEqual(try JSONDecoder().decode(Action.self, from: data), a, String(decoding: data, as: UTF8.self))
        }
        let pay = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Action.pay(.asp, 3))) as? [String: Any]
        XCTAssertEqual(pay?["pay"] as? [String: AnyHashable], ["pool": "asp", "amount": 3])
    }

    func testAnActionIsRecordedWithItsEventsAndBreakdowns() throws {
        let engine = Engine(book: PoolTests.book)
        let before = PoolTests.situation(pools: [.asp: PoolState(current: 5, max: 30)])
        let result = ActionLayer(engine: engine).perform(.pay(.asp, 3), in: before)
        let entry = LogEntry.action(.pay(.asp, 3), before: before, result: result, book: engine.book, appVersion: "t",
                                    id: Self.uuid, date: Self.date)
        XCTAssertEqual(entry.kind, .action)
        XCTAssertEqual(entry.action, .pay(.asp, 3))
        XCTAssertEqual(entry.situation, before)
        XCTAssertEqual(entry.events, result.events)
        XCTAssertEqual(entry.breakdowns, result.breakdowns)
        XCTAssertEqual(entry.rulesSha256, engine.book.sha256)
        XCTAssertEqual(try LogExport.entries(fromJSONLines: LogExport.jsonLines([entry])), [entry])
    }

    // MARK: - JSON Lines

    func testJSONLinesAreOneSortedEntryPerLineWithISODates() throws {
        var second = actionEntry(action: .settle)
        second.id = UUID(uuidString: "00000000-0000-0000-0000-000000000030")!
        let text = LogExport.jsonLines([actionEntry(), second])
        XCTAssertTrue(text.hasSuffix("\n"))
        let lines = text.dropLast().split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.count, 2)
        for line in lines {
            // Read as plain JSON and written again with sorted keys, the line is the same text: its
            // keys are sorted at every level, by code point (`SA_41` before `SA_9`, as Python's
            // `sort_keys`).
            let object = try JSONDecoder().decode(JSONValue.self, from: Data(line.utf8))
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            XCTAssertEqual(String(decoding: try encoder.encode(object), as: UTF8.self), String(line))
            let a = try XCTUnwrap(line.range(of: "\"SA_41\"")), b = try XCTUnwrap(line.range(of: "\"SA_9\""))
            XCTAssertLessThan(a.lowerBound, b.lowerBound)
        }
        XCTAssertTrue(text.contains("\"date\":\"2026-09-21T14:13:20Z\""))
        XCTAssertEqual(LogExport.jsonLines([]), "")
    }

    func testEveryKeyIsLowerCamelCase() throws {
        var entries = [actionEntry()]
        if let (engine, all) = try? real(), let s = all.situations.first(where: { $0.id == "19.1" }) {
            entries.append(LogEntry.query(s.expect.map { Query($0.query) }, in: s.engineSituation, engine: engine,
                                          appVersion: "t", id: Self.uuid, date: Self.date))
            XCTAssertFalse(entries[1].breakdowns.flatMap(\.offers).isEmpty, "19.1 has offers to check")
        }
        let text = LogExport.jsonLines(entries)
        var checked = 0
        for line in text.split(separator: "\n") {
            let object = try JSONSerialization.jsonObject(with: Data(line.utf8))
            let bad = KeyCase.violations(object, checked: &checked)
            XCTAssertEqual(bad, [], "keys that are no lowerCamelCase field name")
        }
        XCTAssertGreaterThan(checked, 100)
        // The walker is not blind: a field name out of case is caught, a data key is exempt.
        var n = 0
        XCTAssertEqual(KeyCase.violations(["situation": ["owned": ["SA_41": ["level": 1]]], "rules_sha": 1], checked: &n), ["rules_sha"])
        XCTAssertEqual(KeyCase.violations(["situation": ["owned": ["SA_41": ["Level": 1]]]], checked: &n), ["situation.owned.*.Level"])
        XCTAssertEqual(KeyCase.violations(["events": [["change": ["structurePoints": 1, "Bad_Field": 2]]]], checked: &n), [])
        XCTAssertEqual(KeyCase.violations(["breakdowns": [["base": ["Value": 1]]]], checked: &n), ["breakdowns.base.Value"],
                       "a breakdown's base is a line, not the situation's data map")
    }

    // MARK: - The draft

    private func draftEntry() -> LogEntry {
        let situation = Situation(
            owned: ["SA_41": OwnedRule(level: 2), "DISADV_37": OwnedRule(level: 1, option: 2), "ADV_25": OwnedRule(level: 1),
                    "COND_6": OwnedRule(level: 3), "STATE_10": OwnedRule(level: 1), "SA_9": OwnedRule(level: 1, option: "TAL_10", option2: 1)],
            facts: [Fact(name: "attr.MU", value: 14, owner: .sheet), Fact(name: "ktw.CT_12", value: 12, owner: .sheet),
                    Fact(name: "fw.TAL_10", value: 9, owner: .sheet), Fact(name: "species.le", value: 5, owner: .sheet),
                    Fact(name: "choice.formation", value: true, owner: .player),
                    Fact(name: "choice.formation.bonus", value: "on", owner: .player),
                    Fact(name: "ally.has", value: "yes", owner: .player),
                    Fact(name: "gmFact.visibility", value: "12", owner: .gm),
                    Fact(name: "rulesets", value: .array(["fokus", "no"]), owner: .gm),
                    Fact(name: "opponent.size", value: "groß", owner: .gm),
                    Fact(name: "round.parries", value: 1, owner: .round),
                    Fact(name: "loadout.weapon", value: "Rabenschnabel", owner: .loadout),
                    Fact(name: "loadout.shield", value: .null, owner: .loadout),
                    Fact(name: "hero.mounted", value: false, owner: .loadout),
                    Fact(name: "item.armbrust-1.loaded", value: true, owner: .loadout),
                    Fact(name: "hit.zone", value: "kopf", owner: .roll),
                    Fact(name: "belastung.source", value: "armour", owner: .derived)],
            base: ["at(with: Rabenschnabel)": 16, "aw": 7, "leCurrent": 30],
            rolls: [7, 12], pools: [.le: PoolState(current: 25, max: 31), .kap: PoolState(current: 2, max: 4)], heroId: "boronmir")
        let at = Breakdown(query: Query("at"),
                           base: Line(value: 16, kind: .base, owner: .sheet),
                           lines: [Line(value: 2, kind: .add, origin: ref("SA_862.F2"), rulings: ["SA_862.formation-bonus"]),
                                   Line(value: -1, kind: .add, origin: ref("COND_1.B3"), via: [ref("SA_41.G1")]),
                                   Line(value: -2, kind: .free, owner: .player),
                                   Line(value: -3, kind: .set, origin: ref("COND_6.S1"), was: 15, now: 12)])
        let leMax = Breakdown(query: Query("leMax"),
                              base: Line(value: 30, kind: .base, parts: [Line(value: 10, kind: .base, origin: ref("lebensenergie.LE1")),
                                                                         Line(value: 20, kind: .base, origin: ref("lebensenergie.LE2"))]),
                              lines: [Line(value: 1, kind: .add, origin: ref("ADV_25.A1"))])
        let rs = Breakdown(query: Query("rs(zone: kopf)"), lines: [Line(value: 2, kind: .add, origin: ref("pl-armour.A1"))])
        return LogEntry(id: Self.uuid, date: Self.date, kind: .query, query: Query("at"), situation: situation,
                        breakdowns: [at, leMax, rs], appVersion: "1.0 (1)", rulesSha256: "abc", note: "AT should be 17: \"F2\"\nsecond line")
    }

    func testTheDraftWritesEachPartInItsSection() {
        let yaml = SituationDraft.yaml(from: draftEntry(), id: "19.1", name: "on: a draft")
        // The hero: owned maps by the id's kind, the sheet's values.
        XCTAssertTrue(yaml.contains("  - id: \"19.1\"\n    name: \"on: a draft\"\n"), yaml)
        XCTAssertTrue(yaml.contains("      abilities:\n        SA_41: 2\n        SA_9:\n          level: 1\n          sid: TAL_10\n          sid2: 1\n"), yaml)
        XCTAssertTrue(yaml.contains("      advantages:\n        ADV_25: 1\n"), yaml)
        XCTAssertTrue(yaml.contains("      disadvantages:\n        DISADV_37:\n          level: 1\n          sid: 2\n"), yaml)
        XCTAssertTrue(yaml.contains("      conditions:\n        COND_6: 3\n"), yaml)
        XCTAssertTrue(yaml.contains("      states:\n        STATE_10: 1\n"), yaml)
        XCTAssertTrue(yaml.contains("      attributes:\n        MU: 14\n"), yaml)
        XCTAssertTrue(yaml.contains("      techniques:\n        CT_12: 12\n"), yaml)
        XCTAssertTrue(yaml.contains("      talents:\n        TAL_10: 9\n"), yaml)
        // The pools as the values the harness reads them from (LE 25 of 31).
        XCTAssertTrue(yaml.contains("      values:\n        \"at(with: Rabenschnabel)\": 16\n        aw: 7\n        leCurrent: 25\n        leMax: 31\n"), yaml)
        // Each fact in its owner's section; the prefixed sections drop their prefix.
        XCTAssertTrue(yaml.contains("    choose:\n      choice.formation: true\n      choice.formation.bonus: \"on\"\n    ally:\n      has: \"yes\"\n"), yaml)
        XCTAssertTrue(yaml.contains("    gm:\n      gmFact.visibility: \"12\"\n      rulesets: [fokus, \"no\"]\n    opponent:\n      size: \"groß\"\n"), yaml)
        XCTAssertTrue(yaml.contains("    round:\n      parries: 1\n"), yaml)
        XCTAssertTrue(yaml.contains("    loadout:\n      hero.mounted: false\n      item.armbrust-1.loaded: true\n      shield: null\n      weapon: Rabenschnabel\n"), yaml)
        // The dice; the roll facts beside them have no section and are left out.
        XCTAssertTrue(yaml.contains("    rolls: [7, 12]\n"), yaml)
        XCTAssertTrue(yaml.contains("hit.zone (roll)"), "a roll fact beside dice is left out, and said so")
        XCTAssertTrue(yaml.contains("belastung.source (derived)"), yaml)
        // A sheet fact outside the attribute, technique and talent maps is `hero: { sheet: … }`
        // (Task 30), which rulec reads back.
        XCTAssertTrue(yaml.contains("      sheet:\n        species.le: 5\n"), yaml)
        XCTAssertFalse(yaml.contains("species.le (sheet)"), yaml)
        XCTAssertTrue(yaml.contains("pool kap"), yaml)
        // expect: the total by the derived-base rule, the lines with from / via / ruling and the
        // value after the step for `set`; no line without a clause.
        XCTAssertTrue(yaml.contains("""
              at:
                # also shown: 16 base (sheet); -2 free (player)
                total: -4
                result: 12
                lines:
                  - from: SA_862.F2
                    value: 2
                    ruling: [SA_862.formation-bonus]
                  - from: COND_1.B3
                    value: -1
                    via: [SA_41.G1]
                  - from: COND_6.S1
                    value: 12

        """), yaml)
        XCTAssertTrue(yaml.contains("""
              leMax:
                total: 31
                result: 31
                lines:
                  - from: lebensenergie.LE1
                    value: 10
                  - from: lebensenergie.LE2
                    value: 20
                  - from: ADV_25.A1
                    value: 1

        """), yaml)
        XCTAssertTrue(yaml.contains("      \"rs(zone: kopf)\":\n        total: 2\n        lines:\n"), yaml)
        XCTAssertTrue(yaml.contains("    appToday: \"AT should be 17: \\\"F2\\\"\\nsecond line\"\n"), yaml)
    }

    func testTheYAMLQuotesWhatWouldReadAsAnotherType() {
        for s in ["on", "off", "yes", "no", "y", "n", "true", "false", "null", "~", "On", "NO", "True", "12", "-3", "1.5",
                  "19.1", "1e3", "0x1F", ".inf", "", " x", "a: b", "a #b", "[x]", "{x}", "*x", "&x", "!x", "%x", "@x", "`x",
                  "- x", "? x", "x\"y", "2026-09-25"] {
            XCTAssertTrue(SituationDraft.scalar(.string(s)).hasPrefix("\""), "\(s) must be quoted")
        }
        for s in ["at", "SA_41", "choice.formation", "Rabenschnabel", "item.armbrust-1.loaded", "TAL_10"] {
            XCTAssertEqual(SituationDraft.scalar(.string(s)), s)
        }
        XCTAssertEqual(SituationDraft.scalar(.string("groß")), "\"groß\"")
        XCTAssertEqual(SituationDraft.scalar(.int(-3)), "-3")
        XCTAssertEqual(SituationDraft.scalar(.bool(false)), "false")
        XCTAssertEqual(SituationDraft.scalar(.null), "null")
        XCTAssertEqual(SituationDraft.scalar(.string("a\\b\n\t")), "\"a\\\\b\\n\\t\"")
    }

    func testTheCompiledDraftStatesTheEntryAndMatchesItsBreakdowns() throws {
        let entry = draftEntry()
        let c = try SituationDraft.compiled(from: entry, id: "19.1", name: "n")
        XCTAssertEqual(c.id, "19.1")
        XCTAssertEqual(c.situation.owned["SA_9"], OwnedRule(level: 1, option: "TAL_10", option2: 1))
        XCTAssertEqual(c.situation.base["leCurrent"], 25)
        XCTAssertEqual(c.situation.base["leMax"], 31)
        XCTAssertEqual(c.engineSituation.pools[.le], PoolState(current: 25, max: 31))
        XCTAssertEqual(c.situation.facts["loadout.shield"], Fact(name: "loadout.shield", value: .null, owner: .loadout))
        XCTAssertEqual(c.situation.items["armbrust-1"]?.loaded, true)
        XCTAssertEqual(c.situation.facts["ally.has"]?.owner, .player)
        XCTAssertEqual(c.situation.facts["opponent.size"]?.owner, .gm)
        XCTAssertNil(c.situation.facts["hit.zone"], "left out beside dice")
        XCTAssertNil(c.situation.facts["belastung.source"])
        XCTAssertEqual(c.rolls, [7, 12])
        XCTAssertEqual(c.expect.map(\.query), ["at", "leMax", "rs(zone: kopf)"])
        XCTAssertEqual(c.expect[0].total, -4)
        XCTAssertEqual(c.expect[0].result, 12)
        XCTAssertEqual(c.expect[0].lines?.map(\.from), ["SA_862.F2", "COND_1.B3", "COND_6.S1"])
        XCTAssertEqual(c.expect[0].lines?[1].via, ["SA_41.G1"])
        XCTAssertEqual(c.expect[0].lines?[0].ruling, ["SA_862.formation-bonus"])
        XCTAssertEqual(c.expect[0].lines?[2].value, 12)
        XCTAssertEqual(c.expect[1].total, 31, "a derived base counts in the total")
        XCTAssertNil(c.expect[2].result)
        // The draft matches the breakdowns it was made from.
        let result = Matcher.compare(c, breakdowns: entry.breakdowns, offers: [], onlyQueries: true)
        XCTAssertEqual(result.mismatches, [])
    }

    func testRollFactsWithoutDiceAreTheRollsMapping() throws {
        var entry = draftEntry()
        entry.situation.rolls = []
        entry.rolls = []
        let yaml = SituationDraft.yaml(from: entry, id: "x", name: "x")
        XCTAssertTrue(yaml.contains("    rolls:\n      hit.zone: kopf\n"), yaml)
        XCTAssertEqual(try SituationDraft.compiled(from: entry).situation.facts["hit.zone"]?.owner, .roll)
    }

    // MARK: - Across languages and the round trip

    /// Record-style (like the app's `RuleVocabularyTests`): the draft of situation 19.1 is
    /// written to `scripts/rulec/fixtures/draft-from-log.yaml`; a change fails once. rulec's
    /// `test_draft_fixture.py` compiles that file against the real rules.
    func testTheDraftOf19_1IsRecordedForRulec() throws {
        let (engine, all) = try real()
        let s = try XCTUnwrap(all.situations.first { $0.id == "19.1" })
        let entry = LogEntry.query(s.expect.map { Query($0.query) }, in: s.engineSituation, engine: engine,
                                   appVersion: "fixture",
                                   note: "das war falsch: Belastung (COND_1.B3) zieht 3 statt 1 ab, Rüstungsgewöhnung "
                                       + "(SA_41.G1) wird nicht angerechnet, und AT und PA haben keinen Basiswert (Rabenschnabel 16/11)",
                                   flagged: true, id: Self.uuid, date: Self.date)
        let fresh = SituationDraft.yaml(from: entry, id: s.id + "-draft", name: s.name ?? s.id)
        let url = Repo.url("scripts/rulec/fixtures/draft-from-log.yaml")
        let onDisk = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if onDisk != fresh {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fresh.write(to: url, atomically: true, encoding: .utf8)
            XCTFail("scripts/rulec/fixtures/draft-from-log.yaml did not match the draft of 19.1; it has been rewritten — commit it and rerun")
        }
    }

    /// For every situation the harness passes: run it → `LogEntry` → JSON Lines → read back →
    /// `SituationDraft.compiled` → run again. The breakdowns are equal, the situation is the
    /// same, and the draft passes the harness's Matcher against the run.
    ///
    /// Each draft's YAML and its compiled object are written to `build/rules/drafts/` (`<id>.yaml`,
    /// `<id>.json`): rulec's `test_draft_fixture.py` reads every YAML back and checks it compiles to that
    /// object, so the draft re-imports as the situation (§8). `make test-rules-engine` writes them;
    /// run it before `make test-rulec`.
    func testEveryPassingSituationRoundTrips() throws {
        let (engine, all) = try real()
        let drafts = Repo.url("build/rules/drafts")
        try? FileManager.default.removeItem(at: drafts)
        try FileManager.default.createDirectory(at: drafts, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let conflicts = Set(SituationsHarnessTests.conflicts(all) ?? [])
        var passing = 0, withQueries = 0
        for s in all.situations {
            guard SituationsHarnessTests.judge(s, engine: engine, conflicts: conflicts).verdict == .passed else { continue }
            passing += 1
            let situation = s.engineSituation
            let entry = LogEntry.query(s.expect.map { Query($0.query) }, in: situation, engine: engine, appVersion: "t",
                                       id: Self.uuid, date: Self.date)
            let read = try LogExport.entries(fromJSONLines: LogExport.jsonLines([entry]))
            XCTAssertEqual(read, [entry], "\(s.id): the export reads back as the entry")
            guard let back = read.first else { continue }
            let draft = try SituationDraft.compiled(from: back, id: s.id, name: s.name ?? s.id)
            try SituationDraft.yaml(from: back, id: s.id, name: s.name ?? s.id)
                .write(to: drafts.appending(path: "\(s.id).yaml"), atomically: true, encoding: .utf8)
            try encoder.encode(SituationDraft.compiledJSON(from: back, id: s.id, name: s.name ?? s.id))
                .write(to: drafts.appending(path: "\(s.id).json"))
            XCTAssertEqual(draft.engineSituation, situation, "\(s.id): the draft states the same situation")
            let again = draft.expect.map { engine.evaluate(Query($0.query), in: draft.engineSituation) }
            XCTAssertEqual(again, entry.breakdowns, "\(s.id): the draft runs to the same breakdowns")
            if !draft.expect.isEmpty {
                withQueries += 1
                let mismatches = Matcher.run(draft, engine: engine, onlyQueries: true).mismatches
                XCTAssertEqual(mismatches.map(\.description), [], "\(s.id): the draft matches its run")
            }
        }
        print("log round trip: \(passing) passing situations, all round-trip (\(withQueries) with queries)")
        XCTAssertGreaterThan(passing, 0)
    }
}

/// The key-case check (extra 7): every key of the export is a lowerCamelCase field name, except
/// the keys of the data maps, which are names and query strings (`SA_41`, `at(with: X)`,
/// `hit.tp`), and inside the JSON values a fact or an option holds. Paths are the keys from the
/// entry down, arrays skipped, a data map's key as `*`.
enum KeyCase {
    /// `^[a-z][a-zA-Z0-9]*$`.
    static func isLowerCamel(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first, ("a"..."z").contains(first) else { return false }
        return key.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("A"..."Z").contains($0) || ("0"..."9").contains($0) }
    }
    /// Objects whose keys are data.
    static let dataMaps: [[String]] = [
        ["situation", "owned"], ["situation", "base"], ["situation", "pools"], ["situation", "processes"],
        ["situation", "items"], ["answers"], ["events", "change"],
    ]
    /// Values that are data (`JSONValue`): not walked. `**` is any prefix.
    static let dataValues: [[String]] = [
        ["**", "facts", "value"], ["events", "value"], ["situation", "owned", "*", "option"],
        ["situation", "owned", "*", "option2"], ["**", "offers", "options"], ["**", "offers", "default"],
        ["**", "refused", "option"], ["**", "questions", "options"], ["answers", "*"], ["events", "change", "*"],
    ]

    static func violations(_ json: Any, checked: inout Int) -> [String] {
        var out: [String] = []
        walk(json, [], &out, &checked)
        return out
    }

    private static func walk(_ json: Any, _ path: [String], _ out: inout [String], _ checked: inout Int) {
        if let array = json as? [Any] {
            array.forEach { walk($0, path, &out, &checked) }
            return
        }
        guard let object = json as? [String: Any] else { return }
        let data = dataMaps.contains(path)
        for (key, value) in object {
            if !data {
                checked += 1
                if !isLowerCamel(key) { out.append((path + [key]).joined(separator: ".")) }
            }
            let child = path + [data ? "*" : key]
            if dataValues.contains(where: { matches($0, child) }) { continue }
            walk(value, child, &out, &checked)
        }
    }

    private static func matches(_ pattern: [String], _ path: [String]) -> Bool {
        if pattern.first == "**" {
            let tail = Array(pattern.dropFirst())
            return path.count >= tail.count && Array(path.suffix(tail.count)) == tail
        }
        return pattern == path
    }
}
