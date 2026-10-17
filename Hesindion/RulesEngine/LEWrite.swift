import Foundation

/// Every write that changes current LE reads `leMax` from `SheetValues.of(hero)?.leMax.result`,
/// which is `nil` while the rules engine has not loaded (`RulesEngineStore.shared`) or cannot
/// resolve `leMax` for the hero's sheet. Before this type existed, a `?? 0` at the write site
/// turned that `nil` into a real 0, and `min(current + amount, 0)` or `min(max(reversed, 0), 0)`
/// then wrote LE down to zero — final whole-branch review item 1. These are pure, so the nil
/// case is a plain unit test instead of a hero built to make `SheetValues.of(hero)` fail.
enum LEWrite {
    /// A heal/regenerate confirm's new current LE — `nil` when `leMax` is unknown, which the
    /// screen then reads as "nothing to write": the confirm button stays disabled and the
    /// screen shows `L("rulesEngine.unavailable")` where the target would be.
    static func healed(current: Int, amount: Int, leMax: Int?) -> Int? {
        guard let leMax else { return nil }
        return min(current + amount, leMax)
    }

    /// One LP-bar ±1 step — `nil` when `leMax` is unknown or the step would leave `[0, leMax]`.
    /// Both buttons disable together while `leMax` is unknown (`LPBarView`); before this fix
    /// the decrement's own guard (`current > 0`) had nothing to do with `leMax` at all, so it
    /// kept firing and wrote LE down against the unknown-as-zero maximum while only the
    /// increment was blocked.
    static func stepped(current: Int, by delta: Int, leMax: Int?) -> Int? {
        guard let leMax else { return nil }
        let next = current + delta
        guard next >= 0, next <= leMax else { return nil }
        return next
    }

    /// An undo (`Reversible.reverse`, `LogEntry.swift`): the value current LE had before the
    /// logged change, clamped to 0 below (LE cannot go negative) but left unclamped above when
    /// `leMax` is unknown — 0 is not a stand-in for "the maximum could not be computed", and
    /// clamping the restored value to it silently threw the undo away.
    static func undone(current: Int, lpChange: Int, leMax: Int?) -> Int {
        let reversed = max(current - lpChange, 0)
        guard let leMax else { return reversed }
        return min(reversed, leMax)
    }
}
