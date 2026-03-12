# Damage & Armor System Design

**Date:** 2026-03-12
**Status:** Approved

## Overview

Add a damage system to the combat view and integrate armor mechanics (RS, BE, Belastung) throughout the app. Heroes can equip/unequip armor pieces, which affects combat stats globally via the Belastung system. In combat, a "Schaden nehmen" action lets the user enter incoming TP and applies LP reduction after RS absorption.

## Data Model Changes

### Armor Model

Add three fields to `Armor`:

- `isEquipped: Bool = false` — whether the hero is currently wearing this armor
- `iniModifier: Int = 0` — direct INI modifier (e.g., -1 for Winterkleidung)
- `gsModifier: Int = 0` — direct GS modifier

### Hero Computed Properties

- `totalRS: Int` — sum of `protectionValue` for all equipped armor
- `effectiveBE: Int` — `max(0, totalEquippedBE - 2 * belastungsgewöhnungLevel)`
- `belastungStufe: Int` — equals `effectiveBE` (0 = none, 1 = I, 2 = II, 3 = III, 4+ = IV)
- `belastungPenalty: Int` — equals `-belastungStufe` (applied to AT, PA, AW, INI, GS)

### Belastungsgewöhnung

Derived from `hero.combatSpecialAbilities` — look for the SA representing Belastungsgewöhnung and read its tier level.

## Belastung Rules

| Stufe | Effective BE | Auswirkung |
|-------|-------------|------------|
| 0     | 0           | No penalty |
| I     | 1           | -1 to AT, Verteidigung, INI, GS, movement-related talent probes |
| II    | 2           | -2 to all above |
| III   | 3           | -3 to all above |
| IV    | 4+          | Handlungsunfähig (player-managed, no enforcement) |

Penalties from Belastung are **always active**, not just in combat.

## Armor Direct Modifiers

Some armor pieces apply direct INI/GS modifiers independent of BE (e.g., Schwere Kleider: -1 INI, -1 GS). These are parsed from Optolith imports and stored as `iniModifier`/`gsModifier` on the Armor model.

Total INI modifier = `belastungPenalty + sum of equipped armor iniModifier`
Total GS modifier = `belastungPenalty + sum of equipped armor gsModifier`

## HeroDetailView Changes

### Armor Rows

- **Swipe left** reveals an equip/unequip toggle button ("Anlegen"/"Ablegen")
- Equipped armor gets a visual indicator (e.g., bold border or filled icon)

### Stat Display with Belastung Modifiers

Wherever AT, PA, AW, INI, GS are displayed, show Belastung penalty as a separate modifier:

- Example: `AT 12 (-1)` meaning base 12, effective 11
- Only shown when penalty is non-zero

## Combat Flow

### 1. Armor Selection Sheet (on combat entry)

- Shown before initiative roll
- Lists all armor from hero inventory with toggle switches
- Pre-selects armor already marked `isEquipped = true`
- Toggling updates `armor.isEquipped` on the model (persisted)
- "Weiter" button proceeds to initiative
- If hero has no armor, skip to initiative

### 2. Initiative Roll Screen

- Existing `CombatInitiativeSheet` logic
- Now shown as a full step (not a sheet), accounting for armor encumbrance impact on INI

### 3. Combat Root View

Existing layout with additions:

- **LP bar**: stays editable (increment/decrement)
- **Armor management button**: gear icon near LP bar, opens modal with equip/unequip toggles per armor piece (same as hero detail, but accessible in combat)
- **"Schaden nehmen" button**: new action button in AKTION section, distinct styling (danger tone)
- **AT/PA/AW values**: show Belastung modifier where applicable

### 4. "Schaden nehmen" Flow

1. Tap "Schaden nehmen" button
2. **TP input screen**: numeric input for TP, displays current total RS
3. **Calculation display** (black background, white text):
   - `TP - RS = X LP Schaden` (or "0 — Rüstung absorbiert allen Schaden" if TP ≤ RS)
4. **"Bestätigen" button**: applies `hero.derivedValues.lebensenergie.current -= damage`
5. Returns to combat root view, LP bar reflects change

**Edge cases:**
- LP clamped to minimum 0
- No death/unconscious enforcement — player manages this

## Import Changes

`OptolithImportService` parses `iniModifier` and `gsModifier` fields for armor pieces from Optolith JSON exports.

## Out of Scope

- Wundschwelle mechanics
- Status effects (bleeding, stunned, etc.)
- Armor degradation / RS reduction
- Stufe IV (handlungsunfähig) automatic enforcement
- Non-combat damage calculation (handled by manual LP editing)
- Ranged weapon combat in CombatView
