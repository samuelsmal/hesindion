import Foundation
@testable import RulesEngine

/// The harness's door to Task 28: a `sequence` runs its steps as actions in order, each step's
/// `expect` checked against the state after it; a situation that expects events without saying
/// which action gives them runs the action it implies.
///
/// **The implied action** of a situation (or of a step that only states facts): a cast when it
/// states a spell check (`check.kind: spell`, `check.spell`, the chosen
/// `choice.spellModification.*`: probe-magie); else `.settle` when it expects events (the
/// standing gains, 1.4); else none (the step only states facts, and its queries are read after).
///
/// **A step** is one of:
/// - `action: X`: `shoot` is the attack with the weapon in hand (`.attack(with:)`, its die from
///   `rolls: { roll.attack: n }` when given), any other X the offered choice taken
///   (`.take(choice: X)`, which advances the processes X names);
/// - `advanceClock: { minutes: n }`, `endRound`, `endFight`: the clock;
/// - statements (`choose`, `gm`, `loadout`, `opponent`, `round`, `hero: { values }`, `rolls` as
///   facts, `event: { RULE: n }` the Stufe the hero now has: Task 30), then the implied action if
///   there is one.
///
/// Each step builds on the situation the one before left (`ActionResult.situation`). Its `expect`:
/// - `events`: as `CombatRunner.events`, plus `after: { aspCurrent, leCurrent, conditions }`
///   (the situation the step leaves), a `paid` of several `pools` (the events of one cost, in
///   order, summed), a `paid` `over: { minutes }` (the step's payments of one pool and origin,
///   summed, over that much game time: MIGRATION probe-magie 20.5), and `itemChanged` (by clause
///   and the field it names);
/// - `process: { <id>: n | ended, capped }`: the running process's progress, `ended` when none
///   runs after a step that had one, `capped` when the step gave it no progress;
/// - `success`: the attack's (`action.attack` hit or miss);
/// - `texts`, `notApplied`, `questions`: the step's action, its breakdowns and the step's own
///   query breakdowns (read first);
/// - any other key is a query: the action's own breakdown of it (the shot's `fk`), else read by the
///   before/after rule (`CombatRunner.choose`) around the step.
///
/// The top-level queries follow the before/after rule around the implied action (R50). The
/// situation-level `texts`, `notApplied` and `questions` are looked up in what every action of
/// the run recorded (21.6's open ruling is shown by its Zielen steps).
enum StateRunner {
    struct Run {
        var view: HitView
        var mismatches: [Mismatch]
        var notes: [String]
        /// Every breakdown the run computed, and one per action holding what it recorded (R32).
        var breakdowns: [Breakdown]
    }

    /// The step keys this runner models.
    static let stepKeys: Set<String> = ["action", "advanceClock", "endRound", "endFight", "choose", "gm", "loadout", "opponent",
                                        "round", "hero", "rolls", "expect", "event"]

    /// A situation this runner takes: a `sequence` whose every step it models, or none and an
    /// expectation of events; dice (`rolls` as a list) and a 3W20 result are other runners'.
    ///
    /// Every expected event must be one the implied action can give: a cast any; settling only
    /// Stufen gained or cleared. A situation expecting other events of no cast (a regeneration's
    /// LeP, a jump off the horse's `itemChanged`, a check's `logged`) needs an action the harness
    /// cannot name, and stays unsupported.
    static func canRun(_ s: CompiledSituation, book: RuleBook? = nil) -> Bool {
        guard s.rolls.isEmpty, Set(ActionRunner.needs(s)).isSubset(of: [.sequence, .events]) else { return false }
        let stepsOK = s.sequence.allSatisfy { raw in
            guard let o = raw.objectValue, Set(o.keys).isSubset(of: stepKeys) else { return false }
            return o["rolls"].map { $0.objectValue != nil } ?? true
        }
        guard stepsOK, !s.sequence.isEmpty || s.expectSituation["events"] != nil else { return false }
        if let book, implied(s, book: book) != nil { return true }
        return casts(s) || expectedEvents(s).allSatisfy(settles)
    }

    /// Ruling R64 (Task 30): the choice a situation expecting only `after` events takes, when its
    /// queries read what a `restore` gated on that choice restores (`regeneration.le`: taking the
    /// Regenerationsphase). nil for any other situation.
    static func implied(_ s: CompiledSituation, book: RuleBook) -> Action? {
        let events = expectedEvents(s)
        if let taken = taking(s, book: book) { return taken }
        guard !events.isEmpty, s.sequence.isEmpty, events.allSatisfy({ $0.objectValue?["after"] != nil }) else { return nil }
        let queried = Set(s.expect.map { Query($0.query).name })
        let choices = book.rules.values.flatMap { $0.clauses.flatMap(\.effects) }.compactMap { e -> String? in
            guard case .restore(let r) = e.payload, !Set(r.amount.targets.map(\.name)).isDisjoint(with: queried) else { return nil }
            let names = e.when?.factNames ?? []
            return names.first { $0.hasPrefix("choice.") }.map { String($0.dropFirst("choice.".count)) }
        }
        let distinct = Set(choices)
        return distinct.count == 1 ? .take(choice: distinct.first!) : nil
    }

