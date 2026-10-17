import Foundation

// A combat roll (1W20) as the state machine of spec §6: target → dice → result → consequence.
// The target is a query (`at`, `fk`, `pa`, `aw`), so rules hook in with the ordinary verbs; a
// 1 or a 20 is confirmed by a second die, itself a check on the same target, which runs the
// rules' `check { of: { check: confirm } }` consequences. Dice come in; the engine never rolls.

/// The defence a combat roll is made for.
public enum DefenceKind: String, Codable, Hashable, Sendable, CaseIterable { case pa, aw }

/// What is rolled for.
public enum CombatRequest: Hashable, Sendable {
    /// The hero's attack, with the piece `with` names (the query's `with:` context, stated as
    /// `action.with`): `fk` when the weapon in hand is a ranged one (`loadout.weapon.kind:
    /// ranged`), else `at`.
    case attack(with: String? = nil)
    /// The hero's defence: `pa(with: …)` (a parry with `shield` is the shield parry,
    /// `action.defence: shieldParry`; any other the weapon parry) or `aw`.
    case defend(kind: DefenceKind, with: String? = nil)

    var isAttack: Bool { if case .attack = self { true } else { false } }
    var with: String? {
        switch self {
        case .attack(let w), .defend(_, let w): w
        }
    }
    /// The roll fact the die is stated as (MIGRATION "Notes for the engine tasks", fernkampf.FK13).
    var rollFact: String { isAttack ? "roll.attack" : "roll.defence" }
}

/// The stage before the dice: the target.
public struct CombatStages: Hashable, Sendable {
    public var request: CombatRequest
    /// The situation as the caller gave it.
    public var outer: Situation
    /// `outer` with the declaration stated (`action.defence`, `action.with`) and an earlier roll's
    /// facts cleared.
    public var situation: Situation
    /// The §5 breakdown of AT, FK, PA or AW the die is rolled against.
    public var target: Breakdown

    public init(request: CombatRequest, outer: Situation, situation: Situation, target: Breakdown) {
        self.request = request; self.outer = outer; self.situation = situation; self.target = target
    }
}

/// The second die a 1 or a 20 asks for: a check on the same target.
public struct Confirmation: Hashable, Sendable {
    /// What it would confirm: `kritischerErfolg` (a 1) or `patzer` (a 20).
    public var of: CheckResultKind
    /// The rules' confirm checks (`check { of: { check: confirm, with: <target> } }`) whose `when`
    /// holds for this die (fernkampf.FK13 on a shot's 1), in rule-id and clause order.
    public var checks: [ClauseRef]
    /// The confirming die, once rolled.
    public var face: Int?
    /// Whether the confirmation check succeeded (at or below the target; a 1 always, a 20 never).
    public var success: Bool?

    public init(of: CheckResultKind, checks: [ClauseRef], face: Int? = nil, success: Bool? = nil) {
        self.of = of; self.checks = checks; self.face = face; self.success = success
    }
}

/// The result of the die (spec §6 `result`).
public struct CombatResult: Hashable, Sendable {
    public var face: Int
    /// The target's result the die was compared with; nil when it cannot be computed.
    public var value: Int?
    /// A 1 succeeds and a 20 fails whatever the target (passierschlag.passierschlag-dice); any
    /// other face succeeds at or below it. nil when the target is unknown.
    public var success: Bool?
    /// The confirmation a 1 or a 20 needs; nil when none is needed, or a rule forbids the critical
    /// result it would confirm (passierschlag.PS4).
    public var confirmation: Confirmation?
    /// `regular` until a confirmation decides: a confirmed 1 is `kritischerErfolg`, a 20 whose
    /// confirmation fails `patzer` (fernkampf.FK14: "the failed confirmation is the Patzer").
    public var kind: CheckResultKind
    /// The rules' confirm check that classified it, when one did.
    public var from: ClauseRef?
    /// The situation after the die: the roll fact (`roll.attack` / `roll.defence`), the attack's
    /// outcome (`action.attack: hit | miss | confirmedFumble`), a defence's crit for the next one
    /// (`round.previousDefenceCrit`). The confirmation's value consequences are not in it: they
    /// act on this roll's `consequence` only.
    public var situation: Situation

