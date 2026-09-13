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

### Testing

**Always run one xcodebuild-backed target at a time, and never widen the destination set.** The `NO_CLONE` flags in the Makefile pin every test run to the single named simulator; test parallelisation otherwise clones the device and boots several simulators at once.

```bash
make test          # everything in the scheme: HesindionTests + HesindionUITests
make test-ui       # HesindionTests only (unit + swift-snapshot-testing)
make screenshots   # HesindionUITests only, exporting attachments to docs/screenshots/
```

Two test targets:

- **`HesindionTests`** — unit tests plus `swift-snapshot-testing` view snapshots. Runs in-process against in-memory `ModelContainer`s built by `TestData`.
- **`HesindionUITests`** — XCUITest. Drives the real app on the simulator and attaches screenshots (`XCTAttachment`, `.keepAlways`). `make screenshots` exports them with `xcrun xcresulttool export attachments` and `scripts/export_screenshots.py` renames the exports to the attachment names.

The app launches into an empty store, so UI tests use a **debug-only seed**: `UITestSeed` (`Hesindion/UITestSeed.swift`) reacts to the `-uitest-seed-hero` launch argument by wiping a *separate* store file, importing the bundled `Hesindion/Resources/UITestHero.json` (the `docs/sample_heros` Boronmir export with the base64 avatars stripped — 3.1 MB → 8 KB, since the resource ships in Release builds too), switching the Trefferzonen Fokus-Regel on and leaving a combat session open (so `CombatView` resumes at the combat root). It is guarded twice — `#if DEBUG` and the launch argument — and never touches the store a real user's app writes to. A second argument, `-uitest-fokus <comma-separated raw FokusRule values>`, switches further Fokus-Regeln on for a test that needs them (`UITest.launch(fokusRules:)`). A third, `-uitest-shield` (`UITest.launch(shield:)`), equips the hero's shield: with a shield in the loadout a parry goes through the weapon list rather than straight to the roll, and that is the path the defence tests are about. UI tests also reuse the existing `DebugLaunch` hooks (`debug load_default path combat`) for navigation.

Elements the UI tests drive carry `.accessibilityIdentifier`s (`heroSettings.fokusRules`, `commandPalette.search`, `combat.zone.<zone>`, `combat.woundEffectPanel`, `combat.woundEffectReminder`, `combat.takeDamage.increaseTP`, `combat.execution.*`). Prefer adding an identifier to an existing element over reshaping a view for a test.

Three known intermittent failures — none of them regressions:

- `SkillCheckModalSnapshotTests.testFailureWithNoSchips` — intermittent SIGTRAP, passes in isolation.
- `DiceRollerTests.testD20IsUniform` — unseeded chi-square, fails ~1 run in 200 by construction.
- `HeroImportTests.importBoronmirFromOptolith` — fails on `combatTechniques.count == 0` roughly 1 full run in 4, passes in isolation and on rerun. The techniques come from `rules.db`, and `RulesDatabase.allCombatTechniqueIds()` returns `[]` on any `sqlite3_prepare_v2` failure, so a transient one is indistinguishable from an empty table. Worth chasing — the same silent empty would import a hero with no combat techniques.

## Architecture

- **SwiftUI** for all UI with **SwiftData** for persistence
- App entry point: `Hesindion/HesindionApp.swift` — sets up the `ModelContainer` and injects it via environment
- Data models use the `@Model` macro (SwiftData)
- Views use `@Query` for reactive data fetching and `@Environment(\.modelContext)` for mutations
- `NavigationSplitView` used for iPad-compatible two-pane layout

### Combat System

- `CombatView` is a full-screen orchestrator with a `CombatStep` enum driving navigation:
  `armorSelection → combatSetup → initiativeRoll → root → (attack/defense/fernkampf/flucht/passierschlag)`
