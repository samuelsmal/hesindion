import XCTest
@testable import Hesindion

/// The optional "Kritische Erfolge" tables (Aventurisches Kompendium 2, p. 100ff).
///
/// Rules references:
/// - https://dsa.ulisses-regelwiki.de/opt_Kritische_Erfolge_beim_Angriff.html
/// - https://dsa.ulisses-regelwiki.de/opt_Kritische_Erfolge_bei_Verteidigung_im_Nahkampf.html
/// - https://dsa.ulisses-regelwiki.de/opt_Kritischer_Erfolg_bei_Verteidigung_im_Fernkampf.html
///
/// Three 2W6 tables with a 1W20 refinement under each of their eleven categories
/// is 33 hand-transcribed sub-tables. Spot-checking them would prove nothing, so
/// most of what follows is structural: coverage, contiguity, and the invariants
/// the rules impose on whole tables at once. That is the only practical way to
/// proofread data of this shape.
final class CriticalSuccessTableTests: XCTestCase {

    // MARK: - 2W6 coverage

    /// 2W6 can only produce 2...12, and every one of those must resolve.
    func testEveryTableCoversTwoThroughTwelve() {
        for table in CriticalSuccessTableType.allCases {
            let rolls = CriticalSuccessTable.categories(for: table).map(\.roll)
            XCTAssertEqual(rolls, Array(2...12), "\(table.rawValue) is not a complete 2W6 table")
        }
    }

    func testEveryCategoryHasATitleAndAnEffect() {
        for table in CriticalSuccessTableType.allCases {
            for category in CriticalSuccessTable.categories(for: table) {
                XCTAssertFalse(category.title.isEmpty, "\(table.rawValue) \(category.roll): no title")
                XCTAssertFalse(category.effect.isEmpty, "\(table.rawValue) \(category.roll): no effect")
                XCTAssertNotEqual(category.title, "—", "\(table.rawValue) \(category.roll): placeholder")
            }
        }
    }

    /// A roll outside 2...12 cannot happen with two dice, but clamping beats
    /// returning the "—" placeholder if a caller ever miscounts.
    func testOutOfRangeRollsClamp() {
        for table in CriticalSuccessTableType.allCases {
            XCTAssertEqual(CriticalSuccessTable.category(1, table: table).roll, 2)
            XCTAssertEqual(CriticalSuccessTable.category(0, table: table).roll, 2)
            XCTAssertEqual(CriticalSuccessTable.category(13, table: table).roll, 12)
            XCTAssertEqual(CriticalSuccessTable.category(99, table: table).roll, 12)
        }
    }

    // MARK: - 1W20 refinements (Fokusregel)

    /// Every category's bands must tile 1...20 exactly: contiguous, ascending, no
    /// gap and no overlap. The published `Schwerer betäubender Treffer` table
    /// skips 15-18 outright — `CriticalSuccessRefinements` fills it with a reroll
    /// and says why, and this test is what would catch the next such hole.
    func testRefinementsTileOneThroughTwenty() {
        for table in CriticalSuccessTableType.allCases {
            for category in CriticalSuccessTable.categories(for: table) {
                let label = "\(table.rawValue) \(category.roll) (\(category.title))"
                XCTAssertFalse(category.refinements.isEmpty, "\(label): no Fokusregel breakdown")

                var expectedNext = 1
                for band in category.refinements {
                    XCTAssertEqual(band.range.lowerBound, expectedNext,
                                   "\(label): band \(band.range) does not start at \(expectedNext)")
                    expectedNext = band.range.upperBound + 1
                }
                XCTAssertEqual(expectedNext, 21, "\(label): bands stop at \(expectedNext - 1), not 20")
            }
        }
    }

    /// Every 1W20 resolves to exactly one band, so the view never has to handle a
    /// `nil` refinement it cannot explain.
    func testEveryDieResolves() {
        for table in CriticalSuccessTableType.allCases {
            for category in CriticalSuccessTable.categories(for: table) {
                for roll in 1...20 {
                    XCTAssertNotNil(
                        CriticalSuccessTable.refinement(roll, in: category),
                        "\(table.rawValue) \(category.roll): 1W20 \(roll) resolves to nothing"
                    )
                }
            }
        }
    }

