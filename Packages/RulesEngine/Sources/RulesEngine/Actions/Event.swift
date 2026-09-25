import Foundation

/// One change to the state (spec §7), as a plain value. `Situation.applying` is the one place an
/// event changes a `Situation`. Each event carries its origin as a line does: the clause that gave
/// it (nil for the player's own action), the clauses it rests on (`via`), its decided rulings, and
/// the facts its `when` and amount read.
///
/// Which fields a kind fills:
/// - `paid`: `pool`, `amount` (one event per pool: a fall-through or a split gives several);
/// - `damaged`: `pool` (`le`), `amount` (the LeP a hit took, from the damage clause:
///   schaden.S2; ruling R53). Damage, unlike `paid`;
/// - `gained`: `rule`, `levels` (the Stufen actually added, within the rule's Stufen), and
///   `span` when the Stufen last only that long (`gain { span }`);
/// - `cleared`: `rule`, `levels` (the Stufen removed, as a positive number; nil: all), `span`
///   as for `gained`;
/// - `progressed`: `process`, `progress` (the steps taken after this one), `steps`, `item` (the
///   instance the process is bound to); the first one starts the process;
/// - `completed`, `brokenOff`: `process` (it ends);
/// - `itemChanged`: `item` (the instance), `change` (each changed field's value after the
///   change), `amount` (for `structurePoints`: the change, `{ of: hit.tp, times: -1 }` → −TP);
/// - `logged`: `note` (Task 26);
/// - `clockAdvanced` (R56): `minutes`, `rounds` (how far the clock moves) and `ends` (the spans
///   that end with it: their facts and choices are cleared, their timed Stufen undone);
/// - `stated` (R56): `fact`, `value`, `owner`: a lasting fact an action sets
///   (`round.previousDefenceCrit`, `action.attack`, a recurring cost's start `upkeep.<rule>.<clause>`,
///   R57). No `value` removes the fact; a JSON `null` states it empty.
public struct Event: Codable, Hashable, Sendable {
    public var kind: EventKind
    public var origin: ClauseRef?
    public var pool: Pool?
    public var amount: Int?
    public var rule: String?
    public var levels: Int?
    public var process: String?
    public var item: String?
    public var change: [String: JSONValue]?
    public var note: String?
    /// `progressed`: the steps taken, the steps the process takes, and the `process` effect's
    /// index in its clause (`origin`), which a clause with two processes of one id needs.
    public var progress: Int?
    public var steps: Int?
    public var index: EffectIndex?
    /// `gained` / `cleared`: how long the change lasts (nil: until changed again).
    public var span: Span?
    /// `clockAdvanced`: the minutes and rounds the clock moves, and the spans that end.
    public var minutes: Int?
    public var rounds: Int?
    public var ends: [Span]
    /// `stated`: the fact, its value (nil: the fact goes) and who states it.
    public var fact: String?
    public var value: JSONValue?
    public var owner: Owner?
    /// As `Line.via`: the enabling require and useLevels of the origin's rule, then the clauses
    /// behind every target its amount read (R26).
    public var via: [ClauseRef]
    public var rulings: [String]
    public var facts: [FactUse]

    public init(kind: EventKind, origin: ClauseRef? = nil, pool: Pool? = nil, amount: Int? = nil, rule: String? = nil,
                levels: Int? = nil, process: String? = nil, item: String? = nil, change: [String: JSONValue]? = nil,
                progress: Int? = nil, steps: Int? = nil, index: EffectIndex? = nil, span: Span? = nil,
                minutes: Int? = nil, rounds: Int? = nil, ends: [Span] = [], fact: String? = nil, value: JSONValue? = nil,
                owner: Owner? = nil,
                via: [ClauseRef] = [], rulings: [String] = [], facts: [FactUse] = [], note: String? = nil) {
        self.kind = kind; self.origin = origin; self.pool = pool; self.amount = amount; self.rule = rule
        self.levels = levels; self.process = process; self.item = item; self.change = change; self.note = note
        self.progress = progress; self.steps = steps; self.index = index; self.span = span
        self.minutes = minutes; self.rounds = rounds; self.ends = ends; self.fact = fact; self.value = value; self.owner = owner
        self.via = via; self.rulings = rulings; self.facts = facts
    }

    enum CodingKeys: String, CodingKey {
        case kind, origin, pool, amount, rule, levels, process, item, change, progress, steps, index, span, minutes, rounds, ends
        case fact, value, owner, note, via, rulings, facts
    }

