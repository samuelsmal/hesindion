import Foundation

/// What the player (or the table) does, for `ActionLayer.perform` (spec §7). Tasks 26–28 add the
/// procedure actions (a staged check, the combat roll, processes, the clock).
public enum Action: Hashable, Sendable {
    /// Cast `spell` with the chosen modifications. The cast states `check.kind: spell`,
    /// `check.spell` and `choice.spellModification.<id>: true` (player) for the rules to read, and
    /// runs every `cost` and `gain` whose `when` then holds: the cast's AsP (ZM12), a split
    /// (SA_74.VP1), a Zustand's consequence.
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
}
