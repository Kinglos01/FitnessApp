import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            WorkoutSelectionView()
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }
            
            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
        }
    }
}