import Foundation
@testable import RulesEngine

/// The harness's door to the action layer (Tasks 25–28). A situation that needs something the
/// action layer cannot run yet is reported `unsupported`, not run (its query expectations are
/// still compared, `Matcher.run(onlyQueries:)`).
///
/// Task 26 runs the 3W20 check (`CheckProcedure`): a situation that states a talent or spell
/// check (`check.kind` and `check.talent` / `check.spell`, the Probe's attributes from the Probe table)
/// runs `start`, then `dice(rolls)`, then each `sequence` step that takes a reroll
/// (`choose: { choice.reroll: RULE, choice.rerollDie: n }`, `rolls: { roll.reroll: face }`) as
/// `.reroll`, then `.confirm`. The top-level `fp`, `qs`, `spent`, `success`, `result` and the stage
/// queries are the state after the dice; each step's `expect` the state after its reroll.
///
/// Extension point: a task that makes the action layer run another `Need` adds it to `supported`,
/// widens `canRun`, and matches its expectations here.
enum ActionRunner {
    /// What makes a situation the action layer's: a `sequence`, dice (`rolls` as a list), or a
    /// situation-level expectation of events, check stages or a check's result.
    enum Need: String, CaseIterable, Codable {
        case sequence, rolls, events, fp, qs, spent, success
        /// The situation-level check result (`{success, kind, from}`, Task 26).
        case result
    }

    /// The needs the action layer can run: the 3W20 check's (Task 26). `events` waits for the
    /// procedures of Tasks 27–28.
    static let supported: Set<Need> = [.sequence, .rolls, .fp, .qs, .spent, .success, .result]

    /// The situation-level keys of a check's result the runner compares.
    static let resultKeys: Set<String> = ["fp", "qs", "spent", "success", "result", "dice"]

    /// What `s` needs of the action layer, in `Need` order.
    static func needs(_ s: CompiledSituation) -> [Need] {
        Need.allCases.filter { need in
            switch need {
            case .sequence: !s.sequence.isEmpty
            case .rolls: !s.rolls.isEmpty
            default: s.expectSituation[need.rawValue] != nil
            }
        }
    }

    /// Whether the harness can run all of `s`: nothing of the action layer, or a 3W20 check whose
    /// every need is supported, with one die per attribute when its result is expected, and only
    /// reroll steps in its sequence.
    ///
    /// A check whose Probe the Probe table does not know still runs: its missing row is a mismatch
    /// (`run`), never a silent `unsupported`.
    static func canRun(_ s: CompiledSituation, attributes: [String: [String]] = CheckAttributes.all) -> Bool {
        let n = Set(needs(s))
        guard !n.isEmpty else { return true }
        // Task 31 fix round 1: a check stated with its result only (`rolls: { check.result: … }`)
        // runs as its outcome, and its events are compared.
        // A talent check only (a cast is the state runner's), whose events are no Stufen gained or
        // cleared (settling's, R50).
        if n == [.events], outcome(s) != nil, checkStated(s)?.kind == .talent,
           !(s.expectSituation["events"]?.arrayValue ?? []).contains(where: StateRunner.settles) { return true }
        guard n.isSubset(of: supported), let stated = checkStated(s) else { return false }
        let dice = attributes[stated.id]?.count ?? 3
        if !n.isDisjoint(with: [.rolls, .fp, .qs, .spent, .success, .result, .sequence]), s.rolls.count != dice { return false }
        return s.sequence.allSatisfy { RerollStep($0) != nil }
    }

    /// The result a situation states for its check without dice (`check.result: success | failure`).
    static func outcome(_ s: CompiledSituation) -> Bool? {
        guard s.rolls.isEmpty, s.sequence.isEmpty, let r = s.situation.facts["check.result"]?.value.string else { return nil }
        return r == "success" ? true : r == "failure" ? false : nil
    }

    /// The 3W20 check `s` states: `check.kind` talent (with `check.talent`) or spell (with
    /// `check.spell`). nil for anything else (a liturgy has no id fact).
    static func checkStated(_ s: CompiledSituation) -> (kind: CheckKind, id: String)? {
        let facts = s.situation.facts
        guard let kind = facts["check.kind"]?.value.string.flatMap(CheckKind.init(rawValue:)) else { return nil }
        let id: String?
        switch kind {
        case .talent: id = facts["check.talent"]?.value.string
        case .spell: id = facts["check.spell"]?.value.string
        case .liturgy: id = nil
        }
        return id.map { (kind, $0) }
    }