    /// "Nochmal würfeln" is `effect == nil`, never an empty or placeholder string —
    /// the view branches on `isReroll` and would otherwise print a blank box.
    func testRerollBandsAreNilAndNothingElseIsBlank() {
        for table in CriticalSuccessTableType.allCases {
            for category in CriticalSuccessTable.categories(for: table) {
                for band in category.refinements {
                    if band.isReroll {
                        XCTAssertNil(band.effect)
                    } else {
                        XCTAssertFalse(band.effect?.isEmpty ?? true,
                                       "\(table.rawValue) \(category.roll) \(band.range): blank effect")
                    }
                }
            }
        }
    }

    /// A reroll band is a dead end unless something else on the table can answer,
    /// so no category may be nothing but rerolls.
    func testNoCategoryIsAllRerolls() {
        for table in CriticalSuccessTableType.allCases {
            for category in CriticalSuccessTable.categories(for: table) {
                XCTAssertTrue(category.refinements.contains { !$0.isReroll },
                              "\(table.rawValue) \(category.roll): every band rerolls")
            }
        }
    }

    // MARK: - Damage

    /// The rule replaces the flat doubling, so the Angriff table is the only one
    /// that touches TP at all. A defensive critical turns an attack aside; it
    /// cannot change the damage of the blow that was stopped.
    func testOnlyTheAttackTableChangesDamage() {
        for table in [CriticalSuccessTableType.verteidigungNahkampf, .verteidigungFernkampf] {
            for category in CriticalSuccessTable.categories(for: table) {
                XCTAssertEqual(category.damage, .unchanged,
                               "\(table.rawValue) \(category.roll) changes TP")
                for band in category.refinements {
                    XCTAssertEqual(band.damage, .unchanged,
                                   "\(table.rawValue) \(category.roll) \(band.range) changes TP")
                }
            }
        }
    }

    /// The published 2W6 column, read straight off the page.
    func testAttackTableDamageMatchesThePublishedColumn() {
        let expected: [Int: CriticalDamage] = [
            2:  .bonus(2),        // Leichter Treffer
            3:  .bonus(2),        // Leicht betäubender Treffer
            4:  .oneAndAHalf,     // Mittelschwerer Treffer
            5:  .oneAndAHalf,
            6:  .oneAndAHalf,
            7:  .double,          // Schwerer Treffer
            8:  .double,
            9:  .double,
            10: .unchanged,       // Aus dem Gleichgewicht gebracht — no TP change
            11: .unchanged,       // Gehirnerschütterung — no TP change
            12: .triple,          // Extrem schwerer Treffer
        ]
        for (roll, damage) in expected {
            XCTAssertEqual(
                CriticalSuccessTable.category(roll, table: .angriff).damage, damage,
                "Angriff \(roll)"
            )
        }
    }

    func testDamageApplication() {
        XCTAssertEqual(CriticalDamage.unchanged.apply(to: 13), 13)
        XCTAssertEqual(CriticalDamage.bonus(2).apply(to: 13), 15)
        XCTAssertEqual(CriticalDamage.double.apply(to: 13), 26)
        XCTAssertEqual(CriticalDamage.triple.apply(to: 13), 39)
    }

    /// The catalog's `multiply` factor, as `DamageModifiers.multiplier` reads it.
    /// A factor with no case here is a catalog author's mistake, not something
    /// this initializer should paper over with a guess.
    func testCriticalDamageFromFactor() {
        XCTAssertEqual(CriticalDamage(factor: 1), .unchanged)
        XCTAssertEqual(CriticalDamage(factor: 1.5), .oneAndAHalf)
        XCTAssertEqual(CriticalDamage(factor: 2), .double)
        XCTAssertEqual(CriticalDamage(factor: 3), .triple)
        XCTAssertNil(CriticalDamage(factor: 2.5))
        XCTAssertNil(CriticalDamage(factor: 0))
    }

    /// "veranderthalbfacht (aufgerundet)" — and DSA rounds up where the rules do
    /// not say otherwise anyway (ADR-0006). The odd cases are the ones worth
    /// pinning: 13 → 19.5 → 20, not 19.
    func testOneAndAHalfRoundsUp() {
        XCTAssertEqual(CriticalDamage.oneAndAHalf.apply(to: 13), 20)
        XCTAssertEqual(CriticalDamage.oneAndAHalf.apply(to: 11), 17)
        XCTAssertEqual(CriticalDamage.oneAndAHalf.apply(to: 1), 2)
        // Even bases are exact and must not be nudged.
        XCTAssertEqual(CriticalDamage.oneAndAHalf.apply(to: 12), 18)
        XCTAssertEqual(CriticalDamage.oneAndAHalf.apply(to: 4), 6)
        XCTAssertEqual(CriticalDamage.oneAndAHalf.apply(to: 0), 0)
    }

