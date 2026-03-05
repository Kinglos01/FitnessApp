//
//  MainTabView.swift
//  FitnessApp
//
//  Created by Nelson Mojica on 2/19/26.
//

import SwiftUI

struct MainTabView: View {
    
    @State private var nutritionManager = NutritionManager()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            
            DashboardView()
                .tag(0)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            
            NutritionView()
                .tag(1)
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
            
            ActivityLogView()
                .tag(2)
                .tabItem {
                    Label("Activity", systemImage: "figure.run")
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
                            selectedTab = min(selectedTab + 1, 2)
                        } else {
                            selectedTab = max(selectedTab - 1, 0)
                        }
                    }
                }
        )
        .environment(nutritionManager)
    }
}

#Preview("Populated") {
    MainTabView()
}

#Preview("Empty State") {
    MainTabView()
}
