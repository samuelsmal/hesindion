import Foundation

// The consequence of a hit (spec §6 `consequence`): TP → RS → SP → the Wundschwelle comparison →
// the Wundeffekt check. Each is a target with its own lines, and every number comes from the
// rules: the chain states the hit, runs the rules' queries and reads their results into the
// derived `hit.*` facts, and asks the rules which checks the hit calls for. It computes nothing of
// its own.

/// A check a rule asks for (a `check` effect whose `when` held): the Wundeffekt's
/// Selbstbeherrschung (trefferzonen.TZ8), the rider's Reiten when the mount is hit
/// (reiterkampf.RK10). It is the caller's to run (`CheckProcedure`, the Probe's attributes are the
/// caller's): `request(attributes:)`, started in `situation`. Its `onSuccess` / `onFailure` run at
/// the check's confirm (the zone's Wundeffekt, `gain` through the action layer).
public struct PendingCheck: Hashable, Sendable {
    /// The clause holding the `check` effect.
    public var origin: ClauseRef
    public var kind: CheckKind
    /// The talent or spell (`TAL_8`).
    public var id: String
    /// The Anwendungsgebiet its `with` names (a `table(…)` form looked up: TZ11's by zone); nil
    /// without one, or while the key is unknown.
    public var application: String?
    public var onSuccess: [Effect]
    public var onFailure: [Effect]
    /// The situation the check was asked in: the hit with its derived facts. Its `when` and its
    /// `modifier` (a line of the check's `check.modifier`) are read there.
    public var situation: Situation
    public var rulings: [String]
    /// The clauses its rule rests on (an enabling require, the useLevels on it).
    public var via: [ClauseRef]
    /// The facts its `when` read.
    public var facts: [FactUse]

    public init(origin: ClauseRef, kind: CheckKind, id: String, application: String?, onSuccess: [Effect],
                onFailure: [Effect], situation: Situation, rulings: [String] = [], via: [ClauseRef] = [],
                facts: [FactUse] = []) {
        self.origin = origin; self.kind = kind; self.id = id; self.application = application
        self.onSuccess = onSuccess; self.onFailure = onFailure; self.situation = situation
        self.rulings = rulings; self.via = via; self.facts = facts
    }

    /// The check to start, with the Probe's attributes (`MU`, `MU`, `KO`).
    public func request(attributes: [String]) -> CheckRequest {
        CheckRequest(kind: kind, id: id, attributes: attributes, application: application)
    }
}

/// What a hit gives: its stages, the situation it leaves, and the checks it calls for.
public struct DamageResult: Hashable, Sendable {
    /// The TP: the hit's input (`hit.tp`, owner roll). nil when the hit states none (a situation
    /// that states the SP after RS instead).
    public var tp: Breakdown?
    /// `rs`, the RS schaden.S1 subtracts: the sheet's, or with Trefferzonen-Rüstungsschutz the
    /// zone's (trefferzonen-ruestungsschutz.RS2 sets it to `hit.zoneRs`).
    public var rs: Breakdown
    /// `sp`: schaden.S1's derive (TP − RS) and floor, or the sheet's SP.
    public var sp: Breakdown
    /// `wundschwelle`: trefferzonen.TZ8's derive and the lines on it (Eisern).
    public var wundschwelle: Breakdown
    /// `leCurrent`: the LE after the hit, schaden.S2's line (−SP). No event applies it: §7 has no
    /// event for damage (`paid` is not damage); the caller writes this result into the LE.
    public var leCurrent: Breakdown
    /// The hit's situation: `hit.tp`, `hit.zone`, `hit.side` as given, and the derived facts the
    /// chain read from the rules (`derived`).
    public var situation: Situation
    /// `hit.sp` (the `sp` result), `hit.overWundschwelle` (the count trefferzonen.TZ8's proportion
    /// defines), `hit.zoneRs` (the zone's `rs`, where a rule that applies reads it).
    public var derived: [FactUse]
    /// The checks the hit calls for: every `check` effect reading a `hit.*` fact whose rule applies
    /// and whose `when` holds.
    public var checks: [PendingCheck]
    public var questions: [Question]
    public var texts: [TextLine]
    /// Every entry of the stages, and the hit's checks that did not come (trefferzonen.TZ8
    /// `conditionFalse` below the Wundschwelle, `rulesetOff` without the Fokusregel).
    public var notApplied: [NotApplied]

