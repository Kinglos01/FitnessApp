//
//  NutritionView.swift
//  FitnessApp
//
//  Created by Nelson Mojica on 2/19/26.
//

import SwiftUI

struct NutritionView: View {
    @State private var service = NutritionService()
    @State private var searchText = ""
    @State private var foods: [FoodItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Shared manager — replaces the old @State loggedFoods
    @Environment(NutritionManager.self) var nutritionManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // MARK: - Calorie Summary Banner
                VStack(spacing: 4) {
                    Text("Calories Today")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(Int(nutritionManager.totalCalories)) kcal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                
                // MARK: - Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search food...", text: $searchText)
                        .onSubmit { Task { await search() } }
                    if isLoading {
                        ProgressView()
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // MARK: - Results or Logged Foods
                if foods.isEmpty && nutritionManager.loggedFoods.isEmpty {
                    Spacer()
                    Text("Search for a food to get started")
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    List {
                        // Search results
                        if !foods.isEmpty {
                            Section(header: Text("Search Results")) {
                                ForEach(foods) { food in
                                    FoodRowView(food: food) {
                                        nutritionManager.logFood(food)
                                        foods = []
                                        searchText = ""
                                    }
                                }
                            }
                        }
                        
                        // Logged foods
                        if !nutritionManager.loggedFoods.isEmpty {
                            Section(header: Text("Logged Today")) {
                                ForEach(nutritionManager.loggedFoods) { food in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(food.description)
                                                .font(.subheadline)
                                                .lineLimit(1)
                                            Text("\(Int(food.calories)) kcal")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                        Spacer()
                                    }
                                }
                                .onDelete { nutritionManager.removeFood(at: $0) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nutrition")
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    func search() async {
        guard !searchText.isEmpty else { return }
        isLoading = true
        do {
            foods = try await service.searchFoods(query: searchText)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Food Row
struct FoodRowView: View {
    let food: FoodItem
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.description)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 12) {
                    MacroLabel(value: food.calories, label: "kcal", color: .orange)
                    MacroLabel(value: food.protein, label: "P", color: .blue)
                    MacroLabel(value: food.carbs, label: "C", color: .green)
                    MacroLabel(value: food.fat, label: "F", color: .red)
                }
            }
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MacroLabel: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        Text("\(Int(value))\(label)")
            .font(.caption)
            .foregroundColor(color)
    }
}

#Preview("With Logged Foods") {
    NutritionView()
        .environment(MockData.populatedNutritionManager)
}

#Preview("Empty State") {
    NutritionView()
        .environment(NutritionManager())
}
