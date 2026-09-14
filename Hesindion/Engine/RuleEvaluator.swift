import Foundation

// MARK: - What comes out

/// A modifier a catalog rule produced. Converts to the `ModifierLine` the
/// breakdown boxes already draw.
struct RuleLine: Equatable, Hashable {
    let ruleId: String
    let name: String
    let target: RuleTarget
    var value: Int
    let reviewed: Bool
    let isZustand: Bool

    var modifierLine: ModifierLine {
        ModifierLine(value: value, source: name, isZustand: isZustand, ruleId: ruleId)
    }
}

struct RuleMultiplier: Equatable {
    let ruleId: String
    let name: String
    let target: RuleTarget
    let factor: Double
    let reviewed: Bool
}

/// Something the hero may do because of a rule.
struct RuleOffer: Equatable {
    enum Shape: Equatable {
        /// A manoeuvre with tiers I…n.
        case tiers(Int)
        /// An either-or; the options are the effects to choose between.
        case choice([RuleEffect])
    }
    let ruleId: String
    let name: String
    let shape: Shape
    let reviewed: Bool
}

/// A fact a rule needs that nobody has stated. Its subject is the current
/// opponent (spans `opponent` and `attack`) or the hero (span `hero`).
struct RuleQuestion: Equatable, Hashable {
    let key: FactKey
    let askedBy: String
}

struct NotApplied: Equatable, Hashable {
    enum Reason: Equatable, Hashable {
        case conditionFalse, questionUnanswered, wrongDomain, offerNotTaken
        case modifiedRuleNotInEffect, netZero
        case byHand, noRollEffect, todo
    }
    let ruleId: String
    let name: String
    let reason: Reason
}

/// Design §3: what the rules say about this roll, in six parts.
struct Evaluation: Equatable {
    var lines: [RuleLine] = []
    var multipliers: [RuleMultiplier] = []
    var opponentLines: [RuleLine] = []
    var offers: [RuleOffer] = []
    var questions: [RuleQuestion] = []
    var notApplied: [NotApplied] = []
    /// Rule ids that changed something: a line, a multiplier, an opponent
    /// line, or a modification that landed on another rule's line.
    var applied: Set<String> = []
}

// MARK: - The evaluator

/// Interprets `implemented` catalog entries against a `Situation`.
///
/// Fixed order (design §3): base adds → rule-on-rule modifications (per
/// line: set, then multiply, then add) → zero lines dropped. Multipliers and
/// opponent lines are collected beside the lines. The −5 Zustand cap is not
/// applied here: `ModifierEngine` applies it once over the union of these
/// lines and the Swift definitions still in migration.
enum RuleEvaluator {

    static func evaluate(catalog: RuleCatalog, situation: Situation) -> Evaluation {
        var out = Evaluation()
        var modifications: [Modification] = []
        for rule in catalog.implemented {
            evaluate(rule, in: situation, into: &out, modifications: &modifications)
        }
        applyModifications(modifications, to: &out)
        dropZeroLines(&out)
        listOwnedRulesTheCatalogDoesNotImplement(catalog, situation, &out)
        out.applied.formUnion(out.lines.map(\.ruleId))
        out.applied.formUnion(out.multipliers.map(\.ruleId))
        out.applied.formUnion(out.opponentLines.map(\.ruleId))
        return out
    }

    // MARK: One rule

    private struct Modification {
        let from: String
        let fromName: String
        let targetRule: String
        let target: RuleTarget
        let add: Int?
        let set: Int?
        let multiply: Double?
    }

