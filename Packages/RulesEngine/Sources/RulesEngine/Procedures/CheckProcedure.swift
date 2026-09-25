import Foundation

/// A talent, spell or liturgy check (3W20) as the state machine of spec §6. Each step is
/// `(state, input) → (state, breakdowns, offers, events)`, pure: everything the next step needs
/// is in the returned `ProcedureState`, nothing is kept anywhere else, and the dice come in from
/// outside. Never throws: an input the state cannot take gives a text and the state as it was.
///
/// The stages are targets, so rules hook in with the ordinary verbs:
/// - `attributes`: `check.attribute(index: i)`, the attribute (the sheet's `attr.<name>`) plus the
///   one shared `check.modifier` breakdown (fertigkeitsproben.FM1), whose `forbid` at 0 or below
///   (FP2) makes the check illegal;
/// - `pool`: `check.fw` (FP3's FW, SA_9's +2);
/// - `dice`: `check.dice`, where the book's `reroll`s are offered and each reroll is a
///   `.rerolled` line;
/// - `result`: FP left (`check.fp`, FP5 from the fact `check.spent`), success, and Doppel-1 /
///   Doppel-20 counted from the faces (`check.ones`, `check.twenties`, stated for the rules);
/// - `quality`: `check.qs` (QS1's table, QS2's floor), read once `check.result` is stated.
public enum CheckProcedure {
    /// The stage breakdowns, awaiting dice (spec §6 step 1).
    public static func start(_ request: CheckRequest, in situation: Situation, engine: Engine) -> StepResult {
        var s = situation
        func state(_ name: String, _ value: JSONValue?, _ owner: Owner) {
            s.facts[name] = value.map { Fact(name: name, value: $0, owner: owner) }
        }
        // This check's facts; what an earlier check left (its result, its dice) is not this one's.
        state("check.kind", .string(request.kind.rawValue), .player)
        state("check.talent", request.kind == .talent ? .string(request.id) : nil, .player)
        state("check.spell", request.kind == .spell ? .string(request.id) : nil, .player)
        for name in ["check.result", "check.ones", "check.twenties", "check.spent"] { s.facts[name] = nil }
        if let application = request.application { state("check.application", .string(application), .player) }
        state("fw.current", s.facts["fw.\(request.id)"]?.value, .derived)
        for (i, name) in request.attributes.enumerated() {
            s.base[attributeQuery(i).description] = s.facts["attr.\(name)"]?.value.int
        }
        let context = Self.context(request)
        let modifier = engine.evaluate(Query(TargetRef(name: "check.modifier", context: context)), in: s)
        let attributes = request.attributes.enumerated().map { i, name -> Breakdown in
            var b = engine.evaluate(attributeQuery(i), in: s)
            if let f = s.facts["attr.\(name)"], f.value.int != nil {
                b.base?.facts = [FactUse(name: f.name, value: f.value, owner: f.owner)]
                b.base?.note = "\(name) laut Bogen"
            } else if !b.questions.contains(where: { $0.fact == "attr.\(name)" }) {
                b.questions.insert(Question(fact: "attr.\(name)", owner: Vocabulary.owner(ofFact: "attr.\(name)")), at: 0)
            }
            return b
        }
        let fw = engine.evaluate(Query(TargetRef(name: "check.fw", context: context)), in: s)
        let stages = Stages(request: request, outer: situation, situation: s, modifier: modifier, attributes: attributes, fw: fw)
        var out = StepResult(state: .awaitingDice(stages))
        out.gather(stages.breakdowns)
        if request.attributes.isEmpty {
            out.texts.append(TextLine(kind: .notApplicable, text: "Probe nicht möglich: keine Eigenschaften angegeben"))
        }
        return out
    }

