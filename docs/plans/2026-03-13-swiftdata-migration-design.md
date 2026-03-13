# SwiftData VersionedSchema + SchemaMigrationPlan

**Date:** 2026-03-13
**Status:** Approved

## Problem

SwiftData model changes cause crashes on the simulator (and would on real devices) because the existing database is incompatible with the new schema. Currently the only fix is deleting the app.

## Decisions

- **Version granularity:** One schema version per app release (not per model change)
- **Migration strategy:** Lightweight migrations only (additive changes with defaults)
- **File organization:** Dedicated `Hesindion/Migration/` directory, separate from model files

## Design

### File Structure

```
Hesindion/Migration/
├── SchemaV1.swift          # Frozen snapshot of current schema (all 16 models)
├── MigrationPlan.swift     # SchemaMigrationPlan with ordered stages
```

### SchemaV1.swift

`enum SchemaV1: VersionedSchema` containing `@Model` copies of all 16 models with their exact current stored properties. Embedded Codable structs (`LifeEnergyValue`, `ResourceValue`, `ComputedValue`, `MutableResourceValue`, `PetAttributes`, `PetAttack`, `HeroTrait`) are also snapshotted inside SchemaV1.

This snapshot is frozen once created — it never changes.

### MigrationPlan.swift

`enum HesindionMigrationPlan: SchemaMigrationPlan`:
- `schemas: [SchemaV1.self]` (single entry initially)
- `stages: []` (empty — V1 is the starting point, no prior versions to migrate from)

### HesindionApp.swift

Replace manual `Schema([...])` + `ModelConfiguration` with:
```swift
ModelContainer(for: SchemaV1.self, migrationPlan: HesindionMigrationPlan.self)
```

### Adding Future Versions

When a release includes model changes:
1. Create `SchemaV2.swift` with the new schema snapshot
2. Add `.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)` to `stages`
3. Update `schemas` to `[SchemaV1.self, SchemaV2.self]`
4. Update `HesindionApp.swift` to use `SchemaV2.self`
5. If a change requires renames or type conversions, use `.custom` instead of `.lightweight`

### Constraints

- Live `@Model` classes remain unchanged — they are the "current" schema
- Each `VersionedSchema` must redeclare all models (SwiftData requirement)
- Lightweight migration handles: new optional properties, new properties with defaults, new models
- During development, delete the simulator app when schemas change; only formalize migrations for releases