    /// Task 31: the choice a situation takes (`choice.X` stated, not `false`) when an event it
    /// expects at the top comes `from` a clause whose `item`, `cost`, `gain` or `check` is gated
    /// on that choice, and every event names its clause (reiterkampf.RK6's jump off the horse, RK14's Reiten for an order):
    /// `.take(choice: X)`. nil for any other situation.
    static func taking(_ s: CompiledSituation, book: RuleBook) -> Action? {
        let events = s.expectSituation["events"]?.arrayValue ?? []
        let froms = events.compactMap { $0.objectValue?["from"]?.string.flatMap(ClauseRef.init) }
        guard !events.isEmpty, froms.count == events.count else { return nil }
        let taken = s.situation.facts.values.filter { $0.name.hasPrefix("choice.") && $0.value != .bool(false) && $0.value != .null }
            .map { String($0.name.dropFirst("choice.".count)) }
        // Fix round 1: an event from a clause gated on a taken choice names the action; the other
        // expected events are compared against what it gives.
        var choices: Set<String> = []
        for (event, from) in zip(events, froms) {
            let effects = book.rules[from.rule]?.clauses.first { $0.id == from.clause }?.effects ?? []
            // Task 33: the effect of the event's own kind, when the event says it (a `cleared` is a
            // `gain`'s): STATE_10.L4's stand-up clears on `aufstehen` alone, while the clause's
            // check reads `passierschlagVermeiden` too.
            let kind = gives(event)
            let gating = effects.filter { e in
                switch e.payload {
                case .item: kind == nil || kind == "item"
                case .cost: kind == nil || kind == "cost"
                case .gain: kind == nil || kind == "gain"
                case .check: kind == nil || kind == "check"
                default: false
                }
            }.flatMap { e in taken.filter { (e.when?.factNames ?? []).contains("choice.\($0)") } }
            choices.formUnion(gating)
        }
        return choices.count == 1 ? .take(choice: choices.first!) : nil
    }

    /// The verb whose effect gives an expected event: `gain` for `gained` / `cleared`, `cost` for
    /// `paid`, `item` for `itemChanged`, `check` for a check asked; nil for any other.
    static func gives(_ event: JSONValue) -> String? {
        guard let o = event.objectValue else { return nil }
        if o["gained"] != nil || o["cleared"] != nil { return "gain" }
        if o["paid"] != nil { return "cost" }
        if o["itemChanged"] != nil { return "item" }
        if o["check"] != nil { return "check" }
        return nil
    }

    /// Whether the situation, or a step of it, states a spell check (its implied action is a cast).
    static func casts(_ s: CompiledSituation) -> Bool {
        let steps = s.sequence.compactMap { $0.objectValue?["choose"]?.objectValue }
        return implied(s.situation, events: false) != nil || steps.contains { $0["check.kind"] == .string("spell") }
    }

    /// Every event the situation expects, at the top and in its steps.
    static func expectedEvents(_ s: CompiledSituation) -> [JSONValue] {
        (s.expectSituation["events"]?.arrayValue ?? [])
            + s.sequence.flatMap { $0.objectValue?["expect"]?.objectValue?["events"]?.arrayValue ?? [] }
    }

    /// An event settling gives: a Stufe gained or cleared.
    static func settles(_ e: JSONValue) -> Bool {
        e.objectValue.map { $0["gained"] != nil || $0["cleared"] != nil } ?? false
    }

    /// The action a situation implies (see the type's doc).
    static func implied(_ s: Situation, events: Bool) -> Action? {
        if s.facts["check.kind"]?.value == .string("spell"), let spell = s.facts["check.spell"]?.value.string {
            let prefix = "choice.spellModification."
            let chosen = s.facts.values.filter { $0.name.hasPrefix(prefix) && $0.value == .bool(true) }
                .map { String($0.name.dropFirst(prefix.count)) }.sorted()
            return .cast(spell: spell, modifications: chosen)
        }
        return events ? .settle : nil
    }

    static func expectsEvents(_ s: CompiledSituation) -> Bool {
        s.expectSituation["events"] != nil || s.sequence.contains { $0.objectValue?["expect"]?.objectValue?["events"] != nil }
    }