    /// One step. `.dice` on a check awaiting them gives the result and the open rerolls; `.reroll`
    /// replaces a die (the log keeps both faces); `.confirm` gives the events; `.forbidden` fails
    /// a check that is not confirmed yet.
    public static func step(_ state: ProcedureState, _ input: ProcedureInput, engine: Engine) -> StepResult {
        switch (state, input) {
        case (.awaitingDice(let stages), .dice(let faces)):
            return roll(stages, faces, state, engine)
        case (.rolled(let stages, let result, let offers), .reroll(let die, let face, let using)):
            return reroll(stages, result, offers, die: die, face: face, using: using, state, engine)
        case (.rolled(let stages, let result, _), .confirm):
            return confirm(stages, result, engine)
        case (.awaitingDice(let stages), .forbidden(let entries)), (.rolled(let stages, _, _), .forbidden(let entries)):
            guard let first = entries.first else { return refuse(state, "keine Begründung für das Verbot") }
            let failed = evaluate(stages, faces: [], rolled: [], rerolls: [], uses: [:], diceLines: [], forbiddenBy: first,
                                  engine)
            var out = confirm(stages, failed, engine)
            out.notApplied = (entries + out.notApplied).uniqued()
            return out
        case (.awaitingDice(let stages), .outcome(let success)):
            guard stages.legal.allowed else { return refuse(state, "die Probe ist nicht erlaubt") }
            let entered = evaluate(stages, faces: [], rolled: [], rerolls: [], uses: [:], diceLines: [], forbiddenBy: nil,
                                   stated: success, engine)
            return confirm(stages, entered, engine)
        case (.rolled, .outcome):
            return refuse(state, "die Würfel sind schon gefallen")
        case (.awaitingDice, _):
            return refuse(state, "erst die Würfel (\(state.stages.request.attributes.count)W20)")
        case (.rolled, .dice):
            return refuse(state, "die Würfel sind schon gefallen")
        case (.confirmed, _):
            return refuse(state, "die Probe ist schon abgeschlossen")
        }
    }

    /// The action layer's `.check`: start, and with the situation's `rolls` (one per attribute)
    /// the dice and the confirm.
    static func perform(_ request: CheckRequest, in situation: Situation, engine: Engine) -> ActionResult {
        var steps = [start(request, in: situation, engine: engine)]
        if !request.attributes.isEmpty, situation.rolls.count == request.attributes.count {
            steps.append(steps[0].state.step(.dice(situation.rolls), engine: engine))
            if case .rolled = steps[1].state { steps.append(steps[1].state.step(.confirm, engine: engine)) }
        }
        return ActionResult(events: steps.flatMap(\.events), breakdowns: steps.flatMap(\.breakdowns),
                            questions: mergeQuestions(steps.flatMap(\.questions)), texts: steps.flatMap(\.texts).uniqued(),
                            notApplied: steps.flatMap(\.notApplied).uniqued())
    }

    // MARK: - The steps

    static func attributeQuery(_ i: Int) -> Query { Query(TargetRef(name: "check.attribute", context: ["index": String(i)])) }

    /// The check's context for `check.modifier` and `check.fw`: `talent:` or `spell:`.
    static func context(_ r: CheckRequest) -> [String: String] {
        switch r.kind {
        case .talent: ["talent": r.id]
        case .spell: ["spell": r.id]
        case .liturgy: [:]
        }
    }

    private static func refuse(_ state: ProcedureState, _ why: String) -> StepResult {
        StepResult(state: state, texts: [TextLine(kind: .notApplicable, text: "Schritt nicht möglich: \(why)")])
    }

    private static func roll(_ stages: Stages, _ faces: [Int], _ state: ProcedureState, _ engine: Engine) -> StepResult {
        let n = stages.attributes.count
        guard n > 0, faces.count == n else { return refuse(state, "\(n) Würfel erwartet, \(faces.count) erhalten") }
        guard faces.allSatisfy({ (1...20).contains($0) }) else { return refuse(state, "ein W20 zeigt 1 bis 20: \(faces)") }
        guard stages.legal.allowed else {
            let why = stages.legal.reasons.map { "\($0.origin)" + ($0.because.map { " (\($0))" } ?? "") }
            return refuse(state, "die Probe ist nicht erlaubt: " + why.joined(separator: ", "))
        }
        let unknown = zip(stages.request.attributes, stages.eew).filter { $0.1 == nil }.map(\.0)
        guard unknown.isEmpty else { return refuse(state, "effektiver Eigenschaftswert unbekannt: \(unknown.joined(separator: ", "))") }
        let result = evaluate(stages, faces: faces, rolled: faces.map { [$0] }, rerolls: [], uses: [:], diceLines: [],
                              forbiddenBy: nil, engine)
        return rolled(stages, result, engine)
    }

