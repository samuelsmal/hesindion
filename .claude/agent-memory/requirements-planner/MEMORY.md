# Requirements Planner Memory

## Project Structure
- Xcode project uses `PBXFileSystemSynchronizedRootGroup` -- files added to `iDSACompanion/` are auto-discovered; no pbxproj editing needed
- Template `Item.swift` and `ContentView.swift` exist from Xcode scaffolding; should be replaced/removed when real models arrive
- Build settings: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`
- Entry point: `iDSACompanionApp.swift` sets up `ModelContainer` with schema array

## Conventions (Established)
- App entry point registers all `@Model` types in `Schema([...])` array
- `NavigationSplitView` used for two-pane layout
- Neo-Brutalist design theme (bold borders, high contrast, flat shadows, stark typography)

## Key Files
- `/iDSACompanion/iDSACompanionApp.swift` -- app entry, ModelContainer setup
- `/iDSACompanion/ContentView.swift` -- current root view (template, to be replaced)
- `/iDSACompanion/Item.swift` -- template model (to be replaced)
- `/specs/001_heros-view/hero.json` -- reference JSON for hero import
- `/specs/001_heros-view/requirement.md` -- spec 001 requirements

## Spec Dependencies
- Spec 001 (Heroes View) -> Spec 002 (Hero Detail View) -- navigation target