    static func run(_ s: CompiledSituation, engine: Engine, attributes: [String: [String]] = CheckAttributes.all) -> Run {
        let layer = ActionLayer(engine: engine)
        // Fix round 2: the checks the last action asked, whose result a later step may enter.
        var pending: [PendingCheck] = []
        var c = MatchResult()
        var all: [Breakdown] = []
        let start = s.engineSituation
        var current = start
        let events = expectsEvents(s)

        // The situation's own action, when it expects events of its own (or has no steps).
        var queries: [String: Breakdown] = [:]
        var viewBreakdowns: [Breakdown] = []
        let topAction = (s.expectSituation["events"] != nil || s.sequence.isEmpty)
            ? (implied(s, book: engine.book) ?? implied(start, events: events)) : nil
        if let action = topAction {
            var r = layer.perform(action, in: start)
            pending = r.checks
            // Task 33: the situation states the result of the check its action asks (liegend 7.6's
            // Körperbeherrschung against the Passierschlag), as a step may: the outcome is entered,
            // and its events and its own effects' texts (an `onFailure` tell) are the action's.
            if let stated = start.facts["check.result"]?.value.string, s.sequence.isEmpty,
               let check = pending.first(where: { c in start.facts["check.talent"].map { $0.value == .string(c.id) } ?? true }),
               let probe = attributes[check.id] {
                // In the situation the check was asked in: the stand-up has cleared the status whose
                // clause holds the check's `onFailure`.
                let begun = CheckProcedure.start(check.request(attributes: probe), in: check.situation, engine: engine)
                let out = begun.state.step(.outcome(success: stated == "success"), engine: engine)
                all += begun.breakdowns + out.breakdowns
                pending = []
                // The outcome's own effects' texts and entries: its stages' breakdowns (a `*` tell
                // such as kampfsonderfertigkeiten.KS2's) are the check's display, not the action's.
                let own = Set((check.onSuccess + check.onFailure).map(\.origin.clauseRef))
                r.events += out.events
                r.texts += out.texts.filter { $0.origin.map(own.contains) ?? false }
                r.notApplied += out.notApplied.filter { own.contains($0.origin) }
                r.questions += out.questions.filter { !Set($0.origins).isDisjoint(with: own) }
                r.situation = r.situation.applying(out.events, book: engine.book)
            }
            all += r.breakdowns + [record(r)]
            viewBreakdowns += r.breakdowns + [record(r)]
            if let raw = s.expectSituation["events"] {
                if let list = raw.arrayValue {
                    c.mismatches += Self.events(list, r, before: start, engine: engine)
                } else {
                    c.mismatches.append(.shape("malformed events", "events \(raw) is not a list"))
                }
            }
            for q in s.expect {
                let (b, after) = choose(q.query, action: r, before: start, engine: engine)
                queries[q.query] = b
                if after { c.notes.append("\(q.query): compared after \(describe(action))") }
            }
            current = r.situation
        } else {
            for q in s.expect { queries[q.query] = engine.evaluate(Query(q.query), in: start) }
        }
        if s.expect.isEmpty, s.expectSituation["offered"] != nil || s.expectSituation["notOffered"] != nil {
            // Task 33: the choice a take chose was offered before it (liegend 7.6's `aufstehen`,
            // which clears the status that offers it).
            let taken: Bool
            if case .take? = topAction { taken = true } else { taken = false }
            viewBreakdowns.append(engine.evaluate(Query("offers"), in: taken ? start : current))
        }

        for (n, raw) in s.sequence.enumerated() {
            let label = "step \(n + 1)"
            guard let o = raw.objectValue else { continue }
            let expect = o["expect"]?.objectValue ?? [:]
            // Fix round 2: a step stating only a check's result (`rolls: { check.result }`) enters
            // the outcome of the check the last action asked (reiterkampf.RK12's Reiten): its
            // `onFailure` runs, and the step's texts, entries and events are its.
            if let rolls = o["rolls"]?.objectValue, Set(rolls.keys) == ["check.result"], Set(o.keys).isSubset(of: ["rolls", "expect"]),
               let check = pending.first, let probe = attributes[check.id] {
                let begun = CheckProcedure.start(check.request(attributes: probe), in: current, engine: engine)
                let out = begun.state.step(.outcome(success: rolls["check.result"]?.string == "success"), engine: engine)
                all += begun.breakdowns + out.breakdowns
                pending = []
                let after = current.applying(out.events, book: engine.book)
                CombatRunner.compare(expect, label: label, events: out.events, checks: [], texts: out.texts, notApplied: out.notApplied,
                                     questions: out.questions, success: nil, successQuery: nil,
                                     breakdown: { engine.evaluate(Query($0), in: after) }, &c)
                current = after
                continue
            }
            let before = current
            var stated = current
            let action: Action?
            if let a = o["action"] {
                guard let name = a.string else {
                    c.mismatches.append(.shape("step action", "\(label): action \(a) is not a name"))
                    continue
                }
                action = name == "shoot" ? .attack(with: current.facts["loadout.weapon"]?.value.string) : .take(choice: name)
                // The shot's die, when the step gives it (`rolls: { roll.attack: n }`).
                if name == "shoot", let face = o["rolls"]?.objectValue?["roll.attack"]?.int { stated.rolls = [face] }
            } else if let clock = o["advanceClock"] {
                guard let minutes = clock.objectValue?["minutes"]?.int, clock.objectValue?.count == 1 else {
                    c.mismatches.append(.shape("step advanceClock", "\(label): advanceClock \(clock) is not { minutes: n }"))
                    continue
                }
                action = .advanceClock(minutes: minutes)
            } else if o["endRound"] != nil {
                action = .endRound
            } else if o["endFight"] != nil {
                action = .endFight
            } else {
                let statements = o.filter { !["expect"].contains($0.key) }
                let (next, shapes) = applying(statements, to: current)
                c.mismatches += shapes.map { $0.at(label) }
                guard shapes.isEmpty else { continue }
                stated = next
                action = implied(stated, events: events)
            }
            let r = action.map { layer.perform($0, in: stated) }
            if let r, !r.checks.isEmpty { pending = r.checks }
            if let r {
                all += r.breakdowns + [record(r)]
                viewBreakdowns.append(record(r))                  // the situation-level texts of the run
            }
            let after = r?.situation ?? stated
            compare(expect, label: label, action: action, result: r, before: before, stated: stated, after: after,
                    engine: engine, &c, &all)
            current = after
        }
        let view = HitView(queries: queries, breakdowns: viewBreakdowns, situation: current)
        return Run(view: view, mismatches: c.mismatches, notes: c.notes, breakdowns: all)
    }

