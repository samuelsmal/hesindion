import XCTest
import SwiftData
@testable import Hesindion

/// Defence-side Trefferzonen rules: Wundschwelle multiples, the Selbstbeherrschung
/// probe modifier, and what a failed probe applies to the hero.
final class WoundEffectApplicationTests: XCTestCase {

    /// In-memory hero with a given Wundschwelle. `TestData` is snapshot-only, so this
    /// mirrors `StateModifiersTests.makeHero`.
    private func makeHero(ws: Int, lp: Int = 30) -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self, Attributes.self,
            configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T")
        ctx.insert(hero)
        hero.derivedValues = DerivedValues(
            lebensenergie: LifeEnergyValue(base: lp, bonus: 0, purchased: 0, max: lp, current: lp),
            astralenergie: nil, karmaenergie: nil,
            seelenkraft: ResourceValue(base: 0, bonus: 0, max: 0),
            zaehigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            ausweichen: ComputedValue(value: 0, bonus: 0, max: 0),
            initiative: ComputedValue(value: 0, bonus: 0, max: 0),
            geschwindigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            wundschwelle: ComputedValue(value: ws, bonus: 0, max: ws),
            schicksalspunkte: MutableResourceValue(current: 0, bonus: 0, max: 0))
        return hero
    }

    // MARK: - Wundschwelle arithmetic

    func testMultipleBoundaries() {
        XCTAssertEqual(WoundEffectResolver.multiple(damage: 5, wundschwelle: 6), 0)
        XCTAssertEqual(WoundEffectResolver.multiple(damage: 6, wundschwelle: 6), 1)
        XCTAssertEqual(WoundEffectResolver.multiple(damage: 11, wundschwelle: 6), 1)
        XCTAssertEqual(WoundEffectResolver.multiple(damage: 12, wundschwelle: 6), 2)
    }

    /// The Regelwiki's worked example, verbatim.
    func testRulesWorkedExample() {
        XCTAssertEqual(WoundEffectResolver.probeModifier(damage: 6,  wundschwelle: 6), -1)
        XCTAssertEqual(WoundEffectResolver.probeModifier(damage: 12, wundschwelle: 6), -2)
        XCTAssertEqual(WoundEffectResolver.probeModifier(damage: 18, wundschwelle: 6), -3)
    }

    func testZeroWundschwelleNeverTriggers() {
        XCTAssertEqual(WoundEffectResolver.multiple(damage: 99, wundschwelle: 0), 0)
        XCTAssertEqual(WoundEffectResolver.probeModifier(damage: 99, wundschwelle: 0), 0)
    }

    func testNegativeWundschwelleNeverTriggers() {
        XCTAssertEqual(WoundEffectResolver.multiple(damage: 99, wundschwelle: -3), 0)
    }

    // MARK: - Applying a failed probe

    func testKopfRaisesBetaeubungAndClamps() {
        let hero = makeHero(ws: 6)
        var extra: Int? = nil
        WoundEffectResolver.apply(.kopf, to: hero, extraDamage: &extra)
        XCTAssertEqual(hero.level(of: "betaeubung"), 1)
        XCTAssertNil(extra, "Kopf must not produce extra damage")

        for _ in 0..<5 { WoundEffectResolver.apply(.kopf, to: hero, extraDamage: &extra) }
        XCTAssertEqual(hero.level(of: "betaeubung"), 4, "setStateLevel clamps Zustände at 4")
    }

    func testBeineSetsLiegend() {
        let hero = makeHero(ws: 6)
        var extra: Int? = nil
        WoundEffectResolver.apply(.beine, to: hero, extraDamage: &extra)
        XCTAssertTrue(hero.hasState("liegend"))
        XCTAssertNil(extra, "Beine must not produce extra damage")
    }

    func testTorsoProducesExtraDamageAndAppliesNoState() {
        let hero = makeHero(ws: 6)
        var extra: Int? = nil
        WoundEffectResolver.apply(.torso, to: hero, extraDamage: &extra)
        XCTAssertNotNil(extra)
        XCTAssertTrue((2...4).contains(extra ?? 0), "1W3+1 must land in 2...4, got \(String(describing: extra))")
        XCTAssertTrue(hero.states.isEmpty, "Torso applies no Zustand")
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 30,
                       "The resolver must not write LP — the view folds extra damage into its single write")
    }

    func testArmeIsAReminderOnly() {
        let hero = makeHero(ws: 6)
        var extra: Int? = nil
        WoundEffectResolver.apply(.arme, to: hero, extraDamage: &extra)
        XCTAssertNil(extra)
        XCTAssertTrue(hero.states.isEmpty, "Arme is a GM reminder — nothing is applied automatically")
    }

    func testTorsoExtraDamageIsSeeded() {
        var rng = SplitMix64(seed: 42)   // defined in DiceRollerTests.swift
        let extra = WoundEffectResolver.rollExtraDamage(count: 1, sides: 3, flat: 1, using: &rng)
        XCTAssertTrue((2...4).contains(extra), "1W3+1 must land in 2...4, got \(extra)")
    }

    func testSeededExtraDamageIsReproducible() {
        var a = SplitMix64(seed: 7)
        var b = SplitMix64(seed: 7)
        XCTAssertEqual(
            WoundEffectResolver.rollExtraDamage(count: 1, sides: 3, flat: 1, using: &a),
            WoundEffectResolver.rollExtraDamage(count: 1, sides: 3, flat: 1, using: &b))
    }

    // MARK: - resolve()

    func testSuccessfulProbeAppliesNothing() {
        let hero = makeHero(ws: 6)
        WoundEffectResolver.resolve(zone: .beine, probeSucceeded: true, hero: hero)
        XCTAssertFalse(hero.hasState("liegend"))
    }

    func testFailedProbeResolvesTheEffect() {
        let hero = makeHero(ws: 6)
        WoundEffectResolver.resolve(zone: .kopf, probeSucceeded: false, hero: hero)
        XCTAssertEqual(hero.level(of: "betaeubung"), 1)
    }

    // MARK: - Zone-analogue coverage

    func testNonHumanoidLegZonesBehaveLikeBeine() {
        for zone in [HitZone.vordereBeine, .hintereBeine] {
            let hero = makeHero(ws: 6)
            var extra: Int? = nil
            WoundEffectResolver.apply(zone, to: hero, extraDamage: &extra)
            XCTAssertTrue(hero.hasState("liegend"), "\(zone) should knock the target prone")
        }
    }

    // MARK: - The single LP write

    func testTotalDamageFoldsExtraIntoOneValue() {
        XCTAssertEqual(WoundEffectResolver.totalDamage(effective: 10, extra: nil), 10)
        XCTAssertEqual(WoundEffectResolver.totalDamage(effective: 10, extra: 3), 13)
        XCTAssertEqual(WoundEffectResolver.totalDamage(effective: 0, extra: 2), 2)
    }

    // MARK: - I6: the confirm-time decision (Task 11's "LP written exactly once")
    //
    // `effectThreatens` / `effectApplies` / `confirmDamage` are the pieces the view
    // used to compute privately (`CombatTakeDamageView.applyDamage()`), untestable
    // there. Extracting them means a regression — writing LP twice, or applying
    // Torso's extra damage without the hit damage — now has somewhere to fail.

    func testTrefferzonenOffNeverThreatens() {
        XCTAssertFalse(WoundEffectResolver.effectThreatens(
            zonesActive: false, hasZone: true, damage: 20, wundschwelle: 6))
    }

    func testRuleOnButNoZoneNeverThreatens() {
        XCTAssertFalse(WoundEffectResolver.effectThreatens(
            zonesActive: true, hasZone: false, damage: 20, wundschwelle: 6))
    }

    func testZoneBelowWundschwelleNeverThreatens() {
        XCTAssertFalse(WoundEffectResolver.effectThreatens(
            zonesActive: true, hasZone: true, damage: 5, wundschwelle: 6))
    }

    func testZoneAtWundschwelleThreatens() {
        XCTAssertTrue(WoundEffectResolver.effectThreatens(
            zonesActive: true, hasZone: true, damage: 6, wundschwelle: 6))
    }

    /// An unrolled probe means the GM has not adjudicated the wound effect. Nothing
    /// may be applied on that basis — the app never decides a rules outcome for the
    /// table. This replaces the old "no Selbstbeherrschung → effect applies" branch:
    /// Selbstbeherrschung is a DSA 5 basic ability every hero has, so that premise
    /// was false, and auto-applying also made *declining* to roll strictly better
    /// than rolling.
    func testUnrolledProbeNeverApplies() {
        XCTAssertFalse(WoundEffectResolver.effectApplies(threatens: true, probeSucceeded: nil))
    }

    func testFailedProbeApplies() {
        XCTAssertTrue(WoundEffectResolver.effectApplies(threatens: true, probeSucceeded: false))
    }

    func testSucceededProbeDoesNotApply() {
        XCTAssertFalse(WoundEffectResolver.effectApplies(threatens: true, probeSucceeded: true))
    }

    func testUnthreatenedNeverApplies() {
        XCTAssertFalse(WoundEffectResolver.effectApplies(threatens: false, probeSucceeded: nil))
        XCTAssertFalse(WoundEffectResolver.effectApplies(threatens: false, probeSucceeded: false))
    }

    // MARK: - Selbstbeherrschung is a basic ability

    /// A hero whose Selbstbeherrschung row is missing is a data anomaly, not a rules
    /// case. The probe stays available at Fertigkeitswert 0 — in DSA you may always
    /// attempt a Talentprobe — and the check attributes (MU/MU/KO) exist on every hero.
    func testMissingTalentFallsBackToAZeroValueProbe() {
        let hero = makeHero(ws: 6)
        XCTAssertTrue(hero.talents.isEmpty, "precondition: no talent rows at all")

        let talent = hero.selbstbeherrschung
        XCTAssertEqual(talent.name, "Selbstbeherrschung")
        XCTAssertEqual(talent.value, 0, "FW 0 probe, not a refusal and not an auto-fail")
        XCTAssertEqual(TalentProbeAttributes.checks["Selbstbeherrschung"], ["MU", "MU", "KO"])
        XCTAssertFalse(
            hero.talents.contains { $0 === talent },
            "the stand-in must not be grafted onto the hero")
    }

    /// The real row wins whenever it exists, at whatever FW the hero has.
    func testExistingTalentIsUsedVerbatim() {
        let hero = makeHero(ws: 6)
        let real = Talent(ruleId: "TAL_8", name: "Selbstbeherrschung", value: 7, category: "Körpertalente")
        hero.talents.append(real)

        XCTAssertTrue(hero.selbstbeherrschung === real)
        XCTAssertEqual(hero.selbstbeherrschung.value, 7)
    }

    /// The heart of the fix: with the talent missing, *not* rolling must leave the
    /// hero untouched — no Betäubung, no Liegend, no extra damage, no LP change.
    func testMissingTalentAndUnrolledProbeAppliesNothing() {
        let hero = makeHero(ws: 6)
        XCTAssertTrue(hero.talents.isEmpty, "precondition: no Selbstbeherrschung row")

        let threatens = WoundEffectResolver.effectThreatens(
            zonesActive: true, hasZone: true, damage: 12, wundschwelle: 6)
        XCTAssertTrue(threatens)

        let applies = WoundEffectResolver.effectApplies(threatens: threatens, probeSucceeded: nil)
        XCTAssertFalse(applies, "a missing talent row must never auto-apply a wound effect")

        for zone in [HitZone.kopf, .torso, .beine, .arme] {
            let (extra, total) = WoundEffectResolver.confirmDamage(
                zoneHit: HitZoneHit(zone: zone, side: nil),
                effectApplies: applies, effectiveDamage: 12, hero: hero)
            XCTAssertNil(extra, "\(zone): no extra damage without an adjudicated probe")
            XCTAssertEqual(total, 12, "\(zone): only the hit damage is written")
        }
        XCTAssertTrue(hero.states.isEmpty, "no Zustand may be applied")
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 30)
    }

    func testConfirmDamageWithNoZoneNeverAddsExtra() {
        let hero = makeHero(ws: 6)
        let (extra, total) = WoundEffectResolver.confirmDamage(
            zoneHit: nil, effectApplies: true, effectiveDamage: 10, hero: hero)
        XCTAssertNil(extra)
        XCTAssertEqual(total, 10)
    }

    func testConfirmDamageWhenEffectDoesNotApplyNeverAddsExtra() {
        let hero = makeHero(ws: 6)
        let torsoHit = HitZoneHit(zone: .torso, side: nil)
        let (extra, total) = WoundEffectResolver.confirmDamage(
            zoneHit: torsoHit, effectApplies: false, effectiveDamage: 10, hero: hero)
        XCTAssertNil(extra, "extra damage must never be rolled when the effect does not apply")
        XCTAssertEqual(total, 10)
        XCTAssertEqual(hero.derivedValues?.lebensenergie.current, 30, "confirmDamage must not itself write LP")
    }

    func testConfirmDamageFoldsTorsoExtraIntoTotal() {
        let hero = makeHero(ws: 6)
        let torsoHit = HitZoneHit(zone: .torso, side: nil)
        let (extra, total) = WoundEffectResolver.confirmDamage(
            zoneHit: torsoHit, effectApplies: true, effectiveDamage: 10, hero: hero)
        XCTAssertNotNil(extra)
        XCTAssertTrue((2...4).contains(extra ?? 0), "1W3+1 must land in 2...4, got \(String(describing: extra))")
        XCTAssertEqual(total, 10 + (extra ?? 0), "extra damage can never apply without the hit damage")
        XCTAssertTrue(hero.states.isEmpty, "Torso applies no Zustand")
    }

    func testConfirmDamageWithKopfRaisesStateAndAddsNoExtra() {
        let hero = makeHero(ws: 6)
        let kopfHit = HitZoneHit(zone: .kopf, side: nil)
        let (extra, total) = WoundEffectResolver.confirmDamage(
            zoneHit: kopfHit, effectApplies: true, effectiveDamage: 7, hero: hero)
        XCTAssertNil(extra, "Kopf must not produce extra damage")
        XCTAssertEqual(total, 7)
        XCTAssertEqual(hero.level(of: "betaeubung"), 1)
    }

    // MARK: - Rüstungsschutz (RS)
    //
    // RS is what decides whether the Wundschwelle is crossed at all, and until now
    // every test fed a pre-computed `effectiveDamage`, so the subtraction itself was
    // never exercised in this path.

    func testRSReducesDamageBelowWundschwelleSoNothingThreatens() {
        // 8 TP against RS 4 is 4 damage — under a Wundschwelle of 6.
        let damage = WoundEffectResolver.effectiveDamage(tp: 8, rs: 4)
        XCTAssertEqual(damage, 4)
        XCTAssertEqual(WoundEffectResolver.multiple(damage: damage, wundschwelle: 6), 0)
        XCTAssertFalse(WoundEffectResolver.effectThreatens(
            zonesActive: true, hasZone: true, damage: damage, wundschwelle: 6))
    }

    func testRSStillLeavesEnoughDamageToThreaten() {
        // 12 TP against RS 4 is 8 damage — one multiple of a Wundschwelle of 6.
        let damage = WoundEffectResolver.effectiveDamage(tp: 12, rs: 4)
        XCTAssertEqual(damage, 8)
        XCTAssertEqual(WoundEffectResolver.multiple(damage: damage, wundschwelle: 6), 1)
        XCTAssertEqual(WoundEffectResolver.probeModifier(damage: damage, wundschwelle: 6), -1)
    }

    func testRSShiftsTheMultiplierDownAFullStep() {
        // Same 18 TP: unarmoured it is ×3, behind RS 6 it is only ×2.
        XCTAssertEqual(WoundEffectResolver.multiple(
            damage: WoundEffectResolver.effectiveDamage(tp: 18, rs: 0), wundschwelle: 6), 3)
        XCTAssertEqual(WoundEffectResolver.multiple(
            damage: WoundEffectResolver.effectiveDamage(tp: 18, rs: 6), wundschwelle: 6), 2)
    }

    func testRSAtOrAboveTPAbsorbsTheHitEntirely() {
        XCTAssertEqual(WoundEffectResolver.effectiveDamage(tp: 5, rs: 5), 0)
        XCTAssertEqual(WoundEffectResolver.effectiveDamage(tp: 3, rs: 9), 0, "never negative")
        XCTAssertFalse(WoundEffectResolver.effectThreatens(
            zonesActive: true, hasZone: true,
            damage: WoundEffectResolver.effectiveDamage(tp: 3, rs: 9), wundschwelle: 6))
    }

    func testRSComesFromEquippedArmourOnly() {
        let hero = makeHero(ws: 6)
        hero.armors.append(Armor(name: "Kettenhemd", protectionValue: 4,
                                 encumbrance: 2, weight: 10, isEquipped: true))
        hero.armors.append(Armor(name: "Helm im Rucksack", protectionValue: 2,
                                 encumbrance: 1, weight: 3, isEquipped: false))
        XCTAssertEqual(hero.totalRS, 4, "unequipped armour must not protect")
        XCTAssertEqual(WoundEffectResolver.effectiveDamage(tp: 10, rs: hero.totalRS), 6)
    }

    // MARK: - RS together with the Wundschwelle-modifying traits
    //
    // Eisern (ADV_54, +1) and Gläsern (DISADV_56, −1) are the only traits that touch
    // this comparison — they move the threshold while RS moves the damage, so the two
    // can cancel or compound. Belastungsgewöhnung (SA_41) is deliberately absent here:
    // it reduces Belastung, not RS or damage.

    private func wundschwelle(ko: Int, adv: [String] = [], disadv: [String] = []) -> Int {
        let t = { (id: String) in HeroTrait(ruleId: id, name: id, tier: nil, sid: nil) }
        let ws = DerivedValueFormulas.wundschwelle(
            ko: ko, advantages: adv.map(t), disadvantages: disadv.map(t))
        return ws.base + ws.bonus
    }

    func testEisernRaisesTheThresholdSoArmouredHeroEscapesTheEffect() {
        // KO 11 → Wundschwelle 6; Eisern makes it 7.
        let damage = WoundEffectResolver.effectiveDamage(tp: 12, rs: 6)   // 6 damage
        XCTAssertEqual(damage, 6)
        XCTAssertEqual(WoundEffectResolver.multiple(
            damage: damage, wundschwelle: wundschwelle(ko: 11)), 1, "×1 without Eisern")
        XCTAssertEqual(WoundEffectResolver.multiple(
            damage: damage, wundschwelle: wundschwelle(ko: 11, adv: ["ADV_54"])), 0,
            "Eisern lifts the threshold above the damage")
    }

    func testGlaesernLowersTheThresholdSoArmourNoLongerSaves() {
        // KO 12 → Wundschwelle 6; Gläsern makes it 5.
        let damage = WoundEffectResolver.effectiveDamage(tp: 11, rs: 6)   // 5 damage
        XCTAssertEqual(damage, 5)
        XCTAssertEqual(WoundEffectResolver.multiple(
            damage: damage, wundschwelle: wundschwelle(ko: 12)), 0, "armour saves without Gläsern")
        XCTAssertEqual(WoundEffectResolver.multiple(
            damage: damage, wundschwelle: wundschwelle(ko: 12, disadv: ["DISADV_56"])), 1,
            "Gläsern drops the threshold onto the damage")
    }

    func testEisernAndGlaesernTogetherLeaveTheThresholdUnchangedBehindArmour() {
        let damage = WoundEffectResolver.effectiveDamage(tp: 12, rs: 6)
        XCTAssertEqual(
            WoundEffectResolver.multiple(damage: damage, wundschwelle: wundschwelle(ko: 11)),
            WoundEffectResolver.multiple(damage: damage, wundschwelle: wundschwelle(
                ko: 11, adv: ["ADV_54"], disadv: ["DISADV_56"])))
    }
}
