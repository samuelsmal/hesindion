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