- **`combatSetup` is the preparation screen** and every hero sees it: armour restated, the loadout chosen (`CombatLoadoutPicker`), Plänkler-Formation, mount and Beengte Umgebung. The weapon used to be chosen two steps later, *after* the initiative roll, so nothing before the first attack showed what the hero was about to fight with. `loadoutEquipment` is now the mid-fight "Ausrüstung wechseln" screen only, reached from the root and returning to it
- **Attack flow**: attackChoice → weaponSelection → announcement (maneuvers, reach, modifiers) → execution (AT roll) → opponentDefense (Pariert/Ausgewichen/Treffer) → damage
- **Defense flow**: PA/AW roll → outcome → fumbleChoice on Patzer, Passierschlag on critical PA
- **Fernkampf flow**: fernkampfSetup (8 modifier categories) → fernkampfExecution (FK roll) → opponentDefense
- **Armor & Belastung**: `Armor.isEquipped` persists across combat sessions. `Hero` computes `totalRS`, `effectiveBE`, and `belastungPenalty` from equipped armor and Belastungsgewöhnung (SA_41). Penalties apply to AT, PA, AW, INI, GS.
- **Damage flow** ("Schaden nehmen"): user enters TP → app shows `max(0, TP - RS)` → confirm applies LP reduction
- **Initiative**: rolled at combat start with Belastung-adjusted base; re-rollable mid-combat via sheet
- **Combat session persistence**: state saved to Hero model; exit/re-enter resumes at root; "Kampf beenden" clears state
- **Schicksalspunkte**: Neuer Wurf (reroll failed AT/PA/AW/FK), W6 wiederholen (damage), Verteidigung stärken (+4), Zustand ignorieren
- **Patzertabellen**: 4 tables (Nahkampf AT, Verteidigung Waffe, Verteidigung Schild, Fernkampf) as alternative to 1W6+2 SP
- **Kritische Erfolge (Fokus-Regeln, optional)**: 3 2W6 tables (Angriff, Verteidigung Nahkampf, Verteidigung Fernkampf) replacing double damage / Passierschlag / the undiminished next defence, each with a nested 1W20 Fokusregel. `CriticalSuccessTable` + `CriticalSuccessRefinements` are the data, `CombatCriticalSuccessView` the screen. Switching a rule on *offers* its table, it does not impose it: the screen asks basic rule or table, the way `CombatFumbleChoiceView` asks 1W6+2 SP or Patzertabelle. Only the damage arithmetic is applied (`CriticalDamage` on `CombatStep.opponentDefense`); opponent conditions and "bis zum Ende der nächsten KR" buffs are stated for the GM — see **ADR-0011**.
- **Weapon reach**: opponent reach selector applies AT penalties (Kurz vs Mittel: -2, Kurz vs Lang: -4, Mittel vs Lang: -2). The hero's side of the comparison is the reach of the thing *in the hand* — `Hero.reach(ofLoadoutNamed:)`, passed to the engine as `ModifierContext.attackerReach` — not `selectedWeapon`, which is the wrong answer for an off-hand swing, a Schildattacke and above all for Raufen (kurz; the old fallback was mittel, so a bare-handed hero closed on a spear for free)
- **Beengte Umgebung**: toggleable; Kurz 0, Mittel -4 AT/PA, Lang -8 AT/PA
- **Multiple defenses**: -3 per defence *already made* this round, cumulative, reset per round. **Parries and dodges are counted apart** — the penalty is per defence type, so the round's first dodge is unmodified however often the hero has parried. The count is incremented when a defence roll is set up (`CombatExecutionView.onAppear`), not when the button is tapped, so the first defence of a round is unmodified
- **`CombatSituation`** (`Hesindion/Engine/CombatSituation.swift`) is the round's flags as one value and the single source of defence modifier lines. Both the combat root and the weapon list build from it — the weapon list, which a shield or a second weapon forces you through, used to build none at all
- **A value the player can roll *or* be told is a fork, not two controls**: they choose the route, the chosen route runs at once (a roll rolls immediately), and only its result stays on screen (`WoundEffectDamageControl`). Both routes on screen at once leaves "what wins if I roll and then type?" unanswered
- **Combat-technique ids live in `CombatTechniqueID`, never as bare strings.** Three sets of them were written inline with the names in comments and all three comments were wrong: the two-handed grip was withheld from Armbrüste rather than Fechtwaffen, "needs both hands, not from the saddle" was applied to *Lanzen*, and `isSchusswaffe` matched Schleudern and Schwerter. `CombatTechniqueIDTests` checks the enum against `rules.db`
- **SF Symbols has no weapons**, so the melee glyphs are the app's own (`Hesindion/Assets.xcassets/weapon.*.imageset`, drawn flat and hard-edged), mapped from the technique by `WeaponIcon` and rendered by `WeaponIconView`. `hammer.fill` used to stand in for every weapon in the loadout
- **Rules data is looked up, never inferred.** The Trefferzonen size category belongs to the *species* (`HitZoneSizes`: Zwerge klein, Menschen and Elfen mittel), with the player's own setting on top — deriving it from the hero's height would be a plausible-looking guess at a rule that says something else
- **The opponent rolls their own dice.** Where a rule turns on the opponent's check, the app asks the player for the outcome (`WoundEffectReminderCard`) and never rolls for the other side — the opponent is not modelled (ADR-0005)
- **An open question holds the way out.** While the Wundeffekt is still asking — the opponent's check unanswered, or a failed check whose damage is unsettled — the damage screen does not offer "Neue Aktion". Two live controls that mean "answer this" and "leave without answering" read as though the question were optional, and leaving drops an announced Wundeffekt out of the reported total
- **A screen that writes something says what it wrote.** The take-damage confirm reports the life points that remain and every state that went up (`CombatDamageOutcomeBox`), by comparing against a snapshot taken before the write — Schmerz is derived from the LP total and moves without any step of the flow touching it
- **One primary action, one button.** `CombatActionButton` draws "Weiter", "Bestätigen" and "Neue Aktion": same size, same box, in the content column at the end of the flow. "Weiter" used to be pinned edge to edge below the scroll view, which reads as a tab bar rather than as the next step
- **The Wundschwelle is core, the Wundeffekt is not**: the take-damage screen states the comparison against the hero's Wundschwelle whether or not the Trefferzonen Fokus-Regel is on (`CombatWundschwelleRow`); the zone effect, its Selbstbeherrschung probe and its extra damage stay behind the rule (`CombatWoundEffectPanel`). Only one of the two prints the comparison at a time
- **Damage parts travel apart**: `CombatStep` carries the weapon's own `damageFormula` *and* `damageLines`, never a pre-folded string, so the damage screen can print every part and no screen can add the same bonus twice. `CombatBreakdownBox` renders both the AT/PA/AW and the TP calculation
- **`DamageModifiers`** (`Hesindion/Engine/DamageModifiers.swift`) is the same idea for TP: Wuchtschlag, the two-handed grip, Sturmangriff and Golgariten-Stil's +1 TP, as lines *and* as the adjusted formula from one call, so the box the player reads cannot drift from the formula the dice get. `DamageFormula` parses and rewrites the damage string; nothing else should carry a copy of that regex
- **Karmale Objekte (Fokusregel, optional)**: a consecrated weapon deals regular damage to a demon and *doubles* against a demon of its opposing deity (`KarmalWeapon`). Both facts are answers, not derivations — which weapon is geweiht is a per-hero setting under the rule's toggle (`Hero.consecratedWeapons`), and what is on the other end is the GM's call, asked on the announcement screen. The multiplier travels beside the critical's own as `damageMultiplier` and gets a row of its own in the calculation
- **What the app cannot know**: no Optolith export carries a weapon's Leiteigenschaft threshold (TP/KK) — there is no equipment table in `rules.db` (issue #14) — so the damage roll has a manual TP modifier for it. Nor does it carry a Weihe, which is why the consecrated-weapon list is a setting
- **Combat views split**: CombatView.swift (orchestrator), CombatSetupViews, CombatRootView, CombatAttackViews, CombatExecutionView, CombatDamageViews, CombatDefenseViews, CombatFernkampfViews

