import XCTest
import SwiftData
@testable import Hesindion

/// The Patzertabellen's *temporary* effects: a level of Schmerz for three
/// Kampfrunden, a stumble the next roll pays for, a dented weapon that stays
/// dented, a jammed crossbow and a round with no defences.
///
/// All five are flags on the hero's combat-session block rather than states,
/// because none of them is a Zustand the catalog knows: Schmerz is derived from
/// LP and `setStateLevel` refuses it, and "die nächste Handlung" is not a
/// condition at all. The boundaries are what these tests are for — a temporary
/// effect that never expires is worse than one the app never applied.
@MainActor
final class FumbleTemporaryEffectTests: XCTestCase {

    private var context: ModelContext!
    private var hero: Hero!

    override func setUpWithError() throws {
        context = ModelContext(try TestData.makeContainer())
        hero = Hero(name: "Patzer")
        context.insert(hero)
        // A fight is running: every temporary effect is scoped to one.
        hero.activeCombatId = UUID()
        hero.activeCombatRound = 1
    }

    override func tearDown() { context = nil; hero = nil }

    // MARK: - Temporary Schmerz

    func testAPatzerAddsALevelOfSchmerzForThreeRounds() {
        XCTAssertEqual(hero.effectiveSchmerzLevel, 0, "a healthy hero has no Schmerz")

        hero.addTemporarySchmerz(rolledInRound: 1)
        XCTAssertEqual(hero.temporarySchmerzLastRound, 3, "rolled in 1 counts through 3")

        // Rounds 1, 2 and 3 — three Kampfrunden — see it; round 4 does not.
        for round in 1...3 {
            hero.activeCombatRound = round
            XCTAssertEqual(hero.effectiveSchmerzLevel, 1, "round \(round) should still hurt")
            XCTAssertEqual(hero.level(of: "schmerz"), 1)
        }
        hero.activeCombatRound = 4
        XCTAssertEqual(hero.effectiveSchmerzLevel, 0, "the fourth round is past it")
        XCTAssertFalse(hero.temporarySchmerzActive)
    }

    func testASecondPatzerAddsALevelAndRestartsTheClock() {
        hero.addTemporarySchmerz(rolledInRound: 1)
        hero.activeCombatRound = 3
        hero.addTemporarySchmerz(rolledInRound: 3)

        XCTAssertEqual(hero.temporarySchmerzLevels, 2)
        XCTAssertEqual(hero.temporarySchmerzLastRound, 5, "the clock restarts from the second one")
        XCTAssertEqual(hero.effectiveSchmerzLevel, 2)

        // Once it has run out, the next one starts again at one level.
        hero.activeCombatRound = 6
        XCTAssertEqual(hero.effectiveSchmerzLevel, 0)
        hero.addTemporarySchmerz(rolledInRound: 6)
        XCTAssertEqual(hero.temporarySchmerzLevels, 1, "an expired one does not accumulate")
    }

    func testTheTemporaryLevelStacksOnTheLPDerivedOneAndIsStillCapped() throws {
        // 9 of 40 LP: at or below a quarter → Schmerz III.
        hero.derivedValues = makeDerivedValues(maxLP: 40, currentLP: 9)
        XCTAssertEqual(hero.schmerzLevel, 3)

        hero.addTemporarySchmerz(rolledInRound: 1)
        XCTAssertEqual(hero.schmerzLevel, 4, "the Patzer's level rides on top of the LP one")

        hero.addTemporarySchmerz(rolledInRound: 1)
        XCTAssertEqual(hero.schmerzLevel, 5, "the raw total is not capped")
        XCTAssertEqual(hero.effectiveSchmerzLevel, 4, "…but the effective one is")
    }

    func testZaeherHundStillTakesOneOffTheTotal() {
        hero.advantages = [HeroTrait(ruleId: "ADV_49", name: "Zäher Hund", tier: nil)]
        XCTAssertTrue(hero.hasZaeherHund)

        hero.addTemporarySchmerz(rolledInRound: 1)
        XCTAssertEqual(hero.schmerzLevel, 1)
        XCTAssertEqual(hero.effectiveSchmerzLevel, 0, "Zäher Hund swallows the first level")

        hero.addTemporarySchmerz(rolledInRound: 1)
        XCTAssertEqual(hero.effectiveSchmerzLevel, 1, "the second one gets through")
    }

