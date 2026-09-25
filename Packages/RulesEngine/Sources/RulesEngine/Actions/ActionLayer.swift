import Foundation

/// The action layer: `(Action, Situation) → [Event]` (spec §7). Pure: it computes events and
/// the situation they leave (`ActionResult.situation`, `applying(_:book:)`), never changing the
/// one it was given. Never throws: what cannot be computed is a question or a §11 text.
public struct ActionLayer: Sendable {
    public let engine: Engine

    public init(engine: Engine) { self.engine = engine }
    public init(book: RuleBook) { self.init(engine: Engine(book: book)) }

    /// The action's events, in rule-id and clause order within each part.
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
    ///   without a check. A cost with `every` is the clock's (`.advanceClock`, `.endRound`).
    /// - `gain { rule, levels, span }` gives `gained(rule, levels)` within the rule's Stufen (a
    ///   state: one), a negative `levels` gives `cleared`; a `span` rides on the event.
    /// - `item { instance, change }` gives `itemChanged` on the instance in the slot (or the
    ///   instance a process is bound to).
    ///
    /// Which effects an action runs: the top-level `cost`, `gain` and `item` effects whose `when`
    /// or amount reads a fact the action states (a cast's `check.kind`, a roll's `action.attack`,
    /// a hit's `hit.*`), and in turn those that read an item field an `itemChanged` of this action
    /// changed (SA_59.SS3: the StP fall, then "at 0 destroyed"). Only `.settle` runs the standing
    /// gains. After every action, a running process whose `breaksOff` turned yes gives
    /// `brokenOff`.
    public func perform(_ action: Action, in situation: Situation) -> ActionResult {
        var out: ActionResult
        var start = situation                       // where `breaksOff` is read before the action
        switch action {
        case .check(let request):
            out = CheckProcedure.perform(request, in: situation, engine: engine)
        case .attack(let with):
            let begun = CombatRoll.start(.attack(with: with), in: situation, engine: engine)
            start = begun.situation
            out = CombatRoll.perform(.attack(with: with), in: situation, engine: engine)
            out = following(out, stated: changedFacts(from: start, to: out.situation))
        case .defend(let kind, let with):
            let begun = CombatRoll.start(.defend(kind: kind, with: with), in: situation, engine: engine)
            start = begun.situation
            out = CombatRoll.perform(.defend(kind: kind, with: with), in: situation, engine: engine)
            out = following(out, stated: changedFacts(from: start, to: out.situation))
        case .takeHit(let tp, let zone, let side, let failedDefence):
            var hit = situation
            if failedDefence { hit.facts["check.result"] = Fact(name: "check.result", value: .string("failure"), owner: .roll) }
            let r = DamageChain.run(hit: tp, zone: zone, side: side, in: hit, engine: engine)
            out = ActionResult(events: r.events, situation: r.situation.applying(r.events, book: engine.book),
                               breakdowns: r.breakdowns, questions: r.questions, texts: r.texts,
                               notApplied: r.notApplied, checks: r.checks)
            out = following(out, stated: Set(r.situation.facts.keys.filter { $0.hasPrefix("hit.") }))
        default:
            out = local(action, in: situation)
        }
        return oneQuery(breakingOff(lasting(out, from: situation), from: start), from: situation)
    }

    /// R58: the action's one-query inputs (`Situation.isOneQueryInput`: a cast's `check.spell`, a
    /// roll's die, a hit's `hit.*`) do not outlive it. Each is given back the value it had where
    /// the action began (or none), so `situation.applying(events, book:)` is the action's
    /// situation, whole. A rule that reads across actions gets the earlier result as a `stated`
    /// fact (`action.attack`, `round.previousDefenceCrit`) or as an input of the later action
    /// (`.takeHit(failedDefence:)`).
    private func oneQuery(_ result: ActionResult, from situation: Situation) -> ActionResult {
        var out = result
        let names = Set(out.situation.facts.keys).union(situation.facts.keys).filter(Situation.isOneQueryInput)
        for name in names { out.situation.facts[name] = situation.facts[name] }
        let bases = Set(out.situation.base.keys).union(situation.base.keys).filter(Situation.isOneQueryBase)
        for key in bases { out.situation.base[key] = situation.base[key] }
        out.situation.unstated = situation.unstated
        out.situation.inForce = situation.inForce
        return out
    }

