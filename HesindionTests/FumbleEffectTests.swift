import XCTest
import SwiftData
@testable import Hesindion

/// The Patzertabellen as data: every entry of all four tables carries a typed
/// effect, the unarmed/dodge shift still maps as it did, and `FumbleEffectResolver`
/// says the right thing about each effect.
///
/// The coverage half exists because the tables were prose only, and the failure
/// mode of prose is silence: a result nobody wired up looks exactly like a result
/// the app deliberately leaves to the GM.
final class FumbleEffectTests: XCTestCase {

    // MARK: - Coverage

    /// Every roll from 2 to 12 is in every table, exactly once, with the effect
    /// this task decided on. Written out per table rather than derived, so
    /// changing what a result does has to be changed here too.
    func testEveryEntryOfEveryTableHasItsEffect() {
        let melee: [Int: FumbleEffect] = [
            2:  .itemLost(permanently: true),
            3:  .itemLost(permanently: false),
            4:  .itemDamaged,
            5:  .itemLost(permanently: false),
            6:  .itemStuck,
            7:  .fall,
            8:  .stumble,
            9:  .pain,
            10: .stupor,
            11: .selfDamage(doubled: false),
            12: .selfDamage(doubled: true),
        ]
        let ranged: [Int: FumbleEffect] = [
            2:  .itemLost(permanently: true),
            3:  .itemLost(permanently: false),
            4:  .itemDamaged,
            5:  .itemLost(permanently: false),
            6:  .friendHit,
            7:  .wildShot,
            8:  .pain,
            9:  .jam,
            10: .noDefense,
            11: .selfDamage(doubled: false),
            12: .selfDamage(doubled: true),
        ]
        let expected: [FumbleTableType: [Int: FumbleEffect]] = [
            .nahkampfAttacke: melee,
            .verteidigungWaffe: melee,
            .verteidigungSchild: melee,
            .fernkampf: ranged,
        ]

        XCTAssertEqual(Set(FumbleTable.allTypes.map(\.rawValue)).count, 4)

        for type in FumbleTable.allTypes {
            let entries = FumbleTable.entries(for: type)
            XCTAssertEqual(entries.map(\.roll), Array(2...12), "\(type.rawValue) is not 2…12")
            for entry in entries {
                XCTAssertEqual(
                    entry.effect, expected[type]?[entry.roll],
                    "\(type.rawValue) \(entry.roll) \"\(entry.title)\" has an unexpected effect")
                XCTAssertFalse(entry.title.isEmpty)
                XCTAssertFalse(entry.description.isEmpty)
            }
        }
    }

    /// Which half of the enum each case is in. The panel renders help for the
    /// automated ones and prose for the rest, so moving a case between the two
    /// has to be a deliberate edit in both places.
    ///
    /// Everything that lands on the hero's own sheet is automated — the five
    /// the first task built, plus the five temporary ones the combat session
    /// now holds. What is left is the two results that happen on the *other*
    /// side of the table, where there is nothing to write to (ADR-0005).
    func testTheAutomatedHalfIsEverythingThatLandsOnTheHerosOwnSheet() {
        for effect in [FumbleEffect.fall, .stupor, .itemLost(permanently: true),
                       .itemLost(permanently: false), .itemStuck,
                       .selfDamage(doubled: false), .selfDamage(doubled: true),
                       .stumble, .pain, .itemDamaged, .jam, .noDefense] {
            XCTAssertTrue(effect.isAutomated, "\(effect) should be automated")
        }
        for effect in [FumbleEffect.friendHit, .wildShot] {
            XCTAssertFalse(effect.isAutomated, "\(effect) belongs to the other side of the table")
        }
    }

    // MARK: - The unarmed/dodge shift

