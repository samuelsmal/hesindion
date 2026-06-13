# ADR-0003: Player States — Static Catalog + Generic HeroStateEntry

## Status

Accepted

## Context

DSA 5 defines roughly 25 player conditions — 8 leveled Zustände (I–IV, e.g. Schmerz, Belastung, Furcht) and 17 binary Status (e.g. Eingeengt, Entrückung). Each carries rules metadata that the app must use in several places: a localized name, effect/cause/removal text shown to the player, an SF Symbol, a modifier mechanic applied to checks, and implication chains between states. The app needs to track which states (and at what level) are active per hero, apply their penalties to skill/combat checks, and surface them as chips and per-round reminders.

## Decision

Model state **data** as a static, in-code `StateCatalog` (`Hesindion/Models/StateCatalog.swift`) holding all ~25 definitions and their rules metadata, and model **per-hero state** as a single generic SwiftData model, `@Model HeroStateEntry(stateID, level)`, attached to `Hero` via a cascade relationship.

The −5 Zustand-penalty cap and the `isZustand` tagging that drives it live in the `ModifierEngine`, not in the catalog or the entry model — the catalog only describes a state's mechanic, while the engine decides how leveled-Zustand penalties combine and cap.

## Considered Alternatives

- **Explicit per-state properties on `Hero`** (one `Int`/`Bool` per condition). Rejected: every new or revised state would require a SwiftData schema migration, and the rules metadata (effects, cause, removal, symbol, implications) would still need a catalog somewhere, so this buys nothing while adding migration risk and ~25 fields of churn.

## Consequences

- Adding a state is one `StateCatalog` entry plus its localization strings — no schema migration, no new properties.
- Introducing `HeroStateEntry` was a single additive, lightweight SwiftData migration; thereafter the schema is stable as the catalog grows.
- Derived states (Schmerz, Belastung) stay computed from existing hero data rather than stored, and are excluded from manual add/edit via `StateCatalog.derivedIDs`, avoiding double-counting.
- State logic is split: descriptive rules metadata in the catalog, persisted per-hero levels in `HeroStateEntry`, and the −5 cap / `isZustand` combination logic in `ModifierEngine`.
