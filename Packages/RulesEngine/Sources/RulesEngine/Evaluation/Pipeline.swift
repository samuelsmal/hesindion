import Foundation

// The value pipeline (spec §5.2): every query runs the phases in `Phase.allCases` order, each a
// function of its own over one `PipelineState`. Phases 1–3 (base, level, add) are here; lines,
// multiply, cap and legality are Task 23's.

/// One `Engine.evaluate` call. The memos live exactly as long as the call and are shared by its
/// nested evaluations (operand targets, `hero.levelOf`), never by another call.
final class Evaluation {
    let book: RuleBook
    let situation: Situation
    var applicabilityMemo: [String: Memo<Applicability>] = [:]
    var baseLevelMemo: [String: Memo<BaseLevel>] = [:]
    /// Operand targets already evaluated in this call, by query.
    var operandMemo: [String: ResolvedTarget] = [:]
    /// The answers that depend on where the evaluation stands, since the memos are not keyed by
    /// depth: depth-guard hits, and `.computing` memo hits (a cycle) by memo key. A result whose
    /// computation met the guard, or a cycle through an entry still open outside it, is not
    /// memoized (`settle`).
    var depthHits = 0
    var cycleHits: [String: Int] = [:]

    init(book: RuleBook, situation: Situation) {
        self.book = book
        self.situation = situation
    }

    /// Every top-level `require { enables: true }` in the book, in rule-id and clause order.
    private(set) lazy var enablers: [(effect: Effect, require: Require)] = book.rules.keys.sorted(by: Self.idOrder)
        .flatMap { id in book.rules[id]!.clauses.flatMap(\.effects) }
        .compactMap { e in
            if case .require(let r) = e.payload, r.enables == true { return (e, r) }
            return nil
        }

    /// Rule id → the derives to `level(rule: id)`, in the compiler's order.
    private(set) lazy var levelDerivesByRule: [String: [Effect]] = (book.reach["level"] ?? [])
        .sorted(by: EffectOrigin.compilerOrder)
        .compactMap { book.effect(at: $0) }
        .reduce(into: [:]) { acc, e in
            if case .derive(let d) = e.payload, d.to.name == "level", let rule = d.to.context["rule"] {
                acc[rule, default: []].append(e)
            }
        }

    /// Runs `compute` for the memo entry `key` (nil for an entry with no `.computing` state) and
    /// says whether its result is final: it met no depth guard, and every cycle it met went
    /// through `key` itself, which is now closed.
    func settle<T>(_ key: String?, _ compute: () -> T) -> (value: T, final: Bool) {
        let depthMark = depthHits, cyclesBefore = cycleHits
        let value = compute()
        if let key { cycleHits[key] = nil }
        return (value, depthHits == depthMark && cycleHits == cyclesBefore)
    }

    /// Rule ids as rulec sorts them (Unicode scalars, as Python compares strings).
    static func idOrder(_ a: String, _ b: String) -> Bool {
        a.unicodeScalars.lexicographicallyPrecedes(b.unicodeScalars)
    }

    /// The breakdown of `query`, running the phases up to `last`. Beyond `Values.maxDepth` a nested
    /// evaluation gives an empty breakdown flagged `depthExceeded`.
    func breakdown(_ query: Query, depth: Int, through last: Phase = .legality) -> Breakdown {
        guard depth <= Values.maxDepth else {
            depthHits += 1
            return Breakdown(query: query, depthExceeded: true)
        }
        var state = PipelineState(query: query, depth: depth, candidates: candidates(for: query))
        for phase in Phase.allCases where phase <= last {
            switch phase {
            case .base: basePhase(&state)
            case .level: levelPhase(&state)
            case .add: addPhase(&state)
            case .lines, .multiply, .cap, .legality: break      // Task 23
            }
        }
        return state.breakdown
    }

