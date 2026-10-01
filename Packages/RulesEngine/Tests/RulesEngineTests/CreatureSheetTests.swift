import XCTest
@testable import RulesEngine

/// Issue #48: the mount as a subject of its own, and the three facts it hands the hero.
final class CreatureSheetTests: XCTestCase {
    let engine = Engine(book: HeroSheetTests.book)

    static func kupperus(le: Int, advantages: [String] = ["zaehes-tier"]) -> CreatureSheet {
        var owned: [String: OwnedRule] = ["svellttaler-kaltblut": .init()]
        for a in advantages { owned[a] = .init() }
        return CreatureSheet(owned: owned, gs: 15, leMax: 137, leCurrent: le, vw: 14,
                             attacks: ["Tritt": 19, "Biss": 16, "Niederreiten": 19])
    }

    func testTheCreatureIsTheSubject() {
        let s = Situation(creature: Self.kupperus(le: 137))
        XCTAssertEqual(s.facts["subject"]?.value, .string("creature"))
        XCTAssertEqual(s.base["gs"], 15)
        XCTAssertEqual(s.base["at(with: Tritt)"], 19)
        XCTAssertEqual(s.pools[.le], PoolState(current: 137, max: 137))
    }

    func testKupperusAt60LePHasSchmerzIIAndActsAtI() {
        let m = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 60)))
        XCTAssertEqual(m.schmerz, 2)                       // has II
        XCTAssertEqual(m.schmerzBreakdown.result, 1)       // acts at I (Zähes Tier)
        XCTAssertEqual(m.gs.result, 14)
        XCTAssertFalse(m.handlungsunfaehig)
    }

    /// Issue #51: each threshold term's line carries the LeP at or below which it gives its Stufe,
    /// scaled to the mount's max LeP (ruling svellttaler-kaltblut.svellttaler-schmerz-thresholds).
    func testEachThresholdLineCarriesItsLeP() {
        let at137 = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 60))).schmerzBreakdown
        XCTAssertEqual(at137.base?.parts.map(\.threshold), [89, 60, 29, 5])
        XCTAssertEqual(at137.base?.parts.map(\.value), [1, 1, 0, 0])

        var printed = Self.kupperus(le: 49)
        printed.leMax = 75
        let at75 = engine.mountFacts(in: Situation(creature: printed)).schmerzBreakdown
        XCTAssertEqual(at75.base?.parts.map(\.threshold), [49, 33, 16, 5])
        XCTAssertEqual(at75.base?.parts.map(\.value), [1, 0, 0, 0])   // 49 is the threshold itself
    }

    /// Only a 0-or-1 step over a fact has a threshold: a sum term like Belastung's has none.
    func testALineThatIsNoStepHasNoThreshold() {
        let gs = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 60))).gs
        XCTAssertTrue(gs.shownLines.allSatisfy { $0.threshold == nil })
    }

    func testWithoutZaehesTierTheGSFallsByTheFullStufe() {
        let m = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 60, advantages: [])))
        XCTAssertEqual(m.schmerz, 2)
        XCTAssertEqual(m.gs.result, 13)
    }

    func testAtFullLeThereIsNoSchmerz() {
        let m = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 137)))
        XCTAssertEqual(m.schmerz, 0)
        XCTAssertEqual(m.gs.result, 15)
        XCTAssertFalse(m.handlungsunfaehig)
    }

    func testAt5LePTheMountIsHandlungsunfaehig() {
        let m = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 5)))
        XCTAssertEqual(m.schmerz, 4)
        XCTAssertEqual(m.gs.result, 0)
        XCTAssertTrue(m.handlungsunfaehig)
    }

    func testTheFactsAreDerived() {
        let facts = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 60))).facts
        XCTAssertEqual(Set(facts.map(\.name)), ["mount.gs", "mount.schmerz", "mount.handlungsunfaehig"])
        XCTAssertTrue(facts.allSatisfy { $0.owner == .derived })
        XCTAssertEqual(facts.first { $0.name == "mount.gs" }?.value, .int(14))
    }

    /// RK14 reads the stated `mount.gs`, not the profile's `provide mount.gs: 12`.
    func testTheChargeReadsTheMountsCurrentGS() {
        let mount = engine.mountFacts(in: Situation(creature: Self.kupperus(le: 60, advantages: [])))
        var sheet = HeroSheetTests.boronmir()
        sheet.owned["SA_43"] = .init()
        sheet.owned["svellttaler-kaltblut"] = .init()
        let charge = Situation(sheet: sheet).stating(mount.facts + [
            Fact(name: "hero.mounted", value: .bool(true), owner: .loadout),
            Fact(name: "choice.order", value: .string("sturmangriffZuPferd"), owner: .player),
            Fact(name: "action.gait", value: .string("galopp"), owner: .player),
            Fact(name: "action.attack", value: .string("hit"), owner: .player),
        ])
        let rk14 = engine.evaluate(Query("tp"), in: charge).lines
            .filter { $0.origin?.rule == "reiterkampf" && $0.origin?.clause == "RK14" }
        XCTAssertEqual(rk14.map(\.value), [9])   // 2 + ⌈13/2⌉
    }
}
