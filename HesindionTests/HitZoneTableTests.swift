import XCTest
@testable import Hesindion

final class HitZoneTableTests: XCTestCase {

    private static let allPlans: [BodyPlan] = [
        .humanoid(.klein), .humanoid(.mittel), .humanoid(.gross),
        .vierbeinig(.klein), .vierbeinig(.mittel), .vierbeinig(.gross),
        .sechsbeinigMitSchwanz(.gross), .sechsbeinigMitSchwanz(.riesig),
        .fangarme(.mittel), .keineZonen,
    ]

    /// The property that matters: every table is total over 1...20.
    func testEveryPlanCoversEveryRollExactlyOnce() {
        for plan in Self.allPlans {
            var covered = Set<Int>()
            for roll in 1...20 {
                _ = HitZoneTable.lookup(roll, plan: plan)   // must not trap
                covered.insert(roll)
            }
            XCTAssertEqual(covered, Set(1...20), "plan \(plan) has a gap")
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