    /// What an action recorded (its entries, questions and texts) as one breakdown, for the
    /// situation-level lookups and the open rulings it met.
    static func record(_ r: ActionResult) -> Breakdown {
        Breakdown(query: Query("action"), notApplied: r.notApplied, questions: r.questions, texts: r.texts)
    }

    static func describe(_ a: Action) -> String {
        switch a {
        case .cast(let spell, _): "the cast of \(spell)"
        case .settle: "settling"
        default: "the action"
        }
    }

    /// The before/after rule around an action (`CombatRunner.choose`): the breakdown after it when
    /// that differs and reads what it changed (a fact it stated, a rule it gained or cleared).
    static func choose(_ query: String, action r: ActionResult, before: Situation, engine: Engine) -> (Breakdown, Bool) {
        let changed = Set(r.situation.facts.values.filter { before.facts[$0.name] != $0 }.map(\.name))
            .union(r.events.flatMap { e in (e.change ?? [:]).keys.map { "item.\(e.item ?? "").\($0)" } })
        let rules = Set(r.events.compactMap(\.rule))
        return CombatRunner.choose(query, before: before, after: r.situation, changed: changed, rules: rules, check: nil, engine: engine)
    }

    /// A step's statements applied (`CombatRunner.applying`), with the opponent's (`opponent.*`,
    /// the GM's) and the round's (`round.*`) facts too. An item field lands on its instance.
    static func applying(_ step: [String: JSONValue], to situation: Situation) -> (Situation, [Mismatch]) {
        var rest = step
        var s = situation
        // Task 30: `event: { RULE: n }` is the Stufe the hero now has of the rule (kampfwerte
        // 16.12: the plate taken off, Belastung 0), stated as the sheet's `level(rule: RULE)`.
        if let e = rest.removeValue(forKey: "event") {
            guard let levels = e.objectValue, !levels.isEmpty, levels.values.allSatisfy({ $0.int != nil }) else {
                return (situation, [.shape("step event", "step event \(e) is not { rule: Stufe }")])
            }
            for (rule, n) in levels { s.base[Evaluation.levelQuery(rule).description] = n.int! }
        }
        for (key, prefix, owner) in [("opponent", "opponent.", Owner.gm), ("round", "round.", Owner.round)] {
            guard let o = rest.removeValue(forKey: key) else { continue }
            guard let facts = o.objectValue else { return (situation, [.shape("step \(key)", "step \(key) \(o) is not modelled")]) }
            for (name, v) in facts { s.state(Fact(name: prefix + name, value: v, owner: owner)) }
        }
        let (next, shapes) = CombatRunner.applying(rest, to: s)
        var out = next
        // `CombatRunner.applying` writes facts directly; an item field belongs to its instance.
        for f in next.facts.values where Situation.itemFact(f.name) != nil { out.facts[f.name] = nil; out.state(f) }
        return (out, shapes)
    }

    // MARK: - A step's expectations

