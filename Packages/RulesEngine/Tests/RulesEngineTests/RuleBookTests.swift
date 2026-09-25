import XCTest
@testable import RulesEngine

final class RuleBookTests: XCTestCase {
    private var fixtureURL: URL { Bundle.module.url(forResource: "mini-rules", withExtension: "json", subdirectory: "Fixtures")! }
    private func mini() throws -> RuleBook { try RuleBook.load(from: fixtureURL) }

    /// The effect of the fixture at `rule.clause` index `i` (a top-level effect).
    private func effect(_ book: RuleBook, _ rule: String, _ clause: String, _ i: Int) throws -> Effect {
        try XCTUnwrap(book.effect(at: EffectOrigin(rule: rule, clause: clause, index: .top(i))))
    }

    // MARK: - The brief's tests

    func testEveryVerbDecodesToItsPayload() throws {
        let book = try mini()
        let verbs = Set(book.rules.values.flatMap { $0.clauses.flatMap(\.effects) }.map(\.payload.verb))
        XCTAssertEqual(verbs, Set(Verb.allCases))
    }

    func testAnotherVocabularyIsRefused() throws {
        var raw = try String(contentsOf: fixtureURL, encoding: .utf8)
        XCTAssertTrue(raw.contains("\"vocabularyVersion\": 1"))
        raw = raw.replacingOccurrences(of: "\"vocabularyVersion\": 1", with: "\"vocabularyVersion\": 99")
        XCTAssertThrowsError(try RuleBook.decode(Data(raw.utf8))) {
            XCTAssertEqual($0 as? RuleBookError, .vocabularyMismatch(found: 99, expected: Vocabulary.version))
        }
    }

