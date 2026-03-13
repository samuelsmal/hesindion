# Weapon Switching & Dual-Wield Combat Design

**Date:** 2026-03-13
**Status:** Approved

## Overview

Allow players to switch weapons mid-combat and support dual-wielding for heroes with the Beidhändig (ADV_5) advantage. Also adds "Vorteilhafte Position" per-roll modifier and two-handed grip option for one-handed weapons.

## 1. Combined Loadout View

Merge `loadoutWeapon` and `loadoutShield` into a single `loadoutEquipment` step.

**UI:** Single list showing all melee weapons + shields + "Raufen" (unarmed). Each item has a checkbox.

**Validation rules:**
- Max 2 items selected
- Can't select 2 weapons unless hero has ADV_5 (Beidhändig)
- Can't select 2 weapons + shield (only 2 hands)
- Can't select 2 shields
- "Raufen" can't be combined with anything (unarmed = both hands free)

## 2. Attack Flow

### Pre-attack choices (shown after tapping "Angriff")

**Two weapons equipped (dual-wield):**
1. "Eine Waffe" → weapon picker → normal attack, no penalty
2. "Beide Waffen" → -2 AT + all defenses this round, two sequential attack rolls

**Single weapon equipped (no off-hand):**
1. "Einhändig" → normal attack
2. "Zweihändig geführt" → +1 TP (damage), -1 PA this round. Not available for Dolche or Fechtwaffen.

**Weapon + shield:** Direct to attack roll (weapon picker if needed, same as today).

### Dual-wield attack sequence ("Beide Waffen")

1. Weapon picker (main or off-hand) → roll with -2 AT penalty
2. If fumble → second attack lost, return to root
3. Second attack: auto-selects other weapon → roll with -2 AT penalty
4. Return to root with -2 defense penalty active for the round

### Vorteilhafte Position

Per-action checkbox on the pre-roll screen (attack, parry, dodge). When checked: +2 to that single roll. Not a persistent toggle — player decides per roll based on narrative context.

## 3. Parry Flow

**Two weapons:** Weapon picker → choose which weapon to parry with.
- If dual-attacked this round: -2 PA applies
- Off-hand weapon: -4 PA if hero lacks ADV_5

**Weapon + shield:** Same as today (weapon or shield picker).

**Single weapon:** Direct to roll. If two-handed grip: -1 PA.

Pre-roll screen shows final PA with Vorteilhafte Position checkbox.

## 4. "Ausrüstung wechseln" Button

Navigates to combined loadout view. Player re-picks weapons/shield, returns to root. Resets round-specific state (dual-attack penalty, two-handed grip).

**Visual distinction:** Blue/teal accent color (distinct from orange actions and dark damage button). Larger tap target or swap icon. Clear spacing from action buttons.

## 5. DSA Rules Reference

### Beidhändiger Kampf (Dual-Wield)
- -2 AT and all defenses when attacking with both weapons in same round
- -4 off-hand penalty on AT and PA (removed by ADV_5 Beidhändig advantage)
- "Beidhändiger Kampf I" SA reduces -2 to -1
- "Beidhändiger Kampf II" SA removes -2 entirely
- Can't use two-handed or chain weapons (chain OK with shield)
- Fumble on first attack → second attack lost
- Only basic maneuvers allowed
- Source: Regelwerk, Spezielle Nahkampfregeln

### Einhändige Waffen zweihändig geführt
- +1 TP (damage), -1 PA
- Switching costs no action, but only at hero's initiative turn
- Not applicable to Dolche or Fechtwaffen
- Source: Regelwerk p. 366

### Vorteilhafte Position
- +2 AT or +2 defense for a single roll
- Per-action decision, depends on narrative positioning vs specific opponent
- Source: Regelwerk p. 238

## 6. Data Model Changes

### Hero.swift
- Add `selectedOffHandName: String?` — second weapon or shield
- Add computed `selectedOffHand` → returns `MeleeWeapon` or `Shield`
- Add computed `hasBeidhaendig: Bool` — checks ADV_5 in advantages
- Add computed `beidhaendigerKampfLevel: Int` — SA tier (0/1/2), reduces -2 penalty
- `selectedShieldName` derived from `selectedOffHandName` when off-hand is shield

### CombatStep enum
- Remove `.loadoutShield` → merged into `.loadoutEquipment`
- Rename `.loadoutWeapon` → `.loadoutEquipment`
- Add `.attackChoice` — pre-attack option screen
- Add `.dualAttackSecond` — second dual-wield attack roll

### CombatView @State
- `dualAttackPenaltyActive: Bool` — reset each round
- `twoHandedGripActive: Bool` — reset on equipment change
- Per-roll: Vorteilhafte Position checkbox on pre-roll screen (not persisted)

## 7. Open Items

- **Beidhändiger Kampf SA ID:** Need to identify the Optolith SA ID for "Beidhändiger Kampf I/II". Boronmir doesn't have it. Will search during implementation; fallback to level 0 with TODO if not found.
