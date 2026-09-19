import XCTest
import SwiftData
@testable import Hesindion

/// The weapon inventory Optolith ships (`equipment` in rules.db): what the rules
/// say about each weapon, and the one thing the app reads off it — a weapon
/// marked "geweiht (…)" counts as consecrated unless the player switched it off
/// (owner decision 2026-09-18).
///
/// Names are not unique in the inventory: the Rabenschnabel is ITEMTPL_19 (note
/// "geweiht (Boron)") *and* ITEMTPL_796 (same stats, no note). The hero's weapon
/// carries the template id Optolith exported, and the texts come from that
/// template; heroes imported before it was stored fall back to the name, which
/// picks the lowest template number. Consecration is read by name across all
/// templates: the Regelwiki is the authority and has one Rabenschnabel, Boron's
/// (owner ruling 2026-09-18).
@MainActor
final class WeaponInventoryTests: XCTestCase {

    override func setUpWithError() throws {
        guard RulesDatabase.shared.equipment(id: "ITEMTPL_35") != nil else { throw XCTSkip("rules.db has no equipment table") }
    }

    // MARK: - The inventory itself

    func testTheRabenschnabelIsBoronsWeapon() throws {
        let entry = try XCTUnwrap(RulesDatabase.shared.equipment(named: "Rabenschnabel"))
        XCTAssertEqual(entry.id, "ITEMTPL_19", "of two Rabenschnäbel, the name lookup takes the lower template number")
        XCTAssertEqual(entry.consecratedTo, "Boron")
        XCTAssertEqual(entry.combatTechniqueId, "CT_5")
        XCTAssertEqual(entry.damage, "1W6+4")
    }

    /// Optolith's duplicate drops the note; the weapon is still Boron's.
    func testTheDuplicateTemplateDropsTheNoteButTheNameIsStillBorons() throws {
        let entry = try XCTUnwrap(RulesDatabase.shared.equipment(id: "ITEMTPL_796"))
        XCTAssertEqual(entry.name, "Rabenschnabel")
        XCTAssertNil(entry.consecratedTo, "the row itself has no note")
        XCTAssertEqual(RulesDatabase.shared.consecratedDeity(forWeaponNamed: "Rabenschnabel"), "Boron")
        XCTAssertNil(RulesDatabase.shared.consecratedDeity(forWeaponNamed: "Langschwert"))
        XCTAssertNil(RulesDatabase.shared.consecratedDeity(forWeaponNamed: "Magierstab, lang"))
        XCTAssertNil(RulesDatabase.shared.consecratedDeity(forWeaponNamed: "Testwaffe"))
    }

    func testTheLangschwertHasNeitherAdvantageNorDisadvantage() throws {
        let entry = try XCTUnwrap(RulesDatabase.shared.equipment(named: "Langschwert"))
        XCTAssertNil(entry.advantage)
        XCTAssertNil(entry.disadvantage)
        XCTAssertNil(entry.consecratedTo)
    }

    func testTheGrossschildHasBoth() throws {
        let entry = try XCTUnwrap(RulesDatabase.shared.equipment(named: "Großschild"))
        XCTAssertNotNil(entry.advantage)
        XCTAssertNotNil(entry.disadvantage)
        XCTAssertEqual(entry.at, -6)
        XCTAssertEqual(entry.pa, 3)
    }

    func testAnUnknownNameHasNoEntry() {
        XCTAssertNil(RulesDatabase.shared.equipment(named: "Leuwagener Dolch"))
        XCTAssertNil(RulesDatabase.shared.equipment(id: "ITEMTPL_0"))
    }

    func testConsecratedToReadsTheNotesPrefix() {
        func entry(_ note: String?) -> EquipmentEntry {
            EquipmentEntry(id: "X", name: "X", combatTechniqueId: nil, damage: nil, at: nil, pa: nil,
                           reach: nil, note: note, advantage: nil, disadvantage: nil)
        }
        XCTAssertEqual(entry("geweiht (Boron); borongeweihte Waffen sind nur für Borongeweihte erwerbbar").consecratedTo, "Boron")
        XCTAssertEqual(entry("geweiht (Rondra)").consecratedTo, "Rondra")
        XCTAssertNil(entry("Um den Stab bei der Heldenerschaffung zu erwerben …").consecratedTo)
        XCTAssertNil(entry("ungeweiht (Boron)").consecratedTo)
        XCTAssertNil(entry(nil).consecratedTo)
    }

    // MARK: - Which entry a hero's weapon is

    private func hero(rabenschnabel templateId: String?) -> Hero {
        let hero = Hero(name: "Boronmir")
        let weapon = MeleeWeapon(name: "Rabenschnabel", combatTechniqueId: "CT_5",
                                 damage: "1W6+4", at: 14, pa: 7, reach: "Mittel", weight: 1.5)
        weapon.templateId = templateId
        hero.meleeWeapons = [
            weapon,
            MeleeWeapon(name: "Langschwert", combatTechniqueId: "CT_12",
                        damage: "1W6+4", at: 14, pa: 7, reach: "Mittel", weight: 2.0),
        ]
        return hero
    }

