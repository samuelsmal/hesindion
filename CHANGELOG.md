# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- Zustände & Status tracking per hero — a static catalog of 8 DSA 5 Zustände (leveled I–IV) and 17 binary Status with localized effects, cause, and removal rules; managed via a "Zustände & Status" section on hero detail (chips, add picker, detail sheet with prominent removal rules) and a shared `StatesStrip`
- Automatic modifier integration for states: active Zustände feed penalties into the ModifierEngine with the DSA −5 Zustand-penalty cap; combat root shows a states strip, a Handlungsunfähig/Bewegungsunfähig warning banner, and per-round reminders
- Entrückung "gottgefällig" toggle in spell and liturgy casting
- Schip (fate point) reroll option on failed skill and spell checks — on a regular failure, the locked 3W20 dice become reroll-selectable (all selected by default) and a "Schip: Neuer Wurf" button spends one Schip to reroll the chosen dice
- UI snapshot testing infrastructure using swift-snapshot-testing
- Snapshot tests for 7 views (HeroList, HeroDetail, Combat, CombatRoot, Adventure, DiceRoll, WeatherDay) across 12 iPad/color/dynamic-type variants
- `make test-ui` and `make test-ui-record` Makefile targets
- TestData factory for creating fake SwiftData models in tests
- `DiceRoller` engine — pure, testable dice rolling with an injectable `RandomNumberGenerator`
- Statistical tests for dice fairness (`DiceRollerTests`): chi-square uniformity for W3/W6/W20, mean, serial-independence, and end-to-end 3d20 → SkillCheckEngine critical-rate checks
- Success-probability tests verifying sampled pass rates for realistic ability profiles match exact enumeration of all 8000 outcomes
- Per-ability **theoretical success rate** on each talent row — traffic-light dot + % computed by exact enumeration (`SkillCheckEngine.successProbability`)
- Per-ability **recorded success rate** (overall %, number of Proben, sessions, and best session), revealed under every talent row at once via the Talents section's **"Aufgezeichnete Werte"** toggle
- **Session grouping** of the action log into play sessions separated by ≥ 8h gaps (`SessionGrouper`), with per-session success-rate headers in the Log panel
- `TalentStatistics` engine for aggregating recorded checks, plus tests (`SessionGrouperTests`, `TalentStatisticsTests`, `SuccessProbabilityTests`)

### Changed

- `DiceRollSheet` and `SkillCheckModal` now route all rolls through `DiceRoller` instead of calling `Int.random(in:)` inline
- Recorded talent stats moved from per-row tap-to-expand to a single section-level toggle, keeping rows uncluttered while still showing the theoretical % inline

### Fixed

- `make test`/`test-ui`/`test-ui-record` no longer clone the simulator per test worker (`-parallel-testing-enabled NO`, `-maximum-concurrent-test-simulator-destinations 1`); `test-ui-record` uses the correct `SNAPSHOT_TESTING_RECORD=all` value

### Changed

- Schmerz now flows through the new states system rather than a standalone computation, with Belastung counting toward the −5 Zustand cap
- The Beengte-Umgebung combat toggle now persists as the `eingeengt` status (its single source of truth) and survives combat exit

## [0.3.0] - 2026-03-28

### Added

- General-purpose dice roller ("Würfeln") command with configurable count and sides, tumble animation, and action log integration

## [0.2.0] - 2026-03-23

### Added

- Generic ModifierEngine for unified modifier calculation across melee, ranged, defense, magic, liturgy, and talent checks
- Magic casting flow — standalone SpellProbeModal with expandable modifications section
- Combat spell casting — "Zaubern" action with spell selection, setup, multi-round casting with round tracker, and 3d20 execution
- Magic & Karma section in hero detail showing spells, liturgies, cantrips, and blessings with swipe-to-roll
- SkillCheckModal — unified 3d20 skill check UI shared by talents and spells
- Magic-specific modifiers: maintained spells, foreign tradition, gestures/formula, Bann des Eisens, distraction, spell modifications
- Effects scraper for populating rule effects from ulisses-regelwiki.de
- DB-sourced rule effect modifiers via RuleEffectModifiers loader

### Changed

- Melee attack, defense, and ranged modifiers now use ModifierEngine instead of hardcoded logic
- TalentProbeModal refactored to delegate to generic SkillCheckModal
- CheckDomain split: meleeParry and meleeDodge replace single meleeDefense for cleaner modifier targeting
- RulesDatabase.lookupEffects() made internal for engine access
- build_db.py now accepts both dict and flat list YAML formats for effects import

### Added (prior)

- Abenteuer (Adventure) system with weather generation
- Aventurian calendar with 12 months + Namenlose Tage
- Weather generator porting DSA 4.1 WdE p.156ff tables
- 13 climate regions from Ewiges Eis to Südmeer
- Day-by-day and bulk weather generation
- Date jumping with time-jump markers in timeline
- Plain-text weather export via share sheet
- Hero ↔ Adventure linking via hero settings
- New sidebar section for adventures

