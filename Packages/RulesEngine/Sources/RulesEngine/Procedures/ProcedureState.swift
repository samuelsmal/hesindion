import Foundation

// A talent, spell or liturgy check (3W20) as a staged procedure (spec §6): start → dice → reroll
// → confirm. Every value here is plain data: the procedure keeps nothing outside the state it
// returns (`CheckProcedure`).

/// The 3W20 check kinds: the values of `check.kind` a `check` selector lists (fertigkeitsproben.FP2).
public enum CheckKind: String, Codable, Hashable, Sendable, CaseIterable { case talent, spell, liturgy }

/// What the caller asks to be checked. The engine reads no database: the three attributes of the
/// Probe are the caller's (rules.db `skill_details` / `spell_details.check_attr_1–3`,
/// fertigkeitsproben.FP1).
public struct CheckRequest: Hashable, Sendable {
    public var kind: CheckKind
    /// The talent, spell or liturgy: `TAL_10`, `SPELL_21`. A talent's is stated as `check.talent`, a
    /// spell's as `check.spell`; its FW is the fact `fw.<id>`.
    public var id: String
    /// The Probe's attributes in rolling order, by the sheet's names (`KL`, `IN`, `IN`): the facts
    /// `attr.<name>`. One die each.
    public var attributes: [String]
    /// The Anwendungsgebiet (`check.application`, fertigkeitsproben.FP8); nil keeps what the
    /// situation states.
    public var application: String?

    public init(kind: CheckKind, id: String, attributes: [String], application: String? = nil) {
        self.kind = kind; self.id = id; self.attributes = attributes; self.application = application
    }
}

/// The stages that exist before the dice (spec §6 `attributes` and `pool`).
public struct Stages: Hashable, Sendable {
    public var request: CheckRequest
    /// The situation as the caller gave it. A `check` effect's `when` (whether a rule asks for this
    /// check: SA_74.VP2 during a cast) is read here.
    public var outer: Situation
    /// `outer` with the check's facts stated: `check.kind`, `check.talent` / `check.spell`,
    /// `check.application`, `fw.current`, and each attribute as the sheet's base of
    /// `check.attribute(index: i)`.
    public var situation: Situation
    /// The one shared `check.modifier` (with the check's `talent:` / `spell:` context): every
    /// Erschwernis and Erleichterung, the GM's modifier (owner gm), Belastung where it reaches.
    public var modifier: Breakdown
    /// `check.attribute(index: i)`, one per die: the attribute, then the modifier's lines.
    public var attributes: [Breakdown]
    /// `check.fw` (with the check's context): the FW and what adds to it (the specialisation).
    public var fw: Breakdown

    public init(request: CheckRequest, outer: Situation, situation: Situation, modifier: Breakdown,
                attributes: [Breakdown], fw: Breakdown) {
        self.request = request; self.outer = outer; self.situation = situation; self.modifier = modifier
        self.attributes = attributes; self.fw = fw
    }

    /// Whether the check may be rolled: no attribute breakdown forbids it (fertigkeitsproben.FP2:
    /// an effective attribute at 0 or below). Every refusing entry, each once.
    public var legal: Legality {
        let reasons = attributes.flatMap(\.legal.reasons).uniqued()
        return Legality(allowed: attributes.allSatisfy(\.legal.allowed), reasons: reasons)
    }

    /// The effective attributes (EEW), nil where one cannot be computed.
    public var eew: [Int?] { attributes.map(\.result) }

    /// Every stage breakdown, in stage order.
    public var breakdowns: [Breakdown] { [modifier] + attributes + [fw] }
}

/// How the result is classified, counted from the faces (spec §6 `result`).
public enum CheckResultKind: String, Codable, Hashable, Sendable, CaseIterable {
    case regular, kritischerErfolg, dreifach1, patzer, dreifach20
}

/// One reroll taken: the die (0-based), its face before and the new face, the face that counts
/// after the reroll's `keep`, and the clause whose `reroll` it was.
public struct RerolledDie: Hashable, Sendable {
    public var die: Int
    public var old: Int
    public var new: Int
    public var counts: Int
    public var origin: ClauseRef

    public init(die: Int, old: Int, new: Int, counts: Int, origin: ClauseRef) {
        self.die = die; self.old = old; self.new = new; self.counts = counts; self.origin = origin
    }
}

/// The result of the dice (spec §6 `dice`, `result`, `quality`).
public struct CheckResult: Hashable, Sendable {
    /// The faces that count, one per attribute; empty for a check that was never rolled (a failed
    /// cast by a `forbid`).
    public var faces: [Int]
    /// Every face each die showed, in order: a rerolled die keeps both.
    public var rolled: [[Int]]
    public var eew: [Int]
    /// FW points spent per die: max(0, face − EEW) (fertigkeitsproben.FP3).
    public var spent: [Int]
    /// `check.fp`'s result: what is left of the FW, floored at 1 on a passed check (QS2).
    public var fp: Int?
    /// `check.qs`'s result; nil on a failed check.
    public var qs: Int?
    /// nil when the FP left cannot be computed and no Doppel-1 / Doppel-20 decides it.
    public var success: Bool?
    public var kind: CheckResultKind
    /// The clause that classifies a Kritischer Erfolg or Patzer (a core rule's clause reading
    /// `check.ones` / `check.twenties`), or the forbid that failed a cast; nil for a regular one.
    public var from: ClauseRef?
    public var ones: Int
    public var twenties: Int
    public var rerolls: [RerolledDie]
    /// Reroll clause → how often it was used in this check (its `max` per `action`).
    public var uses: [ClauseRef: Int]
    /// `check.dice`: one `.rerolled` line per reroll, "W2: 19 → 11, Begabung", `was` the old face,
    /// `now` the face that counts.
    public var dice: Breakdown
    public var fpStage: Breakdown
    public var qsStage: Breakdown
    /// The stages' situation with the result's facts: `check.spent` (derived), `check.ones`,
    /// `check.twenties`, `check.result` (roll).
    public var situation: Situation

