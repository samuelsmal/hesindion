# ADR-0019: On/off options use the neobrutalism Switch

## Status

Accepted, 2026-09-30. Supersedes the "One activation treatment: the fill" part
of [ADR-0010](0010-disabled-state-activation-and-in-app-modals.md) for on/off
options. The fill stays for picks.

## Context

ADR-0010 gave the app one way to say "on": the fill. A picked Manöver, a picked
Trefferzone and an on/off option such as "Ziel ist überrascht" all filled their
row with the accent colour.

That removed the tick box, but it put two different questions into one look.
A pick answers "which one of these?". An on/off option answers "does this
apply?". On the announcement, a filled "Ziel ist überrascht" under a filled
"Torso" read as one more zone.

Issue #37 asks the app to follow the neobrutalism.dev components more closely,
and names the Switch (neobrutalism.dev/docs/switch) for every place where the
player turns an option on or off. The owner decided that this applies to every
on/off option, the combat options included, not only to the hero settings.

## Decision

**Every on/off option shows a `DSASwitch`.** `DSAToggleRow` and
`DSAToggleRowLabel` keep a neutral row and draw the switch on the right, after
the `detail` value. The whole row stays the tap target. The two system
`Toggle`s in the spell options are replaced by a stand-alone `DSASwitch`.

**Picks keep the fill.** Manöver, Trefferzone, opponent size, reach and the
weapons in hand (`CombatLoadoutPicker`) are picks from a set, so ADR-0010 still
applies to them.

**The switch follows the reference.** A pill track (48 × 24 at the default text
size) with the 2 pt border; the surface colour when off, the accent when on; a
white round thumb (16) with the same border, 4 from the track's inner edge. No
shadow, as in the reference. The height scales with Dynamic Type
(`@ScaledMetric`), and the other sizes keep their proportions.

**The switch is round.** Every other control is square (ADR-0009). The pill is
what the reference Switch is, and it is what makes the control read as a switch
and not as a second kind of button. This is the one round control in the app.

## Consequences

- A screen now says "picked" with a fill and "on" with a switch, and the two
  cannot be confused.
- `DSASwitch` is the first round shape in the app. A later control must not cite
  it as a reason to round its own corners.
- The title of an on/off row no longer turns bold when the option is on, so the
  row does not move when it changes state.
- The tick boxes in `StatePickerSheet` and `StateDetailSheet` are unchanged:
  they are multi-select and level-select lists, and ADR-0010 left them out on
  purpose.
- Issue #37 also asks for a check of the other controls against
  neobrutalism.dev/docs. That check is not part of this decision.
- Snapshot baselines with on/off rows are recorded again.
