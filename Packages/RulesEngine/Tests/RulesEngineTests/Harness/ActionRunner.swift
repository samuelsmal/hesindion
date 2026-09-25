import Foundation
@testable import RulesEngine

/// The harness's door to the action layer (Tasks 25–28). A situation that needs something the
/// action layer cannot run yet is reported `unsupported`, not run.
///
/// Extension point: a task that makes the action layer run one of `Need` adds it to `supported`
/// and matches its expectations in `mismatches(_:engine:)` (steps of a `sequence`, dice,
/// `events`, the check stages `fp`/`qs`, `spent`, `success`, and the situation-level `result`).
enum ActionRunner {
    /// What makes a situation the action layer's: a `sequence`, dice (`rolls` as a list), or a
    /// situation-level expectation of events, check stages or a check's result.
    enum Need: String, CaseIterable, Codable {
        case sequence, rolls, events, fp, qs, spent, success
        /// The situation-level check result (`{success, kind, from}`, Task 26).
        case result
    }

    /// The needs the action layer can run. Empty until Task 26.
    static let supported: Set<Need> = []

    /// What `s` needs of the action layer, in `Need` order.
    static func needs(_ s: CompiledSituation) -> [Need] {
        Need.allCases.filter { need in
            switch need {
            case .sequence: !s.sequence.isEmpty
            case .rolls: !s.rolls.isEmpty
            default: s.expectSituation[need.rawValue] != nil
            }
        }
    }

    static func canRun(_ s: CompiledSituation) -> Bool {
        Set(needs(s)).isSubset(of: supported)
    }

    /// The mismatches of `s`'s action-layer expectations. Nothing runs before Task 26.
    static func mismatches(_ s: CompiledSituation, engine: Engine) -> [Mismatch] { [] }
}
