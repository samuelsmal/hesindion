import Foundation
import RulesEngine

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
    @MainActor
    static func lines(situation: Situation) -> [ModifierLine] {
        precondition(situation.domain == .damage, "damage lines want the damage domain")
        var lines: [ModifierLine] = []

        if situation.round.twoHandedGrip {
            lines.append(ModifierLine(value: 1, source: L("source.twoHandedGrip")))
        }

        // Sturmangriff zu Pferd (RK14): one line from the engine, the mount's current GS in it
        // (issue #48). A tap on the line's GS opens the mount's breakdown (CombatRootView).
        if situation.maneuver == .sturmangriff, let line = sturmangriffLine(hero: situation.hero) {
            lines.append(line)
        }

        lines += ModifierEngine.shared.evaluation(situation).lines.map(\.modifierLine)
        return lines
    }

    /// RK14's TP line for a hit with the Sturmangriff zu Pferd, evaluated by the engine with the
    /// mount's facts (`MountValues`). nil without a mount, without the rules, or when RK14 does
    /// not apply (no Berittener Kampf).
    @MainActor
    static func sturmangriffLine(hero: Hero) -> ModifierLine? {
        guard let mount = hero.mount, let values = MountValues.of(mount),
              let store = RulesEngineStore.shared else { return nil }
        let charge = RulesEngine.Situation(sheet: HeroSheetMapping.sheet(for: hero)).stating(values.facts.facts + [
            Fact(name: "hero.mounted", value: .bool(true), owner: .loadout),
            Fact(name: "choice.order", value: .string("sturmangriffZuPferd"), owner: .player),
            Fact(name: "action.gait", value: .string("galopp"), owner: .player),
            Fact(name: "action.attack", value: .string("hit"), owner: .player),
        ])
        let rk14 = store.engine.evaluate(Query("tp"), in: charge).lines
            .filter { $0.origin?.rule == "reiterkampf" && $0.origin?.clause == "RK14" }
        guard !rk14.isEmpty, let gs = values.gs.result else { return nil }
        return ModifierLine(value: rk14.reduce(0) { $0 + $1.value },
                            source: String(format: L("source.sturmangriff.rk14"), mount.name, gs))
    }

    static func total(_ lines: [ModifierLine]) -> Int {
        lines.reduce(0) { $0 + $1.value }
    }

    /// The multiplier the catalog puts on the rolled TP, as the damage screen
    /// already understands it. `RulesCatalogTests.testEveryTPMultiplierIsKnownAndAtMostOneRuleMultipliesTP`
    /// holds the whole catalog to one `tp` multiplier and a factor
    /// `CriticalDamage(factor:)` knows, so both assertions below are a
    /// test-time guarantee failing loudly rather than a path this call
    /// expects to hit.
    static func multiplier(situation: Situation) -> CriticalDamage {
        precondition(situation.domain == .damage, "damage multipliers want the damage domain")
        let tpMultipliers = ModifierEngine.shared.evaluation(situation).multipliers.filter { $0.target == .tp }
        guard let first = tpMultipliers.first else { return .unchanged }
        if tpMultipliers.count > 1 {
            assertionFailure("the damage screen shows one multiplier; two need DamageModifiers.multiplier to combine them")
        }
        guard let damage = CriticalDamage(factor: first.factor) else {
            assertionFailure("no CriticalDamage for factor \(first.factor) from \(first.ruleId)")
            return .unchanged
        }
        return damage
    }

    /// The weapon's formula with every bonus folded in — `nil` for an action that
    /// deals no damage.
    static func applied(to formula: String?, lines: [ModifierLine]) -> String? {
        guard let formula else { return nil }
        return DamageFormula.adding(total(lines), to: formula)
    }
}
