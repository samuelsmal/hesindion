# ADR-0009: Shadow scale, shadow scope, and square corners

## Status

Accepted. Refines [ADR-0008](0008-hard-offset-shadow.md).

## Context

ADR-0008 restored the hard offset shadow at the reference's own values and put it
on every pressable surface. Seeing that rendered on the simulator raised three
questions the ADR had left open, and each was judged against real screenshots
rather than against the spec text.

**Offset.** At iPad point scale a 4pt offset sits close enough to the 2pt border
that it reads as a thicker edge rather than as depth. The reference is calibrated
for CSS pixels in a browser, not for points on a tablet.

**Scope.** With every pressable casting, a list of options became a stack of
shadows — the Manöver list is five cards each with its own — and nothing on the
screen read as the primary action. The shadow was signalling *tappability*, which
every row already has, rather than *importance*.

**Corners.** 272 of the app's 282 strokes were already square, but nothing said
so, and ten rounded outliers survived: 6pt avatar badges, an 8pt hero image, two
`Circle()` adventure avatars and a full `Capsule()` in `WeatherDayRow`.

## Decision

**Shadow offset is 5pt**, not the reference's 4. One point of separation is
enough to read as depth without becoming a statement of its own; 6pt was tested
and rejected because press travel matches the offset, so buttons would jump 6pt
on every tap.

**Only containers and primary actions cast.** Concretely, a surface is `.raised`
when it is a full-width action button or a floating container (a modal on a
scrim). Selection rows, fixed-width segments, toggle chips and inline cells are
`.flush`. 36 sites were demoted; 84 remain raised. The shadow now means
importance.

**Corners are square, and it is written down.** `DSALayout.cornerRadius = 0` — a
harder line than the reference's own 5px radius, and what the app already did
almost everywhere. All ten outliers are squared to match.

## Consequences

- **Combat root is the intended result:** six full-width actions cast, while the
  round-strip segments, status chips and armour badge sit flat. The hierarchy is
  legible at a glance, which it was not when everything cast.
- Squaring the outliers let fourteen further sites move onto `.dsaBox`, which
  takes **hardcoded `lineWidth` literals to zero** (from 247 before the refactor).
- **Avatars are now square.** This is the most opinionated consequence — photo
  avatars are conventionally round — and it follows from the corner decision
  rather than from any separate judgement about avatars. Cheap to revert alone.
- **Edge-attached bars cannot cast.** A shadow draws outside the bounds, so a
  full-bleed bottom action bar (the "Weiter" CTA on the announcement flow) has
  its shadow clipped by the screen edge. Left as-is: a bar welded to the edge is
  not a floating element, and it already reads as primary through colour and
  position. Insetting it would undo a deliberate full-bleed design.
- **The "containers" half is only partly delivered.** Option rows are flush,
  which is the calmer half, but wrapping each option list in a single raised
  container with inner dividers (per ADR-0007's row treatment) is per-screen
  structural work that has not been done. Those lists currently read as flat
  rows with no group shadow.
- **Rows no longer move into a shadow on press**, because they no longer have
  one. Spec 010's background/text colour flip therefore stops being optional for
  them — it is now the only press affordance those rows would have. ADR-0008
  deferred that question; this decision forces it.
- Every snapshot baseline and screenshot is invalidated again and re-recorded.
