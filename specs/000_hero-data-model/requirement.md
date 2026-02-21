# Hero Data Model

## Overview

The hero data model is imported from a JSON file. Most fields are read-only (updated only by re-importing the hero file). Two areas are mutable by the user: **derived-value current fields** and **equipment/money**.

---

## Value-Type Shapes

Four distinct shapes appear in the derived-values object:

| Type | JSON keys | Usage |
|---|---|---|
| `LifeEnergyValue` | `base, bonus, purchased, max, current` | `lebensenergie` |
| `MutableResourceValue` | `current, bonus, max` | `astralenergie`, `karmaenergie`, `schicksalspunkte` |
| `ResourceValue` | `base, bonus, max` (no `current`) | `seelenkraft`, `zähigkeit`, `geschwindigkeit`, `ausweichen`, `initiative`, `wundschwelle` |

---

## Mutability Rules

### Read-only (re-import only)
All fields except those listed below. Re-importing a hero replaces all read-only data.

### Mutable derived values
Fields with a `current` sub-field (`lebensenergie`, `astralenergie`, `karmaenergie`, `schicksalspunkte`) allow the user to modify only `current` in the app. The other sub-fields (`base`, `purchased`, `bonus`, `max`) are read-only.

### Mutable on their own (preserved across re-import)
- **equipment** — items can be added, removed, or modified freely. Re-importing the hero does NOT touch equipment.
- **money** — dukaten/silbertaler/heller/kreuzer are user-editable. Re-importing the hero does NOT reset money.

---

## Weapons, Armor, Shield

`meleeWeapons`, `armor`, and `shield` are **top-level fields** in the JSON (not derived from equipment items). They are decoded and stored directly from those fields.

---

## Carrying Capacity

`carryingCapacity` (Int, read-only) is a top-level JSON field.

**Total weight** = sum of equipment item weights + sum of melee weapon weights + armor weight + shield weight.

**Threshold** = `carryingCapacity + (mount.kk * 2)` if a mount is present, otherwise just `carryingCapacity`.

The hero view shows total weight below the equipment section. An alert is shown when `totalWeight > threshold`.

---

## Stamina

Stamina is **not part of DSA** (Das Schwarze Auge) and is intentionally absent from the model.