    /// The stages in order: TP (when given), RS, SP, Wundschwelle, LE.
    public var breakdowns: [Breakdown] { [tp].compactMap { $0 } + [rs, sp, wundschwelle, leCurrent] }
}

public enum DamageChain {
    /// The derived facts the chain states, in the order it states them.
    static let derivedFacts = ["hit.zoneRs", "hit.sp", "hit.overWundschwelle"]

    /// Runs the chain for a hit of `tp` TP (nil: the situation's `hit.tp`, or its stated SP) on
    /// `zone` / `side` (nil: the situation's `hit.zone` / `hit.side`).
    ///
    /// 1. States the hit: `hit.tp`, `hit.zone`, `hit.side` (roll).
    /// 2. `hit.zoneRs`, where a rule that applies reads it: the `rs(zone: …)` the book names for
    ///    the zone hit (`kopf`, `torso`; an arm or leg with its side, `armRechts`).
    /// 3. The stages `rs` and `sp` (schaden.S1: TP − RS, floored at 0), then `hit.sp`.
    /// 4. `wundschwelle`, then `hit.overWundschwelle`: the magnitude of the proportion over `hit.sp`
    ///    that a rule reading `hit.overWundschwelle` holds (trefferzonen.TZ8's check modifier,
    ///    ⌊SP / Wundschwelle⌋).
    /// 5. The checks the hit calls for: each `check` effect whose `when` or `modifier` reads a
    ///    `hit.*` fact, read as the pipeline reads an effect (its rule applies, no suppress, its
    ///    `when` yes; else `conditionFalse`, `rulesetOff`, an open ruling's text, or a question).
    /// 6. `leCurrent`, the LE after the hit.
    ///
    /// A derived fact the rules cannot give (the SP unknown for want of TP, suppressed by a
    /// mount's hit, reiterkampf.RK11) stays unstated: whatever reads it is unknown, and the
    /// questions ask for what is behind it (R25: a safe unknown).
    public static func run(hit tp: Int?, zone: String? = nil, side: String? = nil, in situation: Situation,
                           engine: Engine) -> DamageResult {
        var s = situation
        func state(_ name: String, _ value: JSONValue, _ owner: Owner) { s.facts[name] = Fact(name: name, value: value, owner: owner) }
        if let tp { state("hit.tp", .int(tp), .roll) }
        if let zone { state("hit.zone", .string(zone), .roll) }
        if let side { state("hit.side", .string(side), .roll) }
        for name in derivedFacts { s.facts[name] = nil }           // an earlier hit's are not this one's
        var derived: [FactUse] = []
        var behind: [String: [Question]] = [:]
        func derive(_ name: String, _ value: Int?, from questions: [Question]) {
            guard let value else {
                behind[name] = questions
                return
            }
            state(name, .int(value), .derived)
            derived.append(FactUse(name: name, value: .int(value), owner: .derived))
        }

        // The zone's RS, where a rule that applies reads it (trefferzonen-ruestungsschutz.RS2).
        let zoneRs = zoneRS(in: s, engine: engine)
        if zoneRs.wanted { derive("hit.zoneRs", zoneRs.breakdown?.result, from: zoneRs.breakdown?.questions ?? []) }

        let tpStage = s.facts["hit.tp"].flatMap { f in
            f.value.int.map {
                Breakdown(query: Query("hit.tp"), base: Line(value: $0, kind: .base, facts: [FactUse(name: f.name, value: f.value, owner: f.owner)],
                                                             owner: f.owner, note: "Trefferpunkte des Treffers"))
            }
        }
        let rs = engine.evaluate(Query("rs"), in: s)
        let sp = engine.evaluate(Query("sp"), in: s)
        derive("hit.sp", sp.result, from: sp.questions)
        let wundschwelle = engine.evaluate(Query("wundschwelle"), in: s)
        let count = overWundschwelle(in: s, engine: engine)
        derive("hit.overWundschwelle", count.value, from: sp.questions + wundschwelle.questions)

        var records = PipelineState(query: Query("hit"), depth: 0, candidates: [])
        records.local = [:]
        count.texts.forEach { records.show($0) }
        let checks = checksCalledFor(in: s, engine: engine, &records)
        let le = engine.evaluate(Query("leCurrent"), in: s)

        let stages = [tpStage].compactMap { $0 } + [rs, sp, wundschwelle, le]
        // A derived fact nobody could give is asked through what is behind it.
        var questions: [Question] = []
        for q in stages.flatMap(\.questions) + records.questions {
            if let instead = behind[q.fact] {
                questions += instead.map { var b = $0; b.origins = (b.origins + q.origins).uniqued(); return b }
            } else if !derivedFacts.contains(q.fact) {
                questions.append(q)
            }
        }
        return DamageResult(tp: tpStage, rs: rs, sp: sp, wundschwelle: wundschwelle, leCurrent: le, situation: s,
                            derived: derived, checks: checks, questions: CheckProcedure.mergeQuestions(questions),
                            texts: (stages.flatMap(\.texts) + records.texts).uniqued(),
                            notApplied: (stages.flatMap(\.notApplied) + records.notApplied).uniqued())
    }

