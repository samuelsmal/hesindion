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
    /// - `restored` (R64) raises `pools[pool].current` by `amount`, held within the pool's caps
    ///   by the action that gave it (regeneration.R5).
    /// - `damaged` (R53) lowers the pool the same way. It is the damage a hit did; applying it
    ///   runs no chain again (the chain gave it).
    /// - `gained` adds `levels` (1 when absent) to `owned[rule].level`; `cleared` removes `levels`
    ///   (all when absent). A rule whose level reaches 0 is no longer owned. With a `span`, the
    ///   change is recorded in `timed` (the inverse event, with the same span, takes it out
    ///   again); a `cleared` without a span ends every Stufe gained for a span of that rule
    ///   (`untilCleared` lasts until then).
    /// - `progressed` starts (the first) or advances the process `process`: its progress, its
    ///   steps, the instance it is bound to, the round it started in. `completed` and `brokenOff`
    ///   end it.
    /// - `itemChanged` sets each field of `change` on the instance `item`. A destroyed item leaves
    ///   the loadout: the slot holding it is stated empty (`loadout.<slot>: null`) and its
    ///   `loadout.<slot>.*` facts go.
    /// - `clockAdvanced` moves the clock and ends its `ends` (`end(_:book:)`); `stated` sets its
    ///   fact (no value: the fact goes).
    /// - `logged` changes nothing.
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
        case .restored:
            // Ruling R64: the pool rises; the action held the amount within the pool's caps.
            guard let pool = e.pool, let amount = e.amount, var state = pools[pool] else { return }
            state.current = state.current.addingSaturating(amount)
            pools[pool] = state
        case .gained:
            guard let rule = e.rule else { return }
            changeLevel(of: rule, by: e.levels ?? 1, most: book?.rules[rule]?.most)
            if let span = e.span { time(rule, (e.levels ?? 1), span, e.origin) }
        case .cleared:
            guard let rule = e.rule else { return }
            let before = owned[rule]?.level ?? 0
            if let n = e.levels { changeLevel(of: rule, by: n == .min ? .min : -abs(n)) } else { owned[rule] = nil }
            if let span = e.span {
                time(rule, -(before - (owned[rule]?.level ?? 0)), span, e.origin)
            } else {
                timed.removeAll { $0.rule == rule && $0.levels > 0 }
            }
        case .progressed:
            guard let id = e.process else { return }
            if var p = processes[id] {
                p.progress = e.progress ?? p.progress.addingSaturating(1)
                p.steps = e.steps ?? p.steps
                processes[id] = p
            } else if let origin = e.origin {
                let effect = EffectOrigin(rule: origin.rule, clause: origin.clause, index: e.index ?? .top(0))
                processes[id] = ProcessState(id: id, rule: origin.rule, origin: effect, progress: e.progress ?? 1,
                                             steps: e.steps ?? 1, startedRound: clock.round, instance: e.item)
            }
        case .completed, .brokenOff:
            guard let id = e.process else { return }
            processes[id] = nil
        case .itemChanged:
            guard let instance = e.item else { return }
            var item = items[instance] ?? ItemState()
            for (field, value) in e.change ?? [:] { item.set(field, value) }
            items[instance] = item
            if item.destroyed == true { leaveLoadout(instance) }
        case .clockAdvanced:
            clock.minutes = clock.minutes.addingSaturating(e.minutes ?? 0)
            clock.round = clock.round.addingSaturating(e.rounds ?? 0)
            end(Set(e.ends), book: book)
        case .stated:
            guard let name = e.fact else { return }
            if let value = e.value {
                state(Fact(name: name, value: value, owner: e.owner ?? Vocabulary.owner(ofFact: name) ?? .derived))
            } else {
                facts[name] = nil
                if let (instance, field) = Self.itemFact(name) { items[instance]?.clear(field) }
            }
        case .logged:
            break
        }
    }

    /// Ends `spans` (R56, `clockAdvanced`): the round's facts (`round.*`) when the round ends; the
    /// choices the book offers with one of `spans` (`choice.<id>` and its options
    /// `choice.<id>.*`; without a book no choice is known to end); and every Stufe gained or
    /// cleared for one of `spans` is undone. A choice offered `whileFormed` stays until it is
    /// cleared, a Stufe gained `untilCleared` until a `cleared` event.
    mutating func end(_ spans: Set<Span>, book: RuleBook?) {
        guard !spans.isEmpty else { return }
        if spans.contains(.round) {
            for name in facts.keys where name.hasPrefix("round.") { facts[name] = nil }
        }
        if let book {
            var choices: Set<String> = []
            for rule in book.rules.values {
                for clause in rule.clauses {
                    for e in clause.effects {
                        if case .offer(let o) = e.payload, let span = o.span, spans.contains(span) { choices.insert(o.choice) }
                    }
                }
            }
            let prefix = "choice."
            for name in facts.keys where name.hasPrefix(prefix) {
                let rest = name.dropFirst(prefix.count)
                if choices.contains(where: { rest == $0 || rest.hasPrefix($0 + ".") }) { facts[name] = nil }
            }
        }
        for t in timed where spans.contains(t.span) && t.levels != .min {
            changeLevel(of: t.rule, by: -t.levels, most: t.levels < 0 ? book?.rules[t.rule]?.most : nil)
        }
        timed.removeAll { spans.contains($0.span) }
    }

    /// A Stufe change for a span: the inverse of a recorded one (same rule and span) takes that
    /// one out; any other is recorded.
    private mutating func time(_ rule: String, _ levels: Int, _ span: Span, _ origin: ClauseRef?) {
        if let i = timed.firstIndex(where: { $0.rule == rule && $0.span == span && $0.levels == -levels }) {
            timed.remove(at: i)
        } else {
            timed.append(TimedChange(rule: rule, levels: levels, span: span, origin: origin))
        }
    }

    /// Every slot holding `instance` is stated empty, and its facts go.
    private mutating func leaveLoadout(_ instance: String) {
        let slots = facts.values.filter { $0.name.hasPrefix("loadout.") && $0.name.hasSuffix(".instance") && $0.value == .string(instance) }
            .map { String($0.name.dropFirst("loadout.".count).dropLast(".instance".count)) }
        for slot in slots {
            let name = "loadout.\(slot)"
            for key in facts.keys where key.hasPrefix(name + ".") { facts[key] = nil }
            facts[name] = Fact(name: name, value: .null, owner: .loadout)
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
