import XCTest
@testable import RulesEngine

/// Task 30, the derived values and the sheet, on the fixture book `Fixtures/sheet-rules.json`
/// (source: `Tests/FixtureRules/sheet`, rebuilt by `make rules-engine-fixture`).
final class SheetTests: XCTestCase {
    private static let book: RuleBook = {
        let url = Bundle.module.url(forResource: "sheet-rules", withExtension: "json", subdirectory: "Fixtures")!
        return try! RuleBook.load(from: url)
    }()

    private let engine = Engine(book: SheetTests.book)

    private func ref(_ text: String) -> ClauseRef { ClauseRef(text)! }

    private func situation(owned: [String: Int] = [:], facts: [String: JSONValue] = [:],
                           base: [String: Int] = [:]) -> Situation {
        Situation(owned: owned.mapValues { OwnedRule(level: $0) },
                  facts: facts.sorted { $0.key < $1.key }.map {
                      Fact(name: $0.key, value: $0.value, owner: Vocabulary.owner(ofFact: $0.key) ?? .sheet)
                  }, base: base)
    }

    private func lines(_ b: Breakdown, from origin: String) -> [Line] {
        b.lines.filter { $0.origin == ref(origin) }
    }

    private let plate: [String: JSONValue] = ["loadout.armour": "Platte", "loadout.armour.belastung": 3]

    // MARK: - belastung.source

    func testBelastungFromWornArmourHasTheSourceArmour() {
        let b = engine.evaluate(Query("level(rule: sh-load)"), in: situation(owned: ["sh-habit": 1], facts: plate))
        XCTAssertEqual(b.result, 2)
        let levelAs = b.lines.first { $0.kind == .levelAs }
        XCTAssertEqual(levelAs?.facts.first { $0.name == "belastung.source" }?.value, "armour")
        XCTAssertEqual(levelAs?.facts.first { $0.name == "belastung.source" }?.owner, .derived)
        XCTAssertEqual(b.questions.map(\.fact), [])
    }

    func testWithoutAStatedArmourTheSourceAsksForTheArmour() {
        let b = engine.evaluate(Query("level(rule: sh-load)"),
                                in: situation(owned: ["sh-habit": 1], facts: ["loadout.armour.belastung": 3]))
        XCTAssertEqual(b.result, 3)
        XCTAssertEqual(b.notApplied.first { $0.origin == ref("sh-habit.G1") }?.reason, .unknownFact)
        XCTAssertEqual(b.questions.map(\.fact), ["loadout.armour"])
    }

    // MARK: - A derived Stufe above the rule's highest

    func testADerivedStufeIsCappedAtTheRulesHighest() throws {
        let facts: [String: JSONValue] = ["loadout.armour": "Turnier", "loadout.armour.belastung": 5]
        let b = engine.evaluate(Query("level(rule: sh-load)"), in: situation(facts: facts))
        XCTAssertEqual(b.result, 4)
        let base = try XCTUnwrap(b.base)
        XCTAssertEqual(base.value, 4)
        XCTAssertEqual(base.parts.map(\.value), [5, -1])
        XCTAssertEqual(base.parts.last?.kind, .capped)
        XCTAssertEqual([base.parts.last?.was, base.parts.last?.now], [5, 4])
        // hero.levelOf reads the capped Stufe too.
        XCTAssertEqual(engine.evaluation(situation(facts: facts)).baseLevel(of: "sh-load", depth: 0).value, 4)
    }

    // MARK: - The rulings of the useLevels a line rests on

    func testALineCarriesTheRulingsOfTheUseLevelsInItsVia() throws {
        let b = engine.evaluate(Query("at"), in: situation(owned: ["sh-habit": 1], facts: plate, base: ["at": 14]))
        let line = try XCTUnwrap(lines(b, from: "sh-load.L1").first)
        XCTAssertEqual(line.value, -2)
        XCTAssertTrue(line.via.contains(ref("sh-habit.G1")))
        XCTAssertEqual(line.rulings, ["sh-habit.shift"])
    }

    // MARK: - Action effects act at the Stufe the rule acts at

