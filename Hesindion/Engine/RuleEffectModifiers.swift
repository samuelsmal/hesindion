import Foundation

/// Loads ModifierDefinitions from the effects table in rules.db.
/// Effects with a non-nil `scope` are converted to ModifierDefinitions
/// that apply to the appropriate CheckDomains.
enum RuleEffectModifiers {

    /// Build modifier definitions from DB effects for the given hero's
    /// special abilities, advantages, and disadvantages.
    static func load(for hero: Hero) -> [ModifierDefinition] {
        var defs: [ModifierDefinition] = []

        // Collect all rule IDs the hero has, with their tiers
        let traitSources: [(ruleId: String, tier: Int)] =
            hero.combatSpecialAbilities.map { ($0.ruleId, $0.tier ?? 1) }
            + hero.generalSpecialAbilities.map { ($0.ruleId, $0.tier ?? 1) }
            + hero.advantages.map { ($0.ruleId, $0.tier ?? 1) }
            + hero.disadvantages.map { ($0.ruleId, $0.tier ?? 1) }

        for (ruleId, heroTier) in traitSources {
            let effects = RulesDatabase.shared.lookupEffects(ruleId: ruleId)
            for effect in effects {
                guard let scope = effect.scope,
                      let domains = domainsForScope(scope),
                      let rawValue = effect.value
                else { continue }

                let value = Int(rawValue)
                let effectLevel = effect.level
                let ruleName = RulesDatabase.shared.lookupByName(ruleId)?.name ?? ruleId

                let def = ModifierDefinition(
                    id: "\(ruleId)_\(effect.type)_\(effect.attribute ?? "none")_\(effectLevel ?? 0)",
                    domains: domains
                ) { _ in
                    // Only apply if the hero's tier matches the effect level (or effect has no level)
                    if let level = effectLevel, level != heroTier {
                        return nil
                    }
                    return ModifierLine(value: value, source: ruleName)
                }
                defs.append(def)
            }
        }

        return defs
    }

    private static func domainsForScope(_ scope: String) -> Set<CheckDomain>? {
        switch scope {
        case "meleeAttack":    return [.meleeAttack]
        case "meleeDefense":   return [.meleeParry, .meleeDodge]
        case "combat":         return [.meleeAttack, .meleeParry, .meleeDodge]
        case "ranged":         return [.rangedAttack]
        case "magic":          return [.spellCasting]
        case "liturgy":        return [.liturgyCasting]
        case "all":            return Set(CheckDomain.allCases)
        default:               return nil
        }
    }
}
