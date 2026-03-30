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
import Observation
import Foundation
import SwiftUI

// MARK: - Activity Level
enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary      = "Sedentary"
    case lightlyActive  = "Lightly Active"
    case moderatelyActive = "Moderately Active"
    case veryActive     = "Very Active"

    var multiplier: Double {
        switch self {
        case .sedentary:        return 1.2
        case .lightlyActive:    return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive:       return 1.725
        }
    }

    var description: String {
        switch self {
        case .sedentary:          return "Little or no exercise"
        case .lightlyActive:      return "Exercise 1–3 days/week"
        case .moderatelyActive:   return "Exercise 3–5 days/week"
        case .veryActive:         return "Hard exercise 6–7 days/week"
        }
    }

    var icon: String {
        switch self {
        case .sedentary:          return "sofa.fill"
        case .lightlyActive:      return "figure.walk"
        case .moderatelyActive:   return "figure.run"
        case .veryActive:         return "flame.fill"
        }
    }
}

// MARK: - Nutrition Goal
enum NutritionGoal: String, CaseIterable, Codable {
    case loseWeight  = "Lose Weight"
    case maintain    = "Maintain"
    case gainMuscle  = "Gain Muscle"

    var calorieDelta: Int {
        switch self {
        case .loseWeight:  return -500
        case .maintain:    return 0
        case .gainMuscle:  return +400
        }
    }

    var icon: String {
        switch self {
        case .loseWeight: return "arrow.down.circle.fill"
        case .maintain:   return "heart.circle.fill"
        case .gainMuscle: return "bolt.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .loseWeight: return .red
        case .maintain:   return .blue
        case .gainMuscle: return .green
        }
    }
}

// MARK: - Logged Food Entry (persisted)
struct LoggedFoodEntry: Identifiable, Codable {
    let id: UUID
    let foodItem: FoodItem
    let date: Date
    let mealType: NutritionMealType

    init(foodItem: FoodItem, mealType: NutritionMealType) {
        self.id = UUID()
        self.foodItem = foodItem
        self.date = Date()
        self.mealType = mealType
    }
}

// MARK: - NutritionManager
@Observable
class NutritionManager {

    // Persisted settings
    var activityLevel: ActivityLevel = .lightlyActive
    var goal: NutritionGoal = .maintain

    // Today's log
    var loggedEntries: [LoggedFoodEntry] = []

    // User-driven TDEE (set from AppState.currentUser)
    var userTDEE: Int? = nil

    private var userId: String = ""
    private var logKey: String { "nutritionLog_\(userId)_\(todayString)" }
    private var settingsKey: String { "nutritionSettings_\(userId)" }

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Setup
    func configure(userId: String, user: User?) {
        self.userId = userId
        loadSettings()
        loadTodayLog()
        if let user = user {
            // Sync goal from user's primaryGoal in settings
            goal = nutritionGoal(from: user.primaryGoal)
            // TDEE uses user's actual activity level
            userTDEE = Int(UserMetricsCalculator.tdee(bmr: user.bmr, activityLevel: user.activityLevel))
        }
        reloadBurnedCalories()
    }

    private func nutritionGoal(from primaryGoal: String) -> NutritionGoal {
        switch primaryGoal.lowercased() {
        case "lose weight":       return .loseWeight
        case "build muscle":      return .gainMuscle
        default:                  return .maintain
        }
    }

    func reloadBurnedCalories() {
        caloriesBurnedToday = loadBurnedCaloriesToday()
    }

    // MARK: - Calories Burned (from Activity Log)
    var caloriesBurnedToday: Int = 0

    private func loadBurnedCaloriesToday() -> Int {
        let key = "savedExercises_\(userId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([ActivityEntry].self, from: data)
        else { return 0 }
        let today = Calendar.current.startOfDay(for: Date())
        return entries
            .filter { $0.isCompleted && Calendar.current.startOfDay(for: $0.date) == today }
            .reduce(0) { $0 + $1.caloriesBurned }
    }

    // MARK: - Calorie Target
    var calorieTarget: Int {
        let base = userTDEE ?? 2000
        return max(1200, base + goal.calorieDelta)
    }

    // Net = target + burned - eaten (how many calories left to eat)
    var remainingCalories: Int {
        calorieTarget + caloriesBurnedToday - Int(totalCalories)
    }

    // MARK: - Today's foods (backwards compat for views that use loggedFoods)
    var loggedFoods: [FoodItem] { loggedEntries.map { $0.foodItem } }

    // MARK: - Computed Totals
    var totalCalories: Double { loggedEntries.reduce(0) { $0 + $1.foodItem.calories } }
    var totalProtein: Double  { loggedEntries.reduce(0) { $0 + $1.foodItem.protein  } }
    var totalCarbs: Double    { loggedEntries.reduce(0) { $0 + $1.foodItem.carbs    } }
    var totalFat: Double      { loggedEntries.reduce(0) { $0 + $1.foodItem.fat      } }

    // MARK: - Macros targets (standard % splits)
    var proteinTarget: Int { Int(Double(calorieTarget) * 0.30 / 4) }  // 30% calories / 4 cal per g
    var carbTarget: Int    { Int(Double(calorieTarget) * 0.45 / 4) }  // 45%
    var fatTarget: Int     { Int(Double(calorieTarget) * 0.25 / 9) }  // 25% / 9 cal per g

    // MARK: - Actions
    func logFood(_ food: FoodItem, mealType: NutritionMealType = .snack) {
        let entry = LoggedFoodEntry(foodItem: food, mealType: mealType)
        loggedEntries.append(entry)
        saveTodayLog()
    }

    func removeEntry(at offsets: IndexSet) {
        loggedEntries.remove(atOffsets: offsets)
        saveTodayLog()
    }

    func removeFood(at offsets: IndexSet) {
        removeEntry(at: offsets)
    }

    func clearAll() {
        loggedEntries.removeAll()
        saveTodayLog()
    }

    func setGoal(_ goal: NutritionGoal) {
        self.goal = goal
        saveSettings()
    }

    // MARK: - Persistence
    private func saveSettings() {
        let data = try? JSONEncoder().encode(NutritionSettings(goal: goal))
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(NutritionSettings.self, from: data)
        else { return }
        goal = settings.goal
    }

    private func saveTodayLog() {
        let data = try? JSONEncoder().encode(loggedEntries)
        UserDefaults.standard.set(data, forKey: logKey)
    }

    private func loadTodayLog() {
        guard let data = UserDefaults.standard.data(forKey: logKey),
              let entries = try? JSONDecoder().decode([LoggedFoodEntry].self, from: data)
        else { loggedEntries = []; return }
        loggedEntries = entries
    }
}

// MARK: - Settings Codable helper
private struct NutritionSettings: Codable {
    let goal: NutritionGoal
}