    func testAGainReadsTheStufeAfterTheUseLevels() {
        let layer = ActionLayer(engine: engine)
        let heavy: [String: JSONValue] = ["loadout.armour": "Gestech", "loadout.armour.belastung": 4]
        let alone = layer.perform(.settle, in: situation(facts: heavy))
        XCTAssertEqual(alone.events.map(\.rule), ["sh-helpless"])
        XCTAssertEqual(alone.events.first?.rulings, ["sh-load.jouster"])
        let used = layer.perform(.settle, in: situation(owned: ["sh-habit": 1], facts: heavy))
        XCTAssertEqual(used.events, [])
    }
}

extension SheetTests {
    // MARK: - A choice nobody made

    func testAnUnmadeChoiceReadsItsOffersDefault() throws {
        let b = engine.evaluate(Query("aw"), in: situation(facts: ["hero.mounted": true], base: ["aw": 7]))
        let line = try XCTUnwrap(lines(b, from: "sh-mount.R6").first)
        XCTAssertEqual(line.value, -2)
        XCTAssertEqual(line.facts.first { $0.name == "choice.jumpOff" }?.value, false)
        let jumped = engine.evaluate(Query("aw"), in: situation(facts: ["hero.mounted": true, "choice.jumpOff": true],
                                                                base: ["aw": 7]))
        XCTAssertEqual(lines(jumped, from: "sh-mount.R6"), [])
    }

    // MARK: - A check query names its check

    func testACheckQuerysContextStatesTheKindOfCheck() throws {
        let spell = engine.evaluate(Query("check.modifier(spell: any)"), in: situation(facts: plate))
        XCTAssertEqual(lines(spell, from: "sh-load.L1").map(\.value), [-3])
        let talent = engine.evaluate(Query("check.modifier(talent: TAL_3)"), in: situation(facts: plate))
        XCTAssertEqual(lines(talent, from: "sh-load.L1"), [])
        XCTAssertEqual(talent.notApplied.first { $0.origin == ref("sh-load.L1") }?.reason, .conditionFalse)
    }
}

extension SheetTests {
    // MARK: - The loadout facts (Loadout.swift)

    private var hero: [String: JSONValue] {
        ["attr.MU": 14, "attr.GE": 14, "attr.KK": 13, "ktw.Schwerter": 12, "ktw.Schilde": 10, "ktw.Raufen": 10]
    }

    func testATechniqueTheQueryNamesGivesItsKtWAndLeiteigenschaft() throws {
        let at = engine.evaluate(Query("at(with: Schwerter)"), in: situation(facts: hero))
        XCTAssertEqual(at.result, 14)
        XCTAssertEqual(at.base?.parts.map(\.value), [12, 2])
        XCTAssertTrue(at.base?.parts.first?.facts.contains(FactUse(name: "ktw.Schwerter", value: 12, owner: .sheet)) ?? false)
        let pa = engine.evaluate(Query("pa(with: Schwerter)"), in: situation(facts: hero))
        XCTAssertEqual(pa.base?.parts.map(\.value), [6, 2])        // the higher of GE 14 and KK 13
        let leit = try XCTUnwrap(pa.base?.parts.last)
        XCTAssertEqual(leit.via, [ref("sh-kampf.T1")])
        XCTAssertTrue(leit.facts.contains(FactUse(name: "attr.GE", value: 14, owner: .sheet)))
        XCTAssertEqual(pa.questions.map(\.fact), [])
    }

    func testTheWeaponInHandIsReadFromItsTemplateFoundByName() throws {
        var facts = hero
        facts["loadout.weapon"] = "Schwert"
        let at = engine.evaluate(Query("at"), in: situation(facts: facts))
        XCTAssertEqual(at.base?.value, 14)
        XCTAssertEqual(lines(at, from: "sh-kampf.M1").map(\.value), [0])
        let pa = engine.evaluate(Query("pa"), in: situation(facts: facts))
        XCTAssertEqual(pa.base?.value, 8)
        let mod = try XCTUnwrap(lines(pa, from: "sh-kampf.M1").first)
        XCTAssertEqual(mod.value, -1)
        XCTAssertEqual(mod.via, [ref("sh-sword.R0")])
        XCTAssertEqual(pa.result, 7)
    }

    func testAStatedItemFieldWinsOverItsRow() {
        var facts = hero
        facts["loadout.weapon"] = "Schwert"
        facts["item.Schwert.paMod"] = 1
        let pa = engine.evaluate(Query("pa"), in: situation(facts: facts))
        XCTAssertEqual(lines(pa, from: "sh-kampf.M1").map(\.value), [1])
    }

