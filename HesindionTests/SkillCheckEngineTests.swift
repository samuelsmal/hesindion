import XCTest
@testable import Hesindion

/// Tests for DSA 5 skill check (Fertigkeitsprobe) and quality level (Qualitätsstufe) computation.
///
/// Rules references:
/// - Fertigkeitsproben: https://dsa.ulisses-regelwiki.de/grundregeln/fertigkeitsproben.html
/// - Qualität bei Talenten: https://dsa.ulisses-regelwiki.de/grundregeln/qualitaet-bei-talenten.html
final class SkillCheckEngineTests: XCTestCase {

    // MARK: - Qualitätsstufen-Tabelle (QS Table)
    //
    // | Remaining FP | QS |
    // |--------------|----|
    // | 0–3          | 1  |
    // | 4–6          | 2  |
    // | 7–9          | 3  |
    // | 10–12        | 4  |
    // | 13–15        | 5  |
    // | 16+          | 6  |

    func testQualityLevelTable() {
        // Negative FP → QS 0 (failure)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: -5), 0)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: -1), 0)

        // FP 0–3 → QS 1
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 0), 1)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 1), 1)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 2), 1)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 3), 1)

        // FP 4–6 → QS 2
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 4), 2)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 5), 2)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 6), 2)

        // FP 7–9 → QS 3
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 7), 3)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 8), 3)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 9), 3)

        // FP 10–12 → QS 4
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 10), 4)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 11), 4)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 12), 4)

        // FP 13–15 → QS 5
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 13), 5)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 14), 5)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 15), 5)

        // FP 16+ → QS 6
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 16), 6)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 17), 6)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 20), 6)
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 100), 6)
    }

    // MARK: - Geron Example from Rulebook
    //
    // Geron: Fährtensuchen (tierische Spuren) FW 7
    // Probe: MU 13, IN 12, GE 14
    // Rolls: MU → 10, IN → 18, GE → ?
    //
    // MU: 10 ≤ 13 → 0 FP consumed
    // IN: 18 - 12 = 6 excess → 6 FP consumed (7 - 6 = 1 remaining)
    // GE: if ≤ 15 → succeeds (1 FP left covers up to 1 excess)

    func testGeronExampleSuccess() {
        // Geron rolls: MU=10, IN=18, GE=14 (exactly at attribute value)
        let result = SkillCheckEngine.evaluate(
            rolls: [10, 18, 14],
            attributeValues: [13, 12, 14],
            skillPoints: 7
        )
        // MU: 0 excess, IN: 6 excess, GE: 0 excess → 7 - 6 = 1 remaining
        XCTAssertEqual(result, .regular(qs: 1, remainingFP: 1))
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.qualityLevel, 1)
    }

    func testGeronExampleExactlyPasses() {
        // Geron rolls: MU=10, IN=18, GE=15 (1 over GE 14, uses last FP)
        let result = SkillCheckEngine.evaluate(
            rolls: [10, 18, 15],
            attributeValues: [13, 12, 14],
            skillPoints: 7
        )
        // MU: 0, IN: 6, GE: 1 → 7 - 7 = 0 remaining → QS 1 (still succeeded!)
        XCTAssertEqual(result, .regular(qs: 1, remainingFP: 0))
        XCTAssertTrue(result.succeeded, "0 remaining FP should still be a success per rules")
    }

    func testGeronExampleFails() {
        // Geron rolls: MU=10, IN=18, GE=16 (2 over GE 14, needs 2 FP but only 1 left)
        let result = SkillCheckEngine.evaluate(
            rolls: [10, 18, 16],
            attributeValues: [13, 12, 14],
            skillPoints: 7
        )
        // MU: 0, IN: 6, GE: 2 → 7 - 8 = -1 remaining → failure
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.qualityLevel, 0)
    }

    // MARK: - FP Consumption Rules
    //
    // "Die eingesetzten Punkte stehen für die übrigen Teilproben nicht mehr zur Verfügung."
    // "Es ist egal, wie weit bei einer Teilprobe unter den Eigenschaftswert gewürfelt wird,
    //  der Held erhält dadurch keine zusätzlichen Punkte."

    func testRollingUnderAttributeDoesNotGainFP() {
        // Roll 2 on attribute 15 → 13 under, but NO bonus FP
        // Roll 19 on attribute 10 → 9 excess, needs 9 FP
        let result = SkillCheckEngine.evaluate(
            rolls: [2, 19, 3],
            attributeValues: [15, 10, 15],
            skillPoints: 8
        )
        // Die 1: 0 excess (rolling far under grants nothing extra)
        // Die 2: 19 - 10 = 9 excess
        // Die 3: 0 excess
        // 8 - 9 = -1 → failure (despite rolling very low on die 1 and 3)
        XCTAssertFalse(result.succeeded)
    }

    func testAllRollsUnderAttributes() {
        // All rolls well under attributes → all FP retained
        let result = SkillCheckEngine.evaluate(
            rolls: [5, 3, 2],
            attributeValues: [13, 12, 14],
            skillPoints: 10
        )
        // No excess anywhere → 10 FP remaining → QS 4
        XCTAssertEqual(result, .regular(qs: 4, remainingFP: 10))
    }

    func testAllRollsExactlyAtAttributes() {
        // All rolls match attribute values exactly → 0 excess each
        let result = SkillCheckEngine.evaluate(
            rolls: [13, 12, 14],
            attributeValues: [13, 12, 14],
            skillPoints: 7
        )
        // 0 excess → 7 FP remaining → QS 3
        XCTAssertEqual(result, .regular(qs: 3, remainingFP: 7))
    }

    func testZeroSkillPointsExactRolls() {
        // FW 0 with all rolls at or under attributes → 0 FP remaining → QS 1 (success!)
        let result = SkillCheckEngine.evaluate(
            rolls: [10, 10, 10],
            attributeValues: [12, 12, 12],
            skillPoints: 0
        )
        XCTAssertEqual(result, .regular(qs: 1, remainingFP: 0))
        XCTAssertTrue(result.succeeded)
    }

    func testZeroSkillPointsAnyExcess() {
        // FW 0, one roll 1 over → 0 - 1 = -1 → failure
        let result = SkillCheckEngine.evaluate(
            rolls: [13, 10, 10],
            attributeValues: [12, 12, 12],
            skillPoints: 0
        )
        XCTAssertFalse(result.succeeded)
    }

    // MARK: - Critical Results
    //
    // Per DSA 5 rules:
    // - 2 or more 1s → Kritischer Erfolg (critical success)
    // - 2 or more 20s → Patzer (critical failure/fumble)

    func testTwoOnesIsCriticalSuccess() {
        let result = SkillCheckEngine.evaluate(
            rolls: [1, 1, 15],
            attributeValues: [10, 10, 10],
            skillPoints: 5
        )
        XCTAssertEqual(result, .criticalSuccess)
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.qualityLevel, 6)
    }

    func testThreeOnesIsCriticalSuccess() {
        let result = SkillCheckEngine.evaluate(
            rolls: [1, 1, 1],
            attributeValues: [10, 10, 10],
            skillPoints: 5
        )
        XCTAssertEqual(result, .criticalSuccess)
    }

    func testTwoTwentiesIsCriticalFailure() {
        let result = SkillCheckEngine.evaluate(
            rolls: [20, 20, 5],
            attributeValues: [15, 15, 15],
            skillPoints: 20
        )
        XCTAssertEqual(result, .criticalFailure)
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.qualityLevel, 0)
    }

    func testThreeTwentiesIsCriticalFailure() {
        let result = SkillCheckEngine.evaluate(
            rolls: [20, 20, 20],
            attributeValues: [15, 15, 15],
            skillPoints: 20
        )
        XCTAssertEqual(result, .criticalFailure)
    }

    func testOneOneAndOneTwentyIsNotCritical() {
        // Only 1 of each → no critical, evaluate normally
        let result = SkillCheckEngine.evaluate(
            rolls: [1, 20, 10],
            attributeValues: [12, 12, 12],
            skillPoints: 10
        )
        // Not critical → regular check
        // Die 1: 1 ≤ 12 → 0 excess
        // Die 2: 20 - 12 = 8 excess
        // Die 3: 10 ≤ 12 → 0 excess
        // 10 - 8 = 2 → QS 1
        XCTAssertEqual(result, .regular(qs: 1, remainingFP: 2))
    }

    // MARK: - Modifiers
    //
    // Positive modifier = easier (effectively raises attribute thresholds)
    // Negative modifier = harder (effectively lowers attribute thresholds)

    func testPositiveModifierMakesCheckEasier() {
        // Without modifier: rolls [15, 15, 15] vs attrs [12, 12, 12], FP 3
        // Each die: 15 - 12 = 3 excess → total 9 excess → 3 - 9 = -6 → failure
        let withoutMod = SkillCheckEngine.evaluate(
            rolls: [15, 15, 15],
            attributeValues: [12, 12, 12],
            skillPoints: 3
        )
        XCTAssertFalse(withoutMod.succeeded)

        // With +3 modifier: thresholds become 15 → 0 excess each → 3 FP → QS 1
        let withMod = SkillCheckEngine.evaluate(
            rolls: [15, 15, 15],
            attributeValues: [12, 12, 12],
            skillPoints: 3,
            modifier: 3
        )
        XCTAssertTrue(withMod.succeeded)
        XCTAssertEqual(withMod, .regular(qs: 1, remainingFP: 3))
    }

    func testNegativeModifierMakesCheckHarder() {
        // Without modifier: rolls [10, 10, 10] vs attrs [12, 12, 12], FP 5
        // 0 excess → 5 FP → QS 2
        let withoutMod = SkillCheckEngine.evaluate(
            rolls: [10, 10, 10],
            attributeValues: [12, 12, 12],
            skillPoints: 5
        )
        XCTAssertEqual(withoutMod, .regular(qs: 2, remainingFP: 5))

        // With -3 modifier: thresholds become 9
        // Each die: 10 - 9 = 1 excess → total 3 → 5 - 3 = 2 FP → QS 1
        let withMod = SkillCheckEngine.evaluate(
            rolls: [10, 10, 10],
            attributeValues: [12, 12, 12],
            skillPoints: 5,
            modifier: -3
        )
        XCTAssertEqual(withMod, .regular(qs: 1, remainingFP: 2))
    }

    // MARK: - QS Boundary Cases from Klettern Example
    //
    // Rulebook: Geron climbs, keeps 12 FP → QS 4
    // "12 FP entspricht der vierten QS der Tabelle"

    func testKletternExampleQS4() {
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 12), 4)
    }

    // MARK: - Layariel Holzbearbeitung Example
    //
    // "Bei der Probe bleiben 4 FP übrig" → QS 2
    // (The text says "jede QS über der ersten", implying QS 2 with 4 FP)

    func testLayarielExampleQS2() {
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 4), 2)
    }

    // MARK: - Rowena Betören Example
    //
    // "15 FP übrig" → QS 5

    func testRowenaExample15FPIsQS5() {
        XCTAssertEqual(SkillCheckEngine.qualityLevel(for: 15), 5)
    }

    // MARK: - Edge Cases

    func testHighSkillPointsCapAtQS6() {
        let result = SkillCheckEngine.evaluate(
            rolls: [5, 5, 5],
            attributeValues: [15, 15, 15],
            skillPoints: 20
        )
        // 0 excess → 20 FP remaining → QS 6 (capped)
        XCTAssertEqual(result.qualityLevel, 6)
        if case .regular(_, let fp) = result {
            XCTAssertEqual(fp, 20)
        }
    }

    func testExactlyZeroRemainingIsSuccess() {
        // "Auch eine Probe, bei der du keine Punkte mehr übrighast, gilt als gelungen."
        let result = SkillCheckEngine.evaluate(
            rolls: [15, 12, 14],
            attributeValues: [12, 12, 12],
            skillPoints: 5
        )
        // Die 1: 15 - 12 = 3, Die 2: 0, Die 3: 14 - 12 = 2 → 5 - 5 = 0
        XCTAssertEqual(result, .regular(qs: 1, remainingFP: 0))
        XCTAssertTrue(result.succeeded, "0 remaining FP must be a success")
    }

    func testMinusOneRemainingIsFailure() {
        let result = SkillCheckEngine.evaluate(
            rolls: [15, 12, 15],
            attributeValues: [12, 12, 12],
            skillPoints: 5
        )
        // Die 1: 3, Die 2: 0, Die 3: 3 → 5 - 6 = -1
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.qualityLevel, 0)
    }
}
