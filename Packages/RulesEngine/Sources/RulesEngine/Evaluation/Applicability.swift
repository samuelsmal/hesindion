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
    /// The `require { enables: true }` clause that made the rule apply, or the clauses whose
    /// derives gave its level (Task 30); its lines carry them in `via`.
    var via: [ClauseRef] = []
    /// A rule that applies by its derived level: the questions that could change that level
    /// (R38, `BaseLevel.carried`); every effect of the rule asks them.
    var carried: [UnknownFact] = []

    static let silent = Applicability(status: .silent)
    var applies: Bool { status == .applies }
}

/// A rule's level before any useLevel: the base phase of `level(rule: X)` (R34).
struct BaseLevel: Hashable {
    /// nil when a derive that gives it lacks a fact (or its operand hit the depth guard).
    var value: Int?
    /// The facts whose absence keeps `value` nil.
    var unknown: [UnknownFact]
    /// A known level: the questions its operands brought along (LE's open `when`s under
    /// Schmerz), which could change it. It keeps its value; whoever reads it asks them (R38).
    var carried: [UnknownFact] = []
    /// The clauses whose derives gave it (Task 30): a rule that applies by it rests on them.
    var via: [ClauseRef] = []
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
    /// - it is `equipment` and a `loadout.*` fact names an item whose template is the rule
    ///   (`item.<name>.template`, else the equipment rule of that name: Task 30), or
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
            if let v = level.value, v > 0 { return Applicability(status: .applies, via: level.via, carried: level.carried) }
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
            return book.template(ofItem: item, in: situation) == id
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
    ///
    /// The level is known only when nothing could still change it: no base-phase effect (a
    /// derive, or a suppress or replace of one) is left undecided for want of a fact (its
    /// `when`, its value), no derive failed (a notApplicable text) and nothing hit the depth
    /// guard. Otherwise it is nil, with the facts those effects ask for, or with none when a
    /// derive could not be computed at all (the caller shows a §11 text). A question an operand
    /// brings along while its value was computed (LE's own open `when`s under Schmerz) does not
    /// make the level unknown.
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
        let open = Set(b.notApplied.filter { $0.reason == .unknownFact }.map(\.origin))
        let failed = b.depthExceeded || b.texts.contains { $0.kind == .notApplicable }
        if open.isEmpty && !failed {
            let derives = (b.base.map { $0.parts.isEmpty ? [$0] : $0.parts } ?? []).compactMap(\.origin).uniqued()
            level = BaseLevel(value: b.base?.value ?? situation.owned[id]?.level ?? 0, unknown: [],
                              carried: b.questions.map { UnknownFact(name: $0.fact, owner: $0.owner) }, via: derives)
        } else {
            level = BaseLevel(value: nil, unknown: b.questions.filter { !open.isDisjoint(with: $0.origins) }
                .map { UnknownFact(name: $0.fact, owner: $0.owner) })
        }
        baseLevelMemo[id] = final ? .done(level) : nil
        return level
    }

    // MARK: - Derived facts

    /// `situation` with the derived facts `names` needs stated, and for each one that stays
    /// unknown, the facts behind it: a question asks for those, not for the derived fact.
    /// - `local`: the query's own facts (`query.target`, and `query.result` in the legality
    ///   phase), which the query states whatever the situation says.
    /// - `hero.levelOf.X`: the base phase of `level(rule: X)` (R34).
    /// - `fw.current`: the FW of the check's spell (`check.spell`), else of its talent
    ///   (`check.talent`): MIGRATION probe-magie 20.1.
    /// - `ladezeit.current` (`targetFacts`): the result of the query `item.ladezeit`.
    /// - `choice.<id>` (Task 30, R61): unstated, the `default` the choice's offers state, when
    ///   they state one and agree (reiterkampf.RK6's `jumpOff: false`); the player's.
    /// - `hero.conditionLevels` (Task 30, zustaende.Z5): the sum of every condition's
    ///   `hero.levelOf`, the Stufen the hero has before any useLevel; unknown while one of them is.
    /// - `belastung.source` (Task 30): `armour` while the hero wears an armour (`loadout.armour`
    ///   names one), the one source of Belastung the rules encode; unknown without a stated armour
    ///   (asking for `loadout.armour`), and with none worn.
    /// - `check.onOption` / `check.applicationOnOption` (MIGRATION ADV_4.B1, SA_9.FS1; plan Task
    ///   26): read by `rule`, from the instance the hero owns: its `option` against the check's
    ///   `check.spell` / `check.talent`, its `option2` against `check.application`. An unknown
    ///   check subject asks for `check.talent`; an unknown Anwendungsgebiet asks the player for
    ///   `check.application`. One that is stated but cannot be compared (an application id against
    ///   a name) stays unknown and asks nothing: `gate` shows a text "… nicht vergleichbar". A rule
    ///   with no owned option cannot say: unknown, nobody asked.
    func prepared(_ names: Set<String>, depth: Int, local: [String: Fact] = [:],
                  rule: String? = nil) -> (situation: Situation, behind: [String: [UnknownFact]]) {
        let p = prepare(names, depth: depth, local: local, rule: rule)
        return (p.situation, p.behind)
    }

    /// `prepared`, with what each derived loadout fact rests on (`Loadout.swift`): the facts it
    /// read and the clauses behind it, which a value reading it carries.
    func prepare(_ names: Set<String>, depth: Int, local: [String: Fact] = [:],
                 rule: String? = nil) -> (situation: Situation, behind: [String: [UnknownFact]], sources: [String: Derived]) {
        let prefix = "hero.levelOf."
        var s = situation
        var behind: [String: [UnknownFact]] = [:]
        for (name, f) in local where names.contains(name) { s.facts[name] = f }
        let owned = rule.flatMap { situation.owned[$0] }
        func option(_ name: String, _ mine: JSONValue?, against checkFact: JSONValue?, asking: String) {
            guard names.contains(name), s.facts[name] == nil else { return }
            guard let mine else {
                s.unstated.insert(name)
                behind[name] = []
                return
            }
            if let checkFact, let same = Self.sameOption(mine, checkFact) {
                s.facts[name] = Fact(name: name, value: .bool(same), owner: .derived)
            } else if let checkFact {
                // Stated but not comparable (an application id against its name): asking again
                // cannot help. `gate` shows why.
                s.unstated.insert(name)
                behind[name] = []
                if let rule { undecidable["\(rule):\(name)"] = "\(mine) und \(checkFact) sind nicht vergleichbar" }
            } else {
                s.unstated.insert(name)
                behind[name] = [UnknownFact(asking)]
            }
        }
        option("check.onOption", owned?.option, against: (s.facts["check.spell"] ?? s.facts["check.talent"])?.value,
               asking: "check.talent")
        option("check.applicationOnOption", owned?.option2, against: s.facts["check.application"]?.value,
               asking: "check.application")
        if names.contains("fw.current"), s.facts["fw.current"] == nil {
            let subject = (s.facts["check.spell"] ?? s.facts["check.talent"])?.value.string
            if let subject, let fw = s.facts["fw.\(subject)"] {
                s.facts["fw.current"] = Fact(name: "fw.current", value: fw.value, owner: .derived)
            } else {
                s.unstated.insert("fw.current")
                behind["fw.current"] = [UnknownFact(subject.map { "fw.\($0)" } ?? "check.spell")]
            }
        }
        for name in names.sorted() where name.hasPrefix("choice.") && s.facts[name] == nil {
            // Task 30 (R61): a choice nobody made reads the default its offer states.
            if let d = choiceDefaults[String(name.dropFirst("choice.".count))] {
                s.facts[name] = Fact(name: name, value: d, owner: .player)
            }
        }
        var sources: [String: Derived] = [:]
        // Task 30: the loadout facts the sheet derives (`Loadout.swift`), which read the query's
        // own facts (the piece its `with:` names) as well.
        let withLocal = local.values.reduce(into: s) { $0.facts[$1.name] = $0.facts[$1.name] ?? $1 }
        for name in names.sorted() where Self.isLoadoutFact(name) && s.fact(name) == nil {
            let d = loadoutFact(name, in: withLocal)
            if let v = d.value {
                s.facts[name] = Fact(name: name, value: v, owner: .derived)
                sources[name] = d
            } else {
                s.unstated.insert(name)
                behind[name] = d.unknown
            }
        }
        if names.contains("hero.conditionLevels"), s.facts["hero.conditionLevels"] == nil {
            // Task 30 (zustaende.Z5): the Stufen of every Zustand the hero has, each as
            // `hero.levelOf` gives it, before any useLevel (ADV_49.zaeher-hund-counts).
            var sum = 0, lacking: [UnknownFact] = [], known = true
            for id in book.rules.keys.sorted() where book.rules[id]!.kind == .condition {
                guard situation.owned[id] != nil || !levelDerives(of: id).isEmpty
                        || situation.base[Self.levelQuery(id).description] != nil else { continue }
                if let v = baseLevel(of: id, depth: depth).value { sum += max(0, v) } else {
                    known = false
                    lacking += baseLevel(of: id, depth: depth).unknown
                }
            }
            if known {
                s.facts["hero.conditionLevels"] = Fact(name: "hero.conditionLevels", value: .int(sum), owner: .derived)
            } else {
                s.unstated.insert("hero.conditionLevels")
                behind["hero.conditionLevels"] = lacking.uniqued()
            }
        }
        if names.contains("belastung.source"), s.facts["belastung.source"] == nil {
            // Task 30: armour is the one source of Belastung the rules encode
            // (ruestung-und-belastung.A1; the Traglast, COND_1.B2, is not written).
            switch s.facts["loadout.armour"]?.value {
            case .string?:
                s.facts["belastung.source"] = Fact(name: "belastung.source", value: .string("armour"), owner: .derived)
            case nil:
                s.unstated.insert("belastung.source")
                behind["belastung.source"] = [UnknownFact("loadout.armour")]
            default:
                // No armour worn: nothing says where a Belastung would come from.
                s.unstated.insert("belastung.source")
                behind["belastung.source"] = []
            }
        }
        for (name, target) in Self.targetFacts.sorted(by: { $0.key < $1.key }) where names.contains(name) && s.facts[name] == nil {
            let r = resolve(TargetRef(target), depth: depth + 1)
            if let v = r.value {
                s.facts[name] = Fact(name: name, value: .int(v), owner: .derived)
            } else {
                s.unstated.insert(name)
                behind[name] = r.unknown
            }
        }
        for name in names.sorted() where name.hasPrefix(prefix) && name.count > prefix.count && s.facts[name] == nil {
            let level = baseLevel(of: String(name.dropFirst(prefix.count)), depth: depth)
            if let v = level.value {
                s.facts[name] = Fact(name: name, value: .int(v), owner: .derived)
            } else {
                s.unstated.insert(name)
                if !level.unknown.isEmpty { behind[name] = level.unknown }
            }
        }
        return (s, behind, sources)
    }

    /// The derived facts that are a target's result (MIGRATION probe-fernkampf): `ladezeit.current`
    /// is the query `item.ladezeit` for the weapon in hand, after every rule (SA_60's −1 or
    /// halving), for LZ2's `when`. Unknown when the target has no result; its questions are asked.
    static let targetFacts: [String: String] = ["ladezeit.current": "item.ladezeit"]

    /// Whether a rule's option names the check's: two strings or two numbers compare; a number
    /// against a string (an Anwendungsgebiet's id against its name) cannot be told: nil.
    static func sameOption(_ a: JSONValue, _ b: JSONValue) -> Bool? {
        if let x = a.string, let y = b.string { return x == y }
        if let x = a.double, let y = b.double { return x == y }
        return nil
    }

    /// The questions carried by the derived levels among `names` that are not stated
    /// (`hero.levelOf.X`, R38).
    func carried(_ names: Set<String>, depth: Int) -> [UnknownFact] {
        let prefix = "hero.levelOf."
        return names.sorted().filter { $0.hasPrefix(prefix) && $0.count > prefix.count && situation.facts[$0] == nil }
            .flatMap { baseLevel(of: String($0.dropFirst(prefix.count)), depth: depth).carried }.uniqued()
    }

    /// Evaluates `when` with the derived facts it reads and the query's own (`local`).
    func condition(_ c: Condition, level: Int?, rule: String, depth: Int, local: [String: Fact] = [:]) -> ConditionResult {
        let (s, behind) = prepared(c.factNames, depth: depth, local: local, rule: rule)
        var r = Conditions.evaluate(c, in: s, level: level, rule: rule)
        r.unknown = r.unknown.flatMap { behind[$0.name] ?? [$0] }.uniqued()
        return r
    }

    /// Evaluates a value with the derived facts it reads; a target operand runs its own query one
    /// level deeper, at the depth `Values` passes on.
    /// A derived loadout fact read carries what it rests on (Task 30): the facts it read join
    /// `used`, its clauses (the equipment row, the Leiteigenschaft table) `via`.
    func value(_ v: ValueExpr, level: Int?, rule: String, depth: Int, local: [String: Fact] = [:]) -> ValueResult {
        let (s, behind, sources) = prepare(v.factNames, depth: depth, local: local, rule: rule)
        var r = Values.evaluate(v, level: level, in: s, book: book, rule: rule, depth: depth) { [unowned self] target, d in
            self.resolve(target, depth: d)
        }
        r.unknown = (r.unknown.flatMap { behind[$0.name] ?? [$0] } + carried(v.factNames, depth: depth)).uniqued()
        for name in v.factNames.sorted() {
            guard let d = sources[name], r.used.contains(where: { $0.name == name }) else { continue }
            r.used = (r.used + d.used).uniqued()
            r.via = (r.via + d.via).uniqued()
        }
        return r
    }

    /// A fact read directly (`add.per`), with the derived facts it may be, and what a derived
    /// loadout fact rests on.
    func fact(_ name: String, level: Int?, rule: String, depth: Int,
              local: [String: Fact] = [:]) -> (use: FactUse?, unknown: [UnknownFact], used: [FactUse], via: [ClauseRef]) {
        let (s, behind, sources) = prepare([name], depth: depth, local: local, rule: rule)
        if let use = s.fact(name, level: level, rule: rule) { return (use, [], sources[name]?.used ?? [], sources[name]?.via ?? []) }
        return (nil, behind[name] ?? [UnknownFact(name)], [], [])
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
