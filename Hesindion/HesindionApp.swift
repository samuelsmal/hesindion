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
            let schema = Schema(versionedSchema: SchemaV1.self)
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(
                for: schema,
                migrationPlan: HesindionMigrationPlan.self,
                configurations: [configuration]
            )
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