    /// The effects that reach `query`: `book.effects(reaching:)`, less those whose own targets do
    /// not match its context. A `level(rule: X)` query keeps the useLevels acting on X (rulec lists
    /// every useLevel under `level`), and no other rule's.
    private func candidates(for query: Query) -> [Effect] {
        let levelRule = query.levelRule
        return book.effects(reaching: query.name).filter { e in
            switch e.payload {
            case .add(let a): return a.to.contains { $0.matches(query.target) }
            case .set(let s): return s.to.contains { $0.matches(query.target) }
            case .derive(let d): return d.to.matches(query.target)
            case .multiply(let m): return m.to.contains { $0.matches(query.target) }
            case .cap(let c): return c.to.contains { $0.matches(query.target) }
            case .floor(let f): return f.to.contains { $0.matches(query.target) }
            case .useLevel(let u): return levelRule == nil || u.rule == levelRule
            default: return true
            }
        }
    }
}

/// What the phases of one query build up.
struct PipelineState {
    let query: Query
    let depth: Int
    let candidates: [Effect]
    var base: Line?
    var lines: [Line] = []
    var notApplied: [NotApplied] = []
    var questions: [Question] = []
    var texts: [TextLine] = []
    /// Rule id → its level after the useLevels so far (phase 2).
    var levels: [String: Int] = [:]
    /// Rule id → the useLevels that acted on it, in order (R28); every later line of the rule
    /// carries them in `via`.
    var levelVia: [String: [ClauseRef]] = [:]
    var depthExceeded = false

    init(query: Query, depth: Int, candidates: [Effect]) {
        self.query = query; self.depth = depth; self.candidates = candidates
    }

    /// The value so far: the base plus every line.
    var running: Int { (base?.value ?? 0) + lines.reduce(0) { $0 + $1.value } }

    var breakdown: Breakdown {
        Breakdown(query: query, base: base, lines: lines, notApplied: notApplied, questions: questions,
                  texts: texts, depthExceeded: depthExceeded)
    }

    mutating func ask(_ unknown: [UnknownFact], for origin: ClauseRef) {
        for u in unknown {
            if let i = questions.firstIndex(where: { $0.fact == u.name }) {
                if !questions[i].origins.contains(origin) { questions[i].origins.append(origin) }
            } else {
                questions.append(Question(fact: u.name, owner: u.owner, origins: [origin]))
            }
        }
    }

    mutating func record(_ entry: NotApplied) {
        if !notApplied.contains(entry) { notApplied.append(entry) }
    }

    mutating func show(_ text: TextLine) {
        if !texts.contains(text) { texts.append(text) }
    }
}

extension Query {
    /// X for `level(rule: X)`.
    var levelRule: String? { name == "level" ? target.context["rule"] : nil }
}

// MARK: - The phases

extension Evaluation {
    /// Phase 1. The sheet's value for the query (`base[query.description]`, else
    /// `base[query.name]`, never for `level`: a key `level` would set every rule's level), or for
    /// `level(rule: X)` the owned level; else the sum of every applicable `derive` reaching the
    /// query, one part per `sum` term. The derives of X to its own level count whether or not X
    /// applies: they decide whether it does.
    ///
    /// R35: a `suppress` naming a clause that holds one of these derives acts here, before the
    /// sum (alternative derives: trefferzonen-ruestungsschutz.RS4 over ruestung-und-belastung.A1,
    /// reiterkampf.RK1 over kampfwerte.KW9). Its applicability and `when` are read as usual; the
    /// derives of the clauses it names go to `notApplied(suppressed)`. Every other suppress is the
    /// lines phase's.
    private func basePhase(_ state: inout PipelineState) {
        let q = state.query
        let derives = state.candidates.filter { $0.phase == .base }
        if let v = situation.base[q.description] ?? (q.name == "level" ? nil : situation.base[q.name]) {
            state.base = Line(value: v, kind: .base, owner: .sheet, note: "Grundwert laut Bogen")
        } else if let id = q.levelRule, let owned = situation.owned[id] {
            state.base = Line(value: owned.level, kind: .base,
                              facts: [FactUse(name: "hero.levelOf.\(id)", value: .int(owned.level), owner: .sheet)],
                              owner: .sheet, note: "Stufe laut Bogen")
        }
        if let base = state.base {
            for e in derives where applies(e, &state, ownLevel: q.levelRule) {
                state.record(NotApplied(origin: e.origin.clauseRef, reason: .overridden, because: base.note,
                                        rulings: e.ruling, via: ruleVia(e.origin.rule, state)))
            }
            return
        }
        let suppressed = suppressions(of: derives, &state)
        var parts: [Line] = []
        for e in derives where suppressed[e.origin.clauseRef] == nil {
            guard case .derive(let d) = e.payload, applies(e, &state, ownLevel: q.levelRule) else { continue }
            let rule = e.origin.rule
            let own = rule == q.levelRule
            let level = own ? nil : ruleLevel(rule, levels: state.levels, depth: state.depth)
            let via = own ? [] : ruleVia(rule, state)
            guard let used = gate(e, level: level, via: via, &state) else { continue }
            let results = d.sum.map { value($0, level: level, rule: rule, depth: state.depth) }
            guard computed(results, of: e, used: used, via: via, &state) else { continue }
            parts += results.map { r in
                Line(value: r.value!, kind: .base, origin: e.origin.clauseRef, via: (via + r.via).uniqued(),
                     rulings: decided(e), facts: (used + r.used).uniqued())
            }
        }
        guard let first = parts.first else { return }
        state.base = Line(value: parts.reduce(0) { $0 + $1.value }, kind: .base, origin: first.origin,
                          via: parts.flatMap(\.via).uniqued(), rulings: parts.flatMap(\.rulings).uniqued(),
                          facts: parts.flatMap(\.facts).uniqued(), parts: parts)
    }

