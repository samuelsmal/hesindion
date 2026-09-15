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

    /// The catalog ids the Swift half below still stands for (the union test
    /// holds these apart from the implemented entries). The grip has no rule id.
    static let rules: [String] = [CombatAbility.berittenerKampf.rawValue]

    /// TP bonuses for a melee attack: the two the Swift side still makes, then
    /// what the catalog says for the `damage` domain.
    static func lines(situation: Situation) -> [ModifierLine] {
        precondition(situation.domain == .damage, "damage lines want the damage domain")
        var lines: [ModifierLine] = []

        if situation.round.twoHandedGrip {
            lines.append(ModifierLine(value: 1, source: L("source.twoHandedGrip")))
        }

        // Sturmangriff zu Pferd: +2 and half the mount's GS.
        if situation.maneuver == .sturmangriff, situation.hero.sturmangriffDamageBonus != 0 {
            lines.append(ModifierLine(value: situation.hero.sturmangriffDamageBonus, source: L("source.sturmangriff")))
        }

        lines += ModifierEngine.shared.evaluation(situation).lines.map(\.modifierLine)
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
