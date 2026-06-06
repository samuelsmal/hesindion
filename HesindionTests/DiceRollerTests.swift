import XCTest
@testable import Hesindion

/// Statistical tests for the dice roller and the dice → skill-check pipeline.
///
/// Two flavours of test live here:
///
/// 1. **Deterministic** tests use a seeded generator (`SplitMix64`). They prove the
///    test harness and the chi-square math are correct, and that the roller is
///    reproducible — these never flake.
/// 2. **Statistical** tests hammer the real `SystemRandomNumberGenerator` (the exact
///    RNG the app ships with) and apply goodness-of-fit / independence checks. By
///    design these have a tiny false-positive rate: thresholds are set at the
///    α = 0.005 level, so each such test fails roughly 1 run in 200 even on a
///    perfectly fair die. If one fails in isolation, re-run before investigating.
final class DiceRollerTests: XCTestCase {

    // MARK: - Tuning (moderate N, balanced rigor)

    /// Rolls per single-die goodness-of-fit test.
    private let sampleSize = 50_000
    /// Full 3d20 checks for the end-to-end critical-rate test.
    private let checkSampleSize = 100_000

    // MARK: - Deterministic harness checks (seeded, never flake)

    /// Same seed → identical sequence. Guarantees reproducibility for any future
    /// regression test that needs fixed rolls.
    func testSeededRollsAreReproducible() {
        var a = SplitMix64(seed: 0xDEADBEEF)
        var b = SplitMix64(seed: 0xDEADBEEF)
        let rollsA = DiceRoller.roll(count: 1000, sides: 20, using: &a)
        let rollsB = DiceRoller.roll(count: 1000, sides: 20, using: &b)
        XCTAssertEqual(rollsA, rollsB)
    }

    /// Different seeds → different sequences (sanity that the seed actually matters).
    func testDifferentSeedsDiffer() {
        var a = SplitMix64(seed: 1)
        var b = SplitMix64(seed: 2)
        let rollsA = DiceRoller.roll(count: 1000, sides: 20, using: &a)
        let rollsB = DiceRoller.roll(count: 1000, sides: 20, using: &b)
        XCTAssertNotEqual(rollsA, rollsB)
    }

    /// All rolls must stay inside `1...sides` — no off-by-one, no zeros.
    func testRollsRespectBounds() {
        for sides in [3, 4, 6, 8, 10, 12, 20] {
            var gen = SplitMix64(seed: UInt64(sides))
            let rolls = DiceRoller.roll(count: 20_000, sides: sides, using: &gen)
            XCTAssertEqual(rolls.min(), 1, "W\(sides) produced a value below 1")
            XCTAssertEqual(rolls.max(), sides, "W\(sides) produced a value above \(sides) or never hit the max")
        }
    }

    /// The chi-square statistic on a *uniform synthetic* sample (each face exactly
    /// equally often) must be ~0 — proves the statistic isn't biased high.
    func testChiSquareOfPerfectlyUniformSampleIsZero() {
        let counts = Array(repeating: 100, count: 20)
        let chi = chiSquare(observed: counts, expectedPerBin: 100)
        XCTAssertEqual(chi, 0, accuracy: 1e-9)
    }

    // MARK: - Single-die uniformity (system RNG, statistical)

    func testD20IsUniform() { assertUniform(sides: 20) }
    func testD6IsUniform() { assertUniform(sides: 6) }
    func testD3IsUniform() { assertUniform(sides: 3) }

    /// Sample mean must sit close to the theoretical mean (sides + 1) / 2.
    /// Uses a z-test on the mean with a generous 4σ bound.
    func testD20MeanIsCorrect() {
        let rolls = DiceRoller.roll(count: sampleSize, sides: 20)
        let mean = Double(rolls.reduce(0, +)) / Double(sampleSize)
        let expectedMean = 10.5
        // Variance of a single d20 = (n^2 - 1) / 12 = 33.25
        let stdErr = (33.25 / Double(sampleSize)).squareRoot()
        let deviation = abs(mean - expectedMean)
        XCTAssertLessThan(
            deviation, 4 * stdErr,
            "d20 mean \(mean) deviates from 10.5 by \(deviation) (> 4σ = \(4 * stdErr))"
        )
    }

