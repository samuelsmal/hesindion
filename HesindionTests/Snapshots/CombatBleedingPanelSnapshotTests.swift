import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Hesindion

/// The Blutend panel on the combat root, in its two states: the duration not
/// yet rolled (Selbstbeherrschung), and the clock running (Heilkunde Wunden).
final class CombatBleedingPanelSnapshotTests: XCTestCase {

    @MainActor
    private func panel(roundsLeft: Int?) throws -> some View {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        hero.setStateLevel(BleedingRules.stateId, level: 1)
        hero.bleedingRoundsLeft = roundsLeft

        return ScrollView {
            CombatBleedingPanel(
                hero: hero,
                accent: combatAccent,
                onRollSelbstbeherrschung: {},
                onRollHeilkunde: {}
            )
            .padding(16)
            .adaptiveContentWidth()
        }
        .background(Color(UIColor.systemBackground))
        .modelContainer(container)
    }

    @MainActor
    func testDurationUnknown() throws {
        assertAllVariants(of: try panel(roundsLeft: nil), named: "bleedingPanel_unknown")
    }

    @MainActor
    func testClockRunning() throws {
        assertAllVariants(of: try panel(roundsLeft: 4), named: "bleedingPanel_clock")
    }
}