    private static func evaluate(_ rule: CatalogRule, in s: Situation, into out: inout Evaluation,
                                 modifications: inout [Modification]) {
        let ownedTier = s.hero.ownedRuleTier(rule.id)
        if rule.needsOwnership && ownedTier == nil { return }
        let tier = ownedTier ?? 1

        if let gate = rule.appliesWith {
            switch test(gate, s) {
            case .no:
                out.notApplied.append(NotApplied(ruleId: rule.id, name: rule.name, reason: .conditionFalse)); return
            case .unknown(let key):
                out.questions.append(RuleQuestion(key: key, askedBy: rule.id))
                out.notApplied.append(NotApplied(ruleId: rule.id, name: rule.name, reason: .questionUnanswered)); return
            case .yes:
                break
            }
        }

        let clauses = rule.clauses.filter { $0.domains.contains(s.domain) }
        guard !clauses.isEmpty else {
            out.notApplied.append(NotApplied(ruleId: rule.id, name: rule.name, reason: .wrongDomain)); return
        }

        var reasons: [NotApplied.Reason] = []
        var landed = false
        for clause in clauses {
            if let when = clause.when {
                switch test(when, s) {
                case .no: reasons.append(.conditionFalse); continue
                case .unknown(let key):
                    out.questions.append(RuleQuestion(key: key, askedBy: rule.id))
                    reasons.append(.questionUnanswered); continue
                case .yes: break
                }
            }
            switch clause.kind {
            case .passive:
                landed = apply(clause.effects, tier: tier, rule, s, &out, &modifications) || landed
            case .offer:
                if case .choice(let options)? = clause.effects.first {
                    if let chosen = s.effectiveChoices[rule.id], options.indices.contains(chosen) {
                        landed = apply([options[chosen]], tier: tier, rule, s, &out, &modifications) || landed
                    } else {
                        out.offers.append(RuleOffer(ruleId: rule.id, name: rule.name, shape: .choice(options), reviewed: rule.reviewed))
                        reasons.append(.offerNotTaken)
                    }
                } else {
                    let maxTier: Int = switch clause.tiers {
                        case .fixed(let n)?: n
                        case .owned?, nil:   tier
                    }
                    if let announced = s.effectiveAnnounced[rule.id] {
                        landed = apply(clause.effects, tier: min(announced, maxTier), rule, s, &out, &modifications) || landed
                    } else {
                        out.offers.append(RuleOffer(ruleId: rule.id, name: rule.name, shape: .tiers(maxTier), reviewed: rule.reviewed))
                        reasons.append(.offerNotTaken)
                    }
                }
            }
        }
        if !landed {
            // No reason recorded means every clause passed its `when` and none
            // had an effect on this domain's target (an offer taken for AT,
            // evaluated on a parry): the same thing as a clause in another domain.
            out.notApplied.append(NotApplied(ruleId: rule.id, name: rule.name, reason: reasons.first ?? .wrongDomain))
        }
    }

    /// Applies the effects that belong to this domain. Returns whether any did.
    private static func apply(_ effects: [RuleEffect], tier: Int, _ rule: CatalogRule, _ s: Situation,
                              _ out: inout Evaluation, _ modifications: inout [Modification]) -> Bool {
        var landed = false
        let isZustand = rule.id.hasPrefix("COND_")
        for effect in effects {
            switch effect {
            case .add(let target, let value, let per):
                guard target.applies(in: s.domain, talentId: s.talentId) else { continue }
                let times: Int = switch per {
                    case .tier?:              tier
                    case .defencesThisRound?: s.defencesThisRound
                    case nil:                 1
                }
                out.lines.append(RuleLine(ruleId: rule.id, name: rule.name, target: target, value: value * times,
                                          reviewed: rule.reviewed, isZustand: isZustand))
                landed = true
            case .multiply(let target, let factor):
                guard target.applies(in: s.domain, talentId: s.talentId) else { continue }
                out.multipliers.append(RuleMultiplier(ruleId: rule.id, name: rule.name, target: target, factor: factor, reviewed: rule.reviewed))
                landed = true
            case .opponentAdd(let target, let value):
                out.opponentLines.append(RuleLine(ruleId: rule.id, name: rule.name, target: target, value: value,
                                                  reviewed: rule.reviewed, isZustand: false))
                landed = true
            case .modifyRule(let id, let target, let add, let set, let multiply):
                guard target.applies(in: s.domain, talentId: s.talentId) else { continue }
                modifications.append(Modification(from: rule.id, fromName: rule.name, targetRule: id, target: target,
                                                  add: add, set: set, multiply: multiply))
                landed = true
            case .choice:
                continue   // only meaningful inside an offer, handled by the caller
            }
        }
        return landed
    }

    // MARK: Rule on rule

    private static func applyModifications(_ modifications: [Modification], to out: inout Evaluation) {
        var missed: [Modification] = []
        for mod in modifications {
            let hits = out.lines.indices.filter { out.lines[$0].ruleId == mod.targetRule && out.lines[$0].target == mod.target }
            guard !hits.isEmpty else { missed.append(mod); continue }
            out.applied.insert(mod.from)
        }
        // Per line: every set, then every multiply, then every add.
        for index in out.lines.indices {
            let line = out.lines[index]
            let mine = modifications.filter { $0.targetRule == line.ruleId && $0.target == line.target }
            guard !mine.isEmpty else { continue }
            var value = line.value
            if let set = mine.compactMap(\.set).last { value = set }
            for factor in mine.compactMap(\.multiply) {
                value = Int((Double(value) * factor).rounded(.towardZero))
            }
            value += mine.compactMap(\.add).reduce(0, +)
            out.lines[index].value = value
        }
        var reported: Set<String> = []
        for mod in missed where !out.applied.contains(mod.from) && reported.insert(mod.from).inserted {
            out.notApplied.append(NotApplied(ruleId: mod.from, name: mod.fromName, reason: .modifiedRuleNotInEffect))
        }
    }

