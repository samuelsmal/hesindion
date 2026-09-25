import Foundation

// What is known (spec §4.6): the rules the hero owns, the facts each with its owner, the base
// values the sheet states, and the dice. A fact nobody has stated is unknown, never false.

/// A rule the hero owns: its Stufe and what the hero file chose for it (`{sid: n}` → `option`,
/// `sid2` → `option2`; a string or a number in the JSON).
public struct OwnedRule: Codable, Hashable, Sendable {
    public var level: Int
    public var option: JSONValue?
    public var option2: JSONValue?

    public init(level: Int = 1, option: JSONValue? = nil, option2: JSONValue? = nil) {
        self.level = level; self.option = option; self.option2 = option2
    }
}

/// One stated fact: `{"name", "value", "owner"}`, as `situations.json` writes it.
public struct Fact: Codable, Hashable, Sendable {
    public var name: String
    /// A stated `null` is known: `loadout.weapon: null` is an empty hand.
    public var value: JSONValue
    public var owner: Owner

    public init(name: String, value: JSONValue, owner: Owner) {
        self.name = name; self.value = value; self.owner = owner
    }
}

/// A fact an evaluation read, with the value it had and who stated it.
public struct FactUse: Codable, Hashable, Sendable {
    public var name: String
    public var value: JSONValue
    public var owner: Owner

    public init(name: String, value: JSONValue, owner: Owner) {
        self.name = name; self.value = value; self.owner = owner
    }
}

/// A fact an evaluation needed and nobody stated; `owner` (from `Vocabulary.owner(ofFact:)`)
/// is who would be asked. nil only for a name outside the vocabulary.
public struct UnknownFact: Codable, Hashable, Sendable {
    public var name: String
    public var owner: Owner?

    public init(name: String, owner: Owner?) { self.name = name; self.owner = owner }
    init(_ name: String) { self.init(name: name, owner: Vocabulary.owner(ofFact: name)) }
}

public struct PoolState: Codable, Hashable, Sendable {
    public var current: Int
    public var max: Int

    public init(current: Int, max: Int) { self.current = current; self.max = max }
}

extension Pool: CodingKeyRepresentable {}

public struct Situation: Codable, Hashable, Sendable {
    /// Rule id → the Stufe and options the hero has. The sheet is complete: a rule not listed is
    /// not owned (`hero.has` is never unknown).
    public var owned: [String: OwnedRule]
    /// Fact name → the stated fact.
    public var facts: [String: Fact]
    /// Query string (`at`, `pa(with: shield)`) → the value the sheet states.
    public var base: [String: Int]
    /// The dice, in the order they were rolled.
    public var rolls: [Int]
    public var pools: [Pool: PoolState]
    /// Process id → the running process (Zielen, Laden, …). A process not listed is not running:
    /// `process.<id>` reads 0.
    public var processes: [String: ProcessState]
    /// Item instance → its state (loaded, strung, current StP, …). The facts
    /// `item.<instance>.<field>` a situation states land here.
    public var items: [String: ItemState]
    public var clock: Clock
    /// The Stufen gained or cleared for a span, undone when the span ends.
    public var timed: [TimedChange]
    public var heroId: String?
    /// Derived facts the evaluator could not compute: unknown, whatever the sheet's fallback
    /// (`hero.levelOf.X` whose derive lacks a fact). Only the evaluator sets it.
    var unstated: Set<String> = []
    /// Value effects a confirmation put in force for its own roll's consequence stage (a confirmed
    /// shot's `onSuccess` doubling the TP, fernkampf.FK13: "für diesen Angriff"). Every query they
    /// reach reads them as it reads the book's. Only `CombatRoll` sets it, on the situation it
    /// evaluates the consequence in; no step returns it, and every entry point
    /// (`CombatRoll.start`, `DamageChain.run`, `CheckProcedure.start`) clears it, so it never
    /// reaches another action. Not part of the JSON.
    var inForce: [Effect] = []

    public init(owned: [String: OwnedRule], facts: [Fact], base: [String: Int] = [:], rolls: [Int] = [],
                pools: [Pool: PoolState] = [:], heroId: String? = nil) {
        self.owned = owned
        self.facts = [:]
        self.base = base
        self.rolls = rolls
        self.pools = pools
        self.processes = [:]
        self.items = [:]
        self.clock = Clock()
        self.timed = []
        self.heroId = heroId
        for f in facts { state(f) }
    }

    enum CodingKeys: String, CodingKey { case owned, facts, base, rolls, pools, processes, items, clock, timed, heroId }

    /// Reads the compiled `situations.json` shape (`owned`, the `facts` list, `base`, `rolls`);
    /// the keys it does not know (`id`, `expect`, `pending`, …) are the harness's. A stated
    /// `item.<instance>.<field>` fact becomes that instance's state (`items`). The state over
    /// time (`processes`, `items`, `clock`, `timed`) is optional: absent, nothing runs, no item
    /// has a state beyond its facts, and the clock stands at round 1, minute 0.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(owned: try c.decodeIfPresent([String: OwnedRule].self, forKey: .owned) ?? [:],
                  facts: [],
                  base: try c.decodeIfPresent([String: Int].self, forKey: .base) ?? [:],
                  rolls: try c.decodeIfPresent([Int].self, forKey: .rolls) ?? [],
                  pools: try c.decodeIfPresent([Pool: PoolState].self, forKey: .pools) ?? [:],
                  heroId: try c.decodeIfPresent(String.self, forKey: .heroId))
        items = try c.decodeIfPresent([String: ItemState].self, forKey: .items) ?? [:]
        for f in try c.decodeIfPresent([Fact].self, forKey: .facts) ?? [] { state(f) }
        processes = try c.decodeIfPresent([String: ProcessState].self, forKey: .processes) ?? [:]
        clock = try c.decodeIfPresent(Clock.self, forKey: .clock) ?? Clock()
        timed = try c.decodeIfPresent([TimedChange].self, forKey: .timed) ?? []
    }

    /// The same shape back: `facts` as a list sorted by name.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(owned, forKey: .owned)
        try c.encode(facts.values.sorted { $0.name < $1.name }, forKey: .facts)
        try c.encode(base, forKey: .base)
        try c.encode(rolls, forKey: .rolls)
        try c.encode(pools, forKey: .pools)
        try c.encode(processes, forKey: .processes)
        try c.encode(items, forKey: .items)
        try c.encode(clock, forKey: .clock)
        try c.encode(timed, forKey: .timed)
        try c.encodeIfPresent(heroId, forKey: .heroId)
    }
}

