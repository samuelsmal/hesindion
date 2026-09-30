import XCTest
@testable import Hesindion

/// Issue #34, trefferzonen.TZ2: under the Fokusregel every landed hit has a zone.
/// An aimed attack hits the zone it named; an attack that named none has its zone
/// rolled with 1W20 on the target's table *after* the hit.
final class LandedHitZoneTests: XCTestCase {

    private let humanoid = BodyPlan.humanoid(.mittel)

    func testAnAimedHitCarriesItsZoneWithoutARoll() {
        let landed = LandedHitZone.resolve(rulesActive: true, plan: humanoid, aimed: .kopf, roll: nil)
        XCTAssertEqual(landed, .aimed(.kopf))
        XCTAssertEqual(landed.zone, .kopf)
        XCTAssertFalse(landed.isAwaitingRoll)
    }

    func testAnUnaimedHitAsksForTheRoll() {
        let landed = LandedHitZone.resolve(rulesActive: true, plan: humanoid, aimed: nil, roll: nil)
        XCTAssertEqual(landed, .awaitingRoll)
        XCTAssertNil(landed.zone)
        XCTAssertTrue(landed.isAwaitingRoll)
    }

    /// TZ4a: 3–12 is Torso on the mittel humanoid table.
    func testTheRollIsLookedUpOnTheTargetsTable() {
        let landed = LandedHitZone.resolve(rulesActive: true, plan: humanoid, aimed: nil, roll: 7)
        XCTAssertEqual(landed, .rolled(HitZoneHit(zone: .torso, side: nil), roll: 7))
        XCTAssertEqual(landed.zone, .torso)
    }

    /// TZ4d: 1–4 is Kopf on the small four-legged table, where the humanoid one
    /// would say Torso — the opponent's table, not the hero's.
    func testAFourLeggedTargetRollsOnItsOwnTable() {
        let landed = LandedHitZone.resolve(rulesActive: true, plan: .vierbeinig(.klein), aimed: nil, roll: 3)
        XCTAssertEqual(landed.zone, .kopf)
    }

    /// TZ4c: an even roll on a paired zone is the right side.
    func testAPairedZoneKeepsItsSide() {
        let landed = LandedHitZone.resolve(rulesActive: true, plan: humanoid, aimed: nil, roll: 14)
        XCTAssertEqual(landed, .rolled(HitZoneHit(zone: .arme, side: .rechts), roll: 14))
    }

    func testWithoutTheFokusRuleThereIsNoZone() {
        XCTAssertEqual(LandedHitZone.resolve(rulesActive: false, plan: humanoid, aimed: nil, roll: nil), .notApplicable)
        XCTAssertEqual(LandedHitZone.resolve(rulesActive: false, plan: humanoid, aimed: .kopf, roll: nil), .notApplicable)
    }

    func testATargetWithoutZonesHasNoZone() {
        let landed = LandedHitZone.resolve(rulesActive: true, plan: .keineZonen, aimed: nil, roll: nil)
        XCTAssertEqual(landed, .notApplicable)
        XCTAssertFalse(landed.isAwaitingRoll)
    }
}