    func testTheShieldAttackedWithGivesItsTechniqueAndItsMod() {
        var facts = hero
        facts["loadout.weapon"] = "Schwert"
        facts["loadout.shield"] = "Schild"
        facts["action.with"] = "Schild"
        let at = engine.evaluate(Query("at"), in: situation(facts: facts))
        XCTAssertEqual(at.base?.parts.map(\.value), [10, 2])
        XCTAssertEqual(lines(at, from: "sh-kampf.M1").map(\.value), [-6])
        let shieldParry = engine.evaluate(Query("pa(with: shield)"), in: situation(facts: facts.filter { $0.key != "action.with" }))
        XCTAssertEqual(shieldParry.base?.parts.map(\.value), [5, 1])   // Schilde: KK 13
        XCTAssertEqual(lines(shieldParry, from: "sh-kampf.M1"), [])       // not a weapon parry
    }

    func testAFieldProvidedUnderItsOwnNameIsRead() {
        let gs = engine.evaluate(Query("gs"), in: situation(facts: ["loadout.shield": "Schild"], base: ["gs": 8]))
        XCTAssertEqual(lines(gs, from: "sh-kampf.M2").map(\.value), [-1])
    }

    func testWithoutAWeaponTheKtWAsksForTheLoadout() {
        let at = engine.evaluate(Query("at"), in: situation(facts: hero))
        XCTAssertNil(at.result)
        XCTAssertTrue(at.questions.map(\.fact).contains("loadout.weapon"))
    }

    func testBareHandsWithATechnique() {
        var facts = hero
        facts["loadout.weapon"] = .null
        facts["action.with"] = "Raufen"
        let pa = engine.evaluate(Query("pa(with: weapon)"), in: situation(facts: facts))
        XCTAssertEqual(pa.base?.parts.map(\.value), [5, 2])
        XCTAssertEqual(lines(pa, from: "sh-kampf.M1"), [])
        XCTAssertEqual(pa.questions.map(\.fact), [])
    }
}

extension SheetTests {
    func testATechniqueByIdAndByNameIsOne() throws {
        // The row names CT_5; the hero states the KtW by name only, the table is by name.
        let facts: [String: JSONValue] = ["attr.MU": 14, "attr.KK": 14, "ktw.Hiebwaffen": 14, "loadout.weapon": "Axt"]
        let pa = engine.evaluate(Query("pa"), in: situation(facts: facts))
        XCTAssertEqual(pa.base?.parts.map(\.value), [7, 2])
        XCTAssertEqual(pa.base?.parts.last?.via, [ref("sh-axe.A0"), ref("sh-kampf.T1")])   // the row named the technique
        // By id only: a query naming the technique by name reads it.
        let byId = engine.evaluate(Query("at(with: Hiebwaffen)"), in: situation(facts: ["attr.MU": 14, "ktw.CT_5": 13]))
        XCTAssertEqual(byId.base?.parts.map(\.value), [13, 2])
    }
}

extension SheetTests {
    /// A rule that applies by its derived level rests on the derive that gave it (as on an
    /// enabling require): its lines carry that clause in `via` (lebensenergie 15.5: Schmerz's
    /// line via COND_6.SZ3, the LP thresholds).
    func testALineOfARuleWithADerivedLevelCarriesTheDeriveInVia() throws {
        let b = engine.evaluate(Query("at"), in: situation(owned: ["sh-habit": 1], facts: plate, base: ["at": 14]))
        let line = try XCTUnwrap(lines(b, from: "sh-load.L1").first)
        XCTAssertEqual(line.via, [ref("sh-armour.A1"), ref("sh-habit.G1")])
        // An owned Stufe is the sheet's: no derive in `via`.
        let owned = engine.evaluate(Query("at"), in: situation(owned: ["sh-load": 2], base: ["at": 14]))
        XCTAssertEqual(lines(owned, from: "sh-load.L1").first?.via, [])
    }
}