    /// R35: the clauses among `derives`' that a firing `suppress` names, with the suppressor. Each
    /// suppressed derive that would apply is recorded as `notApplied(suppressed)`.
    private func suppressions(of derives: [Effect], _ state: inout PipelineState) -> [ClauseRef: Effect] {
        let clauses = Set(derives.map(\.origin.clauseRef))
        var suppressed: [ClauseRef: Effect] = [:]
        for e in state.candidates {
            guard case .suppress(let s) = e.payload, s.line.kind == .line else { continue }
            let named = s.line.ids.compactMap { $0.id.flatMap(ClauseRef.init) }.filter(clauses.contains)
            guard !named.isEmpty, applies(e, &state) else { continue }
            let rule = e.origin.rule
            let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
            guard gate(e, level: level, via: ruleVia(rule, state), &state) != nil else { continue }
            for c in named where suppressed[c] == nil { suppressed[c] = e }
        }
        for d in derives {
            guard let by = suppressed[d.origin.clauseRef], applies(d, &state, ownLevel: state.query.levelRule) else { continue }
            state.record(NotApplied(origin: d.origin.clauseRef, reason: .suppressed,
                                    because: by.because ?? by.origin.clauseRef.description, rulings: d.ruling,
                                    via: [by.origin.clauseRef]))
        }
        return suppressed
    }

