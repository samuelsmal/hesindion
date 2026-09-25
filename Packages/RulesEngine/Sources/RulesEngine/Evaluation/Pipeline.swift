import Foundation

// The value pipeline (spec §5.2): every query runs the phases in `Phase.allCases` order, each a
// function of its own over one `PipelineState`. Phases 1–6 are here; phase 7 (legality), the
// offers and the texts are in `Legality.swift`.

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
    /// The legality effects on choices, evaluated once per call (`choiceRules()`), and the
    /// book's offers.
    var choiceRulesMemo: [ChoiceRule]?
    /// `rule:fact` → why a derived fact stated from the check cannot be decided (a stated
    /// Anwendungsgebiet that cannot be compared with the rule's option); `gate` shows it.
    var undecidable: [String: String] = [:]
    var offersMemo: [(offer: Offer, effect: Effect, rule: String)]?

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

    /// Choice id → the `default` its offers state, for the choices whose offers state one and
    /// agree on it (Task 30).
    private(set) lazy var choiceDefaults: [String: JSONValue] = {
        var seen: [String: [JSONValue?]] = [:]
        for rule in book.rules.values {
            for e in rule.clauses.flatMap(\.effects) {
                if case .offer(let o) = e.payload { seen[o.choice, default: []].append(o.default) }
            }
        }
        return seen.compactMapValues { defaults in
            guard let first = defaults.first, let d = first, defaults.allSatisfy({ $0 == d }) else { return nil }
            return d
        }
    }()

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
    ///
    /// Line control (phase 4) is decided before phase 3 computes a line: a `replace` swaps the
    /// replaced effect's value before its `per` (plan A.3), and a suppressed effect is never
    /// computed, so it asks nothing. This differs from running phase 4 after phase 3 in two
    /// ways: a suppressed effect is recorded as `suppressed` even when its own `when` is no or
    /// unknown (it would have given no line anyway), and a suppressed `set` takes no part in
    /// choosing the winner, so the next firing set wins.
    ///
    /// Legality, the offers and the texts belong to the query asked (depth 0). A nested
    /// evaluation (an operand, `hero.levelOf`) gives a number only: they would add questions that
    /// cannot change it.
    func breakdown(_ query: Query, depth: Int, through last: Phase = .legality) -> Breakdown {
        guard depth <= Values.maxDepth else {
            depthHits += 1
            return Breakdown(query: query, depthExceeded: true)
        }
        var state = PipelineState(query: query, depth: depth, candidates: candidates(for: query))
        for (name, value) in query.checkFacts.merging(combatFacts(of: query), uniquingKeysWith: { a, _ in a })
            where situation.facts[name] == nil {
            state.local[name] = Fact(name: name, value: value, owner: .derived)
        }
        for phase in Phase.allCases where phase <= last {
            switch phase {
            case .base: basePhase(&state)
            case .level: levelPhase(&state)
            case .add:
                linesPhase(&state)
                addPhase(&state)
            case .lines: break                                  // decided with phase 3, above
            case .multiply: multiplyPhase(&state)
            case .cap: capPhase(&state)
            case .legality: if depth == 0 { legalityPhase(&state) }
            }
        }
        if depth == 0 && last == .legality { playerParts(&state) }
        carryLevelRulings(&state)
        return state.breakdown
    }

    /// Task 30: a line of a rule whose level a useLevel changed rests on that useLevel's decided
    /// rulings as it rests on its clause (`levelVia`): SA_41.table-shift on Belastung's line,
    /// ADV_49.zaeher-hund-iv on Schmerz's.
    private func carryLevelRulings(_ state: inout PipelineState) {
        guard !state.levelRulings.isEmpty else { return }
        func carry(_ line: inout Line) {
            guard let rule = line.origin?.rule, line.kind != .levelAs, let more = state.levelRulings[rule] else { return }
            line.rulings = (line.rulings + more).uniqued()
        }
        for i in state.lines.indices { carry(&state.lines[i]) }
        if var base = state.base {
            for i in base.parts.indices { carry(&base.parts[i]) }
            state.base = base
        }
    }

    /// The effects that reach `query`: `book.effects(reaching:)`, less those whose own targets do
    /// not match its context. A `level(rule: X)` query keeps the useLevels acting on X (rulec lists
    /// every useLevel under `level`), and no other rule's. Then the value effects a procedure put
    /// in force for this action (`Situation.inForce`) whose targets match it.
    private func candidates(for query: Query) -> [Effect] {
        let levelRule = query.levelRule
        let inForce = situation.inForce.filter { e in
            switch e.payload {
            case .add(let a): a.to.contains { $0.matches(query.target) }
            case .set(let s): s.to.contains { $0.matches(query.target) }
            case .multiply(let m): m.to.contains { $0.matches(query.target) }
            case .cap(let c): c.to.contains { $0.matches(query.target) }
            case .floor(let f): f.to.contains { $0.matches(query.target) }
            default: false
            }
        }
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
        } + inForce
    }
}

/// A firing `suppress` or `replace` (phase 4), with the level its rule acts at.
struct Control {
    var effect: Effect
    var level: Int?
    /// The replace's payload; nil for a suppress.
    var replace: Replace?

