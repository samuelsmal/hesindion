# Hesindion Agent Memory

See topic files for details. Key references:
- patterns.md — API quirks, SwiftUI patterns, project conventions

## Critical: AppCommand is not Equatable
`AppCommand` holds a closure `execute: (CommandInput.Result?) -> Void`, so it cannot conform to `Equatable`.
Never use `.onChange(of: activeCommand)` — use `.onChange(of: activeCommand?.id)` instead (UUID is Equatable).

## Font API on iOS 26
`.font(.system(.largeTitle, design: .default, weight: .black))` with all three named params compiles fine in this codebase.
The codebase uses this pattern throughout (HeroDetailView.swift line 26, HeroListView.swift line 66, etc).
Earlier memory note about it not compiling was wrong — do not add `.fontDesign()` as a workaround.

## PBXFileSystemSynchronizedRootGroup
The project uses `PBXFileSystemSynchronizedRootGroup` (not traditional PBXGroup+PBXFileReference).
New Swift files placed in the correct subdirectory of `Hesindion/` are automatically picked up.
No pbxproj edits needed for new source files.

## @ViewBuilder limitations
Inside a `@ViewBuilder` function, imperative Swift (e.g. `let x: String; switch { x = ... }`) is NOT valid.
Extract computed values into separate non-ViewBuilder helper functions, then call the helper from the `@ViewBuilder` body.

## SidebarSelection pattern
`SidebarSelection` (enum: `.rulebook`, `.hero(PersistentIdentifier)`, `.rule(String)`) lives in `HeroListView.swift`
and is the single source of truth for navigation. `HeroDetailView` receives it as `@Binding var sidebarSelection: SidebarSelection?`.
Use `List(selection: $selection)` + `.tag(SidebarSelection.xxx)` — NOT `NavigationLink` — for sidebar items.
`previousSelection` is tracked via `.onChange(of: selection)` to support back-navigation from rule detail to hero.

## NavigationSplitView wiring
`HeroListView` is the root view. Its `NavigationSplitView` sidebar renders `sidebarContent` (two sections: Regelbuch,
Helden) and its detail pane switches on `SidebarSelection`:
  - `.rulebook` -> `RulebookView(sidebarSelection: $selection)`
  - `.hero(id)` -> `HeroDetailView(hero:sidebarSelection:)`
  - `.rule(id)` -> RuleDetailView (Task 4, placeholder until then)
`.navigationDestination(for:)` is NOT used — tag-based selection drives navigation.

## RulesDatabase
`RulesDatabase.shared` (in `Hesindion/Services/RulesDatabase.swift`) is a singleton backed by SQLite.
Key methods: `lookup(id:locale:) -> RuleDetail?`, `search(query:locale:limit:) -> [RuleSearchResult]`,
`rulesByCategory(_:locale:) -> [RuleSearchResult]`, `categories() -> [String]`.
`locale` defaults to `"de-DE"` in all methods.
`RuleDetail` has: `id, category, name, description, cost: String?, levels: Int?, max: Int?, effects: [RuleEffect]`.
`RuleEffect` has: `level: Int?, type, attribute: String?, value: Double?, scope: String?, description: String?`.

## Color.groupRulebook
`Color.groupRulebook` is a purple accent color used for rule/rulebook UI elements (added as a parallel task asset).
Neo-Brutalist badge pattern: `.background(Color.groupRulebook.opacity(0.2)).overlay(Rectangle().stroke(Color.black, lineWidth: 1))`.
