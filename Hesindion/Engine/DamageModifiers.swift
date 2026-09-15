import Foundation

/// Every TP bonus the app can work out for itself, in one place.
///
/// The damage side had no equivalent of the `ModifierEngine`: each bonus was
/// folded into the formula string at whichever screen thought of it. Two screens
/// thought of the two-handed grip, so it was applied twice.
///
/// The lines and the formula come from the same call, so the box the player
/// reads and the formula the dice get cannot drift apart.
enum DamageModifiers {

    /// TP bonuses for a melee attack, in the order they are added.
    ///
    /// - Parameters:
    ///   - maneuver: the announced manoeuvre (Wuchtschlag is the one with TP).
    ///   - twoHandedGrip: the weapon is being held in both hands (+1 TP, -1 PA).
    ///   - mounted: the hero is on a mount, which some styles pay for.
    static func lines(
        hero: Hero,
        maneuver: CombatManeuver,
        twoHandedGrip: Bool,
        mounted: Bool
    ) -> [ModifierLine] {
        var lines: [ModifierLine] = []

        // Wuchtschlag (SA_67): +2 TP per tier, the attack 2 harder per tier.
        if maneuver.damageBonus != 0 {
            lines.append(ModifierLine(value: maneuver.damageBonus, source: maneuver.sourceLabel))
        }

        if twoHandedGrip {
            lines.append(ModifierLine(value: 1, source: L("source.twoHandedGrip")))
        }

        // Sturmangriff zu Pferd: +2 and half the mount's GS.
        if maneuver == .sturmangriff, hero.sturmangriffDamageBonus != 0 {
            lines.append(ModifierLine(value: hero.sturmangriffDamageBonus, source: L("source.sturmangriff")))
        }

        return lines
    }

    static func total(_ lines: [ModifierLine]) -> Int {
        lines.reduce(0) { $0 + $1.value }
    }

    /// The weapon's formula with every bonus folded in — `nil` for an action that
    /// deals no damage.
    static func applied(to formula: String?, lines: [ModifierLine]) -> String? {
        guard let formula else { return nil }
        return DamageFormula.adding(total(lines), to: formula)
    }
}