    /// Rolls below 7 get +5 for an unarmed fighter or a dodge, which is what
    /// keeps a bare-handed hero from destroying the weapon they are not holding.
    /// Unchanged by this task — asserted here because the effects now make the
    /// consequence of getting it wrong concrete (an item result with no item).
    func testUnarmedAndDodgeCannotReachTheItemResults() {
        for roll in 2...6 {
            let plain = FumbleTable.lookup(roll, table: .nahkampfAttacke, isUnarmed: false)
            XCTAssertEqual(plain.roll, roll)

            let shifted = FumbleTable.lookup(roll, table: .nahkampfAttacke, isUnarmed: true)
            XCTAssertEqual(shifted.roll, roll + 5, "the +5 shift changed")
            XCTAssertFalse(
                FumbleEffectResolver.unequipsItem(shifted.effect),
                "an unarmed \(roll) reached an item result")
        }
        // 7 and up are untouched.
        for roll in 7...12 {
            XCTAssertEqual(
                FumbleTable.lookup(roll, table: .nahkampfAttacke, isUnarmed: true).roll, roll)
        }
        // And the table is clamped at both ends.
        XCTAssertEqual(FumbleTable.lookup(1, table: .fernkampf, isUnarmed: false).roll, 2)
        XCTAssertEqual(FumbleTable.lookup(99, table: .fernkampf, isUnarmed: false).roll, 12)
    }

    // MARK: - Probes

    func testOnlySturzAndTheStuckWeaponAskForACheck() {
        let sturz = FumbleEffectResolver.probe(for: .fall)
        XCTAssertEqual(sturz?.talentName, "Körperbeherrschung")
        XCTAssertEqual(sturz?.talentRuleId, "TAL_4")
        XCTAssertEqual(sturz?.modifier, -2)
        XCTAssertEqual(sturz?.isRequired, true)

        let stuck = FumbleEffectResolver.probe(for: .itemStuck)
        XCTAssertEqual(stuck?.talentName, "Kraftakt")
        XCTAssertEqual(stuck?.talentRuleId, "TAL_5")
        XCTAssertEqual(stuck?.modifier, -1)
        XCTAssertEqual(stuck?.isRequired, false)

        for effect in [FumbleEffect.stupor, .itemLost(permanently: true),
                       .selfDamage(doubled: false), .stumble, .pain, .itemDamaged,
                       .jam, .noDefense, .friendHit, .wildShot] {
            XCTAssertNil(FumbleEffectResolver.probe(for: effect), "\(effect) asks for no check")
        }
    }

    /// An open question holds the way out — but only the Sturz's. The Kraftakt is
    /// the player's to spend an action on or not.
    func testOnlyTheSturzHoldsTheWayOut() {
        XCTAssertTrue(FumbleEffectResolver.holdsTheWayOut(.fall, probeSucceeded: nil))
        XCTAssertFalse(FumbleEffectResolver.holdsTheWayOut(.fall, probeSucceeded: false))
        XCTAssertFalse(FumbleEffectResolver.holdsTheWayOut(.fall, probeSucceeded: true))
        XCTAssertFalse(FumbleEffectResolver.holdsTheWayOut(.itemStuck, probeSucceeded: nil))
        XCTAssertFalse(FumbleEffectResolver.holdsTheWayOut(.stupor, probeSucceeded: nil))
    }

    // MARK: - What the effects write

    func testOnlyAFailedCheckLaysTheHeroDown() {
        let hero = makeHero()
        FumbleEffectResolver.applyFall(to: hero, probeSucceeded: true)
        XCTAssertFalse(hero.hasState("liegend"), "a passed check must apply nothing")

        FumbleEffectResolver.applyFall(to: hero, probeSucceeded: false)
        XCTAssertEqual(hero.level(of: "liegend"), 1)
    }

    func testTheBeuleRaisesBetaeubungByOneAndStopsAtFour() {
        let hero = makeHero()
        XCTAssertEqual(FumbleEffectResolver.stuporLevel(for: hero), 1)
        FumbleEffectResolver.applyStupor(to: hero)
        XCTAssertEqual(hero.level(of: "betaeubung"), 1)

        FumbleEffectResolver.applyStupor(to: hero)
        XCTAssertEqual(hero.level(of: "betaeubung"), 2)

        for _ in 0..<5 { FumbleEffectResolver.applyStupor(to: hero) }
        XCTAssertEqual(hero.level(of: "betaeubung"), 4, "setStateLevel clamps a Zustand at IV")
    }