    /// The `.rolled` state for `result`, with its open rerolls.
    private static func rolled(_ stages: Stages, _ result: CheckResult, _ engine: Engine) -> StepResult {
        var result = result
        let offers = rerollOffers(result, engine)
        result.dice.notApplied = offers.records.notApplied
        result.dice.questions = offers.records.questions
        result.dice.texts = offers.records.texts
        var out = StepResult(state: .rolled(stages, result, offers.offers), offers: offers.offers)
        out.gather([result.dice, result.fpStage, result.qsStage])
        return out
    }

    private static func reroll(_ stages: Stages, _ result: CheckResult, _ offers: [RerollOffer], die: Int, face: Int,
                               using: ClauseRef?, _ state: ProcedureState, _ engine: Engine) -> StepResult {
        guard result.faces.indices.contains(die) else { return refuse(state, "W\(die + 1) gibt es nicht") }
        guard (1...20).contains(face) else { return refuse(state, "ein W20 zeigt 1 bis 20, nicht \(face)") }
        let offer: RerollOffer
        if let using {
            guard let o = offers.first(where: { $0.origin == using }) else {
                return refuse(state, "\(using) bietet keinen Neuwurf an")
            }
            offer = o
        } else {
            guard let o = offers.first(where: { $0.legal && $0.dice.contains(die) }) ?? offers.first(where: { $0.dice.contains(die) }) else {
                return refuse(state, "kein Neuwurf für W\(die + 1) offen")
            }
            offer = o
        }
        guard offer.legal else { return refuse(state, "\(offer.origin) ist nicht erlaubt: \(offer.because ?? "")") }
        guard offer.dice.contains(die) else { return refuse(state, "\(offer.origin) wirft W\(die + 1) nicht neu") }
        let old = result.faces[die]
        guard let counts = keep(offer.keep, old: old, new: face) else {
            return refuse(state, "\(offer.origin): unbekanntes keep \(offer.keep)")
        }
        var faces = result.faces, rolled = result.rolled, uses = result.uses
        faces[die] = counts
        rolled[die].append(face)
        uses[offer.origin, default: 0] += 1
        let line = Line(value: counts - old, kind: .rerolled, origin: offer.origin, via: offer.via, rulings: offer.rulings,
                        note: "W\(die + 1): \(old) → \(face), \(offer.name)", was: old, now: counts)
        let record = RerolledDie(die: die, old: old, new: face, counts: counts, origin: offer.origin)
        let next = evaluate(stages, faces: faces, rolled: rolled, rerolls: result.rerolls + [record], uses: uses,
                            diceLines: result.dice.lines + [line], forbiddenBy: nil, engine)
        return self.rolled(stages, next, engine)
    }

    /// The face that stands: `better` is the lower (on a Teilprobe a lower number is never
    /// worse, ADV_4.B2), `worse` the higher, `second` / `new` the new face, `first` the old one.
    static func keep(_ keep: String, old: Int, new: Int) -> Int? {
        switch keep {
        case "better": min(old, new)
        case "worse": max(old, new)
        case "second", "new": new
        case "first", "old": old
        default: nil
        }
    }

    // MARK: - The result

