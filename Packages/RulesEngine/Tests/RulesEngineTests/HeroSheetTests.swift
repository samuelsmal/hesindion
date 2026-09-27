import XCTest
@testable import RulesEngine

final class HeroSheetTests: XCTestCase {
    func testTheCheckTableDecodesTheBuiltFile() throws {
        let data = try Data(contentsOf: Repo.url("build/rules/checks.json"))
        let table = try CheckTable.decode(data)
        XCTAssertEqual(table.hinderedByBelastung["TAL_5"], .bool(true))
        XCTAssertEqual(table.attributes["TAL_5"], ["KO", "KK", "KK"])
    }

    static let book: RuleBook = try! RuleBook.load(from: Repo.url("build/rules/rules.json"))

    /// Boronmir as kampfwerte.yaml's header states him.
    static func boronmir(loadout: HeroSheet.Loadout = .init(),
                         items: [HeroSheet.Item] = []) -> HeroSheet {
        HeroSheet(
            owned: ["SA_41": .init(level: 2), "ADV_25": .init(level: 2), "ADV_54": .init(level: 1)],
            attributes: ["MU": 14, "KL": 12, "IN": 13, "CH": 13, "FF": 11, "GE": 14, "KO": 15, "KK": 14],
            techniques: ["CT_5": 14, "CT_12": 12, "CT_10": 10, "CT_9": 10, "CT_3": 8],
            talents: [:], purchasedLE: 0, speciesLE: 5, speciesGS: 8,
            items: items, loadout: loadout)
    }

    static let rabenschnabel = HeroSheet.Item(name: "Rabenschnabel", template: "ITEMTPL_19")
    static let grossschild = HeroSheet.Item(name: "Großschild", template: "ITEMTPL_29")

    func result(_ q: String, _ sheet: HeroSheet) -> Int? {
        Engine(book: Self.book).evaluate(Query(q), in: Situation(sheet: sheet)).result
    }

    func testTheSheetFactsAreHeroPysAndTheLoadouts() {
        let s = Situation(sheet: Self.boronmir(loadout: .init(weapon: "Rabenschnabel"),
                                               items: [Self.rabenschnabel]))
        XCTAssertEqual(s.facts["attr.KO"]?.value, .int(15))
        XCTAssertEqual(s.facts["attr.KO"]?.owner, .sheet)
        XCTAssertEqual(s.facts["ktw.CT_5"]?.value, .int(14))
        XCTAssertEqual(s.facts["hero.purchased.le"]?.value, .int(0))
        XCTAssertEqual(s.facts["species.le"]?.value, .int(5))
        XCTAssertEqual(s.facts["loadout.weapon"]?.value, .string("Rabenschnabel"))
        XCTAssertEqual(s.facts["loadout.weapon"]?.owner, .loadout)
        XCTAssertEqual(s.facts["item.Rabenschnabel.template"]?.value, .string("ITEMTPL_19"))
        XCTAssertNil(s.facts["item.Rabenschnabel.atMod"])
        XCTAssertEqual(s.base["gs"], 8)
        XCTAssertEqual(s.owned["SA_41"]?.level, 2)
    }

    func testAnItemWithoutARuleFileStatesItsOwnStats() {
        let axe = HeroSheet.Item(name: "Streitaxt", technique: "CT_5", atMod: 0, paMod: -1)
        let s = Situation(sheet: Self.boronmir(loadout: .init(weapon: "Streitaxt"), items: [axe]))
        XCTAssertEqual(s.facts["item.Streitaxt.technique"]?.value, .string("CT_5"))
        XCTAssertEqual(s.facts["item.Streitaxt.paMod"]?.value, .int(-1))
        XCTAssertNil(s.facts["item.Streitaxt.template"])
    }