    static func compare(_ expect: [String: JSONValue], label: String, action: Action?, result r: ActionResult?, before: Situation,
                        stated: Situation, after: Situation, engine: Engine, _ c: inout MatchResult, _ all: inout [Breakdown]) {
        let special: Set<String> = ["events", "process", "success", "texts", "notApplied", "questions", "result", "offered", "notOffered",
                                    "legal"]
        // The step's queries first: its `notApplied`, `texts` and `questions` are looked up in them too.
        var queried: [String: Breakdown] = [:]
        for key in expect.keys.sorted() where !special.contains(key) {
            if let own = r?.breakdowns.first(where: { $0.query.description == key }) {
                queried[key] = own
            } else if let r {
                queried[key] = choose(key, action: r, before: stated, engine: engine).0
            } else {
                queried[key] = engine.evaluate(Query(key), in: after)
            }
        }
        let breakdowns = ((r?.breakdowns ?? []) + (r.map { [record($0)] } ?? []) + queried.keys.sorted().map { queried[$0]! }).distinct()
        for key in expect.keys.sorted() {
            let raw = expect[key]!
            switch key {
            case "events":
                guard let list = raw.arrayValue else { c.mismatches.append(.shape("malformed events", "\(label): events \(raw) is not a list")); continue }
                guard let r else {
                    c.mismatches.append(Mismatch(kind: .missingEvent, detail: "\(label): expected events \(raw), but the step runs no action"))
                    continue
                }
                c.mismatches += events(list, r, before: stated, engine: engine).map { $0.at(label) }
            case "process":
                c.mismatches += process(raw, before: before, after: after, events: r?.events ?? [], book: engine.book).map { $0.at(label) }
            case "success":
                guard case .bool(let want) = raw, case .attack? = action else {
                    c.mismatches.append(.shape("step success", "\(label): success \(raw) of an action that is no attack"))
                    continue
                }
                let got = after.facts["action.attack"]?.value.string.map { $0 == "hit" }
                if got != want {
                    c.mismatches.append(Mismatch(kind: .success, query: r?.breakdowns.first?.query.description,
                                                 detail: "\(label): expected success \(want), got \(got.map(String.init) ?? "none")"))
                }
            case "texts", "notApplied", "questions":
                // Task 31: a step that runs no action and queries nothing states facts only; its
                // entries are the hero sheet's there, and a `notApplied` entry for a rule the sheet
                // does not show is looked up in the targets its clause reaches (ITEMTPL_29.GR2 on `pa`).
                var looked = breakdowns
                if looked.isEmpty {
                    looked = [engine.sheet(in: after)]
                    if key == "notApplied" {
                        let named = (raw.arrayValue ?? []).compactMap(ExpectedNotApplied.init)
                        let targets = engine.book.reach.filter { $0.key != "*" }.filter { entry in
                            entry.value.contains { o in named.contains { $0.rule == o.rule && ($0.clause == nil || $0.clause == o.clause) } }
                        }.keys.sorted()
                        looked += targets.map { engine.evaluate(Query($0), in: after) }
                    }
                }
                let texts = looked.flatMap(\.texts), entries = looked.flatMap(\.notApplied), asked = looked.flatMap(\.questions)
                CombatRunner.compare([key: raw], label: label, events: [], checks: [], texts: texts, notApplied: entries,
                                     questions: asked, success: nil, successQuery: nil, breakdown: { _ in Breakdown(query: Query("none")) }, &c)
            case "offered", "notOffered":
                // Task 30 (R62): as a situation's, against the offers of the step's breakdowns.
                guard let list = raw.arrayValue else { c.mismatches.append(.shape("malformed \(key)", "\(label): \(key) \(raw) is not a list")); continue }
                let pool = breakdowns.flatMap(\.offers)
                let offering = Matcher.offeringClauses(engine.book)
                for entry in list {
                    c.mismatches += Matcher.offer(entry, wanted: key == "offered", in: pool, notApplied: breakdowns.flatMap(\.notApplied),
                                                  offering: offering, book: engine.book).map { $0.at(label) }
                }
            case "legal":
                // Task 31: a situation-level `legal` of a step (19.5's `exclusive`), on the
                // situation the step leaves; the open rulings its combinations met count (R32).
                let view = LegalView.read(raw, in: after, engine: engine)
                all += view?.recorded ?? []
                all += view.map { $0.actions + $0.defences } ?? []
                c.mismatches += Matcher.situationLegal(raw, view).map { $0.at(label) }
            case "result":
                c.mismatches.append(.shape("step result", "\(label): the result of a cast is not modelled (no check procedure runs)"))
            default:
                let b = queried[key]!
                all.append(b)
                CombatRunner.compare([key: raw], label: label, events: [], checks: [], texts: [], notApplied: [], questions: [],
                                     success: nil, successQuery: nil, breakdown: { _ in b }, &c)
            }
        }
    }