    // MARK: - The derived facts

    /// `hit.zoneRs` is wanted when a rule that applies reads it; its value is the `rs(zone: Z)` of
    /// the zone hit, Z being the zone the book names for `rs` that is `hit.zone` itself, or for a
    /// limb the one whose stem begins `hit.zone` and ends in `hit.side` (`arme`, `rechts` →
    /// `armRechts`). nil breakdown when no such zone is named or the zone is not known.
    static func zoneRS(in s: Situation, engine: Engine) -> (wanted: Bool, breakdown: Breakdown?) {
        let book = engine.book
        let evaluation = engine.evaluation(s)
        let readers = book.rules.keys.sorted(by: Evaluation.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }
            .filter { e in e.payload.values.contains { $0.factNames.contains("hit.zoneRs") } || e.when?.factNames.contains("hit.zoneRs") == true }
        guard readers.contains(where: { evaluation.applicability(of: $0.origin.rule, depth: 0).applies }) else { return (false, nil) }
        guard let zone = s.facts["hit.zone"]?.value.string else { return (true, nil) }
        let side = s.facts["hit.side"]?.value.string
        let named = book.rules.values.flatMap { $0.clauses.flatMap(\.effects) }
            .flatMap { $0.payload.values.flatMap(\.targets) }
            .filter { $0.name == "rs" }.compactMap { $0.context["zone"] }.uniqued().sorted()
        let key = named.first { $0 == zone } ?? side.flatMap { side in
            let suffix = side.prefix(1).uppercased() + side.dropFirst()
            return named.first { $0.hasSuffix(suffix) && zone.hasPrefix(String($0.dropLast(suffix.count))) }
        }
        guard let key else { return (true, nil) }
        return (true, engine.evaluate(Query(TargetRef(name: "rs", context: ["zone": key])), in: s))
    }

