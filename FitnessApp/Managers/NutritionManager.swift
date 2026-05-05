//
//  NutritionManager.swift
//  SimplyFit
//
//  Created by Nelson Mojica on 2/23/26.
//
import Observation
import Foundation
import SwiftUI

// MARK: - Activity Level
enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary        = "Sedentary"
    case lightlyActive    = "Lightly Active"
    case moderatelyActive = "Moderately Active"
    case veryActive       = "Very Active"

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
        case .sedentary:        return "Little or no exercise"
        case .lightlyActive:    return "Exercise 1–3 days/week"
        case .moderatelyActive: return "Exercise 3–5 days/week"
        case .veryActive:       return "Hard exercise 6–7 days/week"
        }
    }

    var icon: String {
        switch self {
        case .sedentary:        return "sofa.fill"
        case .lightlyActive:    return "figure.walk"
        case .moderatelyActive: return "figure.run"
        case .veryActive:       return "flame.fill"
        }
    }
}

// MARK: - Nutrition Goal
enum NutritionGoal: String, CaseIterable, Codable {
    case loseWeight = "Lose Weight"
    case maintain   = "Maintain"
    case gainMuscle = "Gain Muscle"

    var calorieDelta: Int {
        switch self {
        case .loseWeight: return -500
        case .maintain:   return 0
        case .gainMuscle: return +400
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

// MARK: - Logged Food Entry
struct LoggedFoodEntry: Identifiable, Codable {
    let id: UUID
    let foodItem: FoodItem
    let date: Date
    let mealType: NutritionMealType

    init(foodItem: FoodItem, mealType: NutritionMealType) {
        self.id       = UUID()
        self.foodItem = foodItem
        self.date     = Date()
        self.mealType = mealType
    }

    init(id: UUID, foodItem: FoodItem, date: Date, mealType: NutritionMealType) {
        self.id       = id
        self.foodItem = foodItem
        self.date     = date
        self.mealType = mealType
    }
}

// MARK: - NutritionManager
@Observable
class NutritionManager {

    var activityLevel: ActivityLevel = .lightlyActive
    var goal: NutritionGoal = .maintain
    var loggedEntries: [LoggedFoodEntry] = []
    var userTDEE: Int? = nil

    private(set) var userId: String = ""
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
        if let user = user {
            goal     = nutritionGoal(from: user.primaryGoal)
            userTDEE = Int(UserMetricsCalculator.tdee(bmr: user.bmr, activityLevel: user.activityLevel).rounded())
        }
        reloadBurnedCalories()
    }

    private func nutritionGoal(from primaryGoal: String) -> NutritionGoal {
        switch primaryGoal.lowercased() {
        case "lose weight":  return .loseWeight
        case "build muscle": return .gainMuscle
        default:             return .maintain
        }
    }

    func reloadBurnedCalories() {
        caloriesBurnedToday = loadBurnedCaloriesToday()
    }

    // MARK: - Calories Burned
    var caloriesBurnedToday: Int = 0

    private func loadBurnedCaloriesToday() -> Int {
        let key = "savedExercises_\(userId)"
        guard let data    = UserDefaults.standard.data(forKey: key),
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

    var remainingCalories: Int {
        calorieTarget + caloriesBurnedToday - Int(totalCalories)
    }

    var loggedFoods: [FoodItem] { loggedEntries.map { $0.foodItem } }

    // MARK: - Computed Totals
    var totalCalories: Double { loggedEntries.reduce(0) { $0 + $1.foodItem.calories } }
    var totalProtein: Double  { loggedEntries.reduce(0) { $0 + $1.foodItem.protein  } }
    var totalCarbs: Double    { loggedEntries.reduce(0) { $0 + $1.foodItem.carbs    } }
    var totalFat: Double      { loggedEntries.reduce(0) { $0 + $1.foodItem.fat      } }

    // MARK: - Macro Targets
    var proteinTarget: Int { Int(Double(calorieTarget) * 0.30 / 4) }
    var carbTarget: Int    { Int(Double(calorieTarget) * 0.45 / 4) }
    var fatTarget: Int     { Int(Double(calorieTarget) * 0.25 / 9) }

    // MARK: - Actions
    func logFood(_ food: FoodItem, mealType: NutritionMealType = .snack) {
        let entry = LoggedFoodEntry(foodItem: food, mealType: mealType)
        loggedEntries.append(entry)
        syncDailyLog()
        let uid = userId
        Task { try? await FoodLogService.shared.insertLog(userId: uid, entry: entry) }
    }

    func removeEntry(at offsets: IndexSet) {
        let entriesToRemove = offsets.map { loggedEntries[$0] }
        loggedEntries.remove(atOffsets: offsets)
        syncDailyLog()
        Task {
            for entry in entriesToRemove {
                try? await FoodLogService.shared.deleteLog(id: entry.id)
            }
        }
    }

    func removeFood(at offsets: IndexSet) {
        removeEntry(at: offsets)
    }

    func clearAll() {
        loggedEntries.removeAll()
        syncDailyLog()
        let uid = userId
        Task { try? await FoodLogService.shared.deleteAllTodayLogs(userId: uid) }
    }

    func setGoal(_ goal: NutritionGoal) {
        self.goal = goal
        saveSettings()
    }

    // MARK: - Supabase Daily Log Sync
    // Called internally whenever nutrition changes.
    // Calories burned and workouts are passed as 0 here — the activity
    // view owns those values and will upsert them separately. Supabase
    // upsert merges on (user_id, date) so nothing is overwritten.
    private func syncDailyLog() {
        guard !userId.isEmpty else { return }
        let calories = totalCalories
        Task {
            try? await DailyLogService.shared.upsertLog(
                userId: userId,
                caloriesEaten: calories,
                caloriesBurned: caloriesBurnedToday
            )
        }
    }

    // Public version called from NutritionView when it needs
    // to pass external burned/workout counts.
    func syncDailyLog(userId: String, caloriesBurned: Int, workoutsCompleted: Int) {
        guard !userId.isEmpty else { return }
        let calories = totalCalories
        Task {
            try? await DailyLogService.shared.upsertLog(
                userId: userId,
                caloriesEaten: calories,
                caloriesBurned: caloriesBurned,
                workoutsCompleted: workoutsCompleted
            )
        }
    }

    // MARK: - Supabase Food Log
    @MainActor
    func loadFromSupabase() async {
        guard !userId.isEmpty else { return }
        do {
            let records = try await FoodLogService.shared.fetchTodayLogs(userId: userId)
            loggedEntries = records.map { record in
                let food = FoodItem(
                    fdcId: 0,
                    description: record.foodName,
                    foodNutrients: [
                        FoodNutrient(nutrientId: 1008, value: record.calories),
                        FoodNutrient(nutrientId: 1003, value: record.protein),
                        FoodNutrient(nutrientId: 1005, value: record.carbs),
                        FoodNutrient(nutrientId: 1004, value: record.fat)
                    ]
                )
                let mealType = NutritionMealType(rawValue: record.mealType) ?? .snack
                return LoggedFoodEntry(id: record.id, foodItem: food, date: Date(), mealType: mealType)
            }
        } catch {
            print("⚠️ Failed to load food logs from Supabase: \(error)")
        }
    }

    // MARK: - Persistence
    private func saveSettings() {
        let data = try? JSONEncoder().encode(NutritionSettings(goal: goal))
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    private func loadSettings() {
        guard let data     = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(NutritionSettings.self, from: data)
        else { return }
        goal = settings.goal
    }
}

// MARK: - Settings Codable helper
private struct NutritionSettings: Codable {
    let goal: NutritionGoal
}
