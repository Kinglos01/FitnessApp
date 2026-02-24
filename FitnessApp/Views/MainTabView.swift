//
//  MainTabView.swift
//  FitnessApp
//
//  Created by Nelson Mojica on 2/19/26.
//

import SwiftUI

struct MainTabView: View {
    
    // Single shared instance — both Dashboard and Nutrition read from this
    @State private var nutritionManager = NutritionManager()
    
    var body: some View {
        TabView {
            
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            
            WorkoutSelectionView()
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }
            
            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
            
        }
        .environment(nutritionManager)
    }
}

#Preview {
    MainTabView()
}
