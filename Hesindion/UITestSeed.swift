import Foundation
import SwiftData

/// Debug-only deterministic store seed for the `HesindionUITests` XCUITest target.
///
/// The app normally launches into the empty "Keine Helden" state, so every screen
/// worth a screenshot sits behind an import *and* a pile of taps. This seeds a known
/// hero into a **separate** store file so a UI test starts from the same state every
/// run and never touches the store a real user's app writes to.
///
/// Two independent guards keep it out of normal use:
/// 1. the whole type is compiled out of Release builds (`#if DEBUG`), and
/// 2. even in Debug it only fires when the app is launched with `-uitest-seed-hero`.
#if DEBUG
enum UITestSeed {

    /// Launch argument that enables the seed. XCUITests pass it in `launchArguments`.
    static let launchArgument = "-uitest-seed-hero"

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// `-uitest-fokus kritischeErfolgeAngriff,kritischeErfolgeDetail` switches
    /// further Fokus-Regeln on beyond Trefferzonen.
    ///
    /// The alternative was to drive the hero settings screen in every test that
    /// needs a rule — twenty taps of scrolling before the flow under test starts,
    /// repeated per test. Unknown names are ignored rather than trapping: a typo
    /// in a test argument should fail that test's own assertions, not the launch.
    static let fokusArgument = "-uitest-fokus"

    /// `-uitest-fokus-off trefferzonen` switches a rule back off, applied after the
    /// on-switches above.
    ///
    /// The seed turns Trefferzonen on for everybody, because most of the combat
    /// surfaces only exist with it. A screen that has to behave *without* the rule —
    /// the Wundschwelle on taking damage (issue #23) — needs the other direction.
    static let fokusOffArgument = "-uitest-fokus-off"

    private static var requestedFokusRules: [FokusRule] {
        rules(for: fokusArgument)
    }

    private static var disabledFokusRules: [FokusRule] {
        rules(for: fokusOffArgument)
    }

    private static func rules(for argument: String) -> [FokusRule] {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: argument), index + 1 < args.count else { return [] }
        return args[index + 1]
            .split(separator: ",")
            .compactMap { FokusRule(rawValue: String($0)) }
    }

    /// The weapon the seeded hero goes into combat with. Named here because the
    /// UI tests navigate the attack flow that depends on it (a single one-handed
    /// melee weapon, no shield, no off-hand).
    static let weaponName = "Langschwert"

    /// `-uitest-shield` equips the hero's shield as well.
    ///
    /// It exists for the defence tests: with a shield in the loadout, Parieren
    /// goes through the weapon list rather than straight to the roll, and that is
    /// the path whose modifiers were being dropped.
    static let shieldArgument = "-uitest-shield"

    static let shieldName = "Großschild"

    private static var wantsShield: Bool {
        ProcessInfo.processInfo.arguments.contains(shieldArgument)
    }

    /// The seeded adventure. Named here because the screenshot tests navigate to
    /// it by name to reach the weather table.
    static let adventureName = "Die Sieben Gezeichneten"

    /// A store of its own, wiped on every launch — the real store is never touched
    /// and a repeated run always starts from the same state.
    private static var storeURL: URL {
        URL.applicationSupportDirectory.appending(path: "HesindionUITest.store")
    }

    /// Builds a freshly seeded container. Traps rather than falling back to the real
    /// store: a silently unseeded run would produce misleading screenshots.
    static func makeContainer() -> ModelContainer {
        do {
            try resetStore()
            let container = try ModelContainer(
                for: Hero.self, HeroStateEntry.self, Adventure.self, WeatherDay.self,
                configurations: ModelConfiguration(url: storeURL)
            )
            try populate(container)
            return container
        } catch {
            fatalError("UITestSeed: could not build seeded container: \(error)")
        }
    }

    // MARK: - Private

    private static func resetStore() throws {
        let fm = FileManager.default
        let directory = storeURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: directory.path) {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        // SQLite keeps a -shm/-wal pair alongside the store; all three must go.
        for suffix in ["", "-shm", "-wal"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
            }
        }
    }

    /// Imports `Hesindion/Resources/UITestHero.json` — the `docs/sample_heros`
    /// Boronmir export the snapshot tests use, with the base64 avatar images stripped
    /// (3.1 MB → 8 KB, because the resource ships in Release builds too and nothing
    /// here looks at the portrait). To refresh it after the sample hero changes:
    /// re-copy the export and delete its top-level `avatar` key and each pet's.
    private static func populate(_ container: ModelContainer) throws {
        guard let url = Bundle.main.url(forResource: "UITestHero", withExtension: "json") else {
            fatalError("UITestSeed: UITestHero.json is missing from the app bundle")
        }

        let context = ModelContext(container)
        try OptolithImportService().importHero(from: url, context: context)

        guard let hero = try context.fetch(FetchDescriptor<Hero>()).first else {
            fatalError("UITestSeed: import produced no hero")
        }

        // The Trefferzonen surfaces only exist when the Fokus-Regel is on.
        hero.setFokusRule(.trefferzonen, active: true)
        for rule in requestedFokusRules {
            hero.setFokusRule(rule, active: true)
        }
        for rule in disabledFokusRules {
            hero.setFokusRule(rule, active: false)
        }

        // Drop the hero straight into a running fight: re-entering combat resumes at
        // the combat root (see `CombatView.onAppear`), which skips the armour /
        // setup / initiative / loadout screens the screenshots are not about.
        hero.selectedWeaponName = weaponName
        hero.selectedOffHandName = nil
        hero.selectedShieldName = wantsShield ? shieldName : nil
        hero.activeCombatId = UUID()
        hero.activeCombatRound = 1
        hero.activeCombatInitiative = 12

        seedAdventure(into: context, hero: hero)

        try context.save()
    }

    /// A fixed adventure with a fixed week of weather.
    ///
    /// The values are written out rather than produced by `WeatherGenerator`,
    /// which rolls dice: a generated table would differ on every run and the
    /// weather screenshot could never be compared against its predecessor.
    private static func seedAdventure(into context: ModelContext, hero: Hero) {
        let adventure = Adventure(
            name: adventureName,
            region: .mittelreich,
            startDate: AventurianDate(day: 12, month: .rondra, year: 1040)
        )
        context.insert(adventure)

        // A week that exercises the row's whole vocabulary: clear through storm,
        // a warm day and a near-freezing night, and one hand-edited day so the
        // "bearbeitet" marker is on screen.
        let week: [(Int, CloudCover, WindStrength, Int, Int, RainLevel, WeatherField)] = [
            (12, .none,  .light,  24,  11, .none,   []),
            (13, .few,   .soft,   22,  10, .none,   []),
            (14, .lots,  .fresh,  18,   7, .little, []),
            (15, .all,   .strong, 14,   5, .lots,   [.rain]),
            (16, .lots,  .cool,   16,   6, .little, []),
            (17, .few,   .light,  21,   9, .none,   []),
            (18, .none,  .none,   26,  13, .none,   []),
        ]

        for (day, clouds, wind, dayTemp, nightTemp, rain, overrides) in week {
            let result = WeatherResult(
                date: AventurianDate(day: day, month: .rondra, year: 1040),
                clouds: clouds,
                wind: wind,
                dayTemperature: dayTemp,
                nightTemperature: nightTemp,
                rain: rain
            )
            let weatherDay = WeatherDay(from: result, region: .mittelreich)
            weatherDay.adventure = adventure
            weatherDay.overridesRaw = overrides.rawValue
            context.insert(weatherDay)
        }

        hero.activeAdventure = adventure
    }
}
#endif
