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

    /// The weapon the seeded hero goes into combat with. Named here because the
    /// UI tests navigate the attack flow that depends on it (a single one-handed
    /// melee weapon, no shield, no off-hand).
    static let weaponName = "Langschwert"

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
                for: Hero.self, HeroStateEntry.self,
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

        // Drop the hero straight into a running fight: re-entering combat resumes at
        // the combat root (see `CombatView.onAppear`), which skips the armour /
        // setup / initiative / loadout screens the screenshots are not about.
        hero.selectedWeaponName = weaponName
        hero.selectedOffHandName = nil
        hero.selectedShieldName = nil
        hero.activeCombatId = UUID()
        hero.activeCombatRound = 1
        hero.activeCombatInitiative = 12

        try context.save()
    }
}
#endif
