# Design: Add Spells & Liturgies to Rulebook

**Date:** 2026-03-08
**Branch:** feature/rules

## Overview

Add all magic content (arcane + karmal) to the rules database and display it in the rulebook. This covers ~650+ entries across spells, cantrips, liturgical chants, blessings, curses, elven songs, magical dances/melodies, and various ritual types.

## Categories & Groups

Two new categories:
- `spell` — "Zauber" (arcane magic)
- `liturgy` — "Liturgie" (karmal magic)

Group ID ranges in `groups` table:
- `4000+` — Spell groups from `SpellGroups.yaml`
- `5000+` — Liturgical chant groups from `LiturgicalChantGroups.yaml`
- `4999` — Cantrips (sentinel)
- `5999` — Blessings (sentinel)

## New Table: `spell_details`

```sql
CREATE TABLE spell_details (
    rule_id          TEXT PRIMARY KEY REFERENCES rules(id),
    check_attr_1     TEXT,
    check_attr_2     TEXT,
    check_attr_3     TEXT,
    improvement_cost TEXT,
    casting_time     TEXT,
    casting_time_short TEXT,
    ae_cost          TEXT,
    ae_cost_short    TEXT,
    range            TEXT,
    range_short      TEXT,
    duration         TEXT,
    duration_short   TEXT,
    target           TEXT,
    property         INTEGER,
    tradition_ids    TEXT,
    group_id         INTEGER
);

CREATE INDEX idx_spell_details_property ON spell_details(property);
CREATE INDEX idx_spell_details_group ON spell_details(group_id);
```

## Import Functions (build_db.py)

| Function | Source files | Category | Notes |
|---|---|---|---|
| `import_spells` | Spells.yaml | spell | check attrs, traditions, property |
| `import_cantrips` | Cantrips.yaml | spell | No checks, group_id=4999 |
| `import_curses` | Curses.yaml | spell | SpellGroup gr=3 |
| `import_elven_songs` | ElvenMagicalSongs.yaml | spell | SpellGroup gr=4 |
| `import_magical_dances` | MagicalDances.yaml | spell | SpellGroup gr=6 |
| `import_magical_melodies` | MagicalMelodies.yaml | spell | SpellGroup gr=5 |
| `import_domination_rituals` | DominationRituals.yaml | spell | SpellGroup gr=7 |
| `import_geode_rituals` | GeodeRituals.yaml | spell | SpellGroup gr=10 |
| `import_zibilja_rituals` | ZibiljaRituals.yaml | spell | SpellGroup gr=11 |
| `import_liturgical_chants` | LiturgicalChants.yaml | liturgy | aspects instead of properties |
| `import_blessings` | Blessings.yaml | liturgy | No checks, group_id=5999 |

Description source: `effect` field from de-DE YAML.

## Swift Changes

### RulesDatabase.swift
- Add `spell` and `liturgy` to category handling
- `RuleDetail` gets optional spell fields (castingTime, aeCost, range, duration, target)
- Query joins `spell_details` when category is `spell` or `liturgy`

### RuleDetailView.swift
- Render spell metadata block above description (casting time, cost, range, duration, target)
- Neo-Brutalist styling consistent with existing design

### No changes needed
- `RulebookView` — dynamically lists categories from DB
- `HeroListView` / sidebar — already has rulebook entry
- FTS — already indexes all `rules_i18n` rows
