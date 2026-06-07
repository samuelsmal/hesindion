import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class SkillCheckModalSnapshotTests: XCTestCase {

    private func failingConfig() -> SkillCheckConfig {
        SkillCheckConfig(
            title: "Talent",
            name: "Klettern",
            skillValue: 5,
            checkAttributes: [("MU", 12), ("GE", 12), ("KK", 12)],
            accentColor: .groupCombat,
            modifierLines: [],
            logKind: "talentCheck"
        )
    }

    @MainActor
    func testFailureWithSchipsAvailable() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)  // 3 Schips

        let view = SkillCheckModal(
            config: failingConfig(),
            hero: hero,
            onDismiss: {},
            // QS 0 regular failure (not a critical botch): only one 20, total
            // excess 8+6 against skill 5 → remaining -9. Two+ 20s would be a
            // kritischer Patzer, which is intentionally not reroll-eligible.
            previewFinalRolls: [20, 18, 3]
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "failure-schips-available")
    }

    @MainActor
    func testFailureWithNoSchips() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        hero.derivedValues?.schicksalspunkte.current = 0  // exhaust Schips

        let view = SkillCheckModal(
            config: failingConfig(),
            hero: hero,
            onDismiss: {},
            previewFinalRolls: [20, 18, 3]  // same QS 0 failure, but no Schips
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "failure-no-schips")  // button absent
    }
}