    /// Phase 2. Each applicable `useLevel` changes its target rule's level (R28): the useLevels on
    /// one target chain in rule-id order, then clause order. `as` is evaluated with `level` bound
    /// to the target's level after the earlier useLevels; `lowerBy` with `level` bound to the
    /// acting rule's own level, and is subtracted. Either is floored at `min` (default 0).
    ///
    /// Each gives a `.levelAs` line, "Stufe X wirkt wie Y", with `was` X and `now` Y. Its value is
    /// 0, except in the query `level(rule: target)`, where it is Y − X so that the result is the
    /// level the rule acts at. A useLevel acts only where its target rule has a value line to
    /// change: the target applies and has a value effect reaching the query, or the query is its
    /// level.
    private func levelPhase(_ state: inout PipelineState) {
        let levelRule = state.query.levelRule
        var chains: [String: [Effect]] = [:]
        for e in state.candidates where e.phase == .level {
            if case .useLevel(let u) = e.payload { chains[u.rule, default: []].append(e) }
        }
        for target in chains.keys.sorted(by: Self.idOrder) {
            // The cheap test first: asking a rule's applicability from inside its own (Schmerz's
            // level reads LE, whose query sees the useLevels on Schmerz) is a cycle.
            let relevant = target == levelRule
                || (state.candidates.contains { $0.origin.rule == target && $0.phase != nil && $0.phase != .level }
                    && applicability(of: target, depth: state.depth).applies)
            guard relevant else { continue }
            var current = target == levelRule
                ? state.base?.value
                : ruleLevel(target, levels: state.levels, depth: state.depth)
            for e in chains[target]!.sorted(by: chainOrder) {
                guard case .useLevel(let u) = e.payload, applies(e, &state) else { continue }
                let actor = e.origin.rule
                let actorLevel = ruleLevel(actor, levels: state.levels, depth: state.depth)
                let via = ruleVia(actor, state)
                guard let used = gate(e, level: actorLevel, via: via, &state) else { continue }
                guard let before = current else {
                    let unknown = baseLevel(of: target, depth: state.depth).unknown
                    if unknown.isEmpty {
                        fail(e, "die Stufe von \(target) ist nicht bekannt", &state)
                    } else {
                        state.record(NotApplied(origin: e.origin.clauseRef, reason: .unknownFact, because: e.because,
                                                rulings: e.ruling, facts: used, via: via))
                        state.ask(unknown, for: e.origin.clauseRef)
                    }
                    continue
                }
                let r: ValueResult
                if let asValue = u.as {
                    r = value(asValue, level: before, rule: actor, depth: state.depth)
                } else if let lowerBy = u.lowerBy {
                    r = value(lowerBy, level: actorLevel, rule: actor, depth: state.depth)
                } else {
                    fail(e, "useLevel ohne as und lowerBy", &state)
                    continue
                }
                guard computed([r], of: e, used: used, via: via, &state), let v = r.value else { continue }
                let after = max(u.as != nil ? v : before - v, u.min ?? 0)
                state.lines.append(Line(value: target == levelRule ? after - before : 0, kind: .levelAs,
                                        origin: e.origin.clauseRef, via: (via + r.via).uniqued(), rulings: decided(e),
                                        facts: (used + r.used).uniqued(), note: "Stufe \(before) wirkt wie \(after)",
                                        was: before, now: after))
                current = after
                state.levels[target] = after
                if !state.levelVia[target, default: []].contains(e.origin.clauseRef) {
                    state.levelVia[target, default: []].append(e.origin.clauseRef)
                }
            }
        }
    }

    /// Phase 3. The applicable `set`s whose `when` is yes apply first: the last in rule-id order
    /// wins, giving a `.set` line of `target − (base + lines so far)`; the others are `overridden`.
    /// Then each `add`: its value, times the fact `per` when given, or that many steps along its
    /// `scale`.
    private func addPhase(_ state: inout PipelineState) {
        let effects = state.candidates.filter { $0.phase == .add }
        var sets: [(effect: Effect, value: ValueResult, used: [FactUse], via: [ClauseRef])] = []
        for e in effects {
            guard case .set(let s) = e.payload, applies(e, &state) else { continue }
            let rule = e.origin.rule
            let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
            let via = ruleVia(rule, state)
            guard let used = gate(e, level: level, via: via, &state) else { continue }
            let r = value(s.value, level: level, rule: rule, depth: state.depth)
            guard computed([r], of: e, used: used, via: via, &state) else { continue }
            sets.append((e, r, used, via))
        }
        if let winner = sets.last {
            for lost in sets.dropLast() {
                state.record(NotApplied(origin: lost.effect.origin.clauseRef, reason: .overridden,
                                        because: winner.effect.origin.clauseRef.description, rulings: lost.effect.ruling,
                                        facts: (lost.used + lost.value.used).uniqued(), via: lost.via,
                                        value: lost.value.value))
            }
            let before = state.running, now = winner.value.value!
            state.lines.append(Line(value: now - before, kind: .set, origin: winner.effect.origin.clauseRef,
                                    via: (winner.via + winner.value.via).uniqued(), rulings: decided(winner.effect),
                                    facts: (winner.used + winner.value.used).uniqued(), was: before, now: now))
        }
        for e in effects {
            guard case .add(let a) = e.payload, applies(e, &state) else { continue }
            let rule = e.origin.rule
            let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
            let via = ruleVia(rule, state)
            guard var used = gate(e, level: level, via: via, &state) else { continue }
            var times = 1.0
            if let per = a.per {
                let f = fact(per, level: level, rule: rule, depth: state.depth)
                guard let use = f.use else {
                    state.record(NotApplied(origin: e.origin.clauseRef, reason: .unknownFact, because: e.because,
                                            rulings: e.ruling, facts: used, via: via))
                    state.ask(f.unknown, for: e.origin.clauseRef)
                    continue
                }
                guard let n = use.value.double else {
                    fail(e, "\(per) ist keine Zahl", &state)
                    continue
                }
                used = (used + [use]).uniqued()
                times = n
            }
            let r = value(a.value, level: level, rule: rule, depth: state.depth)
            guard computed([r], of: e, used: used, via: via, &state), let v = r.value else { continue }
            let amount = Int(Values.round(Double(v) * times, .up))
            let facts = (used + r.used).uniqued()
            if let scale = a.scale {
                step(e, along: scale, by: amount, via: (via + r.via).uniqued(), facts: facts, &state)
            } else {
                state.lines.append(Line(value: amount, kind: .add, origin: e.origin.clauseRef,
                                        via: (via + r.via).uniqued(), rulings: decided(e), facts: facts))
            }
        }
    }

