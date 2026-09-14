import XCTest
@testable import Hesindion

/// The reach mismatch penalty, every combination of it.
///
/// The rule is one-sided — reaching *past* a longer weapon costs AT, having the
/// longer weapon costs nothing — and the announcement screen now prints the value
/// per option, so a wrong sign or a missing pair would be visible at the table as
/// a promise the roll does not keep. There was no cover for it at all.
final class WeaponReachTests: XCTestCase {

    /// The full 3×3 matrix, written out rather than derived, so a change to the
    /// rule has to be made here as well as in the code.
    func testEveryCombination() {
        let expected: [WeaponReach: [WeaponReach: Int]] = [
            .kurz:   [.kurz: 0, .mittel: -2, .lang: -4],
            .mittel: [.kurz: 0, .mittel: 0,  .lang: -2],
            .lang:   [.kurz: 0, .mittel: 0,  .lang: 0],
        ]

        for (hero, row) in expected {
            for (opponent, penalty) in row {
                XCTAssertEqual(
                    hero.atPenaltyAgainst(opponent), penalty,
                    "\(hero.rawValue) against \(opponent.rawValue)"
                )
            }
        }
    }

    func testEqualReachIsNeverPenalised() {
        for reach in WeaponReach.allCases {
            XCTAssertEqual(reach.atPenaltyAgainst(reach), 0, "\(reach.rawValue) against itself")
        }
    }

    /// The longer weapon never gains: the rule penalises the shorter side only.
    func testTheLongerWeaponGetsNoBonus() {
        XCTAssertEqual(WeaponReach.lang.atPenaltyAgainst(.kurz), 0)
        XCTAssertEqual(WeaponReach.lang.atPenaltyAgainst(.mittel), 0)
        XCTAssertEqual(WeaponReach.mittel.atPenaltyAgainst(.kurz), 0)
    }

    /// Two steps of mismatch cost twice one step.
    func testTwoStepsCostTwiceOneStep() {
        XCTAssertEqual(
            WeaponReach.kurz.atPenaltyAgainst(.lang),
            2 * WeaponReach.kurz.atPenaltyAgainst(.mittel)
        )
    }

    func testPenaltiesAreNeverPositive() {
        for hero in WeaponReach.allCases {
            for opponent in WeaponReach.allCases {
                XCTAssertLessThanOrEqual(hero.atPenaltyAgainst(opponent), 0)
            }
        }
    }

    // MARK: - Whose reach is it?

    /// The matrix above is only right if the reach fed into it is the reach of
    /// the thing in the hand. It used to be `hero.selectedWeapon` for every
    /// attack, so an off-hand swing, a Schildattacke and a bare fist all borrowed
    /// the main weapon's reach.

    private func armedHero() -> Hero {
        let hero = Hero(name: "Testheld")
        hero.meleeWeapons = [
            MeleeWeapon(name: "Langschwert", combatTechniqueId: "CT_12",
                        damage: "1W6+4", at: 14, pa: 7, reach: "Lang", weight: 2.0),
            MeleeWeapon(name: "Dolch", combatTechniqueId: "CT_1",
                        damage: "1W6+1", at: 12, pa: 5, reach: "Kurz", weight: 0.4),
            MeleeWeapon(name: "Säbel", combatTechniqueId: "CT_12",
                        damage: "1W6+3", at: 13, pa: 7, reach: "Mittel", weight: 1.2),
        ]
        hero.shields = [
            Shield(name: "Großschild", damage: "1W6", at: 8, pa: 5,
                   note: "", reach: "Kurz", structurePoints: 20, weight: 6.0)
        ]
        hero.selectedWeaponName = "Langschwert"
        return hero
    }

    func testEachPieceOfTheLoadoutCarriesItsOwnReach() {
        let hero = armedHero()
        XCTAssertEqual(hero.reach(ofLoadoutNamed: "Langschwert"), .lang)
        XCTAssertEqual(hero.reach(ofLoadoutNamed: "Dolch"), .kurz)
        XCTAssertEqual(hero.reach(ofLoadoutNamed: "Großschild"), .kurz)
    }

    /// Waffenlose Kampftechniken are kurz. This is the case the old code got
    /// worst: `selectedWeapon` is nil for Raufen, the fallback was "Mittel", and
    /// a bare-handed hero closed on a spear for free.
    func testRaufenIsShort() {
        XCTAssertEqual(armedHero().reach(ofLoadoutNamed: "Raufen"), .kurz)
        XCTAssertEqual(WeaponReach.kurz.atPenaltyAgainst(.lang), -4)
    }

    /// A name that matches nothing keeps the value the app used before rather
    /// than inventing a penalty for it.
    func testAnUnknownNameFallsBackToMedium() {
        XCTAssertEqual(armedHero().reach(ofLoadoutNamed: "Sonnenspeer"), .mittel)
    }

    // MARK: - Through the engine

    private func atPenalty(_ hero: Hero, loadout: String?, opponent: WeaponReach) -> Int {
        var situation = Situation(hero: hero, domain: .meleeAttack)
        situation.opponents.current.reach = opponent
        situation.loadoutName = loadout
        return ModifierEngine.shared.evaluate(context: situation)
            .filter { $0.source == L("source.reach") }
            .reduce(0) { $0 + $1.value }
    }

    func testTheEngineUsesTheAnnouncedWeaponNotTheMainOne() {
        let hero = armedHero()   // main weapon is Lang
        XCTAssertEqual(atPenalty(hero, loadout: "Langschwert", opponent: .lang), 0)
        XCTAssertEqual(atPenalty(hero, loadout: "Dolch", opponent: .lang), -4,
                       "The dagger in the off hand reaches like a dagger")
    }

    func testTheEngineFallsBackToTheMainWeapon() {
        XCTAssertEqual(atPenalty(armedHero(), loadout: nil, opponent: .lang), 0)
    }

    /// Beengte Umgebung is the other rule keyed to reach, and it read the same
    /// wrong value: a long weapon is -8 in a corridor, a fist is not.
    func testBeengteUmgebungFollowsTheSameReach() {
        let hero = armedHero()
        func penalty(_ loadout: String) -> Int {
            var situation = Situation(hero: hero, domain: .meleeAttack)
            situation.round.beengteUmgebung = true
            situation.loadoutName = loadout
            return ModifierEngine.shared.evaluate(context: situation)
                .filter { $0.source == L("beengteUmgebung") }
                .reduce(0) { $0 + $1.value }
        }
        XCTAssertEqual(penalty("Langschwert"), -8)
        XCTAssertEqual(penalty("Säbel"), -4)
        XCTAssertEqual(penalty("Dolch"), 0)
    }
}
