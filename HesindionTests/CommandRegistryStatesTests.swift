import XCTest
import SwiftData
@testable import Hesindion

final class CommandRegistryStatesTests: XCTestCase {
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

    func testZustandCommandPresentAndSetsLevel() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)

        let command = hero.commandRegistry.first {
            $0.name == "Zustand" && $0.subparameter == L("state.furcht.name")
        }
        let cmd = try XCTUnwrap(command, "Expected a Zustand command for Furcht")

        guard case .integerAmount(_, _, let max, _)? = cmd.input else {
            return XCTFail("Expected integerAmount input")
        }
        XCTAssertEqual(max, 4)

        cmd.execute(.integerAmount(2))
        XCTAssertEqual(hero.level(of: "furcht"), 2)

        cmd.execute(.integerAmount(0))
        XCTAssertFalse(hero.hasState("furcht"))
    }

    func testStatusCommandTogglesAndRemoves() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)

        let command = hero.commandRegistry.first {
            $0.name == "Status" && $0.subparameter == L("state.liegend.name")
        }
        let cmd = try XCTUnwrap(command, "Expected a Status command for Liegend")

        guard case .integerAmount(_, _, let max, _)? = cmd.input else {
            return XCTFail("Expected integerAmount input")
        }
        XCTAssertEqual(max, 1)

        cmd.execute(.integerAmount(1))
        XCTAssertTrue(hero.hasState("liegend"))

        cmd.execute(.integerAmount(0))
        XCTAssertFalse(hero.hasState("liegend"))
    }

    func testDerivedStatesHaveNoCommand() throws {
        let ctx = try makeContext()
        let hero = Hero(name: "Test"); ctx.insert(hero)

        let derivedKeys = [L("source.schmerz"), L("source.belastung")]
        let offending = hero.commandRegistry.filter {
            (($0.name == "Zustand") || ($0.name == "Status")) &&
            $0.subparameter.map { derivedKeys.contains($0) } == true
        }
        XCTAssertTrue(offending.isEmpty, "Derived states must not have a command")
    }
}
