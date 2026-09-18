import XCTest
@testable import Hesindion

/// I3: an announced Trefferzone must apply to exactly the attack that announced it.
///
/// `CombatView` clears `announcedZone` whenever it enters a step that does not
/// `preservesAnnouncedZone`, so the rule under test is that property. The `@State`
/// wiring itself lives in the view and is not unit-testable.
final class AnnouncedZoneTests: XCTestCase {

    /// Every step the orchestrator can show, one representative value each
    /// (spell steps need a `HeroSpell` model and are omitted — none of them
    /// resolves an attack).
    @MainActor
    private var representativeSteps: [CombatStep] {
        [
            .combatSetup,
            .initiativeRoll,
            .loadoutEquipment,
            .root,
            .attackChoice,
            .weaponSelection(.angriff),
            .announcement(.angriff, name: "Säbel", baseAT: 12, damageFormula: "1W6+4",
                          isOffHand: false, secondAttack: nil, isMountCharge: false),
            .execution(.angriff, name: "Säbel", attributeValue: 12, damageFormula: "1W6+4", note: nil),
            .dualAttackSecond(name: "Dolch", attributeValue: 10, damageFormula: "1W6+2"),
            .mountPreCheck(onSuccess: .root),
            .mountDamage,
            .takeDamage(),
            .flucht,
            .opponentDefense(weaponName: "Säbel", damageFormula: "1W6+4", isCriticalHit: false,
                             criticalDamage: .unchanged, modifierLines: nil),
            .fumbleChoice(action: .angriff, weaponName: "Säbel", isShieldParry: false),
            .passierschlag,
            .fernkampfSetup,
            .fernkampfExecution(weaponName: "Bogen", attributeValue: 11, damageFormula: "1W6+4",
                                distanzTP: 0, modifierLines: []),
        ]
    }

    /// Only the three steps that resolve the announced attack carry the zone.
    @MainActor
    func testOnlyResolutionStepsPreserveTheAnnouncedZone() {
        let preserving = Set(representativeSteps.filter(\.preservesAnnouncedZone).map(\.persistenceKey))
        XCTAssertEqual(preserving, ["execution", "fernkampfExecution", "opponentDefense"])
    }

    /// The off-hand swing of a dual attack never passes an announcement screen, so it
    /// must not inherit the main hand's zone.
    @MainActor
    func testDualAttackSecondDropsTheZone() {
        XCTAssertFalse(CombatStep.dualAttackSecond(name: "Dolch", attributeValue: 10,
                                                   damageFormula: "1W6+2").preservesAnnouncedZone)
    }

    /// Mount attacks (Hufschlag/Tritt, Niederreiten) jump from the attack choice — and
    /// Niederreiten via the mount pre-check — straight into execution, announcing nothing.
    /// Both entry points clear, so the execution they push starts zone-less.
    @MainActor
    func testMountAttackEntryPointsDropTheZone() {
        XCTAssertFalse(CombatStep.attackChoice.preservesAnnouncedZone)
        XCTAssertFalse(CombatStep.mountPreCheck(onSuccess: .root).preservesAnnouncedZone)
    }

    /// Returning to the root screen ends the action, zone included.
    @MainActor
    func testRootDropsTheZone() {
        XCTAssertFalse(CombatStep.root.preservesAnnouncedZone)
    }

    /// A hit lands on the defence screen, which shows the wound-effect reminder — the
    /// zone has to survive execution → opponentDefense.
    @MainActor
    func testAnnouncedAttackKeepsItsZoneThroughResolution() {
        XCTAssertTrue(CombatStep.execution(.angriff, name: "Säbel", attributeValue: 12,
                                           damageFormula: "1W6+4", note: nil).preservesAnnouncedZone)
        XCTAssertTrue(CombatStep.opponentDefense(weaponName: "Säbel", damageFormula: "1W6+4",
                                                 isCriticalHit: false, criticalDamage: .unchanged,
                                                 modifierLines: nil).preservesAnnouncedZone)
        XCTAssertTrue(CombatStep.fernkampfExecution(weaponName: "Bogen", attributeValue: 11,
                                                    damageFormula: "1W6+4", distanzTP: 0,
                                                    modifierLines: []).preservesAnnouncedZone)
    }
}
