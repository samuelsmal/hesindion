# Companion Data — Design

**Status:** Approved in chat 2026-09-24, spec for review.
**Date:** 2026-09-24

## 1. The problem

Optolith stores an animal companion as free text plus a handful of numbers. Writing down
Kupperus's 336-AP build (Boronmir's Svellttaler Kaltblut) showed what that costs:

- **Nothing checks the build.** The export said Körperbeherrschung 4 where the build has 8,
  and `at` 18 where it has 19. No AP total is checked against the purchases.
- **Attacks live in `notes` prose.** The app reads them with a regex
  (`OptolithImportService.parsePetAttacks`). A typo, `Biss: AT 156TP 1W6+3`, drops the attack
  silently.
- **No place for VW, RS, advantages, training or tricks.** Optolith's `pa`/`pro` exist but the
  app ignores them. Advantages and abilities share one free-text `skills` field, and Mächtiger
  Schlag is found by `specialSkills.contains`.
- **Re-import wipes pets.** `applyImport` deletes and recreates `hero.pets`, so anything not in
  the export is lost.

## 2. Decisions

1. **The companion's build is a hand-written YAML file next to the export.** It holds the
   breed, the base values, every purchase with its AP, and the final values.
2. **A local tool checks the build and injects it into the Optolith JSON** under a top-level
   key Optolith does not use: `hesindion`. The tool does not compute final values. Rule effects
   (Kampftier's +20 % LeP, Heldenwuchs) remain the player's and GM's call, recorded in `values`.
3. **Hesindion reads the `hesindion` block when present**, and falls back to today's parsing
   when it is not.
4. **A re-import without the block asks, per affected pet, whether to keep the previous
   companion data.** "Keep" restores only the fields the block adds. Everything Optolith exports
   comes from the new file.
5. **No combat behaviour changes except the attack list.** VW, RS and advantages are stored
   and shown. Using them in combat is a later step.

## 3. The companion file

`<export basename>.companions.yaml`, next to the export. It has one entry per pet, keyed by the
pet's `name` in the export.

```yaml
schemaVersion: 1
pets:
  Kupperus:
    breed: svellttaler-kaltblut          # id, informational (rules/creatures/*.yaml)
    base:                                # the breed's stat block, as printed
      attributes: { mu: 12, kl: 10, in: 12, ch: 12, ff: 8, ge: 15, ko: 24, kk: 25 }
      lep: 75
      vw: 7
      attacks:
        - { name: Tritt, at: 15, tp: 1W6+7, rw: mittel }
      talents: { Körperbeherrschung: 4, Willenskraft: 3 }
      advantages: [Ruhiges Temperament]
      abilities: [Mächtiger Schlag]
      training: [Reittier]
    ap:
      total: 336
    purchases:
      - { advantage: Geduldig, ap: 5 }
      - { training: Kampftier, ap: 17 }
      - { trick: Komm, ap: 3 }
      - { raise: vw, from: 7, to: 14 }          # priced by the tool
      - { raise: at, from: 17, to: 19 }
      - { raise: "talent:Willenskraft", from: 3, to: 8 }
      - { buy: lep, count: 16 }                 # priced by the tool
    values:                                     # final, what the app uses
      attributes: { mu: 15, kl: 10, in: 12, ch: 12, ff: 8, ge: 15, ko: 26, kk: 28 }
      lep: 137
      ini: 15+1W6
      gs: 15
      vw: 14
      rs: 0
      be: 0
      attacks:
        - { name: Tritt, at: 19, tp: 1W6+8, rw: mittel }
      talents: { Körperbeherrschung: 8, Willenskraft: 8 }
      advantages: [Ruhiges Temperament, Geduldig]
      abilities: [Mächtiger Schlag]
      training: [Reittier, Kampftier]
      tricks: [Aus, Fass I, Fass II, Komm]
```

**The purchase kinds:**

| Kind | Fields | AP |
|---|---|---|
| `advantage`, `training`, `trick`, `ability` | name, `ap` | as written (the page's AP-Wert) |
| `raise` | target, `from`, `to` | Kat C, each step priced at the value reached. Targets: `mu`…`kk`, `vw`, `at`, `talent:<Name>` |
| `buy: lep` | `count` | the nth bought point costs what raising a value to n costs in Kat C |

**The Kat C column:** 3 AP per step up to 12, then 3 × (value − 11). The table's last row is 25 → 42.
Above it the same formula continues (26 → 45), since the table grows linearly.

## 4. The injected block

The tool writes the file's `ap`, `purchases` and `values` into the export, keyed by the export's
pet key:

```json
"hesindion": {
  "schemaVersion": 1,
  "pets": {
    "PET_1": {
      "name": "Kupperus",
      "breed": "svellttaler-kaltblut",
      "ap": { "total": 336, "spent": 336 },
      "purchases": [ { "kind": "advantage", "name": "Geduldig", "ap": 5 }, ... ],
      "values": { "vw": 14, "rs": 0, "be": 0, "attacks": [ ... ], "advantages": [ ... ],
                  "abilities": [ ... ], "training": [ ... ], "tricks": [ ... ] }
    }
  }
}
```

In the block every purchase is normalised to `{kind, name|target, ap, from?, to?, count?}`, with
the tool's price filled in. `base` is not injected, because the app does not need it. The JSON Schema
for the block lives at `specs/data/companion-block.schema.json`. The tool validates its own
output against it (by hand-written checks, so there is no new dependency). The Swift tests
decode the sample's block.

## 5. The tool

`scripts/companions/amend_export.py`, run as `make companions HERO="<export.json>"`. It reads
`<export>.companions.yaml` unless `--companions` names another file.

**Checks.** It reports all of them, and each one names the pet, the field and the expected value:

1. Every YAML pet name matches exactly one export pet, and no export pet is matched twice.
2. Every `raise` has `to > from` and a known target. Its price is recomputed.
   `buy: lep` has `count ≤ values.attributes.ko` (hero rule: bought LeP ≤ KO).
3. Σ purchases = `ap.total`. If the export has `totalAp`/`spentAp`, both equal `ap.total`.
4. Every attack has `at` (integer), `tp` (`\d+W\d+([+-]\d+)?`) and `rw` (`kurz|mittel|lang`).
5. **The export matches `values`:**
   - `cou…str` against `attributes`, `lp` against `lep`, `ini`, and `mov` against `gs`.
   - The export's `attack` names an attack in `values.attacks`, and `at`/`dp` equal that
     attack's `at`/`tp`.
   - Every `Name N` in the export's `talents` equals `values.talents`. Entries without a number
     (e.g. Klettern's note) are skipped.
   - Every attack line the regex finds in `notes` equals its `values.attacks` entry. Any
     `values.attacks` entry the regex misses is reported as unreadable.
   - `pa` and `pro`, when present, equal `vw`/`rs`.

**Writing.** It writes only when every check passes, either in place or to `--out`. It keeps
key order (`json.load` with the default dict, `ensure_ascii=False`, indent matching the input:
Optolith writes compact JSON, and the tool writes it back compact). With `--fix`, the export's
own fields are set from `values` instead of being checked: attributes, `lp`, `ini`, `mov`,
`at`/`dp`, `pa`/`pro`, the talents string, and the `notes` attack lines. The Kampfverhalten prose
stays. Errors exit 1. `--check` validates without writing.

**Tests.** `scripts/companions/test_amend_export.py` (unittest, no network) covers the cost
table (7→14 = 30, 18→19 = 24, 16 bought LeP = 78), each check's failure message, `--fix`,
key order, and a golden run on the Boronmir sample. `make test-companions` runs them.

## 6. The app

**`Pet` (SwiftData).** These are new properties, all defaulted, so migration is lightweight:
`defense: Int?` (VW), `armor: Int?` (RS), `encumbrance: Int?` (BE),
`advantages: [String] = []`, `abilities: [String] = []`, `training: [String] = []`,
`tricks: [String] = []`, `purchases: [PetPurchase] = []` (Codable), `apTotal: Int?`,
`apSpent: Int?`. `hasCompanionData` is computed as `apTotal != nil`.

**`parsePets`.** When `hesindion.pets[<key>]` exists:
- `attacks` come from `values.attacks` instead of the regex.
- The new properties come from the block.
- `specialSkills` becomes `abilities` joined.

Without the block, behaviour is unchanged. A block that fails to decode is ignored for that pet
and logged, as it would be if the block were missing. It is not an import error.

**Mächtiger Schlag.** `CombatAttackViews` checks `abilities` first and falls back to
`specialSkills.contains`.

**Display.** `HeroDetailView.petsSection` shows VW/RS when set, and advantages, abilities,
training and tricks as chips. A companion's AP line reads "336 / 336 AP".

## 7. Re-import

**Two steps in `OptolithImportService`:**

- `prepareImport(from:context:) -> PendingImport` parses everything and finds the existing hero
  by the same lookup `importHero` uses today.
- `PendingImport.companionConflicts: [CompanionConflict]` lists every stored pet with
  `hasCompanionData` whose name-matched pet in the new file has no block.
- `applyImport(_:keeping: Set<String>, context:)` writes. For a pet name in `keeping`, it copies
  `defense`, `armor`, `encumbrance`, `advantages`, `abilities`, `training`, `tricks`,
  `purchases`, `apTotal`, `apSpent` and the structured attacks from the old pet onto the new one
  before the old one is deleted.
- `importHero(from:context:)` stays, as prepare + apply keeping all. The UI test seed and
  existing tests keep working.

**`HeroListView`.** After `prepareImport`, if there are conflicts it shows one `DSAModal`, a
sibling in the root ZStack per AGENTS.md:

> **Kupperus: companion data missing**
> This export has no Hesindion companion data (VW, attacks, advantages, training, tricks).
> The last import had it. Keep the previous values?
> [Keep previous] [Use export only]

With several pets, it asks once per pet, in `petsInOrder` order. Cancelling the modal cancels
the import. All strings go into `Strings.swift` (de + en).

**Tests:**
- Unit: conflict detection (block present / absent / new hero / pet renamed). Keep restores
  every listed field and takes the Optolith fields from the new file. Discard leaves them empty.
- UI: import a sample with the block, re-import one without it, keep, and see VW still shown.
  The debug seed gains a second fixture: the same export stripped of `hesindion`.

## 8. Sample data

- **The 2026-09-24 Boronmir export** gets Körperbeherrschung 8, `Biss: AT 16 TP 1W6+3`, `at` 19
  and `pa` 14 via `--fix`, and the `hesindion` block from the tool.
- **`… (2026-09-24).companions.yaml`** holds Kupperus's build: 336 AP, as in the chat of
  2026-09-24. The list is below.
- **`Hesindion/Resources/UITestHero.json`** stays as it is, and a new stripped fixture joins it.

| Purchase | AP |
|---|---|
| Geduldig, Ausdauernd, Heldenwuchs, Zähes Tier, Schnell, Stark, Tapfer, Sprungsicher, Loyal | 5+15+15+12+8+15+15+5+10 = 100 |
| Kampftier (on top of the Reittier every horse has) | 17 |
| Komm | 3 |
| VW 7→14 | 30 |
| AT 17→19 | 21+24 = 45 |
| 16 bought LeP | 78 |
| Willenskraft 3→8, Selbstbeherrschung 4→8, Körperbeherrschung 4→8, Sinnesschärfe 4→8, Einschüchtern 6→10 | 15+12+12+12+12 = 63 |
| **Total** | **336** |

Ruhiges Temperament is part of the breed's stat block (Aventurische Tiergefährten p. 45) and
costs nothing.

## 9. Documentation

- **CHANGELOG `[Unreleased]`:** Added (companion data, tool, re-import question) and Fixed
  (attacks lost to a `notes` typo, once the block is present).
- **ADR 0015:** companion data rides in the Optolith export under `hesindion`.
- **AGENTS.md:** the `make companions` / `make test-companions` targets.

## 10. Out of scope

- Computing final values from purchases, and rule effects in combat (VW for the mount's
  defence, Ruhiges Temperament's +1 Reiten, Schmerz from the companion's LeP).
- Editing companions in the app.
- Loyalty. It is the hero's Kat B talent, paid from the hero's AP.
- Checking that a purchase is allowed for the breed, e.g. which training packages a Svellttaler
  can take.
