import XCTest
import SnapshotTesting
import SwiftUI
@testable import Hesindion

/// The size chips on the attack announcement and on the defence screen: every
/// chip in a row has the same height (issue #38), whether it prints an AT
/// modifier or not.
final class CreatureSizeChipRowSnapshotTests: XCTestCase {

    @MainActor
    private var rows: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CreatureSizeChipRow(
                    size: .constant(.winzig),
                    detail: CreatureSizeChipRow.attackDetail,
                    identifierPrefix: "combat.opponent.size"
                )
                CreatureSizeChipRow(
                    size: .constant(.gross),
                    identifierPrefix: "combat.defense.size"
                )
            }
            .padding(16)
            .adaptiveContentWidth()
        }
        .background(Color(UIColor.systemBackground))
    }

    @MainActor
    func testSizeChips() {
        assertAllVariants(of: rows, named: "sizeChips")
    }
}
