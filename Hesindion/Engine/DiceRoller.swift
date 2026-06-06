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
        var generator = SystemRandomNumberGenerator()
        return roll(sides: sides, using: &generator)
    }

    /// Roll `count` dice using the system RNG (production default).
    static func roll(count: Int, sides: Int) -> [Int] {
        var generator = SystemRandomNumberGenerator()
        return roll(count: count, sides: sides, using: &generator)
    }
}
