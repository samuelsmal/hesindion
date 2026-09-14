import XCTest
import SwiftData
@testable import Hesindion

/// The interpreter, one vocabulary item and one rule of application at a
/// time, against catalogs built by hand so no test depends on rules.db.
@MainActor
final class RuleEvaluatorTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
    }

    override func tearDown() { context = nil; hero = nil }

    // MARK: - Builders

    private func rule(_ id: String, name: String? = nil, reviewed: Bool = false,
                      appliesWith: RulePredicate? = nil, _ clauses: [RuleClause]) -> CatalogRule {
        CatalogRule(id: id, name: name ?? id, reviewed: reviewed, appliesWith: appliesWith, clauses: clauses)
    }

    private func passive(_ domains: [RuleDomain], when: RulePredicate? = nil, _ effects: [RuleEffect]) -> RuleClause {
        RuleClause(kind: .passive, domains: domains, when: when, effects: effects, tiers: nil)
    }

    private func offer(_ domains: [RuleDomain], tiers: OfferTiers? = .owned, when: RulePredicate? = nil, _ effects: [RuleEffect]) -> RuleClause {
        RuleClause(kind: .offer, domains: domains, when: when, effects: effects, tiers: tiers)
    }

    private func own(_ id: String, tier: Int? = nil) {
        hero.combatSpecialAbilities.append(HeroTrait(ruleId: id, name: id, tier: tier, sid: nil))
    }

    private func evaluate(_ rules: [CatalogRule], statuses: [CatalogEntry] = [], _ situation: Situation) -> Evaluation {
        RuleEvaluator.evaluate(catalog: RuleCatalog(rules: rules, statuses: statuses), situation: situation)
    }

    private func line(_ id: String, in e: Evaluation) -> Int? { e.lines.first { $0.ruleId == id }?.value }
    private func reason(_ id: String, in e: Evaluation) -> NotApplied.Reason? { e.notApplied.first { $0.ruleId == id }?.reason }

    private let plusTwoAT = [RuleEffect.add(target: .at, value: 2, per: nil)]

    // MARK: - Ownership and domains

    func testARuleTheHeroDoesNotOwnIsNotEvenListed() {
        let e = evaluate([rule("SA_1", [passive([.meleeAttack], plusTwoAT)])], Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(e, Evaluation())
    }

    func testACoreRuleAppliesToEveryoneAndAnOwnedRuleToItsOwner() {
        own("SA_1")
        let rules = [rule("SA_1", [passive([.meleeAttack], plusTwoAT)]),
                     rule("GRW_x", [passive([.meleeAttack], plusTwoAT)])]
        let e = evaluate(rules, Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(line("SA_1", in: e), 2)
        XCTAssertEqual(line("GRW_x", in: e), 2)
        XCTAssertEqual(e.applied, ["SA_1", "GRW_x"])
    }

    func testAClauseInAnotherDomainIsWrongDomainAndAnUnmetConditionIsConditionFalse() {
        own("SA_1"); own("SA_2")
        let rules = [rule("SA_1", [passive([.meleeParry], plusTwoAT)]),
                     rule("SA_2", [passive([.meleeAttack], when: .situationMounted, plusTwoAT)])]
        let e = evaluate(rules, Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(reason("SA_1", in: e), .wrongDomain)
        XCTAssertEqual(reason("SA_2", in: e), .conditionFalse)
        XCTAssertTrue(e.lines.isEmpty)
    }

    /// An effect on a target the domain does not roll is nobody's line: the
    /// Wuchtschlag clause names AT and TP, the attack takes AT, the damage takes TP.
    func testATargetOutsideTheDomainIsSkipped() {
        own("SA_1")
        let rules = [rule("SA_1", [passive([.meleeAttack, .damage], [.add(target: .at, value: -2, per: nil), .add(target: .tp, value: 2, per: nil)])])]
        let attack = evaluate(rules, Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(attack.lines.map(\.value), [-2])
        let damage = evaluate(rules, Situation(hero: hero, domain: .damage))
        XCTAssertEqual(damage.lines.map(\.value), [2])
        var talent = Situation(hero: hero, domain: .talentCheck)
        talent.talentId = "TAL_8"
        let onTalent = evaluate([rule("GRW_t", [passive([.talentCheck], [.add(target: .talent("TAL_8"), value: -2, per: nil)])])], talent)
        XCTAssertEqual(line("GRW_t", in: onTalent), -2)
        talent.talentId = "TAL_10"
        XCTAssertTrue(evaluate([rule("GRW_t", [passive([.talentCheck], [.add(target: .talent("TAL_8"), value: -2, per: nil)])])], talent).lines.isEmpty)
    }

    // MARK: - Predicates

    func testPerTierUsesTheOwnedTierAndAppliesWithGatesEveryClause() {
        own("SA_1", tier: 3)
        let rules = [rule("SA_1", appliesWith: .situationMounted,
                          [passive([.meleeAttack], [.add(target: .at, value: -2, per: .tier)])])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        XCTAssertEqual(reason("SA_1", in: evaluate(rules, s)), .conditionFalse)
        s.round.mounted = true
        XCTAssertEqual(line("SA_1", in: evaluate(rules, s)), -6)
    }

    func testAnUnansweredOpponentFactIsAQuestion() {
        let rules = [rule("GRW_x", [passive([.meleeAttack], when: .opponentOnFoot, plusTwoAT)])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        let asked = evaluate(rules, s)
        XCTAssertEqual(asked.questions, [RuleQuestion(key: FactKey(id: "onFoot", span: .opponent), askedBy: "GRW_x")])
        XCTAssertEqual(reason("GRW_x", in: asked), .questionUnanswered)
        s.opponents.current.isOnFoot = false
        XCTAssertEqual(reason("GRW_x", in: evaluate(rules, s)), .conditionFalse)
        s.opponents.current.isOnFoot = true
        XCTAssertEqual(line("GRW_x", in: evaluate(rules, s)), 2)
    }

    func testAGMFactIsReadOffTheOpponentByIdAndSpan() {
        let key = FactKey(id: "opposingDeity", span: .attack)
        let rules = [rule("GRW_x", [passive([.damage], when: .gmFact(id: "opposingDeity", span: .attack), [.multiply(target: .tp, factor: 2)])])]
        var s = Situation(hero: hero, domain: .damage)
        let asked = evaluate(rules, s)
        XCTAssertEqual(asked.questions.map(\.key), [key])
        XCTAssertTrue(asked.multipliers.isEmpty)
        s.opponents.current.facts[key] = true
        let answered = evaluate(rules, s)
        XCTAssertEqual(answered.multipliers.map(\.factor), [2])
        XCTAssertEqual(answered.applied, ["GRW_x"])
    }

    func testAnyNotAndTheLoadoutPredicates() {
        hero.meleeWeapons = [MeleeWeapon(name: "Rabenschnabel", combatTechniqueId: "CT_5", damage: "1W6+4", at: 12, pa: 8, reach: "Mittel", weight: 2)]
        hero.shields = [Shield(name: "Großschild", damage: "1W6+1", at: 6, pa: 11, reach: "Kurz", structurePoints: 30, weight: 6)]
        hero.selectedWeaponName = "Rabenschnabel"
        let either: RulePredicate = .any([.loadoutWeapon(technique: ["CT_5"], item: "Rabenschnabel", consecrated: nil),
                                          .loadoutShield(item: "Großschild")])
        let rules = [rule("GRW_x", [passive([.meleeAttack], when: either, plusTwoAT)]),
                     rule("GRW_y", [passive([.meleeAttack], when: .not(.loadoutReach(.mittel)), plusTwoAT)]),
                     rule("GRW_z", [passive([.meleeAttack], when: .loadoutWeapon(technique: nil, item: nil, consecrated: true), plusTwoAT)])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        var e = evaluate(rules, s)
        XCTAssertEqual(line("GRW_x", in: e), 2, "the weapon matches")
        XCTAssertEqual(reason("GRW_y", in: e), .conditionFalse, "the Rabenschnabel is Mittel")
        XCTAssertEqual(reason("GRW_z", in: e), .conditionFalse, "nothing is consecrated")
        hero.selectedShieldName = "Großschild"
        hero.selectedWeaponName = nil
        hero.setConsecrated("Rabenschnabel", true)
        s.loadoutName = "Rabenschnabel"
        e = evaluate(rules, s)
        XCTAssertEqual(line("GRW_x", in: e), 2, "the shield matches too")
        XCTAssertEqual(line("GRW_z", in: e), 2, "the named loadout piece is consecrated")
    }

    func testHeroStateIsOffUnderTheZustandIgnorierenSchipAndCondLinesAreZustaende() {
        hero.setStateLevel("furcht", level: 2)
        let rules = [rule("COND_4", [passive([.talentCheck], when: .heroState(id: "furcht", minLevel: 1), [.add(target: .talent("TAL_8"), value: -2, per: nil)])])]
        var s = Situation(hero: hero, domain: .talentCheck)
        s.talentId = "TAL_8"
        let e = evaluate(rules, s)
        XCTAssertEqual(e.lines.first?.isZustand, true)
        s.round.schipIgnoreZustand = true
        XCTAssertEqual(reason("COND_4", in: evaluate(rules, s)), .conditionFalse)
    }

    /// Belastung is the armour the hero is still wearing, not a Zustand the
    /// Schicksalspunkt can will away — `SharedModifiers.encumbrance` has never
    /// checked the flag either.
    func testBelastungSurvivesTheZustandIgnorierenSchip() {
        hero.armors.append(Armor(name: "Kette", protectionValue: 4, encumbrance: 2, weight: 10, isEquipped: true))
        hero.setStateLevel("furcht", level: 2)
        let rules = [rule("COND_1", [passive([.meleeAttack], when: .heroState(id: "belastung", minLevel: 1),
                                             [.add(target: .at, value: -1, per: nil)])]),
                     rule("COND_4", [passive([.meleeAttack], when: .heroState(id: "furcht", minLevel: 1),
                                             [.add(target: .at, value: -2, per: nil)])])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.round.schipIgnoreZustand = true
        let e = evaluate(rules, s)
        XCTAssertEqual(line("COND_1", in: e), -1, "the Schip does not take the armour off")
        XCTAssertEqual(reason("COND_4", in: e), .conditionFalse)
    }

    func testPerDefencesThisRoundMultipliesByTheCount() {
        let rules = [rule("GRW_x", [passive([.meleeParry, .meleeDodge], when: .situationDefencesThisRound(min: 1),
                                            [.add(target: .vw, value: -3, per: .defencesThisRound)])])]
        var s = Situation(hero: hero, domain: .meleeParry)
        XCTAssertEqual(reason("GRW_x", in: evaluate(rules, s)), .conditionFalse, "the first parry is unmodified")
        s.round.parriesThisRound = 2
        XCTAssertEqual(line("GRW_x", in: evaluate(rules, s)), -6)
        var dodge = Situation(hero: hero, domain: .meleeDodge)
        dodge.round.parriesThisRound = 2
        dodge.round.dodgesThisRound = 1
        XCTAssertEqual(line("GRW_x", in: evaluate(rules, dodge)), -3, "dodges are counted apart")
    }

    func testAFixedTierOfferIgnoresTheOwnedTier() {
        own("SA_1", tier: 3)
        let rules = [rule("SA_1", [offer([.meleeAttack], tiers: .fixed(2), [.add(target: .at, value: -1, per: .tier)])])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        XCTAssertEqual(evaluate(rules, s).offers.first?.shape, .tiers(2))
        s.announced["SA_1"] = 3
        XCTAssertEqual(line("SA_1", in: evaluate(rules, s)), -2, "the rule has only two tiers")
    }

    // MARK: - Order of application

    func testModifyRuleSetsThenMultipliesThenAddsAndMissesWhenTheRuleIsNotInEffect() {
        own("SA_1"); own("SA_2"); own("SA_3")
        let base = rule("GRW_x", [passive([.meleeAttack], when: .situationTargetZone([.kopf]), [.add(target: .at, value: -10, per: nil)])])
        let rules = [base,
                     rule("SA_1", [passive([.meleeAttack], [.modifyRule(id: "GRW_x", target: .at, add: 2, set: nil, multiply: nil)])]),
                     rule("SA_2", [passive([.meleeAttack], [.modifyRule(id: "GRW_x", target: .at, add: nil, set: nil, multiply: 0.5)])]),
                     rule("SA_3", [passive([.meleeAttack], [.modifyRule(id: "GRW_x", target: .at, add: nil, set: -6, multiply: nil)])])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.targetHitZone = .kopf
        let e = evaluate(rules, s)
        XCTAssertEqual(line("GRW_x", in: e), -1, "set −6, halved −3, +2")
        XCTAssertEqual(e.applied, ["GRW_x", "SA_1", "SA_2", "SA_3"])
        s.targetHitZone = nil
        let missed = evaluate(rules, s)
        XCTAssertNil(line("GRW_x", in: missed))
        XCTAssertEqual(reason("SA_1", in: missed), .modifiedRuleNotInEffect)
        XCTAssertEqual(reason("GRW_x", in: missed), .conditionFalse)
    }

    func testALineThatComesToZeroIsDroppedAndSaidSo() {
        own("SA_1")
        let rules = [rule("GRW_x", [passive([.meleeAttack], [.add(target: .at, value: -2, per: nil)])]),
                     rule("SA_1", [passive([.meleeAttack], [.modifyRule(id: "GRW_x", target: .at, add: 2, set: nil, multiply: nil)])])]
        let e = evaluate(rules, Situation(hero: hero, domain: .meleeAttack))
        XCTAssertTrue(e.lines.isEmpty)
        XCTAssertEqual(reason("GRW_x", in: e), .netZero)
        XCTAssertEqual(e.applied, ["SA_1"])
    }

    // MARK: - Offers

    func testAChoiceOfferIsListedUntilTakenAndThenAppliesOnlyTheChosenOption() {
        own("SA_1")
        let options: [RuleEffect] = [.add(target: .at, value: 1, per: nil), .add(target: .vw, value: 1, per: nil)]
        let rules = [rule("SA_1", [offer([.meleeAttack, .meleeParry, .meleeDodge], tiers: nil, [.choice(options)])])]
        var s = Situation(hero: hero, domain: .meleeParry)
        let open = evaluate(rules, s)
        XCTAssertEqual(open.offers, [RuleOffer(ruleId: "SA_1", name: "SA_1", shape: .choice(options), reviewed: false)])
        XCTAssertEqual(reason("SA_1", in: open), .offerNotTaken)
        s.choices["SA_1"] = 1
        XCTAssertEqual(line("SA_1", in: evaluate(rules, s)), 1)
        s.choices["SA_1"] = 0
        XCTAssertTrue(evaluate(rules, s).lines.isEmpty, "AT was chosen; this is a parry")
    }

    func testATieredOfferUsesTheAnnouncedTierCappedAtTheOwnedOne() {
        own("SA_1", tier: 2)
        let rules = [rule("SA_1", [offer([.meleeAttack], [.add(target: .at, value: -2, per: .tier)])])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        let open = evaluate(rules, s)
        XCTAssertEqual(open.offers.first?.shape, .tiers(2))
        s.announced["SA_1"] = 1
        XCTAssertEqual(line("SA_1", in: evaluate(rules, s)), -2)
        s.announced["SA_1"] = 3
        XCTAssertEqual(line("SA_1", in: evaluate(rules, s)), -4, "the hero only has II")
    }

    // MARK: - The rest of the sheet

    func testOwnedRulesTheCatalogDoesNotImplementAreListedWithTheirStatus() {
        own("SA_9"); own("SA_8"); hero.advantages.append(HeroTrait(ruleId: "ADV_1", name: "x", tier: nil, sid: nil))
        let statuses = [CatalogEntry(id: "SA_9", name: "Neun", status: .byHand, note: nil, pointer: nil, reviewedBy: nil, reviewedOn: nil),
                        CatalogEntry(id: "SA_8", name: "Acht", status: .todo, note: nil, pointer: nil, reviewedBy: nil, reviewedOn: nil),
                        CatalogEntry(id: "ADV_1", name: "Eins", status: .noRollEffect, note: nil, pointer: nil, reviewedBy: nil, reviewedOn: nil)]
        let e = evaluate([], statuses: statuses, Situation(hero: hero, domain: .meleeAttack))
        XCTAssertEqual(Set(e.notApplied), [NotApplied(ruleId: "SA_9", name: "Neun", reason: .byHand),
                                           NotApplied(ruleId: "SA_8", name: "Acht", reason: .todo),
                                           NotApplied(ruleId: "ADV_1", name: "Eins", reason: .noRollEffect)])
    }

    func testOpponentLinesAndTheReviewedFlagTravel() {
        let rules = [rule("STATE_x", name: "Liegend", reviewed: true,
                          [passive([.meleeAttack], when: .opponentState("liegend"), [.opponentAdd(target: .vw, value: -2)])])]
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.opponents.current.isProne = true
        let e = evaluate(rules, s)
        XCTAssertEqual(e.opponentLines, [RuleLine(ruleId: "STATE_x", name: "Liegend", target: .vw, value: -2, reviewed: true, isZustand: false)])
        XCTAssertTrue(e.lines.isEmpty)
    }
}
