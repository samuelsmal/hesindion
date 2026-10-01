import XCTest
import SwiftData
import RulesEngine
@testable import Hesindion

/// Issue #51: what `BreakdownSheet` prints for a Stufe's breakdown — each threshold with its value
/// and whether it is reached, Zähes Tier's shift in plain words, and the Stufe as the result.
@MainActor
final class BreakdownTextTests: XCTestCase {
    private var context: ModelContext!
    private var book: RuleBook!

    override func setUpWithError() throws {
        guard let store = RulesEngineStore.shared else { throw XCTSkip("rules.json unavailable") }
        book = store.engine.book
        context = ModelContext(try TestData.makeContainer())
    }

    /// Kupperus with 137 max LeP, as in `MountValuesTests`.
    private func schmerz(le: Int, advantages: [String] = ["Zähes Tier"]) throws -> Breakdown {
        let pet = Pet(
            petId: "PET_1", name: "Kupperus", size: 1.9, type: "Svellttaler Kaltblut",
            attributes: PetAttributes(mu: 15, kl: 10, inValue: 12, ch: 12, ff: 8, ge: 15, ko: 26, kk: 28),
            lifeEnergy: 137, currentLifeEnergy: le, spirit: 0, toughness: 0, initiative: "15+1W6", speed: 15,
            attack: "Tritt", damage: "1W6+8", reach: "mittel", actions: 1,
            talents: "", skills: "", notes: "")
        pet.advantages = advantages
        context.insert(pet)
        return try XCTUnwrap(MountValues.of(pet)).schmerzValue.breakdown
    }

    private func details(_ b: Breakdown) -> [String?] {
        BreakdownText.details(for: b, book: book, openRuling: nil)
    }

    func testEachThresholdNamesItsStufeItsLePAndWhetherItIsReached() throws {
        let d = details(try schmerz(le: 60))
        let reached = L("breakdown.step.reached"), notReached = L("breakdown.step.notReached")
        XCTAssertEqual(d.count, 5)
        XCTAssertTrue(d[0]!.hasPrefix(String(format: L("breakdown.step"), "I", "LeP", 89, reached)), d[0]!)
        XCTAssertTrue(d[1]!.hasPrefix(String(format: L("breakdown.step"), "II", "LeP", 60, reached)), d[1]!)
        XCTAssertTrue(d[2]!.hasPrefix(String(format: L("breakdown.step"), "III", "LeP", 29, notReached)), d[2]!)
        XCTAssertTrue(d[3]!.hasPrefix(String(format: L("breakdown.step"), "IV", "LeP", 5, notReached)), d[3]!)
    }

    func testTheFactsReadAsLePAndHideTheSubject() throws {
        let first = try XCTUnwrap(details(try schmerz(le: 60))[0])
        XCTAssertTrue(first.contains("LeP 60"), first)
        XCTAssertFalse(first.contains("hero.leCurrent"), first)
        XCTAssertFalse(first.contains(L("fact.subject")), first)
        XCTAssertFalse(first.contains(L("owner.derived")), first)
    }

    func testTheRulingMarkHidesItsIdUntilOpened() throws {
        let b = try schmerz(le: 60)
        let shut = try XCTUnwrap(details(b)[0])
        XCTAssertTrue(shut.hasSuffix(L("breakdown.auslegung")), shut)
        XCTAssertFalse(shut.contains("svellttaler-schmerz-thresholds"), shut)
        let ruling = "svellttaler-kaltblut.svellttaler-schmerz-thresholds"
        let open = try XCTUnwrap(BreakdownText.details(for: b, book: book, openRuling: ruling)[0])
        XCTAssertTrue(open.hasSuffix(String(format: L("breakdown.auslegung.open"), book.rulingAnswer(ruling)!)), open)
    }

    func testZaehesTiersLineSaysWhichStufeActsAsWhich() throws {
        let d = details(try schmerz(le: 60))
        XCTAssertTrue(d[4]!.hasPrefix(String(format: L("breakdown.levelAs"), "II", "I")), d[4]!)
    }

    func testTheResultIsTheStufeActedAtAndTheStufeHad() throws {
        XCTAssertEqual(BreakdownText.total(of: try schmerz(le: 60)),
                       String(format: L("breakdown.level.totalHas"), "I", "II"))
        XCTAssertEqual(BreakdownText.total(of: try schmerz(le: 60, advantages: [])),
                       String(format: L("breakdown.level.total"), "II"))
        XCTAssertEqual(BreakdownText.total(of: try schmerz(le: 137, advantages: [])),
                       String(format: L("breakdown.level.total"), L("breakdown.level.none")))
    }
}