    /// `process: { <id>: n | ended, capped: true }` after a step.
    static func process(_ raw: JSONValue, before: Situation, after: Situation, events: [Event], book: RuleBook) -> [Mismatch] {
        guard let o = raw.objectValue else { return [.shape("malformed process", "process \(raw) is not an object")] }
        var out: [Mismatch] = []
        let ids = o.keys.filter { $0 != "capped" }.sorted()
        func names(_ id: String) -> [String] {
            book.rules.values.flatMap { rule in rule.clauses.flatMap(\.effects) }
                .filter { if case .process(let p) = $0.payload { p.id == id } else { false } }
                .map(\.origin.clauseRef.description).sorted()
        }
        for id in ids {
            let want = o[id]!
            let running = after.processes[id]
            if want.string == "ended" {
                if let running {
                    out.append(Mismatch(kind: .process, detail: "expected \(id) ended, it runs at \(running.progress) of \(running.steps)", names: names(id)))
                } else if before.processes[id] == nil {
                    out.append(Mismatch(kind: .process, detail: "expected \(id) ended, but it never ran", names: names(id)))
                }
            } else if let n = want.int {
                if running?.progress != n {
                    out.append(Mismatch(kind: .process, detail: "expected \(id) at \(n), got \(running.map { "\($0.progress) of \($0.steps)" } ?? "none running")",
                                        names: names(id)))
                }
            } else {
                out.append(.shape("malformed process", "process \(id): \(want) is neither a number nor ended"))
            }
            if case .bool(let capped)? = o["capped"] {
                let progressed = events.contains { $0.kind == .progressed && $0.process == id }
                let atCap = running.map { $0.progress >= $0.steps } ?? false
                if capped != (atCap && !progressed) {
                    out.append(Mismatch(kind: .process, detail: "expected \(id) \(capped ? "" : "not ")capped, "
                                        + "got \(progressed ? "progress" : "no progress")\(atCap ? " at its cap" : "")", names: names(id)))
                }
            }
        }
        if ids.isEmpty { out.append(.shape("malformed process", "process \(raw) names no process")) }
        return out
    }

    // MARK: - Events

    /// The expected events against an action's: `after`, several `pools`, `over`, `itemChanged`
    /// here; every other entry as `CombatRunner.events`. A `from` list names one origin per
    /// event: an event has one, so such an entry never matches (MIGRATION conflicts 20.7, 20.8).
    static func events(_ expected: [JSONValue], _ r: ActionResult, before: Situation, engine: Engine) -> [Mismatch] {
        var out: [Mismatch] = []
        var plain: [JSONValue] = []
        var used = Set<Int>()
        for raw in expected {
            guard let o = raw.objectValue else { plain.append(raw); continue }
            if let fromList = o["from"]?.arrayValue {
                out.append(Mismatch(kind: .missingEvent, detail: "expected an event from \(fromList.compactMap(\.string)): an event has one origin",
                                    names: fromList.compactMap(\.string)))
                continue
            }
            if let a = o["after"] {
                out += after(a, r.situation, engine: engine)
                // Task 30: the `from` of an `after` is an event's origin or `via` (the cap R5).
                if let from = o["from"]?.string, !r.events.contains(where: { $0.origin?.description == from || $0.via.contains { $0.description == from } }) {
                    out.append(Mismatch(kind: .missingEvent, detail: "expected the state after from \(from), no event of it", names: [from]))
                }
                continue
            }
            if let item = o["itemChanged"] {
                out += itemChanged(item, o, r.events, &used)
                continue
            }
            if let p = o["paid"]?.objectValue {
                let target = amountTarget(of: o["from"]?.string, pool: p["pool"]?.string, r, book: engine.book)
                out += paid(o, p, r, before: before, &used).map { m in
                    var m = m
                    if m.kind != .unsupportedShape, m.query == nil { m.query = target }
                    return m
                }
                continue
            }
            plain.append(raw)
        }
        if !plain.isEmpty || expected.isEmpty {
            let rest = r.events.indices.filter { !used.contains($0) }.map { r.events[$0] }
            out += CombatRunner.events(plain, events: rest, checks: r.checks, attacks: r.attacks)
        }
        return out
    }

    /// The target a payment's amount reads (`spell.cost`), for R48: an open ruling on that
    /// target's operand chain can explain a payment of another amount, as it explains the
    /// target's own mismatch. From the cost effects of the expected clause, else of the clauses
    /// that paid that pool in the action.
    static func amountTarget(of from: String?, pool: String?, _ r: ActionResult, book: RuleBook) -> String? {
        let clauses: [ClauseRef] = from.flatMap(ClauseRef.init).map { [$0] }
            ?? r.events.filter { $0.kind == .paid && (pool == nil || $0.pool?.rawValue == pool) }.compactMap(\.origin)
        for c in clauses {
            for e in book.rules[c.rule]?.clauses.first(where: { $0.id == c.clause })?.effects ?? [] {
                if case .cost(let cost) = e.payload, let t = cost.amount.targets.first { return t.description }
            }
        }
        return nil
    }

