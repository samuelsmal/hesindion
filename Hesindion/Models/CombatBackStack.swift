import Foundation

/// Where the attack flow's back button goes (issue #40): to the screen the
/// player came from.
///
/// Each screen used to name one fixed back target, and the attack reaches its
/// screens by several paths — the root goes straight to the announcement for a
/// plain weapon, the attack choice goes there for a grip or a mounted swing, the
/// weapon list for a shield or two weapons. So back from the AT roll skipped the
/// announcement, and back from an announcement opened a weapon list the player
/// never saw. `CombatView` records every step the flow leaves and clears the
/// record at the root.
///
/// Vorstoß is the one thing the announcement writes onto the round as it moves
/// on. A step's entry keeps the flag as it was when that step *opened*, so going
/// back to the announcement takes a Vorstoß back with it, and a Vorstoß from an
/// earlier attack this round stays.
struct CombatBackStack {
    struct Entry {
        let step: CombatStep
        let vorstossActiveThisRound: Bool
    }

    private var entries: [Entry] = []
    /// The flag as it stood when the current step opened.
    private var currentStepVorstoss = false

    /// The flow leaves `step`; `vorstossActiveThisRound` is the flag now, as
    /// the next step opens. The Reiten check before a mounted attack is not
    /// recorded: it is rolled once, and back goes past it.
    mutating func advance(from step: CombatStep, vorstossActiveThisRound: Bool) {
        if case .mountPreCheck = step {} else {
            entries.append(Entry(step: step, vorstossActiveThisRound: currentStepVorstoss))
        }
        currentStepVorstoss = vorstossActiveThisRound
    }

    /// The step to return to, or `nil` when nothing is recorded.
    mutating func back() -> Entry? {
        guard let entry = entries.popLast() else { return nil }
        currentStepVorstoss = entry.vorstossActiveThisRound
        return entry
    }

    mutating func clear(vorstossActiveThisRound: Bool) {
        entries.removeAll()
        currentStepVorstoss = vorstossActiveThisRound
    }
}
