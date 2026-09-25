import Foundation
@testable import RulesEngine

/// The harness's door to Task 27: a hit on the hero (`DamageChain`, the action `.takeHit`) and the
/// combat roll (`CombatRoll`).
///
/// **A hit** is a situation that states one: the SP after RS (`sp`) or a `hit.*` fact (at the top
/// or in a step), or that expects a check event from a clause whose `check` reads a `hit.*` fact
/// (reiterkampf.RK10 after "Reittier getroffen", kampfsituationen 17.9). The harness runs the chain
/// on it, and when it states a 3W20 check (`check.kind`, `check.talent`) starts that check where
/// the chain asked for it (the pending check's situation: the hit with its derived facts). Then:
/// - `events` (top): the chain's checks, as `{ check: { talent, application | with }, from }`;
///   `[]` asserts none. The chain itself gives no event.
/// - each `sequence` step either changes the situation (`hero: { values }`, `choose`, `gm`,
///   `loadout`, `rolls: { hit.* }`), and the chain runs again on it, or enters the check's result
///   (`rolls: { check.result: failure }`: `.outcome`), which confirms the check and gives its events
///   (the Wundeffekt's `gained`, a `tell` logged). Its `expect` is compared on that.
/// - the query expectations follow the before/after rule (`choose`).
///
/// **A combat roll** is a situation whose steps roll the attack's die (`rolls: [{ w20: n }]`,
/// probe-fernkampf 21.4): each step rolls the attack with the weapon in hand and compares its
/// `success`.
///
/// Event kinds the engine has no event for (`damage`: no dice value form, `itemChanged`: Task 28,
/// `after`) and step shapes it does not run are unsupported shapes, never passes.
enum CombatRunner {
    struct Run {
        var view: HitView
        var mismatches: [Mismatch]
        var notes: [String]
        /// Every breakdown the run computed (for the open rulings it met, R32).
        var breakdowns: [Breakdown]
    }

    /// The situation-level keys this runner compares.
    static let handled: Set<String> = ["events", "sequence"]

    // MARK: - Which situations

    static func canRun(_ s: CompiledSituation, book: RuleBook) -> Bool {
        isHit(s, book: book) || rollSteps(s) != nil
    }

    static func isHit(_ s: CompiledSituation, book: RuleBook) -> Bool {
        if s.situation.base["sp"] != nil || s.situation.facts.keys.contains(where: { $0.hasPrefix("hit.") }) { return true }
        for step in s.sequence.compactMap(\.objectValue) {
            if step["hero"]?.objectValue?["values"]?.objectValue?["sp"] != nil { return true }
            for key in ["choose", "rolls", "gm"] where step[key]?.objectValue?.keys.contains(where: { $0.hasPrefix("hit.") }) == true {
                return true
            }
        }
        let expected = (s.expectSituation["events"]?.arrayValue ?? [])
            + s.sequence.flatMap { $0.objectValue?["expect"]?.objectValue?["events"]?.arrayValue ?? [] }
        return expected.contains { e in
            guard let o = e.objectValue, o["check"] != nil, let from = o["from"]?.string.flatMap(ClauseRef.init),
                  let clause = book.rules[from.rule]?.clauses.first(where: { $0.id == from.clause }) else { return false }
            return clause.effects.contains { readsAHit($0) }
        }
    }

    /// A `check` effect whose `when` or `modifier` reads a `hit.*` fact: a check a hit asks for.
    static func readsAHit(_ e: Effect) -> Bool {
        guard case .check(let c) = e.payload else { return false }
        return (e.when?.factNames ?? []).union(c.modifier?.factNames ?? []).contains { $0.hasPrefix("hit.") }
    }

    /// The steps as rolls of the attack's die, when every step is one (`rolls: [{ w20: n }]`).
    static func rollSteps(_ s: CompiledSituation) -> [(die: Int, expect: [String: JSONValue])]? {
        guard !s.sequence.isEmpty else { return nil }
        var out: [(Int, [String: JSONValue])] = []
        for raw in s.sequence {
            guard let o = raw.objectValue, Set(o.keys).isSubset(of: ["rolls", "expect"]),
                  let rolls = o["rolls"]?.arrayValue, rolls.count == 1, let roll = rolls[0].objectValue,
                  Set(roll.keys) == ["w20"], let die = roll["w20"]?.int else { return nil }
            out.append((die, o["expect"]?.objectValue ?? [:]))
        }
        return out
    }