    func testEndingTheFightClearsIt() {
        hero.addTemporarySchmerz(rolledInRound: 1)
        XCTAssertEqual(hero.effectiveSchmerzLevel, 1)

        hero.clearCombatSession()
        XCTAssertEqual(hero.temporarySchmerzLevels, 0)
        XCTAssertEqual(hero.effectiveSchmerzLevel, 0)
    }

    func testItNeedsARunningFight() {
        hero.addTemporarySchmerz(rolledInRound: 1)
        hero.activeCombatId = nil
        XCTAssertFalse(hero.temporarySchmerzActive, "no fight, no round to count against")
        XCTAssertEqual(hero.effectiveSchmerzLevel, 0)
    }

    // MARK: - Stolpern

    func testStolpernIsTwoHarderOnEveryCombatRollAndGoneAfterOne() {
        for domain in [RuleDomain.meleeAttack, .meleeParry, .meleeDodge, .rangedAttack] {
            hero.activeCombatStumble = true
            let line = stumbleLine(domain)
            XCTAssertEqual(line?.value, -2, "\(domain) should pay the Stolpern")

            hero.consumeStumble()
            XCTAssertNil(stumbleLine(domain), "\(domain) should be clear once it is spent")
        }
    }

    func testStolpernLeavesANonCombatCheckAlone() {
        hero.activeCombatStumble = true
        XCTAssertNil(stumbleLine(.talentCheck))
        XCTAssertNil(stumbleLine(.spellCasting))
    }

    func testEndingTheFightClearsTheStumble() {
        hero.activeCombatStumble = true
        hero.clearCombatSession()
        XCTAssertFalse(hero.activeCombatStumble)
    }

    // MARK: - Beschädigte Ausrüstung

    func testOnlyTheDamagedThingInTheHandIsHarder() {
        equipSwordAndShield()
        hero.setItemDamaged("Langschwert", true)

        XCTAssertEqual(damagedLine(.meleeAttack, itemInHand: nil)?.value, -2,
                       "the main weapon is the default answer to what is in the hand")
        XCTAssertEqual(damagedLine(.meleeParry, itemInHand: "Langschwert")?.value, -2)

        // The shield is undamaged, so a shield parry is unmodified — a dented
        // sword does not make the shield harder to raise.
        XCTAssertNil(damagedLine(.meleeParry, itemInHand: "Buckler"))
    }

    func testADamagedShieldOnlyCostsTheShieldParry() {
        equipSwordAndShield()
        hero.setItemDamaged("Buckler", true)

        XCTAssertEqual(damagedLine(.meleeParry, itemInHand: "Buckler")?.value, -2)
        XCTAssertNil(damagedLine(.meleeParry, itemInHand: "Langschwert"))
        XCTAssertNil(damagedLine(.meleeAttack, itemInHand: nil))
    }

    func testTheRangedTableCostsFour() {
        let bow = RangedWeapon(name: "Kurzbogen", combatTechniqueId: "CT_2",
                               damage: "1W6+2", at: 10, range: "10/20/40", weight: 1)
        hero.rangedWeapons = [bow]
        hero.selectedRangedWeaponName = "Kurzbogen"
        hero.setItemDamaged("Kurzbogen", true)

        XCTAssertEqual(damagedLine(.rangedAttack, itemInHand: nil)?.value, -4,
                       "the Fernkampf table says −4, not −2")
    }

    func testTheDamageSurvivesTheEndOfTheFight() {
        equipSwordAndShield()
        hero.setItemDamaged("Langschwert", true)
        hero.clearCombatSession()
        XCTAssertTrue(hero.isItemDamaged("Langschwert"),
                      "it is repaired at a smithy, not by the fight ending")
    }