    private static func dropZeroLines(_ out: inout Evaluation) {
        let zero = out.lines.filter { $0.value == 0 }
        out.lines.removeAll { $0.value == 0 }
        for line in zero where !out.lines.contains(where: { $0.ruleId == line.ruleId }) {
            out.notApplied.append(NotApplied(ruleId: line.ruleId, name: line.name, reason: .netZero))
        }
    }

    // MARK: The rest of the sheet

    private static func listOwnedRulesTheCatalogDoesNotImplement(_ catalog: RuleCatalog, _ s: Situation, _ out: inout Evaluation) {
        for id in s.hero.ownedRuleIds {
            guard let entry = catalog.statuses[id] else { continue }
            let reason: NotApplied.Reason
            switch entry.status {
            case .implemented:   continue
            case .byHand:        reason = .byHand
            case .noRollEffect:  reason = .noRollEffect
            case .todo:          reason = .todo
            }
            out.notApplied.append(NotApplied(ruleId: id, name: entry.name, reason: reason))
        }
    }

    // MARK: Predicates

    enum Answer: Equatable {
        case yes, no
        case unknown(FactKey)
    }

    static func test(_ predicate: RulePredicate, _ s: Situation) -> Answer {
        switch predicate {
        case .all(let parts):
            var pending: FactKey?
            for part in parts {
                switch test(part, s) {
                case .no: return .no
                case .unknown(let key): pending = pending ?? key
                case .yes: break
                }
            }
            return pending.map { .unknown($0) } ?? .yes
        case .any(let parts):
            var pending: FactKey?
            for part in parts {
                switch test(part, s) {
                case .yes: return .yes
                case .unknown(let key): pending = pending ?? key
                case .no: break
                }
            }
            return pending.map { .unknown($0) } ?? .no
        case .not(let part):
            switch test(part, s) {
            case .yes: return .no
            case .no: return .yes
            case .unknown(let key): return .unknown(key)
            }
        case .heroHasRule(let id, let minTier):
            return (s.hero.ownedRuleTier(id) ?? 0) >= minTier ? .yes : .no
        case .heroState(let id, let minLevel):
            // The "Zustand ignorieren" Schicksalspunkt switches every state
            // predicate off, as StateModifiers did.
            return !s.round.schipIgnoreZustand && s.hero.level(of: id) >= minLevel ? .yes : .no
        case .heroFokusRule(let raw):
            return FokusRule(rawValue: raw).map(s.hero.isFokusRuleActive) == true ? .yes : .no
        case .loadoutWeapon(let technique, let item, let consecrated):
            guard let weapon = s.loadoutWeapon else { return .no }
            if let technique, !technique.contains(weapon.combatTechniqueId) { return .no }
            if let item, weapon.name != item { return .no }
            if let consecrated, s.hero.isConsecrated(weapon.name) != consecrated { return .no }
            return .yes
        case .loadoutShield(let item):
            guard let shield = s.hero.selectedShield else { return .no }
            return item == nil || shield.name == item ? .yes : .no
        case .loadoutReach(let reach):
            return s.loadoutReach == reach ? .yes : .no
        case .situationMounted:
            return s.round.mounted ? .yes : .no
        case .situationBeengt:
            return s.round.beengteUmgebung ? .yes : .no
        case .situationDefencesThisRound(let min):
            return s.defencesThisRound >= min ? .yes : .no
        case .situationTargetZone(let zones):
            return s.targetHitZone.map(zones.contains) == true ? .yes : .no
        case .situationWoundEffect:
            return s.isWoundEffectProbe ? .yes : .no
        case .opponentReach(let reach):
            return s.opponent.reach == reach ? .yes : .no
        case .opponentOnFoot:
            switch s.opponent.isOnFoot {
            case true?: return .yes
            case false?: return .no
            case nil: return .unknown(FactKey(id: "onFoot", span: .opponent))
            }
        case .opponentState(let id):
            return s.opponent.states.contains(id) ? .yes : .no
        case .opponentType(.demon):
            return s.opponent.isDaemon ? .yes : .no
        case .gmFact(let id, let span):
            let key = FactKey(id: id, span: span)
            switch s.opponent.facts[key] {
            case true?: return .yes
            case false?: return .no
            case nil: return .unknown(key)
            }
        }
    }
}