    /// A step along a provided scale (the spell parameters, zaubermodifikationen.ZM8): from the
    /// entry equal to the value so far, `steps` entries on, held at either end (ZM5: never below
    /// the bottom step). The line's `was` is the value before, `now` the entry reached; the
    /// providing clause joins `via`.
    private func step(_ e: Effect, along scale: String, by steps: Int, via: [ClauseRef], facts: [FactUse],
                      _ state: inout PipelineState) {
        let providers = book.providers(of: scale)
        guard providers.count == 1, case .array(let entries) = providers[0].value else {
            fail(e, "keine Skala \(scale)", &state)
            return
        }
        guard state.base != nil else {
            fail(e, "kein Grundwert für \(state.query)", &state)
            return
        }
        let before = state.running
        guard let i = entries.firstIndex(where: { $0.int == before }) else {
            fail(e, "\(before) steht nicht auf der Skala \(scale)", &state)
            return
        }
        guard let now = entries[min(max(i + steps, 0), entries.count - 1)].int else {
            fail(e, "die Skala \(scale) nennt dort keine Zahl", &state)
            return
        }
        state.lines.append(Line(value: now - before, kind: .add, origin: e.origin.clauseRef,
                                via: (via + [providers[0].origin.clauseRef]).uniqued(), rulings: decided(e), facts: facts,
                                was: before, now: now))
    }
}

// MARK: - One effect

extension Evaluation {
    /// Whether the effect's rule applies; a core rule outside the rulesets records `rulesetOff`.
    /// `ownLevel`: in the query `level(rule: X)`, X's derives to its own level count regardless.
    private func applies(_ e: Effect, _ state: inout PipelineState, ownLevel: String? = nil) -> Bool {
        if let ownLevel, e.origin.rule == ownLevel { return true }
        let a = applicability(of: e.origin.rule, depth: state.depth)
        switch a.status {
        case .rulesetOff(let ruleset):
            state.record(NotApplied(origin: e.origin.clauseRef, reason: .rulesetOff,
                                    because: "Regelset \(ruleset) nicht aktiv", rulings: e.ruling))
        case .unknownLevel(let unknown):
            state.record(NotApplied(origin: e.origin.clauseRef, reason: .unknownFact,
                                    because: "Stufe von \(e.origin.rule) unbekannt", rulings: e.ruling))
            state.ask(unknown, for: e.origin.clauseRef)
        case .applies, .silent:
            break
        }
        return a.applies
    }

    /// The clauses every line of `rule` rests on: the require that enabled it, then the useLevels
    /// that acted on it so far.
    private func ruleVia(_ rule: String, _ state: PipelineState) -> [ClauseRef] {
        (applicability(of: rule, depth: state.depth).via + (state.levelVia[rule] ?? [])).uniqued()
    }

