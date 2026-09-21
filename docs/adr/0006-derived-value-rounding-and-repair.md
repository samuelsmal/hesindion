# ADR-0006: DSA Rounding Convention and Launch-Time Value Repair

## Status

Accepted

## Context

Implementing the Trefferzonen rules required comparing damage against a hero's Wundschwelle, which
exposed a bug in how that value was computed. `OptolithImportService.computeDerivedValues` was
internally inconsistent: Seelenkraft and Zähigkeit rounded up with `Int(ceil(...))`, while
Initiative, Ausweichen and Wundschwelle truncated via Swift integer division, a few lines apart in
the same function.

The Regelwiki's own worked example settles which is right — *"Bei einer KO von 11 und damit einer
Wundschwelle von 6"* — and `11 / 2` is `5` in Swift. Every hero with an odd KO had a Wundschwelle one
point too low, and odd GE or odd MU+GE cost a point of Ausweichen and Initiative respectively.

Separately, the two traits that modify Wundschwelle — Eisern (`ADV_54`, +1) and Gläsern
(`DISADV_56`, −1) — were never applied; `bonus` was hardcoded to `0`, even though the neighbouring
Seelenkraft and Zähigkeit lines did look up their own traits.

Both problems persist in stored data: `computeDerivedValues` runs only at import, so fixing the
formula does not reach heroes already in the store.

## Decision

**Rounding convention.** Where a DSA 5 calculation yields a fraction and the rules do not clearly say
otherwise, round **up**. Two carve-outs stay explicit:

- *"Je volle N Punkte"* wordings are floor by construction — the Leiteigenschaftsbonus and Bann des
  Eisens are both of this shape and are correct as they are.
- For **penalties**, "up" is ambiguous: rounding a −1.5 penalty up numerically gives −1 (gentler),
  up in magnitude gives −2 (harsher). Read the rule; do not apply the convention blind.

The three affected formulas moved into `Hesindion/Engine/DerivedValueFormulas.swift` so the import
path and the repair path share one definition and cannot drift.

**Repair, not migration.** Stored values are corrected by `DerivedValueRepair`, an idempotent pass
run once from `ContentView`'s `.task`, saving only when something actually changed.

## Considered Alternatives

- **A `SchemaV5` migration stage.** Rejected on two counts. This is a data *repair*, not a shape
  change — no stored property is added or altered. And `HesindionApp` constructs its
  `ModelContainer` without a `migrationPlan:` argument, so `HesindionMigrationPlan` does not
  currently run at all; a new stage would have been silently dead code.
- **Recompute everything.** Not possible: LP, SK and ZK need the Optolith `raceId` for their species
  base, and `Hero` never persisted it (`PersonalData.species` holds a display name). That constraint
  turned out not to bind — the three wrong values depend only on persisted attributes and traits,
  and LP, SK and ZK were never wrong. `raceId` is now persisted as `PersonalData.speciesId` so a
  future species-aware recompute becomes possible.

## Consequences

- Heroes with an odd KO, odd GE, or odd MU+GE gain a point of Wundschwelle, Ausweichen and
  Initiative respectively. Ausweichen and Initiative change defence and turn order, so this is a
  visible change at the table, not a silent correction — it is in the CHANGELOG under `Fixed`.
- Adding a derived-value formula now has one obvious home, and a rounding fix lands in one place.
- The repair runs on every launch and writes nothing when there is nothing to fix, so the cost is one
  fetch. It is idempotent by test.
- Persisting `speciesId` makes a latent bug visible: the species tables cover only `R_1`–`R_4`
  (Mensch, Elf, Halbelf, Zwerg) and silently fall back to *human* values for anything else. Now
  detectable rather than invisible. Not fixed here.
  **Follow-up, 2026-09-21:** it found a real one. GS was not keyed on species at all — the import
  wrote a flat `base: 8` for every hero, so every dwarf (GS 6) was two Schritt too fast. The fix uses
  `speciesId` exactly as this ADR anticipated, and `DerivedValueFormulas` gains its first
  species-keyed formula; the file's docstring said *attribute-only*, which described its contents
  rather than its contract, and the contract — the import path and the repair path cannot drift — is
  precisely what GS needed once `DerivedValueRepair` learned about it. The fallback itself is
  unchanged and still human, but it is now an explicit `nil` from the formula that each caller
  decides about: the import substitutes the human value so a hero has something to display, the
  repair declines to write a number it cannot derive. See `CHANGELOG.md` under *Fixed* and Task 13 of
  `docs/plans/2026-09-20-rules-pipeline-and-authoring.md`.
- A future contributor who reads `ausweichen` and expects `GE / 2` will find `ceil`. The convention
  is recorded in `AGENTS.md` so it applies beyond this change.
