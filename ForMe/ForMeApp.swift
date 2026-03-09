//
//  ForMeApp.swift
//  ForMe
//
//  Menu bar app — single popup with inline task/calendar toggle.
//

import SwiftUI
import SwiftData

@main
struct ForMeApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([TaskItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var prayerTimeManager = PrayerTimeManager()

    var body: some Scene {
        MenuBarExtra("ForMe", systemImage: "moon.fill") {
            FloatingIslandView()
                .environment(prayerTimeManager)
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)

        Settings {
            Text("ForMe Settings").padding()
        }
    }
}
