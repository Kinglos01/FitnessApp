//
//  NutritionManager.swift
//  FitnessApp
//
//  Created by Nelson Mojica on 2/23/26.
//
//  Shared in-memory store for logged foods.
//  Both NutritionView and DashboardView read from this.
//  Nothing persists on restart — swap in Firestore later.
//

import Foundation
import SwiftUI

@Observable
class NutritionManager {
    
    var loggedFoods: [FoodItem] = []
    
    // MARK: - Computed Totals
    var totalCalories: Double {
        loggedFoods.reduce(0) { $0 + $1.calories }
    }
    
    var totalProtein: Double {
        loggedFoods.reduce(0) { $0 + $1.protein }
    }
    
    var totalCarbs: Double {
        loggedFoods.reduce(0) { $0 + $1.carbs }
    }
    
    var totalFat: Double {
        loggedFoods.reduce(0) { $0 + $1.fat }
    }
    
    // MARK: - Actions
    func logFood(_ food: FoodItem) {
        loggedFoods.append(food)
    }
    
    func removeFood(at offsets: IndexSet) {
        loggedFoods.remove(atOffsets: offsets)
    }
    
    func clearAll() {
        loggedFoods.removeAll()
    }
}
