import XCTest
import SnapshotTesting
import SwiftUI
@testable import Hesindion

/// The round-start toast (issue #35): a Blutend round that also crosses a
/// Schmerz threshold, so the box shows the title and more than one line.
final class DSAToastSnapshotTests: XCTestCase {

    @MainActor
    func testRoundStart() {
        let toast = DSAToast(content: DSAToastContent(
            title: String(format: L("roundStart.title"), 3),
            lines: [RoundStartChange.bleedingLoss(lep: 1).text,
                    RoundStartChange.lebenspunkteSchmerz(levels: 1).text,
                    RoundStartChange.noDefenseEnded.text]
        ))
        .padding(16)
        .adaptiveContentWidth()
        .background(Color(UIColor.systemBackground))
        assertAllVariants(of: toast, named: "toast_roundStart")
    }
}
