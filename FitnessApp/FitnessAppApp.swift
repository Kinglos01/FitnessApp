//
//  FitnessAppApp.swift
//  FitnessApp
//
//  Created by Carlos Berio on 2/11/26.
//

import SwiftUI

@main
struct FitnessAppApp: App {

    @State private var appState = AppState()
    let exerciseService = ExerciseService()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environment(appState)
        }
    }
}
