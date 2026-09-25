import Foundation

/// What the player (or the table) does, for `ActionLayer.perform` (spec §7): a cast, a payment,
/// a Zustand, a choice taken, the procedures (a staged check, the combat roll, a hit), and the
/// state over time (a process step, the clock, the end of a round or a fight, settling).
public enum Action: Hashable, Sendable {
    /// Cast `spell` with the chosen modifications. The cast states `check.kind: spell`,
    /// `check.spell` and `choice.spellModification.<id>: true` (player) for the rules to read, and
    /// runs every `cost`, `gain` and `item` whose `when` reads what it stated and then holds: the
    /// cast's AsP (ZM12), a split (SA_74.VP1). A standing consequence is `.settle`'s.
    case cast(spell: String, modifications: [String])
    /// Pay `amount` from a pool directly (no rule's cost): a `paid` event without origin.
    case pay(Pool, Int)
    /// A Zustand or Status stated by the table: `levels` > 0 gains, < 0 clears (no origin).
    case state(rule: String, levels: Int)
    /// Take an offered choice: its `costs` are paid through the same cost interpreter (ruling
    /// R23). The choice's fact itself is the caller's to state; an event only records the costs.
    case take(choice: String)
    /// A talent, spell or liturgy check (spec §6, `CheckProcedure`): its stage breakdowns, and with
    /// the situation's `rolls` (one per attribute) the dice and the confirm's events. Step by step
    /// (rerolls between the dice and the confirm) is `CheckProcedure.start` and
    /// `ProcedureState.step`.
    case check(CheckRequest)
    /// The hero's attack (spec §6 combat roll, `CombatRoll`): its target (`at`, or `fk` with a
    /// ranged weapon in hand), and with the situation's `rolls` the die and, for a 1 or a 20, the
    /// confirmation. Step by step: `CombatRoll.start` and `CombatState.step`.
    case attack(with: String? = nil)
    /// The hero's defence: `pa(with: …)` or `aw`, rolled as `.attack` is.
    case defend(kind: DefenceKind, with: String? = nil)
    /// A hit on the hero (`DamageChain`): TP → RS → SP → the Wundschwelle → the checks it calls for
    /// (`ActionResult.checks`). `tp` nil: the situation's `hit.tp`, or its stated SP. Paying LeP
    /// (`.pay(.le, n)`, a `paid(le)` event) is not a hit and never runs the chain.
    ///
    /// `failedDefence` (R58): the hit came through a defence of the hero's that failed (a shield
    /// parry against Schildspalter). The defence's outcome is a one-query input of its own roll, so
    /// the hit carries it: it states `check.result: failure` for the rules that read the failed
    /// defence with the hit (SA_59.SS3: "Misslingt die Parade …").
    case takeHit(tp: Int?, zone: String? = nil, side: String? = nil, failedDefence: Bool = false)
    /// One step of the process `process` (spec §7), as the action its `advancedBy` names does,
    /// without paying that action's cost: a running process progresses; else a `process` effect
    /// with that id whose `when` holds starts one (bound to the weapon in hand). Taking the offered
    /// choice (`.take(choice: laden)`) pays its cost and advances the same way.
    case advance(process: String)
    /// Game time passes (spec §7): the clock's minutes move on, every `cost { every }` that falls
    /// due on the way is paid, and what lasts only the action or the round ends (minutes are
    /// longer than a Kampfrunde).
    case advanceClock(minutes: Int)
    /// The Kampfrunde ends: the round's facts (`round.*`, `round.previousDefenceCrit` among them)
    /// and the choices offered for the round or the action are cleared, a Stufe gained or cleared
    /// for the round or the action is undone, and the clock's round moves on. A process goes on.
    case endRound
    /// The fight ends: as `.endRound`, and what lasts the fight ends too.
    case endFight
    /// The standing consequences the situation implies, with no action: every `gain` whose `when`
    /// holds (Belastung IV → Handlungsunfähig, COND_1.B4). Only `settle` runs them; the other
    /// actions run the effects that read what they state.
    case settle
}

// MARK: - In the log

/// In the log (spec §8) an action is one key, its case, holding its fields by name:
/// `{"cast": {"spell": "SPELL_21", "modifications": []}}`, `{"pay": {"pool": "asp", "amount": 3}}`,
/// `{"endRound": {}}`. An absent optional field is left out.
extension Action: Codable {
    private enum Case: String, CodingKey {
        case cast, pay, state, take, check, attack, defend, takeHit, advance, advanceClock, endRound, endFight, settle
    }

