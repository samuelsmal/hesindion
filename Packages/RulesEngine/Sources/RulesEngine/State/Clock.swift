import Foundation

// The game clock and spans (spec §7): Kampfrunden in a fight, minutes outside. The player
// advances it (`.endRound`, `.endFight`, `.advanceClock(minutes:)`); a recurring cost
// (`cost { every }`) falls due on it, and a Zustand gained or cleared for a span ends with it.

/// The game clock: the Kampfrunde and the minutes of game time.
public struct Clock: Codable, Hashable, Sendable {
    /// The current Kampfrunde, 1 at the start.
    public var round: Int
    /// The game time in minutes. A recurring cost falls due at every multiple of its interval.
    public var minutes: Int

    public init(round: Int = 1, minutes: Int = 0) { self.round = round; self.minutes = minutes }

    /// How many multiples of `interval` the minutes pass on the way from `from` to `to`
    /// (`from` < m ≤ `to`): 2 AsP every 5 minutes, from 0 to 12, falls due twice (5 and 10).
    /// 0 for an interval that is not positive or a clock that does not move forward.
    public static func due(every interval: Int, from: Int, to: Int) -> Int {
        guard interval > 0, to > from else { return 0 }
        func marks(_ m: Int) -> Int { m >= 0 ? m / interval : -((-m + interval - 1) / interval) }
        return marks(to) - marks(from)
    }
}

/// A change of a rule's Stufe that lasts for a span (`gain { rule, levels, span }`): when the
/// span ends, the change is undone by the inverse event.
public struct TimedChange: Codable, Hashable, Sendable {
    public var rule: String
    /// The Stufen the change added (positive) or took (negative).
    public var levels: Int
    public var span: Span
    /// The clause of the `gain` that made it.
    public var origin: ClauseRef?

    public init(rule: String, levels: Int, span: Span, origin: ClauseRef? = nil) {
        self.rule = rule; self.levels = levels; self.span = span; self.origin = origin
    }
}

extension Span {
    /// The spans that end with this one: a round's end ends the action's too; a fight's end the
    /// round's and the action's. `whileFormed` ends when its choice is cleared, `untilCleared`
    /// with a `cleared` event: neither ends with the clock.
    var ending: Set<Span> {
        switch self {
        case .action: [.action]
        case .round: [.action, .round]
        case .fight: [.action, .round, .fight]
        case .whileFormed, .untilCleared: []
        }
    }
}