    /// The check `s` states, with its Probe's attributes from the Probe table; nil without a check or a row.
    static func request(_ s: CompiledSituation, attributes: [String: [String]] = CheckAttributes.all) -> CheckRequest? {
        guard let stated = checkStated(s), let probe = attributes[stated.id] else { return nil }
        return CheckRequest(kind: stated.kind, id: stated.id, attributes: probe)
    }

    /// A `sequence` step that takes a reroll.
    struct RerollStep {
        var rule: String
        /// 1-based, as the situation writes it.
        var die: Int
        var face: Int
        var expect: [String: JSONValue]

        init?(_ json: JSONValue) {
            guard let o = json.objectValue, Set(o.keys).isSubset(of: ["choose", "rolls", "expect"]),
                  let choose = o["choose"]?.objectValue, Set(choose.keys) == ["choice.reroll", "choice.rerollDie"],
                  let rule = choose["choice.reroll"]?.string, let die = choose["choice.rerollDie"]?.int,
                  let rolls = o["rolls"]?.objectValue, Set(rolls.keys) == ["roll.reroll"], let face = rolls["roll.reroll"]?.int
            else { return nil }
            self.rule = rule; self.die = die; self.face = face
            expect = o["expect"]?.objectValue ?? [:]
        }
    }

    /// One run of the check procedure: the view after the dice, the mismatches of the result keys
    /// and of every step, and every breakdown it computed (for the open rulings it met).
    struct CheckRun {
        /// nil when the check could not start (no Probe row).
        var view: ProcedureView?
        var mismatches: [Mismatch]
        var notes: [String]
        var breakdowns: [Breakdown]
    }

    /// Runs `s`'s check when it states one and expects something of it (dice, a stage query);
    /// nil otherwise.
    static func run(_ s: CompiledSituation, engine: Engine, attributes: [String: [String]] = CheckAttributes.all) -> CheckRun? {
        guard let stated = checkStated(s),
              !s.rolls.isEmpty || !needs(s).isEmpty || s.expect.contains(where: { ProcedureView.isStage($0.query) }) else { return nil }
        guard let request = request(s, attributes: attributes) else {
            let m = Mismatch(kind: .checkResult, detail: "the Probe table (checks.yaml) has no row for \(stated.id): the check cannot run")
            return CheckRun(view: nil, mismatches: [m], notes: [], breakdowns: [])
        }
        let start = CheckProcedure.start(request, in: s.engineSituation, engine: engine)
        if let success = outcome(s), let raw = s.expectSituation["events"] {
            // Task 31 fix round 1: the outcome entered, then its events (a check's `onFailure`).
            let out = start.state.step(.outcome(success: success), engine: engine)
            let view = ProcedureView(stages: out.state.stages, result: out.state.result, offers: out.offers)
            let mismatches = raw.arrayValue.map { CombatRunner.events($0, events: out.events, checks: []) }
                ?? [.shape("malformed events", "events \(raw) is not a list")]
            return CheckRun(view: view, mismatches: mismatches, notes: [], breakdowns: start.breakdowns + out.breakdowns)
        }
        var step = start
        var all = start.breakdowns
        var mismatches: [Mismatch] = []
        if !s.rolls.isEmpty {
            step = start.state.step(.dice(s.rolls), engine: engine)
            all += step.breakdowns
            if step.state == start.state {
                mismatches.append(Mismatch(kind: .checkResult, detail: "the dice \(s.rolls) were refused: \(step.texts.map(\.text))"))
            }
        }
        let view = ProcedureView(stages: step.state.stages, result: step.state.result, offers: step.offers)
        var notes: [String] = []
        var c = MatchResult()
        compareResult(s.expectSituation, view, step: nil, &c)
        for (n, raw) in s.sequence.enumerated() {
            guard let reroll = RerollStep(raw) else { continue }
            let label = "step \(n + 1)"
            // The named rule's reroll, never another's: without it the sequence stops here.
            guard let offer = step.offers.first(where: { $0.origin.rule == reroll.rule }) else {
                c.mismatches.append(Mismatch(kind: .missingOffer, query: "check.dice",
                                             detail: "\(label): \(reroll.rule) offers no reroll (offered: \(step.offers.map(\.origin.description)))",
                                             names: [reroll.rule]))
                break
            }
            let next = step.state.step(.reroll(die: reroll.die - 1, face: reroll.face, using: offer.origin), engine: engine)
            guard next.state != step.state else {
                c.mismatches.append(Mismatch(kind: .missingOffer, query: "check.dice",
                                             detail: "\(label): the reroll by \(offer.origin) of W\(reroll.die) was refused: \(next.texts.map(\.text))",
                                             names: [reroll.rule, offer.origin.description]))
                break
            }
            step = next
            all += next.breakdowns
            let after = ProcedureView(stages: step.state.stages, result: step.state.result, offers: step.offers)
            compareStep(reroll.expect, after, label: label, engine: engine, &c)
        }
        let confirmed = step.state.step(.confirm, engine: engine)
        all += confirmed.breakdowns
        mismatches += c.mismatches
        notes += c.notes
        return CheckRun(view: view, mismatches: mismatches, notes: notes, breakdowns: all)
    }

