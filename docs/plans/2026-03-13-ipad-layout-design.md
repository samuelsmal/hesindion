# iPad-Optimized Layout Design

**Date**: 2026-03-13
**Status**: Approved

## Context

The app is primarily used on an older iPad in landscape with a hardware keyboard. The current layout wastes horizontal space — single-column stacks, no inline talent probe info, and no keyboard shortcuts. This design adapts the hero detail view for wider screens.

## Approach

Environment-based adaptive layout using `@Environment(\.horizontalSizeClass)`. `.regular` = landscape/wide optimizations, `.compact` = current layout preserved.

## Design

### 1. Attributes Column (Landscape) / Bar (Portrait)

In `HeroDetailView`, the content is wrapped in an `HStack` when `horizontalSizeClass == .regular`:

- **Left**: Fixed-width (~80pt) vertical attributes column showing all 8 attributes (MU, KL, IN, CH, FF, GE, KO, KK) with values. Neo-brutalist border on right edge. Does not scroll.
- **Right**: Scrollable hero detail content (everything except attributes).

In `.compact` mode, the existing horizontal `AttributesBar` is shown at the top of the scroll content, unchanged.

The `AttributesBar` view is reused in compact mode — no logic duplication.

### 2. Talent Rows with Probe Abbreviations

Each talent row is extended to show the 3 probe attribute abbreviations inline:

```
Tanzen           │ KL │ CH │ GE │     4
```

- Abbreviations sourced from existing `TalentProbeAttributes` lookup.
- Displayed in secondary/muted style with per-attribute colors from `AttributeColors`.
- Layout: name (flexible) → 3 fixed-width abbreviation cells → value (right-aligned, monospace).
- Applies in both compact and regular size classes (abbreviations are short enough).
- Defensive: if no probe mapping exists, show name + value only.

### 3. Personal Data Grid Layout

Replace vertical `FieldRow` stack with `LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))])`:

- Automatically flows into 2-3 columns based on available width.
- Each cell uses the existing `FieldRow` label/value pattern.
- `characteristics` field spans full width (can be long text).
- Works in both size classes — portrait gets 2 columns, landscape gets 3.

### 4. Ctrl+K Command Palette Shortcut

- Add `.onKeyPress(.init("k"), modifiers: .control)` to the root view in `HeroDetailView`.
- Triggers `showCommandSearch = true` — same state as the pull-down gesture.
- Pull-down gesture remains unchanged. Both triggers coexist.
- No changes to `CommandPaletteOverlay` itself.
