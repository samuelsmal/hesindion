import XCTest
@testable import Hesindion

final class HitZoneTableTests: XCTestCase {

    private static let allPlans: [BodyPlan] = [
        .humanoid(.klein), .humanoid(.mittel), .humanoid(.gross),
        .vierbeinig(.klein), .vierbeinig(.mittel), .vierbeinig(.gross),
        .sechsbeinigMitSchwanz(.gross), .sechsbeinigMitSchwanz(.riesig),
        .fangarme(.mittel), .keineZonen,
    ]

    /// The published DSA 5 Trefferzonen tables, mirrored here (not read from
    /// `HitZoneTable`, which keeps its ranges private) so the test has an
    /// independent reference to compare `lookup`'s actual output against. This is
    /// the same class of assertion as `testHumanoidMittelBoundaries` /
    /// `testFangarmeBoundaries` below, just exhaustive across every plan and roll.
    private static let expectedRanges: [(BodyPlan, [(ClosedRange<Int>, HitZone)])] = [
        (.humanoid(.klein), [(1...6, .kopf), (7...10, .torso), (11...18, .arme), (19...20, .beine)]),
        (.humanoid(.mittel), [(1...2, .kopf), (3...12, .torso), (13...16, .arme), (17...20, .beine)]),
        (.humanoid(.gross), [(1...2, .kopf), (3...6, .torso), (7...16, .arme), (17...20, .beine)]),
        (.vierbeinig(.klein), [(1...4, .kopf), (5...12, .torso), (13...16, .vordereBeine), (17...20, .hintereBeine)]),
        (.vierbeinig(.mittel), [(1...4, .kopf), (5...10, .torso), (11...16, .vordereBeine), (17...20, .hintereBeine)]),
        (.vierbeinig(.gross), [(1...5, .kopf), (6...11, .torso), (12...16, .vordereBeine), (17...20, .hintereBeine)]),
        (.sechsbeinigMitSchwanz(.gross), [
            (1...4, .kopf), (5...12, .torso), (13...14, .vordereBeine),
            (15...16, .mittlereGliedmassen), (17...18, .hintereBeine), (19...20, .schwanz),
        ]),
        (.sechsbeinigMitSchwanz(.riesig), [
            (1...2, .kopf), (3...10, .torso), (11...14, .vordereBeine),
            (15...16, .mittlereGliedmassen), (17...18, .hintereBeine), (19...20, .schwanz),
        ]),
        (.fangarme(.mittel), [(1...2, .torso), (3...6, .kopf), (7...20, .fangarme)]),
        (.keineZonen, [(1...20, .koerper)]),
    ]

    /// The property that matters: each table *partitions* 1...20 — every roll maps
    /// to exactly the zone the published rules assign it, so a gap (some roll
    /// falling through to nothing) and an overlap (one zone's range silently
    /// encroaching on a neighbour's) are both caught. A prior version of this test
    /// built `covered` from the loop variable instead of `lookup`'s result, so the
    /// assertion was `Set(1...20) == Set(1...20)` — unconditionally true.
    func testEveryPlanPartitionsEveryRollExactly() {
        for (plan, ranges) in Self.expectedRanges {
            var expectedZone: [Int: HitZone] = [:]
            for (range, zone) in ranges {
                for roll in range {
                    XCTAssertNil(expectedZone[roll], "plan \(plan) reference table overlaps at roll \(roll)")
                    expectedZone[roll] = zone
                }
            }
            XCTAssertEqual(Set(expectedZone.keys), Set(1...20), "plan \(plan) reference table has a gap")

            for roll in 1...20 {
                XCTAssertEqual(
                    HitZoneTable.lookup(roll, plan: plan).zone, expectedZone[roll],
                    "plan \(plan) roll \(roll) did not resolve to the published zone")
            }
        }
    }

    func testHumanoidMittelBoundaries() {
        let plan = BodyPlan.humanoid(.mittel)
        XCTAssertEqual(HitZoneTable.lookup(1, plan: plan).zone, .kopf)
        XCTAssertEqual(HitZoneTable.lookup(2, plan: plan).zone, .kopf)
        XCTAssertEqual(HitZoneTable.lookup(3, plan: plan).zone, .torso)
        XCTAssertEqual(HitZoneTable.lookup(12, plan: plan).zone, .torso)
        XCTAssertEqual(HitZoneTable.lookup(13, plan: plan).zone, .arme)
        XCTAssertEqual(HitZoneTable.lookup(16, plan: plan).zone, .arme)
        XCTAssertEqual(HitZoneTable.lookup(17, plan: plan).zone, .beine)
        XCTAssertEqual(HitZoneTable.lookup(20, plan: plan).zone, .beine)
    }