    private enum Field: String, CodingKey {
        case spell, modifications, pool, amount, rule, levels, choice, request, with, kind, tp, zone, side, failedDefence
        case process, minutes
    }

    public init(from decoder: Decoder) throws {
        let outer = try decoder.container(keyedBy: Case.self)
        guard outer.allKeys.count == 1, let key = outer.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(codingPath: outer.codingPath,
                                                    debugDescription: "an action has exactly one key, its case"))
        }
        let c = try outer.nestedContainer(keyedBy: Field.self, forKey: key)
        switch key {
        case .cast:
            self = .cast(spell: try c.decode(String.self, forKey: .spell),
                         modifications: try c.decodeIfPresent([String].self, forKey: .modifications) ?? [])
        case .pay: self = .pay(try c.decode(Pool.self, forKey: .pool), try c.decode(Int.self, forKey: .amount))
        case .state: self = .state(rule: try c.decode(String.self, forKey: .rule), levels: try c.decode(Int.self, forKey: .levels))
        case .take: self = .take(choice: try c.decode(String.self, forKey: .choice))
        case .check: self = .check(try c.decode(CheckRequest.self, forKey: .request))
        case .attack: self = .attack(with: try c.decodeIfPresent(String.self, forKey: .with))
        case .defend:
            self = .defend(kind: try c.decode(DefenceKind.self, forKey: .kind), with: try c.decodeIfPresent(String.self, forKey: .with))
        case .takeHit:
            self = .takeHit(tp: try c.decodeIfPresent(Int.self, forKey: .tp), zone: try c.decodeIfPresent(String.self, forKey: .zone),
                            side: try c.decodeIfPresent(String.self, forKey: .side),
                            failedDefence: try c.decodeIfPresent(Bool.self, forKey: .failedDefence) ?? false)
        case .advance: self = .advance(process: try c.decode(String.self, forKey: .process))
        case .advanceClock: self = .advanceClock(minutes: try c.decode(Int.self, forKey: .minutes))
        case .endRound: self = .endRound
        case .endFight: self = .endFight
        case .settle: self = .settle
        }
    }

    public func encode(to encoder: Encoder) throws {
        var outer = encoder.container(keyedBy: Case.self)
        func fields(_ key: Case) -> KeyedEncodingContainer<Field> { outer.nestedContainer(keyedBy: Field.self, forKey: key) }
        switch self {
        case .cast(let spell, let modifications):
            var c = fields(.cast)
            try c.encode(spell, forKey: .spell)
            try c.encode(modifications, forKey: .modifications)
        case .pay(let pool, let amount):
            var c = fields(.pay)
            try c.encode(pool, forKey: .pool)
            try c.encode(amount, forKey: .amount)
        case .state(let rule, let levels):
            var c = fields(.state)
            try c.encode(rule, forKey: .rule)
            try c.encode(levels, forKey: .levels)
        case .take(let choice):
            var c = fields(.take)
            try c.encode(choice, forKey: .choice)
        case .check(let request):
            var c = fields(.check)
            try c.encode(request, forKey: .request)
        case .attack(let with):
            var c = fields(.attack)
            try c.encodeIfPresent(with, forKey: .with)
        case .defend(let kind, let with):
            var c = fields(.defend)
            try c.encode(kind, forKey: .kind)
            try c.encodeIfPresent(with, forKey: .with)
        case .takeHit(let tp, let zone, let side, let failedDefence):
            var c = fields(.takeHit)
            try c.encodeIfPresent(tp, forKey: .tp)
            try c.encodeIfPresent(zone, forKey: .zone)
            try c.encodeIfPresent(side, forKey: .side)
            try c.encode(failedDefence, forKey: .failedDefence)
        case .advance(let process):
            var c = fields(.advance)
            try c.encode(process, forKey: .process)
        case .advanceClock(let minutes):
            var c = fields(.advanceClock)
            try c.encode(minutes, forKey: .minutes)
        case .endRound: _ = fields(.endRound)
        case .endFight: _ = fields(.endFight)
        case .settle: _ = fields(.settle)
        }
    }
}
