import Foundation

// Which rules apply to the hero, at which level, and the derived facts that need the evaluator
// (`hero.levelOf.X`, R34). Every answer is memoized in the `Evaluation` of one `evaluate` call.

/// Whether a rule applies to the hero.
struct Applicability: Hashable {
    enum Status: Hashable {
        case applies
        /// A core rule whose ruleset is not among the fact `rulesets`: its effects go to
        /// `notApplied` with `rulesetOff`.
        case rulesetOff(String)
        /// A levelled rule whose derived level cannot be computed for want of these facts: it may
        /// apply, so its effects go to `notApplied(unknownFact)` and the facts are asked (§4.6).
        case unknownLevel([UnknownFact])
        /// Neither owned, nor for everyone, nor enabled: its effects are not mentioned at all.
        case silent
    }

    var status: Status
    /// The `require { enables: true }` clause that made the rule apply; its lines carry it in `via`.
    var via: [ClauseRef] = []

    static let silent = Applicability(status: .silent)
    var applies: Bool { status == .applies }
}

/// A rule's level before any useLevel: the base phase of `level(rule: X)` (R34).
struct BaseLevel: Hashable {
    /// nil when a derive that gives it lacks a fact (or its operand hit the depth guard).
    var value: Int?
    /// The facts whose absence keeps `value` nil.
    var unknown: [UnknownFact]
}

/// A memo entry: `computing` breaks a cycle (a rule whose applicability needs itself does not apply).
enum Memo<T> {
    case computing
    case done(T)
}

extension Evaluation {
    // MARK: - Applicability

    /// A rule applies when (spec §5, plan Task 22):
    /// - the hero owns it (`owned` covers conditions, states, abilities, advantages, disadvantages
    ///   and creatures), or
    /// - it is `core` and its `ruleset` (if any) is in the fact `rulesets`, or
    /// - it is `equipment` and a `loadout.*` fact names an item whose `item.<name>.template` is
    ///   the rule, or
    /// - it is a `talent` and the fact `check.talent` is the rule, or
    /// - it has a level (`level(rule: X)` derives to it) and that level is above 0 (Schmerz from
    ///   LE, Belastung from armour), or
    /// - a `require { enables: true }` whose `when` and `that` are yes enables it: the rule holding
    ///   the require (it needs no other reason), or the rules its `for: { rule: … }` names (the
    ///   holder must apply). Its lines then carry the require's clause in `via`.
    ///
    /// A rule is owned once, at one level: several instances (Begabung for two talents) are a
    /// known gap.
    ///
    /// Not memoized when its computation met the depth guard or a cycle through another open
    /// entry (`settle`).
    func applicability(of id: String, depth: Int) -> Applicability {
        let key = "applies:" + id
        switch applicabilityMemo[id] {
        case .done(let a): return a
        case .computing:
            cycleHits[key, default: 0] += 1
            return .silent
        case nil: break
        }
        applicabilityMemo[id] = .computing
        let (a, final) = settle(key) { computeApplicability(of: id, depth: depth) }
        applicabilityMemo[id] = final ? .done(a) : nil
        return a
    }

    private func computeApplicability(of id: String, depth: Int) -> Applicability {
        guard let rule = book.rules[id] else { return .silent }
        let applies = Applicability(status: .applies)
        if situation.owned[id] != nil { return applies }
        switch rule.kind {
        case .core where rulesetIsOn(rule): return applies
        case .equipment where isEquipped(id): return applies
        case .talent where situation.facts["check.talent"]?.value == .string(id): return applies
        default: break
        }
        var derived: BaseLevel?
        if !levelDerives(of: id).isEmpty {
            let level = baseLevel(of: id, depth: depth)
            if let v = level.value, v > 0 { return applies }
            derived = level
        }
        if let via = enablingRequire(of: id, depth: depth) {
            return Applicability(status: .applies, via: [via])
        }
        if let derived, derived.value == nil { return Applicability(status: .unknownLevel(derived.unknown)) }
        if rule.kind == .core, let ruleset = rule.ruleset { return Applicability(status: .rulesetOff(ruleset)) }
        return .silent
    }

