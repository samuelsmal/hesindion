import XCTest
@testable import Hesindion

/// Größenkategorie: which defences the attacker's size leaves the hero.
final class SizeCategoryRulesTests: XCTestCase {
    func testTheTable() {
        for size in [CreatureSize.winzig, .klein, .mittel] {
            XCTAssertEqual(SizeCategoryRules.allowedDefenses(against: size), [.weaponParry, .shieldParry, .dodge], "\(size)")
        }
        XCTAssertEqual(SizeCategoryRules.allowedDefenses(against: .gross), [.shieldParry, .dodge])
        XCTAssertEqual(SizeCategoryRules.allowedDefenses(against: .riesig), [.dodge])
    }
}
