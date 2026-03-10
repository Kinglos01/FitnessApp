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
    @State private var showSettings: Bool = false
    
    private var firstName: String {
        let full = appState.currentUser?.name ?? ""
        let first = full.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "Friend" : first
    }
    
    var calorieProgress: Double {
        min(nutritionManager.totalCalories / calorieGoal, 1.0)
    }
    
    let workoutStreak: Int = 0
    
    var activeThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let _ = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        ) else { return 0 }
        return workoutStreak  // placeholder — will be replaced with ActivityLog data later
    }

    var workoutsThisMonth: Int {
        workoutStreak * 5  // placeholder — will be replaced with ActivityLog data later
    }
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning" }
        else if hour < 17 { return "Good Afternoon" }
        else { return "Good Evening" }
    }
    
    private var quickStatsBar: some View {
        HStack(spacing: 0) {
            QuickStatCell(
                value: "\(workoutStreak)",
                label: "Day Streak",
                icon: "flame.fill",
                color: .orange
            )
            Divider().frame(height: 40)
            QuickStatCell(
                value: "\(activeThisWeek)",
                label: "Active Days",
                icon: "calendar.badge.checkmark",
                color: .green
            )
            Divider().frame(height: 40)
            QuickStatCell(
                value: "\(workoutsThisMonth)",
                label: "This Month",
                icon: "chart.bar.fill",
                color: .blue
            )
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
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
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                                Circle()
                                    .trim(from: 0, to: calorieProgress)
                                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.blue)
                            }
                            .frame(width: 56, height: 56)
                            
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                    showSettings.toggle()
                                }
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Settings Dropdown
                    if showSettings {
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                    showSettings = false
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "person.fill")
                                    Text("Edit Profile")
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .foregroundColor(.primary)
                            
                            Divider()
                            
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                    showSettings = false
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "gearshape")
                                    Text("Settings")
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .foregroundColor(.primary)
                            
                            Divider()
                            
                            Button {
                                Task {
                                    try? await AuthService.shared.signOut()
                                    appState.signOut()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Log Out")
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .foregroundColor(.red)
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
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
                    
                    // MARK: - Quick Stats Bar
                    quickStatsBar
                    
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
                    
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }
}

// MARK: - Quick Stat Cell
struct QuickStatCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
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