    func testTheRealBookDecodes() throws {
        let url = Repo.url("build/rules/rules.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "run make rules-json")
        let book = try RuleBook.load(from: url)
        XCTAssertNotNil(book.rules["SA_862"])
        XCTAssertFalse(book.effects(reaching: "at").isEmpty)
    }

    func testTargetRefRoundTrips() {
        XCTAssertEqual(TargetRef("pa(with: shield)").description, "pa(with: shield)")
        XCTAssertEqual(TargetRef("pa").description, "pa")
        XCTAssertEqual(TargetRef("pa(with: shield)"), TargetRef(name: "pa", context: ["with": "shield"]))
        XCTAssertTrue(TargetRef("pa").matches(TargetRef("pa(with: shield)")))
        XCTAssertFalse(TargetRef("pa(with: weapon)").matches(TargetRef("pa(with: shield)")))
        XCTAssertTrue(TargetRef("pa(with: shield)").matches(TargetRef("pa(with: shield)")))
        XCTAssertFalse(TargetRef("pa(with: shield)").matches(TargetRef("pa")))
        XCTAssertFalse(TargetRef("at").matches(TargetRef("pa")))
    }

    func testEffectsReachingAreTheIndexedOnesPlusStar() throws {
        let book = try mini()
        let pa = try XCTUnwrap(book.reach["pa"]), star = try XCTUnwrap(book.reach["*"])
        XCTAssertEqual(book.effects(reaching: "pa").map(\.origin), pa + star)
        XCTAssertEqual(book.effects(reaching: "*").map(\.origin), star)
        XCTAssertEqual(book.effects(reaching: "nothing").map(\.origin), star)
    }

    // MARK: - The real book: every effect is typed and loses nothing

    /// Every effect of `rules.json`, nested ones included, decodes into its typed payload, and
    /// encoding that payload back gives the very JSON the compiler wrote: no field is dropped
    /// by the decoder or held as an untyped JSONValue behind the verb's struct.
    func testEveryEffectOfTheRealBookIsTypedAndLosesNothing() throws {
        let url = Repo.url("build/rules/rules.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "run make rules-json")
        try assertEveryEffectRoundTrips(Data(contentsOf: url))
    }

    func testEveryEffectOfTheFixtureIsTypedAndLosesNothing() throws {
        try assertEveryEffectRoundTrips(Data(contentsOf: fixtureURL))
    }

    private func assertEveryEffectRoundTrips(_ data: Data, file: StaticString = #filePath, line: UInt = #line) throws {
        let book = try RuleBook.decode(data)
        let raw = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case .object(let top) = raw, case .array(let rules)? = top["rules"] else {
            return XCTFail("rules.json has no rules list", file: file, line: line)
        }
        var rawEffects: [JSONValue] = []
        func collect(_ effect: JSONValue) {
            rawEffects.append(effect)
            guard case .object(let e) = effect, case .object(let payload)? = e["payload"] else { return }
            for value in payload.values {
                if case .array(let items) = value, items.allSatisfy(Self.isEffect), !items.isEmpty {
                    items.forEach(collect)
                }
            }
        }
        for case .object(let rule) in rules {
            guard case .array(let clauses)? = rule["clauses"] else { continue }
            for case .object(let clause) in clauses {
                if case .array(let effects)? = clause["effects"] { effects.forEach(collect) }
            }
        }
        XCTAssertFalse(rawEffects.isEmpty, file: file, line: line)

        var verbs = Set<Verb>()
        for rawEffect in rawEffects {
            let typed = try JSONDecoder().decode(Effect.self, from: JSONEncoder().encode(rawEffect))
            verbs.insert(typed.payload.verb)
            // Found by its origin in the book, nested effects too.
            XCTAssertEqual(book.effect(at: typed.origin), typed, "\(typed.origin)", file: file, line: line)
            let back = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(typed))
            XCTAssertEqual(back.numbersAsDoubles, rawEffect.numbersAsDoubles,
                           "\(typed.origin) does not round-trip", file: file, line: line)
        }
        XCTAssertFalse(verbs.isEmpty, file: file, line: line)
    }

    private static func isEffect(_ v: JSONValue) -> Bool {
        if case .object(let o) = v { return o["verb"] != nil && o["payload"] != nil && o["origin"] != nil }
        return false
    }

    // MARK: - The fixture's shapes, one by one

    func testTheBooksTopLevel() throws {
        let book = try mini()
        XCTAssertEqual(Set(book.rules.keys), ["mini-core", "mini-levelled"])
        XCTAssertEqual(book.vocabularyVersion, Vocabulary.version)
        XCTAssertEqual(book.vocabularySha256.count, 64)
        XCTAssertEqual(book.sha256, SHA256.hex(try Data(contentsOf: fixtureURL)))
        XCTAssertEqual(book.sha256.count, 64)
    }

    func testSHA256KnownVectors() {
        XCTAssertEqual(SHA256.hex(Data()), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(SHA256.hex(Data("abc".utf8)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(SHA256.hex(Data("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)),
                       "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
        XCTAssertEqual(SHA256.hex(Data(repeating: 0x61, count: 1_000)),
                       "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3")
    }

    func testRuleMetadata() throws {
        let book = try mini()
        let l = try XCTUnwrap(book.rules["mini-levelled"])
        XCTAssertEqual(l.name, "Gestufte Fertigkeit")
        XCTAssertEqual(l.kind, .specialAbility)
        XCTAssertEqual(l.group, "Kampfsonderfertigkeiten")
        XCTAssertEqual(l.levels, 3)
        XCTAssertEqual(l.options, "sid")
        XCTAssertTrue(l.passive)
        XCTAssertEqual(l.techniques, ["Schwerter", "Schilde"])
        XCTAssertEqual(l.manoeuvre, ["kind": .string("spezialmanoever"), "mountedCombat": .bool(false)])
        XCTAssertEqual(l.reviewed, Review(by: "@fixture", date: "2026-09-25"))
        XCTAssertEqual(l.source["book"], .string("Regelwerk"))
        XCTAssertEqual(l.rulings, ["mini-levelled.open-question"])
        XCTAssertNil(l.ruleset)

        let c = try XCTUnwrap(book.rules["mini-core"])
        XCTAssertEqual(c.kind, .core)
        XCTAssertEqual(c.ruleset, "fokus.fixture")
        XCTAssertEqual(c.catalogId, "GRW_fixture")
        XCTAssertEqual(c.provides, ["reach": .array([.string("kurz"), .string("lang")]), "weight": .int(2)])
        XCTAssertNil(c.reviewed)
        XCTAssertFalse(c.passive)
        XCTAssertNil(c.levels)
        XCTAssertEqual(c.clauses.map(\.id), ["V1", "V2", "G1", "P1", "A1"])
    }

    func testClauseBodies() throws {
        let clauses = try XCTUnwrap(try mini().rules["mini-levelled"]).clauses
        XCTAssertEqual(clauses.map(\.id), ["L1", "L2", "L3"])
        XCTAssertEqual(clauses[0].name, "Stufen")
        XCTAssertEqual(clauses[0].page, .object(["book": .string("Regelwerk"), "page": .int(1)]))
        XCTAssertEqual(clauses[0].text, "PA mit Schild +Stufe−1.")
        XCTAssertEqual(clauses[0].effects.count, 1)
        XCTAssertEqual(clauses[1].body, .unencoded("not yet in the vocabulary"))
        XCTAssertEqual(clauses[1].effects, [])
        XCTAssertEqual(clauses[2].body, .none("flavour text"))
    }

    func testRulings() throws {
        let book = try mini()
        XCTAssertEqual(Set(book.rulings.keys), ["mini-core.decided-question", "mini-levelled.open-question", "shared.shared-rounding"])
        XCTAssertEqual(book.rulings["mini-levelled.open-question"],
                       Ruling(id: "mini-levelled.open-question", status: .open, question: "Does it stack?", answer: nil))
        XCTAssertEqual(book.rulings["shared.shared-rounding"]?.status, .decided)
        XCTAssertEqual(book.rulings["shared.shared-rounding"]?.answer, "Up.")
        let e = try effect(book, "mini-levelled", "L1", 0)
        XCTAssertEqual(e.ruling, ["mini-levelled.open-question"])
        XCTAssertEqual(try effect(book, "mini-core", "V1", 0).ruling, ["shared.shared-rounding"])
    }

    func testEffectMetadata() throws {
        let book = try mini()
        let first = try effect(book, "mini-core", "V1", 0)
        XCTAssertEqual(first.because, "halbe Summe")
        XCTAssertNil(first.when)
        XCTAssertEqual(first.phase, .add)
        XCTAssertEqual(first.origin, EffectOrigin(rule: "mini-core", clause: "V1", index: .top(0)))
        // A value verb keeps its phase; data, player and action verbs have none.
        XCTAssertEqual(try effect(book, "mini-core", "V1", 9).phase, .base)
        XCTAssertNil(try effect(book, "mini-core", "P1", 0).phase)
        XCTAssertNil(try effect(book, "mini-core", "P1", 3).phase)
        XCTAssertNil(try effect(book, "mini-core", "A1", 0).phase)
        // An effect's own `phase:` overrides its verb's (suppress runs in `add` here).
        XCTAssertEqual(try effect(book, "mini-core", "V2", 3).phase, .add)
    }

    func testOriginIndexIsAnIntOrAPath() throws {
        let book = try mini()
        let check = try effect(book, "mini-core", "A1", 0)
        guard case .check(let c) = check.payload else { return XCTFail("\(check.payload)") }
        XCTAssertEqual(c.onFailure.map(\.origin.index), [.nested("0.onFailure.0"), .nested("0.onFailure.1")])
        XCTAssertEqual(c.onSuccess.map(\.origin.index), [.nested("0.onSuccess.0")])
        XCTAssertEqual(EffectIndex.top(3).description, "3")
        XCTAssertEqual(EffectIndex.nested("0.onFailure.1").description, "0.onFailure.1")
        let nested = EffectOrigin(rule: "mini-core", clause: "A1", index: .nested("0.onFailure.1"))
        guard case .item(let item)? = book.effect(at: nested)?.payload else { return XCTFail("no nested item") }
        XCTAssertEqual(item.change, ItemDelta(destroyed: true))
        XCTAssertNil(book.effect(at: EffectOrigin(rule: "mini-core", clause: "A1", index: .top(99))))
        // In the reach index the indices are ints.
        XCTAssertTrue(book.reach.values.joined().allSatisfy { if case .top = $0.index { true } else { false } })
    }

    func testValueForms() throws {
        let book = try mini()
        guard case .add(let a0) = try effect(book, "mini-core", "V1", 0).payload,
              case .add(let a1) = try effect(book, "mini-core", "V1", 1).payload,
              case .add(let a2) = try effect(book, "mini-core", "V1", 2).payload,
              case .add(let a3) = try effect(book, "mini-core", "V1", 3).payload,
              case .add(let a4) = try effect(book, "mini-core", "V1", 4).payload
        else { return XCTFail("not adds") }

        // A summed operand, a list of bounds, a plain-number bound, a target `above`.
        XCTAssertEqual(a0.to, [TargetRef("at"), TargetRef("pa(with: shield)")])
        XCTAssertEqual(a0.per, "fw.current")
        XCTAssertEqual(a0.value, .proportion(Proportion(
            of: .sum([.fact("attr.MU"), .fact("attr.GE")]), per: .number(2), times: 1,
            above: .target(TargetRef("leCurrent")), round: .up,
            min: .number(1), max: .each([.number(10), .target(TargetRef("gsNatural"))]))))

        // Target operands for `of` and `per`, a fact `above`, a single operand bound, round down.
        XCTAssertEqual(a1.value, .proportion(Proportion(
            of: .target(TargetRef("spell.cost")), per: .target(TargetRef("spell.range")), times: 2,
            above: .fact("gmFact.threshold"), round: .down,
            min: nil, max: .operand(.target(TargetRef("gsNatural"))))))

        XCTAssertEqual(a2.value, .number(1))
        XCTAssertEqual(a2.scale, "mini.scale")
        XCTAssertEqual(a3.to, [TargetRef("rs(zone: kopf)")])
        XCTAssertEqual(a3.value, .table(name: "mini.table", key: "attr.KO"))
        XCTAssertEqual(a4.to, [TargetRef(name: "level", context: ["rule": "mini-levelled"])])
        XCTAssertEqual(a4.value, .level(times: 2, plus: 1))
    }

    func testValueVerbs() throws {
        let book = try mini()
        let p = { (c: String, i: Int) in try self.effect(book, "mini-core", c, i).payload }
        XCTAssertEqual(try p("V1", 5), .set(SetValue(to: [TargetRef("ini")], value: .number(5))))
        XCTAssertEqual(try p("V1", 6), .multiply(Multiply(to: [TargetRef("tp")], by: 0.5,
            line: Selector(kind: .line, ids: [.id("mini-levelled.L1")]), round: .up)))
        XCTAssertEqual(try p("V1", 7), .cap(Cap(to: [TargetRef("at")],
            max: .proportion(Proportion(of: .target(TargetRef("leCurrent")), per: .number(2), times: 1,
                                        above: .number(0), round: .up, min: nil, max: nil)),
            min: .number(0), over: Selector(kind: .rule, ids: [.id("mini-levelled")]))))
        XCTAssertEqual(try p("V1", 8), .floor(Floor(to: [TargetRef("pa")], min: .number(0))))
        XCTAssertEqual(try p("V1", 9), .derive(Derive(to: TargetRef("wundschwelle"), sum: [
            .proportion(Proportion(of: .fact("attr.KO"), per: .number(2), times: 1, above: .number(0),
                                   round: .up, min: nil, max: nil)),
            .table(name: "mini.table", key: "attr.KO"), .number(1)])))
        XCTAssertEqual(try p("V2", 0), .useLevel(UseLevel(rule: "mini-levelled", as: .level(times: 1, plus: 0), lowerBy: nil, min: nil)))
        XCTAssertEqual(try p("V2", 1), .useLevel(UseLevel(rule: "mini-levelled", as: nil, lowerBy: .number(1), min: 1)))
        XCTAssertEqual(try p("V2", 2), .replace(Replace(line: Selector(kind: .line, ids: [.id("mini-levelled.L1")]), with: .number(2))))
        XCTAssertEqual(try p("V2", 3), .suppress(Suppress(line: Selector(kind: .line, ids: [.id("mini-levelled.L1")]))))
    }

    func testLegalityVerbsSelectorsAndConditions() throws {
        let book = try mini()
        let p = { (i: Int) in try self.effect(book, "mini-core", "G1", i) }
        XCTAssertEqual(try p(0).payload, .forbid(Forbid(what: Selector(kind: .manoeuvre,
            ids: [.match(["kind": .string("spezialmanoever"), "mountedCombat": .bool(false)])]), together: true)))
        XCTAssertEqual(try p(1).payload, .forbid(Forbid(what: Selector(kind: .defence,
            ids: [.id("opponent.weaponParry"), .id("aw")]), together: nil)))
        XCTAssertEqual(try p(2).payload, .require(Require(that: .fact(name: "hero.mounted", comparison: .is(.bool(true))),
            enables: true, for: Selector(kind: .defence, ids: [.id("pa")]))))
        let limit = try p(3)
        XCTAssertEqual(limit.payload, .limit(Limit(what: Selector(kind: .attack, ids: [.id("at")]), max: .number(1), per: .round)))
        XCTAssertEqual(limit.when, .all([
            .any([.fact(name: "hero.mounted", comparison: .is(.bool(true))),
                  .fact(name: "hit.zone", comparison: .in([.string("kopf"), .string("arme")]))]),
            .not(.fact(name: "check.result", comparison: .is(.string("failure")))),
            .fact(name: "round.number", comparison: .atLeast(2)),
            .fact(name: "round.parries", comparison: .atMost(3)),
            .fact(name: "attr.MU", comparison: .above(12)),
            .fact(name: "attr.KO", comparison: .below(20)),
            .fact(name: "choice.power", comparison: .is(.int(3))),
        ]))
    }

    func testPlayerAndDataVerbs() throws {
        let book = try mini()
        let p = { (i: Int) in try self.effect(book, "mini-core", "P1", i).payload }
        guard case .offer(let offer) = try p(0) else { return XCTFail("no offer") }
        XCTAssertEqual(offer.choice, "power")
        XCTAssertEqual(offer.options, [.string("a"), .string("b")])
        XCTAssertEqual(offer.default, .bool(false))
        XCTAssertEqual(offer.span, .action)
        XCTAssertEqual(offer.costs.map(\.payload), [.cost(Cost(pool: .asp, amount: .number(1)))])
        XCTAssertEqual(offer.costs.first?.origin.index, .nested("0.costs.0"))
        XCTAssertEqual(try p(1), .ask(Ask(fact: "gmFact.threshold", who: .gm, options: [.int(1), .int(2)])))
        XCTAssertEqual(try p(2), .tell(Tell(text: "Hinweis", to: .player)))
        XCTAssertEqual(try p(3), .provide(Provide(name: "mini.table", value: .object(["0-3": .int(1), "4+": .int(2)]), readBy: .display)))
        XCTAssertEqual(try p(4), .provide(Provide(name: "mini.scale", value: .array([.int(1), .int(2), .int(4), .int(8)]), readBy: nil)))
        XCTAssertEqual(book.table("mini.table"), .object(["0-3": .int(1), "4+": .int(2)]))
        XCTAssertEqual(book.table("mini.wounds"), .object(["arme": .string("mini-levelled"), "kopf": .string("mini-levelled")]))
        XCTAssertNil(book.table("nothing"))
    }

    func testActionVerbs() throws {
        let book = try mini()
        let p = { (i: Int) in try self.effect(book, "mini-core", "A1", i).payload }
        guard case .check(let check) = try p(0) else { return XCTFail("no check") }
        XCTAssertEqual(check.of, Selector(kind: .talent, ids: [.id("Kriegskunst")], with: ["MU", "KL"]))
        XCTAssertEqual(check.modifier, .proportion(Proportion(of: .fact("attr.MU"), per: .number(2), times: 1,
            above: .number(0), round: .up, min: nil, max: nil)))
        XCTAssertEqual(check.onSuccess.map(\.payload), [.tell(Tell(text: "Gelungen", to: .gm))])
        XCTAssertEqual(check.onFailure.map(\.payload), [
            .cost(Cost(pool: .le, amount: .number(1))),
            .item(ItemChange(instance: Selector(kind: .loadout, ids: [.id("shield")]), change: ItemDelta(destroyed: true))),
        ])
        // A one-string `with` and no branches.
        XCTAssertEqual(try p(1), .check(Check(of: Selector(kind: .spell, ids: [.id("Ignifaxius")], with: ["KL"]),
                                              modifier: nil, onSuccess: [], onFailure: [])))
        XCTAssertEqual(try p(2), .gain(Gain(rule: .id("mini-levelled"), levels: 1, span: .fight)))
        XCTAssertEqual(try p(3), .gain(Gain(rule: .table(name: "mini.wounds", key: "hit.zone"), levels: nil, span: nil)))
        XCTAssertEqual(try p(4), .cost(Cost(pool: .asp,
            amount: .proportion(Proportion(of: .sum([.fact("attr.MU"), .number(2)]), per: .number(2), times: 1,
                                           above: .number(0), round: .up, min: nil, max: nil)),
            split: Split(pools: [.asp, .kap], min: [.asp: 1]), fallThrough: [.le], onFailure: 0.5,
            every: Duration(unit: .minutes, count: .fact("spell.interval")))))
        XCTAssertEqual(try p(5), .cost(Cost(pool: .actions, amount: .number(1),
                                            every: Duration(unit: .rounds, count: .number(2)))))
        guard case .process(let process) = try p(6) else { return XCTFail("no process") }
        XCTAssertEqual(process.id, "laden")
        XCTAssertEqual(process.steps, .number(3))
        XCTAssertEqual(process.advancedBy, Selector(kind: .action, ids: [.id("laden")]))
        XCTAssertEqual(process.breaksOff, .fact(name: "hero.mounted", comparison: .is(.bool(true))))
        XCTAssertEqual(process.completes.map(\.payload),
                       [.item(ItemChange(instance: Selector(kind: .loadout, ids: [.id("weapon")]), change: ItemDelta(loaded: true)))])
        XCTAssertEqual(process.exclusive, true)
        XCTAssertEqual(process.span, .fight)
        XCTAssertEqual(try p(7), .item(ItemChange(instance: Selector(kind: .loadout, ids: [.id("shield")]),
            change: ItemDelta(structurePoints: .scaled(of: "hit.tp", times: -1)))))
        XCTAssertEqual(try p(8), .reroll(Reroll(die: Selector(kind: .dice, ids: [.id("check")]), keep: "better", max: 1, per: .fight)))
    }

    // MARK: - Decoding fails loudly

    func testAMissingPayloadFieldFailsToDecode() {
        let json = #"{"verb": "add", "payload": {"to": [{"name": "at"}]}, "when": null, "ruling": [], "because": null, "phase": "add", "origin": {"rule": "r", "clause": "c", "index": 0}}"#
        XCTAssertThrowsError(try JSONDecoder().decode(Effect.self, from: Data(json.utf8)))
    }

    func testAnUnknownVerbFailsToDecode() {
        let json = #"{"verb": "explode", "payload": {}, "when": null, "ruling": [], "because": null, "phase": "action", "origin": {"rule": "r", "clause": "c", "index": 0}}"#
        XCTAssertThrowsError(try JSONDecoder().decode(Effect.self, from: Data(json.utf8)))
    }

    func testJSONValueDecodesEachKind() throws {
        let v = try JSONDecoder().decode(JSONValue.self, from: Data(#"[null, true, 3, 2.5, "x", [1], {"a": false}]"#.utf8))
        XCTAssertEqual(v, .array([.null, .bool(true), .int(3), .double(2.5), .string("x"), .array([.int(1)]), .object(["a": .bool(false)])]))
    }
}

extension JSONValue {
    /// The same value with every int as a double, so that `1` and `1.0` compare equal.
    var numbersAsDoubles: JSONValue {
        switch self {
        case .int(let i): .double(Double(i))
        case .array(let a): .array(a.map(\.numbersAsDoubles))
        case .object(let o): .object(o.mapValues(\.numbersAsDoubles))
        default: self
        }
    }
}
