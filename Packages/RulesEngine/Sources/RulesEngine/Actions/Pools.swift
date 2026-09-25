import Foundation

// The pools (spec §7): LE, AsP, KaP, Schips, ammunition, and the round's Aktionen and freie
// Aktionen (ruling R23). Their current values live in `Situation.pools`; the rules read LE and AsP
// as the derived facts `hero.leCurrent` / `hero.aspCurrent` and the targets `leCurrent` /
// `aspCurrent` (ruling R39). Only an event changes them (`Situation.applying`).

extension Pool {
    /// The derived fact the rules read the pool's current value as (R39); nil for a pool no fact
    /// names.
    public var currentFact: String? {
        switch self {
        case .le: "hero.leCurrent"
        case .asp: "hero.aspCurrent"
        default: nil
        }
    }

    /// The target whose base is the pool's current value (R39).
    public var currentTarget: String? {
        switch self {
        case .le: "leCurrent"
        case .asp: "aspCurrent"
        default: nil
        }
    }

    /// The pool whose current value the derived fact `name` reads.
    static func current(fact name: String) -> Pool? { allCases.first { $0.currentFact == name } }
    /// The pool whose current value is the base of the target `name`.
    static func current(target name: String) -> Pool? { allCases.first { $0.currentTarget == name } }
}

// MARK: - Applying events

extension Situation {
    /// The situation after `events`, in order: the one place state changes (spec §7).
    /// - `paid` lowers `pools[pool].current` by `amount`. LE may fall to 0 and below (im
    ///   Sterben). A pool the situation does not track stays untracked. Paying LeP is not damage:
    ///   it changes the pool and nothing else (no hit, no RS, no Wundschwelle).
    /// - `gained` adds `levels` (1 when absent) to `owned[rule].level`; `cleared` removes `levels`
    ///   (all when absent). A rule whose level reaches 0 is no longer owned.
    /// - The other kinds are Tasks 26–28's and change nothing yet.
    public func applying(_ events: [Event]) -> Situation {
        var s = self
        for e in events { s.apply(e) }
        return s
    }

    private mutating func apply(_ e: Event) {
        switch e.kind {
        case .paid:
            guard let pool = e.pool, let amount = e.amount, var state = pools[pool] else { return }
            state.current -= amount
            pools[pool] = state
        case .gained:
            guard let rule = e.rule else { return }
            changeLevel(of: rule, by: e.levels ?? 1)
        case .cleared:
            guard let rule = e.rule else { return }
            if let n = e.levels { changeLevel(of: rule, by: -n) } else { owned[rule] = nil }
        case .progressed, .completed, .brokenOff, .itemChanged, .logged:
            break
        }
    }

    private mutating func changeLevel(of rule: String, by delta: Int) {
        let level = (owned[rule]?.level ?? 0) + delta
        guard level > 0 else {
            owned[rule] = nil
            return
        }
        var entry = owned[rule] ?? OwnedRule(level: level)
        entry.level = level
        owned[rule] = entry
    }
}

// MARK: - The bound of a split choice

extension Evaluation {
    /// MIGRATION probe-magie 20.7: an offered `split.<pool>` may take up to the cost of the
    /// offering rule's `cost { split }` over that pool, less the other pools' minimums
    /// (SA_74.VP1: 8 − 1 AsP = 7). nil when the choice names no split, or the cost is unknown.
    func splitBound(of o: Offer, rule: String, level: Int?, depth: Int) -> Int? {
        let prefix = "split."
        guard o.choice.hasPrefix(prefix), let pool = Pool(rawValue: String(o.choice.dropFirst(prefix.count))) else {
            return nil
        }
        for e in book.rules[rule]?.clauses.flatMap(\.effects) ?? [] {
            guard case .cost(let c) = e.payload, let split = c.split, split.pools.contains(pool) else { continue }
            guard let amount = value(c.amount, level: level, rule: rule, depth: depth).value else { return nil }
            return max(0, amount - split.pools.filter { $0 != pool }.reduce(0) { $0 + (split.min[$1] ?? 0) })
        }
        return nil
    }
}
