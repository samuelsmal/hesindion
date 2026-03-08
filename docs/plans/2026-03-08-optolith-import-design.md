# Optolith Import — Design Document

Date: 2026-03-08

## Goal

Replace the custom hero JSON format with direct import of Optolith export files (.json). The hero data model adapts to match Optolith's ID-based structure while enabling trivial rules.db lookups.

## Format

Optolith exports use reference IDs throughout (ADV_36, TAL_4, CT_12, SPELL_105). These map directly to rules.db entries via `RulesDatabase.shared.lookup(id:)`.

## Core Value Types

### HeroTrait (Codable struct, inline on Hero)

Shared across advantages, disadvantages, special abilities, cantrips, and blessings.

```
ruleId: String    — "ADV_36", direct key into rules.db
name: String      — "Reich", resolved at import time
tier: Int?        — Optolith tier (level/stufe), optional
sid: String?      — selection identifier (aspect/choice), int sids converted to String
```

Multiple instances of the same rule (e.g. two DISADV_50 entries) become separate HeroTrait entries.

### Hero model changes

```
advantages: [String]              → [HeroTrait]
disadvantages: [String]           → [HeroTrait]
generalSpecialAbilities: [String] → [HeroTrait]
combatSpecialAbilities: [String]  → [HeroTrait]
+ avatar: Data?                   — decoded from base64 PNG at import
+ cantrips: [HeroTrait]
+ blessings: [HeroTrait]
+ spells: [HeroSpell]            — @Relationship
+ liturgies: [HeroSpell]         — @Relationship
+ pets: [Pet]                    — replaces mount: Mount?
```

## Talent & Combat Technique

Both gain a `ruleId` field for rules.db lookup. Names resolved at import.

- Talent: add `ruleId: String`
- CombatTechnique: add `ruleId: String`

## Spells & Liturgies

New @Model `HeroSpell` with ruleId, name, value (skill rating). Cantrips and blessings use `[HeroTrait]` (no skill value).

## Equipment

### MeleeWeapon

- `technique: String` → `combatTechniqueId: String` ("CT_12")
- Weapon at/pa from Optolith are modifiers; absolute values computed at import from CTR + primary attribute + modifier
- damage composed from damageDiceNumber/Sides/Flat → "1W6+4"
- reach: numeric 1/2/3 → "Kurz"/"Mittel"/"Lang"

### Shield

- Remove: structure, breakingFactor (were always 0)
- Add: damage, reach, structurePoints (from Optolith "stp")

### Armor

- Remove: armorRating (not in Optolith, redundant with protectionValue)
- pro → protectionValue, enc → encumbrance

### EquipmentItem

Unchanged (name, value, weight). Filters to Optolith gr=5.

## Pet (replaces Mount)

Renamed from Mount to Pet. Supports multiple pets per hero.

Key changes from Mount:
- initiative: Int → String (Optolith stores "14+1W6")
- Added: spirit, toughness, attack, actions, notes, avatar
- talents/skills stored as free text (Optolith format is comma-separated strings)
- Removed structured MountAttack/MountTalent arrays

## Personal Data & Attributes

PersonalData model shape stays the same. Numeric IDs (haircolor, eyecolor, socialstatus) resolved to strings at import via static maps.

Attributes: ATTR_1–8 mapped to MU/KL/IN/CH/FF/GE/KO/KK via static map.

## Derived Values

Computed at import using DSA 5e formulas (not stored in Optolith):
- LE max = race base (KO×2 for Mensch) + KK + purchased (attr.lp)
- AE max = if spellcaster: base + purchased (attr.ae)
- KE max = if blessed: base + purchased (attr.kp)
- SK = (MU+KL+IN)/6 rounded
- ZK = (KO+KO+KK)/6 rounded
- INI = (MU+GE)/2 rounded
- AW = GE/2 rounded
- GS = race base (8 for Mensch)
- WS = KO/2 rounded

## Experience

- el (EL_1–7) → level name via static map
- ap.total → totalAP
- spentAP = totalAP, availableAP = 0 (Optolith only tracks total)

## Import Service

### OptolithImportService (replaces HeroImportService)

ID resolution strategy:
1. **rules.db** — ADV_*, DISADV_*, SA_*, TAL_*, CT_*, SPELL_*, CANTRIP_*, LITURGY_*, BLESSING_*
2. **Static maps** — ATTR_1–8, EL_1–7, R_1, haircolor/eyecolor/socialstatus, reach values
3. **Computed** — all derived values, weapon absolute AT/PA

Activatable parsing: categorize by prefix (ADV_ / DISADV_ / SA_), classify SA_ as general vs combat via rules.db category/group.

Format detection: check for `clientVersion` key → Optolith format.

### Deleted files

- HeroDTO.swift — replaced by direct Optolith parsing
- HeroImportService.swift — replaced by OptolithImportService
- Mount.swift — replaced by Pet

## File Change Summary

New: HeroTrait.swift, Pet.swift, HeroSpell.swift, OptolithImportService.swift
Modified: Hero.swift, Talent.swift, CombatTechnique.swift, MeleeWeapon.swift, Shield.swift, Armor.swift
Deleted: Mount.swift, HeroDTO.swift, HeroImportService.swift
View updates: any view referencing changed model fields