    // MARK: - Running

    static func run(_ s: CompiledSituation, engine: Engine, attributes: [String: [String]] = CheckAttributes.all) -> Run {
        if isHit(s, book: engine.book) { return hit(s, engine: engine, attributes: attributes) }
        return rolls(s, engine: engine)
    }

    /// The combat roll steps: the attack with the weapon in hand, one die each.
    private static func rolls(_ s: CompiledSituation, engine: Engine) -> Run {
        var c = MatchResult()
        var all: [Breakdown] = []
        let weapon = s.situation.facts["loadout.weapon"]?.value.string
        for (n, step) in (rollSteps(s) ?? []).enumerated() {
            let label = "step \(n + 1)"
            let start = CombatRoll.start(.attack(with: weapon), in: s.engineSituation, engine: engine)
            let rolled = start.state.step(.dice([step.die]), engine: engine)
            all += start.breakdowns + rolled.breakdowns
            guard rolled.state != start.state else {
                c.mismatches.append(Mismatch(kind: .success, query: start.state.stages.target.query.description,
                                             detail: "\(label): the die \(step.die) was refused: \(rolled.texts.map(\.text))"))
                continue
            }
            compare(step.expect, label: label, events: rolled.events, checks: [], texts: rolled.texts,
                    notApplied: rolled.notApplied, questions: rolled.questions, success: rolled.state.result?.success,
                    successQuery: start.state.stages.target.query.description,
                    breakdown: { engine.evaluate(Query($0), in: rolled.situation) }, &c)
        }
        return Run(view: HitView(queries: [:], breakdowns: [], situation: s.engineSituation), mismatches: c.mismatches,
                   notes: c.notes, breakdowns: all)
    }

    /// A hit: the chain, the check it asks for, the steps.
    private static func hit(_ s: CompiledSituation, engine: Engine, attributes: [String: [String]]) -> Run {
        var c = MatchResult()
        let before = s.engineSituation
        var chain = DamageChain.run(hit: nil, in: before, engine: engine)
        var all = chain.breakdowns
        var check = startCheck(in: chain, stated: ActionRunner.checkStated(s), rolls: s.rolls, engine: engine,
                               attributes: attributes, &c)
        all += check?.view.breakdowns ?? []

        // The query expectations: a check's stage from the check, any other by the before/after rule.
        var queries: [String: Breakdown] = [:]
        for q in s.expect {
            let (b, after) = choose(q.query, before: before, chain: chain, events: [], check: check?.view, engine: engine)
            queries[q.query] = b
            if after { c.notes.append("\(q.query): compared after the hit") }
        }
        if let raw = s.expectSituation["events"] {
            if let expected = raw.arrayValue {
                c.mismatches += events(expected, events: [], checks: chain.checks)
            } else {
                c.mismatches.append(.shape("malformed events", "events \(raw) is not a list"))
            }
        }
        let view = HitView(queries: queries, breakdowns: chain.breakdowns + [summary(chain)] + (check?.view.breakdowns ?? []),
                           situation: chain.situation)

        // The steps, in order; each builds on the one before.
        var current = before
        for (n, raw) in s.sequence.enumerated() {
            let label = "step \(n + 1)"
            guard let o = raw.objectValue else {
                c.mismatches.append(.shape("malformed step", "\(label): \(raw) is not an object"))
                continue
            }
            let expect = o["expect"]?.objectValue ?? [:]
            if let rolls = o["rolls"]?.objectValue, Set(rolls.keys) == ["check.result"], Set(o.keys).isSubset(of: ["rolls", "expect"]) {
                // The check's result entered: confirm it.
                if check == nil, let pending = chain.checks.first, let probe = attributes[pending.id] {
                    let start = CheckProcedure.start(pending.request(attributes: probe), in: pending.situation, engine: engine)
                    check = (start.state, ProcedureView(stages: start.state.stages, result: nil, offers: []), pending.situation)
                }
                guard let open = check else {
                    c.mismatches.append(Mismatch(kind: .checkResult, detail: "\(label): no check to enter the result of (the hit asked for none)"))
                    continue
                }
                let success = rolls["check.result"]?.string == "success"
                let out = open.state.step(.outcome(success: success), engine: engine)
                all += out.breakdowns
                guard out.state != open.state else {
                    c.mismatches.append(Mismatch(kind: .checkResult, detail: "\(label): the result was refused: \(out.texts.map(\.text))"))
                    continue
                }
                let after = open.situation.applying(out.events, book: engine.book)
                let rules = Set(out.events.compactMap(\.rule))
                compare(expect, label: label, events: out.events, checks: [], texts: out.texts, notApplied: out.notApplied,
                        questions: out.questions, success: nil, successQuery: nil,
                        breakdown: { q in
                            let (b, _) = choose(q, before: open.situation, after: after, changed: [], rules: rules, check: nil, engine: engine)
                            return b
                        }, &c)
                check = (out.state, ProcedureView(stages: out.state.stages, result: out.state.result, offers: []), after)
                continue
            }
            // A step that changes what is stated: the chain runs again on it.
            let (next, shapes) = applying(o, to: current)
            c.mismatches += shapes.map { $0.at(label) }
            guard shapes.isEmpty else { continue }
            current = next
            chain = DamageChain.run(hit: nil, in: current, engine: engine)
            all += chain.breakdowns
            var stepped = MatchResult()
            check = startCheck(in: chain, stated: stated(in: current), rolls: [], engine: engine, attributes: attributes, &stepped)
            c.mismatches += stepped.mismatches.map { $0.at(label) }
            all += check?.view.breakdowns ?? []
            let stages = chain.breakdowns + (check?.view.breakdowns ?? [])
            let hitChain = chain, hitCheck = check
            compare(expect, label: label, events: [], checks: chain.checks, texts: stages.flatMap(\.texts) + chain.texts,
                    notApplied: stages.flatMap(\.notApplied) + chain.notApplied,
                    questions: stages.flatMap(\.questions) + chain.questions, success: nil, successQuery: nil,
                    breakdown: { q in
                        choose(q, before: current, chain: hitChain, events: [], check: hitCheck?.view, engine: engine).breakdown
                    }, &c)
        }
        return Run(view: view, mismatches: c.mismatches, notes: c.notes, breakdowns: all)
    }

