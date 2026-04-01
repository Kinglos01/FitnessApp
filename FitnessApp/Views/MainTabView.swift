//
//  MainTabView.swift
//  FitnessApp
//
//  Created by Nelson Mojica on 2/19/26.
//

import SwiftUI

struct MainTabView: View {

    @State private var selectedTab = 0
    @Environment(AppState.self) var appState

    var body: some View {
        TabView(selection: $selectedTab) {

            DashboardView()
                .id(appState.currentUser?.id ?? "")
                .tag(0)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }

            NutritionView()
                .tag(1)
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }

            ActivityLogView(userId: appState.currentUser?.id ?? "")
                .id(appState.currentUser?.id ?? "")
                .tag(2)
                .tabItem {
                    Label("Activity", systemImage: "figure.run")
                }

            CalendarView()
                .id(appState.currentUser?.id ?? "")
                .tag(3)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
        }
        .gesture(
            DragGesture(minimumDistance: 50, coordinateSpace: .local)
                .onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height

                    guard abs(horizontalAmount) > abs(verticalAmount) else { return }

                    withAnimation(.easeInOut(duration: 0.25)) {
                        if horizontalAmount < 0 {
                            selectedTab = min(selectedTab + 1, 3)
                        } else {
                            selectedTab = max(selectedTab - 1, 0)
                        }
                    }
                }
        )
        .preferredColorScheme(appState.colorScheme)
    }
}

#Preview("Populated") {
    MainTabView()
        .environment(AppState())
        .environment(NutritionManager())
}

#Preview("Empty State") {
    MainTabView()
        .environment(AppState())
        .environment(NutritionManager())
}