    func testBoronmirsSheetValues() {
        let armed = Self.boronmir(loadout: .init(weapon: "Rabenschnabel"), items: [Self.rabenschnabel])
        XCTAssertEqual(result("leMax", armed), 37)
        XCTAssertEqual(result("at(with: Rabenschnabel)", armed), 16)
        XCTAssertEqual(result("pa(with: Rabenschnabel)", armed), 8)
        let shielded = Self.boronmir(loadout: .init(weapon: "Rabenschnabel", shield: "Großschild"),
                                     items: [Self.rabenschnabel, Self.grossschild])
        // Plain `at`, not `at(with: Rabenschnabel)`: naming the weapon explicitly in `with:`
        // states `action.with` as the item's own name, which ITEMTPL_29.GR1's `when` (checking
        // literally for `mainHand`/`weapon`) does not match — kampfwerte.yaml 16.7 (a passing
        // situation, no conflict) queries the same loadout with plain `at` and expects 15.
        XCTAssertEqual(result("at", shielded), 15)
    }

    /// Task 7 fix round 1: the app's loadout picker queries a shield's own AT with
    /// `at(with: shield)` while the hero has not (yet) selected a main weapon — the
    /// preparation screen, before the player has tapped anything in the loadout
    /// picker. kampfwerte.KW1's MU term (`{ of: attr.MU, above: 8, per: 3, round:
    /// down }`) is guarded `when: { not: { loadout.weapon.technique: CT_8 } }`, which
    /// reads the *weapon slot*, not the piece the query is about — confirmed correct
    /// by kampfwerte 16.8 (a passing situation), whose loadout keeps a real weapon
    /// (Langschwert) in the slot even while attacking with the shield.
    func testTheShieldsOwnATNeedsAKnownWeaponSlotForKW1sMUTerm() {
        // (a) weapon slot = Rabenschnabel (the hero's real main weapon), at(with: shield):
        // loadout.weapon.technique resolves (CT_5, Hiebwaffen — not CT_8), so KW1's MU term
        // fires. kampfwerte 16.8's own numbers (KtW 10 Schilde + MU 14 → +2 = 12, then
        // ITEMTPL_29.GR0's item.atMod -6 = 6) apply unchanged: the weapon named does not
        // matter to the shield's own value, only that one is known.
        let a = Self.boronmir(loadout: .init(weapon: "Rabenschnabel", shield: "Großschild"),
                              items: [Self.rabenschnabel, Self.grossschild])
        let ba = Engine(book: Self.book).evaluate(Query("at(with: shield)"), in: Situation(sheet: a))
        XCTAssertEqual(ba.result, 6, "\(ba.shownLines)")
        XCTAssertEqual(ba.base?.value, 12, "\(ba.base as Any)")
        XCTAssertTrue(ba.base?.origin?.rule == "kampfwerte" && ba.base?.origin?.clause == "KW1")
        XCTAssertTrue(ba.notApplied.contains { $0.origin == ClauseRef(rule: "ITEMTPL_29", clause: "GR1") },
                      "\(ba.notApplied)")

        // (b) weapon slot empty (no main weapon selected yet), at(with: shield): the query's
        // own `with: shield` only derives `loadout.weapon.technique` when `with` names a
        // technique the hero has a KtW in (Loadout.combatFacts); "shield" is a slot keyword,
        // not a technique, so `ktw("shield", …)` fails to resolve and the derived fact is
        // never synthesised. With no stated `loadout.weapon` either, KW1's guard cannot
        // resolve `not: unknown`, and the MU term does not fire: base 10, result 4 — the
        // preparation-screen bug (task 7, CombatViewSnapshotTests.testPreparation).
        let b = Self.boronmir(loadout: .init(shield: "Großschild"), items: [Self.grossschild])
        let bb = Engine(book: Self.book).evaluate(Query("at(with: shield)"), in: Situation(sheet: b))
        XCTExpectFailure("KW1's MU `when` reads the weapon slot, not the piece being attacked with — owner decision pending (a rules-catalog change, not app code)") {
            XCTAssertEqual(bb.result, 6, "\(bb.shownLines)")
        }
        XCTAssertEqual(bb.result, 4, "confirms the bug's actual number: \(bb.shownLines)")

        // (c) weapon slot still empty, but the query is plain `at` with `action.with` stated
        // directly as the shield's own name (Großschild) — kampfwerte 16.8's own query form
        // (its `choose: { action.with: Großschild }`). This does not touch `loadout.weapon`
        // either, so it is exactly as unresolved as (b): same base 10, same result 4. Naming
        // the shield in `action.with` only changes *what* is being attacked with (the query's
        // subject); it does not make the weapon slot known.
        var c = Situation(sheet: b)
        c.state(Fact(name: "action.with", value: .string("Großschild"), owner: .player))
        let bc = Engine(book: Self.book).evaluate(Query("at"), in: c)
        XCTExpectFailure("action.with names the piece attacked with, not the weapon slot KW1's guard reads — this query form does not resolve loadout.weapon.technique either") {
            XCTAssertEqual(bc.result, 6, "\(bc.shownLines)")
        }
        XCTAssertEqual(bc.result, 4, "confirms: naming action.with does not populate loadout.weapon: \(bc.shownLines)")

        // (d) weapon slot filled with the shield's own name (Großschild is in `items` already,
        // with technique CT_10 via its template): loadout.weapon.technique resolves to CT_10,
        // not CT_8, so the MU term fires. Confirms a same-named filler works.
        let dSheet = b.with(weapon: "Großschild")
        let bd = Engine(book: Self.book).evaluate(Query("at(with: shield)"), in: Situation(sheet: dSheet))
        XCTAssertEqual(bd.result, 6, "\(bd.shownLines)")

        // (e) weapon slot filled with a synthetic "Raufen" item (technique CT_9, no template —
        // every hero can fight bare-handed): also resolves loadout.weapon.technique to CT_9.
        var eSheet = b
        eSheet.items.append(.init(name: "Raufen", technique: "CT_9"))
        eSheet = eSheet.with(weapon: "Raufen")
        let be = Engine(book: Self.book).evaluate(Query("at(with: shield)"), in: Situation(sheet: eSheet))
        XCTAssertEqual(be.result, 6, "\(be.shownLines)")
    }

