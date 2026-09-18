import XCTest
import SwiftData
@testable import Hesindion

/// Design §4, "what fails the build": an `implemented` clause that cannot fire.
/// Because the vocabulary is closed, every predicate has a known satisfying
/// assignment; this builds it and asserts the rule applied.
///
/// `Evaluation.applied` is per *rule*, not per clause: a rule with an
/// unconditional clause and a conditional one counts as applied the moment
/// either fires. So proving one clause reachable means evaluating a catalog
/// reduced to that one clause (plus whatever it `modifyRule`s) — `fires(_:_:
/// domain:appliesWithBranch:whenBranch:in:)` below does the reduction;
/// `testReducedCatalogIsolatesOneClauseFromASiblingThatMasksIt` proves the reduction
/// actually isolates.
@MainActor
final class RuleReachabilityTests: XCTestCase {

    override func setUpWithError() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
    }

    func testEveryImplementedClauseCanFire() throws {
        let catalog = RuleCatalog.bundled
        XCTAssertFalse(catalog.implemented.isEmpty, "nothing is implemented; the fixtures are gone")
        for rule in catalog.implemented {
            for (index, clause) in rule.clauses.enumerated() {
                for domain in clause.domains {
                    // `any` inside `appliesWith` and inside this clause's `when`
                    // each get every one of their branches tried, not just the
                    // first: `GRW_vorteilhaftePosition`'s gm.fact branch and
                    // `SA_661`'s Großschild branch are otherwise never reached.
                    for appliesWithBranch in enumerateAssignments(rule.appliesWith) {
                        for whenBranch in enumerateAssignments(clause.when) {
                            let (fired, evaluation, visited) = try fires(
                                rule, clause, domain: domain,
                                appliesWithBranch: appliesWithBranch, whenBranch: whenBranch, in: catalog
                            )
                            XCTAssertTrue(fired, """
                                \(rule.id) clause \(index) in \(domain) \
                                (appliesWith branch \(appliesWithBranch), when branch \(whenBranch)) did not fire: \
                                \(evaluation.notApplied.filter { visited.contains($0.ruleId) }), \
                                questions \(evaluation.questions.map(\.key))
                                """)
                        }
                    }
                }
            }
        }
    }

    /// A synthetic two-clause rule — clause A unconditional, clause B gated on
    /// `situation.mounted`, which this test never sets — proving the
    /// per-clause reduction `reduced(_:to:modifiedIds:in:)` performs (and
    /// `fires` uses) actually isolates a clause from a sibling that would
    /// otherwise mask it. Before that reduction existed, evaluating the whole
    /// rule at once would have reported clause B as reachable purely because
    /// A's line made `applied` true.
    ///
    /// This deliberately evaluates the situation directly rather than through
    /// `fires`: `fires`'s job is to *satisfy* the clause under test (so it
    /// would dutifully set `mounted = true` for clause B, which is the
    /// opposite of what a negative case needs), not to demonstrate a clause
    /// failing to hold.
    func testReducedCatalogIsolatesOneClauseFromASiblingThatMasksIt() throws {
        let clauseA = RuleClause(kind: .passive, domains: [.meleeAttack], when: nil,
                                 effects: [.add(target: .at, value: 1, per: nil)], tiers: nil)
        let clauseB = RuleClause(kind: .passive, domains: [.meleeAttack], when: .situationMounted,
                                 effects: [.add(target: .at, value: 1, per: nil)], tiers: nil)
        let rule = CatalogRule(id: "GRW_testMask", name: "Test", reviewed: false, appliesWith: nil,
                               clauses: [clauseA, clauseB])
        let catalog = RuleCatalog(rules: [rule])

        let context = ModelContext(try TestData.makeContainer())
        let hero = Hero(name: "Mask")
        context.insert(hero)
        let situation = Situation(hero: hero, domain: .meleeAttack)   // never mounted

        let unreduced = RuleEvaluator.evaluate(catalog: catalog, situation: situation)
        XCTAssertTrue(unreduced.applied.contains("GRW_testMask"),
                     "sanity check: A's unconditional line fires and masks B, even though B's own `when` (mounted) does not hold, when the whole rule is evaluated at once")

        let isolated = RuleEvaluator.evaluate(catalog: reduced(rule, to: clauseB, modifiedIds: [], in: catalog), situation: situation)
        XCTAssertFalse(isolated.applied.contains("GRW_testMask"),
                      "clause B alone, unmounted, must not fire — the reduction removes A's mask and lets B's own failure show")
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
    ///
    /// Out of this test's scope entirely, not tracked here: `RuleVocabulary.Combinator`
    /// (only `.not` has generator support below, and no entry uses it today —
    /// see `satisfy(_:hero:situation:branch:cursor:rule:)`'s `.not` case),
    /// `RuleVocabulary.Target.aw` and `RuleVocabulary.Per` (targets and `per`
    /// values are not independently checked for coverage, only predicates and
    /// effects are).
    private let notYetUsed: Set<RuleVocabulary.Predicate> = [.heroHasRule]
    private let notYetUsedEffects: Set<RuleVocabulary.Effect> = []

    /// The other direction: the vocabulary is scoped to what the fixtures need,
    /// so a predicate or effect no entry uses has no interpreter anyone exercised.
    func testEveryVocabularyItemIsUsedByAnImplementedClause() {
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

    // MARK: - Proving one clause, in isolation

    /// Builds a fresh hero and `Situation` satisfying `clause` (and `rule`'s
    /// `appliesWith`, if any), picking branch `appliesWithBranch` /
    /// `whenBranch` at each `any` node, then evaluates a catalog reduced to
    /// `rule` cut down to this one `clause` plus whatever it recursively
    /// `modifyRule`s (in full, since the evaluator needs their own clauses to
    /// produce the line being modified). Reports whether `rule.id` fired.
    ///
    /// The reduction is what makes this a *per-clause* proof: `rule` in the
    /// full bundled catalog can carry another clause in the same domain whose
    /// line alone would make `Evaluation.applied` true regardless of this one.
    private func fires(_ rule: CatalogRule, _ clause: RuleClause, domain: RuleDomain,
                       appliesWithBranch: [Int], whenBranch: [Int],
                       in catalog: RuleCatalog) throws -> (fired: Bool, evaluation: Evaluation, visited: Set<String>) {
        let context = ModelContext(try TestData.makeContainer())
        let hero = Hero(name: "Reach")
        context.insert(hero)
        var situation = Situation(hero: hero, domain: domain)
        var visited: Set<String> = []
        satisfy(rule, clause, in: catalog, hero: hero, situation: &situation, visited: &visited,
                appliesWithBranch: appliesWithBranch, whenBranch: whenBranch)
        let evaluation = RuleEvaluator.evaluate(catalog: reduced(rule, to: clause, modifiedIds: visited, in: catalog), situation: situation)
        return (evaluation.applied.contains(rule.id), evaluation, visited)
    }

    /// `rule` cut down to just `clause`, plus (in full — the evaluator needs
    /// their own clauses to produce the line being modified) whatever id in
    /// `modifiedIds` is not `rule` itself. This is the reduction that makes a
    /// per-clause proof possible: `Evaluation.applied` is otherwise per rule,
    /// so a second, unconditional clause of `rule` in the same domain would
    /// make it true regardless of whether `clause` held. Used by `fires` for
    /// the real per-clause walk, and directly by
    /// `testReducedCatalogIsolatesOneClauseFromASiblingThatMasksIt` to prove
    /// the reduction actually isolates.
    private func reduced(_ rule: CatalogRule, to clause: RuleClause, modifiedIds: Set<String>, in catalog: RuleCatalog) -> RuleCatalog {
        let cutDown = CatalogRule(id: rule.id, name: rule.name, reviewed: rule.reviewed,
                                  appliesWith: rule.appliesWith, clauses: [clause])
        let modifiedRules = modifiedIds.subtracting([rule.id]).compactMap { catalog.rules[$0] }
        return RuleCatalog(rules: [cutDown] + modifiedRules)
    }

    // MARK: - Enumerating `any` branches

    /// The Cartesian product of one branch choice per `any` node in
    /// `predicate`, depth-first left to right: `[[]]` when there is none,
    /// `[[0], [1]]` for one two-way `any`, and so on. `satisfy` consumes
    /// indices from one of these, in the same order, via a cursor.
    private func enumerateAssignments(_ predicate: RulePredicate?) -> [[Int]] {
        guard let predicate else { return [[]] }
        let counts = branchCounts(predicate)
        guard !counts.isEmpty else { return [[]] }
        return counts.reduce([[]]) { partial, count in
            partial.flatMap { prefix in (0..<count).map { prefix + [$0] } }
        }
    }

    /// One entry per `any` node in `predicate`, depth-first left to right —
    /// how many branches it offers. Does not look inside an `any`'s own
    /// options for a *further* `any`: no clause in the current catalog nests
    /// one `any` inside another's branch (every `any` here sits directly
    /// under `all`, or alone at the top of a `when`/`appliesWith`), so
    /// finding one there is a shape this generator has not been taught, not a
    /// silent gap — it fails the test instead of guessing.
    private func branchCounts(_ predicate: RulePredicate) -> [Int] {
        switch predicate {
        case .all(let parts):
            return parts.flatMap(branchCounts)
        case .any(let parts):
            for part in parts {
                XCTAssertTrue(branchCounts(part).isEmpty, "nested any-inside-any is outside this generator's scope: \(part)")
            }
            return [parts.count]
        case .not(let part):
            return branchCounts(part)
        default:
            return []
        }
    }

    // MARK: - Building a situation that satisfies a clause

    private func satisfy(_ rule: CatalogRule, _ clause: RuleClause, in catalog: RuleCatalog,
                         hero: Hero, situation s: inout Situation, visited: inout Set<String>,
                         appliesWithBranch: [Int], whenBranch: [Int]) {
        guard visited.insert(rule.id).inserted else { return }
        if rule.needsOwnership && (hero.ownedRuleTier(rule.id) ?? 0) < 3 {
            // Replace, not append: `Hero.ownedRuleTier` returns the *first*
            // match, so a second entry for the same id (from an earlier,
            // lower-tier `heroHasRule` predicate, say) would never be seen.
            hero.combatSpecialAbilities.removeAll { $0.ruleId == rule.id }
            hero.combatSpecialAbilities.append(HeroTrait(ruleId: rule.id, name: rule.name, tier: 3, sid: nil))
        }
        if let gate = rule.appliesWith {
            var cursor = 0
            satisfy(gate, hero: hero, situation: &s, branch: appliesWithBranch, cursor: &cursor, rule: rule.id)
        }
        if let when = clause.when {
            var cursor = 0
            satisfy(when, hero: hero, situation: &s, branch: whenBranch, cursor: &cursor, rule: rule.id)
        }
        if clause.kind == .offer {
            if case .choice(let options)? = clause.effects.first {
                // Take the option that has something to say in this domain.
                // `couldApply` does not commit `s.talentId` while scanning —
                // only the option actually chosen gets to set it, below.
                let fitting = options.firstIndex { option in
                    guard let target = target(of: option) else { return false }
                    return couldApply(target, in: s.domain)
                }
                if let fitting, let target = target(of: options[fitting]), case .talent(let id) = target {
                    s.talentId = id
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
                // The modified rule must be in effect on the same target in
                // this domain — its own `add` or `multiply`, at top level or
                // inside a `choice`'s options.
                let base = modified.clauses.first { c in
                    c.domains.contains(s.domain) && c.effects.contains { matches($0, target: target) }
                }
                if let base {
                    // The modified rule's own `any` branches (if it has any)
                    // are not enumerated here — `modified` gets that proof on
                    // its own turn as a top-level `implemented` entry; here it
                    // only needs to be *in effect*, so the first branch of
                    // each of its `any`s (branch array `[]`, defaulted below)
                    // is enough.
                    satisfy(modified, base, in: catalog, hero: hero, situation: &s, visited: &visited,
                            appliesWithBranch: [], whenBranch: [])
                }
            case .choice:
                break   // the option was chosen above
            }
        }
    }

    private func matches(_ effect: RuleEffect, target: RuleTarget) -> Bool {
        switch effect {
        case .add(let t, _, _), .multiply(let t, _):
            return t == target
        case .opponentAdd, .modifyRule:
            return false
        case .choice(let options):
            return options.contains { matches($0, target: target) }
        }
    }

    private func target(of effect: RuleEffect) -> RuleTarget? {
        switch effect {
        case .add(let t, _, _), .multiply(let t, _), .opponentAdd(let t, _), .modifyRule(_, let t, _, _, _): t
        case .choice: nil
        }
    }

    /// Whether `target` *could* apply in `domain` — for a talent target,
    /// "could" rather than "does", since which talent is under check is the
    /// generator's own choice to make once an option is actually picked, not
    /// something to commit to while merely scanning candidates.
    private func couldApply(_ target: RuleTarget, in domain: RuleDomain) -> Bool {
        if case .talent = target { return domain == .talentCheck }
        return target.applies(in: domain, talentId: nil)
    }

    private func satisfy(_ predicate: RulePredicate, hero: Hero, situation s: inout Situation,
                         branch: [Int], cursor: inout Int, rule ruleId: String) {
        switch predicate {
        case .all(let parts):
            parts.forEach { satisfy($0, hero: hero, situation: &s, branch: branch, cursor: &cursor, rule: ruleId) }
        case .any(let parts):
            let chosen = cursor < branch.count ? branch[cursor] : 0
            cursor += 1
            let index = parts.indices.contains(chosen) ? chosen : 0
            satisfy(parts[index], hero: hero, situation: &s, branch: branch, cursor: &cursor, rule: ruleId)
        case .not:
            // No entry uses `.not` today (`RuleVocabularyTests`/the catalog
            // scan agree); when one does, this must be taught what "negate"
            // means for that predicate rather than silently doing nothing.
            XCTFail("the generator cannot negate yet: \(ruleId)")
        case .heroHasRule(let id, let minTier):
            if (hero.ownedRuleTier(id) ?? 0) < minTier {
                hero.combatSpecialAbilities.removeAll { $0.ruleId == id }
                hero.combatSpecialAbilities.append(HeroTrait(ruleId: id, name: id, tier: minTier, sid: nil))
            }
        case .heroState(let id, let minLevel):
            hero.setStateLevel(id, level: minLevel)
        case .heroFokusRule(let raw):
            if let rule = FokusRule(rawValue: raw) { hero.setFokusRule(rule, active: true) }
        case .loadoutWeapon(let technique, let item, let consecrated):
            let name = item ?? "Testwaffe"
            // A prior `loadout.reach` may have set a non-default reach on the
            // weapon `s.loadoutName` currently names; if this predicate names
            // a *different* piece, carry that reach over rather than lose it
            // under a freshly created Mittel weapon.
            let priorReach = s.loadoutName.flatMap { existing in hero.meleeWeapons.first { $0.name == existing }?.reach }
            let weapon = weapon(named: name, technique: technique?.first ?? "CT_12", hero: hero)
            if let priorReach, weapon.name != s.loadoutName, weapon.reach == "Mittel" { weapon.reach = priorReach }
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
