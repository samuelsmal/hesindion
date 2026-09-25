import Foundation

/// The action layer: `(Action, Situation) → [Event]` (spec §7). Pure: it computes events and
/// never applies them; `Situation.applying` does. Never throws: what cannot be computed is a
/// question or a §11 text.
public struct ActionLayer: Sendable {
    public let engine: Engine

    public init(engine: Engine) { self.engine = engine }
    public init(book: RuleBook) { self.init(engine: Engine(book: book)) }

    /// The action's costs and gains as events, in rule-id and clause order.
    ///
    /// Each rule effect is read as the pipeline reads one: its rule must apply, a firing
    /// `suppress` naming it (its clause, rule or rule kind) stops it and records it as
    /// `suppressed` (SA_74.VP1 over zaubermodifikationen.ZM12, the Schip over a condition's
    /// `gain`), and its `when` must be yes (no → `conditionFalse`, unknown → `unknownFact` and a
    /// question). Then:
    /// - `cost { pool, amount }` gives `paid(pool, amount)`. `onFailure` scales the amount (½,
    ///   rounded up) when `check.result` is `failure`. A `split` takes the player's share of each
    ///   other pool from `choice.split.<pool>`, the rest from `pool`, and checks each minimum. A
    ///   pool that cannot pay passes the rest down `fallThrough`; with none left it pays nothing
    ///   and says so (LE excepted: LeP may be paid into the negative). An untracked pool is paid
    ///   without a check. A cost with `every` is the clock's (Task 28).
    /// - `gain { rule, levels }` gives `gained(rule, levels)` within the rule's Stufen (a state:
    ///   one), a negative `levels` gives `cleared`.
    public func perform(_ action: Action, in situation: Situation) -> ActionResult {
        let stated = Self.stated(action, in: situation)
        let evaluation = engine.evaluation(stated)
        var run: ActionRun
        switch action {
        case .cast:
            let effects = evaluation.actionEffects()
            run = evaluation.actionRun(controlling: effects)
            evaluation.run(effects, &run)
        case .pay(let pool, let amount):
            run = evaluation.actionRun(controlling: [])
            evaluation.charge(Cost(pool: pool, amount: .number(Double(amount))), amount: amount, effect: nil,
                              facts: [], via: [], &run)
        case .state(let rule, let levels):
            run = evaluation.actionRun(controlling: [])
            evaluation.gain(rule, levels: levels, effect: nil, facts: [], via: [], &run)
        case .take(let choice):
            let offers = evaluation.allOffers().filter { $0.choice == choice }
            guard let offer = offers.first(where: \.legal) ?? offers.first else {
                run = evaluation.actionRun(controlling: [])
                run.pipeline.show(TextLine(kind: .notApplicable,
                                           text: "Regel konnte nicht angewandt werden: die Wahl \(choice) wird nicht angeboten"))
                break
            }
            run = evaluation.actionRun(controlling: offer.costs)
            guard offer.legal else {
                offer.reasons.forEach { run.pipeline.record($0) }
                break
            }
            evaluation.run(offer.costs, &run)
        }
        let breakdowns = run.read.uniqued().map { engine.evaluate(Query($0), in: stated) }
        return ActionResult(events: run.events, breakdowns: breakdowns, questions: run.pipeline.questions,
                            texts: run.pipeline.texts, notApplied: run.pipeline.notApplied)
    }

    /// The situation as the action states it: a cast states `check.kind: spell`, `check.spell`
    /// and `choice.spellModification.<id>: true`, each the player's.
    static func stated(_ action: Action, in situation: Situation) -> Situation {
        guard case .cast(let spell, let modifications) = action else { return situation }
        var s = situation
        let facts = [("check.kind", JSONValue.string("spell")), ("check.spell", .string(spell))]
            + modifications.map { ("choice.spellModification.\($0)", JSONValue.bool(true)) }
        for (name, value) in facts { s.facts[name] = Fact(name: name, value: value, owner: .player) }
        return s
    }
}

/// What one action builds up: the pipeline state its effects are read in (phase 4's control,
/// the records, questions and texts), the pools as the events so far leave them, the events and
/// the targets their amounts read.
struct ActionRun {
    var pipeline: PipelineState
    var pools: [Pool: PoolState]
    var events: [Event] = []
    var read: [TargetRef] = []
}

extension Evaluation {
    /// Every top-level `cost` and `gain` in the book, in rule-id and clause order: what a cast runs.
    func actionEffects() -> [Effect] {
        book.rules.keys.sorted(by: Self.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }.filter {
            switch $0.payload {
            case .cost, .gain: true
            default: false
            }
        }
    }

