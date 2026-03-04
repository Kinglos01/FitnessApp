//
//  RootView.swift
//  FitnessApp
//
//  Created by Yohangel Adames on 3/4/26.
//

import SwiftUI

struct RootView: View {

    @Environment(AppState.self) var appState

    var body: some View {
        if appState.isLoggedIn && appState.hasCompletedOnboarding {
            MainTabView()
        } else if appState.isLoggedIn && !appState.hasCompletedOnboarding {
            UserInfoView()
        } else {
            ContentView()
        }
    }
}
