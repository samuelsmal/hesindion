# AGENT.md

Instructions for AI coding agents working on this repository.

## Project Overview

iOS companion app for DSA (Das Schwarze Auge / The Dark Eye) tabletop RPG sessions. Features include dice rolling, ability checks, and inventory tracking. Built with SwiftUI and SwiftData.

**Rules reference:** All DSA 5 rules can be looked up at https://dsa.ulisses-regelwiki.de/ — use this for verifying game mechanics (combat formulas, AT/PA, special abilities, etc.).

## Build & Run

This is an Xcode project (no SPM package, no CocoaPods). Open `Hesindion.xcodeproj` in Xcode.

Use `Makefile` targets for all simulator and device operations. If a needed target is missing, add it to the Makefile following the existing patterns rather than running raw commands.

```bash
make run          # Build, install, and launch on iPhone simulator
make run-ipad     # Build, install, and launch on iPad simulator
make deploy       # Build and deploy to physical device (Karl)
make clean        # Clean build artifacts
```

- **Deployment target:** iOS 26.0+
- **Device families:** iPhone and iPad
- **No external dependencies** — uses only Apple frameworks

## Architecture

- **SwiftUI** for all UI with **SwiftData** for persistence
- App entry point: `Hesindion/HesindionApp.swift` — sets up the `ModelContainer` and injects it via environment
- Data models use the `@Model` macro (SwiftData)
- Views use `@Query` for reactive data fetching and `@Environment(\.modelContext)` for mutations
- `NavigationSplitView` used for iPad-compatible two-pane layout

### Combat System

- `CombatView` is a full-screen orchestrator with a `CombatStep` enum driving navigation:
  `armorSelection → initiativeRoll → root → weaponSelection/execution/takeDamage`
- **Armor & Belastung**: `Armor.isEquipped` persists across combat sessions. `Hero` computes `totalRS`, `effectiveBE`, and `belastungPenalty` from equipped armor and Belastungsgewöhnung (SA_41). Penalties apply to AT, PA, AW, INI, GS.
- **Damage flow** ("Schaden nehmen"): user enters TP → app shows `max(0, TP - RS)` → confirm applies LP reduction
- **Initiative**: rolled at combat start with Belastung-adjusted base; re-rollable mid-combat via sheet

## Design

The UI follows a **Neo-Brutalist** design theme.

## Swift Configuration

- Main actor isolation is enabled by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` is enabled

## Code Creation Guidance

- Create minimal and small pieces of code, favour composing
- Try to find the sweet spot between small and large files, do some housekeeping from time to time

## Documentation Requirements

When making changes, keep the following up to date:

### CHANGELOG

Maintain `CHANGELOG.md` in the project root following [Keep a Changelog v1.0.0](https://keepachangelog.com/en/1.0.0/). Group changes under the `[Unreleased]` section using these categories:

- **Added** — new features
- **Changed** — changes to existing functionality
- **Deprecated** — soon-to-be removed features
- **Removed** — removed features
- **Fixed** — bug fixes
- **Security** — vulnerability fixes

When a release is cut, move `[Unreleased]` items into a versioned section with the date.

### Architecture Decision Records (ADRs)

Record significant architecture decisions in `docs/adr/` using the format defined in `docs/adr/0000-template.md`. Create a new ADR when:

- Introducing a new framework, library, or major dependency
- Changing the data model or persistence strategy
- Altering navigation patterns or app structure
- Making a decision that future contributors would question

Number ADRs sequentially (e.g., `0001-use-swiftdata.md`). Existing decisions can be superseded but never deleted.

### Project Documentation

Keep `docs/` current with the state of the project:

- Update or create documentation when adding major features or changing architecture
- Plans live in `docs/plans/`, ADRs in `docs/adr/`
- Sample data lives in `docs/sample_heros/`

## Data Policy

- **No rules data in git**: Actual DSA rules content (e.g., `rules.db` files) must NEVER be committed to the repo