    /// Consecutive rolls must be uncorrelated (no serial dependence). Lag-1 Pearson
    /// correlation should be ~0; SE ≈ 1/√N, so we allow |r| < 4/√N.
    func testRollsAreSeriallyIndependent() {
        let rolls = DiceRoller.roll(count: sampleSize, sides: 20).map(Double.init)
        let r = lag1Correlation(rolls)
        let bound = 4.0 / Double(sampleSize).squareRoot()
        XCTAssertLessThan(
            abs(r), bound,
            "Lag-1 correlation \(r) exceeds ±\(bound) — rolls look serially dependent"
        )
    }

    // MARK: - End-to-end: dice → SkillCheckEngine (system RNG, statistical)

    /// Drive real 3d20 checks through the production roller and the skill-check
    /// engine, then verify the rate of critical successes (2+ ones) and critical
    /// failures (2+ twenties) matches DSA 5 theory.
    ///
    /// p(crit) = C(3,2)·p²·(1−p) + p³ with p = 1/20  →  0.007125 each.
    func testCriticalRatesMatchTheory() {
        let p = 1.0 / 20.0
        let expectedRate = 3 * p * p * (1 - p) + p * p * p   // 0.007125
        let n = checkSampleSize

        var critSuccess = 0
        var critFailure = 0
        for _ in 0..<n {
            let rolls = DiceRoller.roll(count: 3, sides: 20)
            // Attributes/skill are irrelevant to the critical rule; use neutral values.
            let outcome = SkillCheckEngine.evaluate(
                rolls: rolls,
                attributeValues: [14, 14, 14],
                skillPoints: 6
            )
            switch outcome {
            case .criticalSuccess: critSuccess += 1
            case .criticalFailure: critFailure += 1
            case .regular: break
            }
        }

        assertRateMatches(observed: critSuccess, n: n, expected: expectedRate, label: "critical success")
        assertRateMatches(observed: critFailure, n: n, expected: expectedRate, label: "critical failure")
    }

    /// A wide-open check (high attributes, ample FP, with criticals excluded) should
    /// almost always succeed — guards against the pipeline silently inverting success.
    func testTrivialCheckOverwhelminglySucceeds() {
        let n = 20_000
        var successes = 0
        for _ in 0..<n {
            let rolls = DiceRoller.roll(count: 3, sides: 20)
            let outcome = SkillCheckEngine.evaluate(
                rolls: rolls,
                attributeValues: [18, 18, 18],
                skillPoints: 18
            )
            if outcome.succeeded { successes += 1 }
        }
        // With attributes 18 and 18 FP, the only failures are double-20 criticals
        // (~0.7%), so success rate must be very high.
        let rate = Double(successes) / Double(n)
        XCTAssertGreaterThan(rate, 0.98, "Trivial check only succeeded \(rate * 100)% of the time")
    }

    // MARK: - Success probability vs. real ability profiles (system RNG, statistical)

    /// For realistic DSA ability profiles, the sampled success rate (dice → engine)
    /// must match the *exact* theoretical probability obtained by enumerating all
    /// 8000 equally-likely 3d20 outcomes through the same engine. This validates the
    /// dice and the check logic together against an independent ground truth.
    func testSuccessRateMatchesExactProbability() {
        struct Profile { let name: String; let attrs: [Int]; let fp: Int }
        let profiles = [
            Profile(name: "Klettern 13/12/14 FP4", attrs: [13, 12, 14], fp: 4),
            Profile(name: "Typical 14/13/12 FP6", attrs: [14, 13, 12], fp: 6),
            Profile(name: "Weak 11/11/11 FP0", attrs: [11, 11, 11], fp: 0),
            Profile(name: "Strong 16/15/15 FP10", attrs: [16, 15, 15], fp: 10),
        ]
        let n = 200_000
        for p in profiles {
            let exact = exactSuccessProbability(attrs: p.attrs, fp: p.fp)
            var successes = 0
            for _ in 0..<n {
                let rolls = DiceRoller.roll(count: 3, sides: 20)
                if SkillCheckEngine.evaluate(rolls: rolls, attributeValues: p.attrs, skillPoints: p.fp).succeeded {
                    successes += 1
                }
            }
            let sampled = Double(successes) / Double(n)
            let stdErr = (exact * (1 - exact) / Double(n)).squareRoot()
            XCTAssertLessThan(
                abs(sampled - exact), 4 * stdErr,
                "\(p.name): sampled \(sampled) vs exact \(exact), Δ exceeds 4σ (\(4 * stdErr))"
            )
        }
    }

