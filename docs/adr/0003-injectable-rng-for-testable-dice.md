# ADR-0003: Injectable RNG for testable dice

## Status

Accepted

## Context

Dice rolls were generated with `Int.random(in: 1...sides)` called inline inside
SwiftUI views (`DiceRollSheet`, `SkillCheckModal`). Because the randomness was
embedded in view code with no seam, there was no way to:

- statistically validate that the dice are fair (uniform, independent), or
- write deterministic, reproducible tests over the dice → check pipeline.

The check *logic* (`SkillCheckEngine`) was already a pure function, but the dice
feeding it were untestable.

## Decision

Introduce a pure `DiceRoller` engine whose core methods take an injectable
`inout RandomNumberGenerator`:

```swift
DiceRoller.roll(count:sides:using:&generator)
```

Production code uses no-generator convenience overloads that default to
`SystemRandomNumberGenerator` (the same primitive as before). Tests inject either:

- a seeded `SplitMix64` generator for deterministic/reproducible runs, or
- the real `SystemRandomNumberGenerator` for statistical goodness-of-fit checks.

Both views were rewired to call `DiceRoller` instead of `Int.random` inline.

## Consequences

- The exact production dice path is now testable end-to-end with the skill-check engine.
- Statistical tests (chi-square uniformity, mean, serial independence, critical
  rates) can hammer the shipping RNG; they are intentionally set at α=0.005, so
  they carry a ~1-in-200 false-positive rate per assertion — re-run before
  investigating an isolated failure.
- `SplitMix64` lives in the test target only; production randomness is unchanged.
- Future randomized mechanics should depend on `DiceRoller` rather than calling
  `Int.random` directly, preserving the testing seam.
