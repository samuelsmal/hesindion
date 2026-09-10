# AGENTS.md

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
  `armorSelection → combatSetup → initiativeRoll → loadoutEquipment → root → (attack/defense/fernkampf/flucht/passierschlag)`
- **Attack flow**: attackChoice → weaponSelection → announcement (maneuvers, reach, modifiers) → execution (AT roll) → opponentDefense (Pariert/Ausgewichen/Treffer) → damage
- **Defense flow**: PA/AW roll → outcome → fumbleChoice on Patzer, Passierschlag on critical PA
- **Fernkampf flow**: fernkampfSetup (8 modifier categories) → fernkampfExecution (FK roll) → opponentDefense
- **Armor & Belastung**: `Armor.isEquipped` persists across combat sessions. `Hero` computes `totalRS`, `effectiveBE`, and `belastungPenalty` from equipped armor and Belastungsgewöhnung (SA_41). Penalties apply to AT, PA, AW, INI, GS.
- **Damage flow** ("Schaden nehmen"): user enters TP → app shows `max(0, TP - RS)` → confirm applies LP reduction
- **Initiative**: rolled at combat start with Belastung-adjusted base; re-rollable mid-combat via sheet
- **Combat session persistence**: state saved to Hero model; exit/re-enter resumes at root; "Kampf beenden" clears state
- **Schicksalspunkte**: Neuer Wurf (reroll failed AT/PA/AW/FK), W6 wiederholen (damage), Verteidigung stärken (+4), Zustand ignorieren
- **Patzertabellen**: 4 tables (Nahkampf AT, Verteidigung Waffe, Verteidigung Schild, Fernkampf) as alternative to 1W6+2 SP
- **Weapon reach**: opponent reach selector applies AT penalties (Kurz vs Mittel: -2, Kurz vs Lang: -4, Mittel vs Lang: -2)
- **Beengte Umgebung**: toggleable; Kurz 0, Mittel -4 AT/PA, Lang -8 AT/PA
- **Multiple defenses**: -3 cumulative per round, tracked and reset per round
- **Combat views split**: CombatView.swift (orchestrator), CombatSetupViews, CombatRootView, CombatAttackViews, CombatExecutionView, CombatDamageViews, CombatDefenseViews, CombatFernkampfViews

### Trefferzonen (Fokus-Regeln, optional)

- **Activation is per rule and per hero**: `FokusRule` (`Hesindion/Models/FokusRule.swift`) lists the optional Fokus-Regeln; `Hero.fokusRules: [String]` stores which the hero plays with, via `isFokusRuleActive(_:)` / `setFokusRule(_:active:)`. All off by default. These are the table's house rules, not a per-fight choice, so they live with `notes` / `colorSchemeId` — **not** in the combat-session block — and `clearCombatSession()` deliberately does not reset them. The UI is a "Fokus-Regeln" section on **`HeroSettingsView`** with one `ForEach(FokusRule.allCases)` row, so a new rule costs one enum case plus two localized strings.
- **Rules model** — pure value types, no SwiftUI or SwiftData: `HitZone` / `HitZoneTable` (all ten published 1W20 tables; odd rolls hit left, even right) and `WoundEffectCatalog` / `WoundEffectResolver`. `FumbleTable.swift` is the pattern.
- **Offence**: `HitZoneModifiers` emits the Zonenaufschlag as a `ModifierLine` (`SA_160` halves in melee, `SA_161` at range; `targetIsSurprised` is a GM flag on `ModifierContext`, deliberately *not* hero state, because it describes the opponent). After a landed hit a read-only `WoundEffectReminderCard` states the effect for the GM — nothing is applied, because opponents are not modelled.
- **Defence**: `CombatTakeDamageView` compares damage against `wundschwelle.max`; at each multiple the Selbstbeherrschung check is one step harder. Only a *failed* check applies Betäubung/Liegend via `setStateLevel`, or folds 1W3+1 into the **single** LP write on confirm; an unrolled probe means the GM has not adjudicated, so nothing is applied. The probe reuses `TalentProbeModal`. Selbstbeherrschung is a DSA 5 basic ability every hero has — a missing talent row is a data anomaly, and `Hero.selbstbeherrschung` falls back to a transient FW-0 stand-in so the probe can still be rolled.
- The offence/defence asymmetry is deliberate and explained in **ADR-0005**.

### Player States (Zustände & Status)

- **Catalog + storage**: `StateCatalog` (`Hesindion/Models/StateCatalog.swift`) is a static in-code list of 8 leveled Zustände (I–IV) and 17 binary Status with localized name/effects/cause/removal, SF Symbol, modifier mechanic, and implication chains. Per-hero state is one generic `@Model HeroStateEntry(stateID, level)` on `Hero` (cascade relationship) — see ADR-0003.
- **ModifierEngine integration**: active Zustände feed penalties into the `ModifierEngine`, which applies the DSA −5 Zustand-penalty cap via `isZustand` tagging
- **Derived states**: Schmerz and Belastung are computed (not stored) and excluded from manual editing via `StateCatalog.derivedIDs`; Belastung counts toward the −5 cap
- **UI surfaces**: a "Zustände & Status" section on hero detail (chips + add picker + detail sheet with prominent removal rules), a shared `StatesStrip`, and a combat-root states strip with a Handlungsunfähig/Bewegungsunfähig warning banner and per-round reminders
- **Eingeengt**: the `eingeengt` status is the single source of truth for the Beengte-Umgebung combat penalty (the toggle reads/writes it)
- **Entrückung**: a "gottgefällig" toggle in spell/liturgy casting

## Design

The UI follows a **Neo-Brutalist** design theme.

## Swift Configuration

- Main actor isolation is enabled by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` is enabled

## Git Workflow

- **Never commit directly to `main`** — all changes must be on a feature branch and merged via pull request
- Create a descriptive branch name before starting work (e.g., `fix/dark-mode-contrast`, `feat/dice-roller`)

## Code Creation Guidance

- **DSA rounding**: where a calculation yields a fraction and the rules do not clearly say otherwise, round **up** (`Int(ceil(...))`). Two exceptions: *"je volle N Punkte"* wordings are floor by construction, and for penalties "up" is ambiguous (numerically gentler vs. harsher in magnitude) — read the rule. Derived-value formulas live in `Hesindion/Engine/DerivedValueFormulas.swift` so the import and repair paths cannot drift. See **ADR-0006**.
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