    func testSideParity() {
        let plan = BodyPlan.humanoid(.mittel)
        XCTAssertEqual(HitZoneTable.lookup(13, plan: plan).side, .links)   // odd
        XCTAssertEqual(HitZoneTable.lookup(16, plan: plan).side, .rechts)  // even
    }

    func testUnpairedZonesHaveNoSide() {
        let plan = BodyPlan.humanoid(.mittel)
        XCTAssertNil(HitZoneTable.lookup(1, plan: plan).side)   // Kopf
        XCTAssertNil(HitZoneTable.lookup(5, plan: plan).side)   // Torso
        XCTAssertNil(HitZoneTable.lookup(19, plan: .sechsbeinigMitSchwanz(.gross)).side)  // Schwanz
    }

    func testOutOfRangeRollsClamp() {
        let plan = BodyPlan.humanoid(.mittel)
        XCTAssertEqual(HitZoneTable.lookup(0, plan: plan).zone, HitZoneTable.lookup(1, plan: plan).zone)
        XCTAssertEqual(HitZoneTable.lookup(21, plan: plan).zone, HitZoneTable.lookup(20, plan: plan).zone)
    }

    func testUnlistedSizeFallsBackToNearest() {
        XCTAssertEqual(
            HitZoneTable.lookup(1, plan: .sechsbeinigMitSchwanz(.klein)).zone,
            HitZoneTable.lookup(1, plan: .sechsbeinigMitSchwanz(.gross)).zone
        )
    }

    /// No table is printed for winzig: it rolls on the klein one.
    func testWinzigRollsOnTheKleinTable() {
        for roll in 1...20 {
            XCTAssertEqual(
                HitZoneTable.lookup(roll, plan: .humanoid(.winzig)),
                HitZoneTable.lookup(roll, plan: .humanoid(.klein)), "roll \(roll)")
            XCTAssertEqual(
                HitZoneTable.lookup(roll, plan: .vierbeinig(.winzig)),
                HitZoneTable.lookup(roll, plan: .vierbeinig(.klein)), "roll \(roll)")
        }
        XCTAssertEqual(HitZoneTable.zones(for: .humanoid(.winzig)), HitZoneTable.zones(for: .humanoid(.klein)))
    }

    /// The announcement's body-plan picker keeps a size the plan has a table
    /// for (by table key) and otherwise resets to the plan's first published one.
    func testBodyPlanPickerKeepsOrResetsTheSize() {
        XCTAssertEqual(BodyPlanKind.humanoid.size(keeping: .winzig), .winzig)
        XCTAssertEqual(BodyPlanKind.fangarme.size(keeping: .winzig), .mittel)
        XCTAssertEqual(BodyPlanKind.sechsbeinigMitSchwanz.size(keeping: .klein), .gross)
        XCTAssertEqual(BodyPlanKind.keineZonen.size(keeping: .winzig), .winzig)
    }

    /// Fangarme is the one table where Torso precedes Kopf — pin the boundaries so a
    /// future "tidy-up" cannot silently normalise the order.
    func testFangarmeBoundaries() {
        let plan = BodyPlan.fangarme(.mittel)
        XCTAssertEqual(HitZoneTable.lookup(1, plan: plan).zone, .torso)
        XCTAssertEqual(HitZoneTable.lookup(2, plan: plan).zone, .torso)
        XCTAssertEqual(HitZoneTable.lookup(3, plan: plan).zone, .kopf)
        XCTAssertEqual(HitZoneTable.lookup(6, plan: plan).zone, .kopf)
        XCTAssertEqual(HitZoneTable.lookup(7, plan: plan).zone, .fangarme)
        XCTAssertEqual(HitZoneTable.lookup(20, plan: plan).zone, .fangarme)
    }

    func testKeineZonenAlwaysMapsToKoerper() {
        for roll in 1...20 {
            XCTAssertEqual(HitZoneTable.lookup(roll, plan: .keineZonen).zone, .koerper)
        }
    }

    func testFangarmeAndKoerperHaveNoSide() {
        XCTAssertNil(HitZoneTable.lookup(10, plan: .fangarme(.mittel)).side)
        XCTAssertNil(HitZoneTable.lookup(5, plan: .keineZonen).side)
    }
}
