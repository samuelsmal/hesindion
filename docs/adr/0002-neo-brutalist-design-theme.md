# ADR-0002: Neo-Brutalist Design Theme

## Status

Accepted

## Context

The app needed a distinctive visual identity that stands out from typical iOS apps while remaining usable. The tabletop RPG context invites a bold, characterful aesthetic.

## Decision

Adopt a **Neo-Brutalist** design theme: bold borders, high-contrast colors, flat surfaces with visible structure. This applies to all views and components.

## Consequences

- Strong visual identity that fits the tabletop RPG domain
- Custom styling needed for most standard UIKit/SwiftUI components
- Accessibility (contrast, readability) must be verified manually since we deviate from system defaults
