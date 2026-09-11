// HesindionTests/WoundEffectCatalogTests.swift
import XCTest
@testable import Hesindion

final class WoundEffectCatalogTests: XCTestCase {

    func testEveryZoneHasAnEffect() {
        for zone in HitZone.allCases {
            XCTAssertEqual(WoundEffectCatalog.effect(for: zone).zone, zone)
        }
    }

    func testZoneEffects() {
        XCTAssertEqual(WoundEffectCatalog.effect(for: .kopf).kind, .raiseState(id: "betaeubung"))
        XCTAssertEqual(WoundEffectCatalog.effect(for: .beine).kind, .setStatus(id: "liegend"))
        XCTAssertEqual(WoundEffectCatalog.effect(for: .torso).kind, .extraDamage(count: 1, sides: 3, flat: 1))
        XCTAssertEqual(WoundEffectCatalog.effect(for: .arme).kind, .reminder)
    }

    func testLimbZonesMapToTheirAnalogue() {
        XCTAssertEqual(WoundEffectCatalog.effect(for: .vordereBeine).kind, .setStatus(id: "liegend"))
        XCTAssertEqual(WoundEffectCatalog.effect(for: .hintereBeine).kind, .setStatus(id: "liegend"))
        XCTAssertEqual(WoundEffectCatalog.effect(for: .mittlereGliedmassen).kind, .reminder)
        XCTAssertEqual(WoundEffectCatalog.effect(for: .schwanz).kind, .reminder)
    }

    /// The catalog must not name a state that StateCatalog does not define.
    func testReferencedStatesExist() {
        for zone in HitZone.allCases {
            switch WoundEffectCatalog.effect(for: zone).kind {
            case .raiseState(let id), .setStatus(let id):
                XCTAssertNotNil(StateCatalog.definition(for: id), "unknown state \(id)")
            case .extraDamage, .reminder:
                break
            }
        }
    }
}
