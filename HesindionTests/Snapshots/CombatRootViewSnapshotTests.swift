import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

final class CombatRootViewSnapshotTests: XCTestCase {

    @MainActor
    func testMidCombat() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)

        let view = CombatRootView(
            hero: hero,
            step: .constant(.root),
            rolledInitiative: .constant(12),
            roundNumber: .constant(2),
            dualAttackPenaltyActive: .constant(false),
            twoHandedGripActive: .constant(false),
            vorstossActiveThisRound: .constant(false),
            beengteUmgebungActive: .constant(false),
            defenseCountThisRound: .constant(0),
            schipDefenseBoostActive: .constant(false),
            schipIgnoreZustandThisRound: .constant(false),
            mountedActive: false,
            plaenklerActive: false,
            plaenklerBonus: .at,
            onDismiss: {}
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "midCombat")
    }
}