- Fernkampf (ranged) execution view: W20 FK roll with animated dice, modifier breakdown, critical/fumble confirmation, Schip reroll, and distance-adjusted damage formula
- Fernkampf criticals and fumbles mirror melee: roll 1 confirms critical hit (halved defense + double damage), roll 20 confirms fumble using the dedicated FK fumble table
- Opponent defense view now shows "Keine Parade mit Waffe möglich" and defense penalty hint for ranged attacks
- `CombatAction.fernkampf` added so FK fumbles route to the correct `FumbleTableType.fernkampf` table

- Passierschlag (free strike) view: AT-4 attack with no maneuvers, no critical successes or fumbles, with animated dice rolling and damage calculation
- Passierschlag button on critical parry success in defense outcome
- Per-profession color schemes for hero detail views (19 palettes: priests by deity, warriors, mages, mundane)
- Hero settings view accessible via command palette ("Einstellungen für <Hero>")
- Color scheme picker with visual swatch previews and automatic profession-based detection
- Combat execution rolls (AT/PA/AW) now logged automatically with outcome and effective value
- Schip reroll usage logged as dedicated combat action entry

### Changed

- Combat log descriptions enriched: critical/fumble markers on attacks, TP instead of "Schaden ausgeteilt", structured schip/fumble/flucht/opponent-defense text

- Mount pre-check (Galopp + Reiten) redesigned as single-screen vertical flowchart with collapsing steps and connector arrow
- Talent probe modal: enlarged modifier buttons (44pt tap targets) for easier use
- Talent probe modal: constrained max width to 400pt on wide screens
- Sidebar title centered via toolbar principal item
- Panel toggle buttons now have filled backgrounds with white icons (no borders)
- Redesigned landscape sidebar panel buttons — bold 48×48 squares flush to screen edge with distinct amber/teal/purple colors, dark mode adaptive

### Fixed

- LP (Lebenspunkte) calculation now includes species base value (e.g., +5 for humans, +8 for dwarves) — previously only used KO × 2
- "Held importieren" button text readability (black text on gold background)
- Selected hero row visibility in sidebar (increased highlight opacity)
- Removed unnecessary trailing border from attributes column

### Added

- Action log (Protokoll) with event sourcing — all talent checks, combat damage, healing, and resting are recorded as reversible log entries
- Log panel (Protokoll) viewable in split-screen with combat grouping, swipe-to-delete with automatic state reversal
- Split-screen layout — Notes, Protokoll, and Regelwerk panels available in 50/50 split (landscape) or full-screen overlay (portrait)
- Heilung command — heal hero with source tracking and logging
- Reittier: Heilung command — heal mount with logging
- SchemaV3 migration with LogEntry model
- Adaptive content width modifier for iPad: proportional margins (~6% per side) with 700pt max-width cap, standard 16pt padding on iPhone
- Notes panel ("Notizen") sidebar toggleable via toolbar button on iPad in both hero detail and combat views
- Hero.notes property persisted via SwiftData with SchemaV2 lightweight migration
- ContentWithNotesLayout wrapper for consistent notes panel integration across views
- Adaptive attributes column fixed to left side in iPad landscape mode
- Inline probe attribute abbreviations (e.g., KL, CH, GE) in talent rows
- Personal data fields display in responsive grid layout (2-3 columns)
- Ctrl+K keyboard shortcut to open command palette
- LP (Lebenspunkte) bar for all pets in hero detail view
- Mount LP bar in combat view when mounted combat is active
- Mount damage with automatic Reiten (Kampfmanöver) check — penalty scales +1 per 5 SP; Sturz warning on failure
- "Reittier: Schaden" command in command palette for normal mode
- TalentProbeModal now accepts an initial modifier for pre-applied penalties

### Changed

- Replaced notes-only right sidebar (ContentWithNotesLayout) with flexible SplitContentLayout supporting Notes, Protokoll, and Regelwerk panels
- Panel toggle buttons now built into layout instead of toolbar
- Combat view: replaced per-element horizontal padding with adaptive content width modifier for consistent iPad margins
- Mount combat: Reiten check now uses the full talent probe modal with dice rolls instead of a simple Yes/No dialog
- Moved mount attacks from combat root view to attack selection screen
- "Ausruestung wechseln" button restyled with teal accent for better visual distinction
- Weapon and shield selection merged into single loadout step
- Renamed project from iDSACompanion to Hesindion (after Hesinde, DSA goddess of wisdom)

### Added

