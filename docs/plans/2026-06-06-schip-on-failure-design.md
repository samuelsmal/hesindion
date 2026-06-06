# Schip-on-Failure for Skill & Spell Checks — Design

**Date:** 2026-06-06
**Branch:** `feature/schip-on-failure`
**Status:** Approved

## Problem

When a 3W20 skill or spell check fails, the app gives the player no in-context
reminder that they may spend a Schicksalspunkt (Schip / fate point) to reroll.
Combat already offers this (`CombatExecutionView`), but talent and spell probes
do not. We want to extend the established combat affordance to checks, with one
addition: the player chooses *which* dice to reroll (all selected by default).

## Scope

- **In:** `SkillCheckModal` — the single view behind `TalentProbeModal` and
  `SpellProbeModal`. Both get the feature for free.
- **Out:** Combat (already done), `DiceRollSheet` (freeform dice, no check
  result to fail), and any non-reroll fate-point uses (round-up QS, etc.).

## Single Touch-Point

`TalentProbeModal` and `SpellProbeModal` both render through `SkillCheckModal`,
so the entire feature lives in that one view. The roll/result logic stays in
`SkillCheckEngine` (already unit-tested) and needs no change.

## Trigger

Show the Schip affordance only when **all** of:

1. A roll is locked in (`finalRolls != nil`).
2. The result is a **regular failure** — `CheckResult.qs(0)`.
   - Excluded: critical botch (`.kritischerPatzer`) and any success
     (`qs >= 1`). Mirrors the combat decision (`outcome == .misserfolg && !fumble`).
3. `hero.derivedValues?.schicksalspunkte.current ?? 0 > 0`.
4. The Schip has not already been used this check (`!schipUsed`).

## Interaction

1. On a qualifying failure, the three locked W20 boxes become
   **reroll-selectable**. All three start selected (golden highlight =
   "will be rerolled").
2. Tapping a die toggles keep/reroll. Kept dice dim; selected dice keep the
   golden highlight.
3. A full-width golden **"Schip: Neuer Wurf"** button (`sparkles` icon,
   `L("schip.reroll")`) sits below the `summaryBar` — visually identical to the
   combat button (`Color(red: 0.6, green: 0.5, blue: 0.0)`, 3px `dsaBorder`).
   - Disabled (or hidden) when zero dice are selected.
4. Below the button, a caption shows remaining Schips with pip indicators
   (`N Schips übrig`).
5. On tap: spend one Schip, reroll only the selected dice (keep the rest),
   recompute the result, fire `onResult`, and write logs. The button then
   disappears (`schipUsed == true`) — **one reroll per check**, matching combat.

## State

Two new `@State` fields on `SkillCheckModal`:

- `schipUsed: Bool = false`
- `rerollSelection: Set<Int> = [0, 1, 2]`  // all dice selected by default

Both reset implicitly: the modal is recreated per check.

## Reroll Logic

The existing `roll()` always rerolls all three dice and logs. Extract a
`reroll(selection:)` (or parameterize) that:

- For each index `i` in `rerollSelection`, draw a fresh `Int.random(in: 1...20)`.
- For indices not in the selection, keep the current `finalRolls[i]`.
- Set `finalRolls` to the merged array, recompute via `computeResult`, rebuild
  `SkillCheckResult`, fire `onResult`, and insert the `TalentCheckPayload`
  `LogEntry` (same as `roll()`).

## Logging

Mirror combat: when the Schip is spent, also write a `LogEntry` recording the
expenditure so it shows in the LogPanel alongside the new roll. Combat uses
`CombatActionPayload(action: .schipUsed, schipAction: "reroll", …)`; checks have
no combat context, so reuse the check's `config.logKind` with a
`schipAction: "reroll"` marker (exact payload decided in the plan — may need a
small payload field or a dedicated entry). The reroll itself already logs a
fresh `TalentCheckPayload` via the reroll path.

## Testing

Project uses `swift-snapshot-testing`; `SkillCheckModal` and `DiceRollSheet`
snapshots already exist.

- Snapshot: failure state with Schips available — dice selectable (all
  selected), reroll button visible.
- Snapshot: post-reroll / zero-Schips / `schipUsed` state — button absent.
- Engine logic unchanged → no new `SkillCheckEngine` unit tests required.

## Decisions

1. **One reroll per check** (not "spend until success"). Matches combat.
2. **No Schip on a botch** (`kritischerPatzer`). Matches combat; DSA5 would
   technically permit it.
3. **Per-die selection, default all.** The single deviation from the combat
   pattern, per request.

## Out of Scope / YAGNI

- Fate-point uses other than reroll (round-up QS, reroll-one-then-keep loop).
- Schip support in the freeform `DiceRollSheet`.
- No ADR: this extends an existing pattern, not an architecture decision.