    /// `.unchanged` is the only case with no label, because it is the only one the
    /// damage line has nothing to say about.
    func testOnlyUnchangedHasNoLabel() {
        XCTAssertNil(CriticalDamage.unchanged.label)
        for damage in [CriticalDamage.bonus(3), .oneAndAHalf, .double, .triple] {
            XCTAssertNotNil(damage.label, "\(damage) has no label")
        }
    }

    // MARK: - Passierschlag

    /// "Die Ergebnisse ersetzen den Passierschlag des Helden […], es sei denn, ein
    /// Passierschlag wird als Ergebnis aufgeführt." On the melee table that is
    /// results 7 and up; a hero who rolls 2–6 has traded the free strike away.
    func testMeleeDefenceGrantsAPassierschlagFromSevenUp() {
        for category in CriticalSuccessTable.categories(for: .verteidigungNahkampf) {
            XCTAssertEqual(category.grantsPassierschlag, category.roll >= 7,
                           "Nahkampf \(category.roll) (\(category.title))")
        }
    }

    /// Neither the attack table nor the ranged-defence table hands out a
    /// Passierschlag — the attack already landed, and the ranged rule replaces a
    /// defence penalty, not a free strike.
    func testNoOtherTableGrantsAPassierschlag() {
        for table in [CriticalSuccessTableType.angriff, .verteidigungFernkampf] {
            for category in CriticalSuccessTable.categories(for: table) {
                XCTAssertFalse(category.grantsPassierschlag, "\(table.rawValue) \(category.roll)")
                for band in category.refinements {
                    XCTAssertFalse(band.grantsPassierschlag,
                                   "\(table.rawValue) \(category.roll) \(band.range)")
                }
            }
        }
    }

    /// The Fokusregel determines a category's result "genauer" — it cannot invent
    /// a Passierschlag the category never offered, or withdraw one it did. The
    /// view reads the refinement's flag in preference to the category's, so a
    /// mismatch would silently show or hide the button.
    func testRefinementsAgreeWithTheirCategoryOnThePassierschlag() {
        for table in CriticalSuccessTableType.allCases {
            for category in CriticalSuccessTable.categories(for: table) {
                for band in category.refinements where !band.isReroll {
                    XCTAssertEqual(
                        band.grantsPassierschlag, category.grantsPassierschlag,
                        "\(table.rawValue) \(category.roll) \(band.range) disagrees with its category"
                    )
                }
            }
        }
    }

    // MARK: - Wiring

    /// Each table is switched by its own Fokus-Regel, and no two share one — the
    /// hero settings screen would otherwise toggle two tables with one row.
    func testEachTableHasItsOwnFokusRule() {
        let rules = CriticalSuccessTableType.allCases.map(\.fokusRule)
        XCTAssertEqual(Set(rules).count, rules.count, "two tables share a Fokus-Regel")
        XCTAssertEqual(CriticalSuccessTableType.angriff.fokusRule, .kritischeErfolgeAngriff)
        XCTAssertEqual(CriticalSuccessTableType.verteidigungNahkampf.fokusRule, .kritischeErfolgeNahkampf)
        XCTAssertEqual(CriticalSuccessTableType.verteidigungFernkampf.fokusRule, .kritischeErfolgeFernkampf)
    }

    func testTableTitlesAndReplacementNotesAreLocalized() {
        for table in CriticalSuccessTableType.allCases {
            XCTAssertNotEqual(L(table.titleKey), table.titleKey)
            XCTAssertNotEqual(L(table.replacesKey), table.replacesKey)
            XCTAssertNotEqual(L(table.basicRuleKey), table.basicRuleKey)
            XCTAssertNotEqual(L(table.basicEffectKey), table.basicEffectKey)
        }
    }

    // MARK: - The basic rule the table replaces

    /// Switching the Fokus-Regel on offers the table; it does not remove the rule
    /// it replaces, and the screen has to be able to deliver that rule too. These
    /// are what it delivers.
    func testBasicRuleMatchesWhatEachTableReplaces() {
        XCTAssertEqual(CriticalSuccessTableType.angriff.basicDamage, .double)
        XCTAssertEqual(CriticalSuccessTableType.verteidigungNahkampf.basicDamage, .unchanged)
        XCTAssertEqual(CriticalSuccessTableType.verteidigungFernkampf.basicDamage, .unchanged)

        // The free strike *is* the basic rule on the melee defence, and nowhere else.
        for table in CriticalSuccessTableType.allCases {
            XCTAssertEqual(
                table.basicGrantsPassierschlag, table == .verteidigungNahkampf,
                "\(table.rawValue) basic rule"
            )
        }
    }

