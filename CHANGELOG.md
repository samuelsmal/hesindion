# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Changed

- "Ausruestung wechseln" button restyled with teal accent for better visual distinction
- Weapon and shield selection merged into single loadout step
- Renamed project from iDSACompanion to Hesindion (after Hesinde, DSA goddess of wisdom)

### Added

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