- Niederreiten and Sturmangriff zu Pferd as selectable attacks in the attack choice screen
- Galopp confirmation and Reiten (Kampfmanöver) check flow before mounted charge attacks
- Mount attacks (regular, Niederreiten, Sturmangriff zu Pferd) grouped in attack choice view alongside hero attacks
- Mächtiger Schlag reminder for mount attacks: when the mount has "Mächtiger Schlag" in its special skills, an info banner shows during attack execution explaining the Kraftakt check rule, including the calculated penalty from the mount's KK
- SwiftData VersionedSchema and SchemaMigrationPlan for safe schema migrations
- Modifier breakdown for defense actions: Parieren and Ausweichen now compute and display labeled modifier lines (Belastung, Schmerz, Golgariten-Stil PA bonus, Plänkler-Formation AW bonus, mounted dodge penalty, dual-attack penalty) with an effective total, matching the attack announcement breakdown
- Vorstoß defense lock: Parieren and Ausweichen buttons disabled (grey) when Vorstoß active this round, with warning note below
- Schmerz indicator in combat root view: badge showing pain level and penalty when effectiveSchmerzLevel > 0
- Mount attacks section in combat root: when mounted, show pet attack list with AT values; each attack skips the announcement step
- Two-handed weapon selection disabled when mounted (greyed out with "Beritten" note in loadout view)
- Auto-select mount INI base on initiative screen when mounted mode is active
- Modifier breakdown in combat execution view: labeled rows show base AT/PA/AW, each situational modifier (Belastung, Schmerz, Vorteilhafte Position, maneuver, dual-wield, off-hand) and manual zusätzlich adjustment, with a dark "Effektiv" total bar; falls back to simple value box for defense paths without a full breakdown
- Announcement step between weapon selection and execution: maneuver selection (Normal, Finte, Wuchtschlag, Vorstoß, Schildspalter, Sturmangriff) with Vorteilhafte Position toggle and full AT/damage modifier pre-calculation
- Combat setup step between armor selection and initiative: Plänkler-Formation toggle (AT or AW bonus) and mounted toggle for eligible heroes
- Vorstoß and active maneuver state reset on round advance
- Schmerz penalty warning and modifier applied to talent probe results in TalentProbeModal
- Aufmerksamkeit (SA_40) contextual hint shown in talent probe for Sinnenschärfe (TAL_8)
- Schmerz (pain) tracking: raw level from LP thresholds, Zäher Hund (ADV_49) reduction, penalty computation
- Combat ability detection helpers: Aufmerksamkeit, Golgariten-Stil, Berittener Kampf, Finte, Wuchtschlag, Vorstoß, Schildspalter, Plänkler-Formation
- Mount detection and Sturmangriff damage bonus computation
- Combat setup screen flag (needsCombatSetup) for Plänkler-Formation and mounted heroes
- Combined equipment loadout view (weapons + shields in one screen with checkboxes)
- Dual-wielding support for heroes with Beidhaendig (ADV_5) advantage
- Pre-attack choice: "Eine Waffe" vs "Beide Waffen" for dual-wield heroes
- Two-handed grip option (+1 TP, -1 PA) for eligible one-handed weapons
- Vorteilhafte Position per-roll toggle (+2 AT/PA/AW) on combat execution screen
- Off-hand penalty display and calculation for dual-wield combat
- Dual-attack penalty tracking per combat round (resets on round advance)
- Dual-attack second strike flow with fumble handling (Patzer cancels second attack)
- Combat loadout system: select main weapon + shield at combat start, persists across sessions
- Passive shield PA bonus on main weapon parade (single modifier per DSA 5 rules)
- Active shield parry with doubled PA bonus
- Shield-specific combat notes (e.g., Großschild "+1 PA vs. Fernkampf")
- Loadout-aware Angriff/Parieren: skip weapon list when no shield, simplified choice when shield equipped
- "Ausrüstung wechseln" button to change loadout mid-combat
- Armor equip/unequip system with `isEquipped` toggle (swipe-left in hero detail, toggle in combat)
- Belastung (encumbrance) system: effective BE, Belastungsgewöhnung support, penalties on AT/PA/AW/INI/GS
- Belastung penalty display as separate modifiers on combat stats (e.g., "AT 12 (-1)")
- Combat flow: armor selection → initiative roll → combat root (replaces direct-to-root)
- "Schaden nehmen" combat action: TP input → RS calculation → LP reduction with confirm
- Armor management during combat via shield button and modal sheet
- INI/GS direct modifiers on armor model (parsed from Optolith `iniMod`/`movMod`)
- 17 new DE/EN localization strings for damage and armor system
- Adaptive border colors and combat technique AT/PA design docs
- Ranged weapons UI with combat technique ID-to-name resolution
- RangedWeapon model and ranged weapons import
- Attribute-by-ID resolver to Attributes model
- Combat technique detail lookup in RulesDatabase
- Full set of 59 standard talents included on import (missing ones default)
- Hero avatar display in sidebar list rows
- Direct Optolith export import (replacing custom hero JSON import)
- Rule lookup sheet, app icon variants, and UI polish
- Rules system with spells, liturgies, and rulebook UI
- Regenerieren command to restore Lebensenergie via 1W6 roll
- Combat section labels, step transitions, and expanded combat spec

### Fixed

- PA rounding: use ceil(KtW/2) instead of floor per DSA 5 rules
- Initiative re-roll sheet now includes Belastung penalty in base INI
- Weapon AT/PA calculations to use DSA 5 formulas
- AT/PA calculation and listing of all combat techniques
- Numeric select-option IDs resolved to names during hero import
- Button heights in combat root view
- LP bar display at zero value

### Changed

- Parieren/Ausweichen moved to own rows
- LP bar pattern reused in hero view Lebensenergie modal
- INI row height reduced by halving vertical padding
- Added Makefile, fixed UIFileSharingEnabled, and simplified command palette