    func testRepairingTakesItOffTheList() {
        hero.setItemDamaged("Langschwert", true)
        hero.setItemDamaged("Langschwert", true)   // idempotent
        XCTAssertEqual(hero.damagedItems, ["Langschwert"])

        hero.setItemDamaged("Langschwert", false)
        XCTAssertTrue(hero.damagedItems.isEmpty)
        XCTAssertFalse(hero.isItemDamaged("Langschwert"))
        XCTAssertFalse(hero.isItemDamaged(nil))
    }

    // MARK: - Ladehemmung and Zu konzentriert

    func testTheJamRunsForTwoCompleteRoundsAndIsClearedWithTheSession() {
        hero.applyRangedJam(rolledInRound: 2)
        XCTAssertEqual(hero.activeCombatJamUntilRound, 4)

        for round in 2...4 {
            hero.activeCombatRound = round
            XCTAssertTrue(hero.isRangedWeaponJammed, "round \(round) is still clearing the weapon")
        }
        hero.activeCombatRound = 5
        XCTAssertFalse(hero.isRangedWeaponJammed)

        hero.applyRangedJam(rolledInRound: 5)
        hero.clearCombatSession()
        XCTAssertFalse(hero.isRangedWeaponJammed)
        XCTAssertEqual(hero.activeCombatJamUntilRound, 0)
    }

    func testZuKonzentriertLastsUntilTheNextOwnActionAndIsClearedWithTheSession() {
        hero.activeCombatNoDefense = true
        hero.beginOwnAction()
        XCTAssertFalse(hero.activeCombatNoDefense)

        hero.activeCombatNoDefense = true
        hero.clearCombatSession()
        XCTAssertFalse(hero.activeCombatNoDefense)
    }

    /// The other end of "bis zur nächsten Aktion": a hero who takes no action at
    /// all still gets a next round. An archer who spends two rounds reloading
    /// never opens an action screen, and without this the fumble would bar every
    /// parry and dodge for the rest of the fight.
    func testZuKonzentriertAlsoEndsWithTheRound() {
        hero.activeCombatNoDefense = true
        hero.beginCombatRound()
        XCTAssertFalse(hero.activeCombatNoDefense, "a new Kampfrunde lifts it too")
    }

    // MARK: - Re-rolled initiative

    /// Re-rolling initiative sets the round back to 1, and both clocks are
    /// absolute round numbers. Without rebasing, a Zerrung rolled in round 6 —
    /// last round 8, two rounds left — would still say 8 in a count that has just
    /// restarted at 1, and so run for eight more rounds.
    func testRerolledInitiativeKeepsTheRoundsThatWereLeft() {
        hero.activeCombatRound = 6
        hero.addTemporarySchmerz(rolledInRound: 6)
        hero.applyRangedJam(rolledInRound: 6)
        XCTAssertEqual(hero.temporarySchmerzLastRound, 8)
        XCTAssertEqual(hero.activeCombatJamUntilRound, 8)

        // The fight reaches round 7 and initiative is rolled again.
        hero.rebaseCombatClocks(fromRound: 7, toRound: 1)
        hero.activeCombatRound = 1

        XCTAssertEqual(hero.temporarySchmerzLastRound, 2, "rounds 7 and 8 became rounds 1 and 2")
        XCTAssertEqual(hero.activeCombatJamUntilRound, 2)
        XCTAssertEqual(hero.effectiveSchmerzLevel, 1, "it is still running, with two rounds left")
        XCTAssertTrue(hero.isRangedWeaponJammed)

        hero.activeCombatRound = 2
        XCTAssertEqual(hero.effectiveSchmerzLevel, 1)
        hero.activeCombatRound = 3
        XCTAssertEqual(hero.effectiveSchmerzLevel, 0, "and no more than the two")
        XCTAssertFalse(hero.isRangedWeaponJammed)
    }

    func testRerolledInitiativeClearsAClockThatHadAlreadyRunOut() {
        hero.activeCombatRound = 3
        hero.addTemporarySchmerz(rolledInRound: 3)   // through round 5
        hero.applyRangedJam(rolledInRound: 3)

        hero.rebaseCombatClocks(fromRound: 7, toRound: 1)
        hero.activeCombatRound = 1

        XCTAssertEqual(hero.temporarySchmerzLevels, 0, "an expired clock is cleared, not shifted")
        XCTAssertEqual(hero.temporarySchmerzLastRound, 0)
        XCTAssertEqual(hero.activeCombatJamUntilRound, 0)
        XCTAssertEqual(hero.effectiveSchmerzLevel, 0)
        XCTAssertFalse(hero.isRangedWeaponJammed)
    }

