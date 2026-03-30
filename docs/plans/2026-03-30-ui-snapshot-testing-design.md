# UI Snapshot Testing Design

## Goal

Introduce visual regression testing and UI principle validation for the Hesindion app using snapshot testing. Catch unintended visual changes during PR review and validate readability, alignment, and dynamic type resilience.

## Approach

**Preview-based snapshot testing** using [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) (Point-Free). SwiftUI views are instantiated with mock data and rendered in the existing `HesindionTests` unit test target. No XCUITest target needed.

## Dependencies

- `swift-snapshot-testing` — added as a **test-only** SPM dependency (not shipped in app binary)

## Test Infrastructure

### SnapshotTestCase Helper

A base helper providing:
- Standard iPad configurations: 11" (1024x1366) and 13" (1032x1376) portrait
- Color scheme variants: `.light` and `.dark`
- Dynamic type variants: `.large` (default), `.accessibilityLarge`, `.accessibilityExtraExtraExtraLarge`
- Convenience method that snapshots a view across all 12 variant combinations (2 schemes x 2 sizes x 3 type scales)

### File Layout

```
HesindionTests/
  Snapshots/
    SnapshotTestHelpers.swift        # Base helper + iPad configs
    TestData.swift                   # Shared fake data factory
    HeroListViewSnapshotTests.swift
    HeroDetailViewSnapshotTests.swift
    CombatViewSnapshotTests.swift
    CombatRootViewSnapshotTests.swift
    CommandPaletteSnapshotTests.swift
    AdventureListViewSnapshotTests.swift
    DiceRollSheetSnapshotTests.swift
    WeatherDetailViewSnapshotTests.swift
  __Snapshots__/                     # Reference images (committed to git)
```

## View Coverage

| View | States | Fake Data Required |
|------|--------|--------------------|
| HeroListView | empty, populated (2-3 heroes) | Heroes with different professions |
| HeroDetailView | full hero sheet | Hero with attributes, talents, weapons, armor, spells, money, pets |
| CombatView | armor selection (initial) | Hero with melee + ranged weapons, armor, shield |
| CombatRootView | mid-combat | Active combat past initiative/loadout steps |
| CommandPaletteOverlay | open with search results | Hero context + matching query |
| AdventureListView | with entries | Adventure with text, dice roll, weather log entries |
| DiceRollSheet | roll result | Pre-filled roll result |
| WeatherDetailView | weather display | WeatherDay with temperature, wind, precipitation |

### Variant Matrix (per view state)

| Axis | Values | Count |
|------|--------|-------|
| Color scheme | `.light`, `.dark` | 2 |
| iPad size | 11" portrait, 13" portrait | 2 |
| Dynamic type | `.large`, `.accessibilityLarge`, `.accessibilityExtraExtraExtraLarge` | 3 |
| **Total per state** | | **12** |

## UI Principle Validation

No custom pixel-analysis tooling. The snapshot matrix itself validates UI principles — the human reviewer judges the images:

- **Dark/light readability** — both color schemes snapshotted; contrast issues visible in review
- **Layout alignment & clipping** — multiple iPad sizes expose overflow; dynamic type at max scale exposes truncation and overlap
- **Dynamic type resilience** — 3 scale levels catch views that break at large sizes
- **Consistency** — all views rendered with shared `DSALayout` constants and theme; deviations visible in snapshots

## Fake Data Strategy

`TestData` helper creates in-memory SwiftData models:

- Reuse `OptolithImportService` + `docs/sample_heros/` JSON for realistic hero data
- Programmatically create adventures, weather days, combat state, log entries
- Each test sets up its specific state (e.g., `CombatRootView` needs combat past armor/initiative steps)
- In-memory `ModelContainer` pattern already established in `HeroImportTests.swift`

## Makefile Integration

```makefile
test-ui:          # Run snapshot tests (check for regressions)
test-ui-record:   # Re-record all reference images
```

## Workflow

1. Make UI changes
2. `make test-ui` — snapshot tests run
3. On failure: review before/after/diff images in `__Snapshots__/failures/`
4. If change is intentional: `make test-ui-record`, commit updated reference images
5. If change is unintentional: fix the code
6. Reference images visible in PR diff for reviewer

## Git Considerations

- `__Snapshots__/` committed (reference images)
- `__Snapshots__/failures/` in `.gitignore` (transient)
- ~8 views x ~12 variants = ~96 PNG reference images (manageable repo size)
