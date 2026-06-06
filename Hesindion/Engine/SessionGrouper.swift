import Foundation

/// Groups time-stamped items into "sessions": maximal runs of items where each
/// consecutive pair is less than `gap` apart. A new session begins whenever the
/// gap to the neighbouring item is `>= gap`. Default gap is 8 hours, so a session
/// is at least 8h away from the previous and next one.
///
/// Pure. The comparison uses the absolute interval, so input may be ascending or
/// descending by date — but it **must be monotonically sorted** for the grouping
/// to be meaningful. Returned groups preserve input order.
enum SessionGrouper {
    /// Minimum separation between two sessions (8 hours).
    static let defaultGap: TimeInterval = 8 * 60 * 60

    static func group<T>(_ items: [T], by date: (T) -> Date, gap: TimeInterval = defaultGap) -> [[T]] {
        guard !items.isEmpty else { return [] }
        var sessions: [[T]] = []
        var current: [T] = [items[0]]
        for i in 1..<items.count {
            let gapToPrev = abs(date(items[i]).timeIntervalSince(date(items[i - 1])))
            if gapToPrev >= gap {
                sessions.append(current)
                current = [items[i]]
            } else {
                current.append(items[i])
            }
        }
        sessions.append(current)
        return sessions
    }
}