    // MARK: - Reading a row without its damage clause

    /// The screen states the multiplier once, as its own line, and prints every
    /// other effect with the damage clause taken off. That only works while the
    /// published rows keep the shape they have: a row that changes the damage
    /// opens with the clause, and the clause ends at the first " und " or at the
    /// full stop. This is what checks that across all 33 sub-tables — a row typed
    /// in another shape fails here, not silently on screen.

    /// Every opener the tables actually use. A new one must be added
    /// deliberately, because it is a new sentence shape to split.
    private static let damageClauseOpeners = [
        "Die Trefferpunkte samt Modifikatoren werden ",
        "Die Trefferpunkte werden um ",
        "Der Treffer richtet +",
    ]

    private func allRows() -> [(label: String, text: String, damage: CriticalDamage)] {
        var rows: [(String, String, CriticalDamage)] = []
        for table in CriticalSuccessTableType.allCases {
            for category in CriticalSuccessTable.categories(for: table) {
                rows.append(("\(table.rawValue) 2W6 \(category.roll)", category.effect, category.damage))
                for refinement in category.refinements {
                    guard let effect = refinement.effect else { continue }
                    rows.append((
                        "\(table.rawValue) 2W6 \(category.roll) 1W20 \(refinement.range)",
                        effect, refinement.damage
                    ))
                }
            }
        }
        return rows
    }

    func testEveryDamageRowOpensWithItsDamageClause() {
        for row in allRows() where row.damage != .unchanged {
            XCTAssertTrue(
                Self.damageClauseOpeners.contains(where: { row.text.hasPrefix($0) }),
                "\(row.label) changes the damage but does not open with a damage clause: \(row.text)"
            )
        }
    }

    /// What is left after the clause is either nothing (the row only changes the
    /// damage) or a sentence in its own right — never a fragment starting
    /// mid-clause.
    func testStrippingLeavesASentenceOrNothing() {
        for row in allRows() where row.damage != .unchanged {
            guard let rest = CriticalEffectText.withoutDamageClause(row.text, damage: row.damage) else {
                XCTAssertTrue(row.text.hasSuffix("."), "\(row.label): no ' und ' and no full stop")
                continue
            }
            XCTAssertFalse(rest.isEmpty, "\(row.label): empty remainder")
            XCTAssertEqual(
                String(rest.prefix(1)), String(rest.prefix(1)).uppercased(),
                "\(row.label): remainder does not start a sentence — \(rest)"
            )
            XCTAssertFalse(
                Self.damageClauseOpeners.contains(where: { rest.hasPrefix($0) }),
                "\(row.label): the damage clause survived the strip — \(rest)"
            )
        }
    }

    /// A row that changes nothing about the damage is printed whole.
    func testRowsWithoutDamageAreLeftAlone() {
        for row in allRows() where row.damage == .unchanged {
            XCTAssertEqual(
                CriticalEffectText.withoutDamageClause(row.text, damage: .unchanged), row.text,
                row.label
            )
        }
    }

    /// The case the merge exists for: "Schwerer Treffer" says only that the
    /// damage doubles, so it contributes no line of its own, and its 1W20 bands
    /// contribute the part that is not the doubling.
    func testTheDoublingIsNotSaidTwice() {
        let category = CriticalSuccessTable.category(7, table: .angriff)
        XCTAssertEqual(category.title, "Schwerer Treffer")
        XCTAssertNil(category.additionalEffect, "The category is the doubling and nothing else")

        let refinement = CriticalSuccessTable.refinement(7, in: category)
        XCTAssertEqual(refinement?.additionalEffect, "Der Gegner erhält 1 Stufe Schmerz für 2 KR.")
    }

    /// The damage line is generated from the resolved multiplier, so a band that
    /// disagrees with its category cannot leave both claims on screen.
    func testARefinementMayOverrideItsCategorysMultiplier() {
        let category = CriticalSuccessTable.category(5, table: .angriff)
        XCTAssertEqual(category.damage, .oneAndAHalf)   // Mittelschwerer schmerzhafter Treffer
        XCTAssertTrue(
            category.refinements.contains { $0.damage == .unchanged },
            "\(category.title) has bands that leave the damage alone"
        )
    }
}
