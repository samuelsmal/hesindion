import XCTest
import SwiftData
@testable import Hesindion

/// Design §4, "what fails the build": an `implemented` clause that cannot fire.
/// Because the vocabulary is closed, every predicate has a known satisfying
/// assignment; this builds it and asserts the rule applied.
@MainActor
final class RuleReachabilityTests: XCTestCase {

    func testEveryImplementedClauseCanFire() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        let catalog = RuleCatalog.bundled
        XCTAssertFalse(catalog.implemented.isEmpty, "nothing is implemented; the fixtures are gone")
        for rule in catalog.implemented {
            for (index, clause) in rule.clauses.enumerated() {
                for domain in clause.domains {
                    let context = ModelContext(try TestData.makeContainer())
                    let hero = Hero(name: "Reach")
                    context.insert(hero)
                    var situation = Situation(hero: hero, domain: domain)
                    var visited: Set<String> = []
                    satisfy(rule, clause, in: catalog, hero: hero, situation: &situation, visited: &visited)
                    let evaluation = RuleEvaluator.evaluate(catalog: catalog, situation: situation)
                    XCTAssertTrue(
                        evaluation.applied.contains(rule.id),
                        "\(rule.id) clause \(index) in \(domain) did not fire: \(evaluation.notApplied.filter { $0.ruleId == rule.id }.map(\.reason)), questions \(evaluation.questions.map(\.key))"
                    )
                }
            }
        }
    }

    /// Vocabulary the fifteen `implemented` entries do not reach yet. Not a
    /// license to grow the vocabulary further without saying why — each entry
    /// here names the rule that will use it and the test that, meanwhile,
    /// exercises its interpreter directly so it is not untested in between.
    ///
    /// - `.heroHasRule`: every `implemented` entry today gates on its *own*
    ///   ownership (`needsOwnership`); nothing yet gates on owning a
    ///   *different* rule at a tier, the way e.g. a prerequisite chain would.
    ///   `RuleEvaluatorTests.testHeroHasRuleGatesOnOwnershipOfAnotherRuleAtAGivenTier`
    ///   exercises the interpreter (`RuleEvaluator.test(_:_:)`, `.heroHasRule` case).
    private let notYetUsed: Set<RuleVocabulary.Predicate> = [.heroHasRule]
    private let notYetUsedEffects: Set<RuleVocabulary.Effect> = []

    /// The other direction: the vocabulary is scoped to what the fixtures need,
    /// so a predicate or effect no entry uses has no interpreter anyone exercised.
    func testEveryVocabularyItemIsUsedByAnImplementedClause() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        var predicates: Set<RuleVocabulary.Predicate> = []
        var effects: Set<RuleVocabulary.Effect> = []
        for rule in RuleCatalog.bundled.implemented {
            if let gate = rule.appliesWith { collect(gate, into: &predicates) }
            for clause in rule.clauses {
                if let when = clause.when { collect(when, into: &predicates) }
                for effect in clause.effects { collect(effect, into: &effects) }
            }
        }
        XCTAssertEqual(predicates.union(notYetUsed), Set(RuleVocabulary.Predicate.allCases),
                       "unused and not allow-listed: \(Set(RuleVocabulary.Predicate.allCases).subtracting(predicates).subtracting(notYetUsed))")
        XCTAssertTrue(notYetUsed.isDisjoint(with: predicates),
                     "allow-listed but actually used by an implemented clause — drop from notYetUsed: \(notYetUsed.intersection(predicates))")
        XCTAssertEqual(effects.union(notYetUsedEffects), Set(RuleVocabulary.Effect.allCases),
                       "unused and not allow-listed: \(Set(RuleVocabulary.Effect.allCases).subtracting(effects).subtracting(notYetUsedEffects))")
        XCTAssertTrue(notYetUsedEffects.isDisjoint(with: effects),
                     "allow-listed but actually used by an implemented clause — drop from notYetUsedEffects: \(notYetUsedEffects.intersection(effects))")
    }

    private func collect(_ p: RulePredicate, into set: inout Set<RuleVocabulary.Predicate>) {
        switch p {
        case .all(let parts), .any(let parts): parts.forEach { collect($0, into: &set) }
        case .not(let part): collect(part, into: &set)
        case .heroHasRule: set.insert(.heroHasRule)
        case .heroState: set.insert(.heroState)
        case .heroFokusRule: set.insert(.heroFokusRule)
        case .loadoutWeapon: set.insert(.loadoutWeapon)
        case .loadoutShield: set.insert(.loadoutShield)
        case .loadoutReach: set.insert(.loadoutReach)
        case .situationMounted: set.insert(.situationMounted)
        case .situationBeengt: set.insert(.situationBeengt)
        case .situationDefencesThisRound: set.insert(.situationDefencesThisRound)
        case .situationTargetZone: set.insert(.situationTargetZone)
        case .situationWoundEffect: set.insert(.situationWoundEffect)
        case .opponentReach: set.insert(.opponentReach)
        case .opponentOnFoot: set.insert(.opponentOnFoot)
        case .opponentState: set.insert(.opponentState)
        case .opponentType: set.insert(.opponentType)
        case .gmFact: set.insert(.gmFact)
        }
    }

    private func collect(_ e: RuleEffect, into set: inout Set<RuleVocabulary.Effect>) {
        switch e {
        case .add: set.insert(.add)
        case .multiply: set.insert(.multiply)
        case .opponentAdd: set.insert(.opponentAdd)
        case .modifyRule: set.insert(.modifyRule)
        case .choice(let options): set.insert(.choice); options.forEach { collect($0, into: &set) }
        }
    }

    // MARK: - Building a situation that satisfies a clause

    private func satisfy(_ rule: CatalogRule, _ clause: RuleClause, in catalog: RuleCatalog,
                         hero: Hero, situation s: inout Situation, visited: inout Set<String>) {
        guard visited.insert(rule.id).inserted else { return }
        if rule.needsOwnership && hero.ownedRuleTier(rule.id) == nil {
            hero.combatSpecialAbilities.append(HeroTrait(ruleId: rule.id, name: rule.name, tier: 3, sid: nil))
        }
        if let gate = rule.appliesWith { satisfy(gate, hero: hero, situation: &s) }
        if let when = clause.when { satisfy(when, hero: hero, situation: &s) }
        if clause.kind == .offer {
            if case .choice(let options)? = clause.effects.first {
                // Take the option that has something to say in this domain.
                let fitting = options.firstIndex { option in
                    guard let target = target(of: option) else { return false }
                    if case .talent(let id) = target { s.talentId = id }
                    return target.applies(in: s.domain, talentId: s.talentId)
                }
                s.choices[rule.id] = fitting ?? 0
            } else {
                s.announced[rule.id] = 1
            }
        }
        for effect in clause.effects {
            switch effect {
            case .add(let target, _, _), .multiply(let target, _), .opponentAdd(let target, _):
                if case .talent(let id) = target { s.talentId = id }
            case .modifyRule(let id, let target, _, _, _):
                if case .talent(let talentId) = target { s.talentId = talentId }
                guard let modified = catalog.rules[id] else { continue }
                // The modified rule must be in effect on the same target in this domain.
                let base = modified.clauses.first { c in
                    c.domains.contains(s.domain) && c.effects.contains { e in
                        if case .add(let t, _, _) = e { return t == target }
                        return false
                    }
                }
                if let base { satisfy(modified, base, in: catalog, hero: hero, situation: &s, visited: &visited) }
            case .choice:
                break   // the option was chosen above
            }
        }
    }

    private func target(of effect: RuleEffect) -> RuleTarget? {
        switch effect {
        case .add(let t, _, _), .multiply(let t, _), .opponentAdd(let t, _), .modifyRule(_, let t, _, _, _): t
        case .choice: nil
        }
    }

    private func satisfy(_ predicate: RulePredicate, hero: Hero, situation s: inout Situation) {
        switch predicate {
        case .all(let parts):
            parts.forEach { satisfy($0, hero: hero, situation: &s) }
        case .any(let parts):
            if let first = parts.first { satisfy(first, hero: hero, situation: &s) }
        case .not:
            break   // everything the generator does not set is already false
        case .heroHasRule(let id, let minTier):
            hero.combatSpecialAbilities.append(HeroTrait(ruleId: id, name: id, tier: minTier, sid: nil))
        case .heroState(let id, let minLevel):
            hero.setStateLevel(id, level: minLevel)
        case .heroFokusRule(let raw):
            if let rule = FokusRule(rawValue: raw) { hero.setFokusRule(rule, active: true) }
        case .loadoutWeapon(let technique, let item, let consecrated):
            let name = item ?? "Testwaffe"
            let weapon = weapon(named: name, technique: technique?.first ?? "CT_12", hero: hero)
            hero.selectedWeaponName = weapon.name
            s.loadoutName = weapon.name
            if consecrated == true { hero.setConsecrated(weapon.name, true) }
        case .loadoutShield(let item):
            let name = item ?? "Testschild"
            if !hero.shields.contains(where: { $0.name == name }) {
                hero.shields.append(Shield(name: name, damage: "1W6", at: 6, pa: 10, reach: "Kurz", structurePoints: 20, weight: 5))
            }
            hero.selectedShieldName = name
        case .loadoutReach(let reach):
            let name = s.loadoutName ?? hero.selectedWeaponName ?? "Testwaffe"
            let weapon = weapon(named: name, technique: "CT_12", hero: hero)
            weapon.reach = reach.rawValue
            hero.selectedWeaponName = weapon.name
            s.loadoutName = weapon.name
        case .situationMounted:
            s.round.mounted = true
        case .situationBeengt:
            s.round.beengteUmgebung = true
        case .situationDefencesThisRound(let min):
            s.round.parriesThisRound = min
            s.round.dodgesThisRound = min
        case .situationTargetZone(let zones):
            s.targetHitZone = zones.first
        case .situationWoundEffect:
            s.isWoundEffectProbe = true
        case .opponentReach(let reach):
            s.opponents.current.reach = reach
        case .opponentOnFoot:
            s.opponents.current.isOnFoot = true
        case .opponentState(let id):
            s.opponents.current.states.insert(id)
        case .opponentType(.demon):
            s.opponents.current.isDaemon = true
        case .gmFact(let id, let span):
            s.opponents.current.facts[FactKey(id: id, span: span)] = true
        }
    }

    private func weapon(named name: String, technique: String, hero: Hero) -> MeleeWeapon {
        if let existing = hero.meleeWeapons.first(where: { $0.name == name }) { return existing }
        let weapon = MeleeWeapon(name: name, combatTechniqueId: technique, damage: "1W6+3", at: 12, pa: 8, reach: "Mittel", weight: 1.5)
        hero.meleeWeapons.append(weapon)
        return weapon
    }
}
