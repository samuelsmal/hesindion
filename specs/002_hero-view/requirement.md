# Requirements Document

## Overview

This requirement displays a single DSA hero.

Each section of the Hero model shall be displayed as a collapsible block. The block title uses the
model class name (e.g. "PersonalData", "DerivedValues") as the user-facing label, emphasized.

Display sections in the following order:

- **name** — shown as a plain heading above everything else
- **attributes**
    - Implemented with a `LazyVStack` pinned section header so the attributes row stays visible
      regardless of how far the user scrolls into the sections below.
    - Show each attribute (MU, KL, IN, CH, FF, GE, KO, KK) in a box: key above value in slightly
      smaller font.
- **Everything else** — scrollable, in this order:
    1. experience
    2. personalData
    3. derivedValues
    4. advantages
    5. disadvantages
    6. generalSpecialAbilities
    7. languages
    8. scripts
    9. talents — grouped by category
    10. combatTechniques
    11. combatSpecialAbilities
    12. equipment *(see Equipment section below)*
    13. meleeWeapons
    14. shield
    15. armor
    16. money *(see Money section below)*
    17. mount

## Row layout

If not further specified, display each field as a single row: key left-aligned, value
right-aligned.

If a field has sub-fields (i.e. its value is a struct, not a plain string/number), display those
sub-fields in a vertical columnar layout nested inside the parent row rather than on one line.

## Null / zero handling

- If a field or relationship is `null`/`nil`, do not show the field or its section.
- For **derivedValues** only: if a field's `max` is zero, do not show that field. This rule does
  not apply to talents.

## Labels

Use the keys from the sample JSON file (`../001_heros-view/hero.json`) as display labels (mixing
English and German is fine).

---

## Equipment section

Show the list of equipment items after combatSpecialAbilities.

At the **bottom of the equipment section**, show a carrying capacity indicator:
- Display total weight and the threshold: e.g. `"12.25 / 30 kg"`
- If `isOverloaded` is `true`, highlight this row as a warning (e.g. red text or warning icon).

Equipment items can be **deleted** by the user (e.g. swipe-to-delete). No adding or editing of
equipment items is required for this spec.

---

## Money section

Money fields (dukaten, silbertaler, heller, kreuzer) are **editable** by the user. Each value has
a minimum of 0 and no defined maximum (prevent integer overflow in the implementation).

---

# Interaction

## General

Most fields are read-only.

The following derived-value fields are **interactive**: `lebensenergie`, `astralenergie`,
`karmaenergie`, `schicksalspunkte`.

## Interactive derived-value modal

Trigger: **long-press** on the field row.

Presentation: an overlay modal appears above the field. The background is **dimmed**. Dismiss by
**swiping up** on the modal; no confirm/cancel button is needed.

Modal layout:
- Center: `current` value displayed large, with `max` shown smaller above it.
- Left side: `−` button
- Right side: `+` button

Behaviour:
- Step size: **1**
- Minimum: **0**
- Maximum: the field's `max` value
- The `current` value **updates live** on each tap; no explicit save step.
- Only `current` is modified; `max` and all other sub-fields are read-only.

Both `LifeEnergyValue` fields (`lebensenergie`) and `MutableResourceValue` fields
(`astralenergie`, `karmaenergie`, `schicksalspunkte`) use this same modal — only `current` and
`max` are needed regardless of the underlying type.

## Money editing

Each money field is edited inline (e.g. tapping the value opens a numeric input). Minimum is 0,
no maximum, prevent overflow.
