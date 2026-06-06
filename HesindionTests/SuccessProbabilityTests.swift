import XCTest
@testable import Hesindion

/// Tests for the exact theoretical success probability of a DSA 5 skill check.
final class SuccessProbabilityTests: XCTestCase {

    /// Attributes 20/20/20 with ample FP: no die can exceed its threshold, so a
    /// check fails only on a critical failure (2+ twenties) = 58/8000 outcomes.
    func testUnlosableCheckOnlyFailsOnCrit() {
        XCTAssertEqual(
            SkillCheckEngine.successProbability(attributeValues: [20, 20, 20], skillPoints: 20),
            7942.0 / 8000.0, accuracy: 1e-9
        )
    }

    /// Boronmir's Verbergen: MU 14 / IN 13 / GE 14, FP 3 → 4362/8000 = 54.525%.
    func testBoronmirVerbergen() {
        XCTAssertEqual(
            SkillCheckEngine.successProbability(attributeValues: [14, 13, 14], skillPoints: 3),
            4362.0 / 8000.0, accuracy: 1e-9
        )
    }

    /// More skill points can never lower the success probability.
    func testMonotonicInSkillPoints() {
        let low = SkillCheckEngine.successProbability(attributeValues: [12, 12, 12], skillPoints: 0)
        let high = SkillCheckEngine.successProbability(attributeValues: [12, 12, 12], skillPoints: 5)
        XCTAssertGreaterThan(high, low)
    }

    /// A positive modifier (easier) can never lower the success probability.
    func testModifierMakesChecksEasier() {
        let base = SkillCheckEngine.successProbability(attributeValues: [13, 13, 13], skillPoints: 4)
        let eased = SkillCheckEngine.successProbability(attributeValues: [13, 13, 13], skillPoints: 4, modifier: 3)
        XCTAssertGreaterThanOrEqual(eased, base)
    }

    /// Probability is always a valid fraction of 8000.
    func testProbabilityInRange() {
        let p = SkillCheckEngine.successProbability(attributeValues: [10, 11, 9], skillPoints: 2)
        XCTAssertGreaterThanOrEqual(p, 0)
        XCTAssertLessThanOrEqual(p, 1)
        XCTAssertEqual((p * 8000).rounded(), p * 8000, accuracy: 1e-6, "Should be an exact n/8000")
    }
}
