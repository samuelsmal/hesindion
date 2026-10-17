# ADR-0008: Restore the hard offset shadow

## Status

Accepted. Supersedes the border-tier half of [ADR-0007](0007-type-scale-and-border-tiers.md) and
revises the "flat surfaces" reading of [ADR-0002](0002-neo-brutalist-design-theme.md).

## Context

ADR-0002 adopted a neo-brutalist identity as "bold borders, high-contrast colors, flat surfaces
with visible structure". In practice "flat" was implemented as *no shadows at all* — the audit
(`docs/neobrutalism-ui-audit.md`, finding D1) measured **zero `.shadow(`** across 21k lines.

That is the one place the app departs from its own reference. In the neobrutalism system the
**hard offset drop shadow is the signature element**, not an optional flourish: `--shadow:
4px 4px 0 0 var(--border)` — the same offset as the border colour, zero blur, zero spread. Its
`conventions.md` names three things to get right, and the shadow is one of them.

Dropping it cost more than appearance. Three separate findings trace back to it:

- **Emphasis had to be carried by border weight instead.** Hence three border tiers (3 / 2 / 1)
  where the reference has one, which ADR-0007 was still trying to untangle.
- **The reference press interaction became impossible.** Its buttons sit on the shadow and
  *move into it* on press — `translate(+4px, +4px)` with the shadow removed, so the element lands
  flush. With no shadow there was nothing to move into, which is why spec 010 (button feedback)
  went unimplemented and 192 of 211 buttons ended up inert (audit S3).
- **Depth had no cue at all.** No shadow, no elevation, and a scrim at 0.3–0.5 against the
  reference's 0.8 (audit S7) left modals with nothing marking them as above the content.

## Decision

**Restore the hard offset shadow** as the app's depth and emphasis mechanism, exactly as the
reference specifies it: offset `(4, 4)`, **radius 0** (no blur, no spread), colour = the border
colour. It is expressed once, as `DSALayout.shadowOffset` plus the shared box modifier, never at a
call site.

Three consequences follow, and are adopted with it:

1. **One border weight, not two.** With the shadow carrying emphasis, border weight stops being an
   emphasis channel. `primaryBorder` (3px) retires alongside `tertiaryBorder` (1px, retired in
   ADR-0007): **2px everywhere**, as the reference intends. Emphasis is now *has a shadow or not*,
   and fill colour — not a heavier stroke.
2. **Press = move into the shadow.** The reference interaction becomes available, so it is adopted:
   on press the element offsets by `(+4, +4)` and drops its shadow, landing flush. This answers
   spec 010's requirement for press feedback on "all buttons and pressable visual items" — by the
   reference's own mechanism rather than the colour-flip that was proposed when no shadow existed.
   (See "Still open" below.)
3. **Shadow colour follows the border.** The reference uses `var(--border)` for both, and the app's
   border is already brightness-adaptive (`dsaBorder` = `UIColor.label`, ADR-0002/D2). A black
   shadow on the app's near-black dark surface would be invisible, so the same adaptation applies:
   shadow is black in light mode, white in dark.

**Shadows belong to containers, not to rows.** A SwiftUI shadow renders outside the view's bounds
and does not participate in layout, so a shadow on every element in a dense stack overlaps its
neighbour. Group-level surfaces (cards, modals, buttons, section containers) carry the shadow;
elements inside them do not. This composes with ADR-0007's row treatment — one box around the
group, dividers within — which already reduced the number of boxes that could carry one.

## Consequences

- **Easier:** the three findings above collapse into one mechanism. Press feedback, depth, and
  emphasis are all expressed by the same token, defined once.
- **This is the largest *visual* change of the whole refactor.** Every emphasised surface gains a
  4pt offset block of black (or white). The app will look materially different — that is the
  point, but it should be reviewed on device, not assumed.
- **Layout needs headroom.** Because the shadow draws outside the bounds without reserving space,
  containers that previously sat flush need ≥ 4pt trailing/bottom breathing room or the shadow
  will be clipped by a parent or overlap a sibling. Expect padding adjustments alongside the
  migration; this is the main source of non-mechanical work.
- **Every snapshot baseline and screenshot is invalidated.** `docs/screenshots/` and the
  `HesindionTests` snapshot references must be re-recorded. Note `make test-ui-record` only writes
  *missing* baselines, so stale PNGs have to be deleted first.
- **Still open:** spec 010 asks specifically for a background/text colour *flip*. The
  move-into-shadow press satisfies its intent (clear feedback on every pressable) by the
  reference's mechanism. Whether to also flip colours — or to treat the shadow press as fulfilling
  010 — is deferred until the interaction can be judged on device.