    /// R56: every lasting fact the action set (or took away) in its situation is a `stated` event,
    /// so that `situation.applying(events, book:)` gives the action's situation, but for its
    /// one-query inputs (`Situation.isOneQueryInput`).
    private func lasting(_ result: ActionResult, from situation: Situation) -> ActionResult {
        let applied = situation.applying(result.events, book: engine.book)
        let names = Set(applied.facts.keys).union(result.situation.facts.keys).filter { !Situation.isOneQueryInput($0) }
        let events = names.sorted().compactMap { name -> Event? in
            let now = result.situation.facts[name]
            guard applied.facts[name] != now else { return nil }
            return Event(kind: .stated, fact: name, value: now?.value, owner: now?.owner ?? applied.facts[name]?.owner)
        }
        guard !events.isEmpty else { return result }
        var out = result
        out.events += events
        return out
    }

    /// The actions the layer itself runs (no procedure).
    private func local(_ action: Action, in situation: Situation) -> ActionResult {
        let stated = Self.stated(action, in: situation, book: engine.book)
        let evaluation = engine.evaluation(stated)
        var run: ActionRun
        var checks: [PendingCheck] = []
        var attacks: [PendingAttack] = []
        switch action {
        case .cast(_, let modifications):                           // the spell is stated by `stated`
            run = evaluation.actionRun(controlling: evaluation.actionEffects())
            consequences(reading: Set(["check.kind", "check.spell"] + modifications.map { "choice.spellModification.\($0)" }),
                         &run)
            evaluation.startRecurring(&run)
        case .pay(let pool, let amount):
            run = evaluation.actionRun(controlling: [])
            guard amount > 0 else {
                run.pipeline.show(TextLine(kind: .notApplicable,
                                           text: "Kosten konnten nicht bezahlt werden: der Betrag \(amount) ist nicht positiv"))
                break
            }
            evaluation.charge(Cost(pool: pool, amount: .number(Double(amount))), amount: amount, effect: nil,
                              facts: [], via: [], &run)
        case .state(let rule, let levels):
            run = evaluation.actionRun(controlling: [])
            evaluation.gain(rule, levels: levels, span: nil, effect: nil, facts: [], via: [], &run)
        case .check, .attack, .defend, .takeHit:
            run = evaluation.actionRun(controlling: [])                // handled by `perform`
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
            let (texts, entries) = (run.pipeline.texts.count, run.pipeline.notApplied.count)
            evaluation.run(offer.costs, &run)
            // An action that could not be paid is not taken: no process advances.
            let costs = Set(offer.costs.map(\.origin.clauseRef))
            let unpaid = run.pipeline.texts.dropFirst(texts).contains { $0.kind == .notApplicable && $0.origin.map(costs.contains) ?? true }
                || run.pipeline.notApplied.dropFirst(entries).contains { $0.reason == .unknownFact && costs.contains($0.origin) }
            let advances = evaluation.processEffects().contains {
                if case .process(let p) = $0.payload { p.advancedBy.kind == .action && p.advancedBy.ids.contains { $0.id == choice } } else { false }
            }
            if unpaid {
                if advances {
                    run.pipeline.show(TextLine(kind: .notApplicable, text: "Nichts geändert: \(choice) ist nicht bezahlt, kein Vorgang geht weiter"))
                }
            } else {
                advance(.action(choice), &run)
                // Ruling R64: what taking the choice restores (regeneration.R4's LeP), read with the
                // choice taken. Task 31: so every `cost`, `gain`, `item` and `restore` that reads the
                // choice (reiterkampf.RK6's jump off the horse, RK12's Aktion for an order) runs, and
                // each talent `check` that reads it is asked (RK12's Reiten). A choice the situation
                // states keeps its value (the order given); else it is taken as `true`.
                var chosen = situation
                if chosen.facts["choice.\(choice)"] == nil {
                    chosen.facts["choice.\(choice)"] = Fact(name: "choice.\(choice)", value: .bool(true), owner: .player)
                }
                let taken = engine.evaluation(chosen)
                let paidFor = Set(offer.costs.map(\.origin))
                let gated = taken.actionEffects().filter { $0.reads.contains("choice.\(choice)") && !paidFor.contains($0.origin) }
                taken.control(gated, &run.pipeline)
                taken.run(gated, &run)
                checks = DamageChain.checksCalledFor(in: chosen, engine: engine, &run.pipeline) {
                    $0.when?.factNames.contains("choice.\(choice)") ?? false
                }
                // Ruling R72: and the attack checks it gates (a mount's attack on an order).
                attacks = taken.attacksCalledFor(&run.pipeline) { $0.when?.factNames.contains("choice.\(choice)") ?? false }
            }
        case .advance(let process):
            run = evaluation.actionRun(controlling: [])
            advance(.process(process), &run)
        case .advanceClock(let minutes):
            run = evaluation.actionRun(controlling: evaluation.recurringCosts())
            guard minutes > 0, !situation.clock.minutes.addingReportingOverflow(minutes).overflow else {
                run.pipeline.show(TextLine(kind: .notApplicable, text: "Nichts geändert: die Uhr geht um \(minutes) Minuten nicht vor"))
                break
            }
            run.events.append(Event(kind: .clockAdvanced, minutes: minutes, ends: Span.allCases.filter(Span.round.ending.contains)))
            evaluation.recurring(.minutes, from: situation.clock.minutes, to: situation.clock.minutes + minutes, &run)
        case .endRound, .endFight:
            run = evaluation.actionRun(controlling: evaluation.recurringCosts())
            let span: Span = action == .endRound ? .round : .fight
            run.events.append(Event(kind: .clockAdvanced, rounds: 1, ends: Span.allCases.filter(span.ending.contains)))
            evaluation.recurring(.rounds, from: situation.clock.round, to: situation.clock.round.addingSaturating(1), &run)
        case .settle:
            let gains = evaluation.actionEffects().filter { if case .gain = $0.payload { true } else { false } }
            run = evaluation.actionRun(controlling: gains)
            evaluation.run(gains, &run)
        }
        let breakdowns = run.read.uniqued().map { engine.evaluate(Query($0), in: stated) }
        return ActionResult(events: run.events, situation: stated.applying(run.events, book: engine.book),
                            breakdowns: breakdowns, questions: run.pipeline.questions,
                            texts: run.pipeline.texts, notApplied: run.pipeline.notApplied, checks: checks, attacks: attacks)
    }

