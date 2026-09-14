import Foundation

/// A weapon's damage as the app gets it from the import: `"1W6+4"`, `"2W6"`,
/// `"1W6-1"`.
///
/// Four screens carried their own copy of the parsing regex and three carried a
/// second one for adding a bonus to it. That is how a two-handed grip came to
/// add its +1 twice: one copy folded the bonus in at the weapon list, another at
/// the announcement, and neither could see the other.
///
/// Pure value type, no SwiftUI: the arithmetic the dice depend on is testable
/// without a view.
struct DamageFormula: Equatable {
    let count: Int
    let sides: Int
    let bonus: Int

    /// Lenient: reads the first `NWM(+K)` it finds anywhere in the string, so a
    /// formula with a trailing note still yields its dice.
    static func parse(_ formula: String) -> DamageFormula? {
        let pattern = /(\d+)W(\d+)([+-]\d+)?/
        guard let match = formula.firstMatch(of: pattern) else { return nil }
        return DamageFormula(
            count: Int(match.1) ?? 1,
            sides: Int(match.2) ?? 6,
            bonus: match.3.flatMap { Int($0) } ?? 0
        )
    }

    /// Adds `bonus` to a formula and returns it as a string again, or returns the
    /// formula untouched when it is not a plain `NWM(+K)` — a string this cannot
    /// parse in full is one it must not rewrite.
    static func adding(_ bonus: Int, to formula: String) -> String {
        guard bonus != 0 else { return formula }
        let pattern = /^(\d+W\d+)([+-]\d+)?$/
        guard let match = formula.firstMatch(of: pattern) else { return formula }
        let dice = String(match.1)
        let existing = match.2.flatMap { Int($0) } ?? 0
        let total = existing + bonus
        if total == 0 { return dice }
        return total > 0 ? "\(dice)+\(total)" : "\(dice)\(total)"
    }

    /// `"1W6+4"` — the way it is printed on the screens.
    var text: String {
        let dice = "\(count)W\(sides)"
        if bonus == 0 { return dice }
        return bonus > 0 ? "\(dice)+\(bonus)" : "\(dice)\(bonus)"
    }
}
