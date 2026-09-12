# ADR-0010: Disabled state, one activation treatment, and in-app modals

## Status

Accepted. Extends [ADR-0009](0009-shadow-scale-scope-and-square-corners.md).

## Context

Four things surfaced from reviewing the rendered screens rather than the code,
and all four are the same kind of fault: a component that was never given a
design-language answer quietly kept the system default.

**Disabled.** `Color.dsaDisabled` was `UIColor.tertiarySystemFill` — a
translucent grey — and every call site paired it with `.foregroundStyle(.white)`,
because that is what the *enabled* fill needs. So the moment a control settled,
its label went white-on-pale-grey. On `16-take-damage-applied` the entire
Wundeffekt panel became unreadable at exactly the point the player wants to read
it back. A soft grey is also the one thing the design language names and rules
out.

**Two ways to say "on".** Single-select pickers fill the chosen row with the
accent and turn its label white. Boolean toggles kept a neutral row and put a
`checkmark.square.fill` on the left. Both appear on the same screen: on the
announcement, "Torso" is red-filled while "Ziel ist überrascht" one row below is
a tickbox.

**Confirmations.** The overwrite prompt was a `.alert`, which brings rounded
corners, a blurred material and tinted system text onto a screen built without
any of the three.

**Rolls.** The Trefferzone 1W20 resolved silently on tap and reported itself as a
line of text below the chips ("7: Torso") — duplicating what the highlighted chip
already said, and putting the one thing the chip *cannot* show, the die, in the
quietest place on the screen. Every other roll in the app is shown.

## Decision

**A disabled surface loses its depth and its colour, never its contrast.**
`dsaDisabled` is now the page background and `dsaDisabledLabel` is `.primary`;
`DSAStepper(isSettled:)` and `dsaOptionGroup(isSettled:)` also drop the shadow. A
settled control reads as an outline of what it was — the affordance is gone, the
information is not.

**One activation treatment: the fill.** `DSAToggleRow` replaces the tickbox row
at every boolean-toggle site. The checkbox is a control borrowed from a system
list, and it says "on" in a whisper on a screen where everything else says it in
a shout.

**Confirmations are `DSAModal`** — the app's own scrim and raised panel, the
idiom `SkillCheckModal` already drew by hand.

**Rolls are revealed.** `DSADiceRevealModal` tumbles and settles the die in front
of the player and holds it until they dismiss it, for the same reason the skill
check closes deliberately: a modal that dismisses itself takes the number away
before it has been read.

**The AKTION list is a container.** ADR-0009 recorded its "containers" half as
undelivered; the combat root's nine actions now sit in one `dsaOptionGroup`, the
same container the Manöver and Trefferzone lists use.

## Consequences

- **Disabled and *unselected* now look alike** — both are an outlined row on the
  page. They are told apart by position and by whether anything on the screen is
  live, not by the control itself. Accepted: legibility of a settled entry is
  worth more than a distinction the player rarely needs, and the alternative
  (Locked, a solid dark fill) makes a screen with several settled controls very
  heavy. Reconsider if a screen ever mixes live and settled controls of the same
  shape.
- **`Schicksalspunkte` stops being a section.** Its two buttons are actions, so
  they moved into AKTION with a printed `1 Schip` cost; the count became a badge
  beside RS. This also fixed the ordering fault where the section split the
  action list in two and left "Kampf beenden" stranded after it.
- **The LP bar and the round row became controls.** Both were strips of
  separately bordered segments — the round row with a shadow on its middle
  segment only, the LP bar with no border at all. Both are now built like
  `DSAStepper`: one border, one shadow, rules between segments.
- **The take-damage total now includes the Wundeffekt** (`12 TP − 0 RS + 4 WE =
  16`). The display had stopped at `TP − RS`, so on a failed probe the screen
  showed 12 while the confirm wrote 16.
- **Two sheet list-rows still use the tickbox**: `StatePickerSheet` and
  `StateDetailSheet`. They are multi-select and level-select lists rather than
  boolean toggles, and filling a long list of states is a bigger visual call than
  this decision covers. Left deliberately.
- Snapshot baselines and screenshots are invalidated and re-recorded.
