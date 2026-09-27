import XCTest
import RulesEngine
@testable import Hesindion

@MainActor
final class SheetValuesTests: XCTestCase {
    func testBoronmirsValuesComeFromTheEngine() throws {
        let hero = try SampleHeroes.importHero(named: "Boronmir Siebenfeld von Greifenfurt")
        let v = try XCTUnwrap(SheetValues.of(hero))
        XCTAssertEqual(v.leMax.result, 37)
        XCTAssertTrue(v.leMax.breakdown.lines.contains { $0.origin?.rule == "ADV_25" })
    }

    func testAnUnchangedSheetIsNotEvaluatedAgain() throws {
        let hero = try SampleHeroes.importHero(named: "Boronmir Siebenfeld von Greifenfurt")
        let a = try XCTUnwrap(SheetValues.of(hero))
        let b = try XCTUnwrap(SheetValues.of(hero))
        XCTAssertTrue(a === b)
        hero.attributes?.ko += 1
        let c = try XCTUnwrap(SheetValues.of(hero))
        XCTAssertFalse(a === c)
        XCTAssertEqual(c.leMax.result, 39)
    }

    /// A weapon is queried by its slot, so the rules that read the main weapon see it: the
    /// Großschild carried takes one off the Rabenschnabel's AT.
    func testTheMainWeaponCarriesTheShieldsAttackPenalty() throws {
        let hero = try SampleHeroes.importHero(named: "Boronmir Siebenfeld von Greifenfurt")
        let rabenschnabel = try XCTUnwrap(hero.meleeWeapons.first { $0.name == "Rabenschnabel" })
        let grossschild = try XCTUnwrap(hero.shields.first { $0.name == "Großschild" })
        hero.selectedWeaponName = rabenschnabel.name
        hero.selectedOffHandName = nil

        hero.selectedShieldName = grossschild.name
        let carried = try XCTUnwrap(SheetValues.of(hero)).weapon(rabenschnabel).at
        XCTAssertEqual(carried.withoutBelastung, 15, "\(carried.breakdown.shownLines)")
        XCTAssertTrue(carried.breakdown.lines.contains { $0.origin?.rule == "ITEMTPL_29" })

        hero.selectedShieldName = nil
        let bare = try XCTUnwrap(SheetValues.of(hero)).weapon(rabenschnabel).at
        XCTAssertEqual(bare.withoutBelastung, 16, "\(bare.breakdown.shownLines)")

        // The shield's own parry, queried by its slot with the shield carried (kampfwerte 16.16).
        let shieldParry = try XCTUnwrap(SheetValues.of(hero)).shield(grossschild).pa
        XCTAssertEqual(shieldParry.withoutBelastung, 13, "\(shieldParry.breakdown.shownLines)")
    }

    /// Without the Trefferzonen Fokusregel the engine has no Wundschwelle (trefferzonen.TZ8).
    func testTheWundschwelleNeedsTheTrefferzonenFokusregel() throws {
        let hero = try SampleHeroes.importHero(named: "Boronmir Siebenfeld von Greifenfurt")
        hero.setFokusRule(.trefferzonen, active: false)
        XCTAssertNil(try XCTUnwrap(SheetValues.of(hero)).wundschwelle.result)
        hero.setFokusRule(.trefferzonen, active: true)
        XCTAssertEqual(try XCTUnwrap(SheetValues.of(hero)).wundschwelle.result, 9)
    }

    /// The heaviest armour the hero owns, worn alone, and then no armour: the engine's COND_1
    /// lines on the main weapon's AT sum to Swift's Belastung line (design §4, until domain 2).
    func testTheEnginesBelastungIsTheSwiftOne() throws {
        for name in HeroSheetMappingTests.heroes {
            let hero = try SampleHeroes.importHero(named: name)
            guard let w = hero.meleeWeaponsInOrder.first else { continue }
            hero.selectedWeaponName = w.name
            let heaviest = hero.armors.max { $0.encumbrance < $1.encumbrance }
            for wearing in [true, false] {
                for a in hero.armors { a.isEquipped = wearing && a === heaviest }
                let engine = try XCTUnwrap(SheetValues.of(hero)).weapon(w).at.breakdown.lines
                    .filter { $0.origin?.rule == "COND_1" }.reduce(0) { $0 + $1.value }
                let s = Hesindion.Situation(hero: hero, domain: .meleeAttack)
                let swift = SharedModifiers.encumbrance.evaluate(s)?.value ?? 0
                XCTAssertEqual(engine, swift, "\(name), armour \(wearing)")
            }
        }
    }

    /// The engine's values against what the import stored, per sample hero. Every difference is
    /// intended and named (sheet cut-over design §4); anything else fails.
    func testTheEngineAgreesWithTheStoredValuesExceptTheNamedDifferences() throws {
        let intended: [String: Set<String>] = [
            "Boronmir Siebenfeld von Greifenfurt": [
                "at(CT_8)",   // kampfwerte.KW6: Peitschen AT takes FF, not MU (the old value used MU)
            ],
            "Robak Arkanjeff": [],
            "Ingra Tochter der Ilpetta": [],
            "Lyssandra Silberhaar": [],
        ]
        for name in HeroSheetMappingTests.heroes {
            let hero = try SampleHeroes.importHero(named: name)
            // The Wundschwelle is the Trefferzonen Fokusregel's (trefferzonen.TZ8).
            hero.setFokusRule(.trefferzonen, active: true)
            let v = try XCTUnwrap(SheetValues.of(hero))
            let dv = try XCTUnwrap(hero.derivedValues)
            var got: [String: (engine: SheetValue, stored: Int)] = [
                "leMax": (v.leMax, dv.lebensenergie.max),
                "wundschwelle": (v.wundschwelle, dv.wundschwelle.max),
                "iniBase": (v.iniBase, dv.initiative.max),
                "aw": (v.aw, dv.ausweichen.max),
            ]
            for ct in hero.combatTechniques {
                got["at(\(ct.ruleId))"] = (v.technique(ct.ruleId).at, ct.at)
                if ct.pa > 0 { got["pa(\(ct.ruleId))"] = (v.technique(ct.ruleId).pa, ct.pa) }
            }
            // `Hero.passiveShieldPABonus` is gone (no reader left once every
            // roll read `SheetValues`); the shield's own `paModifier` is the
            // same number.
            let shieldPABonus = hero.shields.first { $0.name == hero.selectedShieldName }?.paModifier ?? 0
            for w in hero.meleeWeapons {
                got["at(\(w.name))"] = (v.weapon(w).at, w.at)
                got["pa(\(w.name))"] = (v.weapon(w).pa, w.pa + shieldPABonus)
            }
            func number(_ key: String) -> Int? {
                let e = got[key]!.engine
                return ["leMax", "wundschwelle"].contains(key) ? e.result : e.withoutBelastung
            }
            let differing = Set(got.keys.filter { number($0) != got[$0]!.stored })
            let detail = differing.sorted().map { k in
                "\(k): engine \(number(k).map(String.init) ?? "nil"), stored \(got[k]!.stored); "
                    + got[k]!.engine.breakdown.shownLines
                        .map { "\($0.value) \($0.origin?.description ?? "sheet")" }.joined(separator: ", ")
            }.joined(separator: "\n")
            XCTAssertEqual(differing, intended[name] ?? [], "\(name):\n\(detail)")
        }
    }
}