    /// The situation as the action states it for its own evaluation, before its events: a cast
    /// states `check.kind: spell`, `check.spell` and `choice.spellModification.<id>: true`, each
    /// the player's (one-query inputs, `Situation.isOneQueryInput`). Everything lasting is an event
    /// (R56): the clock and the spans it ends are `clockAdvanced`.
    static func stated(_ action: Action, in situation: Situation, book: RuleBook? = nil) -> Situation {
        var s = situation
        switch action {
        case .cast(let spell, let modifications):
            let facts = [("check.kind", JSONValue.string("spell")), ("check.spell", .string(spell))]
                + modifications.map { ("choice.spellModification.\($0)", JSONValue.bool(true)) }
            for (name, value) in facts { s.facts[name] = Fact(name: name, value: value, owner: .player) }
        default:
            break
        }
        return s
    }

    /// The facts that changed from `a` to `b`: stated anew, or with another value.
    private func changedFacts(from a: Situation, to b: Situation) -> Set<String> {
        Set(b.facts.values.filter { a.facts[$0.name] != $0 }.map(\.name))
    }

    /// A procedure's result with the consequences that read what it stated run after it, in the
    /// situation it left.
    private func following(_ result: ActionResult, stated: Set<String>) -> ActionResult {
        guard !stated.isEmpty else { return result }
        let before = result.situation
        let evaluation = engine.evaluation(before)
        var run = evaluation.actionRun(controlling: evaluation.actionEffects())
        consequences(reading: stated, &run)
        guard !run.events.isEmpty || !run.pipeline.notApplied.isEmpty || !run.pipeline.texts.isEmpty
                || !run.pipeline.questions.isEmpty else { return result }
        var out = result
        out.events += run.events
        out.situation = before.applying(run.events, book: engine.book)
        out.questions = CheckProcedure.mergeQuestions(out.questions + run.pipeline.questions)
        out.texts = (out.texts + run.pipeline.texts).uniqued()
        out.notApplied = (out.notApplied + run.pipeline.notApplied).uniqued()
        return out
    }

    /// Runs the top-level `cost`, `gain` and `item` effects that read a fact of `stated`, then
    /// those that read an item field their `itemChanged` events changed, until nothing more
    /// changes. Each round reads the situation the events so far leave.
    func consequences(reading stated: Set<String>, _ run: inout ActionRun) {
        var done = Set<EffectOrigin>()
        var reading = stated
        while !reading.isEmpty {
            let now = run.base.applying(run.events, book: engine.book)
            let evaluation = engine.evaluation(now)
            let next = evaluation.actionEffects().filter { !done.contains($0.origin) && !$0.reads.isDisjoint(with: reading) }
            guard !next.isEmpty else { return }
            next.forEach { done.insert($0.origin) }
            let before = run.changed
            evaluation.run(next, &run)
            reading = run.changed.subtracting(before)
        }
    }

    // MARK: - Processes

    enum Advance {
        /// The action a process's `advancedBy` names (`laden`, `zielen`).
        case action(String)
        /// The process by its id.
        case process(String)
    }

