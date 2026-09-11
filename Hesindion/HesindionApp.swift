//
//  HesindionApp.swift
//  Hesindion
//
//  Created by vonbaussnerns on 2026-02-20.
//

import SwiftUI
import SwiftData

@main
struct HesindionApp: App {
    var sharedModelContainer: ModelContainer = {
        #if DEBUG
        // Debug builds launched with `-uitest-seed-hero` get a throwaway, pre-seeded
        // store instead of the real one — see `UITestSeed`. Nothing else can reach it.
        if UITestSeed.isRequested {
            return UITestSeed.makeContainer()
        }
        #endif
        do {
            return try ModelContainer(for: Hero.self, HeroStateEntry.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // nil in every normal launch, so the app follows the system.
                .preferredColorScheme(DebugLaunch.appearance)
        }
        .modelContainer(sharedModelContainer)
    }
}