### Trefferzonen (Fokus-Regeln, optional)

- **Activation is per rule and per hero**: `FokusRule` (`Hesindion/Models/FokusRule.swift`) lists the optional Fokus-Regeln; `Hero.fokusRules: [String]` stores which the hero plays with, via `isFokusRuleActive(_:)` / `setFokusRule(_:active:)`. All off by default. These are the table's house rules, not a per-fight choice, so they live with `notes` / `colorSchemeId` — **not** in the combat-session block — and `clearCombatSession()` deliberately does not reset them. The UI is a "Fokus-Regeln" section on **`HeroSettingsView`** with one `ForEach(FokusRule.allCases)` row, so a new rule costs one enum case plus two localized strings. Five rules ship today: `trefferzonen` and the four `kritischeErfolge*` cases.
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

- **No system dialogs.** A confirmation is `DSAModal` + `DSAModalButton`, never `.alert` or `.confirmationDialog`: a system dialog brings rounded corners, blurred material and tinted text onto a screen built without any of the three. The same goes for `.contextMenu`
- **An either/or is drawn as one group with a `DSAOrDivider` between the branches**, both at the same visual weight. Two controls stacked in a box read as two independent actions, and giving one the red fill turns a free choice into a recommendation the rules do not make
- **The combat root's actions are grouped by rules category** — AKTION, REAKTION, SCHICKSALSPUNKTE, EINTRAGEN — and colour then carries one meaning each: red = it is rolled, gold = it costs a Schicksalspunkt, dark = it only records something. Nothing in the app is teal
- **One calculation grammar: `CombatBreakdownBox`.** Parts on top (value left, where it comes from right), the result in the dark bar inside the same border. A bare number in a dark bar is that grammar's *total*, so anything shown that way must say what it is the total of — a dice sum presented like a result reads as the damage
- **A modal is a sibling of the layout, not a child of a panel.** It is drawn in the root `ZStack` next to `SplitContentLayout` (see `HeroDetailView`, and `SplitContentLayout` itself for the log's delete), because a modal placed inside a side panel is bounded by it — in landscape that is a third of the screen

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

The root `CHANGELOG.md` is the only copy. The in-app Changelog screen reads it out
of the app bundle, where the target's *Bundle CHANGELOG.md* script phase puts it at
build time. Do not add a copy under `Hesindion/Resources/` — that directory is a
file-system synchronized group, so a file dropped there is bundled silently, and the
copy that used to live there fell eleven commits behind before anyone noticed.

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
