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
            defensesThisRound: .constant(0),
            schipDefenseBoostActive: .constant(false),
            schipIgnoreZustandThisRound: .constant(false),
            mountedActive: .constant(false),
            waterDepth: .constant(.none),
            formations: .constant([:]),
            opponent: OpponentProfile(),
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
            defensesThisRound: .constant(0),
            schipDefenseBoostActive: .constant(false),
            schipIgnoreZustandThisRound: .constant(false),
            mountedActive: .constant(false),
            waterDepth: .constant(.none),
            formations: .constant([:]),
            opponent: OpponentProfile(),
            onDismiss: {}
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "midCombatHandlungsunfaehig")
    }

    // MARK: - A mount in pain (issue #48)

    /// Boronmir on Kupperus (Svellttaler Kaltblut, 137 LeP) with the given current LeP.
    @MainActor
    private func heroOnKupperus(le: Int, type: String = "Svellttaler Kaltblut", in container: ModelContainer) throws -> Hero {
        let hero = try TestData.importBoronmir(into: container)
        let pet = Pet(
            petId: "PET_1", name: "Kupperus", size: 1.9, type: type,
            attributes: PetAttributes(mu: 15, kl: 10, inValue: 12, ch: 12, ff: 8, ge: 15, ko: 26, kk: 28),
            lifeEnergy: 137, currentLifeEnergy: le, spirit: 0, toughness: 0, initiative: "15+1W6", speed: 15,
            attack: "Tritt", damage: "1W6+8", reach: "mittel", actions: 1,
            talents: "", skills: "", notes: "")
        pet.defense = 14
        pet.advantages = ["Zähes Tier"]
        pet.attacks = [PetAttack(name: "Tritt", at: 19, damage: "1W6+8", reach: "mittel"),
                       PetAttack(name: "Niederreiten", at: 19, damage: "2W6+7", reach: "mittel")]
        hero.pets = [pet]
        hero.selectedWeaponName = "Rabenschnabel"   // a fixed weapon: the store hands weapons over in no fixed order
        hero.combatSpecialAbilities.append(HeroTrait(ruleId: "SA_43", name: "Berittener Kampf"))
        return hero
    }

    @MainActor
    func testRootWithAMountInPain() throws {
        try XCTSkipIf(RulesEngineStore.shared == nil, "rules.json unavailable")
        let container = try TestData.makeContainer()
        let hero = try heroOnKupperus(le: 60, in: container)

        let view = CombatRootView(
            hero: hero,
            step: .constant(.root),
            rolledInitiative: .constant(12),
            roundNumber: .constant(2),
            dualAttackPenaltyActive: .constant(false),
            twoHandedGripActive: .constant(false),
            vorstossActiveThisRound: .constant(false),
            beengteUmgebungActive: .constant(false),
            defensesThisRound: .constant(0),
            schipDefenseBoostActive: .constant(false),
            schipIgnoreZustandThisRound: .constant(false),
            mountedActive: .constant(true),
            waterDepth: .constant(.none),
            formations: .constant([:]),
            opponent: OpponentProfile(),
            onDismiss: {}
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "mountInPain")
    }

    /// A mount whose type has no breed rule: the root says its thresholds are unknown (ADR-0018).
    @MainActor
    func testRootWithAMountWithoutThresholds() throws {
        try XCTSkipIf(RulesEngineStore.shared == nil, "rules.json unavailable")
        let container = try TestData.makeContainer()
        let hero = try heroOnKupperus(le: 60, type: "Pferd", in: container)

        let view = CombatRootView(
            hero: hero,
            step: .constant(.root),
            rolledInitiative: .constant(12),
            roundNumber: .constant(2),
            dualAttackPenaltyActive: .constant(false),
            twoHandedGripActive: .constant(false),
            vorstossActiveThisRound: .constant(false),
            beengteUmgebungActive: .constant(false),
            defensesThisRound: .constant(0),
            schipDefenseBoostActive: .constant(false),
            schipIgnoreZustandThisRound: .constant(false),
            mountedActive: .constant(true),
            waterDepth: .constant(.none),
            formations: .constant([:]),
            opponent: OpponentProfile(),
            onDismiss: {}
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "mountWithoutThresholds")
    }

    @MainActor
    func testMountActionsAtSchmerzIV() throws {
        try XCTSkipIf(RulesEngineStore.shared == nil, "rules.json unavailable")
        let container = try TestData.makeContainer()
        let hero = try heroOnKupperus(le: 5, in: container)

        let view = CombatAttackChoiceView(
            hero: hero,
            step: .constant(.attackChoice),
            dualAttackPenaltyActive: .constant(false),
            twoHandedGripActive: .constant(false),
            mountedActive: true,
            onDismiss: {}
        )
        .modelContainer(container)

        assertAllVariants(of: view, named: "mountActionsSchmerzIV")
    }
}