    func testTheTemplateIdDecidesWhichRabenschnabel() {
        XCTAssertEqual(hero(rabenschnabel: "ITEMTPL_796").equipmentEntry(forLoadoutNamed: "Rabenschnabel")?.id, "ITEMTPL_796")
        XCTAssertEqual(hero(rabenschnabel: "ITEMTPL_19").equipmentEntry(forLoadoutNamed: "Rabenschnabel")?.id, "ITEMTPL_19")
        XCTAssertEqual(hero(rabenschnabel: nil).equipmentEntry(forLoadoutNamed: "Rabenschnabel")?.id, "ITEMTPL_19",
                       "an old import without a template id falls back to the name")
    }

    func testARenamedWeaponIsFoundByItsTemplate() {
        let hero = Hero(name: "Robak")
        let dagger = MeleeWeapon(name: "Leuwagener Dolch", combatTechniqueId: "CT_3",
                                 damage: "1W6+1", at: 10, pa: 5, reach: "Kurz", weight: 0.5)
        dagger.templateId = "ITEMTPL_2"
        hero.meleeWeapons = [dagger]
        XCTAssertEqual(hero.equipmentEntry(forLoadoutNamed: "Leuwagener Dolch")?.id, "ITEMTPL_2")
    }

    func testAShieldIsFoundToo() {
        let hero = Hero(name: "Boronmir")
        let shield = Shield(name: "Großschild", damage: "1W6+1", at: 6, pa: 11, reach: "Kurz", structurePoints: 30, weight: 6)
        shield.templateId = "ITEMTPL_29"
        hero.shields = [shield]
        XCTAssertEqual(hero.equipmentEntry(forLoadoutNamed: "Großschild")?.id, "ITEMTPL_29")
    }

    // MARK: - Consecration: the inventory is the default, the lists override it

    func testOptolithsGeweihtIsTheDefault() {
        XCTAssertTrue(hero(rabenschnabel: "ITEMTPL_19").isConsecrated("Rabenschnabel"))
        XCTAssertTrue(hero(rabenschnabel: "ITEMTPL_796").isConsecrated("Rabenschnabel"),
                      "Optolith's duplicate without the note is still the Regelwiki's one Rabenschnabel")
        XCTAssertTrue(hero(rabenschnabel: nil).isConsecrated("Rabenschnabel"), "old import without a template id")
        XCTAssertEqual(hero(rabenschnabel: "ITEMTPL_796").consecratedDeity(ofLoadoutNamed: "Rabenschnabel"), "Boron",
                       "what the info sheet shows for either template")
        XCTAssertFalse(hero(rabenschnabel: nil).isConsecrated("Langschwert"))
    }

    func testThePlayerCanSwitchTheDefaultOffAndOnAgain() {
        let hero = hero(rabenschnabel: "ITEMTPL_796")
        hero.setConsecrated("Rabenschnabel", false)
        XCTAssertFalse(hero.isConsecrated("Rabenschnabel"))
        XCTAssertEqual(hero.unconsecratedWeapons, ["Rabenschnabel"])
        XCTAssertTrue(hero.consecratedWeapons.isEmpty)

        hero.setConsecrated("Rabenschnabel", true)
        XCTAssertTrue(hero.isConsecrated("Rabenschnabel"))
        XCTAssertTrue(hero.unconsecratedWeapons.isEmpty, "back to the default, no override left")
        XCTAssertTrue(hero.consecratedWeapons.isEmpty)
    }

    func testAnOrdinaryWeaponCanStillBeConsecratedByHand() {
        let hero = hero(rabenschnabel: nil)
        hero.setConsecrated("Langschwert", true)
        XCTAssertTrue(hero.isConsecrated("Langschwert"))
        XCTAssertEqual(hero.consecratedWeapons, ["Langschwert"])
        hero.setConsecrated("Langschwert", false)
        XCTAssertFalse(hero.isConsecrated("Langschwert"))
        XCTAssertTrue(hero.consecratedWeapons.isEmpty)
        XCTAssertTrue(hero.unconsecratedWeapons.isEmpty)
    }

    func testAWeaponOutsideTheInventoryBehavesAsBefore() {
        let hero = hero(rabenschnabel: nil)
        XCTAssertFalse(hero.isConsecrated("Testwaffe"))
        hero.setConsecrated("Testwaffe", true)
        XCTAssertTrue(hero.isConsecrated("Testwaffe"))
        XCTAssertEqual(hero.consecratedWeapons, ["Testwaffe"])
        hero.setConsecrated("Testwaffe", false)
        XCTAssertFalse(hero.isConsecrated("Testwaffe"))
        XCTAssertTrue(hero.unconsecratedWeapons.isEmpty)
        XCTAssertFalse(hero.isConsecrated(nil))
    }

    // MARK: - The import

    func testTheImportKeepsOptolithsTemplateIds() throws {
        let container = try TestData.makeContainer()
        let hero = try TestData.importBoronmir(into: container)
        XCTAssertEqual(hero.meleeWeapons.first { $0.name == "Rabenschnabel" }?.templateId, "ITEMTPL_19")
        XCTAssertEqual(hero.meleeWeapons.first { $0.name == "Langschwert" }?.templateId, "ITEMTPL_35")
        XCTAssertEqual(hero.shields.first { $0.name == "Großschild" }?.templateId, "ITEMTPL_29")
        XCTAssertTrue(hero.isConsecrated("Rabenschnabel"), "Boronmir's Rabenschnabel is geweiht (Boron)")
        XCTAssertFalse(hero.isConsecrated("Langschwert"))
    }
}