    /// `hit.overWundschwelle`: the count a rule reading it defines, as the magnitude of that rule's
    /// proportion over `hit.sp` (trefferzonen.TZ8's `{ of: hit.sp, per: wundschwelle, times: -1,
    /// round: down }` → ⌊SP / Wundschwelle⌋), among the rules that apply. nil when no rule defines
    /// it, when it cannot be computed yet, or when two definitions disagree (a §11 text).
    static func overWundschwelle(in s: Situation, engine: Engine) -> (value: Int?, texts: [TextLine]) {
        let book = engine.book
        let evaluation = engine.evaluation(s)
        var found: [(value: Int, origin: ClauseRef)] = []
        for id in book.rules.keys.sorted(by: Evaluation.idOrder) where evaluation.applicability(of: id, depth: 0).applies {
            for e in book.rules[id]!.clauses.flatMap(\.effects) where e.when?.factNames.contains("hit.overWundschwelle") == true {
                for v in e.payload.values {
                    guard case .proportion(var p) = v, p.of.factNames.contains("hit.sp") else { continue }
                    p.times = abs(p.times)
                    let level = evaluation.ruleLevel(id, levels: [:], depth: 0)
                    if let n = evaluation.value(.proportion(p), level: level, rule: id, depth: 0).value {
                        found.append((n, e.origin.clauseRef))
                    }
                }
            }
        }
        guard let first = found.first else { return (nil, []) }
        if found.contains(where: { $0.value != first.value }) {
            let which = found.map { "\($0.origin) \($0.value)" }.joined(separator: ", ")
            return (nil, [TextLine(kind: .notApplicable,
                                   text: "Regel konnte nicht angewandt werden: \(first.origin) – hit.overWundschwelle wird verschieden bestimmt (\(which))",
                                   origin: first.origin)])
        }
        return (first.value, [])
    }

    // MARK: - The checks a hit calls for

    /// Every top-level `check` effect of a talent or spell whose `when` or `modifier` reads a
    /// `hit.*` fact, in rule-id and clause order, read as the pipeline reads an effect; each whose
    /// `when` holds is pending. A firing `suppress` naming it stops it.
    static func checksCalledFor(in s: Situation, engine: Engine, _ records: inout PipelineState) -> [PendingCheck] {
        let book = engine.book
        let evaluation = engine.evaluation(s)
        let all = book.rules.keys.sorted(by: Evaluation.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }
        let asked = all.filter { e in
            guard case .check(let c) = e.payload, [.talent, .spell].contains(c.of.kind) else { return false }
            let reads = (e.when?.factNames ?? []).union(c.modifier?.factNames ?? [])
            return reads.contains { $0.hasPrefix("hit.") }
        }
        var run = evaluation.actionRun(controlling: asked)
        var out: [PendingCheck] = []
        for e in asked {
            guard case .check(let c) = e.payload, evaluation.applies(e, &run.pipeline),
                  !evaluation.isSuppressed(e, &run.pipeline) else { continue }
            let rule = e.origin.rule
            let via = evaluation.ruleVia(rule, run.pipeline)
            guard let used = evaluation.gate(e, level: evaluation.ruleLevel(rule, levels: [:], depth: 0), via: via,
                                             &run.pipeline) else { continue }
            guard let id = c.of.ids.compactMap(\.id).first, let kind = CheckKind(rawValue: c.of.kind.rawValue) else { continue }
            var application: String?
            for w in c.of.with ?? [] {
                let a = evaluation.application(w, rule: rule, depth: 0)
                if let v = a.value { application = v; break }
                run.pipeline.ask(a.unknown, for: e.origin.clauseRef)
            }
            out.append(PendingCheck(origin: e.origin.clauseRef, kind: kind, id: id, application: application,
                                    onSuccess: c.onSuccess, onFailure: c.onFailure, situation: s,
                                    rulings: evaluation.decided(e), via: via, facts: used))
        }
        run.pipeline.notApplied.forEach { records.record($0) }
        run.pipeline.texts.forEach { records.show($0) }
        for q in run.pipeline.questions {
            for o in q.origins { records.ask([UnknownFact(name: q.fact, owner: q.owner)], for: o) }
        }
        return out
    }
}

extension Payload {
    /// The values the effect computes with (a derive's terms, a check's modifier, a cost's amount, …).
    var values: [ValueExpr] {
        switch self {
        case .add(let a): [a.value]
        case .set(let s): [s.value]
        case .derive(let d): d.sum
        case .cap(let c): [c.max, c.min].compactMap { $0 }
        case .floor(let f): [f.min]
        case .replace(let r): [r.with]
        case .useLevel(let u): [u.as, u.lowerBy].compactMap { $0 }
        case .limit(let l): [l.max]
        case .check(let c): [c.modifier].compactMap { $0 }
        case .cost(let c): [c.amount]
        case .process(let p): [p.steps]
        default: []
        }
    }
}
