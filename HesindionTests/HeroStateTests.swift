import XCTest
import SwiftData
@testable import Hesindion

final class HeroStateTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Hero.self, HeroStateEntry.self, PersonalData.self, Experience.self,
            Attributes.self, DerivedValues.self, Talent.self, CombatTechnique.self,
            MeleeWeapon.self, RangedWeapon.self, Armor.self, Shield.self,
            EquipmentItem.self, Money.self, Pet.self, Language.self,
            HeroSpell.self, LogEntry.self, Adventure.self, WeatherDay.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    func testAddAndReadState() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test")
        ctx.insert(hero)
        hero.setStateLevel("furcht", level: 2)
        XCTAssertEqual(hero.level(of: "furcht"), 2)
        XCTAssertTrue(hero.hasState("furcht"))
    }

    func testSettingLevelZeroRemovesEntry() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("furcht", level: 2)
        hero.setStateLevel("furcht", level: 0)
        XCTAssertFalse(hero.hasState("furcht"))
        XCTAssertEqual(hero.states.count, 0)
    }

    func testZustandLevelClampedToFour() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("furcht", level: 9)
        XCTAssertEqual(hero.level(of: "furcht"), 4)
    }

    func testStatusAlwaysLevelOne() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("liegend", level: 3)   // status: any positive ⇒ 1
        XCTAssertEqual(hero.level(of: "liegend"), 1)
    }

    func testTotalZustandLevelsIncludesSchmerzAndBelastung() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("furcht", level: 2)
        // schmerz/belastung derived = 0 for a bare hero
        XCTAssertEqual(hero.totalZustandLevels, 2)
    }

    func testHandlungsunfaehigAtEightLevels() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("furcht", level: 4)
        hero.setStateLevel("verwirrung", level: 4)
        XCTAssertTrue(hero.isHandlungsunfaehig)
    }

    func testLevelFourZustandImpliesHandlungsunfaehig() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("betaeubung", level: 4)
        XCTAssertTrue(hero.isHandlungsunfaehig)
    }

    func testParalyseFourImpliesBewegungsunfaehig() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("paralyse", level: 4)
        XCTAssertTrue(hero.isBewegungsunfaehig)
    }

    func testImpliedStatusesFromBewusstlos() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)
        hero.setStateLevel("bewusstlos", level: 1)
        let implied = hero.impliedStateIDs
        XCTAssertTrue(implied.contains("handlungsunfaehig"))
        XCTAssertTrue(implied.contains("liegend"))
    }
}
