# Companion Data in Optolith's Pet Fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hesindion reads a companion's VW, RS, BE, attacks, advantages, disadvantages, abilities, training and tricks from a plain Optolith export, in a labelled single-line format, and tells the player about each part it cannot read. The `hesindion` block, `make companions` and the re-import question go away.

**Architecture:** A new pure parser, `PetTextFormat`, turns one pet's Optolith dictionary into values plus a list of `PetImportProblem`s. `OptolithImportService.parsePets` writes the values into `Pet` and stores the problems on it. `HeroImportResult` carries the problems to `HeroListView`, which lists them in a `DSAModal`. The companion sheet shows them as warning rows.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing (`@Test`, `#expect`) for unit tests, XCTest + swift-snapshot-testing for snapshots, XCUITest for UI tests, Python 3 for one-off fixture edits.

**Spec:** `docs/plans/2026-10-03-companion-text-format-design.md`

## Global Constraints

- Deployment target iOS 26.0+, iPhone and iPad. No external dependencies.
- Run one xcodebuild-backed target at a time, never widen the destination set (`make test-only ONLY=…`, `make test-ui`, `make test`).
- All user-visible strings go into `Hesindion/Theme/Strings.swift`, English **and** German.
- Every element a UI test drives gets an `.accessibilityIdentifier`.
- A modal is a `DSAModal`, a sibling in the root ZStack/overlay, never a system sheet.
- Rules are explicit to the player (ADR-0018): a part of the export that the import does not read is reported, never dropped without a message.
- List pets through `hero.petsInOrder`, never `hero.pets` directly.
- Commit messages: `<type>: <summary> (#49)`, ending with the two attribution lines:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01XqN782arHHEks4nWYuMR9X
  ```

## Format summary (from the spec, §3)

- A field is segments separated by `;`; a segment is `Label: content`; items inside are separated by `,`. Neither `;` nor `,` separates inside parentheses. Labels are case-insensitive. Space around separators is ignored. A trailing note in parentheses belongs to the item but not to its name.
- `pa` → VW, `pro` → RS, `spentAp`/`totalAp` → AP.
- Talente: `Name N` items. An item whose last word (before a note) has no digit is a note. A last word that starts with a digit but is not an integer is a problem.
- Sonderfertigkeiten (`skills`): labels `Vorteile`, `Nachteile`, `Sonderfertigkeiten`, `Ausbildung`, `Tricks`. No label or an unknown label is a problem.
- Notizen (`notes`): labels `Angriffe`, `BE`; every other segment is prose and stays in `Pet.notes`.
- Attack item: `Name AT n TP xWy±z RW kurz|mittel|lang`.
- No `Angriffe` segment → one attack from Optolith's `attack`/`at`/`dp`/`reach`, when `attack` is not empty and `at` is an integer.
- `attack` names an `Angriffe` entry with another AT or TP → problem. An `attack` name not in `Angriffe` → no problem.

## Spec amendments made while planning (Task 1 writes them into the spec)

1. **One more problem kind:** a Notizen prose segment that contains attack-like text (`AT <digits>` followed later by `TP`) is a problem (`attackOutsideAngriffe`). Without it, an old export (`Tritt: AT 15 TP …` in prose) imports without attacks and without a message, which ADR-0018 forbids.
2. **`-uitest-reimport` stays** for a UI test of the problem modal. `-uitest-seed-fixture` and `UITestHeroCompanions.json` go. A new bundled fixture, `UITestHeroProblems.json`, is today's `UITestHero.json` (old unlabelled text) before Task 4 converts it.
3. **`HeroImportResult` becomes a struct** (`kind`, `heroName`, `problems`) with `static func created(heroName:)` / `updated(heroName:)`, so existing `== .created(heroName:)` tests keep compiling.

## Review Focus

1. **An old-format export** (attack lines in Notizen prose, unlabelled Sonderfertigkeiten) must give problems, not a silent loss of attacks and Mächtiger Schlag. Test: `PetTextFormatTests.oldFormatExportReportsEveryUnreadPart` (Task 2) and `PetImportTests.oldFormatExportStoresProblems` (Task 4).
2. **Lower-case or mixed-case tokens** (`biss at 16 tp 1w6+3 rw Kurz`, `vorteile:`) must parse; a player types in Optolith by hand. Test: `PetTextFormatTests.tokensAreCaseInsensitive` (Task 2).
3. **Empty segments and stray separators** (`;;`, a trailing `;`, `, ,`) must not create items or problems. Test: `PetTextFormatTests.emptySegmentsAndItemsAreIgnored` (Task 2).
4. **A note with separators inside** (`Klettern (keine Probe erlaubt; Pferde …)`, `Mächtiger Schlag (-4, nur Nahkampf)`) stays one item, and the name used for rule look-ups has no note. Test: `PetTextFormatTests.parenthesesProtectSeparators` and `itemNameDropsTheNote` (Task 2), and `PetImportTests.mightyBlowFromAnAbilityWithANote` (Task 4).
5. **A re-import of a clean export clears earlier problems** on the sheet. Test: `PetImportTests.cleanReimportClearsProblems` (Task 4).

---

## File structure

| File | Responsibility | Task |
|---|---|---|
| `Hesindion/Services/PetTextFormat.swift` (new) | Pure parser and `PetImportProblem` | 2 |
| `HesindionTests/PetTextFormatTests.swift` (new) | Parser unit tests | 2 |
| `HesindionTests/Fixtures/StoreV6/StoreV6.store` (new) | A store written before `Pet.purchases`/`specialSkills` go | 3 |
| `HesindionTests/SchemaV7MigrationTests.swift` (new) | That store opens after the removal | 3 |
| `Hesindion/Models/Pet.swift` | Drop `PetPurchase`, `purchases`, `specialSkills`, `hasCompanionData`, `adoptCompanionData`; add `disadvantages`, `importProblems` | 4 |
| `Hesindion/Services/OptolithImportService.swift` | `parsePets` via `PetTextFormat`; drop the block, conflicts, keep-set, `companionBuildFile`; `HeroImportResult` struct | 4 |
| `Hesindion/Services/CompanionData.swift` | Deleted | 4 |
| `Hesindion/RulesEngine/PetSheetMapping.swift`, `Hesindion/Views/CombatAttackViews.swift`, `Hesindion/Views/HeroDetailView.swift` | Read the new properties | 4 |
| `Hesindion/Views/HeroListView.swift`, `Hesindion/UITestSeed.swift` | Drop the re-import question and `-uitest-seed-fixture` | 4 |
| `specs/heroes/*.json`, `Hesindion/Resources/UITestHero*.json` | Fixtures in the new format | 4 |
| `HesindionTests/PetImportTests.swift` (new, replaces `CompanionImportTests.swift`) | Import tests | 4 |
| `Hesindion/Views/ImportProblemsModal.swift` (new) | Problem modal and `PetImportProblemRow` | 5 |
| `HesindionTests/Snapshots/ImportProblemsSnapshotTests.swift` (new) | Snapshots | 5 |
| `HesindionUITests/ImportProblemsFlowTests.swift` (new, replaces `CompanionReimportFlowTests.swift`) | UI test | 5 |
| `scripts/companions/`, `Makefile`, `specs/data/companion-block.schema.json`, `scripts/rulec/hero_sheet_fixtures.py` | Tool removal | 6 |
| `docs/adr/0021-…`, `docs/adr/0016-…`, `docs/companion-format.md`, `AGENTS.md`, `CHANGELOG.md`, old design | Docs | 7 |

---

### Task 1: Write the planning amendments into the spec

**Files:**
- Modify: `docs/plans/2026-10-03-companion-text-format-design.md`

- [ ] **Step 1: Add the problem kind.** In §3.4, after item 5, add:

```markdown
6. A Notizen segment that is prose but contains attack-like text (`AT` and digits, then later
   `TP`), for example the old `Tritt: AT 15 TP 1W6+7 RW mittel`. The attack is not read, and the
   player must see that. Amended 2026-10-03 during planning.
```

- [ ] **Step 2: Amend §5.1 and §5.5.** In §5.1 "Removed", change "and the `-uitest-reimport` debug hook" to "and the `-uitest-seed-fixture` debug hook (`-uitest-reimport` stays for the problem UI test)". In §5.5 add the bullet:

```markdown
- A UI test seeds `UITestHero` and re-imports `UITestHeroProblems.json` (the old unlabelled
  text) through `-uitest-reimport`, and sees the problem modal.
```

- [ ] **Step 3: Amend §4.3.** After "`HeroImportResult` gets `problems: [PetImportProblem]`." add: "It becomes a struct (`kind`, `heroName`, `problems`) with `created(heroName:)` and `updated(heroName:)` factories."

- [ ] **Step 4: Commit**

```bash
git add docs/plans/2026-10-03-companion-text-format-design.md
git commit -m "docs: attack text outside Angriffe is a problem; the problem UI test keeps -uitest-reimport (#49)"
```

---

### Task 2: `PetTextFormat`, the parser

**Files:**
- Create: `Hesindion/Services/PetTextFormat.swift`
- Test: `HesindionTests/PetTextFormatTests.swift`

**Interfaces:**
- Consumes: `PetAttack(name:at:damage:reach:)` from `Hesindion/Models/Pet.swift` (unchanged).
- Produces:
  - `struct PetImportProblem: Codable, Hashable` with `pet: String`, `field: Field`, `text: String`, `reason: Reason`; `enum Field: String, Codable { case talente = "Talente", sonderfertigkeiten = "Sonderfertigkeiten", notizen = "Notizen", angriff = "Angriff" }`; `enum Reason: String, Codable { case noLabel, unknownLabel, badAttack, badBE, badTalentValue, attackMismatch, attackOutsideAngriffe }`.
  - `enum PetTextFormat` with `static func parse(_ pet: [String: Any]) -> PetTextFormat.Result`, `static func itemName(_ item: String) -> String`, `static func split(_ text: String, on separator: Character) -> [String]`.
  - `PetTextFormat.Result: Equatable` with `defense: Int?`, `armor: Int?`, `encumbrance: Int?`, `apTotal: Int?`, `apSpent: Int?`, `advantages`, `disadvantages`, `abilities`, `training`, `tricks: [String]` (items as written, notes included), `attacks: [PetAttack]`, `notes: String` (prose only), `problems: [PetImportProblem]`.

- [ ] **Step 1: Write the failing tests**

Create `HesindionTests/PetTextFormatTests.swift`:

```swift
import Testing
@testable import Hesindion

/// The labelled single-line format of a pet's Optolith text fields (issue #49,
/// docs/plans/2026-10-03-companion-text-format-design.md §3).
struct PetTextFormatTests {

    private func pet(_ fields: [String: Any]) -> [String: Any] {
        ["name": "Kupperus"].merging(fields) { _, new in new }
    }

    // MARK: - Separators

    @Test func splitIgnoresSeparatorsInsideParentheses() {
        let items = PetTextFormat.split("Einschüchtern 2, Klettern (keine Probe; nie, nimmer), Kraftakt 8", on: ",")
        #expect(items == ["Einschüchtern 2", "Klettern (keine Probe; nie, nimmer)", "Kraftakt 8"])
    }

    @Test func parenthesesProtectSeparators() {
        let r = PetTextFormat.parse(pet([
            "skills": "Sonderfertigkeiten: Mächtiger Schlag (-4 auf Gegner Kraftakt, nur Nahkampf; immer)",
        ]))
        #expect(r.abilities == ["Mächtiger Schlag (-4 auf Gegner Kraftakt, nur Nahkampf; immer)"])
        #expect(r.problems.isEmpty)
    }

    @Test func itemNameDropsTheNote() {
        #expect(PetTextFormat.itemName("Mächtiger Schlag (-4 auf Gegner Kraftakt)") == "Mächtiger Schlag")
        #expect(PetTextFormat.itemName("  Geduldig ") == "Geduldig")
    }

    @Test func emptySegmentsAndItemsAreIgnored() {
        let r = PetTextFormat.parse(pet([
            "skills": "Vorteile: Geduldig, , Loyal;; Tricks: Aus;",
            "notes": ";Angriffe: Biss AT 16 TP 1W6+3 RW kurz,;",
        ]))
        #expect(r.advantages == ["Geduldig", "Loyal"])
        #expect(r.tricks == ["Aus"])
        #expect(r.attacks == [PetAttack(name: "Biss", at: 16, damage: "1W6+3", reach: "kurz")])
        #expect(r.problems.isEmpty)
    }

    @Test func tokensAreCaseInsensitive() {
        let r = PetTextFormat.parse(pet([
            "skills": "vorteile: Geduldig; AUSBILDUNG: Reittier",
            "notes": "angriffe: biss at 16 tp 1w6+3 rw Kurz; be: 1",
        ]))
        #expect(r.advantages == ["Geduldig"])
        #expect(r.training == ["Reittier"])
        #expect(r.attacks == [PetAttack(name: "biss", at: 16, damage: "1W6+3", reach: "kurz")])
        #expect(r.encumbrance == 1)
        #expect(r.problems.isEmpty)
    }

    // MARK: - Fields

    @Test func numericFields() {
        let r = PetTextFormat.parse(pet(["pa": "14", "pro": "0", "spentAp": "336", "totalAp": "340"]))
        #expect(r.defense == 14)
        #expect(r.armor == 0)
        #expect(r.apSpent == 336)
        #expect(r.apTotal == 340)
    }

    @Test func emptyNumericFieldsAreNil() {
        let r = PetTextFormat.parse(pet(["pa": "", "pro": " "]))
        #expect(r.defense == nil)
        #expect(r.armor == nil)
        #expect(r.encumbrance == nil)
        #expect(r.apTotal == nil)
    }

    @Test func kupperusFromTheSpec() {
        let r = PetTextFormat.parse(pet([
            "pa": "14", "pro": "0", "attack": "Niederreiten", "at": "19", "dp": "2W6+7", "reach": "Mittel",
            "talents": "Einschüchtern 10, Klettern (keine Probe erlaubt; Pferde können nicht klettern), Kraftakt 8",
            "skills": "Vorteile: Ruhiges Temperament, Geduldig; Nachteile: Schreckhaft; Sonderfertigkeiten: Mächtiger Schlag (-4 auf Gegner Kraftakt); Ausbildung: Reittier, Kampftier; Tricks: Aus, Fass I",
            "notes": "Angriffe: Tritt AT 19 TP 1W6+8 RW mittel, Biss AT 16 TP 1W6+3 RW kurz, Niederreiten AT 19 TP 2W6+7 RW mittel; BE: 0; Kampfverhalten: Svellttaler Kaltblüter sind besonnen.",
        ]))
        #expect(r.advantages == ["Ruhiges Temperament", "Geduldig"])
        #expect(r.disadvantages == ["Schreckhaft"])
        #expect(r.abilities == ["Mächtiger Schlag (-4 auf Gegner Kraftakt)"])
        #expect(r.training == ["Reittier", "Kampftier"])
        #expect(r.tricks == ["Aus", "Fass I"])
        #expect(r.attacks == [
            PetAttack(name: "Tritt", at: 19, damage: "1W6+8", reach: "mittel"),
            PetAttack(name: "Biss", at: 16, damage: "1W6+3", reach: "kurz"),
            PetAttack(name: "Niederreiten", at: 19, damage: "2W6+7", reach: "mittel"),
        ])
        #expect(r.encumbrance == 0)
        #expect(r.notes == "Kampfverhalten: Svellttaler Kaltblüter sind besonnen.")
        #expect(r.problems.isEmpty)
    }

    @Test func attackNameWithSpacesAndNoBonus() {
        let r = PetTextFormat.parse(pet(["notes": "Angriffe: Huf und Biss AT 12 TP 2W6 RW lang"]))
        #expect(r.attacks == [PetAttack(name: "Huf und Biss", at: 12, damage: "2W6", reach: "lang")])
    }

    @Test func withoutAngriffeTheOptolithAttackIsTheOnlyOne() {
        let r = PetTextFormat.parse(pet(["attack": "Biss", "at": "12", "dp": "1W6+2", "reach": "Kurz"]))
        #expect(r.attacks == [PetAttack(name: "Biss", at: 12, damage: "1W6+2", reach: "kurz")])
    }

    @Test func withoutAngriffeAndWithoutAnAttackNameThereIsNoAttack() {
        let r = PetTextFormat.parse(pet(["attack": "", "at": "12"]))
        #expect(r.attacks.isEmpty)
        #expect(r.problems.isEmpty)
    }

    @Test func proseWithoutLabelsStaysWhole() {
        let r = PetTextFormat.parse(pet(["notes": "Ein ruhiges Pferd, das gern Äpfel frisst."]))
        #expect(r.notes == "Ein ruhiges Pferd, das gern Äpfel frisst.")
        #expect(r.problems.isEmpty)
    }

    // MARK: - Problems

    @Test func unlabelledSonderfertigkeitIsAProblem() {
        let r = PetTextFormat.parse(pet(["skills": "Mächtiger Schlag"]))
        #expect(r.abilities.isEmpty)
        #expect(r.problems == [PetImportProblem(pet: "Kupperus", field: .sonderfertigkeiten,
                                                text: "Mächtiger Schlag", reason: .noLabel)])
    }

    @Test func unknownLabelInSonderfertigkeitenIsAProblem() {
        let r = PetTextFormat.parse(pet(["skills": "Vortiele: Geduldig; Tricks: Aus"]))
        #expect(r.tricks == ["Aus"])
        #expect(r.problems == [PetImportProblem(pet: "Kupperus", field: .sonderfertigkeiten,
                                                text: "Vortiele: Geduldig", reason: .unknownLabel)])
    }

    @Test func badAttackDropsOnlyThatItem() {
        let r = PetTextFormat.parse(pet(["notes": "Angriffe: Tritt AT 19 TP 1W6+8 RW mittel, Biss AT 156TP 1W6+3 RW kurz"]))
        #expect(r.attacks == [PetAttack(name: "Tritt", at: 19, damage: "1W6+8", reach: "mittel")])
        #expect(r.problems == [PetImportProblem(pet: "Kupperus", field: .notizen,
                                                text: "Biss AT 156TP 1W6+3 RW kurz", reason: .badAttack)])
    }

    @Test func badBEIsAProblem() {
        let r = PetTextFormat.parse(pet(["notes": "BE: eins"]))
        #expect(r.encumbrance == nil)
        #expect(r.problems == [PetImportProblem(pet: "Kupperus", field: .notizen, text: "BE: eins", reason: .badBE)])
    }

    @Test func badTalentValueIsAProblemButANoteIsNot() {
        let r = PetTextFormat.parse(pet(["talents": "Kraftakt 8a, Klettern (keine Probe erlaubt), Schwimmen 4"]))
        #expect(r.problems == [PetImportProblem(pet: "Kupperus", field: .talente, text: "Kraftakt 8a", reason: .badTalentValue)])
    }

    @Test func optolithAttackThatDisagreesWithTheListIsAProblem() {
        let r = PetTextFormat.parse(pet([
            "attack": "Niederreiten", "at": "18", "dp": "2W6+7",
            "notes": "Angriffe: Niederreiten AT 19 TP 2W6+7 RW mittel",
        ]))
        #expect(r.attacks.count == 1)
        #expect(r.problems == [PetImportProblem(pet: "Kupperus", field: .angriff,
                                                text: "Niederreiten AT 18 TP 2W6+7", reason: .attackMismatch)])
    }

    @Test func optolithAttackNotInTheListIsNoProblem() {
        let r = PetTextFormat.parse(pet([
            "attack": "Tritt", "at": "1", "dp": "1W6",
            "notes": "Angriffe: Biss AT 16 TP 1W6+3 RW kurz",
        ]))
        #expect(r.attacks == [PetAttack(name: "Biss", at: 16, damage: "1W6+3", reach: "kurz")])
        #expect(r.problems.isEmpty)
    }

    @Test func oldFormatExportReportsEveryUnreadPart() {
        let r = PetTextFormat.parse(pet([
            "attack": "Niederreiten", "at": "15", "dp": "2W6+6", "reach": "Mittel",
            "skills": "Mächtiger Schlag",
            "notes": "Tritt: AT 15 TP 1W6+7 RW mittel Biss: AT 12 TP 1W6+2 RW kurz; Kampfverhalten: Svellttaler Kaltblüter sind besonnen.",
        ]))
        #expect(r.attacks == [PetAttack(name: "Niederreiten", at: 15, damage: "2W6+6", reach: "mittel")])
        #expect(r.abilities.isEmpty)
        #expect(r.problems == [
            PetImportProblem(pet: "Kupperus", field: .sonderfertigkeiten, text: "Mächtiger Schlag", reason: .noLabel),
            PetImportProblem(pet: "Kupperus", field: .notizen,
                             text: "Tritt: AT 15 TP 1W6+7 RW mittel Biss: AT 12 TP 1W6+2 RW kurz",
                             reason: .attackOutsideAngriffe),
        ])
        #expect(r.notes == "Tritt: AT 15 TP 1W6+7 RW mittel Biss: AT 12 TP 1W6+2 RW kurz; Kampfverhalten: Svellttaler Kaltblüter sind besonnen.")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `make test-only ONLY=HesindionTests/PetTextFormatTests`
Expected: build FAIL with "cannot find 'PetTextFormat' in scope".

- [ ] **Step 3: Write the implementation**

Create `Hesindion/Services/PetTextFormat.swift`:

```swift
import Foundation

/// One part of a pet's Optolith fields that the import could not read (issue #49). The import
/// keeps every other part; the player sees each problem after the import and on the companion
/// sheet (ADR-0018).
struct PetImportProblem: Codable, Hashable {
    /// The Optolith pet editor's label of the field, as the player sees it there.
    enum Field: String, Codable {
        case talente = "Talente"
        case sonderfertigkeiten = "Sonderfertigkeiten"
        case notizen = "Notizen"
        case angriff = "Angriff"
    }

    enum Reason: String, Codable {
        case noLabel, unknownLabel, badAttack, badBE, badTalentValue, attackMismatch, attackOutsideAngriffe
    }

    var pet: String
    var field: Field
    var text: String
    var reason: Reason
}

/// The labelled single-line format of a pet's Optolith text fields
/// (docs/plans/2026-10-03-companion-text-format-design.md §3). Optolith's pet fields are
/// single-line inputs, so `;` separates segments and `,` separates items; neither separates
/// inside parentheses.
enum PetTextFormat {
    struct Result: Equatable {
        var defense: Int?
        var armor: Int?
        var encumbrance: Int?
        var apTotal: Int?
        var apSpent: Int?
        var advantages: [String] = []
        var disadvantages: [String] = []
        var abilities: [String] = []
        var training: [String] = []
        var tricks: [String] = []
        var attacks: [PetAttack] = []
        /// The Notizen segments that are prose, joined with "; ".
        var notes: String = ""
        var problems: [PetImportProblem] = []
    }

    private static let attackPattern =
        /^(.+?)\s+AT\s+(\d+)\s+TP\s+(\d+W\d+(?:[+-]\d+)?)\s+RW\s+(kurz|mittel|lang)$/.ignoresCase()
    /// Attack-like text in prose: the old `Tritt: AT 15 TP …` lines.
    private static let attackLikePattern = /\bAT\s*\d+.*\bTP\b/.ignoresCase()

    static func parse(_ pet: [String: Any]) -> Result {
        let name = pet["name"] as? String ?? "?"
        var r = Result()
        r.defense = int(pet["pa"])
        r.armor = int(pet["pro"])
        r.apSpent = int(pet["spentAp"])
        r.apTotal = int(pet["totalAp"])

        func problem(_ field: PetImportProblem.Field, _ text: String, _ reason: PetImportProblem.Reason) {
            r.problems.append(PetImportProblem(pet: name, field: field, text: text, reason: reason))
        }

        // Talente: the text stays in `Pet.talents`; only a number that does not parse is reported.
        for item in split(string(pet["talents"]), on: ",") {
            if let last = itemName(item).split(separator: " ").last,
               last.first?.isNumber == true, Int(last) == nil {
                problem(.talente, item, .badTalentValue)
            }
        }

        // Sonderfertigkeiten
        for segment in split(string(pet["skills"]), on: ";") {
            guard let (label, content) = labelled(segment) else {
                problem(.sonderfertigkeiten, segment, .noLabel)
                continue
            }
            let items = split(content, on: ",")
            switch label {
            case "vorteile": r.advantages += items
            case "nachteile": r.disadvantages += items
            case "sonderfertigkeiten": r.abilities += items
            case "ausbildung": r.training += items
            case "tricks": r.tricks += items
            default: problem(.sonderfertigkeiten, segment, .unknownLabel)
            }
        }

        // Notizen
        var prose: [String] = []
        var hasAngriffe = false
        for segment in split(string(pet["notes"]), on: ";") {
            switch labelled(segment)?.label {
            case "angriffe":
                hasAngriffe = true
                for item in split(labelled(segment)!.content, on: ",") {
                    if let attack = attack(item) { r.attacks.append(attack) } else { problem(.notizen, item, .badAttack) }
                }
            case "be":
                if let be = Int(labelled(segment)!.content) { r.encumbrance = be } else { problem(.notizen, segment, .badBE) }
            default:
                prose.append(segment)
                if segment.contains(attackLikePattern) { problem(.notizen, segment, .attackOutsideAngriffe) }
            }
        }
        r.notes = prose.joined(separator: "; ")

        // Optolith's own attack fields
        let attackName = string(pet["attack"])
        let at = int(pet["at"])
        let dp = string(pet["dp"])
        if !hasAngriffe {
            if !attackName.isEmpty, let at {
                r.attacks = [PetAttack(name: attackName, at: at, damage: dp, reach: string(pet["reach"]).lowercased())]
            }
        } else if !attackName.isEmpty,
                  let listed = r.attacks.first(where: { $0.name.caseInsensitiveCompare(attackName) == .orderedSame }),
                  at != listed.at || dp.uppercased() != listed.damage {
            problem(.angriff, "\(attackName) AT \(at.map(String.init) ?? "") TP \(dp)", .attackMismatch)
        }
        return r
    }

    /// The item without a trailing note in parentheses: "Mächtiger Schlag (-4 …)" → "Mächtiger Schlag".
    static func itemName(_ item: String) -> String {
        let trimmed = item.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix(")"), let open = trimmed.firstIndex(of: "(") else { return trimmed }
        return trimmed[..<open].trimmingCharacters(in: .whitespaces)
    }

    /// Splits on `separator` outside parentheses, trims each part, drops empty parts.
    static func split(_ text: String, on separator: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        for ch in text {
            if ch == "(" { depth += 1 }
            if ch == ")" { depth = max(0, depth - 1) }
            if ch == separator, depth == 0 {
                parts.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        parts.append(current)
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// "Label: content" with the first `:` outside parentheses; the label lower-cased.
    private static func labelled(_ segment: String) -> (label: String, content: String)? {
        var depth = 0
        for index in segment.indices {
            switch segment[index] {
            case "(": depth += 1
            case ")": depth = max(0, depth - 1)
            case ":" where depth == 0:
                let label = segment[..<index].trimmingCharacters(in: .whitespaces).lowercased()
                let content = segment[segment.index(after: index)...].trimmingCharacters(in: .whitespaces)
                return label.isEmpty ? nil : (label, content)
            default: break
            }
        }
        return nil
    }

    private static func attack(_ item: String) -> PetAttack? {
        guard let m = item.wholeMatch(of: attackPattern), let at = Int(m.2) else { return nil }
        return PetAttack(name: String(m.1), at: at, damage: m.3.uppercased(), reach: m.4.lowercased())
    }

    private static func string(_ value: Any?) -> String {
        (value as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    private static func int(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        return Int(string(value))
    }
}
```

Note on the attack `name`: the regex's lazy `(.+?)` keeps spaces (`Huf und Biss`). The TP is upper-cased (`1w6+3` → `1W6+3`) so it compares with Optolith's `dp`.

Note on `oldFormatExportReportsEveryUnreadPart`: the segment `Tritt: AT 15 …` has the label `tritt` (unknown in Notizen), so it is prose and also an `attackOutsideAngriffe` problem.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `make test-only ONLY=HesindionTests/PetTextFormatTests`
Expected: all tests PASS. If `tokensAreCaseInsensitive` fails on the name `biss`, check that the name keeps the player's case (the test expects `biss`).

- [ ] **Step 5: Commit**

```bash
git add Hesindion/Services/PetTextFormat.swift HesindionTests/PetTextFormatTests.swift
git commit -m "feat: PetTextFormat reads a pet's labelled Optolith fields and names what it cannot read (#49)"
```

---

### Task 3: A store fixture written before the `Pet` properties go

`Pet.purchases` and `Pet.specialSkills` go in Task 4. The app has no migration plan: `HesindionApp` opens its store with `ModelContainer(for: Hero.self, HeroStateEntry.self)` and SwiftData infers the migration (see `Hesindion/Migration/MigrationPlan.swift` and `HesindionTests/SchemaV6MigrationTests.swift`). This task captures a real store from **today's** model so a test can prove the removal opens it.

**Files:**
- Create: `HesindionTests/Fixtures/StoreV6/StoreV6.store`
- Create: `HesindionTests/SchemaV7MigrationTests.swift`
- Modify: `Hesindion/Migration/MigrationPlan.swift`, create `Hesindion/Migration/SchemaV7.swift`

- [ ] **Step 1: Write a throwaway test that writes the store**

Create `HesindionTests/WriteStoreV6Fixture.swift` (deleted in Step 3):

```swift
import XCTest
import SwiftData
@testable import Hesindion

@MainActor
final class WriteStoreV6Fixture: XCTestCase {
    func testWrite() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("StoreV6", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("StoreV6.store")
        do {
            let container = try ModelContainer(for: Hero.self, HeroStateEntry.self,
                                               configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            let export = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("specs/heroes/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json")
            try OptolithImportService().importHero(from: export, context: context)
            try context.save()
            let pet = try XCTUnwrap(try context.fetch(FetchDescriptor<Hero>()).first?.petsInOrder.first)
            XCTAssertEqual(pet.purchases.count, 19)
            XCTAssertEqual(pet.specialSkills.isEmpty, false)
        }
        print("STOREV6_PATH=\(url.path)")
    }
}
```

- [ ] **Step 2: Run it and copy the store into the repo, checkpointed to one file**

Run: `make test-only ONLY=HesindionTests/WriteStoreV6Fixture 2>&1 | grep STOREV6_PATH`
Expected: one line `STOREV6_PATH=/…/StoreV6.store` (a path inside the simulator's data, readable from the Mac).

Then:

```bash
P="<the printed path>"
sqlite3 "$P" "PRAGMA wal_checkpoint(TRUNCATE);"
mkdir -p HesindionTests/Fixtures/StoreV6
cp "$P" HesindionTests/Fixtures/StoreV6/StoreV6.store
sqlite3 HesindionTests/Fixtures/StoreV6/StoreV6.store "PRAGMA journal_mode;" 
ls HesindionTests/Fixtures/StoreV6
```

Expected: only `StoreV6.store` in the directory.

- [ ] **Step 3: Delete the throwaway test**

```bash
rm HesindionTests/WriteStoreV6Fixture.swift
```

- [ ] **Step 4: Write the migration test**

Create `HesindionTests/SchemaV7MigrationTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Hesindion

/// SchemaV7 drops `Pet.purchases` and `Pet.specialSkills` and adds `Pet.disadvantages` and
/// `Pet.importProblems` (issue #49). `Fixtures/StoreV6/StoreV6.store` is a store the build before
/// the change wrote with the app's own container call and an imported 2026-09-24 Boronmir, whose
/// Kupperus had 19 purchases. It cannot be regenerated now that the properties are gone.
@MainActor
final class SchemaV7MigrationTests: XCTestCase {

    private func openableFixtureCopyURL() throws -> URL {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/StoreV6/StoreV6.store")
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaV7MigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let copy = scratch.appendingPathComponent("StoreV6.store")
        try FileManager.default.copyItem(at: fixture, to: copy)
        return copy
    }

    func testAPreSchemaV7StoreOpensAndKeepsTheCompanion() throws {
        let container = try ModelContainer(
            for: Hero.self, HeroStateEntry.self,
            configurations: ModelConfiguration(url: try openableFixtureCopyURL())
        )
        let hero = try XCTUnwrap(try ModelContext(container).fetch(FetchDescriptor<Hero>()).first)
        let pet = try XCTUnwrap(hero.petsInOrder.first)
        XCTAssertEqual(pet.name, "Kupperus")
        XCTAssertEqual(pet.defense, 14)
        XCTAssertEqual(pet.attacks.count, 3)
        XCTAssertEqual(pet.disadvantages, [])
        XCTAssertEqual(pet.importProblems, [])
    }
}
```

This test does not compile until Task 4 adds `disadvantages` and `importProblems`. Leave the last two asserts out for now (comment them with `// Task 4:`), so the test passes on today's model.

- [ ] **Step 5: Run it**

Run: `make test-only ONLY=HesindionTests/SchemaV7MigrationTests`
Expected: PASS.

- [ ] **Step 6: Add the schema record**

Create `Hesindion/Migration/SchemaV7.swift` as a copy of `SchemaV6.swift` with `enum SchemaV7` and `Schema.Version(7, 0, 0)`. Change `SchemaV6.swift`'s `models` to stay as it is (it points at the live types, as before). In `MigrationPlan.swift` add `SchemaV7.self` to `schemas`, `migrateV6toV7` to `stages`, and:

```swift
    static let migrateV6toV7 = MigrationStage.lightweight(
        fromVersion: SchemaV6.self,
        toVersion: SchemaV7.self
    )
```

- [ ] **Step 7: Commit**

```bash
git add HesindionTests/Fixtures/StoreV6 HesindionTests/SchemaV7MigrationTests.swift Hesindion/Migration
git commit -m "test: a store with Kupperus's purchases, written before Pet.purchases goes (#49)"
```

---

### Task 4: The import reads the new format; the old paths go

This task changes the model, the import, its callers and the fixtures together, because the build and the existing tests need all of them at once.

**Files:**
- Modify: `Hesindion/Models/Pet.swift`
- Modify: `Hesindion/Services/OptolithImportService.swift`
- Delete: `Hesindion/Services/CompanionData.swift`
- Modify: `Hesindion/RulesEngine/PetSheetMapping.swift:15`
- Modify: `Hesindion/Views/CombatAttackViews.swift:234-240`
- Modify: `Hesindion/Views/HeroDetailView.swift:1214-1225, 1280-1290, 1362-1378`
- Modify: `Hesindion/Views/HeroListView.swift` (re-import question out; `importResult.kind`)
- Modify: `Hesindion/UITestSeed.swift` (`-uitest-seed-fixture` out)
- Modify: `Hesindion/Theme/Strings.swift` (`companion.reimport.*` out, en + de)
- Modify fixtures: `specs/heroes/Boronmir Siebenfeld von Greifenfurt.json`, `specs/heroes/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json`, `Hesindion/Resources/UITestHero.json`
- Create: `Hesindion/Resources/UITestHeroProblems.json`; delete `Hesindion/Resources/UITestHeroCompanions.json`
- Delete: `HesindionTests/CompanionImportTests.swift`, `HesindionUITests/CompanionReimportFlowTests.swift`
- Create: `HesindionTests/PetImportTests.swift`
- Modify: `HesindionTests/SchemaV7MigrationTests.swift` (the two Task 4 asserts back in)

**Interfaces:**
- Consumes: `PetTextFormat.parse(_:)`, `PetTextFormat.itemName(_:)`, `PetImportProblem` (Task 2).
- Produces:
  - `Pet.disadvantages: [String] = []`, `Pet.importProblems: [PetImportProblem] = []`; `Pet.hasMightyBlow` reads `abilities`.
  - `struct HeroImportResult: Equatable { enum Kind: Equatable { case created, updated }; var kind: Kind; var heroName: String; var problems: [PetImportProblem] = []; static func created(heroName: String) -> HeroImportResult; static func updated(heroName: String) -> HeroImportResult }`.
  - `OptolithImportService.importHero(from: URL, context:)` and `importHero(from: Data, context:)` with no `keepingCompanionDataFor`.

- [ ] **Step 1: Convert the fixtures**

Run this one-off script from the repo root (do not commit it):

```bash
python3 - <<'EOF'
import json, shutil

def rewrite(path, skills, notes, compact=True, name=None):
    d = json.load(open(path, encoding="utf-8"))
    d.pop("hesindion", None)
    if name: d["name"] = name
    p = d["pets"]["PET_1"]
    p["skills"] = skills
    prose = p["notes"].split("Kampfverhalten:", 1)[1].strip()
    p["notes"] = notes + "; Kampfverhalten: " + prose
    open(path, "w", encoding="utf-8").write(json.dumps(d, ensure_ascii=False, separators=(",", ":")))

OLD_SKILLS = "Sonderfertigkeiten: Mächtiger Schlag"
OLD_NOTES = "Angriffe: Tritt AT 15 TP 1W6+7 RW mittel, Biss AT 12 TP 1W6+2 RW kurz, Niederreiten AT 15 TP 2W6+6 RW mittel"

# 1. The UI problem fixture is today's UITestHero (old unlabelled text), before it is converted.
shutil.copy("Hesindion/Resources/UITestHero.json", "Hesindion/Resources/UITestHeroProblems.json")
# 2. The older export and the UI seed keep their values, in the new format.
rewrite("specs/heroes/Boronmir Siebenfeld von Greifenfurt.json", OLD_SKILLS, OLD_NOTES)
rewrite("Hesindion/Resources/UITestHero.json", OLD_SKILLS, OLD_NOTES)
# 3. The 2026-09-24 export is the Optolith round trip, under its own name.
src = json.load(open("specs/heroes/Boronmir Formattest_edit.json", encoding="utf-8"))
src["name"] = "Boronmir Siebenfeld von Greifenfurt"
open("specs/heroes/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json", "w", encoding="utf-8").write(
    json.dumps(src, ensure_ascii=False, separators=(",", ":")))
EOF
git rm -q Hesindion/Resources/UITestHeroCompanions.json
```

Check:

```bash
python3 - <<'EOF'
import json
for f in ["specs/heroes/Boronmir Siebenfeld von Greifenfurt.json",
          "specs/heroes/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json",
          "Hesindion/Resources/UITestHero.json", "Hesindion/Resources/UITestHeroProblems.json"]:
    d = json.load(open(f, encoding="utf-8")); p = d["pets"]["PET_1"]
    print(f.split("/")[-1], "|", d["name"], "|", "hesindion" in d, "|", p["skills"][:40], "|", p["notes"][:50])
EOF
```

Expected: no file has `hesindion`; `UITestHeroProblems.json` has `skills` = `Mächtiger Schlag` and notes starting `Tritt: AT 15`; the other three have labelled text; the hero names are unchanged (`… (2026-09-24)` for the older file, without the date for the 2026-09-24 file — that swap is how the files were named before this change).

- [ ] **Step 2: Write the failing import tests**

Create `HesindionTests/PetImportTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import Hesindion

/// A plain Optolith export's pet fields reach `Pet` (issue #49).
@MainActor
struct PetImportTests {

    private func sample(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("specs/heroes/\(name).json")
    }

    private var current: URL { sample("Boronmir Siebenfeld von Greifenfurt (2026-09-24)") }
    private var older: URL { sample("Boronmir Siebenfeld von Greifenfurt") }

    private func kupperus(_ context: ModelContext) throws -> Pet {
        let hero = try #require(try context.fetch(FetchDescriptor<Hero>()).first)
        return try #require(hero.petsInOrder.first { $0.name == "Kupperus" })
    }

    /// `older` with Kupperus's text fields replaced, as Data.
    private func older(skills: String, notes: String) throws -> Data {
        var root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: older)) as? [String: Any])
        var pets = try #require(root["pets"] as? [String: Any])
        var pet = try #require(pets["PET_1"] as? [String: Any])
        pet["skills"] = skills
        pet["notes"] = notes
        pets["PET_1"] = pet
        root["pets"] = pets
        return try JSONSerialization.data(withJSONObject: root)
    }

    @Test func currentExportGivesTheSpecValues() throws {
        let context = ModelContext(try TestData.makeContainer())
        let result = try OptolithImportService().importHero(from: current, context: context)
        let pet = try kupperus(context)
        #expect(result.problems.isEmpty)
        #expect(pet.defense == 14)
        #expect(pet.armor == 0)
        #expect(pet.encumbrance == 0)
        #expect(pet.apTotal == 336)
        #expect(pet.apSpent == 336)
        #expect(pet.attacks.map(\.name) == ["Tritt", "Biss", "Niederreiten"])
        #expect(pet.attacks.first?.at == 19)
        #expect(pet.advantages.contains("Heldenwuchs"))
        #expect(pet.training == ["Reittier", "Kampftier"])
        #expect(pet.tricks == ["Aus", "Fass I", "Fass II", "Komm", "Sitz"])
        #expect(pet.hasMightyBlow)
        #expect(pet.notes.hasPrefix("Kampfverhalten:"))
        #expect(pet.importProblems.isEmpty)
    }

    @Test func olderExportKeepsItsBaseValues() throws {
        let context = ModelContext(try TestData.makeContainer())
        let result = try OptolithImportService().importHero(from: older, context: context)
        let pet = try kupperus(context)
        #expect(result.problems.isEmpty)
        #expect(pet.attacks == [
            PetAttack(name: "Tritt", at: 15, damage: "1W6+7", reach: "mittel"),
            PetAttack(name: "Biss", at: 12, damage: "1W6+2", reach: "kurz"),
            PetAttack(name: "Niederreiten", at: 15, damage: "2W6+6", reach: "mittel"),
        ])
        #expect(pet.defense == nil)
        #expect(pet.hasMightyBlow)
    }

    @Test func oldFormatExportStoresProblems() throws {
        let context = ModelContext(try TestData.makeContainer())
        let data = try older(skills: "Mächtiger Schlag",
                             notes: "Tritt: AT 15 TP 1W6+7 RW mittel; Kampfverhalten: besonnen.")
        let result = try OptolithImportService().importHero(from: data, context: context)
        let pet = try kupperus(context)
        #expect(result.problems.map(\.reason) == [.noLabel, .attackOutsideAngriffe])
        #expect(pet.importProblems == result.problems)
        #expect(!pet.hasMightyBlow)
        #expect(pet.attacks.map(\.name) == ["Niederreiten"])
    }

    @Test func cleanReimportClearsProblems() throws {
        let context = ModelContext(try TestData.makeContainer())
        try OptolithImportService().importHero(from: try older(skills: "Mächtiger Schlag", notes: ""), context: context)
        #expect(try !kupperus(context).importProblems.isEmpty)
        let again = try OptolithImportService().importHero(from: older, context: context)
        #expect(again == .updated(heroName: "Boronmir Siebenfeld von Greifenfurt (2026-09-24)"))
        #expect(try kupperus(context).importProblems.isEmpty)
    }

    @Test func mightyBlowFromAnAbilityWithANote() throws {
        let context = ModelContext(try TestData.makeContainer())
        try OptolithImportService().importHero(
            from: try older(skills: "Sonderfertigkeiten: Mächtiger Schlag (-4 auf Gegner Kraftakt)", notes: ""),
            context: context)
        #expect(try kupperus(context).hasMightyBlow)
    }

    @Test func aHesindionBlockIsIgnored() throws {
        var root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: older)) as? [String: Any])
        root["hesindion"] = ["schemaVersion": 1, "pets": ["PET_1": ["name": "Kupperus", "values": ["vw": 99]]]]
        let context = ModelContext(try TestData.makeContainer())
        try OptolithImportService().importHero(from: try JSONSerialization.data(withJSONObject: root), context: context)
        #expect(try kupperus(context).defense == nil)
    }

    /// Was `CompanionImportTests.mountedChargeUsesTheCompanionGS`: the mount's GS is Optolith's `mov`.
    @Test func mountGSIsTheExportsMov() throws {
        let context = ModelContext(try TestData.makeContainer())
        try OptolithImportService().importHero(from: current, context: context)
        #expect(try kupperus(context).speed == 15)
    }
}
```

Before deleting `HesindionTests/CompanionImportTests.swift`, read its `mountedChargeUsesTheCompanionGS` test (line 73). If it asserts more than the GS (for example a Sturmangriff TP), move that assertion into `mountGSIsTheExportsMov` with the same expected value. Then delete the file and `HesindionUITests/CompanionReimportFlowTests.swift`:

```bash
git rm -q HesindionTests/CompanionImportTests.swift HesindionUITests/CompanionReimportFlowTests.swift
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `make test-only ONLY=HesindionTests/PetImportTests`
Expected: build FAIL (`HeroImportResult` has no member `problems`, `Pet` has no member `importProblems`).

- [ ] **Step 4: Change `Pet`**

In `Hesindion/Models/Pet.swift`:
- Delete `struct PetPurchase` and its doc comment.
- Delete `var specialSkills: String = ""`, `var purchases: [PetPurchase] = []`, `hasCompanionData`, `adoptCompanionData(from:)`, the `specialSkills` init parameter and its assignment.
- Replace the comment above `defense` and add the two properties:

```swift
    // Companion data from Optolith's pet fields (issue #49, PetTextFormat): PA is VW, RS is
    // RS, the Sonderfertigkeiten and Notizen labels give the rest. nil / empty when absent.
    var defense: Int?
    var armor: Int?
    var encumbrance: Int?
    var advantages: [String] = []
    var disadvantages: [String] = []
    var abilities: [String] = []
    var training: [String] = []
    var tricks: [String] = []
    var apTotal: Int?
    var apSpent: Int?
    /// What the last import could not read; a clean re-import clears it.
    var importProblems: [PetImportProblem] = []

    /// An ability item counts by its name, without its note.
    var hasMightyBlow: Bool {
        abilities.contains { PetTextFormat.itemName($0) == "Mächtiger Schlag" }
    }
```

- [ ] **Step 5: Change the import service**

In `Hesindion/Services/OptolithImportService.swift`:

1. Delete the `companionBuildFile` case, its doc comment and its `errorDescription` branch, and the `if root["name"] == nil, root["schemaVersion"] != nil …` guard in `importHero(from: Data…)`.
2. Replace the `HeroImportResult` enum:

```swift
/// What an import did: added a new hero, or replaced the data of the hero
/// with the same name (a re-import), and what of the pets it could not read.
struct HeroImportResult: Equatable {
    enum Kind: Equatable { case created, updated }
    var kind: Kind
    var heroName: String
    var problems: [PetImportProblem] = []

    static func created(heroName: String) -> HeroImportResult { .init(kind: .created, heroName: heroName) }
    static func updated(heroName: String) -> HeroImportResult { .init(kind: .updated, heroName: heroName) }
}
```

3. Delete `companionConflicts(in:context:)`. Remove the `keepingCompanionDataFor keep: Set<String> = []` parameter from both `importHero` overloads and from `replaceHeroData`, and the `keepingCompanionDataFor: keep,` argument. Delete the loop `for pet in pets where keep.contains(pet.name) …`.
4. Change `let pets = parsePets(petsJSON, companions: CompanionData.parse(root: root))` to `let pets = parsePets(petsJSON)`.
5. Where the two branches set `result = .updated(heroName: heroName)` / `.created(heroName: heroName)`, keep them, and directly before the function's `return result` (after the save) set:

```swift
        result.problems = imported.petsInOrder.flatMap(\.importProblems)
```

Change `let result: HeroImportResult` to `var result: HeroImportResult`.

6. Replace `parsePets` and delete `parsePetAttacks`:

```swift
    private func parsePets(_ json: [String: Any]) -> [Pet] {
        json.compactMap { key, value -> Pet? in
            guard let pet = value as? [String: Any] else { return nil }
            let attributes = PetAttributes(
                mu: intFromAny(pet["cou"]) ?? 0,
                kl: intFromAny(pet["sgc"]) ?? 0,
                inValue: intFromAny(pet["int"]) ?? 0,
                ch: intFromAny(pet["cha"]) ?? 0,
                ff: intFromAny(pet["dex"]) ?? 0,
                ge: intFromAny(pet["agi"]) ?? 0,
                ko: intFromAny(pet["con"]) ?? 0,
                kk: intFromAny(pet["str"]) ?? 0
            )
            let text = PetTextFormat.parse(pet)
            let result = Pet(
                petId: key,
                name: pet["name"] as? String ?? "?",
                avatar: parseAvatar(pet["avatar"]),
                size: doubleFromAny(pet["size"]) ?? 0.0,
                type: pet["type"] as? String ?? "",
                attributes: attributes,
                lifeEnergy: intFromAny(pet["lp"]) ?? 0,
                spirit: intFromAny(pet["spi"]) ?? 0,
                toughness: intFromAny(pet["tou"]) ?? 0,
                initiative: pet["ini"] as? String ?? "",
                speed: intFromAny(pet["mov"]) ?? 0,
                attack: pet["attack"] as? String ?? "",
                damage: pet["dp"] as? String ?? "",
                reach: pet["reach"] as? String ?? "",
                actions: intFromAny(pet["actions"]) ?? 1,
                talents: pet["talents"] as? String ?? "",
                skills: pet["skills"] as? String ?? "",
                notes: text.notes,
                attacks: text.attacks
            )
            result.defense = text.defense
            result.armor = text.armor
            result.encumbrance = text.encumbrance
            result.advantages = text.advantages
            result.disadvantages = text.disadvantages
            result.abilities = text.abilities
            result.training = text.training
            result.tricks = text.tricks
            result.apTotal = text.apTotal
            result.apSpent = text.apSpent
            result.importProblems = text.problems
            return result
        }
    }
```

7. Delete `Hesindion/Services/CompanionData.swift`:

```bash
git rm -q Hesindion/Services/CompanionData.swift
```

- [ ] **Step 6: Change the readers**

`Hesindion/RulesEngine/PetSheetMapping.swift`: change `for name in pet.advantages {` to `for name in pet.advantages.map(PetTextFormat.itemName) {`, and in the doc comment change "(`Pet` has no breed field; #49 covers the import)" to "(`Pet` has no breed field)".

`Hesindion/Views/CombatAttackViews.swift`, the "Mount special skills note" block:

```swift
            // Mount abilities note
            if !mount.abilities.isEmpty {
                Text("\u{24D8} \(mount.abilities.joined(separator: ", "))")
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(combatAccent)
                    .padding(.top, 2)
            }
```

`Hesindion/Views/HeroDetailView.swift`:
- Replace `if pet.hasCompanionData { companionBlock(pet) }` with `companionBlock(pet)`.
- Delete the `if !pet.skills.isEmpty { FieldRow(label: "skills", value: pet.skills) }` block (the lists replace it).
- In `petCombatBlock` replace the `else if pet.hasCompanionData { VW }` and the `if pet.hasCompanionData { RS, BE }` parts with:

```swift
            } else if let defense = pet.defense {
                petRow("VW", "\(defense)", valueId: "pet.defense.\(pet.name)")
            }
            if let armor = pet.armor {
                petRow("RS", "\(armor)", valueId: "pet.armor.\(pet.name)")
            }
            if let encumbrance = pet.encumbrance {
                petRow("BE", "\(encumbrance)", valueId: "pet.encumbrance.\(pet.name)")
            }
```

- In `companionBlock`, change the doc comment to `/// The pet's AP and lists, from Optolith's pet fields (issue #49).`, guard the AP row with `if let total = pet.apTotal { petRow("AP", "\(pet.apSpent ?? 0) / \(total)", valueId: "pet.ap.\(pet.name)") }`, and add after the advantages row:

```swift
        if !pet.disadvantages.isEmpty {
            FieldRow(label: "petDisadvantages", value: pet.disadvantages.joined(separator: ", "))
        }
```

`Hesindion/Theme/Strings.swift`: add `"petDisadvantages": "Disadvantages",` after `"petAdvantages"` in the English table and `"petDisadvantages": "Nachteile",` in the German table. Delete the five `companion.reimport.*` keys in both tables.

- [ ] **Step 7: Change `HeroListView` and `UITestSeed`**

`Hesindion/Views/HeroListView.swift`:
- Delete `struct PendingReimport`, `@State private var pendingReimport`, the whole `.overlay { if let name = pendingReimport?.remaining.first { … } }` block, and `answerReimport(keep:)`.
- `handleURL` becomes:

```swift
    private func handleURL(_ url: URL) {
        do {
            importResult = try OptolithImportService().importHero(from: url, context: modelContext)
        } catch {
            showError(error.localizedDescription)
        }
    }
```

- `importResultTitle` and `importResultMessage` switch on `importResult?.kind`:

```swift
    private var importResultTitle: String {
        importResult?.kind == .updated ? L("import.updated.title") : L("import.created.title")
    }

    private var importResultMessage: String {
        guard let importResult else { return "" }
        let key = importResult.kind == .updated ? "import.updated.message" : "import.created.message"
        return String(format: L(key), importResult.heroName)
    }
```

`Hesindion/UITestSeed.swift`:
- Delete `fixtureArgument` and its doc comment; in `populate` use `"UITestHero"` directly:

```swift
        guard let url = Bundle.main.url(forResource: "UITestHero", withExtension: "json") else {
            fatalError("UITestSeed: UITestHero.json is missing from the app bundle")
        }
```

- Change the `reimportArgument` doc comment to: `/// \`-uitest-reimport UITestHeroProblems\` makes \`HeroListView\` import that bundled JSON on appear, through the same path as the file picker, so the import's problem modal can be driven without the system document browser (issue #49).`

- [ ] **Step 8: Put the two migration asserts back**

In `HesindionTests/SchemaV7MigrationTests.swift`, remove the `// Task 4:` comment marks from the `disadvantages` and `importProblems` asserts.

- [ ] **Step 9: Build and run the new and the touched tests**

Run, one at a time:
- `make test-only ONLY=HesindionTests/PetTextFormatTests` — Expected: PASS.
- `make test-only ONLY=HesindionTests/PetImportTests` — Expected: PASS.
- `make test-only ONLY=HesindionTests/SchemaV7MigrationTests` — Expected: PASS.
- `make test-only ONLY=HesindionTests/HeroImportTests` — Expected: PASS (`importBoronmirFromOptolith` is a known flake; rerun once if it fails on `combatTechniques.count == 0`).

- [ ] **Step 10: Run the whole unit and snapshot target**

Run: `make test-ui`
Expected: PASS, apart from the four known flakes in AGENTS.md. If a snapshot fails, open the failure image under `/tmp` (the path is in the log) and compare it with the reference. A change in the pets part of the hero sheet (the raw Sonderfertigkeiten row is gone, "Fähigkeiten: Mächtiger Schlag" shows instead) is expected: re-record that one class with `make test-ui-record-only ONLY=HesindionTests/<Class>` and look at the new image before you commit it. Any other difference is a bug: fix it, do not re-record.

- [ ] **Step 11: Commit**

```bash
git add -A Hesindion HesindionTests HesindionUITests specs/heroes
git reset -q "specs/heroes/Boronmir Formattest.json" "specs/heroes/Boronmir Formattest_edit.json"
git commit -m "feat: the import reads a companion from Optolith's pet fields; the hesindion block and the re-import question are gone (#49)"
```

---

### Task 5: The player sees the problems

**Files:**
- Create: `Hesindion/Views/ImportProblemsModal.swift`
- Modify: `Hesindion/Views/HeroListView.swift`, `Hesindion/Views/HeroDetailView.swift`, `Hesindion/Theme/Strings.swift`
- Test: `HesindionTests/Snapshots/ImportProblemsSnapshotTests.swift`, `HesindionUITests/ImportProblemsFlowTests.swift`

**Interfaces:**
- Consumes: `HeroImportResult.problems`, `Pet.importProblems`, `PetImportProblem` (Tasks 2, 4).
- Produces: `extension PetImportProblem { var message: String; var fieldMessage: String }`, `struct ImportProblemsModal: View { let title: String; let message: String; let problems: [PetImportProblem]; let onDismiss: () -> Void }`, `struct PetImportProblemRow: View { let problem: PetImportProblem; let identifier: String }`. Identifiers `import.problems.modal`, `import.problems.ok`, `pet.problem.<pet>.<index>`.

- [ ] **Step 1: Add the strings**

In the English table of `Strings.swift`, next to `import.updated.message`:

```swift
        "import.problems.intro":     "Not everything in the pet fields could be read. The rest was imported. Fix these parts in Optolith and import again:",
        "pet.problem.noLabel":       "no label (Vorteile:, Nachteile:, Sonderfertigkeiten:, Ausbildung:, Tricks:)",
        "pet.problem.unknownLabel":  "unknown label",
        "pet.problem.badAttack":     "not an attack (Name AT 15 TP 1W6+2 RW kurz)",
        "pet.problem.badBE":         "BE is not a number",
        "pet.problem.badTalentValue": "the value is not a number",
        "pet.problem.attackMismatch": "differs from the same attack under Angriffe",
        "pet.problem.attackOutsideAngriffe": "attack outside Angriffe:, not read",
```

In the German table:

```swift
        "import.problems.intro":     "Nicht alles in den Begleiterfeldern war lesbar. Der Rest ist importiert. Korrigiere diese Stellen in Optolith und importiere erneut:",
        "pet.problem.noLabel":       "ohne Bezeichnung (Vorteile:, Nachteile:, Sonderfertigkeiten:, Ausbildung:, Tricks:)",
        "pet.problem.unknownLabel":  "unbekannte Bezeichnung",
        "pet.problem.badAttack":     "kein Angriff (Name AT 15 TP 1W6+2 RW kurz)",
        "pet.problem.badBE":         "BE ist keine Zahl",
        "pet.problem.badTalentValue": "der Wert ist keine Zahl",
        "pet.problem.attackMismatch": "weicht vom gleichen Angriff unter Angriffe ab",
        "pet.problem.attackOutsideAngriffe": "Angriff ausserhalb von Angriffe:, nicht gelesen",
```

- [ ] **Step 2: Write the failing snapshot test**

Create `HesindionTests/Snapshots/ImportProblemsSnapshotTests.swift`:

```swift
import XCTest
import SnapshotTesting
import SwiftUI
@testable import Hesindion

/// The import's problem modal and the companion sheet's warning row (issue #49).
final class ImportProblemsSnapshotTests: XCTestCase {

    private let problems = [
        PetImportProblem(pet: "Kupperus", field: .sonderfertigkeiten, text: "Mächtiger Schlag", reason: .noLabel),
        PetImportProblem(pet: "Kupperus", field: .notizen, text: "Biss AT 156TP 1W6+3 RW kurz", reason: .badAttack),
    ]

    @MainActor
    func testModal() {
        let view = ImportProblemsModal(title: "Held aktualisiert",
                                       message: "Boronmir wurde neu importiert.",
                                       problems: problems, onDismiss: {})
        assertAllVariants(of: view, named: "importProblems")
    }

    @MainActor
    func testRow() {
        let view = PetImportProblemRow(problem: problems[1], identifier: "pet.problem.Kupperus.0")
            .frame(width: 400)
        assertAllVariants(of: view, named: "petProblemRow")
    }

    func testMessage() {
        XCTAssertEqual(problems[1].fieldMessage,
                       "Notizen: „Biss AT 156TP 1W6+3 RW kurz\" – \(L("pet.problem.badAttack"))")
        XCTAssertEqual(problems[1].message, "Kupperus · " + problems[1].fieldMessage)
    }
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `make test-only ONLY=HesindionTests/ImportProblemsSnapshotTests`
Expected: build FAIL ("cannot find 'ImportProblemsModal' in scope").

- [ ] **Step 4: Write the views**

Create `Hesindion/Views/ImportProblemsModal.swift`:

```swift
import SwiftUI

extension PetImportProblem {
    /// "Notizen: „Biss AT 156TP …" – kein Angriff (…)", for a row under the pet's own name.
    var fieldMessage: String {
        "\(field.rawValue): „\(text)\" – \(L("pet.problem.\(reason.rawValue)"))"
    }

    /// The same with the pet's name first, for the import's list of all pets.
    var message: String { "\(pet) · \(fieldMessage)" }
}

/// The import's result when a pet field could not be read in full (issue #49): what the import
/// did, then each problem. Shown instead of the plain result alert.
struct ImportProblemsModal: View {
    let title: String
    let message: String
    let problems: [PetImportProblem]
    let onDismiss: () -> Void

    var body: some View {
        DSAModal(title: title, accent: .groupEquipment, onClose: onDismiss, scrolls: true) {
            Text(message)
                .font(.dsaBody(.subheadline))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L("import.problems.intro"))
                .font(.dsaBody(.subheadline))
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(problems.enumerated()), id: \.offset) { _, problem in
                Label(problem.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.dsaBody(.caption))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            DSAModalButton(title: L("ok"), accent: .groupEquipment, identifier: "import.problems.ok") {
                onDismiss()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("import.problems.modal")
    }
}

/// One problem of the last import, at the top of a pet on the companion sheet.
struct PetImportProblemRow: View {
    let problem: PetImportProblem
    let identifier: String

    var body: some View {
        Label(problem.fieldMessage, systemImage: "exclamationmark.triangle.fill")
            .font(.dsaBody(.caption2))
            .foregroundStyle(Color.groupEquipment)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .accessibilityIdentifier(identifier)
    }
}
```

If `DSAModal`'s initializer does not accept `onClose:` and `scrolls:` in this order, check `Hesindion/Theme/DSAModal.swift:13-20` (the memberwise order is `title, accent, onScrimTap, onClose, scrolls, content`) and pass them in that order.

- [ ] **Step 5: Run the snapshot test, record, and look at the images**

Run: `make test-ui-record-only ONLY=HesindionTests/ImportProblemsSnapshotTests`, then `make test-only ONLY=HesindionTests/ImportProblemsSnapshotTests`.
Expected: the second run PASSES. Open two of the recorded PNGs under `HesindionTests/Snapshots/__Snapshots__/ImportProblemsSnapshotTests/` (one light default, one dark accXXXL) and check that the text wraps and nothing is cut off.

- [ ] **Step 6: Show the modal and the rows**

`Hesindion/Views/HeroListView.swift`:
- The result alert binding shows the alert only without problems:

```swift
            isPresented: Binding(
                get: { importResult != nil && importResult?.problems.isEmpty == true },
                set: { if !$0 { importResult = nil } }
            )
```

- Add an overlay where the re-import overlay was:

```swift
        .overlay {
            if let result = importResult, !result.problems.isEmpty {
                ImportProblemsModal(title: importResultTitle, message: importResultMessage,
                                    problems: result.problems) { importResult = nil }
            }
        }
```

`Hesindion/Views/HeroDetailView.swift`, in the pets section, directly before `if pet === hero.mount, let v = MountValues.of(pet) {`:

```swift
                        ForEach(Array(pet.importProblems.enumerated()), id: \.offset) { index, problem in
                            PetImportProblemRow(problem: problem, identifier: "pet.problem.\(pet.name).\(index)")
                        }
```

- [ ] **Step 7: Write the UI test**

Create `HesindionUITests/ImportProblemsFlowTests.swift`:

```swift
import XCTest

/// An export whose pet fields are partly unreadable imports, and says what it could not read
/// (issue #49). The seed is `UITestHero`; `-uitest-reimport UITestHeroProblems` re-imports the
/// same hero with the old unlabelled pet text through the file picker's path.
final class ImportProblemsFlowTests: XCTestCase {

    @MainActor
    func testUnreadablePetTextShowsTheProblemsAndTheSheetKeepsThem() {
        let app = XCUIApplication()
        app.launchArguments = [UITest.seedArgument, "debug", "load_default",
                               "-uitest-reimport", "UITestHeroProblems"]
        app.launch()

        let ok = app.buttons["import.problems.ok"]
        XCTAssertTrue(ok.waitForExistence(timeout: UITest.timeout))
        XCTAssertTrue(app.otherElements["import.problems.modal"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Sonderfertigkeiten")).firstMatch.exists)
        ok.tap()
        XCTAssertFalse(ok.waitForExistence(timeout: UITest.probeTimeout))

        let row = app.staticTexts["pet.problem.Kupperus.0"]
        for _ in 0..<12 where !row.exists { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: UITest.timeout))
    }
}
```

- [ ] **Step 8: Run the UI test**

Run: `make test-only ONLY=HesindionUITests/ImportProblemsFlowTests`
Expected: PASS. If the modal's texts are not found as `staticTexts`, check with `print(app.debugDescription)` how the `Label` exposes itself and adjust the query, not the view.

- [ ] **Step 9: Commit**

```bash
git add Hesindion HesindionTests HesindionUITests
git commit -m "feat: the import lists what it could not read in a pet's fields, and the companion sheet keeps the list (#49)"
```

---

### Task 6: The companion tool goes

**Files:**
- Delete: `scripts/companions/`, `specs/data/companion-block.schema.json`, `specs/heroes/Boronmir Siebenfeld von Greifenfurt (2026-09-24).companions.json`, `specs/heroes/Boronmir Formattest.json`, `specs/heroes/Boronmir Formattest_edit.json`
- Modify: `Makefile:30, 108-120, 154-164`, `scripts/rulec/hero_sheet_fixtures.py:1,16`

- [ ] **Step 1: Delete the files**

```bash
git rm -rq scripts/companions specs/data/companion-block.schema.json \
  "specs/heroes/Boronmir Siebenfeld von Greifenfurt (2026-09-24).companions.json"
rm "specs/heroes/Boronmir Formattest.json" "specs/heroes/Boronmir Formattest_edit.json"
grep -rn "companion-block.schema\|scripts/companions\|companions.json" --exclude-dir=.git . | grep -v "docs/plans/2026-09-24\|docs/adr/0016\|CHANGELOG.md" 
```

Expected for the grep: only the Makefile and `hero_sheet_fixtures.py` lines that Steps 2–3 change.

- [ ] **Step 2: Change the Makefile**

- Remove `companions test-companions` from the `.PHONY` line.
- Delete the block from `# Companion builds (docs/plans/2026-09-24-companion-data-design.md): check` down to and including the `test-companions:` recipe line.
- In both `share-heros` recipes, change `find "$(SAMPLE_HEROES)" -maxdepth 1 -name '*.json' ! -name '*.companions.json' -exec cp {} …` to `find "$(SAMPLE_HEROES)" -maxdepth 1 -name '*.json' -exec cp {} …`.

- [ ] **Step 3: Change `hero_sheet_fixtures.py`**

Line 1: change `(specs/heroes/*.json, less the *.companions.json build` so the docstring reads `(specs/heroes/*.json` and drop the rest of that clause up to the closing parenthesis. Line 16: `for p in sorted(heroes.glob("*.json")):`.

- [ ] **Step 4: Regenerate and check the hero-sheet fixtures**

Run: `make hero-sheet-fixtures && git status --short HesindionTests/Fixtures/HeroSheets`
Expected: no change (hero.py does not read pets, and the converted exports differ only in pet fields and in six empty `activatable` entries). If a fixture changes, read the diff: an `activatable` key with an empty list must not change a sheet value. A different value is a bug in the fixture conversion.

- [ ] **Step 5: Run the Python tests that read `specs/heroes`**

Run: `make test-rulec`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A Makefile scripts specs
git commit -m "chore: make companions, its build file and the block schema are gone (#49)"
```

---

### Task 7: Docs

**Files:**
- Create: `docs/adr/0021-companion-data-in-optolith-pet-fields.md`, `docs/companion-format.md`
- Modify: `docs/adr/0016-companion-data-in-optolith-export.md`, `docs/plans/2026-09-24-companion-data-design.md`, `AGENTS.md`, `CHANGELOG.md`

- [ ] **Step 1: Write ADR-0021**

```markdown
# ADR-0021: Companion Data Lives in Optolith's Pet Fields

## Status

Accepted, 2026-10-03 (issue #49). Supersedes ADR-0016.

## Context

ADR-0016 put a companion's data into a `hesindion` block that `make companions` wrote into the
Optolith export from a hand-written build file. Optolith does not know the block, so a pet edited
in Optolith and exported again lost it, and every change took four steps. Optolith's pet text
fields are single-line inputs, so a pasted line break is lost.

## Decision

The player edits the companion in Optolith's pet editor only. PA is VW, RS is RS, and the
Sonderfertigkeiten and Notizen fields hold labelled segments (`Vorteile: …; Tricks: …`,
`Angriffe: …; BE: 0`) on one line. `PetTextFormat` parses them at import. A part that does not
parse is not imported; the import lists it in a modal and the companion sheet keeps the list
until a clean re-import. The purchase list and the AP check against Kat C are dropped; the app
shows Optolith's own AP. The format is `docs/companion-format.md`; the design is
`docs/plans/2026-10-03-companion-text-format-design.md`.

## Considered Alternatives

- **Keep the build file as an optional audit tool** that writes into Optolith's fields. Rejected:
  two sources again, and the player's Optolith edits would be overwritten on the next run.
- **One `Hesindion:` block in Notizen.** Rejected: one long single-line field to edit, and PA/RS
  typed twice.
- **A kind prefix per item** (`Vorteil Geduldig, Trick Aus`). Rejected: more typing per item.
- **Read the old formats as a fallback.** Rejected: three data paths in the code and in every
  test, for one player's exports that are converted in the same change.

## Consequences

- No step between Optolith and the app. An Optolith round trip keeps the data (verified
  2026-10-03).
- A typo no longer drops data silently: the player sees the field, the text and the reason.
- An export with a `hesindion` block imports, but the block is ignored.
- `make companions`, `make test-companions`, the build file and the re-import question are gone.
```

- [ ] **Step 2: Mark ADR-0016 and the old design as superseded**

In `docs/adr/0016-companion-data-in-optolith-export.md`, add as the first line under `## Status`: `Superseded by ADR-0021, 2026-10-03 (issue #49).` In `docs/plans/2026-09-24-companion-data-design.md`, add under the title: `**Superseded 2026-10-03** by docs/plans/2026-10-03-companion-text-format-design.md (issue #49).`

- [ ] **Step 3: Write the player page**

Create `docs/companion-format.md` with: a one-paragraph intro ("Edit a companion in Optolith's pet editor; Hesindion reads these fields at import"); the table of fields from spec §3.2; the general rules from spec §3.1; the attack grammar from §3.3; the list of problems from §3.4 (6 kinds) with the German message each shows; and the Kupperus example from §3.5 as copy-paste lines in code blocks. Write it in English with the German labels as they appear in Optolith.

- [ ] **Step 4: Change AGENTS.md**

- Delete the two lines `make companions HERO=…` and `make test-companions …` in "Build & Run".
- In the UI-test seed paragraph, add after the `-uitest-mount-le` sentence: "A further argument, `-uitest-reimport <bundled JSON>`, makes `HeroListView` import that file on appear through the file picker's path; `ImportProblemsFlowTests` uses it with `UITestHeroProblems.json`, the seed hero with the old unlabelled pet text (issue #49)."
- In the identifier list, add `import.problems.modal`, `import.problems.ok` (the import's problem modal) and `pet.problem.<name>.<index>` (a problem row on the companion sheet), issue #49.
- Add one line under "Architecture" after the SwiftData bullets: "- **Companion data** comes from Optolith's pet fields in a labelled single-line format (`PetTextFormat`, ADR-0021, `docs/companion-format.md`)."

- [ ] **Step 5: Change CHANGELOG.md**

Under `## [Unreleased]`:
- In `### Changed`, add first: "**A companion's data comes from Optolith's own pet fields** (issue #49, ADR-0021). PA is VW, RS is RS, and the Sonderfertigkeiten and Notizen fields hold labelled segments on one line (`Vorteile: …; Ausbildung: …; Tricks: …`, `Angriffe: Tritt AT 19 TP 1W6+8 RW mittel, …; BE: 0`), which survive an Optolith export and re-import. A plain Optolith export imports directly; `docs/companion-format.md` has the format. Disadvantages (`Nachteile:`) are new on the companion sheet."
- Add a `### Removed` section (create it after `### Changed` if missing): "The `hesindion` block, `make companions`, `make test-companions`, the `.companions.json` build file, the purchase list with its Kat C check, and the re-import question (issue #49). An export with a block still imports; the block is ignored."
- Add a `### Fixed` line: "An attack, an ability or a value in a pet field that the import cannot read is reported after the import and on the companion sheet, instead of being dropped (issue #49)."
- Rewrite the two older `### Added` bullets about companion data and the re-import question: append "(replaced by issue #49, see Changed)" to each, without deleting their text.

- [ ] **Step 6: Commit**

```bash
git add docs AGENTS.md CHANGELOG.md
git commit -m "docs: ADR-0021, the companion format page, and the docs that named make companions (#49)"
```

---

### Task 8: Full verification

- [ ] **Step 1: Unit and snapshot tests**

Run: `make test-ui`
Expected: PASS apart from the four known flakes in AGENTS.md.

- [ ] **Step 2: The mount and companion UI tests**

Run, one at a time:
- `make test-only ONLY=HesindionUITests/ImportProblemsFlowTests`
- `make test-only ONLY=HesindionUITests/SheetBreakdownTests`
- `make test-only ONLY=HesindionUITests/MightyBlowFollowUpFlowTests`
- `make test-only ONLY=HesindionUITests/ActionPerRoundFlowTests`

Expected: PASS.

- [ ] **Step 3: Python tests**

Run: `make test-rulec && make test-rules-review`
Expected: PASS.

- [ ] **Step 4: See it in the app**

Run: `make run`, import `specs/heroes/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json` through the file picker, open the companion sheet. Expected: Kupperus shows VW 14, RS 0, BE 0, AP 336 / 336, the Nachteile row is absent, the Tricks row ends with "Sitz", no problem rows.

- [ ] **Step 5: Commit any re-recorded baselines** (only if Step 1 needed a re-record that you checked image by image)

```bash
git add HesindionTests/Snapshots/__Snapshots__
git commit -m "test: snapshot baselines for the companion sheet without the raw Sonderfertigkeiten row (#49)"
```