    public init(face: Int, value: Int?, success: Bool?, confirmation: Confirmation?, kind: CheckResultKind = .regular,
                from: ClauseRef? = nil, situation: Situation) {
        self.face = face; self.value = value; self.success = success; self.confirmation = confirmation
        self.kind = kind; self.from = from; self.situation = situation
    }
}

/// What comes in: the die, then the confirming die.
public enum CombatInput: Hashable, Sendable {
    /// One face, 1–20.
    case dice([Int])
    /// The confirmation's face, 1–20.
    case confirm(Int)
}

/// Where a combat roll stands; the whole of it, so a copy steps like the original.
public enum CombatState: Hashable, Sendable {
    case awaitingDice(CombatStages)
    case awaitingConfirmation(CombatStages, CombatResult)
    case resolved(CombatStages, CombatResult, [Event])

    public var stages: CombatStages {
        switch self {
        case .awaitingDice(let s), .awaitingConfirmation(let s, _), .resolved(let s, _, _): s
        }
    }

    public var result: CombatResult? {
        switch self {
        case .awaitingDice: nil
        case .awaitingConfirmation(_, let r), .resolved(_, let r, _): r
        }
    }

    /// `(state, input) → (state, breakdowns, events)` (spec §6).
    public func step(_ input: CombatInput, engine: Engine) -> CombatStep {
        CombatRoll.step(self, input, engine: engine)
    }
}

/// One step's output. An input the state cannot take leaves the state as it was and says why.
public struct CombatStep: Hashable, Sendable {
    public var state: CombatState
    /// The breakdowns this step computed: start the target; a resolved attack that hit its
    /// consequence.
    public var breakdowns: [Breakdown]
    /// The confirmation's consequences as events: costs and gains, a `tell` logged.
    public var events: [Event]
    public var questions: [Question]
    public var texts: [TextLine]
    public var notApplied: [NotApplied]
    /// The situation this step leaves for what follows (`CombatResult.situation`; before the
    /// dice, the stage's).
    public var situation: Situation
    /// The consequence stage of an attack that hit: `tp` (with the attack's `with:`) in `situation`,
    /// the confirmation's consequences included (fernkampf.FK13's doubling). The damage the target
    /// takes is its side's (the opponent is not modelled); the hero's own hit is `DamageChain`.
    public var consequence: Breakdown?

    public init(state: CombatState, breakdowns: [Breakdown] = [], events: [Event] = [], questions: [Question] = [],
                texts: [TextLine] = [], notApplied: [NotApplied] = [], situation: Situation, consequence: Breakdown? = nil) {
        self.state = state; self.breakdowns = breakdowns; self.events = events; self.questions = questions
        self.texts = texts; self.notApplied = notApplied; self.situation = situation; self.consequence = consequence
    }

    mutating func gather(_ more: [Breakdown]) {
        breakdowns += more
        questions = CheckProcedure.mergeQuestions(questions + more.flatMap(\.questions))
        texts = (texts + more.flatMap(\.texts)).uniqued()
        notApplied = (notApplied + more.flatMap(\.notApplied)).uniqued()
    }
}

/// An attack or a defence the situation offers, with its target and whether it may be taken.
public struct CombatOption: Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable { case attack, defence }
    public var kind: Kind
    /// `melee` / `ranged` (the attack with the weapon in hand), the piece of an `attackWith` offer
    /// (`shield`); `weaponParry` (with the weapon, or a hand of a `parryWith` offer), `shieldParry`,
    /// `aw`.
    public var id: String
    public var request: CombatRequest
    /// The offer that makes it available (schilde.SCH3's shield parry, SCH2's attack with the
    /// shield); nil for the attack with the weapon in hand, the weapon parry and the dodge.
    public var origin: ClauseRef?
    public var target: Breakdown
    /// false when the target's legality or the offer refuses it; every entry in `reasons`.
    public var legal: Bool
    public var reasons: [NotApplied]

    public init(kind: Kind, id: String, request: CombatRequest, origin: ClauseRef?, target: Breakdown, reasons: [NotApplied]) {
        self.kind = kind; self.id = id; self.request = request; self.origin = origin; self.target = target
        self.legal = reasons.isEmpty; self.reasons = reasons
    }
}

