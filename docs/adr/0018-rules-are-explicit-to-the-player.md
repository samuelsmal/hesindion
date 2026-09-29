# ADR-0018: Rules and Their Application Are Explicit to the Player

## Status

Accepted, 2026-09-29.

## Context

The app applies rules for the player: it adds modifiers to a check, caps them, writes a status
effect's damage to LeP or AsP, and reminds the player of what the opponent or the GM must do. At
the table, the player must be able to check each of these against the rules and explain it to the
GM. A value that changes with no stated cause cannot be checked.

Parts of the app already work this way, each for its own reason:

- `CombatBreakdownBox` shows every part of a calculation beside its source, and the total says what
  it is the total of (the **Design** section of `AGENTS.md`).
- `BreakdownSheet` shows each line's rule, clause and facts, and a "Nicht angewandt" list with a
  reason for every owned rule that did not fire. A domain does not switch to the rules engine until
  its screen shows every line's origin (ADR-0015).
- A Patzertabelle result reports on screen everything it wrote (`combat.fumble.writes`), and every
  entry carries a typed `FumbleEffect`, because "the failure mode of prose is silence".
- Where a rule turns on the opponent's check, the app asks the player for the outcome and never
  rolls for the other side (ADR-0005); a critical success states the opponent's conditions for the
  GM (ADR-0011).

Nothing wrote this down as one principle, so new screens miss it. The issues filed on 2026-09-29
show the gaps:

- #35: "Blutend" reduces LeP at the start of a Kampfrunde, and the player gets no notice.
- #43: a talent check applies modifiers but shows no resulting values, so the player cannot tell
  whether the GM-decided +2 of Sinnesschärfe is in or out.
- #41: after a successful attack with "Mächtiger Schlag", the opponent must make a
  Körperbeherrschung check, and the app does not say so.

## Decision

**The player can always tell why something happens.** When the app applies a rule — a modifier, a
status effect, a reduction of LeP or AsP, any value it writes by itself — it tells the player which
rule caused the change.

1. **A computed value shows its parts.** Each modifier line names its rule or source, and the
   result is shown after the modifiers, not only before them. `CombatBreakdownBox` is the grammar.
2. **A change the app writes by itself is announced with its amount and its cause**, for example
   "LeP −1 (Blutend)". A change on the player's own screen shows in that screen's before/after. A
   change with no screen of its own (the start of a Kampfrunde, a status that runs out) gets a
   toast that closes by itself, styled after <https://www.neobrutalism.dev/docs/toast>.
3. **A rule the app does not apply, but that follows from a result, is stated when it becomes
   due**: an opponent's check, a GM decision, an effect for the next round. The player does not
   have to remember it.
4. **A rule that can apply but that the app did not apply is visible as not applied**, with the
   reason. A bonus the GM decides is an explicit choice on screen, never silently in or out.
5. **Silence is not an answer.** A missing notice looks the same as a rule the app does not know.
   A change that applies a rule without saying so is a bug, not a detail.

## Consequences

- Every new screen or flow that applies a rule needs a place to name that rule. Reviews check this.
- The app needs a toast component in the neobrutalist style. `DSAToast` (`.dsaToast`) is that component,
  added for #35; the round-start toast in `CombatView` is its first use.
- Rule names and causes add UI text to `Strings.swift`.
- #35, #41 and #43 are the first follow-ups under this principle. #35 is done: the next-round button
  announces every change it writes by itself.