    /// The chain's own entries (a check that did not come, the questions behind a derived fact) as
    /// one breakdown, for the situation-level lookups.
    static func summary(_ chain: DamageResult) -> Breakdown {
        Breakdown(query: Query("hit"), notApplied: chain.notApplied, questions: chain.questions, texts: chain.texts)
    }

    /// The check the situation states (`check.kind` with `check.talent` / `check.spell`), started
    /// where the chain asked for it (a pending check of that talent: its situation), else in the
    /// hit's situation; with the situation's dice, rolled. The Probe's attributes come from rules.db.
    private static func startCheck(in chain: DamageResult, stated: (kind: CheckKind, id: String)?, rolls: [Int], engine: Engine,
                                   attributes: [String: [String]], _ c: inout MatchResult)
    -> (state: ProcedureState, view: ProcedureView, situation: Situation)? {
        guard let stated else { return nil }
        guard let probe = attributes[stated.id] else {
            c.mismatches.append(Mismatch(kind: .checkResult, detail: "rules.db has no Probe row for \(stated.id): the check cannot run (make rules-db)"))
            return nil
        }
        let pending = chain.checks.first { $0.kind == stated.kind && $0.id == stated.id }
        let situation = pending?.situation ?? chain.situation
        var step = CheckProcedure.start(CheckRequest(kind: stated.kind, id: stated.id, attributes: probe), in: situation, engine: engine)
        if rolls.count == probe.count { step = step.state.step(.dice(rolls), engine: engine) }
        return (step.state, ProcedureView(stages: step.state.stages, result: step.state.result, offers: step.offers), situation)
    }

    static func stated(in s: Situation) -> (kind: CheckKind, id: String)? {
        guard let kind = s.facts["check.kind"]?.value.string.flatMap(CheckKind.init(rawValue:)) else { return nil }
        let id: String? = switch kind {
        case .talent: s.facts["check.talent"]?.value.string
        case .spell: s.facts["check.spell"]?.value.string
        case .liturgy: nil
        }
        return id.map { (kind, $0) }
    }

