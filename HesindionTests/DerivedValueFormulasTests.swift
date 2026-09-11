import XCTest
@testable import Hesindion

final class DerivedValueFormulasTests: XCTestCase {

    private func trait(_ id: String) -> HeroTrait { HeroTrait(ruleId: id, name: id, tier: nil, sid: nil) }

    // The Regelwiki's own worked example: KO 11 → Wundschwelle 6.
    func testWundschwelleRoundsUp() {
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 11, advantages: [], disadvantages: []).base, 6)
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 12, advantages: [], disadvantages: []).base, 6)
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 13, advantages: [], disadvantages: []).base, 7)
    }

    func testEisernAndGlaesern() {
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 12, advantages: [trait("ADV_54")], disadvantages: []).bonus, 1)
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 12, advantages: [], disadvantages: [trait("DISADV_56")]).bonus, -1)
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 12, advantages: [trait("ADV_54")], disadvantages: [trait("DISADV_56")]).bonus, 0)
    }

    // Untiered in rules.db (max: 1) — duplicates must not stack.
    func testEisernDoesNotStack() {
        let two = [trait("ADV_54"), trait("ADV_54")]
        XCTAssertEqual(DerivedValueFormulas.wundschwelle(ko: 12, advantages: two, disadvantages: []).bonus, 1)
    }

    func testAusweichenRoundsUp() {
        XCTAssertEqual(DerivedValueFormulas.ausweichen(ge: 12), 6)
        XCTAssertEqual(DerivedValueFormulas.ausweichen(ge: 13), 7)
    }

    func testInitiativeRoundsUp() {
        XCTAssertEqual(DerivedValueFormulas.initiative(mu: 12, ge: 12), 12)
        XCTAssertEqual(DerivedValueFormulas.initiative(mu: 12, ge: 13), 13)
    }
}
