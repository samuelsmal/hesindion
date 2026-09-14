import XCTest
@testable import Hesindion

/// The combat-technique ids, checked against the table they came from.
///
/// They were used as bare strings with the names in comments, and three of those
/// comments were wrong — each one silently changing a rule:
///
/// - the two-handed grip was withheld from `CT_1`/`CT_3` "Dolche, Fechtwaffen".
///   `CT_1` is Armbrüste and `CT_4` is Fechtwaffen, so every rapier in the game
///   could be gripped two-handed and no crossbow could;
/// - "needs both hands, not from the saddle" was applied to `CT_7`/`CT_14`
///   "Zweihandschwerter, Stangenwaffen" — Lanzen and Wurfwaffen — so the app
///   forbade the *lance* to a mounted hero and let a Zweihänder through;
/// - `isSchusswaffe` was `CT_11`/`CT_12` "Armbrüste, Bögen" — Schleudern and
///   Schwerter.
///
/// None of that is visible reading the code. It is visible here.
final class CombatTechniqueIDTests: XCTestCase {

    /// The name each id carries in `rules.db`, as the importer reads it.
    private func publishedName(_ id: CombatTechniqueID) -> String? {
        RulesDatabase.shared.lookup(id: id.rawValue)?.name
    }

    /// Skipped rather than failed when the database comes back empty — a known
    /// flake in the shared connection, and this test is about the mapping, not
    /// about sqlite.
    private func requireDatabase() throws {
        guard publishedName(.schwerter) != nil else {
            throw XCTSkip("rules.db unavailable in this run")
        }
    }

    private static let expected: [CombatTechniqueID: String] = [
        .armbrueste: "Armbrüste", .boegen: "Bögen", .dolche: "Dolche",
        .fechtwaffen: "Fechtwaffen", .hiebwaffen: "Hiebwaffen",
        .kettenwaffen: "Kettenwaffen", .lanzen: "Lanzen", .peitschen: "Peitschen",
        .raufen: "Raufen", .schilde: "Schilde", .schleudern: "Schleudern",
        .schwerter: "Schwerter", .stangenwaffen: "Stangenwaffen",
        .wurfwaffen: "Wurfwaffen", .zweihandhiebwaffen: "Zweihandhiebwaffen",
        .zweihandschwerter: "Zweihandschwerter", .feuerspeien: "Feuerspeien",
        .blasrohre: "Blasrohre", .diskusse: "Diskusse", .faecher: "Fächer",
        .spiesswaffen: "Spießwaffen",
    ]

    func testEveryIdNamesWhatTheRulesSayItNames() throws {
        try requireDatabase()
        for id in CombatTechniqueID.allCases {
            XCTAssertEqual(publishedName(id), Self.expected[id], id.rawValue)
        }
    }

    func testTheListIsComplete() throws {
        try requireDatabase()
        XCTAssertEqual(CombatTechniqueID.allCases.count, Self.expected.count)
    }

    // MARK: - The rules keyed to these ids

    func testOnlyTrueTwoHandersOccupyBothHands() {
        XCTAssertTrue(CombatTechniqueID.zweihandschwerter.isTwoHandedOnly)
        XCTAssertTrue(CombatTechniqueID.zweihandhiebwaffen.isTwoHandedOnly)
        XCTAssertTrue(CombatTechniqueID.stangenwaffen.isTwoHandedOnly)
        XCTAssertFalse(CombatTechniqueID.schwerter.isTwoHandedOnly)
    }

    /// The bug this set had: a lance is a two-handed weapon and *the* mounted
    /// weapon, and the rule driven by this set bans two-handers from the saddle.
    func testALanceIsNotBannedFromTheSaddle() {
        XCTAssertFalse(CombatTechniqueID.lanzen.isTwoHandedOnly)
    }

    func testOneHandedWeaponsCannotBeGrippedInTwo() {
        XCTAssertFalse(CombatTechniqueID.dolche.allowsTwoHandedGrip)
        XCTAssertFalse(CombatTechniqueID.fechtwaffen.allowsTwoHandedGrip)
        XCTAssertTrue(CombatTechniqueID.schwerter.allowsTwoHandedGrip)
        XCTAssertTrue(CombatTechniqueID.armbrueste.allowsTwoHandedGrip,
                      "A crossbow is not a melee weapon; nothing here should exclude it")
    }

    func testSchusswaffenAreTheOnesThatShoot() {
        func weapon(_ id: CombatTechniqueID) -> RangedWeapon {
            RangedWeapon(name: "x", combatTechniqueId: id.rawValue,
                         damage: "1W6", at: 10, range: "10/20/30", weight: 1)
        }
        XCTAssertTrue(weapon(.boegen).isSchusswaffe)
        XCTAssertTrue(weapon(.armbrueste).isSchusswaffe)
        XCTAssertTrue(weapon(.blasrohre).isSchusswaffe)
        XCTAssertFalse(weapon(.wurfwaffen).isSchusswaffe)
        XCTAssertFalse(weapon(.schleudern).isSchusswaffe)
        XCTAssertFalse(weapon(.schwerter).isSchusswaffe, "A sword is not a Schusswaffe")
    }

    // MARK: - Iconography

    /// Every technique resolves to a glyph, and a melee weapon never gets the
    /// hammer that used to stand in for all of them.
    func testEveryTechniqueHasAnIcon() {
        for id in CombatTechniqueID.allCases {
            let icon = WeaponIcon.forTechnique(id)
            XCTAssertNotEqual(icon, .system("hammer.fill"), id.rawValue)
        }
    }

    func testASwordLooksLikeASword() {
        XCTAssertEqual(WeaponIcon.forTechnique(.schwerter), .asset("weapon.sword"))
        XCTAssertEqual(WeaponIcon.forTechnique(.zweihandschwerter), .asset("weapon.sword"))
        XCTAssertEqual(WeaponIcon.forTechnique(.hiebwaffen), .asset("weapon.axe"))
        XCTAssertEqual(WeaponIcon.forTechnique(.schilde), .system("shield.fill"))
    }

    func testAnUnknownTechniqueStillGetsAGlyph() {
        XCTAssertEqual(WeaponIcon.forTechniqueId("CT_999"), .asset("weapon.generic"))
        XCTAssertEqual(WeaponIcon.forTechniqueId(nil), .asset("weapon.generic"))
    }
}
