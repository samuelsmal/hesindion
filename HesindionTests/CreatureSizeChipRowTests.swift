import XCTest
@testable import Hesindion

/// The announcement's size chips each print what the size costs the hero's
/// attack (GRW_groessenkategorie GK3), so every chip has the same two lines
/// and the same height (issue #38).
final class CreatureSizeChipRowTests: XCTestCase {

    func testEverySizePrintsItsAttackModifier() {
        XCTAssertEqual(CreatureSizeChipRow.attackDetail(.winzig), "AT −4")
        for size in CreatureSize.allCases where size != .winzig {
            XCTAssertEqual(CreatureSizeChipRow.attackDetail(size), "AT ±0", "\(size)")
        }
    }
}
