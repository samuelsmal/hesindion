# Companion Data in Optolith's Pet Fields — Design

**Status:** Approved in chat 2026-10-03, spec for review.
**Date:** 2026-10-03
**Issue:** #49
**Supersedes:** `docs/plans/2026-09-24-companion-data-design.md` and ADR-0016.

## 1. The problem

ADR-0016 put a companion's data into a `hesindion` block that a Python tool (`make companions`)
writes into the Optolith export. That flow has four problems:

- **Too many steps.** Export from Optolith, edit a `.companions.json` build file, run
  `make companions` (and usually again with `FIX=1`), then import into Hesindion.
- **Optolith does not keep the block.** The block is a top-level key that Optolith does not know.
  A player who edits the pet in Optolith and exports again loses it.
- **Free text drops data without a message.** The attacks in `notes` are read with a regex. A typo
  (`Biss: AT 156TP 1W6+3`) drops the attack. `skills` mixes advantages and abilities.
- **Line breaks do not survive.** Every Optolith pet text field is a single-line `<input>`
  (`src/App/Views/Universal/TextField.tsx`, `develop-V1`). A pasted line break is lost, which is
  why the older Boronmir export reads `… RW mittel Biss: AT 12 …`.

## 2. Decisions

1. **Optolith is the only source of a companion's data.** The player edits the pet in Optolith's
   pet editor. Hesindion reads a plain Optolith export. No tool runs between the two.
2. **The purchase list and the AP check against Kat C are dropped.** The app shows Optolith's own
   `spentAp` / `totalAp`.
3. **The data uses Optolith's own fields, with a labelled single-line syntax in the text fields**
   (§3).
4. **A segment that does not parse does not stop the import.** The app keeps every part that
   parses, shows the problems in a modal after the import, and keeps them on the companion sheet
   until a clean re-import (§4).
5. **One format only.** The app ignores a `hesindion` block. The re-import question, the
   purchase list, the build file and `scripts/companions/` are removed (§5).

### Verified in Optolith (2026-10-03)

- Optolith's hero schema requires only `id`, `name`, `clientVersion`, `dateCreated` and
  `dateModified`, allows extra keys, and does not check the pet fields.
- An import gives the hero a new ID (`getNewIdByDate`). It adds a hero and does not replace one.
  Hesindion matches a hero by name, so the new ID does no harm.
- The round trip works: `specs/heroes/Boronmir Formattest.json` was imported into Optolith, the
  trick `Sitz` was added in the pet editor, and the export (`Boronmir Formattest_edit.json`)
  differs only in that trick, the hero's `id` and `dateModified`, and six empty `activatable`
  entries (`ADV_5: []` …) that Optolith drops by itself.
- The pet text fields have no length limit in the source.

## 3. The format

### 3.1 General rules (all three text fields)

- A field is a list of **segments** separated by `;`.
- A segment is `Label: content`. The label is case-insensitive. Space around `;`, `:` and `,` is
  ignored.
- Inside a segment, `,` separates the **items**.
- Neither `;` nor `,` separates inside parentheses. `Klettern (keine Probe erlaubt; Pferde können
  nicht klettern)` is one item.
- An item can end with a **note** in parentheses. The app shows the note but does not use it for
  a comparison: `Mächtiger Schlag (-4 auf Gegner Kraftakt)` counts as `Mächtiger Schlag`.
- The whole field is one line. The format needs no line breaks.

### 3.2 Field by field

| Optolith field (JSON key) | Content | `Pet` property |
|---|---|---|
| PA (`pa`) | integer | `defense` (VW) |
| RS (`pro`) | integer | `armor` (RS) |
| AP (`spentAp`, `totalAp`) | integers | `apSpent`, `apTotal` |
| Talente (`talents`) | `Name N` items, no labels. An item without a number is a note, not a problem. | `talents` (unchanged) |
| Sonderfertigkeiten (`skills`) | labels `Vorteile`, `Nachteile`, `Sonderfertigkeiten`, `Ausbildung`, `Tricks` | `advantages`, `disadvantages` (new), `abilities`, `training`, `tricks` |
| Notizen (`notes`) | labels `Angriffe` and `BE`. Each other segment is prose. | `attacks`, `encumbrance`; `notes` keeps the prose segments only |

