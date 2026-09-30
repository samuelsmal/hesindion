import XCTest
import SwiftUI
import SwiftData
@testable import Hesindion

/// The manoeuvres a weapon attack's announcement offers.
@MainActor
final class CombatAnnouncementManeuverTests: XCTestCase {

    private var context: ModelContext!
    private var rider: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        rider = Hero(name: "Rider")
        context.insert(rider)
        rider.combatSpecialAbilities = [HeroTrait(ruleId: CombatAbility.berittenerKampf.rawValue, name: "Berittener Kampf")]
    }

    override func tearDown() { context = nil; rider = nil }

    private func announcement(isMountCharge: Bool) -> CombatAnnouncementView {
        CombatAnnouncementView(
            hero: rider,
            action: .angriff,
            weaponName: "Rabenschnabel",
            baseAT: 12,
            damageFormula: "1W6+5",
            isOffHand: false,
            mountedActive: true,
            waterDepth: .none,
            isMountCharge: isMountCharge,
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
            onBack: {},
            onDismiss: {}
        )
    }

    /// Issue #39: the Sturmangriff zu Pferd is a command to the horse behind a
    /// Reiten check, reached from the mount's own button. A mounted rider's
    /// plain weapon attack does not offer it as one of its manoeuvres.
    func testAMountedWeaponAttackDoesNotOfferTheCharge() {
        XCTAssertTrue(rider.hasBerittenerKampf)
        XCTAssertFalse(announcement(isMountCharge: false).availableManeuvers.contains(.sturmangriff))
    }
}