    /// Absent fields and empty lists may be left out.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(kind: try c.decode(EventKind.self, forKey: .kind),
                  origin: try c.decodeIfPresent(ClauseRef.self, forKey: .origin),
                  pool: try c.decodeIfPresent(Pool.self, forKey: .pool),
                  amount: try c.decodeIfPresent(Int.self, forKey: .amount),
                  rule: try c.decodeIfPresent(String.self, forKey: .rule),
                  levels: try c.decodeIfPresent(Int.self, forKey: .levels),
                  process: try c.decodeIfPresent(String.self, forKey: .process),
                  item: try c.decodeIfPresent(String.self, forKey: .item),
                  change: try c.decodeIfPresent([String: JSONValue].self, forKey: .change),
                  progress: try c.decodeIfPresent(Int.self, forKey: .progress),
                  steps: try c.decodeIfPresent(Int.self, forKey: .steps),
                  index: try c.decodeIfPresent(EffectIndex.self, forKey: .index),
                  span: try c.decodeIfPresent(Span.self, forKey: .span),
                  minutes: try c.decodeIfPresent(Int.self, forKey: .minutes),
                  rounds: try c.decodeIfPresent(Int.self, forKey: .rounds),
                  ends: try c.decodeIfPresent([Span].self, forKey: .ends) ?? [],
                  fact: try c.decodeIfPresent(String.self, forKey: .fact),
                  value: c.contains(.value) ? (try c.decodeNil(forKey: .value) ? .null : c.decode(JSONValue.self, forKey: .value)) : nil,
                  owner: try c.decodeIfPresent(Owner.self, forKey: .owner),
                  via: try c.decodeIfPresent([ClauseRef].self, forKey: .via) ?? [],
                  rulings: try c.decodeIfPresent([String].self, forKey: .rulings) ?? [],
                  facts: try c.decodeIfPresent([FactUse].self, forKey: .facts) ?? [],
                  note: try c.decodeIfPresent(String.self, forKey: .note))
    }

    /// Leaves out what is absent or empty.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(origin, forKey: .origin)
        try c.encodeIfPresent(pool, forKey: .pool)
        try c.encodeIfPresent(amount, forKey: .amount)
        try c.encodeIfPresent(rule, forKey: .rule)
        try c.encodeIfPresent(levels, forKey: .levels)
        try c.encodeIfPresent(process, forKey: .process)
        try c.encodeIfPresent(item, forKey: .item)
        try c.encodeIfPresent(change, forKey: .change)
        try c.encodeIfPresent(progress, forKey: .progress)
        try c.encodeIfPresent(steps, forKey: .steps)
        try c.encodeIfPresent(index, forKey: .index)
        try c.encodeIfPresent(span, forKey: .span)
        try c.encodeIfPresent(minutes, forKey: .minutes)
        try c.encodeIfPresent(rounds, forKey: .rounds)
        if !ends.isEmpty { try c.encode(ends, forKey: .ends) }
        try c.encodeIfPresent(fact, forKey: .fact)
        try c.encodeIfPresent(value, forKey: .value)
        try c.encodeIfPresent(owner, forKey: .owner)
        try c.encodeIfPresent(note, forKey: .note)
        if !via.isEmpty { try c.encode(via, forKey: .via) }
        if !rulings.isEmpty { try c.encode(rulings, forKey: .rulings) }
        if !facts.isEmpty { try c.encode(facts, forKey: .facts) }
    }
}

/// What an action gave: its events, the situation they leave, the breakdowns of the targets its
/// amounts read (`spell.cost`) or of its procedure's stages, what was asked and shown, every
/// effect that did not act and why (a suppressed cost, an illegal offer, a `when` that is no or
/// unknown), and the checks it calls for.
public struct ActionResult: Hashable, Sendable {
    public var events: [Event]
    /// The situation after the action: what it stated (a cast's `check.spell`, a roll's
    /// `roll.attack` and `action.attack`, a hit's `hit.*`, the clock it advanced) with its events
    /// applied (`applying(_:book:)`). The next action starts from it, so a roll's state
    /// (`round.previousDefenceCrit`, `action.attack`) carries across `perform` calls.
    public var situation: Situation
    public var breakdowns: [Breakdown]
    public var questions: [Question]
    public var texts: [TextLine]
    public var notApplied: [NotApplied]
    /// The checks the action calls for, the caller's to run (`.takeHit`: the Wundeffekt's
    /// Selbstbeherrschung, trefferzonen.TZ8; the rider's Reiten, reiterkampf.RK10).
    public var checks: [PendingCheck]

    public init(events: [Event] = [], situation: Situation, breakdowns: [Breakdown] = [], questions: [Question] = [],
                texts: [TextLine] = [], notApplied: [NotApplied] = [], checks: [PendingCheck] = []) {
        self.events = events; self.situation = situation; self.breakdowns = breakdowns; self.questions = questions
        self.texts = texts; self.notApplied = notApplied; self.checks = checks
    }
}
