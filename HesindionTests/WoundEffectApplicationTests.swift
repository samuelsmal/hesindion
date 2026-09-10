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

    func testNoTalentAlwaysApplies() {
        XCTAssertTrue(WoundEffectResolver.effectApplies(threatens: true, hasTalent: false, probeSucceeded: nil))
    }

    func testFailedProbeApplies() {
        XCTAssertTrue(WoundEffectResolver.effectApplies(threatens: true, hasTalent: true, probeSucceeded: false))
    }

    func testSucceededProbeDoesNotApply() {
        XCTAssertFalse(WoundEffectResolver.effectApplies(threatens: true, hasTalent: true, probeSucceeded: true))
    }

    func testUnthreatenedNeverAppliesRegardlessOfTalentOrProbe() {
        XCTAssertFalse(WoundEffectResolver.effectApplies(threatens: false, hasTalent: false, probeSucceeded: nil))
        XCTAssertFalse(WoundEffectResolver.effectApplies(threatens: false, hasTalent: true, probeSucceeded: false))
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
}
