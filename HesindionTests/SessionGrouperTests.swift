import XCTest
@testable import Hesindion

/// Tests for grouping time-stamped items into play sessions (≥ 8h gaps).
final class SessionGrouperTests: XCTestCase {

    /// Helper: a date `hours` after the epoch.
    private func at(_ hours: Double) -> Date { Date(timeIntervalSince1970: hours * 3600) }

    func testEmpty() {
        XCTAssertTrue(SessionGrouper.group([Date](), by: { $0 }).isEmpty)
    }

    func testSingleItem() {
        let groups = SessionGrouper.group([at(0)], by: { $0 })
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].count, 1)
    }

    func testCloseTogetherIsOneSession() {
        // 0h, 2h, 5h — all gaps < 8h → single session
        let groups = SessionGrouper.group([at(0), at(2), at(5)], by: { $0 })
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].count, 3)
    }

    func testLargeGapSplitsSessions() {
        // 0h, 1h | (9h gap) | 10h, 11h → two sessions of two
        let groups = SessionGrouper.group([at(0), at(1), at(10), at(11)], by: { $0 })
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].count, 2)
        XCTAssertEqual(groups[1].count, 2)
    }

    func testExactlyEightHoursSplits() {
        // gap exactly 8h is >= threshold → new session
        XCTAssertEqual(SessionGrouper.group([at(0), at(8)], by: { $0 }).count, 2)
    }

    func testJustUnderEightHoursIsOneSession() {
        XCTAssertEqual(SessionGrouper.group([at(0), at(7.99)], by: { $0 }).count, 1)
    }

    func testDescendingOrderAlsoGroups() {
        // Newest-first input (as the log is sorted) still groups via absolute gap.
        let groups = SessionGrouper.group([at(11), at(10), at(1), at(0)], by: { $0 })
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].count, 2) // 11h, 10h
        XCTAssertEqual(groups[1].count, 2) // 1h, 0h
    }

    func testCustomGap() {
        // With a 1h gap, 0h and 2h split.
        XCTAssertEqual(SessionGrouper.group([at(0), at(2)], by: { $0 }, gap: 3600).count, 2)
    }
}
