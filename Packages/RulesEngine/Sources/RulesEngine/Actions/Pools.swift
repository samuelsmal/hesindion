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
    /// - `damaged` (R53) lowers the pool the same way. It is the damage a hit did; applying it
    ///   runs no chain again (the chain gave it).
    /// - `gained` adds `levels` (1 when absent) to `owned[rule].level`; `cleared` removes `levels`
    ///   (all when absent). A rule whose level reaches 0 is no longer owned.
    /// - The other kinds are Tasks 26–28's and change nothing yet.
    ///
    /// Arithmetic saturates: an event decoded with an extreme amount or count never traps.
    /// This form trusts a `gained`'s `levels` (the action layer bounds them); `applying(_:book:)`
    /// also holds each rule within its Stufen.
    public func applying(_ events: [Event]) -> Situation {
        var s = self
        for e in events { s.apply(e, book: nil) }
        return s
    }

    /// `applying(_:)`, holding a `gained` within the rule's Stufen (`Rule.most`), as the action
    /// layer does: a state is owned once, a condition at most at its highest Stufe.
    public func applying(_ events: [Event], book: RuleBook) -> Situation {
        var s = self
        for e in events { s.apply(e, book: book) }
        return s
    }

    private mutating func apply(_ e: Event, book: RuleBook?) {
        switch e.kind {
        case .paid, .damaged:
            guard let pool = e.pool, let amount = e.amount, var state = pools[pool] else { return }
            state.current = state.current.subtractingSaturating(amount)
            pools[pool] = state
        case .gained:
            guard let rule = e.rule else { return }
            changeLevel(of: rule, by: e.levels ?? 1, most: book?.rules[rule]?.most)
        case .cleared:
            guard let rule = e.rule else { return }
            if let n = e.levels { changeLevel(of: rule, by: n == .min ? .min : -abs(n)) } else { owned[rule] = nil }
        case .progressed, .completed, .brokenOff, .itemChanged, .logged:
            break
        }
    }

    private mutating func changeLevel(of rule: String, by delta: Int, most: Int? = nil) {
        var level = (owned[rule]?.level ?? 0).addingSaturating(delta)
        if let most, delta > 0 { level = min(level, max(most, owned[rule]?.level ?? 0)) }
        guard level > 0 else {
            owned[rule] = nil
            return
        }
        var entry = owned[rule] ?? OwnedRule(level: level)
        entry.level = level
        owned[rule] = entry
    }
}

extension Rule {
    /// The highest Stufe the hero can have: `levels`, 1 for a state, nil (no bound) for a rule
    /// with neither (COND_9 keeps Stufen above IV).
    public var most: Int? { levels ?? (kind == .state ? 1 : nil) }
}

extension Int {
    func addingSaturating(_ other: Int) -> Int {
        let (r, overflow) = addingReportingOverflow(other)
        return overflow ? (other > 0 ? .max : .min) : r
    }

    func subtractingSaturating(_ other: Int) -> Int {
        let (r, overflow) = subtractingReportingOverflow(other)
        return overflow ? (other > 0 ? .min : .max) : r
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
