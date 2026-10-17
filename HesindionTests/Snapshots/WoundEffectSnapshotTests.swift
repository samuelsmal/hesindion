import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

/// Snapshots `CombatWoundEffectPanel` directly rather than the full
/// `CombatTakeDamageView`. The panel's initialiser takes only plain values, a
/// `Hero`, and a `Binding<Bool?>` — nothing private to its parent — so it can be
/// constructed standalone without adding test-only seed parameters to a
/// production view.
final class WoundEffectSnapshotTests: XCTestCase {

    @MainActor
    func testWoundEffectPanelArmeThreshold() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        hero.setFokusRule(.trefferzonen, active: true)

        // Wundschwelle 6, 8 damage, Arme: multiple = 8 / 6 = 1 (×1), a
        // `.reminder`-kind effect that resists via Selbstbeherrschung.
        let hit = HitZoneHit(zone: .arme, side: .rechts)

        let view = ScrollView {
            VStack(spacing: 16) {
                CombatWoundEffectPanel(
                    hero: hero,
                    hit: hit,
                    effectiveDamage: 8,
                    wundschwelle: 6,
                    probeSucceeded: .constant(nil),
                    effectApplies: false,
                    extraDamage: .constant(nil),
                    confirmed: false,
                    dropWeapon: .constant(false),
                    onRollProbe: {}
                )
            }
            .adaptiveContentWidth()
        }
        .background(Color(UIColor.systemBackground))
        .modelContainer(container)

        assertAllVariants(of: view, named: "woundEffectPanel_arme")
    }
}