    var ref: ClauseRef { effect.origin.clauseRef }
    /// What the controlled effect's entry says: the effect's `because`, else its clause.
    var because: String { effect.because ?? ref.description }
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
    var offers: [OfferedChoice] = []
    var legal = Legality()
    /// Rule id → its level after the useLevels so far (phase 2).
    var levels: [String: Int] = [:]
    /// Rule id → the useLevels that acted on it, in order (R28); every later line of the rule
    /// carries them in `via`.
    var levelVia: [String: [ClauseRef]] = [:]
    /// Rule id → the decided rulings of those useLevels (Task 30), which the rule's lines carry.
    var levelRulings: [String: [String]] = [:]
    /// Phase 4: the firing suppresses by the clause, rule or rule kind they name, and the firing
    /// replaces by clause.
    var suppressedClauses: [ClauseRef: Control] = [:]
    var suppressedRules: [String: Control] = [:]
    var suppressedKinds: [RuleKind: Control] = [:]
    var replacements: [ClauseRef: Control] = [:]
    /// The query's own facts, which every `when` of it reads: `query.target` (its name), and
    /// `query.result` once phase 7 runs.
    var local: [String: Fact]
    var depthExceeded = false

    init(query: Query, depth: Int, candidates: [Effect]) {
        self.query = query; self.depth = depth; self.candidates = candidates
        local = ["query.target": Fact(name: "query.target", value: .string(query.name), owner: .derived)]
    }

    /// The value so far: the base plus every line.
    var running: Int { (base?.value ?? 0) + lines.reduce(0) { $0 + $1.value } }

    /// The lines so far as a screen lists them: the base's parts (or the base), then the lines.
    var shown: [Line] { (base.map { $0.parts.isEmpty ? [$0] : $0.parts } ?? []) + lines }

    var breakdown: Breakdown {
        Breakdown(query: query, base: base, lines: lines, notApplied: notApplied, offers: offers, questions: questions,
                  texts: texts, legal: legal, depthExceeded: depthExceeded)
    }

    /// The suppress acting on `e` (of a rule of `kind`), if any.
    func suppressor(of e: Effect, kind: RuleKind?) -> Control? {
        suppressedClauses[e.origin.clauseRef] ?? suppressedRules[e.origin.rule] ?? kind.flatMap { suppressedKinds[$0] }
    }

