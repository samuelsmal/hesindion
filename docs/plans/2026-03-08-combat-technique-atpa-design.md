# Combat Technique AT/PA Calculation & Display Fix

## Problem

1. Weapon display shows raw IDs like "CT_5" instead of "Hiebwaffen"
2. Only hero-trained combat techniques are listed; missing ones should default to value 6
3. AT/PA calculated incorrectly as `ceil(val/2)` / `val/2` instead of DSA 5 formulas
4. Ranged weapons (`gr=2`) are discarded into general equipment instead of being parsed

## Formulas

**Eigenschaftsbonus:** `max(0, floor((attribute - 8) / 3))`

**AT (Attacke):** `KtW + Eigenschaftsbonus(MU)`

**PA (Parade):** `floor(KtW / 2) + Eigenschaftsbonus(max(primaryAttr1, primaryAttr2))`

**FK (Fernkampf):** Same as AT but using the ranged CT's primary attribute instead of MU. Ranged CTs have no PA (`has_no_parry` flag in rules.db).

**AW (Ausweichen):** `floor(GE / 2)`

**KtW default:** 6 for any combat technique not listed in the hero JSON.

**Primary attributes** per combat technique come from `combat_technique_details.primary_attr_1/2` in rules.db, stored as `"ATTR_1"` through `"ATTR_8"`.

## Changes

### 1. RulesDatabase: Combat technique detail lookup

New struct and method:

```swift
struct CombatTechniqueDetail {
    let primaryAttr1: String?
    let primaryAttr2: String?
    let hasNoParry: Bool
}

func lookupCombatTechniqueDetail(ruleId: String) -> CombatTechniqueDetail?
// Queries combat_technique_details JOIN rules for has_no_parry
```

Also add `allCombatTechniqueIds() -> [String]` to list all CT rule IDs from the DB.

### 2. Attributes: Attribute-by-ID resolver

```swift
extension Attributes {
    func value(for attrId: String) -> Int
    // "ATTR_1" → mu, "ATTR_2" → kl, ..., "ATTR_8" → kk
}
```

### 3. OptolithImportService: Fix parseCombatTechniques

- Accept `attributes: Attributes` parameter
- Query all CT IDs from rules.db
- For each CT: use hero JSON value if present, else default to 6
- Look up `CombatTechniqueDetail` for primary attributes
- Calculate AT/PA using correct formulas
- CTs with `hasNoParry` get `pa = 0`

### 4. RangedWeapon model

New `@Model` class:

```swift
@Model
final class RangedWeapon {
    var name: String
    var combatTechniqueId: String
    var damage: String
    var at: Int          // FK value
    var range: String    // e.g. "20/40/60"
    var weight: Double
}
```

Add `@Relationship(deleteRule: .cascade) var rangedWeapons: [RangedWeapon]` to `Hero`.

### 5. OptolithImportService: Fix parseItems

- Handle `gr=2` (ranged weapons) → create `RangedWeapon`
- Fix melee weapon AT/PA calculation to use correct formulas
- Both need access to `attributes` and `CombatTechniqueDetail` lookups

### 6. HeroDetailView: Resolve combatTechniqueId

In weapon display sections, resolve `w.combatTechniqueId` via `RulesDatabase.shared.lookup(id:)?.name` instead of showing raw ID. Apply to both melee and ranged weapon sections.

### 7. Verify AW

Confirm `ausweichen` derived value matches `floor(GE / 2)`. Fix if needed.

## What stays unchanged

- `CombatTechnique` model fields (ruleId, name, value, at, pa)
- `CombatView` weapon selection / combat execution flow
- Shields (already handled separately via CT_10)
