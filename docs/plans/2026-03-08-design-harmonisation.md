# Design Harmonisation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Harmonise the Neo-Brutalist design system across all views, extracting design tokens, unifying colors, fixing inconsistencies, and replacing long-press interactions with swipe-to-action.

**Architecture:** Bottom-up approach -- first extract shared design tokens (colors, layout, animation constants), then fix each view file to use them, then refactor interaction patterns (swipe replaces long-press, merge EquipmentRow into SwipeActionRow).

**Tech Stack:** SwiftUI, Swift

---

### Task 0: Extract design tokens into DSALayout and extend DSAAnimation

**Files:**
- Create: `iDSACompanion/Theme/Layout.swift`
- Modify: `iDSACompanion/Theme/Animations.swift`
- Modify: `iDSACompanion/Theme/AttributeColors.swift`

**Step 1: Create `Layout.swift` with layout constants**

```swift
import SwiftUI

enum DSALayout {
    // Horizontal padding for sections and content areas
    static let horizontalPadding: CGFloat = 16
    // Inner content padding (rows, cells)
    static let contentPadding: CGFloat = 12
    // Vertical padding for headers (combat, modal, section)
    static let headerVerticalPadding: CGFloat = 14
    // Border widths — Neo-Brutalist hierarchy
    static let primaryBorder: CGFloat = 3
    static let secondaryBorder: CGFloat = 2
    static let tertiaryBorder: CGFloat = 1
}
```

**Step 2: Add animation constants to `Animations.swift`**

Add to `DSAAnimation`:
```swift
/// Opacity for the "dice tumbling" background tint.
static let animatingBackgroundOpacity: Double = 0.15
```

**Step 3: Add semantic dark color to `AttributeColors.swift`**

Add to `Color` extension:
```swift
/// Dark accent background used for stat badges and INI boxes.
static let dsaDark = Color(white: 0.18)
```

**Step 4: Commit**

```
feat: extract design tokens into DSALayout, DSAAnimation, and Color extensions
```

---

### Task 1: Unify Color.yellow to Color.groupPersonalData

**Files:**
- Modify: `iDSACompanion/Views/HeroDetailView.swift`
- Modify: `iDSACompanion/Views/TalentProbeModal.swift`
- Modify: `iDSACompanion/Views/CommandPaletteOverlay.swift`
- Modify: `iDSACompanion/Views/EditCurrentModal.swift`
- Modify: `iDSACompanion/Views/HeroListView.swift`

Replace every occurrence of `Color.yellow` with `Color.groupPersonalData` in:

- `HeroDetailView.swift:28` — hero name banner background
- `TalentProbeModal.swift:70` — header background
- `TalentProbeModal.swift:159` — dice animating background (also change opacity to `DSAAnimation.animatingBackgroundOpacity`)
- `TalentProbeModal.swift:292-305` — modifier edit overlay buttons
- `CommandPaletteOverlay.swift:223` — search field background
- `CommandPaletteOverlay.swift:314` — section header background (also change opacity to `DSAAnimation.animatingBackgroundOpacity`)
- `CommandModal:351` — header background
- `CommandModal:382,397` — +/- buttons
- `CommandModal:420` — confirm button
- `EditCurrentModal.swift:47,60` — +/- buttons
- `HeroListView.swift:130` — import button
- `RegenerierenSheet` header, dice bg, modifier buttons, confirm button

**Step 1: Do all replacements**

Use `replace_all` on each file to replace `Color.yellow` with `Color.groupPersonalData`.

For opacity values, also replace:
- `.opacity(0.3)` and `.opacity(0.25)` with `.opacity(DSAAnimation.animatingBackgroundOpacity)`

**Step 2: Commit**

```
fix: unify Color.yellow to Color.groupPersonalData across all views
```

---

### Task 2: Fix RegenerierenSheet dice timing

**Files:**
- Modify: `iDSACompanion/Views/CommandPaletteOverlay.swift`

**Step 1: Replace hardcoded 120ms with DSAAnimation constant**

In `RegenerierenSheet.startAnimation()` (line ~174), replace:
```swift
try await Task.sleep(nanoseconds: 120_000_000)
```
with:
```swift
try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval)
```

**Step 2: Commit**

```
fix: use DSAAnimation.diceTumbleInterval in RegenerierenSheet
```

---

### Task 3: Apply design tokens across all views

**Files:**
- Modify: `iDSACompanion/Views/CombatView.swift`
- Modify: `iDSACompanion/Views/TalentProbeModal.swift`
- Modify: `iDSACompanion/Views/CommandPaletteOverlay.swift`
- Modify: `iDSACompanion/Views/HeroDetailView.swift`
- Modify: `iDSACompanion/Views/HeroDetailComponents.swift`
- Modify: `iDSACompanion/Views/RulebookView.swift`
- Modify: `iDSACompanion/Views/RuleDetailView.swift`
- Modify: `iDSACompanion/Views/HeroListView.swift`

**Step 1: Replace `Color(white: 0.18)` with `Color.dsaDark`**

In `CombatView.swift`, replace all `Color(white: 0.18)` with `.dsaDark`.