    /// A step's statements applied: `hero: { values }` as the sheet's base, `choose` (the player's
    /// facts), `gm`, `loadout`, `rolls` (roll facts). Anything else is an unsupported shape.
    static func applying(_ step: [String: JSONValue], to situation: Situation) -> (Situation, [Mismatch]) {
        var s = situation
        var shapes: [Mismatch] = []
        for key in step.keys.sorted() where key != "expect" {
            guard let o = step[key]?.objectValue else {
                shapes.append(.shape("step \(key)", "step \(key) \(step[key]!) is not modelled"))
                continue
            }
            switch key {
            case "hero":
                for (k, v) in o {
                    guard k == "values", let values = v.objectValue else {
                        shapes.append(.shape("step hero.\(k)", "step hero.\(k) is not modelled"))
                        continue
                    }
                    for (name, n) in values {
                        if let n = n.int { s.base[name] = n } else { shapes.append(.shape("step value", "step value \(name): \(n) is not a number")) }
                    }
                }
            case "choose", "gm", "loadout", "rolls":
                let owner: Owner? = switch key {
                case "gm": .gm
                case "loadout": .loadout
                case "rolls": .roll
                default: nil
                }
                for (name, v) in o {
                    s.facts[name] = Fact(name: name, value: v, owner: owner ?? Vocabulary.owner(ofFact: name) ?? .player)
                }
            default:
                shapes.append(.shape("step \(key)", "step \(key) is not modelled"))
            }
        }
        return (s, shapes)
    }

    // MARK: - Before or after the action

    /// R50, per expectation: a query is compared on the situation the action leaves when its
    /// breakdown there reads what the action changed: a fact the action stated (the hit's derived
    /// facts `hit.sp`, `hit.overWundschwelle`, `hit.zoneRs`) or a rule an event of the action gained
    /// or cleared (a line, a `notApplied` entry). Otherwise it describes the situation as stated,
    /// and is compared before. A check's stage (`check.modifier`, …) is the check's. The flag says
    /// whether the breakdown after was taken.
    static func choose(_ query: String, before: Situation, chain: DamageResult, events: [Event], check: ProcedureView?,
                       engine: Engine) -> (breakdown: Breakdown, after: Bool) {
        choose(query, before: before, after: chain.situation.applying(events, book: engine.book),
               changed: Set(chain.derived.map(\.name)), rules: Set(events.compactMap(\.rule)), check: check, engine: engine)
    }

    static func choose(_ query: String, before: Situation, after: Situation, changed: Set<String>, rules: Set<String>,
                       check: ProcedureView?, engine: Engine) -> (breakdown: Breakdown, after: Bool) {
        if let check, ProcedureView.stageTargets.contains(TargetRef(query).name), let b = check.breakdown(for: query) { return (b, false) }
        let b = engine.evaluate(Query(query), in: before), a = engine.evaluate(Query(query), in: after)
        return describesTheAfter(a, differsFrom: b, changed: changed, rules: rules) ? (a, true) : (b, false)
    }

    /// Whether `after` (≠ `before`) reads what the action changed: a fact in `changed`, or a line or
    /// entry of a rule in `rules`.
    static func describesTheAfter(_ after: Breakdown, differsFrom before: Breakdown, changed: Set<String>, rules: Set<String>) -> Bool {
        guard after != before else { return false }
        let lines = after.shownLines
        let read = Set((lines.flatMap(\.facts) + after.notApplied.flatMap(\.facts)).map(\.name))
        let origins = Set(lines.compactMap(\.origin?.rule) + after.notApplied.map(\.origin.rule))
        return !read.isDisjoint(with: changed) || !origins.isDisjoint(with: rules)
    }

    // MARK: - Comparing

