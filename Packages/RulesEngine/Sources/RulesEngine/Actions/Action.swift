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
    case takeHit(tp: Int?, zone: String? = nil, side: String? = nil)
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
