import XCTest
import SnapshotTesting
import SwiftUI
@testable import Hesindion

/// The neobrutalism Switch (issue #37) on its own and inside `DSAToggleRow`, off
/// and on: an on/off option says its state with the switch, not with a fill.
final class DSASwitchSnapshotTests: XCTestCase {

    @MainActor
    private var rows: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    DSASwitch(isOn: .constant(false))
                    DSASwitch(isOn: .constant(true))
                    DSASwitch(isOn: .constant(true), accent: .groupMagic)
                }
                DSAToggleRow(title: "Ziel ist überrascht", isOn: .constant(false), detail: "+2")
                DSAToggleRow(
                    title: "Gegner kämpft zu Fuß",
                    isOn: .constant(true),
                    detail: "AT/VW +2",
                    subtitle: "Vorteilhafte Position"
                )
                DSAToggleRow(title: "Trefferzonen", isOn: .constant(true), subtitle: "Fokus-Regel", icon: "scope")
            }
            .padding(16)
            .adaptiveContentWidth()
        }
        .background(Color(UIColor.systemBackground))
    }

    @MainActor
    func testSwitchAndToggleRows() {
        assertAllVariants(of: rows, named: "switch")
    }
}