    /// No ruleset, or one the fact `rulesets` lists. An unknown `rulesets` lists none.
    private func rulesetIsOn(_ rule: Rule) -> Bool {
        guard let ruleset = rule.ruleset else { return true }
        switch situation.facts["rulesets"]?.value {
        case .array(let on)?: return on.contains(.string(ruleset))
        case .string(let on)?: return on == ruleset
        default: return false
        }
    }

    /// A `loadout.*` fact names an item whose template is `id`.
    private func isEquipped(_ id: String) -> Bool {
        situation.facts.values.contains { f in
            guard f.name.hasPrefix("loadout."), let item = f.value.string else { return false }
            return situation.facts["item.\(item).template"]?.value == .string(id)
        }
    }

    /// The clause of the first `require { enables: true }` (rule-id and clause order) that enables
    /// `id` in this situation.
    private func enablingRequire(of id: String, depth: Int) -> ClauseRef? {
        for (effect, require) in enablers {
            let holder = effect.origin.rule
            let targets = require.for.map { $0.kind == .rule ? $0.ids.compactMap(\.id) : [] } ?? [holder]
            guard targets.contains(id) else { continue }
            if holder != id, !applicability(of: holder, depth: depth).applies { continue }
            let level = ruleLevel(holder, levels: [:], depth: depth)
            if let when = effect.when, condition(when, level: level, rule: holder, depth: depth).truth != .yes { continue }
            guard condition(require.that, level: level, rule: holder, depth: depth).truth == .yes else { continue }
            return effect.origin.clauseRef
        }
        return nil
    }

    // MARK: - Levels

    /// The derives to `level(rule: id)`, in the compiler's order.
    func levelDerives(of id: String) -> [Effect] { levelDerivesByRule[id] ?? [] }

    /// The level `id`'s effects read: after the useLevels of this query (`levels`), else the base
    /// phase of `level(rule: id)` (R34) for a rule the hero owns, the sheet states a level for, or
    /// one whose level derives. nil for any other rule (a core rule has no level).
    func ruleLevel(_ id: String, levels: [String: Int], depth: Int) -> Int? {
        if let l = levels[id] { return l }
        let stated = situation.base[Self.levelQuery(id).description] != nil
        guard situation.owned[id] != nil || stated || !levelDerives(of: id).isEmpty else { return nil }
        return baseLevel(of: id, depth: depth).value
    }

    static func levelQuery(_ id: String) -> Query { Query(TargetRef(name: "level", context: ["rule": id])) }

    /// `hero.levelOf.id`: the base-phase result of `level(rule: id)`, before any useLevel. With no
    /// stated base, no owned level and no derive, it is 0 (the sheet is complete).
    func baseLevel(of id: String, depth: Int) -> BaseLevel {
        let key = "levelOf:" + id
        switch baseLevelMemo[id] {
        case .done(let l): return l
        case .computing:
            cycleHits[key, default: 0] += 1
            return BaseLevel(value: nil, unknown: [])
        case nil: break
        }
        baseLevelMemo[id] = .computing
        let (b, final) = settle(key) { breakdown(Self.levelQuery(id), depth: depth + 1, through: .base) }
        let level: BaseLevel
        if let base = b.base {
            level = BaseLevel(value: base.value, unknown: [])
        } else if b.questions.isEmpty && !b.depthExceeded && !b.texts.contains(where: { $0.kind == .notApplicable }) {
            level = BaseLevel(value: situation.owned[id]?.level ?? 0, unknown: [])
        } else {
            level = BaseLevel(value: nil, unknown: b.questions.map { UnknownFact(name: $0.fact, owner: $0.owner) })
        }
        baseLevelMemo[id] = final ? .done(level) : nil
        return level
    }

    // MARK: - Derived facts

    /// `situation` with the derived facts `names` needs stated (`hero.levelOf.X`, from the base
    /// phase of `level(rule: X)`), and for each one that stays unknown, the facts behind it: a
    /// question asks for those, not for the derived fact.
    func prepared(_ names: Set<String>, depth: Int) -> (situation: Situation, behind: [String: [UnknownFact]]) {
        let prefix = "hero.levelOf."
        var s = situation
        var behind: [String: [UnknownFact]] = [:]
        for name in names.sorted() where name.hasPrefix(prefix) && name.count > prefix.count && s.facts[name] == nil {
            let level = baseLevel(of: String(name.dropFirst(prefix.count)), depth: depth)
            if let v = level.value {
                s.facts[name] = Fact(name: name, value: .int(v), owner: .derived)
            } else {
                s.unstated.insert(name)
                if !level.unknown.isEmpty { behind[name] = level.unknown }
            }
        }
        return (s, behind)
    }