public enum CombatRoll {
    /// The target stage, awaiting the die (spec §6 `target`).
    public static func start(_ request: CombatRequest, in situation: Situation, engine: Engine) -> CombatStep {
        var s = situation
        s.inForce = []                                            // an earlier action's consequences are not this one's
        func state(_ name: String, _ value: JSONValue, _ owner: Owner) { s.facts[name] = Fact(name: name, value: value, owner: owner) }
        // An earlier roll's die and outcome are not this one's.
        s.facts[request.rollFact] = nil
        if request.isAttack { s.facts["action.attack"] = nil }
        if case .defend(let kind, let with) = request {
            state("action.defence", .string(kind == .aw ? "aw" : with == "shield" ? "shieldParry" : "weaponParry"), .player)
        }
        if let with = request.with { state("action.with", .string(with), .player) }
        let target = engine.evaluate(targetQuery(request, in: s), in: s)
        let stages = CombatStages(request: request, outer: situation, situation: s, target: target)
        var out = CombatStep(state: .awaitingDice(stages), situation: s)
        out.gather([target])
        return out
    }

    /// One step: `.dice` on a roll awaiting its die gives the result (and the confirmation a 1 or
    /// a 20 needs); `.confirm` on one awaiting its confirmation resolves it.
    public static func step(_ state: CombatState, _ input: CombatInput, engine: Engine) -> CombatStep {
        switch (state, input) {
        case (.awaitingDice(let stages), .dice(let faces)):
            return roll(stages, faces, state, engine)
        case (.awaitingConfirmation(let stages, let result), .confirm(let face)):
            return confirm(stages, result, face, state, engine)
        case (.awaitingDice, .confirm):
            return refuse(state, "erst der Wurf (1W20)")
        case (.awaitingConfirmation, .dice):
            return refuse(state, "der Wurf ist gefallen; es fehlt die Bestätigung")
        case (.resolved, _):
            return refuse(state, "der Wurf ist schon entschieden")
        }
    }

    /// The action layer's `.attack` / `.defend`: start, and with the situation's `rolls` the die
    /// (the first) and the confirmation (the second) when one is needed.
    static func perform(_ request: CombatRequest, in situation: Situation, engine: Engine) -> ActionResult {
        var steps = [start(request, in: situation, engine: engine)]
        if let face = situation.rolls.first {
            steps.append(steps[0].state.step(.dice([face]), engine: engine))
            if case .awaitingConfirmation = steps[1].state, situation.rolls.count > 1 {
                steps.append(steps[1].state.step(.confirm(situation.rolls[1]), engine: engine))
            }
        }
        let events = steps.flatMap(\.events)
        return ActionResult(events: events, situation: steps[steps.count - 1].situation.applying(events, book: engine.book),
                            breakdowns: steps.flatMap(\.breakdowns),
                            questions: CheckProcedure.mergeQuestions(steps.flatMap(\.questions)),
                            texts: steps.flatMap(\.texts).uniqued(), notApplied: steps.flatMap(\.notApplied).uniqued())
    }

    /// The query a request is rolled against.
    static func targetQuery(_ request: CombatRequest, in s: Situation) -> Query {
        let context = request.with.map { ["with": $0] } ?? [:]
        switch request {
        case .attack:
            let ranged = s.facts["loadout.weapon.kind"]?.value == .string("ranged")
            return Query(TargetRef(name: ranged ? "fk" : "at", context: context))
        case .defend(let kind, _):
            return Query(TargetRef(name: kind.rawValue, context: context))
        }
    }

    private static func refuse(_ state: CombatState, _ why: String) -> CombatStep {
        CombatStep(state: state, texts: [TextLine(kind: .notApplicable, text: "Schritt nicht möglich: \(why)")],
                   situation: state.result?.situation ?? state.stages.situation)
    }

    /// Who `action.attack` (the attack's outcome, R37) is stated by: the vocabulary's owner of the
    /// fact, as a situation states it in `choose`.
    static let outcomeOwner: Owner = Vocabulary.owner(ofFact: "action.attack") ?? .player

    /// A 1 always succeeds, a 20 always fails; any other face at or below the value.
    static func succeeds(_ face: Int, against value: Int?) -> Bool? {
        switch face {
        case 1: true
        case 20: false
        default: value.map { face <= $0 }
        }
    }

    // MARK: - dice