    func testOnlyTheItemResultsTakeSomethingOutOfTheHand() {
        XCTAssertTrue(FumbleEffectResolver.unequipsItem(.itemLost(permanently: true)))
        XCTAssertTrue(FumbleEffectResolver.unequipsItem(.itemLost(permanently: false)))
        XCTAssertTrue(FumbleEffectResolver.unequipsItem(.itemStuck))
        // "Beschädigt" leaves the weapon in the hand — it is harder to use, not gone.
        XCTAssertFalse(FumbleEffectResolver.unequipsItem(.itemDamaged))
        XCTAssertFalse(FumbleEffectResolver.unequipsItem(.fall))
    }

    // MARK: - Unzerstörbare Waffen

    /// "Bei unzerstörbaren Waffen: Waffe verloren" is printed on results 2, 3
    /// and 4 of every table that can destroy something, and it points at that
    /// table's own result 5. All three tables, all eleven rolls, so a fourth
    /// table or a changed text cannot quietly stop asking.
    func testResultsTwoThreeAndFourBecomeTheTablesOwnFive() {
        for table in FumbleTable.allTypes {
            let five = FumbleTable.entries(for: table)
                .first { $0.roll == FumbleTable.indestructibleSubstituteRoll }
            XCTAssertNotNil(five, "\(table) has no result 5")

            for entry in FumbleTable.entries(for: table) {
                let substitute = FumbleTable.indestructibleSubstitute(for: entry, table: table)
                if [2, 3, 4].contains(entry.roll) {
                    XCTAssertEqual(substitute?.roll, 5, "\(table) \(entry.roll) should become 5")
                    XCTAssertEqual(substitute?.title, five?.title)
                    XCTAssertEqual(substitute?.effect, .itemLost(permanently: false),
                                   "an indestructible thing is dropped, not destroyed or dented")
                } else {
                    XCTAssertNil(
                        substitute,
                        "\(table) \(entry.roll) (\(entry.title)) says nothing about indestructibility")
                }
            }
        }
    }

    /// The Schild table names the shield, not the weapon, and the substitute has
    /// to be *that* table's fifth result rather than the melee one's.
    func testTheShieldTableSubstitutesTheShieldResult() {
        let destroyed = FumbleTable.lookup(2, table: .verteidigungSchild, isUnarmed: false)
        XCTAssertEqual(destroyed.title, "Schild zerstört")
        let substitute = FumbleTable.indestructibleSubstitute(for: destroyed, table: .verteidigungSchild)
        XCTAssertEqual(substitute?.title, "Schild verloren")
    }

    /// The answer is the hero's, lasts past the fight, and is taken back only on
    /// the hero settings screen — like `damagedItems`, and for the same reason:
    /// a staff is no more breakable once the fighting stops.
    func testTheRememberedAnswerSurvivesTheEndOfTheFight() {
        let hero = makeHero()
        XCTAssertFalse(hero.isItemIndestructible("Magierstab"))

        hero.setItemIndestructible("Magierstab", true)
        hero.setItemIndestructible("Magierstab", true)
        XCTAssertEqual(hero.indestructibleItems, ["Magierstab"], "asked once, stored once")

        hero.activeCombatId = UUID()
        hero.clearCombatSession()
        XCTAssertTrue(hero.isItemIndestructible("Magierstab"),
                      "ending the fight does not make the staff breakable")

        hero.setItemIndestructible("Magierstab", false)
        XCTAssertFalse(hero.isItemIndestructible("Magierstab"))
        XCTAssertFalse(hero.isItemIndestructible(nil))
    }

    // MARK: - Selbst verletzt

