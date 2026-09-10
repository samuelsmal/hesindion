# Derived-value rounding audit

**Date:** 2026-09-10
**Trigger:** spec `011_trefferzonen` compares damage against `derivedValues.wundschwelle`, which
exposed that `wundschwelle` truncates where DSA 5 rounds up. This audit sweeps the rest of the
codebase for the same class of error.

## The tell

`OptolithImportService.computeDerivedValues` is internally inconsistent. Two values round up
explicitly, three truncate via Swift's integer division — in the same function, a few lines apart:

```swift
let skBase   = speciesSK + Int(ceil(Double(mu + kl + inVal) / 6.0))   // rounds up
let zkBase   = speciesZK + Int(ceil(Double(ko + ko + kk) / 6.0))      // rounds up
let iniValue = (mu + ge) / 2                                          // truncates
let awValue  = ge / 2                                                 // truncates
let wsValue  = ko / 2                                                 // truncates
```

DSA 5 rounds derived values up. Truncation is one point low for every odd input.

## Project convention: round up

**Decided 2026-09-10.** Where a DSA 5 calculation produces a fraction and the rules do not clearly
say otherwise, **round up**. This is how the rules read, and how the table has been playing it.

Two things the convention does *not* cover, which still need reading the rule text:

- **"Je volle N Punkte" wordings**, which are floor by construction — the Leiteigenschaftsbonus and
  Bann des Eisens below are both of this shape.
- **Penalties**, where "up" is ambiguous: rounding a −1.5 penalty "up" numerically gives −1 (gentler)
  but "up in magnitude" gives −2 (harsher). Read the rule; do not apply the convention blind.

## Findings

### 1. Wundschwelle — confirmed bug

`OptolithImportService.swift:888`, `let wsValue = ko / 2`.

Proven by the Regelwiki's own worked example on the Trefferzonen page: *"Bei einer KO von 11 und
damit einer Wundschwelle von 6"*. `11 / 2` is `5` in Swift. Every hero with an odd KO is one point
low. Fix and repair are specified in `specs/011_trefferzonen/requirement.md`.

Separately, the Wundschwelle modifiers `ADV_54` (Eisern, +1) and `DISADV_56` (Gläsern, −1) are
never applied — `bonus` is hardcoded to `0`, unlike `seelenkraft` (`ADV_26`) and `zaehigkeit`
(`ADV_27`) which do look their traits up. Neither rule id appears anywhere in the Swift sources.

### 2. Ausweichen — bug, fix under the convention

`OptolithImportService.swift:881`, `let awValue = ge / 2` → `Int(ceil(Double(ge) / 2.0))`.

Nothing in the rules carves AW out, so the round-up convention applies. It also matches the `ceil`
treatment SK and ZK already get in this same function, and the community reading is explicit
(*"Ungerade Zahlen sind immer besser als Gerade, da aufgerundet wird"*).

Heroes with odd GE gain +1 AW. That changes defence rolls, so it is a visible change at the table,
not a silent correction — worth mentioning in the CHANGELOG rather than burying.

### 3. Initiative — bug, fix under the convention

`OptolithImportService.swift:877`, `let iniValue = (mu + ge) / 2` →
`Int(ceil(Double(mu + ge) / 2.0))`.

Wiki Aventurica gives the formula as *"(MU + GE)/2 + eventuelle Vor-/Nachteile"* (citing Kodex der
Helden p. 22) and states no rounding, so the convention applies.

The *"eventuelle Vor-/Nachteile"* term is separately unimplemented — the same omission as
Eisern/Gläsern on Wundschwelle. Scoping which traits modify INI is **not** part of this work; it is
a follow-up, and the rounding fix does not depend on it.

### 4. Checked and correct — leave alone

| Site | Expression | Why it is right |
|------|-----------|-----------------|
| `OptolithImportService.swift:30` | `max(0, Int(floor(Double(v - 8) / 3.0)))` | Leiteigenschaftsbonus is *"je volle 3 Punkte über 8"* — floor is the rule |
| `OptolithImportService.swift:514, 600, 631` | `(ktw + 1) / 2` | The `+1` idiom **is** `ceil(ktw/2)`; PA rounds up. Correct, just terse |
| `Hero.swift:243–245` | `(maxLP * 3) / 4`, `maxLP / 2`, `maxLP / 4` with `<=` | Schmerz triggers at or below a fraction of LE. For integer LE, `LE <= floor(f · max)` is exactly `LE <= f · max`. Truncation is correct here |
| `CombatSpellViews.swift:126`, `SpellProbeModal.swift:74` | `spell.value / 4` | Max spell modifications is FW/4 *abgerundet* |
| `CombatAttackViews.swift:195, 243` | `(kk - 20) / 2` | Mächtiger Schlag, guarded by `penalty > 0`, so the negative-truncation asymmetry is never reached |

### 5. Follow-ups — apply the convention after a rule read

| Site | Expression | Note |
|------|-----------|------|
| `Hero.swift:401` | `2 + (mountGS / 2)` | Sturmangriff bonus damage. A bonus, so the convention points at `ceil` — confirm the rule text does not say *"je volle 2"* |
| `CombatDefenseViews.swift:877` | `Text("GS/2 = \(gs / 2) Schritt")` | Movement display. Convention points at `ceil`. Display-only, so it is cosmetic until the number is used for something |
| `MagicModifiers.swift:51` | `ironSteinCarried / 2` | **Correct as-is.** Bann des Eisens is *−1 per 2 Stein* — a "je volle N" wording, so floor is right, and it is guarded by `penalty > 0` besides |

None of these block spec 011.

## Recommendation

1. Fix all three — Wundschwelle (rounding **and** Eisern/Gläsern), Ausweichen, Initiative — as one
   change, since all three are attribute-only and share the same `DerivedValueRepair` pass. The
   Wundschwelle half blocks spec 011; the other two ride along at no extra cost.
2. Extract the derived-value formulas out of `OptolithImportService` so the import path and the
   repair path share one definition. That is what lets a future rounding fix land in one place.
3. Persist the Optolith `raceId` (see spec 011) so species-dependent values become recomputable
   later. Not needed for this fix — LP, SK and ZK are already correct.
4. Item 5 needs a rules read, not a decision. Nothing depends on it.
5. Follow-up, out of scope here: the *"eventuelle Vor-/Nachteile"* term on Initiative.

## Note on the migration plan

While tracing where a repair pass should live: `HesindionApp.swift:15` constructs its container as
`ModelContainer(for: Hero.self, HeroStateEntry.self)` without a `migrationPlan:` argument, so
`HesindionMigrationPlan` (`Migration/MigrationPlan.swift`, stages V1–V4) is defined but never
applied. Unrelated to rounding, and not investigated further here, but worth confirming it is
deliberate.
