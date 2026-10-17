import Foundation
import RulesEngine

/// `Hero` → `HeroSheet` (sheet cut-over design §2): the only code that knows both models. Reads
/// unfolded inputs only — attributes, KtW, template ids, the SchemaV5 modifiers — never a stored
/// AT/PA. An item whose template has an equipment rule in the book enters under the rule's name.
enum HeroSheetMapping {
    /// The app's Fokusregeln that are an engine ruleset; the others have none.
    static let rulesets: [String: String] = [FokusRule.trefferzonen.rawValue: "fokus.trefferzonen"]

    static func sheet(for hero: Hero, book: RuleBook? = RulesEngineStore.shared?.engine.book) -> HeroSheet {
        var owned: [String: OwnedRule] = [:]
        // Cantrips and blessings belong to the magic domain, not to the sheet's values.
        let traits = hero.advantages + hero.disadvantages + hero.generalSpecialAbilities
            + hero.combatSpecialAbilities
        for t in traits where owned[t.ruleId] == nil { owned[t.ruleId] = OwnedRule(level: t.tier ?? 1) }

        var attributes: [String: Int] = [:]
        if let a = hero.attributes {
            attributes = ["MU": a.mu, "KL": a.kl, "IN": a.inValue, "CH": a.ch,
                          "FF": a.ff, "GE": a.ge, "KO": a.ko, "KK": a.kk]
        }
        let techniques = Dictionary(hero.combatTechniques.map { ($0.ruleId, $0.value) },
                                    uniquingKeysWith: { a, _ in a })
        let talents = Dictionary(hero.talents.map { ($0.ruleId, $0.value) },
                                 uniquingKeysWith: { a, _ in a })

        /// An item with an equipment rule in the book: the rule's name and template only (the rule
        /// provides its stats). Any other: the app's name and its own stats.
        func item(_ appName: String, template: String?, technique: String, at: Int?, pa: Int?) -> HeroSheet.Item {
            if let t = template, let rule = book?.rules[t], rule.kind == .equipment {
                return HeroSheet.Item(name: rule.name, template: t)
            }
            return HeroSheet.Item(name: appName, technique: technique, atMod: at, paMod: pa)
        }
        let weapons = hero.meleeWeaponsInOrder.map {
            item($0.name, template: $0.templateId, technique: $0.combatTechniqueId,
                 at: $0.atModifier, pa: $0.paModifier)
        }
        let shields = hero.shieldsInOrder.map {
            item($0.name, template: $0.templateId, technique: CombatTechniqueID.schilde.rawValue,
                 at: $0.atModifier, pa: $0.paModifier)
        }

        let worn = hero.armorsInOrder.filter(\.isEquipped)
        let loadout = HeroSheet.Loadout(
            weapon: hero.selectedWeapon.map { engineName($0.name, template: $0.templateId, book: book) },
            shield: hero.selectedShield.map { engineName($0.name, template: $0.templateId, book: book) },
            armour: worn.first?.name,
            armourBelastung: worn.reduce(0) { $0 + $1.encumbrance },
            armourExtraPenalty: worn.reduce(0) { $0 + $1.iniModifier })

        let dv = hero.derivedValues
        return HeroSheet(
            owned: owned, attributes: attributes, techniques: techniques, talents: talents,
            purchasedLE: dv?.lebensenergie.purchased ?? 0,
            speciesLE: dv?.speciesLE,
            speciesGS: dv.map { $0.geschwindigkeit.base },
            items: weapons + shields, loadout: loadout,
            rulesets: hero.fokusRules.compactMap { rulesets[$0] }.sorted())
    }

    /// The name the rules know an item by: its equipment rule's name when the book has one for
    /// its template, else the app's.
    static func engineName(_ appName: String, template: String?, book: RuleBook?) -> String {
        guard let t = template, let rule = book?.rules[t], rule.kind == .equipment else { return appName }
        return rule.name
    }
}