    private static func roll(_ stages: CombatStages, _ faces: [Int], _ state: CombatState, _ engine: Engine) -> CombatStep {
        guard faces.count == 1, let face = faces.first else { return refuse(state, "1 Würfel erwartet, \(faces.count) erhalten") }
        guard (1...20).contains(face) else { return refuse(state, "ein W20 zeigt 1 bis 20, nicht \(face)") }
        guard stages.target.legal.allowed else {
            let why = stages.target.legal.reasons.map { "\($0.origin)" + ($0.because.map { " (\($0))" } ?? "") }
            return refuse(state, "\(stages.target.query) ist nicht erlaubt: " + why.joined(separator: ", "))
        }
        var s = stages.situation
        func put(_ name: String, _ value: JSONValue, _ owner: Owner) { s.facts[name] = Fact(name: name, value: value, owner: owner) }
        put(stages.request.rollFact, .int(face), .roll)
        let value = stages.target.result
        let success = succeeds(face, against: value)
        if stages.request.isAttack, let success { put("action.attack", .string(success ? "hit" : "miss"), outcomeOwner) }
        // A defence reads the crit of the one before it (fernkampf.FK17), then it is used up.
        if !stages.request.isAttack { s.facts["round.previousDefenceCrit"] = nil }

        var records = PipelineState(query: stages.target.query, depth: 0, candidates: [])
        records.local = [:]
        var confirmation: Confirmation?
        if face == 1 || face == 20 {
            let of: CheckResultKind = face == 1 ? .kritischerErfolg : .patzer
            let forbids = criticalForbids(of, in: s, engine, &records)
            if forbids.isEmpty {
                let checks = confirmChecks(stages, in: s, engine, &records)
                confirmation = Confirmation(of: of, checks: checks.map(\.origin.clauseRef))
            } else {
                forbids.forEach { records.record($0) }
            }
        }
        let result = CombatResult(face: face, value: value, success: success, confirmation: confirmation, situation: s)
        var out: CombatStep
        if confirmation != nil {
            out = CombatStep(state: .awaitingConfirmation(stages, result), situation: s)
        } else {
            out = resolved(stages, result, events: [], engine)
        }
        out.questions = CheckProcedure.mergeQuestions(out.questions + records.questions)
        out.texts = (out.texts + records.texts).uniqued()
        out.notApplied = (out.notApplied + records.notApplied).uniqued()
        return out
    }

    /// The `forbid`s of a critical result (`forbid { what: { check: [kritischerErfolg, patzer] } }`,
    /// passierschlag.PS4) that fire here: no confirmation is rolled for it.
    static func criticalForbids(_ kind: CheckResultKind, in s: Situation, _ engine: Engine,
                                _ records: inout PipelineState) -> [NotApplied] {
        let evaluation = engine.evaluation(s)
        var out: [NotApplied] = []
        for e in topLevel(engine.book) {
            guard case .forbid(let f) = e.payload, f.together != true, f.what.kind == .check,
                  f.what.ids.compactMap(\.id).contains(kind.rawValue), evaluation.applies(e, &records),
                  !evaluation.isSuppressed(e, &records) else { continue }
            let rule = e.origin.rule
            let via = evaluation.ruleVia(rule, records)
            guard let used = evaluation.gate(e, level: evaluation.ruleLevel(rule, levels: [:], depth: 0), via: via, &records)
            else { continue }
            out.append(NotApplied(origin: e.origin.clauseRef, reason: .forbidden, because: e.because, rulings: e.ruling,
                                  facts: used, via: via))
        }
        return out
    }

    /// The rules' confirm checks for this roll: top-level `check { of: { check: confirm, with } }`
    /// whose `with` names the target (or is absent), whose rule applies and whose `when` holds
    /// with the die stated.
    static func confirmChecks(_ stages: CombatStages, in s: Situation, _ engine: Engine,
                              _ records: inout PipelineState) -> [Effect] {
        let evaluation = engine.evaluation(s)
        let target = stages.target.query.name
        var out: [Effect] = []
        for e in topLevel(engine.book) {
            guard case .check(let c) = e.payload, c.of.kind == .check, c.of.ids.compactMap(\.id).contains("confirm"),
                  c.of.with.map({ $0.contains(target) }) ?? true,
                  evaluation.applies(e, &records), !evaluation.isSuppressed(e, &records) else { continue }
            let rule = e.origin.rule
            guard evaluation.gate(e, level: evaluation.ruleLevel(rule, levels: [:], depth: 0),
                                  via: evaluation.ruleVia(rule, records), &records) != nil else { continue }
            out.append(e)
        }
        return out
    }

