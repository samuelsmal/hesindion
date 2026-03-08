# Rulebook View & Swipe-to-Lookup Design

Date: 2026-03-07

## Overview

Add a browsable Regelbuch (rule book) as a first-class section in the app sidebar, and add swipe-to-reveal lookup buttons on talent/combat/ability rows in the hero detail view for quick rule lookups.

## 1. Sidebar Refactor

Refactor `HeroListView` into a general sidebar with two sections, driven by a selection enum:

```swift
enum SidebarSelection: Hashable {
    case rulebook
    case hero(PersistentIdentifier)
    case rule(String) // rule ID for deep-linking
}
```

- **Section 1 "Regelbuch"**: Single NavigationLink with book icon
- **Section 2 "Helden"**: Existing hero list

Detail pane switches on selection:
- `.rulebook` -> `RulebookView`
- `.hero(id)` -> `HeroDetailView`
- `.rule(id)` -> `RuleDetailView`
- `nil` -> `ContentUnavailableView`

## 2. Regelbuch View

Shown in detail pane when "Regelbuch" is selected.

- `.searchable` modifier for FTS filtering
- `ScrollView` with `LazyVStack(pinnedViews: .sectionHeaders)`
- One `CollapsibleSection` per rule category
- Each section lists rules as rows (name + short description)
- Tapping a rule updates selection to `.rule(id)`

Search behavior:
- Empty search: all categories collapsed
- Typing: filters via FTS, matching sections auto-expand

Neo-Brutalist styling consistent with existing views.

## 3. Rule Detail View

Adapted from existing `RuleDetailSheet` content, shown as full detail pane:

- Rule name as header (yellow Neo-Brutalist banner)
- Category badge
- Description text
- Metadata badges (cost, levels, max) if present
- Effects list if present
- Back button ("Zurueck zu [Hero Name]") when deep-linked from hero detail

## 4. Swipe-to-Reveal Refactor

Refactor `TalentSwipeRow` into generic `SwipeActionRow` with two buttons:

Interaction model:
- **Partial left-swipe** (~80pt): Reveals two buttons — lookup (book icon) + dice (dice icon)
- **Full left-swipe** (>120pt): Triggers dice throw directly
- **Tap book icon**: Navigates to rule via sidebar selection `.rule(id)`
- **Tap dice icon**: Triggers probe (existing behavior)

Where it applies:
- **Talents**: Both buttons (lookup + dice)
- **Combat techniques**: Both buttons (lookup + dice if applicable, otherwise just lookup)
- **Special abilities**: Lookup only
- **Vorteile/Nachteile**: Lookup only

Rule matching: Look up row name against rules database. Only show lookup button if a match exists. Only show dice button where a probe is applicable.

## 5. Deep-Linking from Hero Detail to Rule

When user taps lookup button on a swipe row:
1. Store current selection as "previous selection"
2. Update sidebar selection to `.rule(ruleId)`
3. Detail pane shows `RuleDetailView` with back button
4. Back button restores previous `.hero(id)` selection

The `SidebarSelection` binding is passed down into `HeroDetailView` so nested views can trigger navigation.

## Key Files to Modify

- `HeroListView.swift` -> refactor into sidebar with two sections
- `HeroDetailView.swift` -> accept `SidebarSelection` binding, pass to swipe rows
- `HeroDetailComponents.swift` -> refactor `TalentSwipeRow` into `SwipeActionRow`
- New: `RulebookView.swift` — category browser with search
- New: `RuleDetailView.swift` — full-pane rule detail (adapt from `RuleDetailSheet`)
- `RulesDatabase.swift` -> add method to list rules by category
- `ContentView.swift` -> may need updates if it references `HeroListView` directly
