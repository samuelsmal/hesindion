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

    /// Only the first threshold shows the LeP read and the Auslegung mark; the rows below
    /// repeat neither.
    func testALineRepeatsNoFactAndNoMarkOfTheLineAbove() throws {
        let d = details(try schmerz(le: 60))
        for line in d[1...3] {
            XCTAssertFalse(line!.contains("LeP 60"), line!)
            XCTAssertFalse(line!.contains(L("breakdown.auslegung")), line!)
        }
    }

    /// The rule name shows once per run of lines from the same rule, without the clause id.
    func testTheSourceIsTheRuleNameOncePerRun() throws {
        let sources = BreakdownText.sources(for: try schmerz(le: 60), book: book)
        let breed = book.rules["svellttaler-kaltblut"]!.name, tough = book.rules["zaehes-tier"]!.name
        XCTAssertEqual(sources, [breed, "", "", "", tough])
    }

    /// "Mehr Infos": each clause, rule and ruling id once.
    func testTheReferencesListEachClauseAndRulingOnce() throws {
        let refs = BreakdownText.references(for: try schmerz(le: 60), book: book)
        let breed = book.rules["svellttaler-kaltblut"]!.name
        XCTAssertEqual(refs.filter { $0 == "\(breed) · SK10" }.count, 1, "\(refs)")
        XCTAssertEqual(refs.filter { $0.contains("svellttaler-kaltblut.svellttaler-schmerz-thresholds") }.count, 1,
                       "\(refs)")
        XCTAssertEqual(Set(refs).count, refs.count, "\(refs)")
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
