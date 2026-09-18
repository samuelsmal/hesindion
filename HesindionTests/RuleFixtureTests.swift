import XCTest
import SwiftData
@testable import Hesindion

/// Design §6: hero, loadout, Situation, answers → lines, opponent lines,
/// offers, questions, not-applied. Every reviewed exemplar the catalog gains
/// gets a row here. These run against the bundled `rules.db`, so they also
/// hold the compiled clauses to what the YAML says.
@MainActor
final class RuleFixtureTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        guard RulesDatabase.shared.lookup(id: "SA_67") != nil else { throw XCTSkip("rules.db unavailable") }
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Test")
        context.insert(hero)
    }

    override func tearDown() { context = nil; hero = nil }

    // MARK: - Helpers

    private func own(_ id: String, _ name: String, tier: Int? = nil, list: WritableKeyPath<Hero, [HeroTrait]> = \.combatSpecialAbilities) {
        hero[keyPath: list].append(HeroTrait(ruleId: id, name: name, tier: tier, sid: nil))
    }

    @discardableResult
    private func arm(_ name: String, technique: String, reach: String, select: Bool = true) -> MeleeWeapon {
        let weapon = MeleeWeapon(name: name, combatTechniqueId: technique, damage: "1W6+3", at: 12, pa: 8, reach: reach, weight: 1.5)
        hero.meleeWeapons.append(weapon)
        if select { hero.selectedWeaponName = name }
        return weapon
    }

    private func lines(_ s: Situation) -> [ModifierLine] { ModifierEngine.shared.evaluate(context: s) }
    private func evaluation(_ s: Situation) -> Evaluation { ModifierEngine.shared.evaluation(s) }
    private func value(_ ruleId: String, in lines: [ModifierLine]) -> Int? { lines.first { $0.ruleId == ruleId }?.value }
    private func reason(_ ruleId: String, in e: Evaluation) -> NotApplied.Reason? { e.notApplied.first { $0.ruleId == ruleId }?.reason }

    private func defence(_ domain: RuleDomain, parries: Int = 0, dodges: Int = 0) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.round.parriesThisRound = parries
        s.round.dodgesThisRound = dodges
        return s
    }

    // MARK: - Mehrfache Verteidigung (GRW)

    func testMehrfacheVerteidigungIsMinusThreePerDefenceOfTheSameKind() {
        XCTAssertNil(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry))))
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 1))), -3)
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 3))), -9)
        XCTAssertNil(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeDodge, parries: 2))), "the first dodge is free however often the hero parried")
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeDodge, dodges: 1))), -3)
    }

    // MARK: - Vinsalt-Stil (SA_923)

    func testVinsaltStilSetsTheStepToTwoWithAFechtwaffeInHand() {
        own("SA_923", "Vinsalt-Stil")
        arm("Rapier", technique: "CT_4", reach: "Mittel")
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 1))), -2)
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 2))), -4)
        XCTAssertTrue(evaluation(defence(.meleeParry, parries: 1)).applied.contains("SA_923"))
    }

    func testVinsaltStilNeedsItsWeaponAndSomethingToModify() {
        own("SA_923", "Vinsalt-Stil")
        arm("Langschwert", technique: "CT_12", reach: "Lang")
        let sword = evaluation(defence(.meleeParry, parries: 1))
        XCTAssertEqual(value("GRW_mehrfacheVerteidigung", in: lines(defence(.meleeParry, parries: 1))), -3)
        XCTAssertEqual(reason("SA_923", in: sword), .conditionFalse)
        arm("Rapier", technique: "CT_4", reach: "Mittel")
        XCTAssertEqual(reason("SA_923", in: evaluation(defence(.meleeParry))), .modifiedRuleNotInEffect, "no second defence yet")
    }

    // MARK: - Reichweite (GRW)

    func testTheShorterWeaponPaysForReach() {
        arm("Dolch", technique: "CT_3", reach: "Kurz")
        arm("Säbel", technique: "CT_12", reach: "Mittel", select: false)
        arm("Speer", technique: "CT_13", reach: "Lang", select: false)
        let expected: [String: [WeaponReach: Int?]] = [
            "Dolch": [.kurz: nil, .mittel: -2, .lang: -4],
            "Säbel": [.kurz: nil, .mittel: nil, .lang: -2],
            "Speer": [.kurz: nil, .mittel: nil, .lang: nil],
        ]
        for (weapon, row) in expected {
            for (opponent, penalty) in row {
                var s = Situation(hero: hero, domain: .meleeAttack)
                s.loadoutName = weapon
                s.opponents.current.reach = opponent
                XCTAssertEqual(value("GRW_reichweite", in: lines(s)), penalty, "\(weapon) against \(opponent.rawValue)")
                XCTAssertEqual(value("GRW_reichweite", in: lines(s)) ?? 0, hero.reach(ofLoadoutNamed: weapon).atPenaltyAgainst(opponent), "the announcement chips (WeaponReach.atPenaltyAgainst) and the roll must agree")
            }
        }
    }

    // MARK: - Beengte Umgebung (GRW)

    func testBeengteUmgebungFollowsTheReachOfThePieceInHandOnAttackAndParry() {
        arm("Speer", technique: "CT_13", reach: "Lang")
        arm("Säbel", technique: "CT_12", reach: "Mittel", select: false)
        arm("Dolch", technique: "CT_3", reach: "Kurz", select: false)
        func penalty(_ domain: RuleDomain, _ loadout: String?) -> Int? {
            var s = Situation(hero: hero, domain: domain)
            s.round.beengteUmgebung = true
            s.loadoutName = loadout
            return value("GRW_beengteUmgebung", in: lines(s))
        }
        XCTAssertEqual(penalty(.meleeAttack, "Speer"), -8)
        XCTAssertEqual(penalty(.meleeParry, "Speer"), -8)
        XCTAssertEqual(penalty(.meleeAttack, "Säbel"), -4)
        XCTAssertEqual(penalty(.meleeParry, "Säbel"), -4)
        XCTAssertEqual(penalty(.meleeParry, nil), -8, "nothing named: the main weapon, the Speer")
        XCTAssertNil(penalty(.meleeAttack, "Dolch"))
        XCTAssertNil(penalty(.meleeAttack, "Raufen"), "bare hands are kurz")
        XCTAssertNil(penalty(.meleeDodge, "Speer"), "a dodge is not a parry")
        var calm = Situation(hero: hero, domain: .meleeAttack)
        calm.loadoutName = "Speer"
        XCTAssertNil(value("GRW_beengteUmgebung", in: lines(calm)))
    }

    // MARK: - Zonenaufschlag (Fokusregel), Gezielter Angriff (SA_160), Gezielter Schuss (SA_161), Überrascht (STATE_13)

    private func aimed(_ domain: RuleDomain, at zone: HitZone?, surprised: Bool = false, hero: Hero? = nil) -> Situation {
        var s = Situation(hero: hero ?? self.hero, domain: domain)
        s.targetHitZone = zone
        s.opponents.current.isSurprised = surprised
        // the test hero is bare-handed (kurz); a Mittel opponent would add a GRW_reichweite line
        s.opponents.current.reach = .kurz
        return s
    }

    func testTheZonenaufschlagNeedsTheFokusregelAndAZone() {
        XCTAssertNil(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .kopf))), "rule off")
        hero.setFokusRule(.trefferzonen, active: true)
        XCTAssertNil(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: nil))))
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .kopf))), -10)
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.rangedAttack, at: .torso))), -4)
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .beine))), -8)
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .schwanz))), -8, "extra limbs take the limb value")
    }

    func testGezielterAngriffHalvesItInMeleeOnlyAndSurpriseEasesItByTwo() {
        hero.setFokusRule(.trefferzonen, active: true)
        own("SA_160", "Gezielter Angriff")
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .kopf))), -5)
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .kopf, surprised: true))), -3, "halved, then +2")
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.rangedAttack, at: .kopf))), -10, "the melee ability does not halve a shot")
        let torso = evaluation(aimed(.meleeAttack, at: .torso, surprised: true))
        XCTAssertTrue(torso.lines.isEmpty, "−4, halved −2, +2 = 0")
        XCTAssertEqual(reason("GRW_zonenaufschlag", in: torso), .netZero)
        XCTAssertTrue(torso.applied.isSuperset(of: ["SA_160", "STATE_13"]))
        let unaimed = evaluation(aimed(.meleeAttack, at: nil))
        XCTAssertEqual(reason("SA_160", in: unaimed), .modifiedRuleNotInEffect)
        XCTAssertEqual(reason("STATE_13", in: unaimed), .conditionFalse)
    }

    func testGezielterSchussIsTheRangedHalf() {
        hero.setFokusRule(.trefferzonen, active: true)
        own("SA_161", "Gezielter Schuss")
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.rangedAttack, at: .kopf))), -5)
        XCTAssertEqual(value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: .kopf))), -10)
        XCTAssertEqual(reason("SA_161", in: evaluation(aimed(.meleeAttack, at: .kopf))), .wrongDomain)
    }

    /// Every combination the picker can produce is a penalty or nothing: the
    /// evaluator has no clamp, so the arithmetic itself must never go positive.
    func testTheZonenaufschlagIsNeverABonus() {
        hero.setFokusRule(.trefferzonen, active: true)
        own("SA_160", "Gezielter Angriff")
        for zone in HitZone.allCases {
            let v = value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: zone, surprised: true))) ?? 0
            XCTAssertLessThanOrEqual(v, 0, "\(zone)")
        }
    }

    /// The evaluator's own arithmetic must agree with the table `CombatZonePicker` shows
    /// on its chips (`HitZoneModifiers.penalty`) — the pattern Task 8 established for the
    /// reach table (`testTheShorterWeaponPaysForReach`).
    func testTheZoneChipsAndTheRollAgree() {
        hero.setFokusRule(.trefferzonen, active: true)
        let armedHero = Hero(name: "Armed")
        context.insert(armedHero)
        armedHero.setFokusRule(.trefferzonen, active: true)
        armedHero.combatSpecialAbilities.append(HeroTrait(ruleId: "SA_160", name: "Gezielter Angriff", tier: nil, sid: nil))
        for zone in HitZone.allCases {
            for sf in [false, true] {
                for surprised in [false, true] {
                    let subject = sf ? armedHero : hero!
                    let rolled = value("GRW_zonenaufschlag", in: lines(aimed(.meleeAttack, at: zone, surprised: surprised, hero: subject))) ?? 0
                    let chip = HitZoneModifiers.penalty(for: zone, hasSonderfertigkeit: sf, targetIsSurprised: surprised)
                    XCTAssertEqual(rolled, chip, "zone \(zone), sf \(sf), surprised \(surprised)")
                }
            }
        }
    }

    // MARK: - Vorteilhafte Position (GRW) and Golgariten-Stil (SA_661)

    /// A mounted Golgarit with the style's weapon, and nothing else switched on.
    private func golgarit(weapon: Bool = true, shield: Bool = false) {
        own("SA_661", "Golgariten-Stil")
        if weapon { arm("Rabenschnabel", technique: "CT_5", reach: "Mittel") }
        if shield {
            hero.shields = [Shield(name: "Großschild", damage: "1W6+1", at: 6, pa: 11, reach: "Kurz", structurePoints: 30, weight: 6)]
            hero.selectedShieldName = "Großschild"
        }
    }

    private func mounted(_ domain: RuleDomain, onFoot: Bool?) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.round.mounted = true
        s.opponents.current.isOnFoot = onFoot
        return s
    }

    func testTheDesignsWorkedExample() {
        golgarit()
        let attack = lines(mounted(.meleeAttack, onFoot: true))
        XCTAssertEqual(value("GRW_vorteilhaftePosition", in: attack), 4, "Vorteilhafte Position +2, raised by Golgariten-Stil +2")
        XCTAssertNil(value("SA_661", in: attack), "the style has no AT line of its own")
        XCTAssertTrue(evaluation(mounted(.meleeAttack, onFoot: true)).applied.contains("SA_661"))
        let parry = lines(mounted(.meleeParry, onFoot: true))
        XCTAssertEqual(value("GRW_vorteilhaftePosition", in: parry), 2)
        XCTAssertEqual(value("SA_661", in: parry), 1)
    }

    func testAgainstAMountedOpponentOnlyTheParryBonusRemains() {
        golgarit()
        let attack = evaluation(mounted(.meleeAttack, onFoot: false))
        XCTAssertTrue(attack.lines.isEmpty)
        XCTAssertEqual(reason("GRW_vorteilhaftePosition", in: attack), .questionUnanswered, "no toggle, not on foot: the GM has not said")
        XCTAssertEqual(reason("SA_661", in: attack), .conditionFalse)
        XCTAssertEqual(value("SA_661", in: lines(mounted(.meleeParry, onFoot: false))), 1)
    }

    func testOnFootTheStylePaysNothingAndSaysWhy() {
        golgarit()
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.opponents.current.isOnFoot = true
        let e = evaluation(s)
        XCTAssertTrue(e.lines.isEmpty)
        XCTAssertEqual(reason("SA_661", in: e), .conditionFalse)
    }

    func testAnUnstatedOpponentIsAQuestion() {
        golgarit()
        let e = evaluation(mounted(.meleeAttack, onFoot: nil))
        XCTAssertTrue(e.questions.contains(RuleQuestion(key: FactKey(id: "onFoot", span: .opponent), askedBy: "GRW_vorteilhaftePosition")))
        XCTAssertTrue(e.questions.contains(RuleQuestion(key: FactKey(id: "onFoot", span: .opponent), askedBy: "SA_661")))
        XCTAssertEqual(reason("SA_661", in: e), .questionUnanswered)
    }

    func testTheGrossschildAloneQualifiesAndALangschwertDoesNot() {
        golgarit(weapon: false, shield: true)
        arm("Langschwert", technique: "CT_12", reach: "Lang")
        XCTAssertEqual(value("SA_661", in: lines(mounted(.meleeParry, onFoot: true))), 1, "Rabenschnabel *oder* Großschild")
        hero.selectedShieldName = nil
        XCTAssertEqual(reason("SA_661", in: evaluation(mounted(.meleeParry, onFoot: true))), .conditionFalse)
    }

    /// The parry is rolled from the combat root and from the weapon list, and
    /// neither passes an announcement screen — so both have to hand the
    /// evaluator the opponent, or a mounted Golgarit's parry loses the half of
    /// the rule that turns on who is being parried.
    func testTheParryScreenSeesTheOpponent() {
        golgarit()
        var afoot = OpponentProfile()
        afoot.isOnFoot = true
        let round = CombatSituation(mounted: true)
        let against = round.defenseModifiers(hero: hero, isAusweichen: false, opponents: OpponentRoster([afoot]))
        XCTAssertEqual(value("GRW_vorteilhaftePosition", in: against), 2)
        XCTAssertEqual(value("SA_661", in: against), 1)
        let unstated = round.defenseModifiers(hero: hero, isAusweichen: false)
        XCTAssertNil(value("GRW_vorteilhaftePosition", in: unstated), "nobody has said what the opponent is standing on")
        XCTAssertEqual(value("SA_661", in: unstated), 1, "the style's own +1 PA needs no opponent")
    }

    func testTheGMToggleIsVorteilhaftePositionOnFootToo() {
        var s = Situation(hero: hero, domain: .meleeAttack)
        s.opponents.current.advantageousPosition = true
        XCTAssertEqual(value("GRW_vorteilhaftePosition", in: lines(s)), 2)
        var parry = Situation(hero: hero, domain: .meleeParry)
        parry.opponents = s.opponents
        XCTAssertEqual(value("GRW_vorteilhaftePosition", in: lines(parry)), 2)
    }

    // MARK: - Plänkler-Formation (SA_884)

    private func formation(_ domain: RuleDomain, bonus: PlaenklerBonus?) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.round.plaenklerActive = bonus != nil
        s.round.plaenklerBonus = bonus ?? .at
        return s
    }

    func testPlaenklerFormationIsAnOfferUntilTheFormationDecides() {
        own("SA_884", "Plänkler-Formation")
        let e = evaluation(formation(.meleeAttack, bonus: nil))
        XCTAssertEqual(e.offers.map(\.ruleId), ["SA_884"])
        guard case .choice(let options)? = e.offers.first?.shape else { return XCTFail("not a choice") }
        XCTAssertEqual(options, [.add(target: .at, value: 1, per: nil), .add(target: .vw, value: 1, per: nil)])
        XCTAssertEqual(reason("SA_884", in: e), .offerNotTaken)
    }

    func testTheChosenHalfAppliesAndTheOtherDoesNot() {
        own("SA_884", "Plänkler-Formation")
        XCTAssertEqual(value("SA_884", in: lines(formation(.meleeAttack, bonus: .at))), 1)
        XCTAssertTrue(evaluation(formation(.meleeAttack, bonus: .at)).offers.isEmpty, "a taken choice is no longer offered")
        XCTAssertNil(value("SA_884", in: lines(formation(.meleeParry, bonus: .at))))
        XCTAssertNil(value("SA_884", in: lines(formation(.meleeDodge, bonus: .at))))
        XCTAssertEqual(reason("SA_884", in: evaluation(formation(.meleeParry, bonus: .at))), .wrongDomain)
        XCTAssertEqual(value("SA_884", in: lines(formation(.meleeParry, bonus: .aw))), 1, "VW is parry and dodge")
        XCTAssertEqual(value("SA_884", in: lines(formation(.meleeDodge, bonus: .aw))), 1)
        XCTAssertNil(value("SA_884", in: lines(formation(.meleeAttack, bonus: .aw))))
    }

    func testWithoutTheAbilityTheFormationSettingDoesNothing() {
        XCTAssertNil(value("SA_884", in: lines(formation(.meleeAttack, bonus: .at))))
    }

    // MARK: - Wuchtschlag (SA_67)

    private func swing(_ domain: RuleDomain, _ maneuver: CombatManeuver) -> Situation {
        var s = Situation(hero: hero, domain: domain)
        s.maneuver = maneuver
        // the test hero is bare-handed (kurz); a Mittel opponent would add a GRW_reichweite line
        s.opponents.current.reach = .kurz
        return s
    }

    func testWuchtschlagIsOfferedUpToTheOwnedTier() {
        own("SA_67", "Wuchtschlag", tier: 2)
        let e = evaluation(swing(.meleeAttack, .normal))
        XCTAssertEqual(e.offers.map(\.shape), [.tiers(2)])
        XCTAssertEqual(reason("SA_67", in: e), .offerNotTaken)
    }

    func testTheAnnouncedTierCostsATAndPaysTP() {
        own("SA_67", "Wuchtschlag", tier: 2)
        XCTAssertEqual(value("SA_67", in: lines(swing(.meleeAttack, .wuchtschlag(tier: 1)))), -2)
        XCTAssertEqual(value("SA_67", in: lines(swing(.meleeAttack, .wuchtschlag(tier: 2)))), -4)
        XCTAssertEqual(value("SA_67", in: lines(swing(.meleeAttack, .wuchtschlag(tier: 3)))), -4, "the hero has II")
        XCTAssertEqual(value("SA_67", in: DamageModifiers.lines(situation: swing(.damage, .wuchtschlag(tier: 2)))), 4)
        XCTAssertNil(value("SA_67", in: lines(swing(.meleeParry, .wuchtschlag(tier: 2)))))
        // The Swift manoeuvre line has no ruleId, so value(_:in:) would not see
        // it: count the rows and add them up instead.
        XCTAssertEqual(lines(swing(.meleeAttack, .wuchtschlag(tier: 2))).filter { $0.source.hasPrefix("Wuchtschlag") }.count, 1, "one row, from the catalog")
        XCTAssertEqual(lines(swing(.meleeAttack, .wuchtschlag(tier: 2))).reduce(0) { $0 + $1.value }, -4)
    }

    // MARK: - Liegend (STATE_10)

    func testAProneHeroAttacksAtMinusFourAndDefendsAtMinusTwo() {
        hero.setStateLevel("liegend", level: 1)
        XCTAssertEqual(value("STATE_10", in: lines(Situation(hero: hero, domain: .meleeAttack))), -4)
        XCTAssertEqual(value("STATE_10", in: lines(Situation(hero: hero, domain: .meleeParry))), -2)
        XCTAssertEqual(value("STATE_10", in: lines(Situation(hero: hero, domain: .meleeDodge))), -2)
        XCTAssertEqual(lines(Situation(hero: hero, domain: .meleeAttack)).first { $0.ruleId == "STATE_10" }?.isZustand, false, "a Status, not a Zustand: outside the −5 cap")
        XCTAssertEqual(reason("STATE_10", in: evaluation(Situation(hero: hero, domain: .talentCheck))), .wrongDomain)
        var ignored = Situation(hero: hero, domain: .meleeAttack)
        ignored.round.schipIgnoreZustand = true
        XCTAssertNil(value("STATE_10", in: lines(ignored)))
    }

    func testAProneOpponentIsTheirPenaltyNotTheHerosBonus() {
        var s = Situation(hero: hero, domain: .meleeAttack)
        // The test hero is bare-handed (kurz); a Mittel opponent would add its
        // own GRW_reichweite line and e.lines would no longer be empty.
        s.opponents.current.reach = .kurz
        s.opponents.current.isProne = true
        let e = evaluation(s)
        XCTAssertEqual(e.opponentLines.map(\.ruleId), ["STATE_10"])
        XCTAssertEqual(e.opponentLines.map(\.value), [-2])
        XCTAssertTrue(e.lines.isEmpty)
        XCTAssertTrue(evaluation(Situation(hero: hero, domain: .meleeAttack)).opponentLines.isEmpty)
    }

    /// The picker draws its own chips from `CombatManeuver`; the roll comes from
    /// the catalog. Same pattern as the reach and zone tables.
    func testTheManoeuvrePickerAndTheCatalogAgreeOnWuchtschlag() {
        own("SA_67", "Wuchtschlag", tier: 3)
        for tier in 1...3 {
            let maneuver = CombatManeuver.wuchtschlag(tier: tier)
            XCTAssertEqual(maneuver.atModifier, value("SA_67", in: lines(swing(.meleeAttack, maneuver))),
                           "the picker's chips (CombatManeuver) and the roll must agree")
            XCTAssertEqual(maneuver.damageBonus, value("SA_67", in: DamageModifiers.lines(situation: swing(.damage, maneuver))),
                           "the picker's chips (CombatManeuver) and the roll must agree")
        }
    }

    /// The row keeps the tier in its name, as the manoeuvre's label did: the
    /// tier is what the player chose and what the UI tests read.
    func testATieredOffersLineIsNamedWithItsTier() {
        own("SA_67", "Wuchtschlag", tier: 3)
        XCTAssertEqual(lines(swing(.meleeAttack, .wuchtschlag(tier: 2))).first { $0.ruleId == "SA_67" }?.source, "Wuchtschlag II")
        XCTAssertEqual(DamageModifiers.lines(situation: swing(.damage, .wuchtschlag(tier: 1))).first { $0.ruleId == "SA_67" }?.source, "Wuchtschlag I")
    }

    // MARK: - Karmale Objekte (Fokusregel)

    private func consecratedSwing(daemon: Bool, opposing: Bool?) -> Situation {
        var s = Situation(hero: hero, domain: .damage)
        s.loadoutName = "Rabenschnabel"
        s.opponents.current.isDaemon = daemon
        if let opposing { s.opponents.current.facts[OpponentProfile.opposingDeityKey] = opposing }
        return s
    }

    func testAConsecratedWeaponDoublesAgainstTheOpposingDeitysDemon() {
        hero.setFokusRule(.karmaleObjekte, active: true)
        arm("Rabenschnabel", technique: "CT_5", reach: "Mittel")
        hero.setConsecrated("Rabenschnabel", true)
        XCTAssertEqual(DamageModifiers.multiplier(situation: consecratedSwing(daemon: true, opposing: true)), .double)
        let e = evaluation(consecratedSwing(daemon: true, opposing: true))
        XCTAssertEqual(e.multipliers.map(\.ruleId), ["GRW_karmaleObjekte"])
    }

    func testWhichDeityIsTheGMsQuestionAndOnlyForADemon() {
        hero.setFokusRule(.karmaleObjekte, active: true)
        arm("Rabenschnabel", technique: "CT_5", reach: "Mittel")
        hero.setConsecrated("Rabenschnabel", true)
        let unasked = evaluation(consecratedSwing(daemon: true, opposing: nil))
        XCTAssertEqual(unasked.questions, [RuleQuestion(key: OpponentProfile.opposingDeityKey, askedBy: "GRW_karmaleObjekte")])
        XCTAssertEqual(DamageModifiers.multiplier(situation: consecratedSwing(daemon: true, opposing: nil)), .unchanged)
        XCTAssertEqual(reason("GRW_karmaleObjekte", in: evaluation(consecratedSwing(daemon: true, opposing: false))), .conditionFalse)
        let ordinary = evaluation(consecratedSwing(daemon: false, opposing: nil))
        XCTAssertTrue(ordinary.questions.isEmpty, "no demon, nothing to ask")
        XCTAssertEqual(reason("GRW_karmaleObjekte", in: ordinary), .conditionFalse)
    }

    func testTheRuleAndTheWeaponBothHaveToBeOn() {
        arm("Rabenschnabel", technique: "CT_5", reach: "Mittel")
        hero.setConsecrated("Rabenschnabel", true)
        XCTAssertEqual(DamageModifiers.multiplier(situation: consecratedSwing(daemon: true, opposing: true)), .unchanged, "Fokusregel off")
        XCTAssertEqual(reason("GRW_karmaleObjekte", in: evaluation(consecratedSwing(daemon: true, opposing: true))), .conditionFalse)
        hero.setFokusRule(.karmaleObjekte, active: true)
        hero.setConsecrated("Rabenschnabel", false)
        XCTAssertEqual(DamageModifiers.multiplier(situation: consecratedSwing(daemon: true, opposing: true)), .unchanged, "an ordinary blade")
        XCTAssertEqual(reason("GRW_karmaleObjekte", in: evaluation(consecratedSwing(daemon: true, opposing: true))), .conditionFalse)
    }

    // MARK: - Verweichlicht (DISADV_57)

    private func probe(_ talentId: String, woundEffect: Bool) -> Situation {
        var s = Situation(hero: hero, domain: .talentCheck)
        s.talentId = talentId
        s.isWoundEffectProbe = woundEffect
        return s
    }

    func testVerweichlichtMakesTheWundeffektProbeTwoHarder() {
        own("DISADV_57", "Verweichlicht", list: \.disadvantages)
        let probeLines = lines(probe(Talent.selbstbeherrschungRuleId, woundEffect: true))
        XCTAssertEqual(value("DISADV_57", in: probeLines), -2)
        let line = probeLines.first { $0.ruleId == "DISADV_57" }
        XCTAssertEqual(line?.isZustand, false, "a Nachteil's penalty, not a Zustand — it must not feed the −5 Zustand cap")
        XCTAssertEqual(line?.source, "Verweichlicht")
        XCTAssertEqual(reason("DISADV_57", in: evaluation(probe(Talent.selbstbeherrschungRuleId, woundEffect: false))), .conditionFalse)
        // wrongDomain here is the evaluator's fallback for "no clause landed and no
        // reason was recorded" — DISADV_57's target is TAL_8, so on TAL_10 it is as
        // silent as a rule about a domain this check is not.
        XCTAssertEqual(reason("DISADV_57", in: evaluation(probe(Talent.sinnesschaerfeRuleId, woundEffect: true))), .wrongDomain)
    }

    func testWithoutTheNachteilTheProbeIsUnmodified() {
        XCTAssertNil(value("DISADV_57", in: lines(probe(Talent.selbstbeherrschungRuleId, woundEffect: true))))
    }

    /// `Situation.woundEffectProbe` is what both `CombatWoundEffectPanel`'s preview
    /// number and `TalentProbeModal`'s roll are built from — this is the total the
    /// panel must add on top of `WoundEffectResolver.probeModifier` so the two agree.
    private func woundEffectEngineTotal() -> Int {
        ModifierEngine.shared.evaluate(
            context: Situation.woundEffectProbe(hero: hero, talentId: Talent.selbstbeherrschungRuleId)
        ).reduce(0) { $0 + $1.value }
    }

    func testWoundEffectProbeHelperIsWhatThePanelMustAddToItsPreview() {
        XCTAssertEqual(woundEffectEngineTotal(), 0, "a plain hero adds nothing beyond the Wundschwelle penalty")
        own("DISADV_57", "Verweichlicht", list: \.disadvantages)
        XCTAssertEqual(woundEffectEngineTotal(), -2)
        // Betäubung (COND_2) penalises every check domain, talentCheck included, so
        // it stacks on top of Verweichlicht — the modal rolls with both.
        hero.setStateLevel("betaeubung", level: 1)
        XCTAssertEqual(woundEffectEngineTotal(), -3)
    }
}