    /// A step's `expect`: the result keys, reroll offers, and any other key as a query of the
    /// state after the step.
    static func compareStep(_ expect: [String: JSONValue], _ view: ProcedureView, label: String, engine: Engine,
                            _ c: inout MatchResult) {
        compareResult(expect, view, step: label, &c)
        for (key, wanted) in [("offered", true), ("notOffered", false)] {
            for entry in expect[key]?.arrayValue ?? [] {
                c.mismatches += Matcher.offer(entry, wanted: wanted, in: [], notApplied: view.breakdowns.flatMap(\.notApplied),
                                              offering: [:], rerolls: view.offers).map { $0.at(label) }
            }
        }
        for key in expect.keys.sorted() where !resultKeys.contains(key) && key != "offered" && key != "notOffered" {
            guard var o = expect[key]?.objectValue else {
                c.mismatches.append(.shape("step \(key)", "\(label): \(key) \(expect[key]!) is not modelled"))
                continue
            }
            o["query"] = .string(key)
            guard let data = try? JSONEncoder().encode(JSONValue.object(o)),
                  let q = try? JSONDecoder().decode(QueryExpectation.self, from: data),
                  let b = view.breakdown(for: key) else {
                c.mismatches.append(.shape("step \(key)", "\(label): \(key) is no stage query of the check"))
                continue
            }
            var one = MatchResult()
            Matcher.query(q, b, values: view.values(for: key), &one)
            c.mismatches += one.mismatches.map { $0.at(label) }
            c.notes += one.notes
        }
    }

    /// `fp`, `qs`, `spent`, `success`, `result {success, kind, from}` and `dice [{die, rolled,
    /// counts, from}]` against the procedure's result.
    static func compareResult(_ expect: [String: JSONValue], _ view: ProcedureView, step: String?, _ c: inout MatchResult) {
        func add(_ kind: Mismatch.Kind, _ query: String, _ detail: String, names: [String] = []) {
            c.mismatches.append(Mismatch(kind: kind, query: query, detail: step.map { "\($0): \(detail)" } ?? detail, names: names))
        }
        let r = view.result
        func show(_ v: Int?) -> String { v.map(String.init) ?? "none" }
        if let fp = expect["fp"] {
            if fp.int == nil { c.mismatches.append(.shape("malformed fp", "fp \(fp) is not a number")) }
            else if r?.fp != fp.int { add(.fp, "check.fp", "expected fp \(fp.int!), got \(show(r?.fp))") }
        }
        if let qs = expect["qs"] {
            if qs.int == nil { c.mismatches.append(.shape("malformed qs", "qs \(qs) is not a number")) }
            else if r?.qs != qs.int { add(.qs, "check.qs", "expected qs \(qs.int!), got \(show(r?.qs))") }
        }
        if let spent = expect["spent"] {
            let want = spent.arrayValue?.compactMap(\.int)
            if want == nil || want?.count != spent.arrayValue?.count {
                c.mismatches.append(.shape("malformed spent", "spent \(spent) is not a list of numbers"))
            } else if r?.spent != want {
                add(.spent, "check.attribute", "expected spent \(want!), got \(r.map { "\($0.spent)" } ?? "none")")
            }
        }
        if let success = expect["success"] {
            if case .bool(let b) = success {
                if r?.success != b { add(.success, "check.fp", "expected success \(b), got \(r?.success.map(String.init) ?? "none")") }
            } else {
                c.mismatches.append(.shape("malformed success", "success \(success) is not a bool"))
            }
        }
        if let result = expect["result"] {
            guard let o = result.objectValue else {
                c.mismatches.append(.shape("malformed result", "result \(result) is not an object"))
                return
            }
            var wrong: [String] = []
            if let s = o["success"] {
                if case .bool(let b) = s, r?.success == b {} else { wrong.append("success \(s)") }
            }
            if let k = o["kind"], k.string != r?.kind.rawValue { wrong.append("kind \(k)") }
            if let f = o["from"], f.string != r?.from?.description { wrong.append("from \(f)") }
            if !wrong.isEmpty {
                add(.checkResult, "check.fp", "expected result \(wrong.joined(separator: ", ")), got success "
                    + "\(r?.success.map(String.init) ?? "none"), kind \(r?.kind.rawValue ?? "none"), from \(r?.from?.description ?? "none")",
                    names: [o["from"]?.string].compactMap { $0 })
            }
            for key in o.keys.sorted() where !["success", "kind", "from"].contains(key) {
                c.mismatches.append(.shape("result field \(key)", "result.\(key) is not modelled"))
            }
        }
        for entry in expect["dice"]?.arrayValue ?? [] {
            guard let o = entry.objectValue, let die = o["die"]?.int else {
                c.mismatches.append(.shape("malformed dice", "dice entry \(entry) has no die"))
                continue
            }
            let i = die - 1
            let names = [o["from"]?.string].compactMap { $0 }
            guard let r, r.faces.indices.contains(i) else {
                add(.dice, "check.dice", "expected W\(die), got no such die", names: names)
                continue
            }
            var wrong: [String] = []
            if let rolled = o["rolled"]?.arrayValue?.compactMap(\.int), rolled != r.rolled[i] { wrong.append("rolled \(rolled) (got \(r.rolled[i]))") }
            if let counts = o["counts"]?.int, counts != r.faces[i] { wrong.append("counts \(counts) (got \(r.faces[i]))") }
            let origin = r.rerolls.last { $0.die == i }?.origin.description
            if let from = o["from"]?.string, from != origin { wrong.append("from \(from) (got \(origin ?? "no reroll"))") }
            if !wrong.isEmpty { add(.dice, "check.dice", "W\(die): expected " + wrong.joined(separator: ", "), names: names) }
            for key in o.keys.sorted() where !["die", "rolled", "counts", "from"].contains(key) {
                c.mismatches.append(.shape("dice field \(key)", "dice.\(key) is not modelled"))
            }
        }
    }
}

