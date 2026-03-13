# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

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