    /// A step's (or a roll's) `expect`: `events`, `texts`, `notApplied`, `questions`, `success`, and
    /// any other key as a query of the state after it.
    static func compare(_ expect: [String: JSONValue], label: String, events actual: [Event], checks: [PendingCheck],
                        texts: [TextLine], notApplied: [NotApplied], questions: [Question], success: Bool?, successQuery: String?,
                        breakdown: (String) -> Breakdown, _ c: inout MatchResult) {
        for key in expect.keys.sorted() {
            let raw = expect[key]!
            switch key {
            case "events":
                guard let list = raw.arrayValue else { c.mismatches.append(.shape("malformed events", "\(label): events \(raw) is not a list")); continue }
                c.mismatches += events(list, events: actual, checks: checks).map { $0.at(label) }
            case "texts":
                guard let list = raw.arrayValue else { c.mismatches.append(.shape("malformed texts", "\(label): texts \(raw) is not a list")); continue }
                c.mismatches += Matcher.texts(list, in: texts).map { $0.at(label) }
            case "notApplied":
                for entry in raw.arrayValue ?? [] {
                    guard let e = ExpectedNotApplied(entry) else { c.mismatches.append(.shape("malformed notApplied", "\(label): \(entry)")); continue }
                    var one = MatchResult()
                    Matcher.notApplied(e, in: notApplied, query: nil, &one)
                    c.mismatches += one.mismatches.map { $0.at(label) }
                    c.notes += one.notes
                }
            case "questions":
                let list = raw.arrayValue ?? []
                if list.isEmpty, !questions.isEmpty {
                    c.mismatches.append(Mismatch(kind: .unexpectedQuestion, detail: "\(label): expected no question, asked: \(questions.map(\.fact).distinct())"))
                }
                for e in list {
                    guard let fact = e.objectValue?["fact"]?.string else { c.mismatches.append(.shape("malformed question", "\(label): \(e)")); continue }
                    if !questions.contains(where: { $0.fact == fact }) {
                        c.mismatches.append(Mismatch(kind: .missingQuestion, detail: "\(label): no question for \(fact)"))
                    }
                }
            case "success":
                guard case .bool(let want) = raw, successQuery != nil else {
                    c.mismatches.append(.shape("step success", "\(label): success \(raw) is not modelled here"))
                    continue
                }
                if success != want {
                    c.mismatches.append(Mismatch(kind: .success, query: successQuery,
                                                 detail: "\(label): expected success \(want), got \(success.map(String.init) ?? "none")"))
                }
            default:
                guard var o = raw.objectValue else {
                    c.mismatches.append(.shape("step \(key)", "\(label): \(key) \(raw) is not modelled"))
                    continue
                }
                o["query"] = .string(key)
                guard let data = try? JSONEncoder().encode(JSONValue.object(o)),
                      let q = try? JSONDecoder().decode(QueryExpectation.self, from: data) else {
                    c.mismatches.append(.shape("step \(key)", "\(label): \(key) is not modelled"))
                    continue
                }
                var one = MatchResult()
                Matcher.query(q, breakdown(key), &one)
                c.mismatches += one.mismatches.map { $0.at(label) }
                c.notes += one.notes
            }
        }
    }

