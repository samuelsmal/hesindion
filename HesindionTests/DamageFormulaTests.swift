import XCTest
@testable import Hesindion

/// The damage string, which four screens used to parse with four copies of one
/// regex and three used to rewrite with another. The two-handed grip's +1 was
/// applied by two of those copies at once.
final class DamageFormulaTests: XCTestCase {

    // MARK: - Parsing

    func testParsesDiceBonusAndSides() {
        XCTAssertEqual(DamageFormula.parse("1W6+4"), DamageFormula(count: 1, sides: 6, bonus: 4))
        XCTAssertEqual(DamageFormula.parse("2W6"), DamageFormula(count: 2, sides: 6, bonus: 0))
        XCTAssertEqual(DamageFormula.parse("1W6-1"), DamageFormula(count: 1, sides: 6, bonus: -1))
        XCTAssertEqual(DamageFormula.parse("1W3+1"), DamageFormula(count: 1, sides: 3, bonus: 1))
    }

    /// `"0"` is what the import writes for an item whose damage it could not read
    /// (`formatDamage` with no dice and no flat value). It is not a roll, and the
    /// damage screen must be able to tell.
    func testAFormulaWithNoDiceDoesNotParse() {
        XCTAssertNil(DamageFormula.parse("0"))
        XCTAssertNil(DamageFormula.parse("+2"))
        XCTAssertNil(DamageFormula.parse("—"))
        XCTAssertNil(DamageFormula.parse(""))
    }

    /// Lenient on purpose: a pet's attack line arrives with text around the dice.
    func testReadsTheDiceOutOfALongerString() {
        XCTAssertEqual(DamageFormula.parse("Tritt 1W6+7 RW mittel"),
                       DamageFormula(count: 1, sides: 6, bonus: 7))
    }

    // MARK: - Adding a bonus

    func testAddsToAnExistingBonus() {
        XCTAssertEqual(DamageFormula.adding(4, to: "1W6+4"), "1W6+8")
        XCTAssertEqual(DamageFormula.adding(1, to: "2W6"), "2W6+1")
        XCTAssertEqual(DamageFormula.adding(-2, to: "1W6+3"), "1W6+1")
    }

    /// A bonus that cancels the weapon's own leaves bare dice, not "+0".
    func testACancelledBonusDisappears() {
        XCTAssertEqual(DamageFormula.adding(-4, to: "1W6+4"), "1W6")
    }

    func testANegativeTotalKeepsItsSign() {
        XCTAssertEqual(DamageFormula.adding(-6, to: "1W6+4"), "1W6-2")
    }

    func testZeroBonusIsTheFormulaItself() {
        XCTAssertEqual(DamageFormula.adding(0, to: "1W6+4"), "1W6+4")
    }

    /// Strict where `parse` is lenient: a string this cannot rewrite in full is
    /// one it must return untouched rather than mangle.
    func testAStringItCannotFullyReadIsLeftAlone() {
        XCTAssertEqual(DamageFormula.adding(2, to: "1W6+4 (KK)"), "1W6+4 (KK)")
        XCTAssertEqual(DamageFormula.adding(2, to: "0"), "0")
    }

    /// Adding twice is what the bug looked like: the weapon list folded the grip
    /// bonus in and the announcement screen folded it in again.
    func testAddingTwiceIsVisiblyDifferentFromAddingOnce() {
        let once = DamageFormula.adding(1, to: "1W6+4")
        XCTAssertEqual(once, "1W6+5")
        XCTAssertEqual(DamageFormula.adding(1, to: once), "1W6+6")
    }

    // MARK: - Round trip

    func testTextIsWhatParseReads() {
        for formula in ["1W6", "1W6+4", "2W6-1", "1W3+1"] {
            XCTAssertEqual(DamageFormula.parse(formula)?.text, formula)
        }
    }
}
