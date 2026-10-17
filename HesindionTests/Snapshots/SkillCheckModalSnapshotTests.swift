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

    /// Issue #43: the Zielwert row shows the value after the modifiers, and the GM-decided
    /// Aufmerksamkeit +2 reads as applied or not applied. The 14 fails against 12 without it and
    /// passes against 14 with it.
    @MainActor
    private func gmBonusView(applied: Bool, container: ModelContainer, hero: Hero) -> some View {
        SkillCheckModal(
            config: SkillCheckConfig(
                title: "Probe",
                name: "Sinnesschärfe",
                skillValue: 6,
                checkAttributes: [("KL", 13), ("IN", 14), ("IN", 14)],
                accentColor: .groupPersonalData,
                modifierLines: [ModifierLine(value: -1, source: "Belastung")],
                logKind: "talentCheck"
            ),
            hero: hero,
            onDismiss: {},
            previewFinalRolls: [14, 10, 5],
            gmBonus: ModifierLine(value: 2, source: "Aufmerksamkeit (Überraschung vermeiden)"),
            previewGMBonusApplied: applied
        )
        .modelContainer(container)
    }

    @MainActor
    func testGMBonusNotApplied() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        assertAllVariants(of: gmBonusView(applied: false, container: container, hero: hero), named: "gm-bonus-off")
    }

    @MainActor
    func testGMBonusApplied() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        assertAllVariants(of: gmBonusView(applied: true, container: container, hero: hero), named: "gm-bonus-on")
    }
}
