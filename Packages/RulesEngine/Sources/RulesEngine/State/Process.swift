import Foundation

// A process (spec §7): Zielen, Laden, Bogen spannen, a multi-action cast. It is data in the
// `Situation`, started and advanced by the action its `advancedBy` names, and ended by its
// completion or by `breaksOff` turning yes. It outlives the Kampfrunde.

/// A running process: which `process` effect started it, how far it is, and the item instance it
/// is bound to.
public struct ProcessState: Codable, Hashable, Sendable {
    /// The process's id (`laden`, `zielen`): the fact `process.<id>` reads its progress.
    public var id: String
    /// The rule of the `process` effect.
    public var rule: String
    /// The `process` effect itself (its `steps`, `breaksOff`, `completes`).
    public var origin: EffectOrigin
    /// The steps taken so far, 1 after the action that started it.
    public var progress: Int
    /// The steps it takes, fixed when it started (`{ of: item.ladezeit }` read then).
    public var steps: Int
    /// The Kampfrunde (`Clock.round`) it started in.
    public var startedRound: Int
    /// The item instance the process is bound to (`loadout.weapon.instance` when it started): its
    /// `completes` change that instance, whatever is in hand later (MIGRATION ladezeiten.LZ2).
    public var instance: String?

    public init(id: String, rule: String, origin: EffectOrigin, progress: Int, steps: Int, startedRound: Int,
                instance: String? = nil) {
        self.id = id; self.rule = rule; self.origin = origin; self.progress = progress; self.steps = steps
        self.startedRound = startedRound; self.instance = instance
    }

    /// The derived fact the rules read the progress as (`process.zielen`, owner derived).
    public static func fact(_ id: String) -> String { "process.\(id)" }
}