    func testTheSelfDamageFormulaIsTheWeaponsOwnAndRaufenWhenUnarmed() {
        XCTAssertEqual(
            FumbleEffectResolver.selfDamageFormula(weaponFormula: "1W6+4", isUnarmed: false),
            "1W6+4")
        XCTAssertEqual(
            FumbleEffectResolver.selfDamageFormula(weaponFormula: "1W6+4", isUnarmed: true),
            "1W6", "unarmed and dodge roll Raufen, not the weapon on the belt")
        XCTAssertEqual(
            FumbleEffectResolver.selfDamageFormula(weaponFormula: nil, isUnarmed: false),
            "1W6")
        XCTAssertEqual(
            FumbleEffectResolver.selfDamageFormula(weaponFormula: "keine", isUnarmed: false),
            "1W6", "an unparseable formula falls back rather than rolling nothing")
    }

    func testTheDoubledResultDoublesTheWholeThing() {
        let plain = FumbleSelfDamage(formula: "1W6+4", rolls: [3], bonus: 4, doubled: false)
        XCTAssertEqual(plain.total, 7)

        let doubled = FumbleSelfDamage(formula: "1W6+4", rolls: [3], bonus: 4, doubled: true)
        XCTAssertEqual(doubled.total, 14, "the bonus is doubled with the dice")

        let negative = FumbleSelfDamage(formula: "1W6-4", rolls: [1], bonus: -4, doubled: false)
        XCTAssertEqual(negative.total, 0, "TP never go below zero")
    }

    func testRollingItReadsTheFormulaThroughDamageFormula() {
        let damage = FumbleEffectResolver.rollSelfDamage(formula: "2W6+3", doubled: true)
        XCTAssertEqual(damage.formula, "2W6+3")
        XCTAssertEqual(damage.rolls.count, 2)
        XCTAssertEqual(damage.bonus, 3)
        XCTAssertTrue(damage.doubled)
        XCTAssertTrue(damage.rolls.allSatisfy { (1...6).contains($0) })
        XCTAssertEqual(damage.total, (damage.rolls.reduce(0, +) + 3) * 2)
    }

    // MARK: - WeaponFumbleExtras (issue #14: the Rabenschnabel's Waffennachteil)

    /// "Nach einem bestätigten Patzer bei einer Attacke erhält der Träger
    /// zusätzlich 1 Stufe Betäubung." — only on an attack, only for this weapon.
    func testTheRabenschnabelAddsBetaeubungOnlyOnAConfirmedAttackPatzer() {
        let onAttack = WeaponFumbleExtras.extraStates(weaponName: "Rabenschnabel", action: .angriff)
        XCTAssertEqual(onAttack.count, 1)
        XCTAssertEqual(onAttack.first?.stateId, "betaeubung")
        XCTAssertEqual(onAttack.first?.levels, 1)

        XCTAssertTrue(
            WeaponFumbleExtras.extraStates(weaponName: "Rabenschnabel", action: .parieren).isEmpty,
            "a shield-parry (or any) Patzer with the Rabenschnabel is not an attack")
        XCTAssertTrue(
            WeaponFumbleExtras.extraStates(weaponName: "Langschwert", action: .angriff).isEmpty,
            "only the Rabenschnabel carries this Waffennachteil")
    }

    /// Ties the Swift table to the imported text (Task 12's `EquipmentEntry`):
    /// the online Regelwiki is the golden truth (owner decision 2026-09-18).
    func testRabenschnabelDisadvantageAgreesWithTheCatalog() throws {
        let entry = try XCTUnwrap(RulesDatabase.shared.equipment(named: "Rabenschnabel"))
        let disadvantage = try XCTUnwrap(entry.disadvantage)
        XCTAssertTrue(
            disadvantage.contains("Betäubung"),
            "the imported Waffennachteil should still mention Betäubung: \(disadvantage)")
    }

    // MARK: - Helpers

    private func makeHero() -> Hero {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Hero.self, HeroStateEntry.self, DerivedValues.self, Attributes.self,
            configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "T")
        ctx.insert(hero)
        return hero
    }
}