**Step 2: Replace hardcoded border lineWidths with DSALayout constants**

Across all files, replace:
- `lineWidth: 3)` on primary elements with `lineWidth: DSALayout.primaryBorder)`
- `lineWidth: 2)` on secondary elements with `lineWidth: DSALayout.secondaryBorder)`
- `lineWidth: 1)` on tertiary elements with `lineWidth: DSALayout.tertiaryBorder)`

**Step 3: Replace hardcoded padding values with DSALayout constants**

Replace common patterns:
- `.padding(.horizontal, 16)` with `.padding(.horizontal, DSALayout.horizontalPadding)` (section-level)
- `.padding(.horizontal, 12)` with `.padding(.horizontal, DSALayout.contentPadding)` (row-level)
- `.padding(.vertical, 14)` with `.padding(.vertical, DSALayout.headerVerticalPadding)` (headers)

**Step 4: Replace hardcoded animating opacity**

In `CombatView.swift`, replace `combatAccent.opacity(0.12)` with `combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity)`.

**Step 5: Fix "Neue Aktion" button border from 2 to primaryBorder (3)**

In `CombatExecutionView`, the "Neue Aktion" button at ~line 497 uses `lineWidth: 2`. Change to `DSALayout.primaryBorder`.

**Step 6: Commit**

```
refactor: apply DSALayout and DSAAnimation tokens across all views
```

---

### Task 4: Add borders to TalentProbeModal boxes

**Files:**
- Modify: `iDSACompanion/Views/TalentProbeModal.swift`

The dice boxes, modifier boxes, and result boxes in TalentProbeModal currently have no border, unlike their CombatView counterparts.

**Step 1: Add border to diceBox**

In `diceBox(value:isAnimating:)`, add after `.background(...)`:
```swift
.overlay(Rectangle().stroke(Color.black, lineWidth: DSALayout.secondaryBorder))
```

**Step 2: Add border to modBox**

In `modBox(index:)`, add after `.background(...)`:
```swift
.overlay(Rectangle().stroke(Color.black, lineWidth: DSALayout.secondaryBorder))
```

**Step 3: Add border to resultBox**

In `resultBox(value:)`, add after `.background(...)`:
```swift
.overlay(Rectangle().stroke(Color.black, lineWidth: DSALayout.secondaryBorder))
```

**Step 4: Fix header vertical padding to use DSALayout.headerVerticalPadding**

In `headerView`, change `.padding(.vertical, 12)` to `.padding(.vertical, DSALayout.headerVerticalPadding)`.

**Step 5: Commit**

```
fix: add Neo-Brutalist borders to TalentProbeModal boxes
```

---

### Task 5: Translate English section headers to German

**Files:**
- Modify: `iDSACompanion/Views/HeroDetailView.swift`

**Step 1: Replace all English CollapsibleSection/CollapsibleGroup titles**

| Current (English) | New (German) |
|---|---|
| `"Personal Data"` | `"Persoenliche Daten"` |
| `"Talents"` | `"Talente"` |
| `"Combat"` | `"Kampf"` |
| `"Equipment"` | `"Ausruestung"` |
| `"Experience"` | `"Erfahrung"` |
| `"PersonalData"` | `"Persoenliche Daten"` |
| `"DerivedValues"` | `"Abgeleitete Werte"` |
| `"Advantages"` | `"Vorteile"` |
| `"Disadvantages"` | `"Nachteile"` |
| `"GeneralSpecialAbilities"` | `"Allgemeine Sonderfertigkeiten"` |
| `"Languages"` | `"Sprachen"` |
| `"Scripts"` | `"Schriften"` |
| `"CombatTechniques"` | `"Kampftechniken"` |
| `"CombatSpecialAbilities"` | `"Kampf-Sonderfertigkeiten"` |
| `"MeleeWeapons"` | `"Nahkampfwaffen"` |
| `"Shields"` | `"Schilde"` |
| `"Armors"` | `"Ruestungen"` |
| `"Money"` | `"Geld"` |
| `"Mount"` | `"Reittier"` |

Note: Use ae/oe/ue instead of umlauts (consistent with existing patterns in the codebase like `backLabel`).

**Step 2: Commit**

```
fix: translate all English section headers to German
```

---

### Task 6: Extend SwipeActionRow to support right-side edit actions and merge EquipmentRow

**Files:**
- Modify: `iDSACompanion/Views/HeroDetailView.swift` (SwipeActionRow lives here)
- Modify: `iDSACompanion/Views/HeroDetailComponents.swift` (delete EquipmentRow)

**Step 1: Add a delete action variant to SwipeAction**

SwipeAction already has `icon`, `color`, `action`. This is sufficient — EquipmentRow's delete action is just `SwipeAction(icon: "trash", color: .red) { onDelete() }`.

**Step 2: Remove EquipmentRow from HeroDetailComponents.swift**

Delete the entire `EquipmentRow` struct (lines 270-312).

**Step 3: Update equipment usage in HeroDetailView.swift**