    func testRebasingLeavesAHeroWithNoClocksAlone() {
        hero.activeCombatRound = 4
        hero.rebaseCombatClocks(fromRound: 4, toRound: 1)
        XCTAssertEqual(hero.temporarySchmerzLevels, 0)
        XCTAssertEqual(hero.temporarySchmerzLastRound, 0)
        XCTAssertEqual(hero.activeCombatJamUntilRound, 0)
    }

    // MARK: - Which table a parry reads

    /// The fix the previous task's review turned up: a hero who parries with the
    /// sword while carrying a shield was sent to the Schild-Patzertabelle, whose
    /// item results then unequipped the shield.
    func testOnlyAParryMadeWithTheShieldIsAShieldParry() {
        equipSwordAndShield()
        XCTAssertTrue(hero.isShieldInHand("Buckler"))
        XCTAssertFalse(hero.isShieldInHand("Langschwert"))
        XCTAssertFalse(hero.isShieldInHand(nil))

        hero.selectedOffHandName = nil
        hero.selectedShieldName = nil
        XCTAssertFalse(hero.isShieldInHand("Buckler"), "no shield in hand, no shield parry")
    }

    // MARK: - Helpers

    private func makeDerivedValues(maxLP: Int, currentLP: Int) -> DerivedValues {
        DerivedValues(
            lebensenergie: LifeEnergyValue(base: maxLP, bonus: 0, purchased: 0, max: maxLP, current: currentLP),
            astralenergie: nil, karmaenergie: nil,
            seelenkraft: ResourceValue(base: 0, bonus: 0, max: 0),
            zaehigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            ausweichen: ComputedValue(value: 0, bonus: 0, max: 0),
            initiative: ComputedValue(value: 0, bonus: 0, max: 0),
            geschwindigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            wundschwelle: ComputedValue(value: 0, bonus: 0, max: 0),
            schicksalspunkte: MutableResourceValue(current: 0, bonus: 0, max: 0))
    }

    private func equipSwordAndShield() {
        let sword = MeleeWeapon(name: "Langschwert", combatTechniqueId: "CT_12",
                                damage: "1W6+4", at: 12, pa: 8, reach: "Mittel", weight: 2)
        let shield = Shield(name: "Buckler", damage: "1W6", at: 8, pa: 6, paModifier: 1,
                            note: "", reach: "Kurz", structurePoints: 3, weight: 1)
        hero.meleeWeapons = [sword]
        hero.shields = [shield]
        hero.selectedWeaponName = "Langschwert"
        hero.selectedOffHandName = "Buckler"
        hero.selectedShieldName = "Buckler"
    }

    /// Through the engine rather than through the definition's closure, so the
    /// `domains` set is part of what is under test: a definition's closure knows
    /// nothing about which check it was asked for, and calling it directly would
    /// pass for a rule scoped to the wrong domain.
    private static let engine = ModifierEngine(
        modifiers: FumbleModifiers.all, catalog: RuleCatalog(rules: []))

    private func lines(_ domain: RuleDomain, itemInHand: String?) -> [ModifierLine] {
        var s = Situation(hero: hero, domain: domain)
        s.itemInHand = itemInHand
        return Self.engine.evaluate(context: s)
    }

    private func stumbleLine(_ domain: RuleDomain) -> ModifierLine? {
        lines(domain, itemInHand: nil).first { $0.source == L("fumble.modifier.stumble") }
    }

    private func damagedLine(_ domain: RuleDomain, itemInHand: String?) -> ModifierLine? {
        // The engine above holds only the two fumble definitions, and these
        // tests leave the stumble flag alone, so anything else is the damage.
        lines(domain, itemInHand: itemInHand).first { $0.source != L("fumble.modifier.stumble") }
    }
}