    /// The result of `faces`: the spend per die, FP left, success, the kind counted from the faces
    /// and its classifying clause, then `check.fp` and `check.qs` with `check.result` stated.
    /// With `forbiddenBy` the check was never rolled: a failure, named by that entry. With `stated`
    /// it was rolled at the table and only its success is known (`.outcome`).
    private static func evaluate(_ stages: Stages, faces: [Int], rolled: [[Int]], rerolls: [RerolledDie],
                                 uses: [ClauseRef: Int], diceLines: [Line], forbiddenBy: NotApplied?,
                                 stated: Bool? = nil, _ engine: Engine) -> CheckResult {
        let eew = faces.isEmpty ? [] : stages.eew.map { $0 ?? 0 }
        let spent = zip(faces, eew).map { face, e -> Int in
            let (d, overflow) = face.subtractingReportingOverflow(e)
            return overflow ? Int.max : max(0, d)
        }
        let total = spent.reduce(0) { $0.addingSaturating($1) }
        let ones = faces.filter { $0 == 1 }.count, twenties = faces.filter { $0 == 20 }.count
        var s = stages.situation
        func state(_ name: String, _ value: JSONValue, _ owner: Owner) { s.facts[name] = Fact(name: name, value: value, owner: owner) }
        if !faces.isEmpty {
            state("check.spent", .int(total), .derived)
            state("check.ones", .int(ones), .roll)
            state("check.twenties", .int(twenties), .roll)
        }
        let kind: CheckResultKind
        let success: Bool?
        var from: ClauseRef?
        if let forbiddenBy {
            (kind, success, from) = (.regular, false, forbiddenBy.origin)
        } else if let stated {
            (kind, success) = (.regular, stated)
        } else if twenties >= 2 {
            (kind, success) = (twenties >= 3 ? .dreifach20 : .patzer, false)
            from = classifying("check.twenties", count: twenties, in: s, engine)
        } else if ones >= 2 {
            (kind, success) = (ones >= 3 ? .dreifach1 : .kritischerErfolg, true)
            from = classifying("check.ones", count: ones, in: s, engine)
        } else {
            // FP left before QS2's floor (phase 6), which reads the result this decides.
            let raw = engine.evaluation(s).breakdown(Query("check.fp"), depth: 0, through: .multiply).result
            (kind, success) = (.regular, raw.map { $0 >= 0 })
        }
        if let success { state("check.result", .string(success ? "success" : "failure"), .roll) }
        let fpStage = engine.evaluate(Query("check.fp"), in: s)
        let qsStage = engine.evaluate(Query("check.qs"), in: s)
        return CheckResult(faces: faces, rolled: rolled, eew: eew, spent: spent,
                           fp: forbiddenBy == nil && stated == nil ? fpStage.result : nil,
                           qs: success == true && stated == nil ? qsStage.result : nil, success: success, kind: kind, from: from,
                           ones: ones, twenties: twenties, rerolls: rerolls, uses: uses,
                           dice: Breakdown(query: Query("check.dice"), lines: diceLines), fpStage: fpStage, qsStage: qsStage,
                           situation: s)
    }

    /// The clause that classifies a Doppel-1 / Doppel-20 (MIGRATION probe-fertigkeiten 22.5–22.8):
    /// among the effects of the core rules that apply, those whose `when` compares `fact` with a
    /// least count; the one with the highest count the faces reach, else the one with the lowest
    /// (fertigkeitsproben.PZ1 speaks of the Dreifach-20 and names the Doppel-20 too). Rule-id and
    /// clause order break ties.
    static func classifying(_ fact: String, count: Int, in situation: Situation, _ engine: Engine) -> ClauseRef? {
        let evaluation = engine.evaluation(situation)
        var found: [(least: Double, clause: ClauseRef)] = []
        for id in engine.book.rules.keys.sorted(by: Evaluation.idOrder) {
            guard let rule = engine.book.rules[id], rule.kind == .core, evaluation.applicability(of: id, depth: 0).applies else { continue }
            for clause in rule.clauses {
                for e in clause.effects {
                    if let least = e.when?.least(fact) { found.append((least, ClauseRef(rule: id, clause: clause.id))) }
                }
            }
        }
        var best: (least: Double, clause: ClauseRef)?
        for f in found where f.least <= Double(count) && f.least > (best?.least ?? -.infinity) { best = f }
        if best == nil {
            for f in found where f.least < (best?.least ?? .infinity) { best = f }
        }
        return best?.clause
    }

    // MARK: - Rerolls