    /// `after: { aspCurrent, leCurrent, conditions, levels, actsAs }`: the pools, the Zustände and
    /// Status (rule → Stufe) the action leaves, and a rule's Stufe (`levels`) and the Stufe it acts
    /// at (`actsAs`) there.
    static func after(_ raw: JSONValue, _ s: Situation, engine: Engine) -> [Mismatch] {
        let book = engine.book
        guard let o = raw.objectValue else { return [.shape("malformed after", "after \(raw) is not an object")] }
        var out: [Mismatch] = []
        for key in o.keys.sorted() {
            switch key {
            case "aspCurrent", "leCurrent":
                let pool: Pool = key == "aspCurrent" ? .asp : .le
                let got = s.pools[pool]?.current
                if got != o[key]!.int {
                    out.append(Mismatch(kind: .missingEvent, query: key, detail: "expected \(key) \(o[key]!) after, got \(got.map(String.init) ?? "none")"))
                }
            case "conditions":
                guard let want = o[key]!.objectValue else { out.append(.shape("malformed after", "after.conditions is not an object")); continue }
                let kinds: Set<RuleKind> = [.condition, .state]
                let have = Dictionary(uniqueKeysWithValues: s.owned.filter { id, _ in
                    book.rules[id].map { kinds.contains($0.kind) } ?? false
                }.map { ($0.key, $0.value.level) })
                let wanted = want.compactMapValues(\.int)
                if have != wanted {
                    out.append(Mismatch(kind: .missingEvent, detail: "expected the Zustände \(wanted) after, got \(have)"))
                }
            case "levels", "actsAs":
                // Task 30: a Stufe the hero has after (the base of `level(rule: X)`) and the one it
                // acts at (its result).
                guard let want = o[key]!.objectValue else { out.append(.shape("malformed after", "after.\(key) is not an object")); continue }
                for (rule, n) in want.sorted(by: { $0.key < $1.key }) {
                    let b = engine.evaluate(Evaluation.levelQuery(rule), in: s)
                    let got = key == "levels" ? b.base?.value : b.result
                    if got != n.int {
                        out.append(Mismatch(kind: .missingEvent, query: Evaluation.levelQuery(rule).description,
                                            detail: "expected \(key) \(rule) \(n) after, got \(got.map(String.init) ?? "none")", names: [rule]))
                    }
                }
            default:
                out.append(.shape("after field \(key)", "after.\(key) is not modelled"))
            }
        }
        return out
    }

    /// `{ itemChanged: loadout.<slot>[.<field>] | …, change, from }`: an `itemChanged` from that
    /// clause changing that field (or every field of `change`, with its value).
    static func itemChanged(_ item: JSONValue, _ o: [String: JSONValue], _ actual: [Event], _ used: inout Set<Int>) -> [Mismatch] {
        guard let name = item.string else { return [.shape("event itemChanged object", "itemChanged \(item) names no slot")] }
        let parts = name.split(separator: ".").map(String.init)
        var fields = (o["change"]?.objectValue ?? [:])
        if parts.count == 3, ItemDelta.fields.contains(parts[2]) { fields[parts[2]] = fields[parts[2]] ?? .null }
        let from = o["from"]?.string, ruling = o["ruling"].map(strings) ?? []
        for key in o.keys.sorted() where !["itemChanged", "change", "from", "ruling"].contains(key) {
            return [.shape("event field \(key)", "itemChanged event: field \(key) is not modelled")]
        }
        let fit = actual.indices.first { i in
            let e = actual[i]
            guard !used.contains(i), e.kind == .itemChanged, from == nil || e.origin?.description == from,
                  ruling.allSatisfy({ Matcher.rulingMatches($0, e.rulings) }) else { return false }
            return fields.allSatisfy { k, v in e.change?[k].map { v == .null || $0 == v } ?? false }
        }
        if let fit { used.insert(fit); return [] }
        let got = actual.filter { $0.kind == .itemChanged }.map { "\($0.item ?? "?") \($0.change ?? [:]) from \($0.origin?.description ?? "–")" }
        return [Mismatch(kind: .missingEvent, detail: "expected itemChanged \(name) \(fields) from \(from ?? "–"), got \(got.isEmpty ? "none" : got.joined(separator: "; "))",
                         names: [from].compactMap { $0 } + ruling)]
    }