    static func topLevel(_ book: RuleBook) -> [Effect] {
        book.rules.keys.sorted(by: Evaluation.idOrder).flatMap { book.rules[$0]!.clauses.flatMap(\.effects) }
    }

    // MARK: - confirm

    /// The confirmation is a check on the same target (spec §6). A confirmed 1 is a Kritischer
    /// Erfolg, a 20 whose confirmation fails a Patzer; otherwise the die's own result stands. Each
    /// of the rules' confirm checks runs its `onSuccess` or `onFailure` for this roll: costs and
    /// gains through the action layer, a `tell` shown and logged, a value effect in force for this
    /// roll's consequence stage (`Situation.inForce`), and for nothing after it.
    private static func confirm(_ stages: CombatStages, _ result: CombatResult, _ face: Int, _ state: CombatState,
                                _ engine: Engine) -> CombatStep {
        guard (1...20).contains(face) else { return refuse(state, "ein W20 zeigt 1 bis 20, nicht \(face)") }
        guard var confirmation = result.confirmation else { return refuse(state, "keine Bestätigung offen") }
        guard let success = succeeds(face, against: result.value) else {
            return refuse(state, "die Bestätigung ist nicht zu entscheiden: \(stages.target.query) unbekannt")
        }
        confirmation.face = face
        confirmation.success = success
        var r = result
        r.confirmation = confirmation
        r.kind = switch confirmation.of {
        case .kritischerErfolg where success: .kritischerErfolg
        case .patzer where !success: .patzer
        default: .regular
        }
        var s = result.situation
        func put(_ name: String, _ value: JSONValue, _ owner: Owner) { s.facts[name] = Fact(name: name, value: value, owner: owner) }
        if stages.request.isAttack, r.kind == .patzer { put("action.attack", .string("confirmedFumble"), outcomeOwner) }
        if !stages.request.isAttack, confirmation.of == .kritischerErfolg {
            put("round.previousDefenceCrit", .string(success ? "confirmed" : "unconfirmed"), .round)
        }

        var records = PipelineState(query: stages.target.query, depth: 0, candidates: [])
        records.local = [:]
        let checks = confirmChecks(stages, in: result.situation, engine, &records)
        r.from = checks.first?.origin.clauseRef
        let consequences = checks.flatMap { e -> [Effect] in
            guard case .check(let c) = e.payload else { return [] }
            return success ? c.onSuccess : c.onFailure
        }
        // Value consequences act on this roll's consequence stage only ("für diesen Angriff"):
        // they are not part of the situation the step leaves.
        var inForce = s
        inForce.inForce = consequences.filter {
            switch $0.payload {
            case .add, .set, .multiply, .cap, .floor: true
            default: false
            }
        }
        let evaluation = engine.evaluation(s)
        let actions = consequences.filter {
            switch $0.payload {
            case .cost, .gain: true
            default: false
            }
        }
        var run = evaluation.actionRun(controlling: actions)
        evaluation.run(actions, &run)
        for e in consequences {
            switch e.payload {
            case .add, .set, .multiply, .cap, .floor, .cost, .gain:
                continue
            case .tell(let t):
                guard evaluation.applies(e, &run.pipeline), !evaluation.isSuppressed(e, &run.pipeline) else { continue }
                let rule = e.origin.rule
                let via = evaluation.ruleVia(rule, run.pipeline)
                guard let used = evaluation.gate(e, level: evaluation.ruleLevel(rule, levels: [:], depth: 0), via: via,
                                                 &run.pipeline, asking: false) else { continue }
                run.pipeline.show(TextLine(kind: .tell, audience: t.to, text: t.text, origin: e.origin.clauseRef))
                run.events.append(Event(kind: .logged, origin: e.origin.clauseRef, via: via, rulings: evaluation.decided(e),
                                        facts: used, note: t.text))
            default:
                evaluation.fail(e, "\(e.payload.verb.rawValue) nach einer Bestätigung wird nicht ausgeführt", &run.pipeline)
            }
        }
        r.situation = s
        var out = resolved(stages, r, events: run.events, consequencesIn: inForce, engine)
        out.questions = CheckProcedure.mergeQuestions(out.questions + records.questions + run.pipeline.questions)
        out.texts = (out.texts + records.texts + run.pipeline.texts).uniqued()
        out.notApplied = (out.notApplied + records.notApplied + run.pipeline.notApplied).uniqued()
        return out
    }

