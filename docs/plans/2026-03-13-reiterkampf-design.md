# Reiterkampf Integration Design

**Date:** 2026-03-13
**Status:** Approved

## Overview

Integrate mounted combat attacks (Niederreiten, Sturmangriff zu Pferd) into the
combat flow. Move mount attacks from the combat root view into the attack
selection screen. Add a Galopp confirmation + Reiten (Kampfmanöver) check flow
before mounted charge attacks.

## Attack Selection Screen

When `mountedActive`, the weapon/attack selection screen shows two groups:

```
── EIGENE ANGRIFFE ──
  Rabenschnabel (1W6+4)

── REITTIER-ANGRIFFE ──
  Hufschlag (AT 10, 1W6+4, RW 1)
  Niederreiten (AT 10, 2W6+6)
  Sturmangriff zu Pferd (Rabenschnabel, AT 14, 1W6+4 +X)
```

### Niederreiten

- Uses the pet's Niederreiten attack entry (AT and TP from JSON).
- The Niederreiten AT value equals the pet's base AT (same as Tritt).
- Available whenever mounted.

### Sturmangriff zu Pferd

- Uses the rider's currently equipped weapon AT.
- Damage = weapon TP + bonus of `2 + floor(mountGS / 2)`.
- Only available when `hasBerittenerKampf` (SA_43) and mounted.
- This is distinct from the foot maneuver "Sturmangriff" (separate SA).

### Regular Mount Attacks

- Hufschlag, Tritt, Biss, etc. from the pet's attacks array.
- Biss AT uses Raufen formula: `floor(KK / 2)`.
- Moved here from the combat root view (no longer shown there).

## Pre-Attack Flow

Niederreiten and Sturmangriff zu Pferd share this flow before the attack roll:

1. **Galopp confirmation** -- "Ist dein Reittier im Galopp?" (Yes / No)
2. If no: return to attack selection.
3. **Reiten (Kampfmanöver) check** -- display the skill value, user confirms
   pass or fail.
4. If failed: return to attack selection.
5. If passed: proceed to attack execution.

Regular mount attacks (Hufschlag, Tritt, Biss) skip this flow.

## Attack Execution

### Niederreiten

- AT from pet's Niederreiten attack data.
- TP from pet's Niederreiten attack data (e.g. 2W6+6).
- Info reminder: "Niederreiten kann nur durch Ausweichen verteidigt werden."
- Existing Maechtiger Schlag reminder applies if mount has the ability.

### Sturmangriff zu Pferd

- AT from rider's equipped weapon.
- TP from rider's equipped weapon + mount charge bonus in modifier breakdown.
- Info reminder: "Sturmangriff zu Pferd kann nicht mit Waffen pariert werden --
  nur Schildparade oder Ausweichen."

## Combat Root View Changes

- Remove the mount attacks section from the root view.
- All mount-related attacks are accessed through the attack flow (weapon
  selection screen).

## Model Changes

- The existing `.sturmangriff` case in `CombatManeuver` already implements
  Sturmangriff zu Pferd semantics (checks `hasBerittenerKampf`, uses mount GS).
  Keep and clarify naming.
- Niederreiten flows through the mount attack path (not a `CombatManeuver`
  case), since it uses the mount's own AT/TP.
- No new `CombatManeuver` enum case needed for Niederreiten.

## Out of Scope (Next Feature)

- Mount LP tracking and damage handling.
- Reiten check when mount takes damage (+1 difficulty per 5 full damage points).
- Falling off mount consequences.
