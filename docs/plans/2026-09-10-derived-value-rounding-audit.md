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

## Findings

### 1. Wundschwelle — confirmed bug

`OptolithImportService.swift:888`, `let wsValue = ko / 2`.

Proven by the Regelwiki's own worked example on the Trefferzonen page: *"Bei einer KO von 11 und
damit einer Wundschwelle von 6"*. `11 / 2` is `5` in Swift. Every hero with an odd KO is one point
low. Fix and repair are specified in `specs/011_trefferzonen/requirement.md`.

Separately, the Wundschwelle modifiers `ADV_54` (Eisern, +1) and `DISADV_56` (Gläsern, −1) are
never applied — `bonus` is hardcoded to `0`, unlike `seelenkraft` (`ADV_26`) and `zaehigkeit`
(`ADV_27`) which do look their traits up. Neither rule id appears anywhere in the Swift sources.

### 2. Ausweichen — very likely the same bug, needs a book check

`OptolithImportService.swift:881`, `let awValue = ge / 2`.

Community consensus is explicit that AW rounds up (*"Ungerade Zahlen sind immer besser als Gerade,
da aufgerundet wird"*), and it matches the `ceil` treatment SK and ZK already get in this same
function. But no primary quote was found stating the rounding for AW directly.

**Verify against the Basisregelwerk / Kodex der Helden before changing.** A hero with odd GE gains
+1 AW, which changes defence rolls — this is not a silent fix.

### 3. Initiative — very likely the same bug, needs a book check

`OptolithImportService.swift:877`, `let iniValue = (mu + ge) / 2`.

Wiki Aventurica gives the formula as *"(MU + GE)/2 + eventuelle Vor-/Nachteile"* (citing Kodex der
Helden p. 22) but states no rounding. Same reasoning and same caveat as Ausweichen.

Note also that the *"eventuelle Vor-/Nachteile"* term is unimplemented, the same omission as
Eisern/Gläsern on Wundschwelle. Scoping which advantages modify INI was not part of this pass.

### 4. Checked and correct — leave alone

| Site | Expression | Why it is right |
|------|-----------|-----------------|
| `OptolithImportService.swift:30` | `max(0, Int(floor(Double(v - 8) / 3.0)))` | Leiteigenschaftsbonus is *"je volle 3 Punkte über 8"* — floor is the rule |
| `OptolithImportService.swift:514, 600, 631` | `(ktw + 1) / 2` | The `+1` idiom **is** `ceil(ktw/2)`; PA rounds up. Correct, just terse |
| `Hero.swift:243–245` | `(maxLP * 3) / 4`, `maxLP / 2`, `maxLP / 4` with `<=` | Schmerz triggers at or below a fraction of LE. For integer LE, `LE <= floor(f · max)` is exactly `LE <= f · max`. Truncation is correct here |
| `CombatSpellViews.swift:126`, `SpellProbeModal.swift:74` | `spell.value / 4` | Max spell modifications is FW/4 *abgerundet* |
| `CombatAttackViews.swift:195, 243` | `(kk - 20) / 2` | Mächtiger Schlag, guarded by `penalty > 0`, so the negative-truncation asymmetry is never reached |

### 5. Not verified in this pass

Low impact, but no rules check was done:

- `Hero.swift:401` — Sturmangriff bonus `2 + (mountGS / 2)`
- `CombatDefenseViews.swift:877` — the `GS/2 = … Schritt` display
- `MagicModifiers.swift:51` — `ironSteinCarried / 2`

## Recommendation

1. Fix Wundschwelle (rounding **and** Eisern/Gläsern) as part of spec 011 — it blocks that spec.
2. Check AW and INI against the printed rules before touching them. If confirmed, they fold into
   the same `DerivedValueRepair` pass at no extra cost; both depend only on persisted attributes.
3. Extract the derived-value formulas out of `OptolithImportService` so the import path and the
   repair path share one definition. That is what lets a future rounding fix land in one place.
4. Item 5 can wait for a rules pass; nothing depends on it.

## Note on the migration plan

While tracing where a repair pass should live: `HesindionApp.swift:15` constructs its container as
`ModelContainer(for: Hero.self, HeroStateEntry.self)` without a `migrationPlan:` argument, so
`HesindionMigrationPlan` (`Migration/MigrationPlan.swift`, stages V1–V4) is defined but never
applied. Unrelated to rounding, and not investigated further here, but worth confirming it is
deliberate.
