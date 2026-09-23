import XCTest
@testable import Hesindion

/// `SkillCheckModal.emitResult` fires once from `roll()` and again from
/// `reroll()` (the Schip reroll offered on a plain failure), so
/// `CombatFluchtView`'s probe can report an outcome more than once for a
/// single Flucht. The log entry is written exactly once, when the probe
/// modal closes, guarded by `CombatFluchtView.shouldLogOutcome`. This
/// exercises that guard directly, without a SwiftUI harness.
final class CombatFluchtLoggingTests: XCTestCase {

    func testLogsOnceAFinalOutcomeExistsAndNothingHasLoggedItYet() {
        XCTAssertTrue(CombatFluchtView.shouldLogOutcome(hasOutcome: true, alreadyLogged: false))
    }

    func testDoesNotLogAgainOnceAlreadyLogged() {
        // The Schip-reroll case: a second `onRolled` (or a second modal
        // close) must not insert a second `combatAction` entry.
        XCTAssertFalse(CombatFluchtView.shouldLogOutcome(hasOutcome: true, alreadyLogged: true))
    }

    func testDoesNotLogWhenTheProbeClosedWithoutARoll() {
        XCTAssertFalse(CombatFluchtView.shouldLogOutcome(hasOutcome: false, alreadyLogged: false))
    }
}