    /// Exact theoretical success probability via the engine's enumeration.
    /// (Hand-verifiable cases are covered in `SuccessProbabilityTests`.)
    private func exactSuccessProbability(attrs: [Int], fp: Int) -> Double {
        SkillCheckEngine.successProbability(attributeValues: attrs, skillPoints: fp)
    }

    // MARK: - Helpers

    /// Run a chi-square goodness-of-fit test for uniformity against the system RNG.
    /// Fails only above the α = 0.005 critical value (≈1-in-200 false-positive rate).
    private func assertUniform(sides: Int, file: StaticString = #filePath, line: UInt = #line) {
        let rolls = DiceRoller.roll(count: sampleSize, sides: sides)

        var counts = Array(repeating: 0, count: sides)
        for r in rolls {
            XCTAssertTrue((1...sides).contains(r), "Out-of-range roll \(r) for W\(sides)", file: file, line: line)
            counts[r - 1] += 1
        }
        // Every face should appear at least once at this sample size.
        XCTAssertFalse(counts.contains(0), "W\(sides): some face never appeared", file: file, line: line)

        let expectedPerBin = Double(sampleSize) / Double(sides)
        let chi = chiSquare(observed: counts, expectedPerBin: expectedPerBin)
        let critical = chiSquareCritical005(df: sides - 1)

        XCTAssertLessThan(
            chi, critical,
            "W\(sides) chi-square \(chi) exceeds α=0.005 critical \(critical) (df=\(sides - 1)) — distribution looks non-uniform",
            file: file, line: line
        )
    }

    /// z-test that an observed count matches an expected binomial rate, 4σ bound.
    private func assertRateMatches(observed: Int, n: Int, expected: Double, label: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let mean = Double(n) * expected
        let stdDev = (Double(n) * expected * (1 - expected)).squareRoot()
        let deviation = abs(Double(observed) - mean)
        XCTAssertLessThan(
            deviation, 4 * stdDev,
            "\(label): observed \(observed), expected ≈\(mean) ±\(4 * stdDev) (4σ) — rate is off",
            file: file, line: line
        )
    }

    private func chiSquare(observed: [Int], expectedPerBin: Double) -> Double {
        observed.reduce(0.0) { acc, count in
            let diff = Double(count) - expectedPerBin
            return acc + (diff * diff) / expectedPerBin
        }
    }

    /// Pearson correlation between each value and its successor.
    private func lag1Correlation(_ x: [Double]) -> Double {
        let n = x.count - 1
        guard n > 1 else { return 0 }
        let a = Array(x[0..<n])
        let b = Array(x[1...])
        let meanA = a.reduce(0, +) / Double(n)
        let meanB = b.reduce(0, +) / Double(n)
        var cov = 0.0, varA = 0.0, varB = 0.0
        for i in 0..<n {
            let da = a[i] - meanA
            let db = b[i] - meanB
            cov += da * db
            varA += da * da
            varB += db * db
        }
        guard varA > 0, varB > 0 else { return 0 }
        return cov / (varA.squareRoot() * varB.squareRoot())
    }

    /// Upper-tail chi-square critical values at α = 0.005 for the degrees of freedom
    /// this test suite exercises (df = sides − 1 for d3/d6/d20).
    private func chiSquareCritical005(df: Int) -> Double {
        switch df {
        case 2: return 10.597   // d3
        case 5: return 16.750   // d6
        case 19: return 38.582  // d20
        default:
            XCTFail("No tabulated α=0.005 critical value for df=\(df); add it")
            return .infinity
        }
    }
}

/// Seedable PRNG (SplitMix64) for deterministic test runs. Test-only — production
/// dice use `SystemRandomNumberGenerator`.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