    /// One question per unknown fact, with the asking clauses. The query's own facts
    /// (`query.result` of a query without a result) are the engine's: nobody is asked for them.
    mutating func ask(_ unknown: [UnknownFact], for origin: ClauseRef) {
        for u in unknown where !u.name.hasPrefix("query.") {
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

    /// Task 30: the check a check stage query names by its context, as facts every `when` of it
    /// reads where the situation states none: `check.modifier(spell: X)` is a spell check
    /// (`check.kind: spell`, `check.spell: X`), `(talent: X)` a talent check. `any` names no
    /// spell or talent.
    var checkFacts: [String: JSONValue] {
        guard name.hasPrefix("check.") else { return [:] }
        for kind in ["spell", "talent"] {
            guard let subject = target.context[kind] else { continue }
            var out: [String: JSONValue] = ["check.kind": .string(kind)]
            if subject != "any" { out["check.\(kind)"] = .string(subject) }
            return out
        }
        return [:]
    }
}

// MARK: - The phases

extension Evaluation {
    /// Phase 1. For `leCurrent` / `aspCurrent`, the pool's current value when the situation tracks
    /// the pool (R39). Else the sheet's value for the query (`base[query.description]`, else the
    /// one keyed by the item it is made with (R66, `itemBase`), else
    /// `base[query.name]`, never for `level`: a key `level` would set every rule's level), or for
    /// `level(rule: X)` the owned level; else the sum of every applicable `derive` reaching the
    /// query, one part per `sum` term. The derives of X to its own level count whether or not X
    /// applies: they decide whether it does.
    ///
    /// R35: a `suppress` or `replace` naming a clause that holds one of these derives acts here,
    /// before the sum (alternative derives: trefferzonen-ruestungsschutz.RS4 over
    /// ruestung-und-belastung.A1, reiterkampf.RK1 over kampfwerte.KW9). Its applicability and
    /// `when` are read as usual, at its rule's level as the derives read theirs. A suppressed
    /// derive goes to `notApplied(suppressed)`; a replaced one (its `when` kept) gives one
    /// `.replaced` part of the replacer's value, with `was` its own sum, and goes to
    /// `notApplied(replaced)` with that sum. Every other suppress and replace is phase 4's.
    ///
    /// Task 30: a derived `level(rule: X)` above X's `levels` is X's highest Stufe, with a
    /// `.capped` part (Turnierrüstung's Belastung 5 is Belastung IV).
    private func basePhase(_ state: inout PipelineState) {
        let q = state.query
        let derives = state.candidates.filter { $0.phase == .base }
        if q.target.context.isEmpty, let pool = Pool.current(target: q.name), let current = situation.pools[pool] {
            // R39: the pool's current value, whatever the sheet's base says.
            state.base = Line(value: current.current, kind: .base,
                              facts: [FactUse(name: pool.currentFact!, value: .int(current.current), owner: .derived)],
                              owner: .sheet, note: "aktueller Stand")
        } else if let v = situation.base[q.description] ?? itemBase(q) ?? (q.name == "level" ? nil : situation.base[q.name]) {
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
        let control = baseControl(of: derives, &state)
        var parts: [Line] = []
        var replacedClauses: Set<ClauseRef> = []
        for e in derives {
            let clause = e.origin.clauseRef
            if let by = control[clause], by.replace == nil { continue }
            guard case .derive(let d) = e.payload, applies(e, &state, ownLevel: q.levelRule) else { continue }
            let rule = e.origin.rule
            let own = rule == q.levelRule
            let level = own ? nil : ruleLevel(rule, levels: state.levels, depth: state.depth)
            let via = own ? [] : ruleVia(rule, state)
            guard let used = gate(e, level: level, via: via, &state) else { continue }
            if let by = control[clause], let replace = by.replace {
                let own = d.sum.map { value($0, level: level, rule: rule, depth: state.depth, local: state.local).value }
                let was = own.contains(nil) ? nil : own.reduce(0) { $0 + $1! }
                state.record(NotApplied(origin: clause, reason: .replaced, because: by.because, rulings: e.ruling,
                                        facts: used, via: via, value: was))
                // The clause's value is replaced once, however many derives it holds.
                guard replacedClauses.insert(clause).inserted else { continue }
                let r = value(replace.with, level: by.level, rule: by.effect.origin.rule, depth: state.depth, local: state.local)
                guard computed([r], of: by.effect, used: used, via: via, &state, [replace.with]), let v = r.value else { continue }
                parts.append(Line(value: v, kind: .replaced, origin: clause, via: (via + r.via + [by.ref]).uniqued(),
                                  rulings: (decided(e) + decided(by.effect)).uniqued(), facts: (used + r.used).uniqued(),
                                  was: was, now: v))
                continue
            }
            let results = d.sum.map { value($0, level: level, rule: rule, depth: state.depth, local: state.local) }
            guard computed(results, of: e, used: used, via: via, &state, d.sum) else { continue }
            parts += results.map { r in
                Line(value: r.value!, kind: .base, origin: e.origin.clauseRef, via: (via + r.via).uniqued(),
                     rulings: decided(e), facts: (used + r.used).uniqued())
            }
        }
        guard let first = parts.first else { return }
        // Task 30: a derived Stufe above the rule's highest is that Stufe (COND_1: Turnierrüstung's
        // Belastung 5 is Stufe IV), as a `.capped` part of the base.
        let sum = parts.reduce(0) { $0 + $1.value }
        if let id = q.levelRule, let most = book.rules[id]?.levels, sum > most {
            parts.append(Line(value: most - sum, kind: .capped, note: "höchstens Stufe \(most)", was: sum, now: most))
        }
        state.base = Line(value: parts.reduce(0) { $0 + $1.value }, kind: .base, origin: first.origin,
                          via: parts.flatMap(\.via).uniqued(), rulings: parts.flatMap(\.rulings).uniqued(),
                          facts: parts.flatMap(\.facts).uniqued(), parts: parts)
    }

    /// Ruling R66: the sheet's base keyed `q(with: X)` (`at(with: Rabenschnabel)`) for a query `q`
    /// made with the item X: the piece its `with:` or the action's `with` names, else the
    /// Hauptwaffe. The weapon's own lines (at-pa-modifikatoren.M1, schilde.SCH1) still add.
    private func itemBase(_ q: Query) -> Int? {
        guard q.target.context["with"].map({ situation.base["\(q.name)(with: \($0))"] == nil }) ?? true else { return nil }
        var s = situation
        for (name, value) in combatFacts(of: q) where s.facts[name] == nil {
            s.facts[name] = Fact(name: name, value: value, owner: .derived)
        }
        guard let item = piece(in: s).item else { return nil }
        return situation.base["\(q.name)(with: \(item))"]
    }

    /// R35: the clauses among `derives`' that a firing `suppress` or `replace` names, with it (the
    /// first in compiler order wins). Each suppressed derive that would apply is recorded as
    /// `notApplied(suppressed)`.
    ///
    /// The controlling effect's applicability and level are read as the derives' are: in the
    /// query `level(rule: X)`, X's own suppress counts whether or not X applies, and reads no
    /// level (extra 1: `hero.levelOf.X` and `level(rule: X)` then agree).
    private func baseControl(of derives: [Effect], _ state: inout PipelineState) -> [ClauseRef: Control] {
        let clauses = Set(derives.map(\.origin.clauseRef))
        let levelRule = state.query.levelRule
        var control: [ClauseRef: Control] = [:]
        for e in state.candidates {
            let selector: RuleSelector, replace: Replace?
            switch e.payload {
            case .suppress(let s): (selector, replace) = (s.line, nil)
            case .replace(let r): (selector, replace) = (r.line, r)
            default: continue
            }
            guard selector.kind == .line else { continue }
            let named = selector.ids.compactMap { $0.id.flatMap(ClauseRef.init) }.filter(clauses.contains)
            guard !named.isEmpty, applies(e, &state, ownLevel: levelRule) else { continue }
            let rule = e.origin.rule
            let own = rule == levelRule
            let level = own ? nil : ruleLevel(rule, levels: state.levels, depth: state.depth)
            guard gate(e, level: level, via: own ? [] : ruleVia(rule, state), &state) != nil else { continue }
            for c in named where control[c] == nil { control[c] = Control(effect: e, level: level, replace: replace) }
        }
        for d in derives {
            guard let by = control[d.origin.clauseRef], by.replace == nil,
                  applies(d, &state, ownLevel: levelRule) else { continue }
            // Ruling R68: the entry rests on the suppressor's rulings too.
            state.record(NotApplied(origin: d.origin.clauseRef, reason: .suppressed, because: by.because,
                                    rulings: (d.ruling + decided(by.effect)).uniqued(),
                                    via: [by.ref]))
        }
        return control
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
    /// level. The useLevel's decided rulings go with its clause: every line of the target rule
    /// carries them (Task 30, `carryLevelRulings`).
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
                if target != levelRule, !levelDerives(of: target).isEmpty {
                    state.ask(baseLevel(of: target, depth: state.depth).carried, for: e.origin.clauseRef)
                }
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
                state.levelRulings[target] = (state.levelRulings[target, default: []] + decided(e)).uniqued()
            }
        }
    }

    /// Phase 4, line control: which clauses the firing `suppress`es and `replace`s of this query
    /// act on. Decided before phase 3 computes a line (see `breakdown`), and applied there: a
    /// suppressed `add`, `set` or `tell` gives no line or text and goes to
    /// `notApplied(suppressed)`; a replaced `add` or `set` computes the replacer's `with` in
    /// place of its `value`, before its `per`, keeping its targets and `when` (plan A.3).
    ///
    /// A suppress names clauses (`line`), rules (`rule`) or rule kinds (`ruleKind`: every
    /// condition's lines); a replace names clauses. One naming nothing this query computes from
    /// a rule that applies (or only a derive, which phase 1 handled: R35) is not read, so it
    /// neither asks nor is recorded twice. A second replace of one clause is `overridden`.
    private func linesPhase(_ state: inout PipelineState) {
        // A tell, ask, offer and legality effect acts at depth 0 only (phase 7, `playerParts`).
        let controllable = state.candidates.filter { e in
            switch e.payload {
            case .add, .set: return true
            case .tell, .ask, .offer, .forbid, .require, .limit: return state.depth == 0
            default: return false
            }
        }
        control(controllable, &state)
    }

    /// Phase 4's decision over `controllable`: registers each firing `suppress` and `replace`
    /// among `state.candidates` that names one of them (from a rule that applies) in `state`, for
    /// `isSuppressed` and `swapped` to act on. The lines phase passes a query's value, text,
    /// player and legality effects; the action layer its `cost`s and `gain`s (SA_74.VP1 over
    /// zaubermodifikationen.ZM12, MIGRATION "Notes for the engine tasks").
    func control(_ controllable: [Effect], _ state: inout PipelineState) {
        for e in state.candidates where e.phase == .lines {
            let selector: RuleSelector, replace: Replace?
            switch e.payload {
            case .suppress(let s): (selector, replace) = (s.line, nil)
            case .replace(let r): (selector, replace) = (r.line, r)
            default: continue
            }
            // The cheap tests first: the controlling rule may apply, and it names something here.
            // A rule whose level is unknown goes on to `applies`, which records it and asks.
            switch applicability(of: e.origin.rule, depth: state.depth).status {
            case .applies, .unknownLevel: break
            case .rulesetOff, .silent: continue
            }
            let targets = controllable.filter { selects(selector, effect: $0) }
            guard targets.contains(where: { applicability(of: $0.origin.rule, depth: state.depth).applies }),
                  applies(e, &state) else { continue }
            let rule = e.origin.rule
            let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
            guard gate(e, level: level, via: ruleVia(rule, state), &state) != nil else { continue }
            let control = Control(effect: e, level: level, replace: replace)
            if replace != nil {
                for c in Set(targets.map(\.origin.clauseRef)).sorted(by: { $0.description < $1.description }) {
                    if let first = state.replacements[c] {
                        state.record(NotApplied(origin: control.ref, reason: .overridden, because: first.ref.description,
                                                rulings: e.ruling))
                    } else {
                        state.replacements[c] = control
                    }
                }
                continue
            }
            for id in selector.ids.compactMap(\.id) {
                switch selector.kind {
                case .line: if let c = ClauseRef(id), state.suppressedClauses[c] == nil { state.suppressedClauses[c] = control }
                case .rule: if state.suppressedRules[id] == nil { state.suppressedRules[id] = control }
                case .ruleKind, .lineKind:
                    if let k = RuleKind(rawValue: id), state.suppressedKinds[k] == nil { state.suppressedKinds[k] = control }
                default: break
                }
            }
        }
    }

    /// Phase 3. The applicable `set`s whose `when` is yes apply first: the last in rule-id order
    /// wins, giving a `.set` line of `target − (base + lines so far)`; the others are `overridden`.
    /// Then each `add`: its value, times the fact `per` when given, or that many steps along its
    /// `scale`. Phase 4's control acts here: a suppressed effect is skipped, a replaced one
    /// computes the replacer's value (an `add` then gives a `.replaced` line, `was` its own
    /// amount; a `set` keeps its kind, with the replacer in `via`). Last, the modifiers typed in
    /// for the query (`freeLines`).
    ///
    /// A 3W20 check's attribute stage `check.attribute(index: i)` (spec §6, fertigkeitsproben.FM1)
    /// is the attribute (its base) plus the one shared `check.modifier` of the check: the modifier's
    /// lines come first, as they are, and its questions with them.
    private func addPhase(_ state: inout PipelineState) {
        if state.query.name == "check.attribute" { modifierLines(&state) }
        let effects = state.candidates.filter { $0.phase == .add }
        var sets: [(effect: Effect, value: ValueResult, used: [FactUse], via: [ClauseRef], by: Control?)] = []
        for e in effects {
            guard case .set(let s) = e.payload, applies(e, &state), !isSuppressed(e, &state) else { continue }
            let rule = e.origin.rule
            let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
            let via = ruleVia(rule, state)
            guard let used = gate(e, level: level, via: via, &state) else { continue }
            let (r, by, original) = swapped(s.value, of: e, level: level, state)
            guard computed([r], of: by?.effect ?? e, used: used, via: via, &state, [by?.replace?.with ?? s.value]) else { continue }
            if let by {
                state.record(NotApplied(origin: e.origin.clauseRef, reason: .replaced, because: by.because, rulings: e.ruling,
                                        facts: used, via: via, value: original))
            }
            sets.append((e, r, used, via, by))
        }
        if let winner = sets.last {
            for lost in sets.dropLast() {
                state.record(NotApplied(origin: lost.effect.origin.clauseRef, reason: .overridden,
                                        because: winner.effect.origin.clauseRef.description, rulings: lost.effect.ruling,
                                        facts: (lost.used + lost.value.used).uniqued(), via: lost.via,
                                        value: lost.value.value))
            }
            let before = state.running, now = winner.value.value!
            let replacer = winner.by.map { [$0.ref] } ?? []
            state.lines.append(Line(value: now - before, kind: .set, origin: winner.effect.origin.clauseRef,
                                    via: (winner.via + winner.value.via + replacer).uniqued(),
                                    rulings: (decided(winner.effect) + (winner.by.map { decided($0.effect) } ?? [])
                                              + offerRulings(reading: winner.effect, state)).uniqued(),
                                    facts: (winner.used + winner.value.used).uniqued(), was: before, now: now))
        }
        for e in effects {
            guard case .add(let a) = e.payload, applies(e, &state), !isSuppressed(e, &state) else { continue }
            add(e, a, &state)
        }
        if state.query.name == "check.modifier" { checkModifiers(&state) }
        freeLines(&state)
    }

    /// A `check` effect's `modifier` (spec §6: a rule asking for a check makes it harder) is a line
    /// of the `check.modifier` of the check it names, while its `when` holds: trefferzonen.TZ8's
    /// −1 per full Wundschwelle on the Wundeffekt check, reiterkampf.RK10's −1 per 5 SP of the
    /// mount. Its `via` holds the clauses behind the targets it reads (R26: Eisern behind the
    /// Wundschwelle).
    private func checkModifiers(_ state: inout PipelineState) {
        for e in state.candidates {
            guard case .check(let c) = e.payload, let modifier = c.modifier,
                  namesCheck(c.of, context: state.query.target.context, rule: e.origin.rule, depth: state.depth),
                  applies(e, &state), !isSuppressed(e, &state) else { continue }
            let rule = e.origin.rule
            let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
            let via = ruleVia(rule, state)
            guard let used = gate(e, level: level, via: via, &state) else { continue }
            let r = value(modifier, level: level, rule: rule, depth: state.depth, local: state.local)
            guard computed([r], of: e, used: used, via: via, &state, [modifier]), let v = r.value else { continue }
            state.lines.append(Line(value: v, kind: .add, origin: e.origin.clauseRef, via: (via + r.via).uniqued(),
                                    rulings: decided(e), facts: (used + r.used).uniqued()))
        }
    }

    /// The lines of the check's shared `check.modifier` (its `talent:` / `spell:` context from the
    /// stated `check.kind`, `check.talent`, `check.spell`), evaluated one level deeper.
    private func modifierLines(_ state: inout PipelineState) {
        let modifier = breakdown(Query(TargetRef(name: "check.modifier", context: checkContext)), depth: state.depth + 1)
        if modifier.depthExceeded { state.depthExceeded = true }
        state.lines += modifier.lines
        for q in modifier.questions {
            for origin in q.origins { state.ask([UnknownFact(name: q.fact, owner: q.owner)], for: origin) }
        }
    }

    /// The context of the check the situation states: `spell: X` for a spell check, `talent: X`
    /// for a talent check, none for a liturgy or no check.
    var checkContext: [String: String] {
        let kind = situation.facts["check.kind"]?.value.string
        if kind == "spell" || kind == nil, let spell = situation.facts["check.spell"]?.value.string { return ["spell": spell] }
        if kind == "talent" || kind == nil, let talent = situation.facts["check.talent"]?.value.string { return ["talent": talent] }
        return [:]
    }

    /// One `add`: its value (or its replacer's), times the fact `per` when given, as a line; or
    /// that many steps along its `scale`. A line whose number is a GM-stated fact's value carries
    /// owner `gm` (R49, `gmNumber`): the GM's modifier is the GM's line (fertigkeitsproben.FM2).
    private func add(_ e: Effect, _ a: Add, _ state: inout PipelineState) {
        let rule = e.origin.rule
        let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
        let via = ruleVia(rule, state)
        guard var used = gate(e, level: level, via: via, &state) else { return }
        var times = 1.0
        var perVia: [ClauseRef] = []
        if let per = a.per {
            let f = fact(per, level: level, rule: rule, depth: state.depth, local: state.local)
            guard let use = f.use else {
                state.record(NotApplied(origin: e.origin.clauseRef, reason: .unknownFact, because: e.because,
                                        rulings: e.ruling, facts: used, via: via))
                state.ask(f.unknown, for: e.origin.clauseRef)
                return
            }
            guard let n = use.value.double else {
                fail(e, "\(per) ist keine Zahl", &state)
                return
            }
            used = (used + [use] + f.used).uniqued()
            perVia = f.via
            times = n
            state.ask(carried([per], depth: state.depth), for: e.origin.clauseRef)
        }
        let (r, by, original) = swapped(a.value, of: e, level: level, state)
        guard computed([r], of: by?.effect ?? e, used: used, via: via, &state, [by?.replace?.with ?? a.value]),
              let v = r.value else { return }
        guard let amount = Values.int(Values.round(Double(v) * times, .up)) else {
            fail(e, "\(v) × \(times) liegt außerhalb des Zahlenbereichs", &state)
            return
        }
        let facts = (used + r.used).uniqued()
        if let by {
            guard a.scale == nil else {
                fail(by.effect, "ersetzt eine Stufe auf der Skala \(a.scale!)", &state)
                return
            }
            let was = original.flatMap { Values.int(Values.round(Double($0) * times, .up)) }
            state.record(NotApplied(origin: e.origin.clauseRef, reason: .replaced, because: by.because, rulings: e.ruling,
                                    facts: used, via: via, value: was))
            state.lines.append(Line(value: amount, kind: .replaced, origin: e.origin.clauseRef,
                                    via: (via + r.via + perVia + [by.ref]).uniqued(),
                                    rulings: (decided(e) + decided(by.effect) + offerRulings(reading: e, state)).uniqued(), facts: facts,
                                    was: was, now: amount))
        } else if let scale = a.scale {
            step(e, along: scale, by: amount, via: (via + r.via + perVia).uniqued(), facts: facts, &state)
        } else {
            state.lines.append(Line(value: amount, kind: .add, origin: e.origin.clauseRef,
                                    via: (via + r.via + perVia).uniqued(), rulings: (decided(e) + offerRulings(reading: e, state)).uniqued(),
                                    facts: facts, owner: gmNumber(a.value, r) ? .gm : nil))
        }
    }

    /// R49: whether a value's number is the GM's: a proportion over exactly one fact, that fact
    /// stated by the GM, with no target and no table (`{ of: gmFact.x }`, FM2's
    /// `{ of: 0, above: gmFact.x, times: -1 }`). A table keyed by a GM fact, or a value read from
    /// anyone else's facts, is the rule's number: the facts are in `Line.facts`.
    private func gmNumber(_ value: ValueExpr, _ r: ValueResult) -> Bool {
        guard case .proportion = value, value.factNames.count == 1, value.targets.isEmpty,
              let name = value.factNames.first else { return false }
        return r.used.contains { $0.name == name && $0.owner == .gm }
    }

    /// The value an `add` or `set` computes: its own, or, when phase 4 replaced its clause, the
    /// replacer's `with` at the replacer's level. `original` is then its own value, computed
    /// quietly for `was` (nil when it cannot be: a replaced value asks nothing).
    private func swapped(_ own: ValueExpr, of e: Effect, level: Int?,
                         _ state: PipelineState) -> (result: ValueResult, by: Control?, original: Int?) {
        guard let by = state.replacements[e.origin.clauseRef], let replace = by.replace else {
            return (value(own, level: level, rule: e.origin.rule, depth: state.depth, local: state.local), nil, nil)
        }
        let original = value(own, level: level, rule: e.origin.rule, depth: state.depth, local: state.local).value
        return (value(replace.with, level: by.level, rule: by.effect.origin.rule, depth: state.depth, local: state.local), by, original)
    }

    /// Phase 4 on one effect: when a firing suppress names it (its clause, rule or rule kind), it
    /// goes to `notApplied(suppressed)` with the suppressor as `because` and in `via`, and, for an
    /// `add`, the value its line would have had (computed on a copy of the state: it asks and
    /// records nothing; nil when it would give no line).
    func isSuppressed(_ e: Effect, _ state: inout PipelineState) -> Bool {
        guard let by = state.suppressor(of: e, kind: book.rules[e.origin.rule]?.kind) else { return false }
        var wouldBe: Int?
        if case .add(let a) = e.payload {
            var scratch = state
            scratch.lines = []
            add(e, a, &scratch)
            wouldBe = scratch.lines.first?.value
        }
        // Ruling R68: the entry rests on the suppressor's rulings too.
        state.record(NotApplied(origin: e.origin.clauseRef, reason: .suppressed, because: by.because,
                                rulings: (e.ruling + decided(by.effect)).uniqued(),
                                via: [by.ref], value: wouldBe))
        return true
    }

    /// A modifier typed in for this query (spec §5.5): `choice.freeModifier.<query>`, the
    /// player's, is a `.free` line "frei eingegeben"; `gmFact.modifier.<query>`, the GM's, is an
    /// `.add` line. Each has the fact's owner and the fact. `<query>` is the query as written
    /// (`pa(with: shield)`), else its name (`pa`). A value that is no number is a §11 text.
    private func freeLines(_ state: inout PipelineState) {
        let q = state.query
        let kinds: [(prefix: String, kind: LineKind, note: String)] = [
            ("choice.freeModifier.", .free, "frei eingegeben"), ("gmFact.modifier.", .add, "vom Meister"),
        ]
        for k in kinds {
            guard let f = [q.description, q.name].lazy.compactMap({ self.situation.facts[k.prefix + $0] }).first else { continue }
            guard let n = f.value.double.flatMap({ Values.int(Values.round($0, .up)) }) else {
                state.show(TextLine(kind: .notApplicable,
                                    text: "Regel konnte nicht angewandt werden: \(f.name) – keine Zahl im Zahlenbereich"))
                continue
            }
            state.lines.append(Line(value: n, kind: k.kind,
                                    facts: [FactUse(name: f.name, value: f.value, owner: f.owner)], owner: f.owner,
                                    note: k.note))
        }
    }

    /// Phase 5. Each applicable `multiply` whose `when` is yes scales the lines its `line` names
    /// (base parts included), or without one the value so far. The difference is a `.multiplied`
    /// line: `was` the value before, `now` after, the scaled clauses in `via`.
    ///
    /// Rounding (`round`, default up) rounds the magnitude of the scaled value, keeping its sign:
    /// 15 × ½ = 7.5 → 8 (probe-fernkampf 21.8e), −5 × ½ = −2.5 → −3.
    private func multiplyPhase(_ state: inout PipelineState) {
        for e in state.candidates where e.phase == .multiply {
            guard case .multiply(let m) = e.payload, applies(e, &state) else { continue }
            let rule = e.origin.rule
            let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
            let via = ruleVia(rule, state)
            guard let used = gate(e, level: level, via: via, &state) else { continue }
            let old: Int
            var scaled: [ClauseRef] = []
            if let selector = m.line {
                let named = state.shown.filter { selects(selector, line: $0) }
                guard !named.isEmpty else { continue }                  // nothing of it in this query
                old = named.reduce(0) { $0 + $1.value }
                scaled = named.compactMap(\.origin).uniqued()
            } else {
                guard state.base != nil else { continue }               // no value to scale
                old = state.running
            }
            guard let now = Values.int(Values.round(Double(old) * m.by, m.round ?? .up)) else {
                fail(e, "\(old) × \(m.by) liegt außerhalb des Zahlenbereichs", &state)
                continue
            }
            state.lines.append(Line(value: now - old, kind: .multiplied, origin: e.origin.clauseRef,
                                    via: (via + scaled).uniqued(), rulings: decided(e), facts: used, was: old, now: now))
        }
    }

    /// Phase 6. Each applicable `cap` and `floor` whose `when` is yes bounds a sum, and the
    /// difference is a `.capped` or `.floored` line (`was` the sum, `now` the bounded one); a sum
    /// within the bounds gives none.
    /// - A `cap` with `over` bounds the sum of the `add` lines of the rules it selects
    ///   (`ruleKind: condition`: the −5 Zustand cap, zustaende.Z3). A `set` line is never summed
    ///   (Schmerz IV's GS 0).
    /// - A `cap` without `over`, and a `floor`, bound the value so far.
    private func capPhase(_ state: inout PipelineState) {
        for e in state.candidates where e.phase == .cap {
            let low: ValueExpr?, high: ValueExpr?, over: RuleSelector?, kind: LineKind
            switch e.payload {
            case .cap(let c): (low, high, over, kind) = (c.min, c.max, c.over, .capped)
            case .floor(let f): (low, high, over, kind) = (f.min, nil, nil, .floored)
            default: continue
            }
            guard applies(e, &state) else { continue }
            let rule = e.origin.rule
            let level = ruleLevel(rule, levels: state.levels, depth: state.depth)
            let via = ruleVia(rule, state)
            guard let used = gate(e, level: level, via: via, &state) else { continue }
            let exprs = [low, high].compactMap { $0 }
            let results = exprs.map { value($0, level: level, rule: rule, depth: state.depth, local: state.local) }
            guard computed(results, of: e, used: used, via: via, &state, exprs) else { continue }
            var bounds = results.makeIterator()
            let lo = low != nil ? bounds.next()?.value : nil
            let hi = high != nil ? bounds.next()?.value : nil
            let old: Int
            if let over {
                old = state.lines.filter { $0.kind == .add && selects(over, line: $0) }.reduce(0) { $0 + $1.value }
            } else {
                guard state.base != nil else { continue }               // no value to bound
                old = state.running
            }
            var now = old
            if let lo { now = max(now, lo) }
            if let hi { now = min(now, hi) }
            guard now != old else { continue }
            state.lines.append(Line(value: now - old, kind: kind, origin: e.origin.clauseRef,
                                    via: (via + results.flatMap(\.via)).uniqued(), rulings: decided(e),
                                    facts: (used + results.flatMap(\.used)).uniqued(), was: old, now: now))
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
    /// A rule whose level cannot be known records `unknownFact` and asks the facts behind it, or,
    /// with no fact to ask (a derive that cannot be computed, a cycle, the depth guard), shows
    /// the §11 text. `ownLevel`: in the query `level(rule: X)`, X's derives to its own level
    /// count regardless.
    func applies(_ e: Effect, _ state: inout PipelineState, ownLevel: String? = nil) -> Bool {
        if let ownLevel, e.origin.rule == ownLevel { return true }
        let a = applicability(of: e.origin.rule, depth: state.depth)
        switch a.status {
        case .rulesetOff(let ruleset):
            state.record(NotApplied(origin: e.origin.clauseRef, reason: .rulesetOff,
                                    because: "Regelset \(ruleset) nicht aktiv", rulings: e.ruling))
        case .unknownLevel(let unknown) where unknown.isEmpty:
            fail(e, "die Stufe von \(e.origin.rule) ist nicht berechenbar", &state)
        case .unknownLevel(let unknown):
            state.record(NotApplied(origin: e.origin.clauseRef, reason: .unknownFact,
                                    because: "Stufe von \(e.origin.rule) unbekannt", rulings: e.ruling))
            state.ask(unknown, for: e.origin.clauseRef)
        case .applies:
            state.ask(a.carried, for: e.origin.clauseRef)
        case .silent:
            break
        }
        return a.applies
    }

    /// The clauses every line of `rule` rests on: the require that enabled it, then the useLevels
    /// that acted on it so far.
    func ruleVia(_ rule: String, _ state: PipelineState) -> [ClauseRef] {
        (applicability(of: rule, depth: state.depth).via + (state.levelVia[rule] ?? [])).uniqued()
    }

    /// The effect's `when` (with the query's own facts): the facts it read when it is yes and the
    /// effect rests on no open ruling; else nil, with the reason recorded: no →
    /// `conditionFalse`; an open ruling → `openRuling` and the clause text with the ruling's
    /// question; unknown → `unknownFact` and, when `asking`, one question per unknown fact, with
    /// its owner (a tell changes no number, so it asks nothing).
    func gate(_ e: Effect, level: Int?, via: [ClauseRef], _ state: inout PipelineState,
              asking: Bool = true) -> [FactUse]? {
        let origin = e.origin.clauseRef
        var r = ConditionResult(truth: .yes)
        if let when = e.when {
            r = condition(when, level: level, rule: e.origin.rule, depth: state.depth, local: state.local)
            // R38: a derived level read here brings the questions that could change it.
            if asking { state.ask(carried(when.factNames, depth: state.depth), for: origin) }
        }
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
            if asking { state.ask(r.unknown, for: origin) }
            for name in (e.when?.factNames ?? []).sorted() {
                if let why = undecidable["\(e.origin.rule):\(name)"] { fail(e, "\(name): \(why)", &state) }
            }
            return nil
        }
        return r.used
    }

    /// Whether every value of an effect was computed. When one was not: its unknown facts give
    /// `unknownFact` and questions; the depth guard or anything else gives a text "Regel konnte
    /// nicht angewandt werden" (spec §11), naming a table without the row when `exprs` (the
    /// values, in the order of `results`) says so. A computed value that read an operand with
    /// open questions asks them too.
    func computed(_ results: [ValueResult], of e: Effect, used: [FactUse], via: [ClauseRef],
                  _ state: inout PipelineState, _ exprs: [ValueExpr] = []) -> Bool {
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
                let table = zip(exprs, results).lazy.compactMap { x, r -> String? in
                    guard r.value == nil, case .table(let name, let key) = x else { return nil }
                    return "die Tabelle \(name) hat keinen Eintrag für \(key)"
                }.first
                fail(e, table ?? "Wert nicht berechenbar", &state)
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

    func fail(_ e: Effect, _ reason: String, _ state: inout PipelineState) {
        let origin = e.origin.clauseRef
        state.show(TextLine(kind: .notApplicable, text: "Regel konnte nicht angewandt werden: \(origin) – \(reason)",
                            origin: origin))
    }

    /// The decided rulings an applied effect rests on (an unknown id counts as decided: rulec
    /// checks every id).
    func decided(_ e: Effect) -> [String] {
        e.ruling.filter { book.rulings[$0]?.status != .open }
    }

    /// A clause's text, without the line break a YAML block leaves at its end.
    func clauseText(_ ref: ClauseRef) -> String? {
        book.rules[ref.rule]?.clauses.first { $0.id == ref.clause }?.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether `selector` (of a suppress or replace) names the effect: its clause (`line`), its
    /// rule (`rule`), or its rule's kind (`ruleKind`; a `lineKind` naming a rule kind the same).
    func selects(_ selector: RuleSelector, effect e: Effect) -> Bool {
        selects(selector, clause: e.origin.clauseRef)
    }

    /// Whether `selector` (of a multiply or cap) names the line: as `selects(_:effect:)` by the
    /// line's origin, or a `lineKind` naming the line's kind. The sheet's lines have no origin.
    func selects(_ selector: RuleSelector, line: Line) -> Bool {
        if selector.kind == .lineKind, selector.ids.contains(where: { $0.id == line.kind.rawValue }) { return true }
        guard let origin = line.origin else { return false }
        return selects(selector, clause: origin)
    }

    private func selects(_ selector: RuleSelector, clause: ClauseRef) -> Bool {
        let ids = selector.ids.compactMap(\.id)
        switch selector.kind {
        case .line: return ids.contains(clause.description)
        case .rule: return ids.contains(clause.rule)
        case .ruleKind, .lineKind: return book.rules[clause.rule].map { ids.contains($0.kind.rawValue) } ?? false
        default: return false
        }
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
