import Foundation

/// Status Blutend (https://dsa.ulisses-regelwiki.de/Status_Blutend.html).
enum BleedingRules {
    static let stateId = "blutend"

    /// Rounds the status lasts after the Selbstbeherrschung probe it demands:
    /// 7 − QS, twice that on a Patzer, none at all on a critical success.
    static func duration(qualityLevel: Int, succeeded: Bool, critical: Bool, fumble: Bool) -> Int {
        if critical { return 0 }
        let base = 7 - (succeeded ? qualityLevel : 0)
        return fumble ? base * 2 : base
    }

    /// Heilkunde Wunden shortens it by QS/2, rounded up (project convention).
    static func treatmentReduction(qs: Int) -> Int { (max(qs, 0) + 1) / 2 }
}

extension Hero {
    /// Starts (or, if already bleeding, possibly extends) the clock. A second
    /// Blutend does not stack: the longer duration wins.
    func startBleeding(rounds: Int) {
        guard rounds > 0 else {
            setStateLevel(BleedingRules.stateId, level: 0)
            bleedingRoundsLeft = nil
            return
        }
        setStateLevel(BleedingRules.stateId, level: 1)
        bleedingRoundsLeft = max(bleedingRoundsLeft ?? 0, rounds)
    }

    /// End of a Kampfrunde: 1 SP (Schadenspunkte — armour does not reduce it)
    /// while the status lasts. Returns the SP taken.
    @discardableResult
    func endOfRoundBleeding() -> Int {
        guard hasState(BleedingRules.stateId) else { return 0 }
        if let dv = derivedValues { dv.lebensenergie.current = max(0, dv.lebensenergie.current - 1) }
        if let left = bleedingRoundsLeft {
            if left <= 1 { startBleeding(rounds: 0) } else { bleedingRoundsLeft = left - 1 }
        }
        return 1
    }

    func treatBleeding(qs: Int) {
        guard let left = bleedingRoundsLeft else { return }
        let rest = left - BleedingRules.treatmentReduction(qs: qs)
        if rest <= 0 { startBleeding(rounds: 0) } else { bleedingRoundsLeft = rest }
    }
}
