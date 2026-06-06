import Foundation

/// Pure aggregation of *recorded* talent-check results (from the action log) into
/// success rates — overall, per ability, and grouped into play sessions.
///
/// Operates on a lightweight `Check` value so it stays testable without SwiftData.
enum TalentStatistics {

    /// One recorded talent check, distilled from a `LogEntry` / `TalentCheckPayload`.
    struct Check {
        let name: String
        let succeeded: Bool
        let date: Date

        init(name: String, succeeded: Bool, date: Date) {
            self.name = name
            self.succeeded = succeeded
            self.date = date
        }
    }

    /// Success score for a single session.
    struct SessionScore: Equatable {
        let total: Int
        let successes: Int
        var rate: Double { total == 0 ? 0 : Double(successes) / Double(total) }
    }

    /// Recorded stats for one ability.
    struct Record: Equatable {
        let total: Int
        let successes: Int
        let sessionCount: Int
        let bestSession: SessionScore?
        var rate: Double { total == 0 ? 0 : Double(successes) / Double(total) }
    }

    /// Overall recorded success rate across all checks, or nil if there are none.
    static func overallRate(_ checks: [Check]) -> Double? {
        guard !checks.isEmpty else { return nil }
        let successes = checks.filter(\.succeeded).count
        return Double(successes) / Double(checks.count)
    }

    /// Recorded stats for a single ability, or nil if it was never rolled.
    static func record(for name: String, checks: [Check], gap: TimeInterval = SessionGrouper.defaultGap) -> Record? {
        let relevant = checks.filter { $0.name == name }
        guard !relevant.isEmpty else { return nil }

        let sorted = relevant.sorted { $0.date < $1.date }
        let sessions = SessionGrouper.group(sorted, by: \.date, gap: gap)
        let scores = sessions.map { session in
            SessionScore(total: session.count, successes: session.filter(\.succeeded).count)
        }
        let best = scores.max { lhs, rhs in
            lhs.rate != rhs.rate ? lhs.rate < rhs.rate : lhs.total < rhs.total
        }

        return Record(
            total: relevant.count,
            successes: relevant.filter(\.succeeded).count,
            sessionCount: sessions.count,
            bestSession: best
        )
    }
}
