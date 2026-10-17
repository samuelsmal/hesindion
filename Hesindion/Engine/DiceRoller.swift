import Foundation

/// Pure, testable dice rolling for DSA checks.
///
/// All randomness flows through an injectable `RandomNumberGenerator`. Production
/// code uses the system RNG (the no-generator convenience methods), while tests can
/// inject a seeded generator for deterministic runs or hammer the system RNG for
/// statistical validation — both exercise the exact same code path.
enum DiceRoller {

    /// Roll a single die with `sides` faces. Result is uniform in `1...sides`.
    static func roll<G: RandomNumberGenerator>(sides: Int, using generator: inout G) -> Int {
        precondition(sides >= 1, "A die needs at least one side")
        return Int.random(in: 1...sides, using: &generator)
    }

    /// Roll `count` dice with `sides` faces each.
    static func roll<G: RandomNumberGenerator>(count: Int, sides: Int, using generator: inout G) -> [Int] {
        precondition(count >= 0, "Cannot roll a negative number of dice")
        return (0..<count).map { _ in roll(sides: sides, using: &generator) }
    }

    /// Roll a single die using the system RNG (production default).
    static func roll(sides: Int) -> Int {
        #if DEBUG
        if let forced = ScriptedDice.next(sides: sides) { return forced }
        #endif
        var generator = SystemRandomNumberGenerator()
        return roll(sides: sides, using: &generator)
    }

    /// Roll `count` dice using the system RNG (production default).
    static func roll(count: Int, sides: Int) -> [Int] {
        precondition(count >= 0, "Cannot roll a negative number of dice")
        #if DEBUG
        if ScriptedDice.isActive {
            return (0..<count).map { _ in roll(sides: sides) }
        }
        #endif
        var generator = SystemRandomNumberGenerator()
        return roll(count: count, sides: sides, using: &generator)
    }
}

#if DEBUG
/// A queue of predetermined die results for UI tests.
///
/// ADR-0003 made the engine injectable, which is enough for unit tests — they
/// call `roll(using:)` directly. A UI test drives the real app, which uses the
/// no-generator overloads, so it had no way to control the outcome: the
/// take-damage flow turns on a resistance probe, and both branches have to be
/// reachable on demand rather than by rolling until the wanted one appears.
/// (`test03ReminderCard` retries up to five times for exactly this reason.)
///
/// Enabled only by `-dice-script`, and compiled out of Release entirely.
enum ScriptedDice {
    private static var queue: [Int] = []
    private static var loaded = false
    private static let lock = NSLock()

    /// `dice_script 20,1,7` — consumed in order, then the queue repeats so a
    /// short script can cover a longer flow.
    static var isActive: Bool {
        load()
        return !queue.isEmpty
    }

    static func next(sides: Int) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        loadLocked()
        guard !queue.isEmpty else { return nil }
        let value = queue.removeFirst()
        queue.append(value)          // repeat rather than run dry mid-flow
        return min(max(value, 1), sides)
    }

    private static func load() {
        lock.lock()
        defer { lock.unlock() }
        loadLocked()
    }

    private static func loadLocked() {
        guard !loaded else { return }
        loaded = true
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "dice_script"), idx + 1 < args.count else { return }
        queue = args[idx + 1].split(separator: ",").compactMap { Int($0) }
    }
}
#endif
