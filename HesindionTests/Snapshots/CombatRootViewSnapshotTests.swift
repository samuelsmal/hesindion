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
        // Give the hero a couple of states so the combat states strip and a per-round
        // reminder (Blutend) are visible in the snapshot.
        hero.setStateLevel("furcht", level: 2)
        hero.setStateLevel("blutend", level: 1)

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

    @MainActor
    func testMidCombatHandlungsunfaehig() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        // Furcht IV makes the hero handlungsunfähig — the warning banner must render.
        hero.setStateLevel("furcht", level: 4)

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

        assertAllVariants(of: view, named: "midCombatHandlungsunfaehig")
    }
}
