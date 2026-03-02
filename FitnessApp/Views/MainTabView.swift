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
            
            WorkoutSelectionView()
                .tag(1)
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }
            
            NutritionView()
                .tag(2)
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
        }
        .gesture(
            DragGesture(minimumDistance: 50, coordinateSpace: .local)
                .onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height

                    // Only trigger if swipe is more horizontal than vertical
                    guard abs(horizontalAmount) > abs(verticalAmount) else { return }

                    withAnimation(.easeInOut(duration: 0.25)) {
                        if horizontalAmount < 0 {
                            // Swipe left → next tab
                            selectedTab = min(selectedTab + 1, 2)
                        } else {
                            // Swipe right → previous tab
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
