import Foundation

/// A rule that acts on the opponent after an attack, depending on how the
/// opponent defended (issue #41). The app does not roll the opponent's check —
/// the opponent is the GM's (ADR-0005) — so it states the check when it becomes
/// due, and says so when the defence took it away (ADR-0018).
///
/// The only one today is the mount's Mächtiger Schlag
/// (specs/rules/creatures/maechtiger-schlag.yaml).
struct AttackFollowUp: Equatable {

    /// What the GM said on the opponent-defence screen.
    enum DefenceOutcome {
        case parried, dodged, hit
    }

    enum Resolution: Equatable {
        case due
        case notApplied(reason: String)
    }

    let name: String
    /// What the opponent has to do, then why, one line each.
    let lines: [String]
    /// Whether a successful dodge takes the follow-up away.
    let avoidedByDodge: Bool

    func resolution(after outcome: DefenceOutcome) -> Resolution {
        if outcome == .dodged && avoidedByDodge {
            return .notApplied(reason: L("followUp.dodged"))
        }
        return .due
    }

    func toast(after outcome: DefenceOutcome) -> DSAToastContent {
        switch resolution(after: outcome) {
        case .due:
            DSAToastContent(title: name, lines: lines)
        case .notApplied(let reason):
            DSAToastContent(title: String(format: L("followUp.notApplied"), name), lines: [reason])
        }
    }

    // MARK: - Mächtiger Schlag

    /// MS1–MS3: on a successful attack the opponent rolls Kraftakt or is Liegend;
    /// only a dodge avoids it. The size condition (mittel or smaller) is a line
    /// of its own: nothing on the mount's attack path states the opponent's size.
    ///
    /// The penalty is the KK of `creature`, the one that has the SF and strikes
    /// (MS2) — never the rider's. Its line names the creature.
    static func mightyBlow(creature: String, kk: Int) -> AttackFollowUp {
        let penalty = mightyBlowPenalty(kk: kk)
        var lines = [
            penalty == 0
                ? L("mightyBlow.checkNoPenalty")
                : String(format: L("mightyBlow.check"), "−\(-penalty)")
        ]
        if penalty != 0 {
            lines.append(String(format: L("mightyBlow.penalty"), creature, kk, kk - 20))
        }
        lines.append(L("mightyBlow.size"))
        return AttackFollowUp(name: L("mightyBlow.name"), lines: lines, avoidedByDodge: true)
    }

    /// MS2: half the points of KK above 20, rounded up (KK 23 → −2, KK 26 → −3).
    static func mightyBlowPenalty(kk: Int) -> Int {
        guard kk > 20 else { return 0 }
        return -((kk - 20 + 1) / 2)
    }
}