    /// One step of every process `by` names (spec §7): a running one progresses (at its `steps`
    /// it completes, running its `completes`; a process with nothing to complete stays at its
    /// cap and a further step changes nothing); otherwise the first `process` effect of that id,
    /// in rule-id and clause order, whose rule applies, that is not suppressed and whose `when`
    /// holds starts one: `steps` read now, bound to the instance in the slot its `completes`
    /// names. An effect resting on an open ruling starts nothing and shows its text.
    func advance(_ by: Advance, _ run: inout ActionRun) {
        let now = run.base.applying(run.events, book: engine.book)
        let evaluation = engine.evaluation(now)
        func named(_ p: ProcessPayload) -> Bool {
            switch by {
            case .action(let a): p.advancedBy.kind == .action && p.advancedBy.ids.contains { $0.id == a }
            case .process(let id): p.id == id
            }
        }
        var stepped: Set<String> = []
        for (id, process) in now.processes.sorted(by: { $0.key < $1.key }) {
            guard let e = engine.book.effect(at: process.origin), case .process(let p) = e.payload, named(p) else { continue }
            stepped.insert(id)
            evaluation.step(process, p, e, &run)
        }
        for e in evaluation.processEffects() {
            guard case .process(let p) = e.payload, named(p), !stepped.contains(p.id) else { continue }
            if evaluation.start(p, e, &run) { stepped.insert(p.id) }
        }
        if stepped.isEmpty, case .process(let id) = by {
            run.pipeline.show(TextLine(kind: .notApplicable, text: "Nichts geändert: kein Vorgang \(id) läuft oder beginnt"))
        }
    }

    /// `brokenOff` for every process still running after the action whose `breaksOff` is yes there
    /// and was not yes where the action began (`start`).
    private func breakingOff(_ result: ActionResult, from start: Situation) -> ActionResult {
        var out = result
        let after = engine.evaluation(result.situation)
        let before = engine.evaluation(start)
        var events: [Event] = []
        for (id, process) in result.situation.processes.sorted(by: { $0.key < $1.key }) {
            guard let e = engine.book.effect(at: process.origin), case .process(let p) = e.payload,
                  let breaks = p.breaksOff else { continue }
            let now = after.condition(breaks, level: nil, rule: process.rule, depth: 0)
            guard now.truth == .yes,
                  before.condition(breaks, level: nil, rule: process.rule, depth: 0).truth != .yes else { continue }
            events.append(Event(kind: .brokenOff, origin: e.origin.clauseRef, process: id, item: process.instance,
                                rulings: after.decided(e), facts: now.used))
        }
        guard !events.isEmpty else { return out }
        out.events += events
        out.situation = result.situation.applying(events, book: engine.book)
        return out
    }
}


/// What one action builds up: the situation it starts from (`base`: what the action stated),
/// the pipeline state its effects are read in (phase 4's control, the records, questions and
/// texts), the pools as the events so far leave them, the events, the targets their amounts read,
/// the facts its item changes changed, and the instance a running process binds its `completes` to.
struct ActionRun {
    var base: Situation
    var pipeline: PipelineState
    var pools: [Pool: PoolState]
    /// Rule id → the Stufe the hero has as the events so far leave it (a gain's bound).
    var owned: [String: Int]
    var events: [Event] = []
    var read: [TargetRef] = []
    /// The facts the run's `itemChanged` events changed (`item.<instance>.<field>` and
    /// `loadout.<slot>.<field>`): the effects that read them run next (`consequences`).
    var changed: Set<String> = []
    /// While a process's `completes` run: the instance it is bound to, which `{ loadout: … }` names.
    var bound: String?
}

extension Effect {
    /// Every fact the effect reads: its `when`, and its payload's values (a cost's amount, a
    /// gain's table key, an item change's `of`).
    var reads: Set<String> {
        var out = when?.factNames ?? []
        switch payload {
        case .cost(let c):
            out.formUnion(c.amount.factNames)
            if case .fact(let f) = c.every?.count { out.insert(f) }
        case .gain(let g):
            if case .table(_, let key) = g.rule { out.insert(key) }
        case .restore(let r):
            out.formUnion(r.amount.factNames)
        case .item(let i):
            if case .scaled(let of, _) = i.change.structurePoints { out.insert(of) }
        default: break
        }
        return out
    }
}

extension Evaluation {
    /// Every top-level `cost` (but a recurring one), `gain` and `item` in the book, in rule-id and
    /// clause order: what an action may run.
    func actionEffects() -> [Effect] {
        book.rules.keys.sorted(by: Self.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }.filter {
            switch $0.payload {
            case .cost(let c): c.every == nil
            case .gain, .item, .restore: true
            default: false
            }
        }
    }

    /// Every top-level `cost { every }` in the book, in rule-id and clause order: the clock's.
    func recurringCosts() -> [Effect] {
        book.rules.keys.sorted(by: Self.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }.filter {
            if case .cost(let c) = $0.payload { c.every != nil } else { false }
        }
    }