    /// The resolved state, with an attack's consequence stage when it hit.
    /// The consequence is evaluated in `consequencesIn` (the result's situation with the
    /// confirmation's value consequences in force), never returned with them.
    private static func resolved(_ stages: CombatStages, _ result: CombatResult, events: [Event],
                                 consequencesIn: Situation? = nil, _ engine: Engine) -> CombatStep {
        var out = CombatStep(state: .resolved(stages, result, events), events: events, situation: result.situation)
        if stages.request.isAttack, result.success == true {
            let tp = engine.evaluate(Query(TargetRef(name: "tp", context: stages.request.with.map { ["with": $0] } ?? [:])),
                                     in: consequencesIn ?? result.situation)
            out.consequence = tp
            out.gather([tp])
        }
        return out
    }

    // MARK: - What may be rolled

    /// The attacks and defences `situation` offers, each with its target breakdown and whether it
    /// may be taken (MIGRATION "Notes for the engine tasks", schilde.SCH2/SCH3: a choice that picks
    /// the piece or the defence is the action's `with:` / `action.defence`, listed as the action
    /// layer's entry):
    /// - the attack with the weapon in hand (`melee` → `at`, `ranged` → `fk`), then one per option
    ///   of an `attackWith` offer (`at(with: shield)`, schilde.SCH2);
    /// - the weapon parry (`pa(with: weapon)`), then one per hand of a `parryWith` offer
    ///   (`pa(with: offHand)`, beidhaendiger-kampf.ZW7), each offer whose choice is a defence (the
    ///   shield parry `pa(with: shield)`, schilde.SCH3), and the dodge (`aw`).
    ///
    /// An option is refused by its target's legality (a `forbid` naming it: GK4, PS2, SCH8, FK3,
    /// FK10) and by its offer's.
    public static func options(in situation: Situation, engine: Engine) -> [CombatOption] {
        let offers = engine.offers(in: situation)
        func option(_ kind: CombatOption.Kind, _ id: String, _ request: CombatRequest, from offer: OfferedChoice?,
                    refused: [NotApplied] = []) -> CombatOption {
            var s = situation
            if case .defend(let k, let with) = request {
                let declared = k == .aw ? "aw" : with == "shield" ? "shieldParry" : "weaponParry"
                s.facts["action.defence"] = Fact(name: "action.defence", value: .string(declared), owner: .player)
            }
            let target = engine.evaluate(targetQuery(request, in: s), in: s)
            let reasons = (offer?.reasons ?? []) + refused + target.legal.reasons
            return CombatOption(kind: kind, id: id, request: request, origin: offer?.origin, target: target, reasons: reasons.uniqued())
        }
        var out: [CombatOption] = []
        let ranged = situation.facts["loadout.weapon.kind"]?.value == .string("ranged")
        out.append(option(.attack, ranged ? "ranged" : "melee", .attack(), from: nil))
        for offer in offers where offer.choice == "attackWith" {
            for piece in offer.options?.compactMap(\.string) ?? [] {
                let refused = offer.refused.first { $0.option == .string(piece) }?.reasons ?? []
                out.append(option(.attack, piece, .attack(with: piece), from: offer, refused: refused))
            }
        }
        out.append(option(.defence, "weaponParry", .defend(kind: .pa, with: "weapon"), from: nil))
        for offer in offers where offer.choice == "parryWith" {
            for hand in offer.options?.compactMap(\.string) ?? [] {
                let refused = offer.refused.first { $0.option == .string(hand) }?.reasons ?? []
                out.append(option(.defence, "weaponParry", .defend(kind: .pa, with: hand), from: offer, refused: refused))
            }
        }
        for offer in offers {
            guard let target = Evaluation.defenceTarget(offer.choice), offer.choice != "aw", offer.choice != "weaponParry" else { continue }
            let kind = DefenceKind(rawValue: target) ?? .pa
            let piece = offer.choice.lowercased().hasPrefix("shield") || offer.choice.lowercased().hasPrefix("schild") ? "shield" : nil
            out.append(option(.defence, offer.choice, .defend(kind: kind, with: kind == .pa ? piece : nil), from: offer))
        }
        out.append(option(.defence, "aw", .defend(kind: .aw), from: nil))
        return out
    }
}
