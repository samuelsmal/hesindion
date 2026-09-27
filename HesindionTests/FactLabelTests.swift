import XCTest
import RulesEngine
@testable import Hesindion

/// `BreakdownSheet`'s fact-name labels (sheet cut-over design §5, controller ruling R13): a
/// breakdown shows "MU 14 · Heldenbogen", never the engine's own "attr.MU 14 · Heldenbogen".
final class FactLabelTests: XCTestCase {
    private var book: RuleBook { RulesEngineStore.shared!.engine.book }

    func testAnAttributeFactDropsItsPrefix() {
        XCTAssertEqual(FactLabel.label("attr.MU", book: book), "MU")
        XCTAssertEqual(FactLabel.label("attr.KO", book: book), "KO")
    }

    func testATechniqueFactNamesItselfFromTheBooksKampfwerteTable() {
        XCTAssertEqual(FactLabel.label("ktw.CT_5", book: book), "Hiebwaffen")
    }

    func testATechniqueFactFallsBackToTheRawIdWithoutABook() {
        XCTAssertEqual(FactLabel.label("ktw.CT_5", book: nil), "CT_5")
    }

    func testATalentFactNamesItselfFromTheBooksOwnRuleWhenThereIsOne() {
        // TAL_7 (Schwimmen) is the one talent the book carries its own rule for.
        XCTAssertEqual(FactLabel.label("fw.TAL_7", book: book), "Schwimmen")
    }

    func testATalentFactWithoutABookRuleFallsBackToTheRawId() {
        // TAL_1 has no rule of its own in the book.
        XCTAssertNil(book.rules["TAL_1"])
        XCTAssertEqual(FactLabel.label("fw.TAL_1", book: book), "TAL_1")
    }

    func testAKnownSheetFactUsesItsLocalizedLabel() {
        XCTAssertEqual(FactLabel.label("species.le", book: book), L("fact.species.le"))
        XCTAssertEqual(FactLabel.label("hero.purchased.le", book: book), L("fact.hero.purchased.le"))
        XCTAssertEqual(FactLabel.label("level", book: book), L("fact.level"))
        XCTAssertEqual(FactLabel.label("loadout.weapon", book: book), L("fact.loadout.weapon"))
        XCTAssertEqual(FactLabel.label("loadout.shield", book: book), L("fact.loadout.shield"))
        XCTAssertEqual(FactLabel.label("loadout.armour", book: book), L("fact.loadout.armour"))
        XCTAssertEqual(FactLabel.label("loadout.armour.belastung", book: book), L("fact.loadout.armour.belastung"))
        XCTAssertEqual(FactLabel.label("loadout.armour.extraPenalty", book: book), L("fact.loadout.armour.extraPenalty"))
    }

    func testAnUnknownFactShowsItsRawName() {
        XCTAssertEqual(FactLabel.label("some.unknown.fact", book: book), "some.unknown.fact")
    }

    /// A fact under the same `fw.`/`ktw.` prefix that isn't a talent/technique id must not be
    /// mangled by dropping the prefix — it falls through to the raw-name case untouched.
    func testAFactSharingATalentOrTechniquePrefixWithoutMatchingTheIdShapeIsShownRaw() {
        XCTAssertEqual(FactLabel.label("fw.current", book: book), "fw.current")
        XCTAssertEqual(FactLabel.label("ktw.current", book: book), "ktw.current")
    }
}