// MARK: - Reading a fact

extension Situation {
    /// The fact `name` as the rules read it, or nil when it is unknown.
    ///
    /// - `level`: the effective level passed in (`level`), else the owned level of the acting
    ///   `rule`.
    /// - `option`: the acting `rule`'s owned option.
    /// - a stated fact: its value and owner.
    /// - `hero.levelOf.<rule>`: the Stufe the hero has, `owned[rule].level` before any
    ///   useLevel, and 0 for a rule the hero does not own (the sheet is complete). The evaluator
    ///   states it first from the base phase of `level(rule: X)` (R34), so this is the fallback
    ///   when there is neither an owned level nor a derive.
    /// - `hero.leCurrent` / `hero.aspCurrent`: the current value of the pool (R39); unknown
    ///   when the situation does not track the pool.
    /// - the state over time (`stateFact`): `item.<instance>.<field>` and `loadout.<slot>.<field>`
    ///   from `items`, `process.<id>` from `processes`, `clock.minutes` from `clock`.
    /// - anything else: unknown. The other derived facts (`hero.conditionLevels`, `fw.current`,
    ///   `hit.*`, …) are the evaluator's (Task 22).
    ///
    /// `hero.has` is not a value: `Conditions` answers it from `owned`.
    public func fact(_ name: String, level: Int? = nil, rule: String? = nil) -> FactUse? {
        switch name {
        case "level":
            guard let l = level ?? rule.flatMap({ owned[$0]?.level }) else { break }
            return FactUse(name: name, value: .int(l), owner: .sheet)
        case "option":
            guard let o = rule.flatMap({ owned[$0]?.option }) else { break }
            return FactUse(name: name, value: o, owner: .sheet)
        default:
            break
        }
        if let pool = Pool.current(fact: name), let p = pools[pool] {
            return FactUse(name: name, value: .int(p.current), owner: .derived)
        }
        if let state = stateFact(name) { return state }
        if let f = facts[name] { return FactUse(name: f.name, value: f.value, owner: f.owner) }
        if unstated.contains(name) { return nil }
        let levelOf = "hero.levelOf."
        if name.hasPrefix(levelOf), name.count > levelOf.count {
            let id = String(name.dropFirst(levelOf.count))
            return FactUse(name: name, value: .int(owned[id]?.level ?? 0), owner: .derived)
        }
        return nil
    }
}

// MARK: - The state over time as facts

extension Situation {
    /// The facts the state over time answers (spec §7, MIGRATION probe-fernkampf):
    /// - `item.<instance>.<field>`: the instance's state (owner loadout);
    /// - `loadout.<slot>.<field>` for an item field (`loadout.weapon.loaded`, `…strung`,
    ///   `loadout.shield.structurePoints`): the state of the instance in the slot
    ///   (`loadout.<slot>.instance`), never of an item by name; a slot whose instance has no such
    ///   state falls back to the fact as stated;
    /// - `process.<id>` (one segment after `process.`): the running process's progress, 0 when
    ///   none runs (the situation lists every running process), owner derived;
    /// - `clock.minutes`: the clock (owner round).
    func stateFact(_ name: String) -> FactUse? {
        if let (instance, field) = Self.itemFact(name), let v = items[instance]?[field: field] {
            return FactUse(name: name, value: v, owner: .loadout)
        }
        if let (slot, field) = Self.slotFact(name), let v = item(in: slot)?[field: field] {
            return FactUse(name: name, value: v, owner: .loadout)
        }
        let process = "process."
        if name.hasPrefix(process), name.count > process.count, !name.dropFirst(process.count).contains(".") {
            return FactUse(name: name, value: .int(processes[String(name.dropFirst(process.count))]?.progress ?? 0), owner: .derived)
        }
        if name == "clock.minutes" { return FactUse(name: name, value: .int(clock.minutes), owner: .round) }
        return nil
    }
}

extension Situation {
    /// The facts an action states for its own evaluation only (R56): its one-query inputs, which
    /// are no lasting state and so no `stated` event. They are a check's (`check.*`, `fw.current`),
    /// a cast's (`choice.spellModification.*` beside `check.*`), a roll's die and declaration
    /// (`roll.*`, `action.defence`, `action.with`), a hit's (`hit.*`) and a query's own
    /// (`query.*`). A roll's outcome (`action.attack`) and `round.previousDefenceCrit` last: they are
    /// `stated`.
    public static func isOneQueryInput(_ name: String) -> Bool {
        let prefixes = ["check.", "roll.", "hit.", "query.", "choice.spellModification."]
        return prefixes.contains { name.hasPrefix($0) } || ["fw.current", "action.defence", "action.with"].contains(name)
    }
}