Replace:
```swift
EquipmentRow(item: item) { modelContext.delete(item) }
```
with:
```swift
SwipeActionRow(
    label: item.name,
    value: String(format: "%.2f st", item.weight),
    actions: [SwipeAction(icon: "trash", color: .red) { modelContext.delete(item) }]
)
Divider()
```

**Step 4: Commit**

```
refactor: merge EquipmentRow into SwipeActionRow with delete action
```

---

### Task 7: Replace long-press with swipe actions for derived values

**Files:**
- Modify: `iDSACompanion/Views/HeroDetailView.swift`
- Delete: `iDSACompanion/Views/EditCurrentModal.swift`

This is the biggest change. Currently, `interactiveDerivedRow` uses `onLongPressGesture` to open `EditCurrentModal` (a full overlay with +/- buttons). We replace this with swipe-to-reveal edit actions.

**Step 1: Replace `interactiveDerivedRow` with SwipeActionRow + edit icon**

Replace the `interactiveDerivedRow` function with calls to `SwipeActionRow` that have an edit action. The edit action opens the `CommandModal` (which already has +/- integer editing).

For each derived value (lebensenergie, schicksalspunkte, etc.), the swipe action should be:
```swift
SwipeActionRow(
    label: "lebensenergie",
    value: "\(dv.lebensenergie.current) / \(dv.lebensenergie.max)",
    actions: [SwipeAction(icon: "pencil", color: .groupPersonalData) {
        activeCommand = AppCommand(...)  // same AppCommand as before
    }]
)
Divider()
```

**Step 2: Replace money long-press with swipe actions**

Replace `moneyRow` long-press with SwipeActionRow + edit action:
```swift
SwipeActionRow(
    label: label,
    value: "\(get())",
    actions: [SwipeAction(icon: "pencil", color: .groupPersonalData) {
        activeEdit = ActiveEdit(...)
    }]
)
Divider()
```

Wait — we still need `EditCurrentModal` for money since money has unbounded max. The `CommandModal` requires an `AppCommand` with specific input. Keep `EditCurrentModal` for now but trigger it via swipe instead of long-press.

Actually, let's keep it simpler: keep `activeEdit` and `EditCurrentModal` for money rows, but trigger via swipe. For derived values, the `activeCommand = AppCommand(...)` pattern already works and opens `CommandModal`.

**Step 3: Replace melee weapons / shields long-press with swipe to combat**

Replace:
```swift
.onLongPressGesture { showCombatMode = true }
```
with an additional swipe action on the SubfieldBlock. Since SubfieldBlock isn't a SwipeActionRow, wrap the content:
```swift
SwipeActionRow(
    label: w.name,
    value: "",
    actions: [SwipeAction(icon: "bolt.fill", color: .groupCombat) { showCombatMode = true }]
) // but we need SubfieldBlock content inside...
```

Better approach: make SwipeActionRow accept a `@ViewBuilder` content parameter as an alternative to label/value strings. Add an initializer:

```swift
init(actions: [SwipeAction], @ViewBuilder content: () -> some View)
```

This lets us wrap SubfieldBlock in a swipe row.

**Step 4: Remove `activeEdit` state and `EditCurrentModal` overlay from HeroDetailView if no longer needed**

If money rows use `EditCurrentModal`, keep it. Remove `activeEdit` only if all uses are migrated.

Actually: derived values already use `activeCommand`/`CommandModal`. Money rows use `activeEdit`/`EditCurrentModal`. Keep both but swipe-trigger both.

**Step 5: Remove TalentProbeModal long-press modifier edit**

In `TalentProbeModal`, the modifier boxes use `onLongPressGesture` to open an edit overlay. Replace with:
- Direct tap on modifier box cycles through common values, OR
- Add +/- buttons flanking each modifier box (matching CombatView's modifier style)

The simplest consistent approach: add compact +/- buttons above/below each modifier box (like CombatView uses left/right). Actually, let's just add small tap targets: tap the left half decrements, tap the right half increments. This avoids adding more complex swipe in a modal context.

Better: replace the modifier row with a layout matching CombatView's modifier box — a row with [-] [value] [+] per attribute column.

**Step 6: Commit**

```
refactor: replace all long-press interactions with swipe-to-action
```

---

### Task 8: Fix RuleDetailView system color usage

**Files:**
- Modify: `iDSACompanion/Views/RuleDetailView.swift`

**Step 1: Replace `Color(UIColor.secondarySystemBackground)` with a fixed Neo-Brutalist color**

In `effectRow`, replace:
```swift
.background(Color(UIColor.secondarySystemBackground))
```
with:
```swift
.background(Color.groupRulebook.opacity(0.08))
```

This uses the semantic rulebook purple at very low opacity, keeping the Neo-Brutalist fixed-color approach.

**Step 2: Commit**

```
fix: replace system adaptive color with fixed Neo-Brutalist color in RuleDetailView
```

---

### Task 9: Build and verify

**Step 1: Build the project**

```bash
xcodebuild -project iDSACompanion.xcodeproj -scheme iDSACompanion -sdk iphonesimulator build
```

**Step 2: Fix any build errors**

**Step 3: Final commit if fixups needed**

```
fix: resolve build errors from design harmonisation
```
