# ADR-0007: Type scale and border tiers

## Status

Accepted

## Context

`docs/neobrutalism-ui-audit.md` measured the SwiftUI UI against the neobrutalism reference
(`design-systems/neobrutalism`) and found the visual language committed and consistent, but
expressed as copy-paste rather than as code: 202 byte-identical copies of the border idiom,
border-width tokens used 27 times against 247 hardcoded literals, and 551 inline font-weight
declarations.

Before that can be consolidated into a shared style layer (audit item 5, `.dsaBox(…)`), two
questions had to be settled, because the abstraction has to encode an answer to each and every
call site inherits whatever it encodes.

**Typography.** The reference allows exactly two weights — 500 body, 700 heading. The app used
four: `.bold` (700) ×273, `.black` (900) ×201, `.semibold` (600) ×52, `.medium` (500) ×25. The
de-facto *body* weight was 700, so headings had climbed to 900 to stay above it: the pair was
900/700, one step heavy throughout, and both halves off-spec.

**Border tiers.** `DSALayout` defined three weights (3 / 2 / 1); actual use was 2px ×134, 3px ×117,
1px ×23. The reference has a single 2px weight and prohibits hairlines. Rendered comparisons also
exposed a defect in the 1px stacks: because each row strokes its own full rectangle, adjacent
borders stack into a 2px double line between rows while the outer edge stays 1px — the inverse of
the intended emphasis. Promoting those rows to 2px makes it worse (4px between rows), so "keep" and
"promote" were both wrong answers. Six of the 23 sites compounded it further with
`Color.dsaBorder.opacity(0.3)`, i.e. a hairline *and* a soft grey — the two things the reference
names outright.

## Decision

**Type scale: heading 700, body 500.** Adopt the reference's two weights exactly. Hierarchy is
preserved by lowering body to 500 rather than raising headings to 900. `.black` (900) and
`.semibold` (600) are retired. Weights stop being declared inline: named tokens in `Theme/` become
the only way to set one, preserving the existing Dynamic Type base (`.system(<textStyle>,
weight:)`) so text continues to scale with the user's accessibility settings.

**Border tiers: two, not three.** `tertiaryBorder` (1px) is retired as a *border*. Where a 1px
stroke currently separates stacked rows, the group takes one 2px box and the rows take a light
inner divider instead — the separation is stated by the container, not hinted at per row. This
removes the doubling defect and the six 30%-alpha hairlines together. `primaryBorder` (3px) and
`secondaryBorder` (2px) remain, with 2px the default as the reference intends.

Both decisions are encoded in the shared style layer, so call sites cannot opt out.

## Consequences

- **Easier:** one place decides weight and border geometry, so the remaining audit items get
  cheap — the press-feedback `ButtonStyle` (spec 010), the scrim token, and the corner-radius
  question all land in the same layer. A CI guard banning bare `lineWidth:` and inline
  `weight:` outside `Theme/` keeps it from regressing.
- **Harder / watch:** the diff is large and touches nearly every view — 201 `.black` and 273
  `.bold` sites for the type change, 202 border copies plus 23 hairline sites for the geometry.
  It is mechanical, but it is not small, and it should land slice by slice rather than in one
  commit.
- **Visual change is real and intended.** Body text gets noticeably lighter (700 → 500) and dense
  numeric readouts lose their per-row boxes. Screenshots in `docs/screenshots/` will be stale.
- **Still open** (deliberately out of scope here): whether the app records its square corners as a
  token (it is de-facto square — 272 of 282 strokes on `Rectangle` — but nothing says so), and
  whether ADR-0002 should state that the absent drop shadow is a conscious departure from the
  upstream reference rather than an omission.