    /// Evaluates `when` with the derived facts it reads.
    func condition(_ c: Condition, level: Int?, rule: String, depth: Int) -> ConditionResult {
        let (s, behind) = prepared(c.factNames, depth: depth)
        var r = Conditions.evaluate(c, in: s, level: level, rule: rule)
        r.unknown = r.unknown.flatMap { behind[$0.name] ?? [$0] }.uniqued()
        return r
    }

    /// Evaluates a value with the derived facts it reads; a target operand runs its own query one
    /// level deeper, at the depth `Values` passes on.
    func value(_ v: ValueExpr, level: Int?, rule: String, depth: Int) -> ValueResult {
        let (s, behind) = prepared(v.factNames, depth: depth)
        var r = Values.evaluate(v, level: level, in: s, book: book, rule: rule, depth: depth) { [unowned self] target, d in
            self.resolve(target, depth: d)
        }
        r.unknown = r.unknown.flatMap { behind[$0.name] ?? [$0] }.uniqued()
        return r
    }

    /// A fact read directly (`add.per`), with the derived facts it may be.
    func fact(_ name: String, level: Int?, rule: String, depth: Int) -> (use: FactUse?, unknown: [UnknownFact]) {
        let (s, behind) = prepared([name], depth: depth)
        if let use = s.fact(name, level: level, rule: rule) { return (use, []) }
        return (nil, behind[name] ?? [UnknownFact(name)])
    }

    /// An operand target, as its own query at `depth` (R26): its result, the clauses behind it
    /// (the clauses that set its base, then every later line's origin, each once), the facts it
    /// read and the ones it lacked.
    ///
    /// Memoized for the rest of the call once computed without hitting the depth guard; a target
    /// still being computed is not in the memo, so a target that reads itself recurses until the
    /// guard stops it.
    func resolve(_ target: TargetRef, depth: Int) -> ResolvedTarget {
        let query = Query(target)
        if let known = operandMemo[query.description] { return known }
        let (b, final) = settle(nil) { breakdown(query, depth: depth) }
        var contributors: [ClauseRef] = []
        for line in (b.base?.parts ?? []) + b.lines {
            if let o = line.origin, !contributors.contains(o) { contributors.append(o) }
        }
        let read = ((b.base.map { [$0] + $0.parts } ?? []) + b.lines).flatMap(\.facts).uniqued()
        let resolved = ResolvedTarget(value: b.result, contributors: contributors, used: read,
                                      unknown: b.questions.map { UnknownFact(name: $0.fact, owner: $0.owner) },
                                      depthExceeded: b.depthExceeded)
        if final && !b.depthExceeded { operandMemo[query.description] = resolved }
        return resolved
    }
}

// MARK: - The facts a form reads

extension Condition {
    var factNames: Set<String> {
        switch self {
        case .all(let cs), .any(let cs): cs.reduce(into: Set()) { $0.formUnion($1.factNames) }
        case .not(let c): c.factNames
        case .fact(let name, _): [name]
        }
    }
}

extension ValueExpr {
    var factNames: Set<String> {
        switch self {
        case .number, .level: []
        case .proportion(let p):
            [p.of, p.per, p.above].reduce(into: Set()) { $0.formUnion($1.factNames) }
                .union(p.min?.factNames ?? []).union(p.max?.factNames ?? [])
        case .table(_, let key): [key]
        }
    }
}

extension Operand {
    var factNames: Set<String> {
        switch self {
        case .number, .target: []
        case .fact(let f): [f]
        case .sum(let os): os.reduce(into: Set()) { $0.formUnion($1.factNames) }
        }
    }
}

extension Bound {
    var factNames: Set<String> {
        switch self {
        case .number: []
        case .operand(let o): o.factNames
        case .each(let os): os.reduce(into: Set()) { $0.formUnion($1.factNames) }
        }
    }
}
