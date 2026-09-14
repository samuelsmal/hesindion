import XCTest
import SwiftData
@testable import Hesindion

/// The defence side of a round: who is penalised for defending again, and by how
/// much. These are the numbers two different screens used to compute differently
/// — the combat root through the modifier engine, the weapon list not at all.
@MainActor
final class CombatSituationTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        // A hero with nothing switched on: no Zustände, no armour, no
        // Sonderfertigkeiten, so every line in these tests is one the situation
        // itself put there.
        hero = Hero(name: "Test")
        context.insert(hero)
    }

    override func tearDown() {
        context = nil
        hero = nil
    }

    private func lines(_ situation: CombatSituation, isAusweichen: Bool = false, isOffHand: Bool = false) -> [ModifierLine] {
        situation.defenseModifiers(hero: hero, isAusweichen: isAusweichen, isOffHand: isOffHand)
    }

    private func value(of source: String, in lines: [ModifierLine]) -> Int? {
        lines.first { $0.source == source }?.value
    }

    /// A catalog line names its rule, not a localized source string.
    private func value(ofRule ruleId: String, in lines: [ModifierLine]) -> Int? {
        lines.first { $0.ruleId == ruleId }?.value
    }

    // MARK: - Mehrfache Verteidigung

    /// The first defence of a round is unmodified. The count is incremented as a
    /// defence is *rolled*, so while the first one is being set up it is still 0.
    func testFirstDefenceOfTheRoundIsUnpenalised() {
        let l = lines(CombatSituation(parriesThisRound: 0))
        XCTAssertNil(value(ofRule: "GRW_mehrfacheVerteidigung", in: l))
    }

    func testSecondDefenceIsAtMinusThreeAndItIsCumulative() {
        XCTAssertEqual(value(ofRule: "GRW_mehrfacheVerteidigung", in: lines(CombatSituation(parriesThisRound: 1))), -3)
        XCTAssertEqual(value(ofRule: "GRW_mehrfacheVerteidigung", in: lines(CombatSituation(parriesThisRound: 2))), -6)
        XCTAssertEqual(value(ofRule: "GRW_mehrfacheVerteidigung", in: lines(CombatSituation(parriesThisRound: 3))), -9)
    }

    // MARK: - Parade and Ausweichen are counted apart

    /// Mehrfache Verteidigung is tracked per defence *type*: parries and dodges
    /// have their own counts, so the round's first dodge is unmodified however
    /// often the hero has already parried, and the other way round.
    func testParriesDoNotMakeTheFirstDodgeHarder() {
        let parriedTwice = CombatSituation(parriesThisRound: 2, dodgesThisRound: 0)
        XCTAssertEqual(value(ofRule: "GRW_mehrfacheVerteidigung", in: lines(parriedTwice)), -6,
                       "the third parry is at -6")
        XCTAssertNil(value(ofRule: "GRW_mehrfacheVerteidigung", in: lines(parriedTwice, isAusweichen: true)),
                     "the first dodge of the round is unmodified")
    }

    func testDodgesDoNotMakeTheFirstParryHarder() {
        let dodgedTwice = CombatSituation(parriesThisRound: 0, dodgesThisRound: 2)
        XCTAssertEqual(value(ofRule: "GRW_mehrfacheVerteidigung", in: lines(dodgedTwice, isAusweichen: true)), -6)
        XCTAssertNil(value(ofRule: "GRW_mehrfacheVerteidigung", in: lines(dodgedTwice)))
    }

    func testEachKindCountsItsOwnPendingPenalty() {
        let s = CombatSituation(parriesThisRound: 1, dodgesThisRound: 3)
        XCTAssertEqual(s.pendingMultipleDefensePenalty(isAusweichen: false), -3)
        XCTAssertEqual(s.pendingMultipleDefensePenalty(isAusweichen: true), -9)
        XCTAssertEqual(s.defensesSoFar(isAusweichen: false), 1)
        XCTAssertEqual(s.defensesSoFar(isAusweichen: true), 3)
    }

    /// A dodge accumulates the same way a parry does, on its own count.
    func testTheDodgeAccumulatesOnItsOwnCount() {
        XCTAssertEqual(
            value(ofRule: "GRW_mehrfacheVerteidigung", in: lines(CombatSituation(dodgesThisRound: 2), isAusweichen: true)),
            -6)
    }

    /// What the buttons print before you commit to another defence.
    func testPendingPenaltyMatchesWhatTheNextDefenceWillCost() {
        XCTAssertEqual(CombatSituation().pendingMultipleDefensePenalty(isAusweichen: false), 0)
        XCTAssertEqual(CombatSituation(parriesThisRound: 1).pendingMultipleDefensePenalty(isAusweichen: false), -3)
        XCTAssertEqual(CombatSituation(parriesThisRound: 2).pendingMultipleDefensePenalty(isAusweichen: false), -6)
    }

    // MARK: - The lines the weapon list used to lose

    /// Picking the parrying weapon first must not cost the hero their modifiers.
    /// Every one of these was silently absent on the shield / dual-wield path.
    func testAParryKeepsEveryLineWhicheverScreenRollsIt() {
        let situation = CombatSituation(
            dualAttackActive: true,
            twoHandedGrip: true,
            parriesThisRound: 1,
            schipDefenseBoost: true
        )
        let l = lines(situation)
        XCTAssertEqual(value(ofRule: "GRW_mehrfacheVerteidigung", in: l), -3)
        XCTAssertEqual(value(of: L("source.schipDefense"), in: l), 4)
        XCTAssertEqual(value(of: L("source.twoHandedGrip"), in: l), -1)
        XCTAssertEqual(value(of: L("source.dualAttack"), in: l), hero.dualAttackPenalty)
    }

    /// The grip is a parry-only thing; a dodge has no weapon in it.
    func testTwoHandedGripDoesNotTouchTheDodge() {
        let l = lines(CombatSituation(twoHandedGrip: true), isAusweichen: true)
        XCTAssertNil(value(of: L("source.twoHandedGrip"), in: l))
    }

    /// The off-hand weapon parries at the same penalty it attacks with. The
    /// weapon list used to add this to the row's own number, where the
    /// calculation box could not show it.
    func testOffHandWeaponParriesAtTheOffHandPenalty() {
        let l = lines(CombatSituation(), isOffHand: true)
        XCTAssertEqual(value(of: L("source.offHand"), in: l), hero.offHandPenalty)
        XCTAssertNil(value(of: L("source.offHand"), in: lines(CombatSituation())),
                     "the main hand pays no off-hand penalty")
    }

    func testMountedDodgeIsHarderAndMountedParryIsNot() {
        XCTAssertEqual(value(of: L("source.mounted"), in: lines(CombatSituation(mounted: true), isAusweichen: true)), -2)
        XCTAssertNil(value(of: L("source.mounted"), in: lines(CombatSituation(mounted: true))))
    }
}