    func testPlateGivesOneBelastungLineAfterBelastungsgewoehnung() {
        let plate = Self.boronmir(
            loadout: .init(weapon: "Rabenschnabel", armour: "Plattenrüstung", armourBelastung: 3),
            items: [Self.rabenschnabel])
        let b = Engine(book: Self.book).evaluate(Query("at(with: Rabenschnabel)"), in: Situation(sheet: plate))
        let belastung = b.lines.filter { $0.origin?.rule == "COND_1" }
        XCTAssertEqual(belastung.map(\.value), [-1])
    }

    /// The Wundschwelle's derive belongs to the Trefferzonen Fokusregel (trefferzonen.TZ8): on,
    /// it is ⌈KO 15 / 2⌉ 8 plus Eisern's 1; off, there is no base and TZ8 says why.
    func testTheWundschwelleFollowsTheTrefferzonenRuleset() {
        var on = Self.boronmir()
        on.rulesets = ["fokus.trefferzonen"]
        XCTAssertEqual(Situation(sheet: on).facts["rulesets"]?.value, .array([.string("fokus.trefferzonen")]))
        XCTAssertEqual(result("wundschwelle", on), 9)

        let off = Self.boronmir()
        XCTAssertEqual(Situation(sheet: off).facts["rulesets"]?.value, .array([]))
        let b = Engine(book: Self.book).evaluate(Query("wundschwelle"), in: Situation(sheet: off))
        XCTAssertNil(b.result)
        XCTAssertTrue(b.notApplied.contains { $0.origin == ClauseRef(rule: "trefferzonen", clause: "TZ8") && $0.reason == .rulesetOff },
                      "\(b.notApplied.map { "\($0.origin) \($0.reason)" })")
    }

    /// `schilde.shield-bonus-raufen` is the decided ruling `pa(with: weapon)` rests on for a
    /// bare-handed Raufen parry with a shield (kampfwerte.yaml 16.16-ish, `ruling:` on SCH1).
    func testRulingAnswerLooksUpADecidedRulingByItsQualifiedId() {
        let answer = Self.book.rulingAnswer("schilde.shield-bonus-raufen")
        XCTAssertEqual(answer, "Yes: unarmed is the hand the hero fights with; the shield covers him either way.")
        XCTAssertNil(Self.book.rulingAnswer("schilde.no-such-ruling"))
    }
}