    public init(faces: [Int], rolled: [[Int]], eew: [Int], spent: [Int], fp: Int?, qs: Int?, success: Bool?,
                kind: CheckResultKind, from: ClauseRef?, ones: Int, twenties: Int, rerolls: [RerolledDie],
                uses: [ClauseRef: Int], dice: Breakdown, fpStage: Breakdown, qsStage: Breakdown, situation: Situation) {
        self.faces = faces; self.rolled = rolled; self.eew = eew; self.spent = spent; self.fp = fp; self.qs = qs
        self.success = success; self.kind = kind; self.from = from; self.ones = ones; self.twenties = twenties
        self.rerolls = rerolls; self.uses = uses; self.dice = dice; self.fpStage = fpStage; self.qsStage = qsStage
        self.situation = situation
    }
}

/// A `reroll` the player may take now (spec §6 step 2): Begabung, a Schip.
public struct RerollOffer: Hashable, Sendable {
    public var origin: ClauseRef
    /// The rule's name, as the rerolled line names it ("Begabung").
    public var name: String
    /// The dice (0-based) it may reroll.
    public var dice: [Int]
    /// Which face stands: `better` (the lower), `second` (the new one), `first`, `worse`.
    public var keep: String
    /// Uses left in this check (`max` less the uses); nil without a `max`.
    public var remaining: Int?
    public var rulings: [String]
    /// The clauses its rule rests on (its enabling require, the useLevels on it).
    public var via: [ClauseRef]
    /// false when a `forbid` naming its clause or rule fires (ADV_4.B5 on a Doppel-20).
    public var legal: Bool
    /// The first reason's `because`, else its clause.
    public var because: String?
    public var reasons: [NotApplied]

    public init(origin: ClauseRef, name: String, dice: [Int], keep: String, remaining: Int?, rulings: [String] = [],
                via: [ClauseRef] = [], reasons: [NotApplied] = []) {
        self.origin = origin; self.name = name; self.dice = dice; self.keep = keep; self.remaining = remaining
        self.rulings = rulings; self.via = via; self.legal = reasons.isEmpty
        self.because = reasons.first.map { $0.because ?? $0.origin.description }; self.reasons = reasons
    }
}

/// What comes in from outside: the dice, a reroll, a forbid from another check, the confirm.
public enum ProcedureInput: Hashable, Sendable {
    /// The faces, one per attribute, 1–20.
    case dice([Int])
    /// Reroll die `die` (0-based) with the new `face`, by the offer `using` (nil: the first legal
    /// offer that may reroll it).
    case reroll(die: Int, face: Int, using: ClauseRef? = nil)
    /// A check forbidden by another check's consequence (`StepResult.forbidden`, SA_74.VP2's failed
    /// Selbstbeherrschung): read as a failed check, and confirmed at once.
    case forbidden([NotApplied])
    case confirm
}

/// Where a check stands. The state is the whole of it: stepping a copy gives what stepping the
/// original gives.
public enum ProcedureState: Hashable, Sendable {
    case awaitingDice(Stages)
    case rolled(Stages, CheckResult, [RerollOffer])
    case confirmed(Stages, CheckResult, [Event])

    public var stages: Stages {
        switch self {
        case .awaitingDice(let s), .rolled(let s, _, _), .confirmed(let s, _, _): s
        }
    }

    public var result: CheckResult? {
        switch self {
        case .awaitingDice: nil
        case .rolled(_, let r, _), .confirmed(_, let r, _): r
        }
    }

    /// `(state, input) → (state, breakdowns, offers, events)` (spec §6).
    public func step(_ input: ProcedureInput, engine: Engine) -> StepResult {
        CheckProcedure.step(self, input, engine: engine)
    }
}

/// One step's output. An input the state cannot take leaves the state as it was and says why in
/// `texts`.
public struct StepResult: Hashable, Sendable {
    public var state: ProcedureState
    /// The breakdowns this step computed: start the stages, dice and reroll `check.dice`,
    /// `check.fp` and `check.qs`, confirm `check.fp` and `check.qs`.
    public var breakdowns: [Breakdown]
    /// The open rerolls (after dice and reroll), legal or not.
    public var offers: [RerollOffer]
    /// The confirm's events: the costs, the gains of a `check` effect's `onSuccess` / `onFailure`,
    /// `logged` with the QS and every `tell` that reads the result.
    public var events: [Event]
    public var questions: [Question]
    public var texts: [TextLine]
    public var notApplied: [NotApplied]
    /// The `forbid`s on a check kind that a `check` effect's `onSuccess` / `onFailure` gave at the
    /// confirm (SA_74.VP2): the caller hands them to that check as `.forbidden`.
    public var forbidden: [NotApplied]

    public init(state: ProcedureState, breakdowns: [Breakdown] = [], offers: [RerollOffer] = [], events: [Event] = [],
                questions: [Question] = [], texts: [TextLine] = [], notApplied: [NotApplied] = [],
                forbidden: [NotApplied] = []) {
        self.state = state; self.breakdowns = breakdowns; self.offers = offers; self.events = events
        self.questions = questions; self.texts = texts; self.notApplied = notApplied; self.forbidden = forbidden
    }
}