extension SheetTests {
    /// The hero sheet (Task 30, R52/R62): the breakdown of no target, which every rule's `*`
    /// effects reach: the tells the player is shown, the offers, the questions, and the entries
    /// of those that do not apply.
    func testTheSheetHoldsTheTextsAndEntriesEveryQueryShows() throws {
        let b = engine.sheet(in: situation(facts: ["hero.mounted": true]))
        XCTAssertNil(b.base)
        XCTAssertEqual(b.lines, [])
        XCTAssertTrue(b.texts.contains { $0.origin == ref("sh-note.N1") && $0.text == "Absitzen kostet eine Aktion." }, "\(b.texts)")
        XCTAssertEqual(b.notApplied.first { $0.origin == ref("sh-note.N2") }?.reason, .conditionFalse)
    }
}

extension SheetTests {
    /// Task 30: whether a piece may be carried (the loadout screen): the `forbid` / `require` of
    /// kind `loadout` naming it, read as phase 7 reads a query's (belastung 6.1: a second armour).
    func testALoadoutPieceIsForbiddenByTheRuleThatNamesIt() throws {
        let second = engine.legality(ofLoadout: ["armour", "secondArmour"], in: situation(facts: plate))
        XCTAssertFalse(second.allowed)
        XCTAssertEqual(second.reasons.map(\.origin), [ref("sh-armour.A1")])
        XCTAssertEqual(second.reasons.first?.because, "eine Rüstung zur Zeit")
        XCTAssertEqual(second.reasons.first?.rulings, ["sh-armour.one"])
        XCTAssertTrue(engine.legality(ofLoadout: ["armour"], in: situation(facts: plate)).allowed)
        // A forbid's `when` reads the loadout it would be part of.
        XCTAssertTrue(engine.legality(ofLoadout: ["other"], in: situation(facts: [:])).allowed)
        XCTAssertFalse(engine.legality(ofLoadout: ["other"], in: situation(facts: ["loadout.shield": "Schild"])).allowed)
    }
}

extension SheetTests {
    /// `hero.conditionLevels` (zustaende.Z5): the Stufen of every Zustand the hero has, each as
    /// `hero.levelOf` gives it (before any useLevel: ADV_49.zaeher-hund-counts), derived ones
    /// included (lebensenergie 15.8).
    func testTheZustandsstufenAreSummed() {
        let layer = ActionLayer(engine: engine)
        let seven = layer.perform(.settle, in: situation(owned: ["sh-stun": 3, "sh-habit": 2],
                                                         facts: ["loadout.armour": "Gestech", "loadout.armour.belastung": 4]))
        XCTAssertEqual(seven.events.map(\.rule), [], "3 + 4 = 7 (the armour's IV, before the useLevel)")
        let eight = layer.perform(.settle, in: situation(owned: ["sh-stun": 4, "sh-habit": 2],
                                                         facts: ["loadout.armour": "Gestech", "loadout.armour.belastung": 4]))
        XCTAssertEqual(eight.events.map(\.rule), ["sh-helpless"])
        XCTAssertEqual(eight.events.first?.facts.first { $0.name == "hero.conditionLevels" }?.value, 8)
        let unknown = layer.perform(.settle, in: situation(owned: ["sh-stun": 4]))
        XCTAssertEqual(unknown.questions.map(\.fact), ["loadout.armour"], "the armour behind the unknown Stufe")
    }
}

extension SheetTests {
    /// Ruling R64: taking the Regenerationsphase restores its `regeneration.le` to LE, held at
    /// the maximum by the cap on `leCurrent` (regeneration.R5), which joins the event's `via`.
    func testTakingTheRegenerationsphaseRestoresLE() throws {
        let layer = ActionLayer(engine: engine)
        var s = situation(facts: ["roll.regeneration": 5, "attr.KO": 15])
        s.pools = [.le: PoolState(current: 20, max: 30)]
        let r = layer.perform(.take(choice: "regenerationsphase"), in: s)
        let e = try XCTUnwrap(r.events.first { $0.kind == .restored })
        XCTAssertEqual(e.amount, 5)
        XCTAssertEqual(e.origin, ref("sh-rest.R4"))
        XCTAssertEqual(r.situation.pools[.le]?.current, 25)
        s.pools = [.le: PoolState(current: 28, max: 30)]
        let near = layer.perform(.take(choice: "regenerationsphase"), in: s)
        let capped = try XCTUnwrap(near.events.first { $0.kind == .restored })
        XCTAssertEqual(capped.amount, 2)
        XCTAssertTrue(capped.via.contains(ref("sh-rest.R5")))
        XCTAssertEqual(near.situation.pools[.le]?.current, 30)
    }
}
