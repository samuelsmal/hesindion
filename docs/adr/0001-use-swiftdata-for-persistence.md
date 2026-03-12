# ADR-0001: Use SwiftData for Persistence

## Status

Accepted

## Context

The app needs to persist hero data, combat state, and imported rules locally on-device. Options considered were Core Data, SwiftData, SQLite directly, or flat-file JSON.

## Decision

Use **SwiftData** with the `@Model` macro for all persistent data. SwiftData integrates natively with SwiftUI via `@Query` and `@Environment(\.modelContext)`, reducing boilerplate and keeping the codebase aligned with Apple's recommended patterns for iOS 17+.

## Consequences

- Tight coupling to the Apple ecosystem (acceptable for an iOS-only app)
- Reactive UI updates come for free via `@Query`
- Migration tooling is still maturing compared to Core Data
- No external dependencies needed for persistence
