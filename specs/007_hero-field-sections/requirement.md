# Overview

> This spec supersedes the section ordering defined in spec 002. See spec 002 for row layout, null handling, labels, and interaction rules.

The sections in the HeroDetailView shall be grouped into four main groups.

## Group component

Each group is represented by a **collapsible divider**: a visible horizontal divider labelled with the group name. Tapping the divider toggles the group collapsed/expanded. The divider remains visible at all times, even when the group is collapsed. Group headers are always shown, even if all sections within the group are empty.

The attributes bar shall remain pinned at the top (as defined in spec 002).

### Group colours

Each group has a fixed accent colour (no dark mode adaptation). The accent colour is used for:
- The divider lines and label of the group header
- The background of every section header (`CollapsibleSection`) within the group

| Group | Colour | Hex | Section title text |
|---|---|---|---|
| Personal Data | Bold yellow | `#F5C400` | Black |
| Talents | Electric blue | `#1D4ED8` | White |
| Combat | Crimson | `#DC2626` | Black |
| Equipment | Forest green | `#16A34A` | White |

Colours are defined as `Color.groupPersonalData`, `Color.groupTalents`, `Color.groupCombat`, `Color.groupEquipment` in `Theme/AttributeColors.swift` and propagated to child sections via the SwiftUI environment (`groupColor`, `groupTextColor`).

## Groups and sections

1. **Personal Data**
    1. personalData
    2. experience
    3. derivedValues
    4. advantages
    5. disadvantages
    6. generalSpecialAbilities
    7. languages
    8. scripts

2. **Talents**
    - Create one collapsible section per key in `TalentsContainerDTO` (e.g. `körpertalente`)

3. **Combat**
    1. combatTechniques
    2. combatSpecialAbilities
    3. meleeWeapons
    4. armors
    5. shields

    > `meleeWeapons`, `armors`, and `shields` are moved here. They no longer appear in the Equipment group.

4. **Equipment**
    1. equipment (general items, swipe-to-delete)
    2. meleeWeapons — name + weight only (read-only; for carrying capacity tracking)
    3. shields — name + weight only (read-only)
    4. armors — name + weight only (read-only)
    5. money
    6. mount

    > Weapons, shields, and armors appear here as lightweight weight rows only. Their full detail sections (with stats) are in the Combat group.