    /// A `paid` of several `pools` (the events of one cost, in order: `[{ asp: 3 }, { le: 1 }]`,
    /// summing to `amount`), or `over: { minutes }` (every payment of that pool and origin in the
    /// step, summed, while the clock went on by that much).
    static func paid(_ o: [String: JSONValue], _ p: [String: JSONValue], _ r: ActionResult, before: Situation, _ used: inout Set<Int>) -> [Mismatch] {
        let from = o["from"]?.string, ruling = o["ruling"].map(strings) ?? [], via = o["via"].map(strings) ?? []
        let names = [from].compactMap { $0 } + ruling + via
        // Fix round 2: an unmodelled field is a shape, and the rest is still compared (its ruling).
        let fieldShapes = o.keys.sorted().filter { !["paid", "from", "ruling", "via", "over"].contains($0) }
            .map { Mismatch.shape("event field \($0)", "paid event: field \($0) is not modelled") }
        return fieldShapes + paidFields(o, p, r, before: before, &used)
    }

    private static func paidFields(_ o: [String: JSONValue], _ p: [String: JSONValue], _ r: ActionResult, before: Situation,
                                   _ used: inout Set<Int>) -> [Mismatch] {
        let from = o["from"]?.string, ruling = o["ruling"].map(strings) ?? [], via = o["via"].map(strings) ?? []
        let names = [from].compactMap { $0 } + ruling + via
        let payments = r.events.indices.filter { i in
            let e = r.events[i]
            return !used.contains(i) && e.kind == .paid && (from == nil || e.origin?.description == from)
                && ruling.allSatisfy { Matcher.rulingMatches($0, e.rulings) } && Set(via).isSubset(of: e.via.map(\.description))
        }
        if p["pools"] == nil, o["over"] == nil {
            for key in p.keys.sorted() where !["pool", "amount"].contains(key) {
                return [.shape("paid field \(key)", "paid.\(key) is not modelled")]
            }
            if let i = payments.first(where: { r.events[$0].pool?.rawValue == p["pool"]?.string && r.events[$0].amount == p["amount"]?.int }) {
                used.insert(i)
                return []
            }
            let got = r.events.filter { $0.kind == .paid }.map { "\($0.pool?.rawValue ?? "?") \($0.amount ?? 0) from \($0.origin?.description ?? "–")" }
            return [Mismatch(kind: .missingEvent, detail: "expected paid \(p["amount"] ?? .null) \(p["pool"]?.string ?? "")\(from.map { " from \($0)" } ?? ""), "
                             + "got \(got.isEmpty ? "none" : got.joined(separator: "; "))", names: names)]
        }
        let got = payments.map { "\(r.events[$0].pool?.rawValue ?? "?") \(r.events[$0].amount ?? 0)" }
        if let over = o["over"] {
            guard let minutes = over.objectValue?["minutes"]?.int, over.objectValue?.count == 1 else {
                return [.shape("malformed over", "over \(over) is not { minutes: n }")]
            }
            let pool = p["pool"]?.string
            let mine = payments.filter { pool == nil || r.events[$0].pool?.rawValue == pool }
            let sum = mine.reduce(0) { $0 + (r.events[$1].amount ?? 0) }
            var out: [Mismatch] = []
            if sum != p["amount"]?.int || mine.isEmpty {
                out.append(Mismatch(kind: .missingEvent, detail: "expected \(p["amount"] ?? .null) \(pool ?? "") paid over \(minutes) minutes from \(from ?? "–"), got \(got.isEmpty ? "none" : got.joined(separator: ", "))",
                                    names: names))
            }
            let passed = r.situation.clock.minutes - before.clock.minutes
            if passed != minutes {
                out.append(Mismatch(kind: .missingEvent, detail: "expected \(minutes) minutes to pass, \(passed) passed", names: names))
            }
            mine.forEach { used.insert($0) }
            return out
        }
        guard let pools = p["pools"]?.arrayValue, let amount = p["amount"]?.int else {
            return [.shape("malformed paid", "paid \(p) has no amount and pools")]
        }
        let want: [(String, Int)] = pools.compactMap { entry in
            guard let e = entry.objectValue, e.count == 1, let (k, v) = e.first, let n = v.int else { return nil }
            return (k, n)
        }
        guard want.count == pools.count else { return [.shape("malformed paid", "paid pools \(pools) are not { pool: n }")] }
        // Consecutive payments of one origin, in order.
        for start in payments.indices where start + want.count <= payments.count {
            let run = Array(payments[start..<(start + want.count)])
            let origins = Set(run.map { r.events[$0].origin })
            let fits = origins.count == 1 && zip(run, want).allSatisfy { i, w in r.events[i].pool?.rawValue == w.0 && r.events[i].amount == w.1 }
            if fits, want.reduce(0, { $0 + $1.1 }) == amount {
                run.forEach { used.insert($0) }
                return []
            }
        }
        return [Mismatch(kind: .missingEvent, detail: "expected \(amount) paid as \(want.map { "\($0.0) \($0.1)" }) from \(from ?? "–"), got \(got.isEmpty ? "none" : got.joined(separator: ", "))",
                         names: names)]
    }
}