    /// Every top-level `process` in the book, in rule-id and clause order.
    func processEffects() -> [Effect] {
        book.rules.keys.sorted(by: Self.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }.filter {
            if case .process = $0.payload { true } else { false }
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
        return ActionRun(base: situation, pipeline: pipeline, pools: situation.pools, owned: situation.owned.mapValues(\.level))
    }

    /// Reads each effect as the pipeline does (applies, not suppressed, `when` yes) and runs it.
    /// A recurring cost is the clock's (`recurring`).
    func run(_ effects: [Effect], _ run: inout ActionRun) {
        for e in effects {
            if case .cost(let c) = e.payload, c.every != nil { continue }
            guard let (level, used, via) = admitted(e, &run) else { continue }
            switch e.payload {
            case .cost(let c): cost(c, e, level: level, used: used, via: via, &run)
            case .gain(let g): gain(g, e, level: level, used: used, via: via, &run)
            case .restore(let r): restore(r, e, level: level, used: used, via: via, &run)
            case .item(let i): item(i, e, level: level, used: used, via: via, &run)
            default: continue
            }
        }
    }

    /// Whether `e` acts, read as the pipeline reads it: its rule applies, it is not suppressed,
    /// and its `when` is yes. Its level, the facts its `when` read and its `via` when it does.
    ///
    /// Task 30: the level is the one the rule acts at, the result of `level(rule: X)` after its
    /// useLevels (Belastungsgewöhnung lowers Belastung IV to III, so no Handlungsunfähig), and
    /// those useLevels join `via` (ADV_49.ZH3 keeping Schmerz IV).
    private func admitted(_ e: Effect, _ run: inout ActionRun) -> (level: Int?, used: [FactUse], via: [ClauseRef])? {
        guard applies(e, &run.pipeline), !isSuppressed(e, &run.pipeline) else { return nil }
        let rule = e.origin.rule
        let acting = actingLevel(of: rule)
        let level = acting?.value ?? ruleLevel(rule, levels: [:], depth: 0)
        let via = (ruleVia(rule, run.pipeline) + (acting?.via ?? [])).uniqued()
        guard let used = gate(e, level: level, via: via, &run.pipeline) else { return nil }
        return (level, used, via)
    }

    /// The level a levelled rule acts at outside a query (an action's effects): the result of
    /// `level(rule: id)` through its useLevels, and the useLevels that changed or kept it. nil for
    /// a rule without a level, or one whose level is not known.
    func actingLevel(of id: String) -> (value: Int, via: [ClauseRef])? {
        let stated = situation.base[Self.levelQuery(id).description] != nil
        guard situation.owned[id] != nil || stated || !levelDerives(of: id).isEmpty else { return nil }
        let b = breakdown(Self.levelQuery(id), depth: 1, through: .level)
        guard let value = b.result else { return nil }
        return (value, b.lines.filter { $0.kind == .levelAs }.compactMap(\.origin).uniqued())
    }

    // MARK: - The clock's costs

    /// Every `cost { every }` that falls due while the clock goes from `from` to `to` (in the
    /// cost's unit): one payment per multiple of its interval passed (2 AsP every 5 minutes, 0 →
    /// 12: two payments of 2). The interval is a number or a fact (`spell.interval`). A cost in the
    /// other unit does not fall due.
    func recurring(_ unit: GameDuration.Unit, from: Int, to: Int, _ run: inout ActionRun) {
        for e in recurringCosts() {
            guard case .cost(let c) = e.payload, let every = c.every, every.unit == unit,
                  let (level, used, via) = admitted(e, &run) else { continue }
            let rule = e.origin.rule
            var facts = used
            let interval: Int
            switch every.count {
            case .number(let n): interval = n
            case .fact(let name):
                let f = fact(name, level: level, rule: rule, depth: 0)
                guard let use = f.use else {
                    unknown(e, f.unknown, facts: facts, via: via, &run)
                    continue
                }
                guard let n = use.value.int else {
                    fail(e, "\(name) ist keine Anzahl (\(use.value))", &run.pipeline)
                    continue
                }
                facts = (facts + [use]).uniqued()
                interval = n
            }
            guard interval > 0 else {
                fail(e, "das Intervall \(interval) ist nicht positiv", &run.pipeline)
                continue
            }
            // R57: counted from the cost's start; a cost nobody started starts where the clock stands.
            let name = Self.upkeepFact(e)
            let since: Int
            if let start = situation.facts[name]?.value.int {
                since = start
            } else {
                since = from
                run.events.append(Event(kind: .stated, origin: e.origin.clauseRef, fact: name, value: .int(from), owner: .derived))
            }
            let due = Clock.due(every: interval, since: since, from: from, to: to)
            guard due > 0 else { continue }
            for _ in 0..<due { cost(c, e, level: level, used: facts, via: via, &run) }
        }
    }

    /// The fact a recurring cost's start is kept in (R57): `upkeep.<rule>.<clause>`, in the cost's
    /// unit (a minute or a round of the clock).
    static func upkeepFact(_ e: Effect) -> String { "upkeep.\(e.origin.rule).\(e.origin.clause)" }

    /// R57: the recurring costs this action starts: every `cost { every }` that acts now (its rule
    /// applies, it is not suppressed, its `when` is yes) and has no start yet gets one, the clock's
    /// minute (or round) as a `stated` event. The cast of a maintained spell starts its upkeep. A
    /// cost that does not act now is read quietly: it records and asks nothing.
    func startRecurring(_ run: inout ActionRun) {
        for e in recurringCosts() {
            guard case .cost(let c) = e.payload, let every = c.every else { continue }
            let name = Self.upkeepFact(e)
            // Read quietly: a cost that does not start now asks nothing of the action.
            var quiet = run
            guard situation.facts[name] == nil, admitted(e, &quiet) != nil else { continue }
            let now = every.unit == .minutes ? situation.clock.minutes : situation.clock.round
            run.events.append(Event(kind: .stated, origin: e.origin.clauseRef, fact: name, value: .int(now), owner: .derived))
        }
    }

    // MARK: - Processes

    /// One step of a running process: its progress + 1 (`progressed`); at its `steps`, a process
    /// with `completes` completes (`completed`, then its `completes` on the bound instance). A
    /// process at its cap with nothing to complete changes nothing (a text says so).
    func step(_ process: ProcessState, _ p: ProcessPayload, _ e: Effect, _ run: inout ActionRun) {
        guard process.progress < process.steps else {
            run.pipeline.show(TextLine(kind: .notApplicable,
                                       text: "Nichts geändert: \(process.id) hat alle \(process.steps) Schritte", origin: e.origin.clauseRef))
            return
        }
        progress(process.id, to: process.progress + 1, of: process.steps, p, e, instance: process.instance, used: [],
                 via: [], &run)
    }

    /// Starts the process of `e` when its rule applies, it is not suppressed and its `when` holds:
    /// its `steps` read now (at least 1), bound to the instance in the slot its `completes` name.
    /// Whether it started.
    func start(_ p: ProcessPayload, _ e: Effect, _ run: inout ActionRun) -> Bool {
        guard let (level, used, via) = admitted(e, &run) else { return false }
        let rule = e.origin.rule
        run.read += p.steps.targets
        let r = value(p.steps, level: level, rule: rule, depth: 0)
        guard computed([r], of: e, used: used, via: via, &run.pipeline, [p.steps]), let steps = r.value else { return false }
        guard steps >= 1 else {
            fail(e, "\(p.id) hat \(steps) Schritte", &run.pipeline)
            return false
        }
        let slot = p.completes.lazy.compactMap { c -> String? in
            guard case .item(let i) = c.payload, i.instance.kind == .loadout else { return nil }
            return i.instance.ids.first?.id
        }.first
        let instance = slot.flatMap { situation.instance(in: $0) }
        progress(p.id, to: 1, of: steps, p, e, instance: instance, used: (used + r.used).uniqued(), via: (via + r.via).uniqued(), &run)
        return true
    }

    private func progress(_ id: String, to progress: Int, of steps: Int, _ p: ProcessPayload, _ e: Effect, instance: String?,
                          used: [FactUse], via: [ClauseRef], _ run: inout ActionRun) {
        run.events.append(Event(kind: .progressed, origin: e.origin.clauseRef, process: id, item: instance, progress: progress,
                                steps: steps, index: e.origin.index, via: via, rulings: decided(e), facts: used))
        guard progress >= steps, !p.completes.isEmpty else { return }
        run.events.append(Event(kind: .completed, origin: e.origin.clauseRef, process: id, item: instance, via: via,
                                rulings: decided(e)))
        let outer = run.bound
        run.bound = instance
        self.run(p.completes, &run)
        run.bound = outer
    }

    // MARK: - item

    /// `itemChanged` on the instance the effect names (`{ loadout: weapon }`: the instance in that
    /// slot, or the one a process is bound to while its `completes` run). A flag is set to its
    /// value. `structurePoints` is a change (`{ of: hit.tp, times: -1 }`: lower by the TP, rounded
    /// up in magnitude; a number: that many more), counted from the instance's current StP (its
    /// state, else the slot's stated `loadout.<slot>.structurePoints`); the event carries the value
    /// after (`change`) and the change (`amount`). An unknown instance, amount or current StP is
    /// asked.
    private func item(_ i: ItemChange, _ e: Effect, level: Int?, used: [FactUse], via: [ClauseRef], _ run: inout ActionRun) {
        let rule = e.origin.rule
        guard i.instance.kind == .loadout, let slot = i.instance.ids.first?.id, i.instance.ids.count == 1 else {
            fail(e, "\(i.instance.kind.rawValue) nennt keinen Platz der Ausrüstung", &run.pipeline)
            return
        }
        let now = run.base.applying(run.events)
        let instanceFact = "loadout.\(slot).instance"
        guard let instance = run.bound ?? now.instance(in: slot) else {
            unknown(e, [UnknownFact(instanceFact)], facts: used, via: via, &run)
            return
        }
        var facts = used
        if run.bound == nil, let f = now.facts[instanceFact] { facts.append(FactUse(name: f.name, value: f.value, owner: f.owner)) }
        let d = i.change
        var change: [String: JSONValue] = [:]
        for (field, flag) in [("loaded", d.loaded), ("strung", d.strung), ("damaged", d.damaged), ("destroyed", d.destroyed),
                              ("ridden", d.ridden), ("held", d.held)] {
            if let flag { change[field] = .bool(flag) }
        }
        var amount: Int?
        if let sp = d.structurePoints {
            let delta: Int
            switch sp {
            case .number(let n):
                guard let k = Values.int(n), Double(k) == n else {
                    fail(e, "\(n) Strukturpunkte sind keine Anzahl", &run.pipeline)
                    return
                }
                delta = k
            case .scaled(let of, let times):
                let f = fact(of, level: level, rule: rule, depth: 0)
                guard let use = f.use else {
                    unknown(e, f.unknown, facts: facts, via: via, &run)
                    return
                }
                guard let x = use.value.double, let k = Values.int(Values.round(x * times, .up)) else {
                    fail(e, "\(of) × \(times) ist keine Anzahl", &run.pipeline)
                    return
                }
                facts.append(use)
                delta = k
            }
            let currentName = "loadout.\(slot).structurePoints"
            guard let current = now.items[instance]?.structurePoints
                    ?? (run.bound == nil ? now.fact(currentName)?.value.int : now.fact("item.\(instance).structurePoints")?.value.int) else {
                unknown(e, [UnknownFact(run.bound == nil ? currentName : "item.\(instance).structurePoints")], facts: facts, via: via, &run)
                return
            }
            let (after, overflow) = current.addingReportingOverflow(delta)
            guard !overflow else {
                fail(e, "\(current) + \(delta) Strukturpunkte liegen außerhalb des Zahlenbereichs", &run.pipeline)
                return
            }
            change["structurePoints"] = .int(after)
            amount = delta
        }
        guard !change.isEmpty else {
            fail(e, "die Änderung nennt kein Feld", &run.pipeline)
            return
        }
        run.events.append(Event(kind: .itemChanged, origin: e.origin.clauseRef, amount: amount, item: instance, change: change,
                                via: via, rulings: decided(e), facts: facts.uniqued()))
        let slots = now.facts.values.filter { $0.name.hasPrefix("loadout.") && $0.name.hasSuffix(".instance") && $0.value == .string(instance) }
            .map { String($0.name.dropFirst("loadout.".count).dropLast(".instance".count)) }
        for field in change.keys {
            run.changed.insert("item.\(instance).\(field)")
            for s in slots { run.changed.insert("loadout.\(s).\(field)") }
        }
    }

    // MARK: - cost

    /// Ruling R64: `restore` raises its pool by its amount, held by the caps of the pool's target
    /// (`leCurrent`: regeneration.R5 at `leMax`), which join the `restored` event's `via`. An
    /// untracked pool, or one no target reads, gains nothing and says so.
    func restore(_ r: Restore, _ e: Effect, level: Int?, used: [FactUse], via: [ClauseRef], _ run: inout ActionRun) {
        run.read += r.amount.targets
        let v = value(r.amount, level: level, rule: e.origin.rule, depth: 0)
        guard computed([v], of: e, used: used, via: via, &run.pipeline, [r.amount]), let amount = v.value else { return }
        guard amount >= 0 else {
            fail(e, "negative Erholung (\(amount))", &run.pipeline)
            return
        }
        guard let state = run.pools[r.pool], let target = r.pool.currentTarget else {
            fail(e, "der Vorrat \(r.pool.rawValue) wird nicht geführt", &run.pipeline)
            return
        }
        var raised = run.base.applying(run.events, book: book)
        raised.pools[r.pool] = PoolState(current: state.current.addingSaturating(amount), max: state.max)
        let b = Evaluation(book: book, situation: raised).breakdown(Query(target), depth: 0)
        let held = b.result.map { min($0, state.current.addingSaturating(amount)) } ?? state.current.addingSaturating(amount)
        let granted = max(0, held - state.current)
        let caps = b.lines.filter { $0.kind == .capped }.compactMap(\.origin)
        run.events.append(Event(kind: .restored, origin: e.origin.clauseRef, pool: r.pool, amount: granted,
                                via: (via + v.via + caps).uniqued(), rulings: decided(e), facts: (used + v.used).uniqued()))
        run.pools[r.pool] = PoolState(current: state.current + granted, max: state.max)
    }

    func cost(_ c: Cost, _ e: Effect, level: Int?, used: [FactUse], via: [ClauseRef], _ run: inout ActionRun) {
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
        // Checked: the shares are the player's numbers, however large.
        var chosen = 0
        for n in shares.values {
            let (sum, overflow) = chosen.addingReportingOverflow(n)
            guard !overflow else {
                fail(e, "die gewählten Anteile liegen außerhalb des Zahlenbereichs", &run.pipeline)
                return
            }
            chosen = sum
        }
        shares[c.pool] = amount - chosen          // amount ≥ 0 and chosen ≥ 0: no overflow
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
            guard n > 0, let state = run.pools[p] else { continue }
            if p != .le, state.current < n {
                fail(e, "\(n) \(p.rawValue) gefordert, \(max(0, state.current)) vorhanden", &run.pipeline)
                return
            }
            if state.current.subtractingReportingOverflow(n).overflow {
                fail(e, "\(n) \(p.rawValue) liegt außerhalb des Zahlenbereichs", &run.pipeline)
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
                guard !state.current.subtractingReportingOverflow(remaining).overflow else {
                    refuse(e, "\(remaining) \(p.rawValue) liegt außerhalb des Zahlenbereichs", &run)
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

    func unknown(_ e: Effect, _ facts: [UnknownFact], facts used: [FactUse], via: [ClauseRef],
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
            gain(id, levels: g.levels ?? 1, span: g.span, effect: e, facts: used, via: via, &run)
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
            gain(id, levels: g.levels ?? 1, span: g.span, effect: e, facts: facts, via: (via + t.via).uniqued(), &run)
        }
    }

    /// `gained` within the rule's Stufen (`Rule.most`), counted against the Stufe the hero has
    /// as this action's events so far leave it: two conditions at IV gaining one state give one
    /// `gained(…, 1)`. Nothing left to gain gives no event: the effect is recorded `overridden`
    /// with the reason (the player's own `.state`: a text). A note says when fewer are gained
    /// than asked. A negative count gives `cleared`; a count of 0, or one beyond `Int`, a text.
    func gain(_ id: String, levels: Int, span: Span?, effect e: Effect?, facts: [FactUse], via: [ClauseRef],
              _ run: inout ActionRun) {
        func nothing(_ reason: String) {
            if let e { fail(e, reason, &run.pipeline) } else {
                run.pipeline.show(TextLine(kind: .notApplicable, text: "Nichts geändert: \(reason)"))
            }
        }
        guard let target = book.rules[id] else {
            let reason = "die Regel \(id) gibt es nicht"
            if let e { fail(e, reason, &run.pipeline) } else {
                run.pipeline.show(TextLine(kind: .notApplicable, text: "Regel konnte nicht angewandt werden: \(reason)"))
            }
            return
        }
        guard levels != 0 else {
            nothing("\(id) um 0 Stufen")
            return
        }
        guard levels != .min else {
            let reason = "\(levels) Stufen liegen außerhalb des Zahlenbereichs"
            if let e { fail(e, reason, &run.pipeline) } else {
                run.pipeline.show(TextLine(kind: .notApplicable, text: "Regel konnte nicht angewandt werden: \(reason)"))
            }
            return
        }
        let origin = e?.origin.clauseRef, rulings = e.map(decided) ?? []
        let have = run.owned[id] ?? 0
        if levels < 0 {
            run.events.append(Event(kind: .cleared, origin: origin, rule: id, levels: -levels, span: span, via: via,
                                    rulings: rulings, facts: facts))
            run.owned[id] = max(0, have.subtractingSaturating(-levels))
            return
        }
        var granted = levels, note: String?
        if let most = target.most {
            granted = max(0, min(levels, most.subtractingSaturating(have)))
            guard granted > 0 else {
                let reason = "\(id) bereits auf Stufe \(have) (höchstens Stufe \(most))"
                if let e {
                    run.pipeline.record(NotApplied(origin: e.origin.clauseRef, reason: .overridden, because: reason,
                                                   rulings: e.ruling, facts: facts, via: via))
                } else {
                    run.pipeline.show(TextLine(kind: .notApplicable, text: "Nichts geändert: \(id) ist bereits auf Stufe \(have) (höchstens Stufe \(most))"))
                }
                return
            }
            if granted < levels { note = "höchstens Stufe \(most)" }
        }
        run.events.append(Event(kind: .gained, origin: origin, rule: id, levels: granted, span: span, via: via,
                                rulings: rulings, facts: facts, note: note))
        run.owned[id] = have.addingSaturating(granted)
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
