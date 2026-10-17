import XCTest
@testable import Hesindion

/// The Fokusregel *Karmale Objekte*, and the two answers it needs before it can
/// say anything.
///
/// > "Angriffe mit geweihten Waffen bewirken bei Dämonen regulären Schaden.
/// > Angriffe mit geweihten Waffen der Gegengottheit erzeugen doppelte
/// > Trefferpunkte."
///
/// https://dsa.ulisses-regelwiki.de/Fokus_Karmale_Objekte.html
final class KarmalWeaponTests: XCTestCase {

    /// The unremarkable case the rule spends most of its time in: a consecrated
    /// weapon reaches a demon, and does exactly what it does to anything else.
    func testAConsecratedWeaponDealsRegularDamageToADemon() {
        XCTAssertTrue(KarmalWeapon.statesSomething(consecrated: true, target: .daemon),
                      "Worth saying on screen even though it changes no number")
    }

    /// The doubling is the *weapon's*, not the wielder's conviction: an
    /// unconsecrated blade against the right demon still does nothing special.
    func testAnUnconsecratedWeaponNeverDoubles() {
        XCTAssertFalse(KarmalWeapon.statesSomething(consecrated: false, target: .daemon))
    }

    // MARK: - Which weapons are consecrated

    private func hero() -> Hero {
        let hero = Hero(name: "Boronmir")
        hero.meleeWeapons = [
            MeleeWeapon(name: "Rabenschnabel", combatTechniqueId: "CT_5",
                        damage: "1W6+4", at: 14, pa: 7, reach: "Mittel", weight: 1.5),
            MeleeWeapon(name: "Langschwert", combatTechniqueId: "CT_12",
                        damage: "1W6+4", at: 14, pa: 7, reach: "Mittel", weight: 2.0),
        ]
        return hero
    }

    /// Optolith's own inventory marks the Rabenschnabel "geweiht (Boron)", and
    /// that is the default (owner decision 2026-09-18). Nothing else is.
    func testTheInventorysGeweihtIsTheDefault() {
        let hero = self.hero()
        XCTAssertTrue(hero.isConsecrated("Rabenschnabel"))
        XCTAssertFalse(hero.isConsecrated("Langschwert"))
        XCTAssertFalse(hero.isConsecrated(nil))
    }

    /// Optolith's second Rabenschnabel template (ITEMTPL_796) drops the note,
    /// but the Regelwiki — the authority — has one Rabenschnabel, Boron's.
    func testTheDuplicateTemplateIsConsecratedToo() {
        let hero = self.hero()
        hero.meleeWeapons.first { $0.name == "Rabenschnabel" }?.templateId = "ITEMTPL_796"
        XCTAssertTrue(hero.isConsecrated("Rabenschnabel"))
    }

    func testTheSettingIsPerWeapon() {
        let hero = self.hero()
        hero.setConsecrated("Langschwert", true)
        XCTAssertTrue(hero.isConsecrated("Langschwert"))
        hero.setConsecrated("Rabenschnabel", false)
        XCTAssertFalse(hero.isConsecrated("Rabenschnabel"))
        XCTAssertTrue(hero.isConsecrated("Langschwert"))
    }

    func testSettingItTwiceDoesNotDuplicate() {
        let hero = self.hero()
        hero.setConsecrated("Langschwert", true)
        hero.setConsecrated("Langschwert", true)
        XCTAssertEqual(hero.consecratedWeapons, ["Langschwert"])
        hero.setConsecrated("Rabenschnabel", false)
        hero.setConsecrated("Rabenschnabel", false)
        XCTAssertEqual(hero.unconsecratedWeapons, ["Rabenschnabel"])
    }

    func testItCanBeTakenBack() {
        let hero = self.hero()
        hero.setConsecrated("Langschwert", true)
        hero.setConsecrated("Langschwert", false)
        XCTAssertFalse(hero.isConsecrated("Langschwert"))
        XCTAssertTrue(hero.consecratedWeapons.isEmpty)
        XCTAssertTrue(hero.unconsecratedWeapons.isEmpty)
    }

    /// The rule is a Fokusregel: off unless the table plays with it.
    func testTheRuleIsOffByDefault() {
        XCTAssertFalse(hero().isFokusRuleActive(.karmaleObjekte))
    }
}