An empty `pa` or `pro` gives `nil`. A missing `BE` segment gives `nil`.

### 3.3 Attacks

An `Angriffe` item is `Name AT n TP xWy±z RW kurz|mittel|lang`, for example
`Biss AT 16 TP 1W6+3 RW kurz`. The name can contain spaces (`Huf und Biss`). The `±z` part is
optional.

Without an `Angriffe` segment, the pet gets one attack from Optolith's own `attack`, `at`, `dp`
and `reach` fields, if `attack` is not empty.

### 3.4 Problems

Each of these is a `PetImportProblem`:

1. A segment in Sonderfertigkeiten with no label, or with an unknown label.
2. An `Angriffe` item that does not match §3.3.
3. A `BE` value that is not an integer.
4. A Talente item whose last word (before a note) starts with a digit but is not an integer
   (`Kraftakt 8a`). An item whose last word has no digit (`Klettern (…)`) is a note.
5. Optolith's `attack` field names an attack from `Angriffe`, and its `at` or `dp` differs from
   that attack's AT or TP. An `attack` name that is not in `Angriffe` is not a problem: the list
   is the source, and Optolith's `attack` field is then ignored.
6. A Notizen segment that is prose but contains attack-like text (`AT` and digits, then later
   `TP`), for example the old `Tritt: AT 15 TP 1W6+7 RW mittel`. The attack is not read, and the
   player must see that. Amended 2026-10-03 during planning.

An unknown label in Notizen is not a problem. It is prose (`Kampfverhalten: …`).

### 3.5 Example: Kupperus

- PA `14`, RS `0`
- Sonderfertigkeiten: `Vorteile: Ruhiges Temperament, Geduldig, Ausdauernd, Heldenwuchs, Zähes
  Tier, Schnell, Stark, Tapfer, Sprungsicher, Loyal; Sonderfertigkeiten: Mächtiger Schlag (-4 auf
  Gegner Kraftakt); Ausbildung: Reittier, Kampftier; Tricks: Aus, Fass I, Fass II, Komm, Sitz`
- Notizen: `Angriffe: Tritt AT 19 TP 1W6+8 RW mittel, Biss AT 16 TP 1W6+3 RW kurz, Niederreiten
  AT 19 TP 2W6+7 RW mittel; BE: 0; Kampfverhalten: Svellttaler Kaltblüter sind besonnen …`

## 4. The app

### 4.1 `PetTextFormat`

A new pure Swift type in `Hesindion/Services/PetTextFormat.swift`, with no SwiftData. It takes one
pet's dictionary from the export and returns the parsed values and `[PetImportProblem]`.

`PetImportProblem` (Codable, Hashable) holds the pet name, the Optolith field label as the player
sees it (`Sonderfertigkeiten`, `Notizen`, `Talente`), the exact segment or item text, and the
reason. It replaces `CompanionData.swift` and `OptolithImportService.parsePetAttacks`.

### 4.2 `parsePets`

`OptolithImportService.parsePets` calls `PetTextFormat` for each pet and writes the result into
`Pet`:

- `notes` keeps only the prose segments, so the sheet does not show the attacks two times.
- `hasMightyBlow` reads `abilities` only. The fallback to the raw `skills` text goes away with
  `specialSkills`. An unlabelled Sonderfertigkeiten field is a problem (§3.4, 1), so the player
  sees why Mächtiger Schlag does not apply (ADR-0018).
- A bad item drops only that item. The other items of the segment stay.

### 4.3 The problems reach the player

1. `HeroImportResult` gets `problems: [PetImportProblem]`. It becomes a struct (`kind`, `heroName`, `problems`) with `created(heroName:)` and `updated(heroName:)` factories. After an import with problems,
   `HeroListView` shows a `DSAModal` (a sibling in the root ZStack) that lists them, for example
   *Kupperus · Notizen · Angriffe: „Biss AT 156TP 1W6+3": TP fehlt*. It has one button, OK.
2. `Pet.importProblems` stores the list. The companion sheet (`HeroDetailView.petsSection`)
   shows one warning row per problem at the top of the pet. A clean re-import clears the list.

All strings go into `Strings.swift` (de + en). The modal and the rows get accessibility
identifiers (`import.problems.modal`, `pet.problem.<name>.<index>`).

