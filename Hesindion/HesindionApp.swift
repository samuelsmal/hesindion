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
        do {
            return try ModelContainer(for: Hero.self, HeroStateEntry.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
