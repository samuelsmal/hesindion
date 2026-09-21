import XCTest
import SwiftData
@testable import Hesindion

/// Covers the two AT definitions that share the *vorteilhafte Position* (`MeleeModifiers`).
///
/// `CHAP_Reiterkampf` clause 2 grants the +2 to **every** mounted hero facing a fighter on
/// foot; `SA_661` clause 1 *raises* that existing ease by a further +2 rather than adding an
/// independent bonus. So the two stack to +4 for a Golgarite with the right loadout, and both
/// collapse to nothing the moment the opponent is not on foot. Before this suite existed, both
/// lines were gated on `golgaritenActive` alone: a plain rider got nothing, and a Golgarite got
/// +4 against another rider.
final class VorteilhaftePositionTests: XCTestCase {

    // MARK: - Fixtures

    private func makeHero(golgaritenLoadout: Bool) -> Hero {
        let schema = Schema([Hero.self, HeroStateEntry.self, DerivedValues.self,
                             Armor.self, MeleeWeapon.self, Shield.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let ctx = ModelContext(container)
        let hero = Hero(name: "Reiter")
        ctx.insert(hero)

        if golgaritenLoadout {
            hero.combatSpecialAbilities = [HeroTrait(ruleId: "SA_661", name: "Golgariten-Stil")]
            hero.meleeWeapons.append(MeleeWeapon(name: "Rabenschnabel", combatTechniqueId: "CT_14",
                                                 damage: "1W6+4", at: 0, pa: 0, reach: "Mittel", weight: 2.5))
            hero.selectedWeaponName = "Rabenschnabel"
            hero.shields.append(Shield(name: "Großschild", damage: "1W6", at: 0, pa: 0,
                                       reach: "Kurz", structurePoints: 6, weight: 6.0))
            hero.selectedShieldName = "Großschild"
            XCTAssertTrue(hero.golgaritenActive(mounted: true),
                          "precondition: style + Rabenschnabel + Großschild while mounted")
        } else {
            XCTAssertFalse(hero.golgaritenActive(mounted: true),
                           "precondition: this hero has no Golgariten-Stil at all")
        }
        return hero
    }

    private func lines(_ hero: Hero, mounted: Bool, opponentOnFoot: Bool) -> [ModifierLine] {
        var ctx = ModifierContext(hero: hero, domain: .meleeAttack)
        ctx.mounted = mounted
        ctx.opponentOnFoot = opponentOnFoot
        return ModifierEngine.shared.evaluate(context: ctx)
    }

    /// Only the two definitions under test — Belastung, reach and the rest are somebody else's.
    private func positionTotal(_ hero: Hero, mounted: Bool, opponentOnFoot: Bool) -> Int {
        lines(hero, mounted: mounted, opponentOnFoot: opponentOnFoot)
            .filter { $0.source == L("source.vorteilhaft") || $0.source == L("source.golgariten") }
            .reduce(0) { $0 + $1.value }
    }

    // MARK: - The four combinations that move numbers

    func testMountedAgainstFootFighterWithoutTheStyleGetsTheChapterEase() {
        let hero = makeHero(golgaritenLoadout: false)
        XCTAssertEqual(positionTotal(hero, mounted: true, opponentOnFoot: true), 2,
                       "CHAP_Reiterkampf clause 2 binds every rider, style or not")
    }

    func testMountedAgainstFootFighterWithTheStyleGetsBoth() {
        let hero = makeHero(golgaritenLoadout: true)
        XCTAssertEqual(positionTotal(hero, mounted: true, opponentOnFoot: true), 4,
                       "SA_661 raises the existing ease: 2 (chapter) + 2 (style)")
    }

    func testMountedAgainstAMountedOpponentGetsNothingEvenWithTheStyle() {
        let hero = makeHero(golgaritenLoadout: true)
        XCTAssertEqual(positionTotal(hero, mounted: true, opponentOnFoot: false), 0,
                       "no advantageous position against another rider, so nothing to raise")
    }

    func testUnmountedHeroGetsNothingEitherWay() {
        for loadout in [false, true] {
            let hero = makeHero(golgaritenLoadout: loadout)
            XCTAssertEqual(positionTotal(hero, mounted: false, opponentOnFoot: true), 0)
            XCTAssertEqual(positionTotal(hero, mounted: false, opponentOnFoot: false), 0)
        }
    }

    // MARK: - Which line is which

    func testTheChapterLineIsTheOneAPlainRiderGets() {
        let hero = makeHero(golgaritenLoadout: false)
        let sources = lines(hero, mounted: true, opponentOnFoot: true).map(\.source)
        XCTAssertTrue(sources.contains(L("source.vorteilhaft")))
        XCTAssertFalse(sources.contains(L("source.golgariten")),
                       "a hero without the style must never see a Golgariten line")
    }

    func testTheGolgaritenLineNeedsTheOpponentOnFootToo() {
        let hero = makeHero(golgaritenLoadout: true)
        XCTAssertFalse(lines(hero, mounted: true, opponentOnFoot: false)
            .map(\.source).contains(L("source.golgariten")),
                       "clause 1 raises an ease that does not exist here")
    }

    // MARK: - The manual toggle must not double-count

    /// `CombatAttackViews` inserts a manual +2 only when the engine supplies none, and asks
    /// `emitsVorteilhaftePosition` which case it is in. That predicate is what this asserts;
    /// the definition above is written in terms of it, so the two cannot disagree.
    func testEngineOwnsThePositionExactlyWhenMountedAgainstFoot() {
        XCTAssertTrue(MeleeModifiers.emitsVorteilhaftePosition(mounted: true, opponentOnFoot: true),
                      "engine supplies it — the manual toggle must stay out of the way")
        XCTAssertFalse(MeleeModifiers.emitsVorteilhaftePosition(mounted: true, opponentOnFoot: false),
                       "opponent is mounted too: the manual toggle is the only way to the +2")
        XCTAssertFalse(MeleeModifiers.emitsVorteilhaftePosition(mounted: false, opponentOnFoot: true))
        XCTAssertFalse(MeleeModifiers.emitsVorteilhaftePosition(mounted: false, opponentOnFoot: false))
    }

    func testOnlyOneChapterLineIsEmitted() {
        // The guard against the regression a manual insert would cause: whatever else is on
        // the sheet, the engine contributes the advantageous position exactly once.
        let hero = makeHero(golgaritenLoadout: true)
        let count = lines(hero, mounted: true, opponentOnFoot: true)
            .filter { $0.source == L("source.vorteilhaft") }.count
        XCTAssertEqual(count, 1)
    }

    // MARK: - Neighbours that must not move

    func testGolgaritenParryBonusIsMountedOnlyAndIgnoresOpponentStance() {
        // SA_661 clause 2 is a flat defensive bonus gated on `mounted` alone — the opponent's
        // stance belongs to clause 1 only, and must not leak into the parry side.
        let hero = makeHero(golgaritenLoadout: true)
        for onFoot in [true, false] {
            var ctx = ModifierContext(hero: hero, domain: .meleeParry)
            ctx.mounted = true
            ctx.opponentOnFoot = onFoot
            let pa = ModifierEngine.shared.evaluate(context: ctx)
                .filter { $0.source == L("source.golgariten") }
                .reduce(0) { $0 + $1.value }
            XCTAssertEqual(pa, 1, "PA +1 stands whether or not the opponent is on foot")
        }
    }
}