## 5. Removals, migration, fixtures, docs

### 5.1 Removed

- App: `CompanionData.swift`, `parsePetAttacks`, `PetPurchase`, `Pet.purchases`,
  `Pet.specialSkills`, `hasCompanionData`, `adoptCompanionData`, `companionConflicts`, the
  `keepingCompanionDataFor` parameter, the re-import modal in `HeroListView` and its strings, and
  the `-uitest-seed-fixture` debug hook (`-uitest-reimport` stays for the problem UI test).
- Tests: `CompanionReimportFlowTests`, the re-import cases in `CompanionImportTests`, and
  `Hesindion/Resources/UITestHeroCompanions.json`.
- Tools: `scripts/companions/`, the `companions` and `test-companions` Makefile targets,
  `specs/data/companion-block.schema.json`, the `.companions.json` build file, and the
  `.companions.json` exclusions in the Makefile and in `scripts/rulec/hero_sheet_fixtures.py`.

### 5.2 Added and kept on `Pet`

- Added: `disadvantages: [String] = []`, `importProblems: [PetImportProblem] = []`.
- Kept: `defense`, `armor`, `encumbrance`, `advantages`, `abilities`, `training`, `tricks`,
  `apTotal`, `apSpent`. `apTotal` and `apSpent` now come from `totalAp` and `spentAp`.

### 5.3 Migration

The change adds and removes properties with defaults, so a lightweight migration is sufficient.
The plan checks how the 2026-09-24 `Pet` additions went through `MigrationPlan` and follows the
same method. A pet imported before the change keeps its stored values until the next import.

### 5.4 Fixtures

1. `specs/heroes/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json` takes its content from
   `Boronmir Formattest_edit.json`, with the original hero name. Its `hesindion` block goes away,
   so the sample is a real Optolith export.
2. `specs/heroes/Boronmir Siebenfeld von Greifenfurt.json` (the older export without labels) gets
   the new format **with its own values** (Tritt AT 15 TP 1W6+7, Biss AT 12 TP 1W6+2, Niederreiten
   AT 15 TP 2W6+6, Sonderfertigkeiten: Mächtiger Schlag). `TestData.boronmirURL` and 22 test
   files load it, and 11 of them expect these attacks. Amended 2026-10-03 during planning: the
   first version kept this file unlabelled as the problem fixture, which would break those tests.
3. Kupperus in `Hesindion/Resources/UITestHero.json` (a stripped copy of fixture 2) gets the same
   text as fixture 2, so the mount UI tests (issues #48, #51, #52) keep their attacks and their
   base values.
4. The two `Boronmir Formattest*.json` files are deleted, and `make hero-sheet-fixtures` runs
   again.

### 5.5 Tests

- `PetTextFormatTests`: one test per rule in §3.1–§3.3 and one per problem kind in §3.4.
- Import tests on fixtures 1 and 2: each gives its Kupperus values and no problems. The problem
  path is tested on a small export built inside the test from the old unlabelled text.
- Snapshot tests of the problem modal and of the warning rows on the companion sheet.
- The existing mount UI tests pass on the changed `UITestHero.json`.
- A UI test seeds `UITestHero` and re-imports `UITestHeroProblems.json` (the old unlabelled
  text) through `-uitest-reimport`, and sees the problem modal.

### 5.6 Docs

- **ADR-0021**, "Companion data lives in Optolith's pet fields". It supersedes ADR-0016, and
  ADR-0016's status changes to *Superseded by ADR-0021*.
- **`docs/companion-format.md`**, a player page with the grammar, the labels and the Kupperus
  example, to copy from when editing in Optolith.
- **`AGENTS.md`**: remove the `make companions` / `make test-companions` lines and the re-import
  hook. Link the player page.
- **CHANGELOG `[Unreleased]`**: Changed (companion data from Optolith's pet fields), Removed (the
  `hesindion` block, `make companions`, the re-import question), Fixed (an unreadable attack is
  reported, not dropped).
- `docs/plans/2026-09-24-companion-data-design.md` gets a status line: superseded by this design.

## 6. Out of scope

- An in-app editor for companions.
- Computing values from purchases, and any AP check.
- Using RS, BE, advantages or training in combat beyond what the app does today.
- Disadvantages in combat: the app stores and shows them only.
