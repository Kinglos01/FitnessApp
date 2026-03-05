//
//  DashboardView.swift
//  FitnessApp
//
//  Created by Nelson Mojica on 2/23/26.
//

import SwiftUI

struct DashboardView: View {
    
    @Environment(NutritionManager.self) var nutritionManager
    @Environment(AppState.self) var appState
    
    let calorieGoal: Double = 2200
    let waterGoal: Int = 8
    @State private var waterConsumed: Int = 0
    
    private var firstName: String {
        let full = appState.currentUser?.name ?? ""
        let first = full.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "there" : first
    }
    
    var calorieProgress: Double {
        min(nutritionManager.totalCalories / calorieGoal, 1.0)
    }
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning" }
        else if hour < 17 { return "Good Afternoon" }
        else { return "Good Evening" }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - Greeting Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(greeting), \(firstName) 👋")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Let's crush today's goals")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Calorie Card (NOW LIVE)
                    VStack(spacing: 12) {
                        HStack {
                            Text("Calories")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(nutritionManager.totalCalories)) / \(Int(calorieGoal)) kcal")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        ProgressView(value: calorieProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                            .scaleEffect(x: 1, y: 2)
                        
                        // Macros Row (NOW LIVE)
                        HStack(spacing: 0) {
                            MacroCard(value: Int(nutritionManager.totalProtein), label: "Protein", color: .blue)
                            Divider().frame(height: 40)
                            MacroCard(value: Int(nutritionManager.totalCarbs), label: "Carbs", color: .green)
                            Divider().frame(height: 40)
                            MacroCard(value: Int(nutritionManager.totalFat), label: "Fat", color: .red)
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // MARK: - Water Tracker
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Water Intake", systemImage: "drop.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Spacer()
                            Text("\(waterConsumed) / \(waterGoal) glasses")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 8) {
                            ForEach(0..<waterGoal, id: \.self) { index in
                                Image(systemName: index < waterConsumed ? "drop.fill" : "drop")
                                    .foregroundColor(index < waterConsumed ? .blue : .gray.opacity(0.3))
                                    .font(.title3)
                            }
                            Spacer()
                            Button {
                                if waterConsumed > 0 {
                                    waterConsumed -= 1
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                            Button {
                                if waterConsumed < waterGoal {
                                    waterConsumed += 1
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // MARK: - Streak Card
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Workout Streak", systemImage: "flame.fill")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("0 days — get started!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("0")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // MARK: - Logged Foods Preview
                    if !nutritionManager.loggedFoods.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Today's Food Log", systemImage: "fork.knife")
                                .font(.headline)
                            
                            ForEach(nutritionManager.loggedFoods.suffix(3)) { food in
                                HStack {
                                    Text(food.description)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(Int(food.calories)) kcal")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            if nutritionManager.loggedFoods.count > 3 {
                                Text("+ \(nutritionManager.loggedFoods.count - 3) more items")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Log Out
                    Button {
                        Task {
                            try? await AuthService.shared.signOut()
                            appState.signOut()
                        }
                    } label: {
                        Text("Log Out")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }
}

// MARK: - Macro Card
struct MacroCard: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)g")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DashboardView()
        .environment(NutritionManager())
        .environment(AppState())
}
