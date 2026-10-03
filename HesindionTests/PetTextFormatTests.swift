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
