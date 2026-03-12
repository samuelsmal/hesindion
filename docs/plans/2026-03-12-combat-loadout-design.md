# Combat Loadout System

## Problem

The combat view has no concept of equipped weapon + shield loadout. This means:
1. Melee weapon PA doesn't include the passive shield PA bonus
2. There's no distinction between active shield parry (doubled bonus) and passive shield bonus on weapon parry
3. No loadout persistence across combat sessions

## Rules Reference

Source: https://dsa.ulisses-regelwiki.de/

**Passive shield bonus:** When carrying a shield alongside a main weapon, the shield's PA-mod is added (single) to the main weapon's parade. Only the highest bonus counts if multiple shields/parrying weapons are present.

**Active shield parry:** When parrying with the Schilde combat technique, the shield's PA bonus is doubled.

**Shield AT:** The shield's AT modifier only affects attacks with the shield itself, not the main weapon.

**Ausweichen:** Unaffected by loadout.

**Weapon-specific notes:** Some items have special rules (e.g., Großschild: +1 PA vs. Fernkampf after doubling). These are displayed as reminders in the execution view.

## Combat Flow

```
Combat opens
  → Has persisted loadout? → Action Root
  → No loadout? → Loadout Selection (weapon → shield) → Action Root

Action Root: Angriff / Parieren / Ausweichen / Schaden nehmen / [Ausrüstung wechseln]

Angriff → Choose: Main weapon or Shield (if equipped) → Execution
Parieren → Choose: Hauptwaffe (PA + passive shield bonus) or Schild (PA with doubled bonus) → Execution
Ausweichen → Execution (unchanged)
```

## Loadout Selection

- **Step 1: Main weapon** — list of hero's melee weapons + Raufen (unarmed). Full-screen Neo-Brutalist style matching existing combat steps.
- **Step 2: Shield** — list of hero's shields + "Kein Schild" option. Skipped entirely if hero has no shields.
- Persisted on the Hero model so it's remembered across sessions.
- "Ausrüstung wechseln" button on the action root screen allows switching mid-combat.

## PA Value Calculation

- **Main weapon parade (with shield):** `weapon.pa + shield.paModifier` (passive, single bonus; highest if multiple)
- **Shield parade (active):** `shield.pa` (already stored with doubled bonus from import)
- **No shield equipped:** weapon PA shown as-is

## AT Value Calculation

- **Attack with main weapon:** `weapon.at` (unaffected by shield)
- **Attack with shield:** `shield.at` (shield's own AT)

## Model Changes

### Shield model

Add two fields:
- `paModifier: Int` — raw PA-mod from item JSON (needed for passive bonus on weapon parade)
- `note: String` — weapon-specific reminder (e.g., "+1 PA vs. Fernkampf"), populated from known item templates during import

### Hero model

Add optional persisted fields:
- `selectedWeaponID` — PersistentIdentifier of the selected melee weapon (nil = not yet chosen)
- `selectedShieldID` — PersistentIdentifier of the selected shield (nil = no shield)

## Import Changes

### Shield import

- Store raw `paMod` from item JSON in `shield.paModifier`
- Map known item templates to notes:
  - `ITEMTPL_29` (Großschild): "+1 PA vs. Fernkampf"

### Existing fixes (already applied)

- PA rounding: `ceil(KtW / 2)` instead of `floor`
- Shield PA: `basePA + 2 × paMod` (doubled bonus for active parry)

## CombatView Changes

### New step: `.loadout`

Two-phase selection (weapon then shield), shown on first combat entry or when changing equipment.

### Modified step: `.root`

- Show current loadout (weapon + shield names) at top
- "Ausrüstung wechseln" button to re-enter loadout selection
- Angriff button → weapon/shield choice (if shield equipped)
- Parieren button → main weapon vs shield choice (if shield equipped)

### Modified step: `.execution`

- When parrying with shield: show `shield.note` if non-empty as a reminder hint

## What stays unchanged

- Ausweichen — uses AW derived value, no loadout influence
- Schaden nehmen — unrelated to loadout
- Belastung penalties — displayed as before
- Ranged weapons — not part of loadout (separate flow, future work)
