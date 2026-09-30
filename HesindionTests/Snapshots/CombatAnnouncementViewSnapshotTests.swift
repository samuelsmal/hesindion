import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

/// The attack announcement.
final class CombatAnnouncementViewSnapshotTests: XCTestCase {

    /// Against a winzig target (Größenkategorie): the size on the folded
    /// opponent section's lid and the AT −4 in the calculation.
    @MainActor
    func testWinzigTarget() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        var opponent = OpponentProfile()
        opponent.size = .winzig
        opponent.reach = .kurz   // keep GRW_reichweite out of the lines

        let view = CombatAnnouncementView(
            hero: hero,
            action: .angriff,
            weaponName: "Rabenschnabel",
            baseAT: 12,
            damageFormula: "1W6+5",
            isOffHand: false,
            mountedActive: false,
            waterDepth: .none,
            isMountCharge: false,
            beengteUmgebungActive: false,
            schipIgnoreZustandThisRound: false,
            secondAttack: nil,
            step: .constant(.root),
            activeManeuver: .constant(.normal),
            vorstossActiveThisRound: .constant(false),
            announcedZone: .constant(nil),
            dualAttackPenaltyActive: false,
            twoHandedGripActive: false,
            plaenklerActive: false,
            plaenklerBonus: .at,
            opponent: .constant(opponent),
            onDismiss: {}
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "winzigTarget")
    }

    /// A mounted charge (issue #32): the header names the maneuver, the
    /// subtitle the weapon. The maneuver list is hidden, so the header was
    /// the only place left to say it, and it said "Ansage".
    @MainActor
    func testMountCharge() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)

        let view = CombatAnnouncementView(
            hero: hero,
            action: .angriff,
            weaponName: "Rabenschnabel",
            baseAT: 12,
            damageFormula: "1W6+5",
            isOffHand: false,
            mountedActive: true,
            waterDepth: .none,
            isMountCharge: true,
            beengteUmgebungActive: false,
            schipIgnoreZustandThisRound: false,
            secondAttack: nil,
            step: .constant(.root),
            activeManeuver: .constant(.normal),
            vorstossActiveThisRound: .constant(false),
            announcedZone: .constant(nil),
            dualAttackPenaltyActive: false,
            twoHandedGripActive: false,
            plaenklerActive: false,
            plaenklerBonus: .at,
            opponent: .constant(OpponentProfile()),
            onDismiss: {}
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "mountCharge")
    }
}
