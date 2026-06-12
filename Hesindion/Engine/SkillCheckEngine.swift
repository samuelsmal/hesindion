import Foundation

/// Result of a 3d20 skill check (Fertigkeitsprobe).
enum SkillCheckOutcome: Equatable {
    case criticalSuccess
    case criticalFailure
    /// Regular result with quality level (0 = failure, 1–6 = success).
    case regular(qs: Int, remainingFP: Int)

    var qualityLevel: Int {
        switch self {
        case .criticalSuccess: return 6
        case .criticalFailure: return 0
        case .regular(let qs, _): return qs
        }
    }

    var succeeded: Bool {
        switch self {
        case .criticalSuccess: return true
        case .criticalFailure: return false
        case .regular(let qs, _): return qs > 0
        }
    }
}

/// Pure computation for DSA 5 skill checks (Fertigkeitsproben).
///
/// Rules reference: https://dsa.ulisses-regelwiki.de/grundregeln/fertigkeitsproben.html
/// QS reference: https://dsa.ulisses-regelwiki.de/grundregeln/qualitaet-bei-talenten.html
enum SkillCheckEngine {

    /// Compute the outcome of a 3d20 skill check.
    ///
    /// - Parameters:
    ///   - rolls: Exactly 3 d20 results (1–20 each).
    ///   - attributeValues: The 3 attribute values for this check.
    ///   - skillPoints: The talent's Fertigkeitspunkte (FP).
    ///   - modifier: Global modifier applied to all 3 thresholds (positive = easier).
    static func evaluate(
        rolls: [Int],
        attributeValues: [Int],
        skillPoints: Int,
        modifier: Int = 0
    ) -> SkillCheckOutcome {
        precondition(rolls.count == 3 && attributeValues.count == 3)

        // Critical results: 2+ ones = critical success, 2+ twenties = critical failure
        let ones = rolls.filter { $0 == 1 }.count
        let twenties = rolls.filter { $0 == 20 }.count
        if ones >= 2 { return .criticalSuccess }
        if twenties >= 2 { return .criticalFailure }

        // Calculate remaining FP after consuming excesses
        var remaining = skillPoints
        for i in 0..<3 {
            let threshold = attributeValues[i] + modifier
            let excess = rolls[i] - threshold
            if excess > 0 { remaining -= excess }
        }

        if remaining < 0 { return .regular(qs: 0, remainingFP: remaining) }
        return .regular(qs: qualityLevel(for: remaining), remainingFP: remaining)
    }

    /// Exact probability that a check succeeds, by enumerating all 8000 equally
    /// likely 3d20 outcomes through `evaluate`. Pure and deterministic — this is the
    /// theoretical success rate shown per ability.
    ///
    /// - Parameters:
    ///   - attributeValues: The 3 attribute values for this check.
    ///   - skillPoints: The talent's Fertigkeitspunkte (FP).
    ///   - modifier: Global modifier applied to all 3 thresholds (positive = easier).
    static func successProbability(attributeValues: [Int], skillPoints: Int, modifier: Int = 0) -> Double {
        precondition(attributeValues.count == 3)
        var successes = 0
        for a in 1...20 {
            for b in 1...20 {
                for c in 1...20 {
                    if evaluate(rolls: [a, b, c], attributeValues: attributeValues,
                                skillPoints: skillPoints, modifier: modifier).succeeded {
                        successes += 1
                    }
                }
            }
        }
        return Double(successes) / 8000.0
    }

    /// Convert remaining FP to quality level (Qualitätsstufe).
    ///
    /// | FP    | QS |
    /// |-------|----|
    /// | 0–3   | 1  |
    /// | 4–6   | 2  |
    /// | 7–9   | 3  |
    /// | 10–12 | 4  |
    /// | 13–15 | 5  |
    /// | 16+   | 6  |
    static func qualityLevel(for remainingFP: Int) -> Int {
        guard remainingFP >= 0 else { return 0 }
        if remainingFP <= 3 { return 1 }
        if remainingFP <= 6 { return 2 }
        if remainingFP <= 9 { return 3 }
        if remainingFP <= 12 { return 4 }
        if remainingFP <= 15 { return 5 }
        return 6
    }
}