    /// The effect's `when`: the facts it read when it is yes and the effect rests on no open
    /// ruling; else nil, with the reason recorded: no → `conditionFalse`; an open ruling →
    /// `openRuling` and the clause text with the ruling's question; unknown → `unknownFact` and
    /// one question per unknown fact, with its owner.
    private func gate(_ e: Effect, level: Int?, via: [ClauseRef], _ state: inout PipelineState) -> [FactUse]? {
        let origin = e.origin.clauseRef
        var r = ConditionResult(truth: .yes)
        if let when = e.when { r = condition(when, level: level, rule: e.origin.rule, depth: state.depth) }
        if r.truth == .no {
            state.record(NotApplied(origin: origin, reason: .conditionFalse, because: e.because, rulings: e.ruling,
                                    facts: r.used, via: via))
            return nil
        }
        if let open = e.ruling.first(where: { book.rulings[$0]?.status == .open }) {
            state.record(NotApplied(origin: origin, reason: .openRuling, because: e.because, rulings: e.ruling,
                                    facts: r.used, via: via))
            state.show(TextLine(kind: .openRuling, text: clauseText(origin) ?? origin.description, origin: origin,
                                ruling: open, question: book.rulings[open]?.question))
            return nil
        }
        if r.truth == .unknown {
            state.record(NotApplied(origin: origin, reason: .unknownFact, because: e.because, rulings: e.ruling,
                                    facts: r.used, via: via))
            state.ask(r.unknown, for: origin)
            return nil
        }
        return r.used
    }

    /// Whether every value of an effect was computed. When one was not: its unknown facts give
    /// `unknownFact` and questions; the depth guard or anything else gives a text "Regel konnte
    /// nicht angewandt werden" (spec §11). A computed value that read an operand with open
    /// questions asks them too.
    private func computed(_ results: [ValueResult], of e: Effect, used: [FactUse], via: [ClauseRef],
                          _ state: inout PipelineState) -> Bool {
        let origin = e.origin.clauseRef
        let unknown = results.flatMap(\.unknown).uniqued()
        if results.contains(where: \.depthExceeded) {
            state.depthExceeded = true
            depthHits += 1
            fail(e, "Rekursionstiefe \(Values.maxDepth) überschritten", &state)
            return false
        }
        if results.contains(where: { $0.value == nil }) {
            if unknown.isEmpty {
                fail(e, "Wert nicht berechenbar", &state)
            } else {
                state.record(NotApplied(origin: origin, reason: .unknownFact, because: e.because, rulings: e.ruling,
                                        facts: (used + results.flatMap(\.used)).uniqued(), via: via))
                state.ask(unknown, for: origin)
            }
            return false
        }
        state.ask(unknown, for: origin)
        return true
    }

    private func fail(_ e: Effect, _ reason: String, _ state: inout PipelineState) {
        let origin = e.origin.clauseRef
        state.show(TextLine(kind: .notApplicable, text: "Regel konnte nicht angewandt werden: \(origin) – \(reason)",
                            origin: origin))
    }

    /// The decided rulings an applied effect rests on (an unknown id counts as decided: rulec
    /// checks every id).
    private func decided(_ e: Effect) -> [String] {
        e.ruling.filter { book.rulings[$0]?.status != .open }
    }

    private func clauseText(_ ref: ClauseRef) -> String? {
        book.rules[ref.rule]?.clauses.first { $0.id == ref.clause }?.text
    }

    /// R28: rule id, then the clause's position in the rule, then the effect's index.
    private func chainOrder(_ a: Effect, _ b: Effect) -> Bool {
        if a.origin.rule != b.origin.rule { return Self.idOrder(a.origin.rule, b.origin.rule) }
        let clauses = book.rules[a.origin.rule]?.clauses.map(\.id) ?? []
        let ia = clauses.firstIndex(of: a.origin.clause) ?? .max, ib = clauses.firstIndex(of: b.origin.clause) ?? .max
        if ia != ib { return ia < ib }
        return EffectOrigin.compilerOrder(a.origin, b.origin)
    }
}
