import XCTest
@testable import Hesindion

/// Tests for recorded talent-check aggregation (overall, per-ability, per-session).
final class TalentStatisticsTests: XCTestCase {

    private typealias Check = TalentStatistics.Check
    private func at(_ hours: Double) -> Date { Date(timeIntervalSince1970: hours * 3600) }

    func testRecordIsNilWhenNeverRolled() {
        XCTAssertNil(TalentStatistics.record(for: "Klettern", checks: []))
        let other = [Check(name: "Verbergen", succeeded: true, date: at(0))]
        XCTAssertNil(TalentStatistics.record(for: "Klettern", checks: other))
    }

    func testOverallRate() {
        let checks = [
            Check(name: "A", succeeded: true, date: at(0)),
            Check(name: "B", succeeded: false, date: at(1)),
            Check(name: "A", succeeded: true, date: at(2)),
        ]
        XCTAssertEqual(TalentStatistics.overallRate(checks)!, 2.0 / 3.0, accuracy: 1e-9)
        XCTAssertNil(TalentStatistics.overallRate([]))
    }

    func testPerTalentRecordWithSessions() {
        // Verbergen: session 1 = 3 rolls (2 successes), session 2 (>8h later) = 1 fail.
        // Klettern in between should be ignored for Verbergen.
        let checks = [
            Check(name: "Verbergen", succeeded: true,  date: at(0)),
            Check(name: "Verbergen", succeeded: true,  date: at(1)),
            Check(name: "Verbergen", succeeded: false, date: at(2)),
            Check(name: "Klettern",  succeeded: true,  date: at(2)),
            Check(name: "Verbergen", succeeded: false, date: at(20)), // +18h → new session
        ]
        let record = TalentStatistics.record(for: "Verbergen", checks: checks)!
        XCTAssertEqual(record.total, 4)
        XCTAssertEqual(record.successes, 2)
        XCTAssertEqual(record.rate, 0.5, accuracy: 1e-9)
        XCTAssertEqual(record.sessionCount, 2)
        // Best session is session 1: 2/3 beats session 2's 0/1.
        XCTAssertEqual(record.bestSession?.successes, 2)
        XCTAssertEqual(record.bestSession?.total, 3)
    }

    func testBestSessionTieBreaksOnMoreRolls() {
        // Two sessions both 100%, the one with more rolls wins.
        let checks = [
            Check(name: "X", succeeded: true, date: at(0)),
            Check(name: "X", succeeded: true, date: at(1)),
            Check(name: "X", succeeded: true, date: at(20)),
        ]
        let record = TalentStatistics.record(for: "X", checks: checks)!
        XCTAssertEqual(record.bestSession?.total, 2)
        XCTAssertEqual(record.bestSession?.rate, 1.0)
    }
}