    /// The book's top-level `reroll`s (rule-id and clause order) whose rule applies and whose
    /// `when` is yes, with uses left (`max` per check). A `per` other than `action` is not
    /// counted here: that reroll is not offered, and a text says so. Each is illegal while a `forbid` naming
    /// its clause or rule fires. The records (a `when` no or unknown, an open ruling) are the
    /// `check.dice` breakdown's.
    static func rerollOffers(_ result: CheckResult, _ engine: Engine) -> (offers: [RerollOffer], records: PipelineState) {
        let evaluation = engine.evaluation(result.situation)
        let book = engine.book
        var records = PipelineState(query: Query("check.dice"), depth: 0, candidates: [])
        records.local = [:]
        let all = book.rules.keys.sorted(by: Evaluation.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }
        let forbids = all.filter {
            if case .forbid(let f) = $0.payload { return f.together != true && [.line, .rule].contains(f.what.kind) }
            return false
        }
        var offers: [RerollOffer] = []
        for e in all {
            guard case .reroll(let r) = e.payload, evaluation.applies(e, &records) else { continue }
            let rule = e.origin.rule
            let level = evaluation.ruleLevel(rule, levels: [:], depth: 0)
            let via = evaluation.ruleVia(rule, records)
            guard evaluation.gate(e, level: level, via: via, &records) != nil else { continue }
            // Uses are counted within this check (`per: action`); a check cannot count another span.
            if let per = r.per, per != .action {
                evaluation.fail(e, "ein Neuwurf je \(per.rawValue) wird in einer Probe nicht gezählt", &records)
                continue
            }
            let remaining = r.max.map { max(0, $0 - (result.uses[e.origin.clauseRef] ?? 0)) }
            if remaining == 0 { continue }                           // used up: no longer offered
            var reasons: [NotApplied] = []
            for f in forbids {
                guard case .forbid(let forbid) = f.payload, evaluation.selects(forbid.what, effect: e),
                      evaluation.applies(f, &records) else { continue }
                let fRule = f.origin.rule
                let fVia = evaluation.ruleVia(fRule, records)
                guard let used = evaluation.gate(f, level: evaluation.ruleLevel(fRule, levels: [:], depth: 0), via: fVia,
                                                 &records) else { continue }
                reasons.append(NotApplied(origin: f.origin.clauseRef, reason: .forbidden, because: f.because, rulings: f.ruling,
                                          facts: used, via: fVia))
            }
            offers.append(RerollOffer(origin: e.origin.clauseRef, name: book.rules[rule]?.name ?? rule,
                                      dice: dice(r.die, count: result.faces.count), keep: r.keep, remaining: remaining,
                                      rulings: evaluation.decided(e), via: via, reasons: reasons))
        }
        return (offers, records)
    }

    /// The dice (0-based) a `reroll`'s `die` selector names: `any`, or 1-based numbers.
    static func dice(_ selector: RuleSelector, count: Int) -> [Int] {
        let ids = selector.ids.compactMap(\.id)
        if ids.contains("any") { return Array(0..<count) }
        return ids.compactMap(Int.init).map { $0 - 1 }.filter { (0..<count).contains($0) }.uniqued()
    }

    // MARK: - Confirm