    /// The expected `events` against what the action gave: its events and the checks it asked
    /// for. Each actual entry matches one expectation at most; entries not mentioned are not
    /// checked, and `[]` asserts that there is neither an event nor a check.
    /// - `{ check: { talent | spell, application | with }, from, via, ruling }`: a check asked for,
    ///   by the talent, its Anwendungsgebiet (when given and not null), its clause, `via` (subset)
    ///   and rulings;
    /// - `{ gained | cleared: RULE, from, levels, ruling, via }`;
    /// - `{ logged: text, from }`;
    /// - `{ paid: { amount, pool }, from }`;
    /// - anything else (`damage`, `itemChanged`, `after`, a check of an attack) is an unsupported shape.
    static func events(_ expected: [JSONValue], events actual: [Event], checks: [PendingCheck]) -> [Mismatch] {
        if expected.isEmpty {
            let got = actual.map { "\($0.kind.rawValue) \($0.rule ?? $0.note ?? "")" } + checks.map { "check \($0.id) from \($0.origin)" }
            return got.isEmpty ? [] : [Mismatch(kind: .unexpectedEvent, detail: "expected no event, got \(got)",
                                               names: checks.map(\.origin.description) + actual.compactMap { $0.origin?.description })]
        }
        var out: [Mismatch] = []
        var usedEvents = Set<Int>(), usedChecks = Set<Int>()
        for raw in expected {
            guard let o = raw.objectValue else { out.append(.shape("malformed event", "event \(raw) is not an object")); continue }
            let from = o["from"]?.string, ruling = o["ruling"].map(strings) ?? [], via = o["via"].map(strings) ?? []
            let names = [from].compactMap { $0 } + ruling + via
            if let check = o["check"]?.objectValue {
                let kind = ["talent", "spell"].first { check[$0] != nil }
                let extra = Set(check.keys).subtracting(["talent", "spell", "application", "with"])
                guard let kind, extra.isEmpty, let id = check[kind]?.string else {
                    out.append(.shape("event check \(check.keys.sorted())", "event check \(check.keys.sorted()) is not a 3W20 check the engine asks"))
                    continue
                }
                let application: String?? = (check["application"] ?? check["with"]).map { $0.string }
                let fits = checks.indices.filter { i in
                    let p = checks[i]
                    return !usedChecks.contains(i) && p.kind.rawValue == kind && p.id == id
                        && (application.map { $0 == nil || $0 == p.application } ?? true)
                        && (from == nil || p.origin.description == from)
                        && Set(via).isSubset(of: p.via.map(\.description)) && ruling.allSatisfy { Matcher.rulingMatches($0, p.rulings) }
                }
                if let i = fits.first {
                    usedChecks.insert(i)
                } else {
                    let got = checks.map { "\($0.id) (\($0.application ?? "–")) from \($0.origin)" }
                    out.append(Mismatch(kind: .missingEvent, detail: "expected the check \(id)\(application.flatMap { $0 }.map { " (\($0))" } ?? "")"
                                        + "\(from.map { " from \($0)" } ?? ""), got \(got.isEmpty ? "none" : got.joined(separator: "; "))", names: names))
                }
                continue
            }
            let kinds: [(key: String, kind: EventKind)] = [("gained", .gained), ("cleared", .cleared), ("logged", .logged), ("paid", .paid)]
            guard let (key, kind) = kinds.first(where: { o[$0.key] != nil }) else {
                out.append(.shape("event \(o.keys.filter { $0 != "from" && $0 != "ruling" && $0 != "via" }.sorted())",
                                  "event \(o.keys.sorted()) has no engine event"))
                continue
            }
            let known: Set<String> = [key, "from", "ruling", "via", "levels"]
            if let extra = Set(o.keys).subtracting(known).sorted().first {
                out.append(.shape("event field \(extra)", "\(key) event: field \(extra) is not modelled"))
                continue
            }
            let value = o[key]!
            let fits = actual.indices.filter { i in
                let e = actual[i]
                guard !usedEvents.contains(i), e.kind == kind else { return false }
                switch kind {
                case .gained, .cleared: if e.rule != value.string { return false }
                case .logged: if e.note != value.string { return false }
                case .paid:
                    guard let p = value.objectValue, p["pool"]?.string == e.pool?.rawValue, p["amount"]?.int == e.amount else { return false }
                default: return false
                }
                return (from == nil || e.origin?.description == from) && (o["levels"].map { $0.int == e.levels } ?? true)
                    && Set(via).isSubset(of: e.via.map(\.description)) && ruling.allSatisfy { Matcher.rulingMatches($0, e.rulings) }
            }
            if let i = fits.first {
                usedEvents.insert(i)
            } else {
                let got = actual.map { "\($0.kind.rawValue) \($0.rule ?? $0.note ?? $0.pool?.rawValue ?? "") from \($0.origin?.description ?? "–")" }
                out.append(Mismatch(kind: .missingEvent, detail: "expected \(key) \(value)\(from.map { " from \($0)" } ?? ""), got \(got.isEmpty ? "none" : got.joined(separator: "; "))",
                                    names: names))
            }
        }
        return out
    }
}

/// What a hit run shows the matcher: the breakdown of each expected query, and every other
/// breakdown it computed (the chain's stages and entries, the check's stages).
struct HitView {
    var queries: [String: Breakdown]
    var breakdowns: [Breakdown]
    /// The situation the hit leaves.
    var situation: Situation

    func breakdown(for query: String) -> Breakdown? { queries[query] }
}

// MARK: - Attacks and defences offered

extension Matcher {
    /// The fields an `offered` / `notOffered` entry for an attack or a defence may hold.
    static let combatOfferFields: Set<String> = ["defence", "attack", "from", "because", "ruling", "reason", "result", "base", "lines"]