    /// A run over `effects`, with phase 4's control decided on them: the book's firing
    /// `suppress`es (and `replace`s) that name one of them, as the lines phase decides it for a
    /// query's lines (`control`). The run has no query: `query.*` is unknown.
    func actionRun(controlling effects: [Effect]) -> ActionRun {
        let controls = book.rules.keys.sorted(by: Self.idOrder)
            .flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }
            .filter { $0.phase == .lines }
        var pipeline = PipelineState(query: Query("action"), depth: 0, candidates: controls)
        pipeline.local = [:]
        control(effects, &pipeline)
        return ActionRun(pipeline: pipeline, pools: situation.pools)
    }

    /// Reads each effect as the pipeline does (applies, not suppressed, `when` yes) and runs it.
    func run(_ effects: [Effect], _ run: inout ActionRun) {
        for e in effects {
            if case .cost(let c) = e.payload, c.every != nil { continue }       // the clock's (Task 28)
            guard applies(e, &run.pipeline), !isSuppressed(e, &run.pipeline) else { continue }
            let rule = e.origin.rule
            let level = ruleLevel(rule, levels: [:], depth: 0)
            let via = ruleVia(rule, run.pipeline)
            guard let used = gate(e, level: level, via: via, &run.pipeline) else { continue }
            switch e.payload {
            case .cost(let c): cost(c, e, level: level, used: used, via: via, &run)
            case .gain(let g): gain(g, e, level: level, used: used, via: via, &run)
            default: continue
            }
        }
    }

    // MARK: - cost

    private func cost(_ c: Cost, _ e: Effect, level: Int?, used: [FactUse], via: [ClauseRef], _ run: inout ActionRun) {
        let rule = e.origin.rule
        run.read += c.amount.targets
        let r = value(c.amount, level: level, rule: rule, depth: 0)
        guard computed([r], of: e, used: used, via: via, &run.pipeline, [c.amount]), var amount = r.value else { return }
        var facts = (used + r.used).uniqued()
        let via = (via + r.via).uniqued()
        if let share = c.onFailure {
            let f = fact("check.result", level: level, rule: rule, depth: 0)
            guard let result = f.use else {
                unknown(e, f.unknown, facts: facts, via: via, &run)
                return
            }
            facts = (facts + [result]).uniqued()
            if result.value == .string("failure") {
                guard let scaled = Values.int(Values.round(Double(amount) * share, .up)) else {
                    fail(e, "\(amount) × \(share) liegt außerhalb des Zahlenbereichs", &run.pipeline)
                    return
                }
                amount = scaled
            }
        }
        guard amount >= 0 else {
            fail(e, "negative Kosten (\(amount))", &run.pipeline)
            return
        }
        guard let split = c.split else {
            charge(c, amount: amount, effect: e, facts: facts, via: via, &run)
            return
        }
        // The player's share of every other pool (`choice.split.<pool>`), the rest from `pool`.
        var shares: [Pool: Int] = [:]
        var missing: [UnknownFact] = []
        for p in split.pools where p != c.pool {
            let name = "choice.split.\(p.rawValue)"
            let f = fact(name, level: level, rule: rule, depth: 0)
            guard let use = f.use else {
                missing += f.unknown
                continue
            }
            guard let n = use.value.double.flatMap({ Values.int($0) }), Double(n) == use.value.double, n >= 0 else {
                fail(e, "\(name) ist keine Anzahl", &run.pipeline)
                return
            }
            facts = (facts + [use]).uniqued()
            shares[p] = n
        }
        guard missing.isEmpty else {
            unknown(e, missing.uniqued(), facts: facts, via: via, &run)
            return
        }
        shares[c.pool] = amount - shares.values.reduce(0, +)
        let order = (split.pools.contains(c.pool) ? split.pools : [c.pool] + split.pools)
        for p in order {
            let n = shares[p] ?? 0
            let least = max(split.min[p] ?? 0, 0)
            guard n >= least else {
                fail(e, "mindestens \(least) \(p.rawValue), gewählt \(n)", &run.pipeline)
                return
            }
        }
        for p in order {
            let n = shares[p] ?? 0
            if n > 0, p != .le, let state = run.pools[p], state.current < n {
                fail(e, "\(n) \(p.rawValue) gefordert, \(max(0, state.current)) vorhanden", &run.pipeline)
                return
            }
        }
        for p in order where (shares[p] ?? 0) > 0 {
            pay(p, shares[p]!, effect: e, facts: facts, via: via, &run)
        }
    }

    /// Pays `amount` from `c.pool`, then down `c.fallThrough` as each pool runs dry. The last pool
    /// pays the rest, or, short of it, nothing is paid at all (LE excepted). An untracked pool
    /// pays what is asked of it; one that is not the last cannot say how much it holds.
    func charge(_ c: Cost, amount: Int, effect e: Effect?, facts: [FactUse], via: [ClauseRef], _ run: inout ActionRun) {
        guard amount > 0 else { return }
        let chain = [c.pool] + c.fallThrough.filter { $0 != c.pool }
        var remaining = amount
        var plan: [(Pool, Int)] = []
        for (i, p) in chain.enumerated() {
            let last = i == chain.count - 1
            guard let state = run.pools[p] else {
                guard last else {
                    refuse(e, "der Stand von \(p.rawValue) ist nicht bekannt", &run)
                    return
                }
                plan.append((p, remaining))
                remaining = 0
                break
            }
            let available = max(0, state.current)
            if last {
                guard remaining <= available || p == .le else {
                    refuse(e, "\(remaining) \(p.rawValue) gefordert, \(available) vorhanden", &run)
                    return
                }
                plan.append((p, remaining))
                remaining = 0
            } else {
                let take = min(available, remaining)
                if take > 0 { plan.append((p, take)) }
                remaining -= take
            }
            if remaining == 0 { break }
        }
        for (p, n) in plan { pay(p, n, effect: e, facts: facts, via: via, &run) }
    }

    private func pay(_ pool: Pool, _ amount: Int, effect e: Effect?, facts: [FactUse], via: [ClauseRef],
                     _ run: inout ActionRun) {
        run.events.append(Event(kind: .paid, origin: e?.origin.clauseRef, pool: pool, amount: amount, via: via,
                                rulings: e.map(decided) ?? [], facts: facts))
        run.pools[pool]?.current -= amount
    }

    /// A payment that cannot be made: a §11 text naming the clause, or for the player's own
    /// payment "Kosten konnten nicht bezahlt werden".
    private func refuse(_ e: Effect?, _ reason: String, _ run: inout ActionRun) {
        if let e {
            fail(e, reason, &run.pipeline)
        } else {
            run.pipeline.show(TextLine(kind: .notApplicable, text: "Kosten konnten nicht bezahlt werden: \(reason)"))
        }
    }

    private func unknown(_ e: Effect, _ facts: [UnknownFact], facts used: [FactUse], via: [ClauseRef],
                         _ run: inout ActionRun) {
        run.pipeline.record(NotApplied(origin: e.origin.clauseRef, reason: .unknownFact, because: e.because,
                                       rulings: e.ruling, facts: used, via: via))
        run.pipeline.ask(facts, for: e.origin.clauseRef)
    }

    // MARK: - gain

    private func gain(_ g: Gain, _ e: Effect, level: Int?, used: [FactUse], via: [ClauseRef], _ run: inout ActionRun) {
        let rule = e.origin.rule
        switch g.rule {
        case .id(let id):
            gain(id, levels: g.levels ?? 1, effect: e, facts: used, via: via, &run)
        case .table(let name, let key):
            let (s, behind) = prepared([key], depth: 0)
            let t = Tables.lookup(name, key: key, level: level, in: s, book: book, rule: rule, depth: 0) { [unowned self] target, d in
                self.resolve(target, depth: d)
            }
            let facts = (used + t.used).uniqued()
            guard let entry = t.value else {
                let lacking = t.unknown.flatMap { behind[$0.name] ?? [$0] }.uniqued()
                if lacking.isEmpty {
                    fail(e, "die Tabelle \(name) hat keinen Eintrag für \(key)", &run.pipeline)
                } else {
                    unknown(e, lacking, facts: facts, via: (via + t.via).uniqued(), &run)
                }
                return
            }
            guard let id = entry.string else {
                fail(e, "die Tabelle \(name) nennt keine Regel", &run.pipeline)
                return
            }
            gain(id, levels: g.levels ?? 1, effect: e, facts: facts, via: (via + t.via).uniqued(), &run)
        }
    }

    /// `gained` within the rule's Stufen (`levels`; a state has one, a rule with neither has no
    /// bound), with a note when fewer are gained than asked; `cleared` for a negative count.
    func gain(_ id: String, levels: Int, effect e: Effect?, facts: [FactUse], via: [ClauseRef], _ run: inout ActionRun) {
        guard let target = book.rules[id] else {
            let reason = "die Regel \(id) gibt es nicht"
            if let e { fail(e, reason, &run.pipeline) } else {
                run.pipeline.show(TextLine(kind: .notApplicable, text: "Regel konnte nicht angewandt werden: \(reason)"))
            }
            return
        }
        let origin = e?.origin.clauseRef, rulings = e.map(decided) ?? []
        if levels < 0 {
            run.events.append(Event(kind: .cleared, origin: origin, rule: id, levels: -levels, via: via, rulings: rulings,
                                    facts: facts))
            return
        }
        guard levels > 0 else { return }
        var granted = levels, note: String?
        if let most = target.levels ?? (target.kind == .state ? 1 : nil) {
            let have = situation.owned[id]?.level ?? 0
            granted = max(0, min(levels, most - have))
            if granted < levels { note = "höchstens Stufe \(most)" }
        }
        run.events.append(Event(kind: .gained, origin: origin, rule: id, levels: granted, via: via, rulings: rulings,
                                facts: facts, note: note))
    }
}

extension ValueExpr {
    /// The targets the value reads, in reading order.
    var targets: [TargetRef] {
        switch self {
        case .number, .level: []
        case .table(_, let key): Vocabulary.targets.contains(TargetRef(key).name) ? [TargetRef(key)] : []
        case .proportion(let p):
            [p.of, p.per, p.above].flatMap(\.targets) + (p.min?.targets ?? []) + (p.max?.targets ?? [])
        }
    }
}

extension Operand {
    var targets: [TargetRef] {
        switch self {
        case .number, .fact: []
        case .target(let t): [t]
        case .sum(let os): os.flatMap(\.targets)
        }
    }
}

extension Bound {
    var targets: [TargetRef] {
        switch self {
        case .number: []
        case .operand(let o): o.targets
        case .each(let os): os.flatMap(\.targets)
        }
    }
}
