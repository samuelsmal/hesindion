import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

/// The defence screen Parieren and Ausweichen open on the combat root.
final class CombatDefenseSetupViewSnapshotTests: XCTestCase {

    /// In the saddle, against an attacker on foot: the rider-only question is
    /// on screen and answered.
    @MainActor
    func testMountedParry() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        var opponent = OpponentProfile()
        opponent.isOnFoot = true

        let view = CombatDefenseSetupView(
            hero: hero,
            action: .parieren,
            situation: CombatSituation(mounted: true),
            mountedActive: true,
            opponent: .constant(opponent),
            step: .constant(.defenseSetup(.parieren)),
            onDismiss: {}
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "mountedParry")
    }

    /// On foot, attacked from behind: no rider question, and the −4 in the sum.
    @MainActor
    func testDodgeFromBehind() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        var opponent = OpponentProfile()
        opponent.fromBehind = true

        let view = CombatDefenseSetupView(
            hero: hero,
            action: .ausweichen,
            situation: CombatSituation(),
            mountedActive: false,
            opponent: .constant(opponent),
            step: .constant(.defenseSetup(.ausweichen)),
            onDismiss: {}
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "dodgeFromBehind")
    }
}