/// What the check procedure shows at one point: its stages, its result and the open rerolls.
struct ProcedureView {
    var stages: Stages
    var result: CheckResult?
    var offers: [RerollOffer]

    /// The targets of the check's stages (spec §6).
    static let stageTargets: Set<String> = ["check.attribute", "check.modifier", "check.fw", "check.dice", "check.fp", "check.qs"]

    /// A query only the procedure answers: the attributes (from the rolled-for Probe) and the
    /// stages after the dice.
    static func isStage(_ query: String) -> Bool {
        ["check.attribute", "check.dice", "check.fp", "check.qs"].contains(TargetRef(query).name)
    }

    /// The procedure's breakdown of a stage query: `check.attribute(index: i)`, or the three
    /// joined for `check.attribute` (each carries the same modifier lines once; their legality is
    /// the check's); `check.modifier` / `check.fw` in the check's context; `check.dice`,
    /// `check.fp`, `check.qs` after the dice. nil for anything else.
    func breakdown(for query: String) -> Breakdown? {
        let t = TargetRef(query)
        switch t.name {
        case "check.attribute":
            if let i = t.context["index"].flatMap(Int.init) { return stages.attributes.indices.contains(i) ? stages.attributes[i] : nil }
            guard t.context.isEmpty else { return nil }
            let a = stages.attributes
            return Breakdown(query: Query(t), lines: a.flatMap(\.lines).distinct(), notApplied: a.flatMap(\.notApplied).distinct(),
                             questions: a.flatMap(\.questions).distinct(), texts: a.flatMap(\.texts).distinct(), legal: stages.legal,
                             depthExceeded: a.contains(where: \.depthExceeded))
        case "check.modifier": return t.context.isEmpty || stages.modifier.query.target == t ? stages.modifier : nil
        case "check.fw": return t.context.isEmpty || stages.fw.query.target == t ? stages.fw : nil
        case "check.dice": return result?.dice
        case "check.fp": return result?.fpStage
        case "check.qs": return result?.qsStage
        default: return nil
        }
    }

    /// `values`: the attribute stage's effective values.
    func values(for query: String) -> [Int?]? {
        TargetRef(query).name == "check.attribute" && TargetRef(query).context.isEmpty ? stages.eew : nil
    }

    /// Every breakdown of the check so far.
    var breakdowns: [Breakdown] {
        stages.breakdowns + (result.map { [$0.dice, $0.fpStage, $0.qsStage] } ?? [])
    }
}

extension Mismatch {
    /// The mismatch as one of a sequence step's: the step is named in the detail (the query
    /// stays the stage's, which R41 reads).
    func at(_ step: String) -> Mismatch {
        var m = self
        m.detail = "\(step): \(detail)"
        return m
    }
}
