import XCTest
@testable import Hesindion

final class StringsCoverageTests: XCTestCase {

    private func assertLocalized(_ key: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotEqual(L(key), key, "missing translation for \(key)", file: file, line: line)
    }

    func testHitZoneNamesAreLocalized() {
        for zone in HitZone.allCases { assertLocalized(zone.nameKey) }
        assertLocalized(BodySide.links.nameKey)
        assertLocalized(BodySide.rechts.nameKey)
    }

    func testWoundEffectTextsAreLocalized() {
        for zone in HitZone.allCases {
            let effect = WoundEffectCatalog.effect(for: zone)
            assertLocalized(effect.effectKey)
            assertLocalized(effect.resistanceKey)
        }
    }

    func testScreenKeysAreLocalized() {
        for key in [
            "fokus.section", "fokus.trefferzonen.name", "fokus.trefferzonen.subtitle",
            "trefferzone.section", "trefferzone.none", "trefferzone.roll",
            "trefferzone.targetSurprised",
            "trefferzone.sfHalves.melee", "trefferzone.sfHalves.ranged",
            "trefferzone.woundEffect", "trefferzone.threshold",
            "trefferzone.probe", "trefferzone.dropWeapon",
            "trefferzone.reminderTitle",
        ] { assertLocalized(key) }
    }

    /// The critical-table screen's own chrome. The table titles and the
    /// "replaces …" notes are covered by `CriticalSuccessTableTests`, which can
    /// derive them from the enum; these are hand-written call sites and so have
    /// nowhere else to be checked.
    func testCriticalTableScreenKeysAreLocalized() {
        for key in [
            "critical.title", "critical.category", "critical.detail",
            "critical.rollCategory", "critical.rollDetail", "critical.rerollPrompt",
            "critical.damageEffect", "critical.chooseTable",
            "critical.chooseMelee", "critical.chooseRanged",
            "critical.chooseResolution", "critical.basicRule",
            "critical.fokusRule", "critical.rollTable",
        ] { assertLocalized(key) }
    }

    /// The Patzertabelle's help screen. Hand-written call sites, like the
    /// critical table's above, so there is nowhere else to check them.
    func testFumbleEffectKeysAreLocalized() {
        for key in [
            "fumble.title", "fumble.takeDamage", "fumble.rollTable",
            "fumble.effect.label", "fumble.rollProbe", "fumble.cost.oneAction",
            "fumble.itemDropped", "fumble.itemRecovered",
            "fumble.fall.avoided", "fumble.stuck.failed",
            "fumble.selfDamage.label", "fumble.selfDamage.doubled",
            "fumble.damageSource", "fumble.gmOnly", "flucht.gsLiegend",
            // The temporary effects: the two modifier labels, what the panel
            // reports having written, the two reasons a button is dark, the
            // loadout badge and the repair row.
            "fumble.modifier.stumble", "fumble.modifier.damaged",
            "fumble.stumble.write", "fumble.until.round", "fumble.untilNextAction",
            "fumble.jam.write", "fumble.jam.reason",
            "fumble.noDefense.write", "fumble.noDefense.reason",
            "fumble.damaged.badge", "fumble.friendHit.selfDamage",
            "damagedItems.title", "damagedItems.subtitle", "damagedItems.repair",
            "schmerz.fromFumble",
        ] { assertLocalized(key) }
    }

    /// M7: the melee and ranged zone pickers share one component but not one hint —
    /// SA_160 *Gezielter Angriff* halves in melee, SA_161 *Gezielter Schuss* at range.
    /// A single shared string was necessarily wrong on one of the two screens.
    func testSfHalvesHintsDifferPerDomain() {
        XCTAssertNotEqual(L("trefferzone.sfHalves.melee"), L("trefferzone.sfHalves.ranged"))
    }
}