    /// Spec §6 step 4: `logged` with the QS; the costs and gains that read `check.result` (the
    /// cast's AsP, half on a failure); each `check` effect naming this check, whose `when` holds in
    /// the situation that asked for it, runs its `onSuccess` or `onFailure` (costs and gains as
    /// events, a `tell` logged, a `forbid` on a check kind handed on in `forbidden`); and every
    /// `tell` reading `check.result` that fires is shown and logged.
    private static func confirm(_ stages: Stages, _ result: CheckResult, _ engine: Engine) -> StepResult {
        let book = engine.book
        let evaluation = engine.evaluation(result.situation)
        let request = stages.request
        let all = book.rules.keys.sorted(by: Evaluation.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }
        let readsResult = { (e: Effect) in e.when?.factNames.contains("check.result") == true }
        let actions = evaluation.actionEffects().filter(readsResult)

        // The `check` effects asking for this check, read where they were asked.
        let outer = engine.evaluation(stages.outer)
        let stated = engine.evaluation(stages.situation)
        var asked = PipelineState(query: Query("check"), depth: 0, candidates: [])
        asked.local = [:]
        var consequences: [Effect] = []
        for e in all {
            guard case .check(let c) = e.payload, names(c.of, request, stated, rule: e.origin.rule),
                  outer.applies(e, &asked) else { continue }
            let rule = e.origin.rule
            let level = outer.ruleLevel(rule, levels: [:], depth: 0)
            guard outer.gate(e, level: level, via: outer.ruleVia(rule, asked), &asked) != nil,
                  let success = result.success else { continue }
            consequences += success ? c.onSuccess : c.onFailure
        }
        let nestedActions = consequences.filter {
            switch $0.payload {
            case .cost, .gain: true
            default: false
            }
        }

        var run = evaluation.actionRun(controlling: actions + nestedActions)
        let resultFact = result.situation.facts["check.result"].map { [FactUse(name: $0.name, value: $0.value, owner: $0.owner)] }
        run.events.append(Event(kind: .logged, facts: resultFact ?? [], note: note(request, result)))
        evaluation.run(actions + nestedActions, &run)

        var forbidden: [NotApplied] = []
        let tells = all.filter { e in if case .tell = e.payload { return readsResult(e) } else { return false } }
        for e in consequences + tells {
            switch e.payload {
            case .forbid(let f) where f.what.kind == .check && f.together != true:
                guard evaluation.applies(e, &run.pipeline) else { continue }
                let rule = e.origin.rule
                let via = evaluation.ruleVia(rule, run.pipeline)
                guard let used = evaluation.gate(e, level: evaluation.ruleLevel(rule, levels: [:], depth: 0), via: via,
                                                 &run.pipeline) else { continue }
                forbidden.append(NotApplied(origin: e.origin.clauseRef, reason: .forbidden, because: e.because, rulings: e.ruling,
                                            facts: used, via: via))
            case .tell(let t):
                guard evaluation.applies(e, &run.pipeline), !evaluation.isSuppressed(e, &run.pipeline) else { continue }
                let rule = e.origin.rule
                let via = evaluation.ruleVia(rule, run.pipeline)
                guard let used = evaluation.gate(e, level: evaluation.ruleLevel(rule, levels: [:], depth: 0), via: via,
                                                 &run.pipeline, asking: false) else { continue }
                run.pipeline.show(TextLine(kind: .tell, audience: t.to, text: t.text, origin: e.origin.clauseRef))
                run.events.append(Event(kind: .logged, origin: e.origin.clauseRef, via: via, rulings: evaluation.decided(e),
                                        facts: used, note: t.text))
            case .cost, .gain:
                continue                                              // run above
            default:
                evaluation.fail(e, "\(e.payload.verb.rawValue) nach einer Probe wird nicht ausgeführt", &run.pipeline)
            }
        }

        let events = run.events
        var out = StepResult(state: .confirmed(stages, result, events), events: events, forbidden: forbidden)
        out.gather([result.fpStage, result.qsStage])
        out.questions = mergeQuestions(out.questions + asked.questions + run.pipeline.questions)
        out.texts = (out.texts + asked.texts + run.pipeline.texts).uniqued()
        out.notApplied = (out.notApplied + asked.notApplied + run.pipeline.notApplied).uniqued()
        return out
    }

    /// What the log says of the check: "TAL_10: gelungen, QS 2", "…: misslungen".
    private static func note(_ request: CheckRequest, _ result: CheckResult) -> String {
        switch result.success {
        case true?: "\(request.id): gelungen" + (result.qs.map { ", QS \($0)" } ?? "")
        case false?: "\(request.id): misslungen"
        case nil: "\(request.id): Ergebnis unbekannt"
        }
    }

    /// Whether a `check` effect's `of` names this check: a `talent` / `spell` selector by id (with
    /// `with`, the check's Anwendungsgebiet too, a `table(…)` form looked up in the situation: the
    /// Wundeffekt check's by hit zone, trefferzonen.TZ8), a `check` selector by kind.
    static func names(_ of: RuleSelector, _ request: CheckRequest, _ evaluation: Evaluation, rule: String) -> Bool {
        switch of.kind {
        case .talent, .spell:
            return of.kind.rawValue == request.kind.rawValue
                && evaluation.namesCheck(of, context: context(request), rule: rule, depth: 0)
        case .check:
            guard of.ids.compactMap(\.id).contains(request.kind.rawValue) else { return false }
            guard let with = of.with else { return true }
            let stated = evaluation.situation.facts["check.application"]?.value.string
            return with.contains { evaluation.application($0, rule: rule, depth: 0).value.map { $0 == stated } ?? false }
        default:
            return false
        }
    }