    /// An `offered` / `notOffered` entry naming an attack or a defence (MIGRATION "Notes for the
    /// engine tasks", schilde.SCH2/SCH3: the action layer's entry), against `CombatRoll.options`.
    /// `defence` / `attack` is an id or a list: each names the options with that id, or with a
    /// generic id (`pa`, `aw`; `at`, `fk`, `any`) the options on that target.
    /// - offered: for each id some named option is legal, from `from` when given; `result`,
    ///   `base` and `lines` compare with its target as a query's do;
    /// - not offered: no named option is legal; `because` (by clause, `via`, or text) and `ruling`
    ///   are found among the reasons refusing them. A prose `reason` is a note.
    static func combatOffer(_ o: [String: JSONValue], wanted: Bool, options: [CombatOption], _ c: inout MatchResult) {
        let key = wanted ? "offered" : "notOffered"
        let kind: CombatOption.Kind = o["defence"] != nil ? .defence : .attack
        let ids = strings(o[kind == .defence ? "defence" : "attack"]!)
        for field in o.keys.sorted() where !combatOfferFields.contains(field) || (field == "reason" && wanted) {
            c.mismatches.append(.shape("\(key) field \(field)", "\(key) \(kind.rawValue) \(ids): field \(field) is not modelled"))
        }
        if let reason = o["reason"]?.string, !wanted { c.notes.append("\(key) \(ids): reason \"\(reason)\" (prose, R42)") }
        let from = o["from"]?.string, because = o["because"]?.string, ruling = o["ruling"].map(strings)
        let names = [from, because].compactMap { $0 } + (ruling ?? [])
        func named(_ id: String) -> [CombatOption] {
            options.filter { opt in
                guard opt.kind == kind else { return false }
                if opt.id == id { return true }
                let target = opt.target.query.name
                return kind == .defence ? ["pa", "aw"].contains(id) && target == id : id == "any" || id == target
            }
        }
        for id in ids {
            let seen = named(id).filter { from == nil || $0.origin?.description == from }
            let legal = seen.filter(\.legal)
            let got = seen.isEmpty ? "not offered"
                : seen.map { "\($0.id) \($0.target.query) legal \($0.legal)" + ($0.reasons.first.map { " because \($0.origin)" } ?? "") }
                    .joined(separator: "; ")
            if legal.isEmpty == wanted {
                c.mismatches.append(Mismatch(kind: wanted ? .missingOffer : .unexpectedOffer,
                                             detail: "expected \(kind.rawValue) \(id)\(from.map { " from \($0)" } ?? "") \(wanted ? "offered" : "not offered"), got \(got)",
                                             names: names))
                continue
            }
            if wanted {
                guard o["result"] != nil || o["base"] != nil || o["lines"] != nil else { continue }
                var e = o.filter { ["result", "base", "lines"].contains($0.key) }
                e["query"] = .string(legal[0].target.query.description)
                guard let data = try? JSONEncoder().encode(JSONValue.object(e)),
                      let q = try? JSONDecoder().decode(QueryExpectation.self, from: data) else {
                    c.mismatches.append(.shape("malformed offer", "\(key) \(id): result / base / lines malformed"))
                    continue
                }
                // Some legal option meets them.
                var best: MatchResult?
                for opt in legal {
                    var one = MatchResult()
                    query(q, opt.target, &one)
                    if best == nil || one.mismatches.count < best!.mismatches.count { best = one }
                }
                c.mismatches += best?.mismatches ?? []
                c.notes += best?.notes ?? []
                continue
            }
            guard because != nil || ruling != nil else { continue }
            let reasons = seen.flatMap(\.reasons)
            let becauseOK = because.map { b in reasons.contains { self.because(b, $0) || $0.because == b } } ?? true
            let rulingOK = ruling.map { $0.allSatisfy { r in reasons.contains { rulingMatches(r, $0.rulings) } } } ?? true
            if seen.isEmpty {
                c.mismatches.append(.shape("notOffered reason undecidable",
                                           "notOffered \(kind.rawValue) \(id): it is not offered at all, so its reason cannot be checked"))
            } else if !(becauseOK && rulingOK) {
                c.mismatches.append(Mismatch(kind: .wrongOffer,
                                             detail: "expected \(kind.rawValue) \(id) not offered because \(because ?? "–") on \(ruling ?? []), refused by "
                                                 + "\(reasons.map { "\($0.origin)" + ($0.because.map { " (\($0))" } ?? "") })", names: names))
            }
        }
    }

    /// Whether any `offered` / `notOffered` entry names an attack or a defence.
    static func expectsCombatOptions(_ s: CompiledSituation) -> Bool {
        ["offered", "notOffered"].contains { key in
            (s.expectSituation[key]?.arrayValue ?? []).contains { $0.objectValue.map { $0["defence"] != nil || $0["attack"] != nil } ?? false }
        }
    }
}
