import XCTest
import RulesEngine
@testable import Hesindion

@MainActor
final class TalentBelastungTests: XCTestCase {
    func boronmirInPlate() throws -> Hero {
        let hero = try SampleHeroes.importHero(named: "Boronmir Siebenfeld von Greifenfurt")
        for a in hero.armors { a.isEquipped = a.encumbrance == 3 }   // the Plattenrüstung
        XCTAssertTrue(hero.armors.contains { $0.isEquipped }, "Boronmir owns a Belastung-3 armour")
        return hero
    }

    func testAHinderedTalentGetsTheBelastungLine() throws {
        let r = TalentBelastung.lines(hero: try boronmirInPlate(), talentId: "TAL_5", choices: .init())
        XCTAssertEqual(r.lines.map(\.value), [-1])
        XCTAssertEqual(r.lines.first?.ruleId, "COND_1")
        XCTAssertTrue(r.lines.allSatisfy(\.isZustand))
    }

    func testATalentNotHinderedGetsNone() throws {
        let unhindered = try XCTUnwrap(RulesEngineStore.shared?.checks.hinderedByBelastung
            .first { $0.value == .bool(false) }?.key)
        XCTAssertTrue(TalentBelastung.lines(hero: try boronmirInPlate(), talentId: unhindered, choices: .init()).lines.isEmpty)
    }

    func testAMaybeTalentCountsOnlyWhenThePlayerSaysSo() throws {
        let maybe = try XCTUnwrap(RulesEngineStore.shared?.checks.hinderedByBelastung
            .first { $0.value == .string("maybe") }?.key)
        let hero = try boronmirInPlate()
        XCTAssertTrue(TalentBelastung.lines(hero: hero, talentId: maybe, choices: .init()).lines.isEmpty)
        var yes = TalentBelastung.Choices(); yes.belastungZaehlt = true
        XCTAssertEqual(TalentBelastung.lines(hero: hero, talentId: maybe, choices: yes).lines.map(\.value), [-1])
    }

    func testPuttingTheArmourDownForThisCheckRemovesTheLine() throws {
        let hero = try boronmirInPlate()
        var c = TalentBelastung.Choices()
        c.putDown = Set(hero.armors.filter(\.isEquipped).map(\.name))
        XCTAssertTrue(TalentBelastung.lines(hero: hero, talentId: "TAL_5", choices: c).lines.isEmpty)
        XCTAssertTrue(hero.armors.contains { $0.isEquipped }, "the stored loadout does not change")
    }

    func testIgnoringKeepsTheLineStruckAndAddsNothing() throws {
        var c = TalentBelastung.Choices(); c.ignoreBelastung = true
        let r = TalentBelastung.lines(hero: try boronmirInPlate(), talentId: "TAL_5", choices: c)
        XCTAssertTrue(r.struck)
        XCTAssertEqual(r.effectiveLines.reduce(0) { $0 + $1.value }, 0)
        XCTAssertEqual(r.lines.map(\.value), [-1])
    }

    /// The −5 Zustand cap is applied exactly once over the *combined* Zustand lines — the Swift
    /// `ModifierEngine`'s own Zustand lines (Furcht, Betäubung: `StateModifiers`, `−level` each,
    /// domains `Set(CheckDomain.allCases)` so they hit a talent check too) plus `TalentBelastung`'s
    /// COND_1 line for Boronmir in plate (`−1`).
    ///
    /// Furcht IV and Betäubung IV alone already sum to −8, past the cap on their own: `evaluate`
    /// (`ModifierEngine.evaluate`) caps them first and appends its own correction line
    /// (`+3`, tagged `source.zustandCap`, `isZustand: false`) so the *base* list already totals
    /// exactly −5. `TalentBelastung.combinedModifierLines` must drop that line before folding in
    /// the `−1` Belastung line and capping the union once (−8 + −1 = −9 → one `+4` correction),
    /// landing on −5 again with a single cap line.
    ///
    /// This is exactly the scenario that catches either failure mode:
    /// - **capped twice** (the old `+3` line is *not* dropped): `applyingZustandCap` still reads
    ///   zustand penalty as −9 (the stale `+3` line is `isZustand: false`, so it is not part of
    ///   that sum either way) and appends a *second* `+4` correction on top of the first. The
    ///   result carries **two** `source.zustandCap` lines and sums to −8 + 3 − 1 + 4 = **−2**, not
    ///   −5 — far too lenient a penalty.
    /// - **not capped at all** (the union is returned uncorrected): the result sums to
    ///   −8 − 1 = **−9**, with **zero** `source.zustandCap` lines.
    ///
    /// Both fail the assertions below; only "capped exactly once over the union" lands on a single
    /// correction line and a total of exactly −5.
    func testTheCapAppliesOnceOverTheCombinedZustandLines() throws {
        let hero = try boronmirInPlate()
        hero.setStateLevel("furcht", level: 4)
        hero.setStateLevel("betaeubung", level: 4)

        var situation = Situation(hero: hero, domain: .talentCheck)
        situation.talentId = "TAL_5"
        let base = ModifierEngine.shared.evaluate(context: situation)

        // The base line already needs its own cap: Furcht IV (−4) + Betäubung IV (−4) = −8.
        XCTAssertEqual(base.reduce(0) { $0 + $1.value }, -5, "the Swift-only Zustände are already capped")
        XCTAssertEqual(base.filter { $0.source == L("source.zustandCap") }.count, 1)

        let belastung = TalentBelastung.lines(hero: hero, talentId: "TAL_5", choices: .init())
        XCTAssertEqual(belastung.effectiveLines.map(\.value), [-1], "Boronmir in plate is hindered on TAL_5")

        let combined = TalentBelastung.combinedModifierLines(base: base, belastung: belastung)

        let capLines = combined.filter { $0.source == L("source.zustandCap") }
        XCTAssertEqual(capLines.count, 1, "the cap must be applied exactly once over the combined lines")
        XCTAssertEqual(combined.reduce(0) { $0 + $1.value }, -5,
                       "−8 (Furcht+Betäubung) and −1 (Belastung) cap once to −5, not −2 (capped twice) or −9 (never capped)")
    }
}