    static func mergeQuestions(_ questions: [Question]) -> [Question] {
        var out: [Question] = []
        for q in questions {
            if let i = out.firstIndex(where: { $0.fact == q.fact }) {
                for o in q.origins where !out[i].origins.contains(o) { out[i].origins.append(o) }
                out[i].options = out[i].options ?? q.options
            } else {
                out.append(q)
            }
        }
        return out
    }
}

extension StepResult {
    /// Adds the breakdowns with their questions (one per fact), texts and `notApplied`.
    mutating func gather(_ breakdowns: [Breakdown]) {
        self.breakdowns += breakdowns
        questions = CheckProcedure.mergeQuestions(questions + breakdowns.flatMap(\.questions))
        texts = (texts + breakdowns.flatMap(\.texts)).uniqued()
        notApplied = (notApplied + breakdowns.flatMap(\.notApplied)).uniqued()
    }
}

extension Condition {
    /// The least count this condition asks of `fact` (`atLeast n`, `above n` as n + 1, `is n`),
    /// the first found; nil when it does not compare `fact` with a number.
    func least(_ fact: String) -> Double? {
        switch self {
        case .all(let cs), .any(let cs): return cs.lazy.compactMap { $0.least(fact) }.first
        case .not: return nil
        case .fact(let name, let comparison):
            guard name == fact else { return nil }
            switch comparison {
            case .atLeast(let n): return n
            case .above(let n): return n + 1
            case .is(let v): return v.double
            default: return nil
            }
        }
    }
}

// MARK: - What a `check` effect names

extension Evaluation {
    /// A `check` selector's `with` entry as this situation reads it: plain text (`Kampfmanöver`),
    /// or `table(name, key)`, the provided table's entry for the key (trefferzonen.TZ8's
    /// Anwendungsgebiet by `hit.zone`, from TZ11). nil when the key is unknown (`unknown`) or the
    /// table has no text there.
    func application(_ text: String, rule: String, depth: Int) -> (value: String?, used: [FactUse], unknown: [UnknownFact]) {
        guard let form = Self.tableForm(text) else { return (text, [], []) }
        let (s, behind) = prepared([form.key], depth: depth, rule: rule)
        let t = Tables.lookup(form.name, key: form.key, level: nil, in: s, book: book, rule: rule, depth: depth) {
            [unowned self] target, d in self.resolve(target, depth: d)
        }
        return (t.value?.string, t.used, t.unknown.flatMap { behind[$0.name] ?? [$0] }.uniqued())
    }

    /// `table(name, key)` written as text (a selector's `with`) → its name and key.
    static func tableForm(_ text: String) -> (name: String, key: String)? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("table("), t.hasSuffix(")") else { return nil }
        let parts = t.dropFirst("table(".count).dropLast().split(separator: ",", maxSplits: 1)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return (parts[0], parts[1])
    }

    /// Whether a `check` effect's `of` names the 3W20 check `context` is a stage of (`talent: X` /
    /// `spell: X`; without one, the stated `check.kind` with `check.talent` / `check.spell`): a
    /// `talent` or `spell` selector listing it (or `any`), and with a `with` the stated
    /// `check.application` among its entries (`application`).
    func namesCheck(_ of: RuleSelector, context: [String: String], rule: String, depth: Int) -> Bool {
        let key: String
        switch of.kind {
        case .talent: key = "talent"
        case .spell: key = "spell"
        default: return false
        }
        let stated = situation.facts["check.kind"]?.value.string == key ? situation.facts["check.\(key)"]?.value.string : nil
        guard let subject = context[key] ?? (context.isEmpty ? stated : nil) else { return false }
        let ids = of.ids.compactMap(\.id)
        guard ids.contains(subject) || ids.contains("any") else { return false }
        guard let with = of.with else { return true }
        guard let application = situation.facts["check.application"]?.value.string else { return false }
        return with.contains { self.application($0, rule: rule, depth: depth).value == application }
    }
}
