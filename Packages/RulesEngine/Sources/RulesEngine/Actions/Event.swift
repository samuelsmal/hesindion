import Foundation

/// One change to the state (spec §7), as a plain value. `Situation.applying` is the one place an
/// event changes a `Situation`. Each event carries its origin as a line does: the clause that gave
/// it (nil for the player's own action), the clauses it rests on (`via`), its decided rulings, and
/// the facts its `when` and amount read.
///
/// Which fields a kind fills:
/// - `paid`: `pool`, `amount` (one event per pool: a fall-through or a split gives several);
/// - `gained`: `rule`, `levels` (the Stufen actually added, within the rule's Stufen);
/// - `cleared`: `rule`, `levels` (the Stufen removed, as a positive number; nil: all);
/// - `progressed`, `completed`, `brokenOff`: `process` (Task 28);
/// - `itemChanged`: `item`, `change` (Task 28);
/// - `logged`: `note` (Task 26).
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
    /// As `Line.via`: the enabling require and useLevels of the origin's rule, then the clauses
    /// behind every target its amount read (R26).
    public var via: [ClauseRef]
    public var rulings: [String]
    public var facts: [FactUse]

    public init(kind: EventKind, origin: ClauseRef? = nil, pool: Pool? = nil, amount: Int? = nil, rule: String? = nil,
                levels: Int? = nil, process: String? = nil, item: String? = nil, change: [String: JSONValue]? = nil,
                via: [ClauseRef] = [], rulings: [String] = [], facts: [FactUse] = [], note: String? = nil) {
        self.kind = kind; self.origin = origin; self.pool = pool; self.amount = amount; self.rule = rule
        self.levels = levels; self.process = process; self.item = item; self.change = change; self.note = note
        self.via = via; self.rulings = rulings; self.facts = facts
    }

    enum CodingKeys: String, CodingKey {
        case kind, origin, pool, amount, rule, levels, process, item, change, note, via, rulings, facts
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
        try c.encodeIfPresent(note, forKey: .note)
        if !via.isEmpty { try c.encode(via, forKey: .via) }
        if !rulings.isEmpty { try c.encode(rulings, forKey: .rulings) }
        if !facts.isEmpty { try c.encode(facts, forKey: .facts) }
    }
}

/// What an action gave: its events (not yet applied), the breakdowns of the targets its amounts
/// read (`spell.cost`) or of its procedure's stages, what was asked and shown, every effect that
/// did not act and why (a suppressed cost, an illegal offer, a `when` that is no or unknown), and
/// the checks it calls for.
public struct ActionResult: Hashable, Sendable {
    public var events: [Event]
    public var breakdowns: [Breakdown]
    public var questions: [Question]
    public var texts: [TextLine]
    public var notApplied: [NotApplied]
    /// The checks the action calls for, the caller's to run (`.takeHit`: the Wundeffekt's
    /// Selbstbeherrschung, trefferzonen.TZ8; the rider's Reiten, reiterkampf.RK10).
    public var checks: [PendingCheck]

    public init(events: [Event] = [], breakdowns: [Breakdown] = [], questions: [Question] = [], texts: [TextLine] = [],
                notApplied: [NotApplied] = [], checks: [PendingCheck] = []) {
        self.events = events; self.breakdowns = breakdowns; self.questions = questions; self.texts = texts
        self.notApplied = notApplied; self.checks = checks
    }
}
