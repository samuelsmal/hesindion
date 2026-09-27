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

    func testPlateGivesOneBelastungLineAfterBelastungsgewoehnung() {
        let plate = Self.boronmir(
            loadout: .init(weapon: "Rabenschnabel", armour: "Plattenrüstung", armourBelastung: 3),
            items: [Self.rabenschnabel])
        let b = Engine(book: Self.book).evaluate(Query("at(with: Rabenschnabel)"), in: Situation(sheet: plate))
        let belastung = b.lines.filter { $0.origin?.rule == "COND_1" }
        XCTAssertEqual(belastung.map(\.value), [-1])
    }
}
