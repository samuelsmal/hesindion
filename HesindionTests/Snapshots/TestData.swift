import Foundation
import SwiftData
@testable import Hesindion

@MainActor
enum TestData {

    static let schema = Schema([
        Hero.self, HeroStateEntry.self, PersonalData.self, Experience.self, Attributes.self,
        DerivedValues.self, Talent.self, CombatTechnique.self,
        MeleeWeapon.self, RangedWeapon.self, Armor.self, Shield.self,
        EquipmentItem.self, Money.self, Pet.self, Language.self,
        HeroSpell.self, LogEntry.self, Adventure.self, WeatherDay.self,
    ])

    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    static var boronmirURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // TestData.swift → Snapshots/
            .deletingLastPathComponent()    // Snapshots/ → HesindionTests/
            .deletingLastPathComponent()    // HesindionTests/ → project root
            .appendingPathComponent("specs/heroes/Boronmir Siebenfeld von Greifenfurt.json")
    }

    static func importBoronmir(into container: ModelContainer) throws -> Hero {
        let context = ModelContext(container)
        try OptolithImportService().importHero(from: boronmirURL, context: context)
        let heroes = try context.fetch(FetchDescriptor<Hero>())
        return heroes.first!
    }

    static func makeSampleAdventure(in context: ModelContext) -> Adventure {
        let startDate = AventurianDate(day: 1, month: .praios, year: 1040)
        let adventure = Adventure(name: "Die Schwarze Katze", region: .mittelreich, startDate: startDate)

        let samples: [(Int, WeatherRegion, CloudCover, WindStrength, Int, Int, RainLevel)] = [
            (1, .mittelreich, .none, .none, 22, 13, .none),
            (2, .mittelreich, .lots, .fresh, 16, 10, .little),
            (3, .khom,        .none, .strong, 41, 21, .none),   // travel into the desert
        ]
        for (offset, region, clouds, wind, dayT, nightT, rain) in samples {
            let date = AventurianDate(day: offset, month: .praios, year: 1040)
            let result = WeatherResult(date: date, clouds: clouds, wind: wind,
                                       dayTemperature: dayT, nightTemperature: nightT, rain: rain)
            let weatherDay = WeatherDay(from: result, region: region, isTimeJump: region == .khom)
            adventure.weatherDays.append(weatherDay)
        }
        context.insert(adventure)
        return adventure
    }

    static func makeDiceRollLogEntry(for hero: Hero) -> LogEntry {
        let payload = DiceRollPayload(count: 3, sides: 6, results: [4, 2, 6], total: 12)
        return LogEntry.create(kind: "diceRoll", payload: payload, hero: hero)
    }

    /// A minimal `DerivedValues` with only Lebensenergie populated — current == max == `lp`,
    /// no bonus/purchased. Everything else is zeroed, the way `HeroStateTests` builds one.
    static func derivedValues(lp: Int) -> DerivedValues {
        DerivedValues(
            lebensenergie: LifeEnergyValue(base: lp, bonus: 0, purchased: 0, max: lp, current: lp),
            astralenergie: nil, karmaenergie: nil,
            seelenkraft: ResourceValue(base: 0, bonus: 0, max: 0),
            zaehigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            ausweichen: ComputedValue(value: 0, bonus: 0, max: 0),
            initiative: ComputedValue(value: 0, bonus: 0, max: 0),
            geschwindigkeit: ResourceValue(base: 0, bonus: 0, max: 0),
            wundschwelle: ComputedValue(value: 0, bonus: 0, max: 0),
            schicksalspunkte: MutableResourceValue(current: 0, bonus: 0, max: 0))
    }
}
