//
//  FitnessAppApp.swift
//  FitnessApp
//
//  Created by Carlos Berio on 2/11/26.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct FitnessAppApp: App {

    init() {
        FirebaseApp.configure()
        print("Firebase configured:", FirebaseApp.app() != nil)
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
