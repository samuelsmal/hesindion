# Action Log & Split Layout Design

**Date:** 2026-03-14
**Status:** Approved

## Overview

Two extensions to the iDSACompanion app:

1. **Action Log** — An event-sourcing log that records all talent checks, combat actions, healing, and resting. Entries are reversible (deleting an entry undoes its effect on hero state). Designed for future Supabase sync.
2. **Split Layout** — Replace the current notes-only right sidebar with a flexible split-screen system supporting Notes, Logs, and Rules panels.

## 1. Log Data Model

### LogEntry (SwiftData @Model)

```
LogEntry
├── id: UUID
├── timestamp: Date
├── kind: String          // discriminator: "talentCheck", "combatAction", "healing", "rest", "mountLPChange"
├── payload: Data         // JSON-encoded Codable struct per kind
└── hero: Hero?           // @Relationship
```

Hero gains:
```
@Relationship(deleteRule: .cascade, inverse: \LogEntry.hero)
var logEntries: [LogEntry] = []
```

### Payload Types (Codable structs)

**TalentCheckPayload**
- `talentName: String`
- `qualityLevel: Int`
- `succeeded: Bool`

**CombatActionPayload**
- `combatId: UUID` (groups all entries for one combat)
- `round: Int`
- `action: CombatActionType` (enum: attack, parry, dodge, damageDealt, damageTaken)
- `weaponName: String?`
- `rollValue: Int?`
- `damageDealt: Int?`
- `damageTaken: Int?`
- `lpChange: Int` (negative = damage, positive = healing)

**HealingPayload**
- `source: String` (potion name, spell, etc.)
- `lpRestored: Int`

**RestPayload**
- `lpRestored: Int`
- `duration: String?`

**MountLPChangePayload**
- `petName: String`
- `lpChange: Int` (negative = damage, positive = healing)

### Reversible Protocol

Each payload conforms to `Reversible`:
```swift
protocol Reversible {
    func reverse(on hero: Hero)
}
```

- `lpChange` reversal: `hero.derivedValues.lebensenergie.current -= lpChange`
- Mount LP reversal: `pet.currentLifeEnergy -= lpChange`
- Talent checks: no-op (informational only)
- Post-reversal: clamp LP to `0...max`
- Combat group deletion: reverse all child entries in chronological order (oldest first)

## 2. Layout System

### Portrait Mode
- Hero detail view takes full screen
- Side panels (Notes, Logs, Rules) open as full-screen views on top
- Toggle buttons visible on right edge
- Tapping active button closes panel, returns to hero detail

### Landscape Mode
- Default: hero detail view full-screen
- Right-edge toggle buttons for Notes / Logs / Rules
- Tapping a button opens 50/50 split: hero detail left, selected panel right
- Tapping active button closes panel (back to full-screen)
- Tapping different button replaces right panel (no stacking)
- Only hero detail can be full-screen

### Implementation
- Replace `ContentWithNotesLayout` with `SplitContentLayout`
- `@State var activePanel: SidePanel?` enum (`.notes`, `.logs`, `.rules`, `nil`)
- Vertical icon button strip on right edge
- GeometryReader or flexible frames for 50/50 split

## 3. Log View UI (LogPanelView)

- Chronological list, newest at top
- Grouped by combat: entries sharing `combatId` collapsible under summary header
  - Header: "Kampf — 5 Runden, -12 LP"
- Entry display: icon + one-line summary + timestamp
  - Talent: `"Klettern — QS 3 ✓"` / `"Klettern — misslungen ✗"`
  - Attack: `"Angriff Schwert — 14 TP"`
  - Damage: `"Schaden erhalten — 8 SP"`
  - Healing: `"Heiltrank — +5 LP"`
  - Rest: `"Rast — +3 LP"`
  - Mount: `"Sturmwind — Schaden 6"` / `"Sturmwind — Heilung +4 LP"`
- Swipe-to-delete with confirmation dialog (warns about reversal)
- Combat sub-entries: expandable, individually deletable

## 4. New Commands

### Heilung (Healing)
- Command palette entry: `"Heilung"`
- Sheet: source text field + LP number input
- Creates LogEntry with HealingPayload

### Rast (Rest)
- Extend existing `RegenerierenSheet` to emit LogEntry with RestPayload
- Ensure command palette entry exists

### Reittier: Heilung (Mount Healing)
- Command palette entry: `"Reittier: Heilung"`
- Sheet: LP number input
- Creates LogEntry with MountLPChangePayload

## 5. Logging Integration Points

| Source | Payload Type | Trigger |
|---|---|---|
| TalentProbeModal | TalentCheckPayload | On roll completion |
| CombatView (attack) | CombatActionPayload | On each attack/parry/dodge action |
| CombatView (damage) | CombatActionPayload | On takeDamage confirmation |
| MountDamageSheet | MountLPChangePayload | On confirm |
| Heilung command | HealingPayload | On confirm |
| Rast/Regenerieren | RestPayload | On confirm |
| Mount healing command | MountLPChangePayload | On confirm |
| EditCurrentModal | — | No logging (direct manipulation) |

## 6. Schema Migration

**SchemaV3** — additive only:
- New model: `LogEntry`
- New relationship on `Hero`: `logEntries`
- Lightweight migration (no data transformation)

### Sync-Readiness
- UUID id + Date timestamp for ordering and deduplication
- `kind` + JSON `payload` is self-describing for external consumers
- Hero UUID from Optolith import serves as foreign key for remote sync
